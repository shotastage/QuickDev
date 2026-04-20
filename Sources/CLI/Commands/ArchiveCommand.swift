import ArgumentParser
import Foundation
import QuickDev

struct ArchiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "archive",
        abstract: "Archive a project safely into a compact .qda file for future restoration."
    )

    @Argument(help: "Target project path. Defaults to the current directory.")
    var targetPath: String?

    @Flag(name: .long, help: "Preview archive planning without creating files.")
    var dryRun: Bool = false

    @Option(name: .long, help: "Output archive path. Defaults to ~/.quickdev/archive/<project>-<timestamp>.qda")
    var output: String?

    @Option(name: .long, help: "Compression profile: default or max.")
    var compression: ArchiveCompressionOption = .default

    @Flag(name: .customLong("include-dotenv"), help: "Explicitly show included .env* files in logs.")
    var includeDotenv: Bool = false

    @Option(name: .long, help: "Additional exclude patterns as a comma-separated list.")
    var exclude: String?

    @Flag(name: .customLong("keep-git"), help: "Keep .git in the archive payload (default behavior).")
    var keepGit: Bool = false

    @Option(name: .long, help: "Archive format. MVP supports qda only.")
    var format: ArchiveFormatOption = .qda

    mutating func run() throws {
        do {
            try execute()
        } catch let error as ArchiveCommandFailure {
            fputs("\(error.message)\n", stderr)
            throw ExitCode(error.exitCode.rawValue)
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            throw ExitCode(ArchiveCommandExitCode.generalError.rawValue)
        }
    }

    private func execute() throws {
        guard format == .qda else {
            throw ArchiveCommandFailure(
                message: "Unsupported format '\(format.rawValue)'. Only 'qda' is available in this MVP.",
                exitCode: .invalidArguments
            )
        }

        let fileManager = FileManager.default
        let detector = ArchiveProjectDetector(fileManager: fileManager)
        let scanner = ArchiveFileScanner(fileManager: fileManager)
        let planner = ArchivePlanner()
        let policyBuilder = ArchivePolicyBuilder()
        let outputPathResolver = ArchiveOutputPathResolver(fileManager: fileManager)
        let manifestBuilder = ArchiveManifestBuilder()
        let gitCollector = ArchiveGitMetadataCollector(fileManager: fileManager)
        let writer = ArchiveWriter(fileManager: fileManager)

        let project: ArchiveProjectInfo
        do {
            project = try detector.detectProject(targetPath: targetPath)
        } catch {
            throw ArchiveCommandFailure(
                message: describe(error: error),
                exitCode: .invalidTargetPath
            )
        }

        let policy = policyBuilder.makePolicy(
            project: project,
            extraExcludePatterns: parseExcludePatterns(exclude),
            keepGit: true
        )

        let scannedEntries: [ArchiveScannedEntry]
        do {
            scannedEntries = try scanner.scan(projectRootURL: project.rootURL)
        } catch {
            throw ArchiveCommandFailure(
                message: describe(error: error),
                exitCode: .invalidTargetPath
            )
        }

        let plan = planner.plan(scannedEntries: scannedEntries, policy: policy)

        let outputURL: URL
        do {
            outputURL = try outputPathResolver.resolveOutputPath(projectName: project.name, outputPath: output)
        } catch {
            throw ArchiveCommandFailure(
                message: describe(error: error),
                exitCode: .generalError
            )
        }

        var runtimeWarnings = runtimeWarnings(for: project)

        if dryRun {
            printDryRunSummary(project: project, plan: plan, outputURL: outputURL, runtimeWarnings: runtimeWarnings)
            if includeDotenv {
                printDotenvSummary(paths: plan.dotenvPaths)
            }
            return
        }

        let gitMetadata = gitCollector.collect(projectRootURL: project.rootURL, includeGitDirectory: true)
        runtimeWarnings.append(contentsOf: gitMetadata.warnings)

        let firstManifest = manifestBuilder.buildManifest(
            project: project,
            plan: plan,
            git: gitMetadata.gitInfo,
            compression: compression.quickDevCompression,
            quickdevVersion: quickDevCLIVersion,
            archivedBytes: 0,
            additionalWarnings: runtimeWarnings
        )

        let firstWriteResult: ArchiveWriteResult
        do {
            firstWriteResult = try writer.writeArchive(
                projectRootURL: project.rootURL,
                includedEntries: plan.included,
                manifest: firstManifest,
                outputURL: outputURL,
                compression: compression.quickDevCompression
            )
            try writer.verifyArchive(at: firstWriteResult.outputURL)
        } catch let error as ArchiveWriterError {
            throw ArchiveCommandFailure(message: describe(error: error), exitCode: mapArchiveWriterError(error))
        } catch {
            throw ArchiveCommandFailure(message: describe(error: error), exitCode: .archiveCreationFailed)
        }

        let finalManifest = manifestBuilder.buildManifest(
            project: project,
            plan: plan,
            git: gitMetadata.gitInfo,
            compression: compression.quickDevCompression,
            quickdevVersion: quickDevCLIVersion,
            archivedBytes: firstWriteResult.archivedBytes,
            additionalWarnings: runtimeWarnings
        )

        // Rewrite once so the embedded manifest carries final archive byte size metadata.
        do {
            try fileManager.removeItem(at: firstWriteResult.outputURL)

            _ = try writer.writeArchive(
                projectRootURL: project.rootURL,
                includedEntries: plan.included,
                manifest: finalManifest,
                outputURL: outputURL,
                compression: compression.quickDevCompression
            )
            try writer.verifyArchive(at: outputURL)
        } catch let error as ArchiveWriterError {
            throw ArchiveCommandFailure(message: describe(error: error), exitCode: mapArchiveWriterError(error))
        } catch {
            throw ArchiveCommandFailure(message: describe(error: error), exitCode: .archiveCreationFailed)
        }

        let finalSize = (try? fileManager.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.int64Value ?? 0

        printFinalSummary(
            project: project,
            plan: plan,
            outputURL: outputURL,
            archiveBytes: finalSize,
            runtimeWarnings: runtimeWarnings,
            restoreCommands: finalManifest.restoreHints.commands
        )

        if includeDotenv {
            printDotenvSummary(paths: plan.dotenvPaths)
        }
    }

    private func parseExcludePatterns(_ value: String?) -> [String] {
        guard let value else {
            return []
        }

        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func runtimeWarnings(for project: ArchiveProjectInfo) -> [ArchiveWarningEntry] {
        var warnings: [ArchiveWarningEntry] = []

        if project.type == .unknown {
            warnings.append(
                ArchiveWarningEntry(path: project.rootURL.lastPathComponent, reason: "unknown_project_type_detected")
            )
        }

        let lockfileNames = ["pnpm-lock.yaml", "yarn.lock", "package-lock.json"]
        let hasLockfile = lockfileNames.contains { lockfile in
            FileManager.default.fileExists(atPath: project.rootURL.appendingPathComponent(lockfile, isDirectory: false).path)
        }

        if hasLockfile == false {
            warnings.append(
                ArchiveWarningEntry(path: project.rootURL.lastPathComponent, reason: "package_manager_inferred_as_npm")
            )
        }

        return warnings
    }

    private func mapArchiveWriterError(_ error: ArchiveWriterError) -> ArchiveCommandExitCode {
        switch error {
        case .verificationFailed:
            return .verificationFailed
        default:
            return .archiveCreationFailed
        }
    }

    private func describe(error: Error) -> String {
        if let localizedError = error as? LocalizedError,
            let description = localizedError.errorDescription,
            description.isEmpty == false
        {
            return description
        }

        return error.localizedDescription
    }

    private func printDryRunSummary(
        project: ArchiveProjectInfo,
        plan: PlannedArchive,
        outputURL: URL,
        runtimeWarnings: [ArchiveWarningEntry]
    ) {
        let allWarnings = (plan.warnings + runtimeWarnings)
            .sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }

        print("Project: \(project.name)")
        print("Type: \(project.type.rawValue)")
        print("Package manager: \((project.packageManager ?? .npm).rawValue)")
        print("")
        print("Included files: \(formatInteger(plan.stats.archivedFileCount))")
        print("Excluded entries: \(formatInteger(plan.excluded.count))")
        print("Warnings: \(formatInteger(allWarnings.count))")
        print("")

        if plan.excluded.isEmpty {
            print("Excluded: (none)")
        } else {
            print("Excluded:")
            for entry in plan.excluded {
                print("- \(entry.path) (\(entry.category))")
            }
        }

        print("")
        if allWarnings.isEmpty {
            print("Warnings: (none)")
        } else {
            print("Warnings:")
            for warning in allWarnings {
                print("- \(warning.path) (\(warning.reason))")
            }
        }

        print("")
        print("Estimated size reduction: \(formatBytes(plan.stats.excludedBytesEstimate))")
        print("Archive will be written to: \(outputURL.path)")
    }

    private func printFinalSummary(
        project: ArchiveProjectInfo,
        plan: PlannedArchive,
        outputURL: URL,
        archiveBytes: Int64,
        runtimeWarnings: [ArchiveWarningEntry],
        restoreCommands: [String]
    ) {
        let allWarnings = (plan.warnings + runtimeWarnings)
            .sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }

        print("Archived project: \(project.name)")
        print("Type: \(project.type.rawValue)")
        print("Package manager: \((project.packageManager ?? .npm).rawValue)")
        print("Output: \(outputURL.path)")
        print("Archive size: \(formatBytes(archiveBytes))")
        print("Included files: \(formatInteger(plan.stats.archivedFileCount))")
        print("Excluded entries: \(formatInteger(plan.excluded.count))")
        print("Warnings: \(formatInteger(allWarnings.count))")

        if allWarnings.isEmpty == false {
            print("")
            print("Warnings:")
            for warning in allWarnings {
                print("- \(warning.path) (\(warning.reason))")
            }
        }

        print("")
        print("Restore hints:")
        for command in restoreCommands {
            print("- \(command)")
        }
    }

    private func printDotenvSummary(paths: [String]) {
        if paths.isEmpty {
            print("")
            print("Dotenv files explicitly included: (none detected)")
            return
        }

        print("")
        print("Dotenv files explicitly included:")
        for path in paths {
            print("- \(path)")
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }

        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024.0 && unitIndex < units.count - 1 {
            value /= 1024.0
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private func formatInteger(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

private struct ArchiveCommandFailure: Error {
    let message: String
    let exitCode: ArchiveCommandExitCode
}

private enum ArchiveCommandExitCode: Int32 {
    case success = 0
    case generalError = 1
    case invalidArguments = 2
    case invalidTargetPath = 3
    case archiveCreationFailed = 4
    case verificationFailed = 5
}

enum ArchiveCompressionOption: String, ExpressibleByArgument, CaseIterable {
    case `default`
    case max

    var quickDevCompression: ArchiveCompressionLevel {
        switch self {
        case .default:
            return .default
        case .max:
            return .max
        }
    }
}

enum ArchiveFormatOption: String, ExpressibleByArgument, CaseIterable {
    case qda
}
