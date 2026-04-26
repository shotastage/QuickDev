import Foundation

public enum ArchiveRestorerError: LocalizedError, Equatable {
    case archiveNotFound(String)
    case invalidArchive(String)
    case invalidManifest(String)
    case unsupportedSchemaVersion(Int)
    case unsupportedArchiveFormat(String)
    case unsafeArchiveEntry(String)
    case destinationAlreadyExists(String)
    case failedToCreateDestinationDirectory(String)
    case extractionFailed(String)
    case missingPayloadDirectory(String)

    public var errorDescription: String? {
        switch self {
        case .archiveNotFound(let path):
            return "Archive file not found: \(path)"
        case .invalidArchive(let details):
            return "Archive is not a valid qda file: \(details)"
        case .invalidManifest(let details):
            return "Archive manifest is invalid: \(details)"
        case .unsupportedSchemaVersion(let version):
            return "Unsupported archive manifest schema version: \(version)"
        case .unsupportedArchiveFormat(let format):
            return "Unsupported archive format: \(format)"
        case .unsafeArchiveEntry(let path):
            return "Archive contains an unsafe entry: \(path)"
        case .destinationAlreadyExists(let path):
            return "Restore destination already exists: \(path)"
        case .failedToCreateDestinationDirectory(let path):
            return "Failed to create restore destination directory: \(path)"
        case .extractionFailed(let details):
            return "Archive extraction failed: \(details)"
        case .missingPayloadDirectory(let path):
            return "Archive payload directory is missing after extraction: \(path)"
        }
    }
}

public struct ArchiveRestorer {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Reads and validates archive contents before restore.
    public func inspectArchive(at archiveURL: URL) throws -> ArchiveRestoreInspection {
        let normalizedArchiveURL = archiveURL.standardizedFileURL

        guard fileManager.fileExists(atPath: normalizedArchiveURL.path) else {
            throw ArchiveRestorerError.archiveNotFound(normalizedArchiveURL.path)
        }

        let archiveEntries = try listArchiveEntries(at: normalizedArchiveURL)
        let normalizedEntries = try validateArchiveEntries(archiveEntries)
        let manifest = try extractManifest(from: normalizedArchiveURL)

        guard manifest.schemaVersion == 1 else {
            throw ArchiveRestorerError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        guard manifest.archiveFormat == ArchiveFormat.qda.rawValue else {
            throw ArchiveRestorerError.unsupportedArchiveFormat(manifest.archiveFormat)
        }

        let payloadEntries = normalizedEntries
            .filter { $0.hasPrefix("payload/") && $0.hasSuffix("/") == false }
            .map { String($0.dropFirst("payload/".count)) }

        return ArchiveRestoreInspection(
            archiveURL: normalizedArchiveURL,
            manifest: manifest,
            payloadEntries: payloadEntries
        )
    }

    /// Restores payload contents into a new destination directory.
    public func restoreArchive(at archiveURL: URL, to destinationURL: URL) throws -> ArchiveRestoreResult {
        let inspection = try inspectArchive(at: archiveURL)
        let normalizedDestinationURL = destinationURL.standardizedFileURL

        guard fileManager.fileExists(atPath: normalizedDestinationURL.path) == false else {
            throw ArchiveRestorerError.destinationAlreadyExists(normalizedDestinationURL.path)
        }

        let destinationParentURL = normalizedDestinationURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: destinationParentURL, withIntermediateDirectories: true)
        } catch {
            throw ArchiveRestorerError.failedToCreateDestinationDirectory(destinationParentURL.path)
        }

        let stagingRootURL = fileManager.temporaryDirectory
            .appendingPathComponent("quickdev-restore-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL

        do {
            try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        } catch {
            throw ArchiveRestorerError.extractionFailed("Failed to create restore staging directory: \(stagingRootURL.path)")
        }

        defer {
            try? fileManager.removeItem(at: stagingRootURL)
        }

        let extractResult = try runProcess(
            executable: "tar",
            arguments: ["-xzf", inspection.archiveURL.path, "-C", stagingRootURL.path, "payload"]
        )

        guard extractResult.status == 0 else {
            let details = extractResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ArchiveRestorerError.extractionFailed(details.isEmpty ? "tar exited with status \(extractResult.status)" : details)
        }

        let payloadURL = stagingRootURL.appendingPathComponent("payload", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: payloadURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArchiveRestorerError.missingPayloadDirectory(payloadURL.path)
        }

        do {
            try fileManager.moveItem(at: payloadURL, to: normalizedDestinationURL)
        } catch {
            throw ArchiveRestorerError.extractionFailed(
                "Failed to move restored payload to \(normalizedDestinationURL.path)"
            )
        }

        return ArchiveRestoreResult(
            destinationURL: normalizedDestinationURL,
            manifest: inspection.manifest,
            restoredFileCount: inspection.payloadEntries.count
        )
    }

    private func extractManifest(from archiveURL: URL) throws -> ArchiveManifest {
        let extractionRootURL = fileManager.temporaryDirectory
            .appendingPathComponent("quickdev-manifest-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL

        do {
            try fileManager.createDirectory(at: extractionRootURL, withIntermediateDirectories: true)
        } catch {
            throw ArchiveRestorerError.invalidManifest("Failed to create temporary directory for manifest extraction")
        }

        defer {
            try? fileManager.removeItem(at: extractionRootURL)
        }

        let extractionResult = try runProcess(
            executable: "tar",
            arguments: ["-xzf", archiveURL.path, "-C", extractionRootURL.path, "meta/archive.json"]
        )

        guard extractionResult.status == 0 else {
            let details = extractionResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ArchiveRestorerError.invalidManifest(details.isEmpty ? "meta/archive.json could not be extracted" : details)
        }

        let manifestURL = extractionRootURL.appendingPathComponent("meta/archive.json", isDirectory: false)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw ArchiveRestorerError.invalidManifest("meta/archive.json is missing")
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode(ArchiveManifest.self, from: data)
        } catch {
            throw ArchiveRestorerError.invalidManifest(error.localizedDescription)
        }
    }

    private func listArchiveEntries(at archiveURL: URL) throws -> [String] {
        let result = try runProcess(executable: "tar", arguments: ["-tzf", archiveURL.path])

        guard result.status == 0 else {
            let details = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ArchiveRestorerError.invalidArchive(details.isEmpty ? "tar exited with status \(result.status)" : details)
        }

        return result.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.isEmpty == false }
    }

    private func validateArchiveEntries(_ entries: [String]) throws -> [String] {
        guard entries.isEmpty == false else {
            throw ArchiveRestorerError.invalidArchive("Archive is empty")
        }

        var normalizedEntries: [String] = []
        var hasManifest = false
        var hasPayloadRoot = false

        for entry in entries {
            let normalizedEntry = normalize(entry: entry)

            guard normalizedEntry.isEmpty == false else {
                throw ArchiveRestorerError.unsafeArchiveEntry(entry)
            }

            guard normalizedEntry.hasPrefix("/") == false else {
                throw ArchiveRestorerError.unsafeArchiveEntry(normalizedEntry)
            }

            let components = normalizedEntry.split(separator: "/", omittingEmptySubsequences: false)
            guard components.contains("..") == false else {
                throw ArchiveRestorerError.unsafeArchiveEntry(normalizedEntry)
            }

            if normalizedEntry == "payload" || normalizedEntry == "payload/" {
                hasPayloadRoot = true
            } else if normalizedEntry.hasPrefix("payload/") {
                hasPayloadRoot = true
            } else if normalizedEntry == "meta" || normalizedEntry == "meta/" {
                // Allow the metadata directory entry.
            } else if normalizedEntry == "meta/archive.json" {
                hasManifest = true
            } else {
                throw ArchiveRestorerError.unsafeArchiveEntry(normalizedEntry)
            }

            normalizedEntries.append(normalizedEntry)
        }

        guard hasManifest else {
            throw ArchiveRestorerError.invalidManifest("meta/archive.json is missing")
        }

        guard hasPayloadRoot else {
            throw ArchiveRestorerError.invalidArchive("payload directory is missing")
        }

        return normalizedEntries
    }

    private func normalize(entry: String) -> String {
        if entry.hasPrefix("./") {
            return String(entry.dropFirst(2))
        }

        return entry
    }

    private func runProcess(executable: String, arguments: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard let stdout = String(data: stdoutData, encoding: .utf8),
            let stderr = String(data: stderrData, encoding: .utf8)
        else {
            throw ArchiveRestorerError.invalidArchive("Process output was not valid UTF-8")
        }

        return (process.terminationStatus, stdout, stderr)
    }
}
