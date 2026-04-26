import ArgumentParser
import Foundation
import QuickDev

struct RestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Restore a project from a .qda archive into ~/Developer or a custom directory."
    )

    @Argument(help: "Path to the .qda archive to restore.")
    var archivePath: String

    @Option(name: .long, help: "Destination directory. Defaults to ~/Developer/<project-name>")
    var destination: String?

    @Flag(name: .long, help: "Preview restore metadata without extracting files.")
    var dryRun: Bool = false

    mutating func run() throws {
        let fileManager = FileManager.default
        let homeDirectoryURL = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
        let restorer = ArchiveRestorer(fileManager: fileManager)

        do {
            let archiveURL = try RestoreCommandSupport.resolveArchiveURL(from: archivePath, fileManager: fileManager)
            let inspection = try restorer.inspectArchive(at: archiveURL)
            let destinationURL = try RestoreCommandSupport.buildRestoreDestinationPath(
                manifest: inspection.manifest,
                destinationPath: destination,
                fileManager: fileManager,
                homeDirectoryURL: homeDirectoryURL
            )

            if dryRun {
                printDryRunSummary(
                    inspection: inspection,
                    destinationURL: destinationURL,
                    homeDirectoryURL: homeDirectoryURL
                )
                return
            }

            let result = try restorer.restoreArchive(at: archiveURL, to: destinationURL)
            printFinalSummary(result: result, homeDirectoryURL: homeDirectoryURL)
        } catch let error as RestoreCommandError {
            fputs("\(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        } catch let error as ArchiveRestorerError {
            fputs("\(error.localizedDescription)\n", stderr)
            throw ExitCode.failure
        }
    }

    private func printDryRunSummary(
        inspection: ArchiveRestoreInspection,
        destinationURL: URL,
        homeDirectoryURL: URL
    ) {
        print("Archive: \(inspection.archiveURL.path)")
        print("Project: \(inspection.manifest.project.name)")
        print("Original path: \(inspection.manifest.project.originalPath)")
        print("Created at: \(inspection.manifest.createdAt)")
        print("Archived files: \(formatInteger(inspection.manifest.stats.archivedFileCount))")
        print("Warnings: \(formatInteger(inspection.manifest.warnings.count))")
        print("Destination: \(RestoreCommandSupport.displayPath(destinationURL, homeDirectoryURL: homeDirectoryURL))")

        print("")
        print("Restore hints:")
        for command in inspection.manifest.restoreHints.commands {
            print("- \(command)")
        }
    }

    private func printFinalSummary(result: ArchiveRestoreResult, homeDirectoryURL: URL) {
        print("Restored project: \(result.manifest.project.name)")
        print("Destination: \(RestoreCommandSupport.displayPath(result.destinationURL, homeDirectoryURL: homeDirectoryURL))")
        print("Restored files: \(formatInteger(result.restoredFileCount))")

        if result.manifest.warnings.isEmpty == false {
            print("")
            print("Archived warnings:")
            for warning in result.manifest.warnings {
                print("- \(warning.path) (\(warning.reason))")
            }
        }

        print("")
        print("Suggested next steps:")
        for command in result.manifest.restoreHints.commands {
            print("- \(command)")
        }
    }

    private func formatInteger(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

enum RestoreCommandSupport {
    static func resolveArchiveURL(from archivePath: String, fileManager: FileManager) throws -> URL {
        let trimmedPath = archivePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.isEmpty == false else {
            throw RestoreCommandError.emptyArchivePath
        }

        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
        let archiveURL: URL

        if expandedPath.hasPrefix("/") {
            archiveURL = URL(fileURLWithPath: expandedPath, isDirectory: false)
        } else {
            archiveURL = URL(
                fileURLWithPath: expandedPath,
                relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            )
        }

        let normalizedArchiveURL = archiveURL.standardizedFileURL
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: normalizedArchiveURL.path, isDirectory: &isDirectory) else {
            throw RestoreCommandError.archiveDoesNotExist(normalizedArchiveURL)
        }

        guard isDirectory.boolValue == false else {
            throw RestoreCommandError.archivePathIsDirectory(normalizedArchiveURL)
        }

        return normalizedArchiveURL
    }

    static func buildRestoreDestinationPath(
        manifest: ArchiveManifest,
        destinationPath: String?,
        fileManager: FileManager,
        homeDirectoryURL: URL
    ) throws -> URL {
        if let destinationPath {
            let trimmedPath = destinationPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedPath.isEmpty == false else {
                throw RestoreCommandError.emptyDestinationPath
            }

            let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
            if expandedPath.hasPrefix("/") {
                return URL(fileURLWithPath: expandedPath, isDirectory: true).standardizedFileURL
            }

            return URL(
                fileURLWithPath: expandedPath,
                relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            ).standardizedFileURL
        }

        return homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent(manifest.project.name, isDirectory: true)
            .standardizedFileURL
    }

    static func displayPath(_ url: URL, homeDirectoryURL: URL) -> String {
        let standardizedPath = url.standardizedFileURL.path
        let homePath = homeDirectoryURL.standardizedFileURL.path

        if standardizedPath == homePath {
            return "~"
        }

        if standardizedPath.hasPrefix(homePath + "/") {
            let relativePath = String(standardizedPath.dropFirst(homePath.count))
            return "~\(relativePath)"
        }

        return standardizedPath
    }
}

enum RestoreCommandError: LocalizedError, Equatable {
    case emptyArchivePath
    case archiveDoesNotExist(URL)
    case archivePathIsDirectory(URL)
    case emptyDestinationPath

    var errorDescription: String? {
        switch self {
        case .emptyArchivePath:
            return "Archive path is required."
        case .archiveDoesNotExist(let archiveURL):
            return "Archive does not exist: \(archiveURL.path)"
        case .archivePathIsDirectory(let archiveURL):
            return "Archive path must point to a file: \(archiveURL.path)"
        case .emptyDestinationPath:
            return "Destination path cannot be empty."
        }
    }
}
