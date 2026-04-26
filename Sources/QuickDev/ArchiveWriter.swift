import Foundation

public enum ArchiveWriterError: LocalizedError, Equatable {
    case failedToCreateStagingDirectory(String)
    case failedToCopyFile(String)
    case failedToWriteManifest(String)
    case outputAlreadyExists(String)
    case failedToCreateOutputDirectory(String)
    case archiveCreationFailed(String)
    case verificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .failedToCreateStagingDirectory(let path):
            return "Failed to create archive staging directory: \(path)"
        case .failedToCopyFile(let path):
            return "Failed to copy file into archive staging area: \(path)"
        case .failedToWriteManifest(let path):
            return "Failed to write archive manifest: \(path)"
        case .outputAlreadyExists(let path):
            return "Archive output already exists: \(path)"
        case .failedToCreateOutputDirectory(let path):
            return "Failed to create output directory: \(path)"
        case .archiveCreationFailed(let details):
            return "Archive creation failed: \(details)"
        case .verificationFailed(let details):
            return "Archive verification failed: \(details)"
        }
    }
}

public struct ArchiveWriter {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Writes a qda archive by staging payload/meta and compressing with tar+gzip.
    public func writeArchive(
        projectRootURL: URL,
        includedEntries: [ArchiveScannedEntry],
        manifest: ArchiveManifest,
        outputURL: URL,
        compression: ArchiveCompressionLevel
    ) throws -> ArchiveWriteResult {
        let normalizedOutputURL = outputURL.standardizedFileURL

        if fileManager.fileExists(atPath: normalizedOutputURL.path) {
            throw ArchiveWriterError.outputAlreadyExists(normalizedOutputURL.path)
        }

        let outputDirectoryURL = normalizedOutputURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
        } catch {
            throw ArchiveWriterError.failedToCreateOutputDirectory(outputDirectoryURL.path)
        }

        let stagingRootURL = fileManager.temporaryDirectory
            .appendingPathComponent("quickdev-archive-\(UUID().uuidString)", isDirectory: true)
            .standardizedFileURL

        do {
            try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        } catch {
            throw ArchiveWriterError.failedToCreateStagingDirectory(stagingRootURL.path)
        }

        defer {
            try? fileManager.removeItem(at: stagingRootURL)
        }

        let payloadURL = stagingRootURL.appendingPathComponent("payload", isDirectory: true)
        let metaURL = stagingRootURL.appendingPathComponent("meta", isDirectory: true)

        do {
            try fileManager.createDirectory(at: payloadURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: metaURL, withIntermediateDirectories: true)
        } catch {
            throw ArchiveWriterError.failedToCreateStagingDirectory(stagingRootURL.path)
        }

        let includedFiles = includedEntries.filter { $0.type == .file }
        for entry in includedFiles {
            let sourceURL = URL(fileURLWithPath: entry.absolutePath, isDirectory: false)
            let destinationURL = payloadURL
                .appendingPathComponent(entry.relativePath, isDirectory: false)
                .standardizedFileURL

            do {
                try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            } catch {
                throw ArchiveWriterError.failedToCopyFile(entry.relativePath)
            }
        }

        let manifestURL = metaURL.appendingPathComponent("archive.json", isDirectory: false)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            try data.write(to: manifestURL)
        } catch {
            throw ArchiveWriterError.failedToWriteManifest(manifestURL.path)
        }

        let tarFileURL = stagingRootURL.appendingPathComponent("archive.tar", isDirectory: false)
        do {
            let tarResult = try runProcess(
                executable: "tar",
                arguments: ["-cf", tarFileURL.path, "-C", stagingRootURL.path, "payload", "meta"]
            )

            guard tarResult.status == 0 else {
                let details = tarResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw ArchiveWriterError.archiveCreationFailed(details.isEmpty ? "tar exited with status \(tarResult.status)" : details)
            }

            let compressionOption = compression == .max ? "-9" : "-6"
            let gzipResult = try runProcess(
                executable: "gzip",
                arguments: ["-n", compressionOption, tarFileURL.path]
            )

            guard gzipResult.status == 0 else {
                let details = gzipResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw ArchiveWriterError.archiveCreationFailed(details.isEmpty ? "gzip exited with status \(gzipResult.status)" : details)
            }
        } catch let error as ArchiveWriterError {
            throw error
        } catch {
            throw ArchiveWriterError.archiveCreationFailed(error.localizedDescription)
        }

        let compressedURL = URL(fileURLWithPath: tarFileURL.path + ".gz", isDirectory: false)

        do {
            try fileManager.moveItem(at: compressedURL, to: normalizedOutputURL)
        } catch {
            throw ArchiveWriterError.archiveCreationFailed("Failed to move archive to \(normalizedOutputURL.path)")
        }

        let archivedBytes = (try? fileSize(at: normalizedOutputURL)) ?? 0

        return ArchiveWriteResult(outputURL: normalizedOutputURL, archivedBytes: archivedBytes)
    }

    /// Performs archive existence and tar index verification checks.
    public func verifyArchive(at archiveURL: URL) throws {
        let normalizedURL = archiveURL.standardizedFileURL

        guard fileManager.fileExists(atPath: normalizedURL.path) else {
            throw ArchiveWriterError.verificationFailed("Archive file not found: \(normalizedURL.path)")
        }

        let size = try fileSize(at: normalizedURL)
        guard size > 0 else {
            throw ArchiveWriterError.verificationFailed("Archive file is empty: \(normalizedURL.path)")
        }

        do {
            let result = try runProcess(executable: "tar", arguments: ["-tzf", normalizedURL.path])
            guard result.status == 0 else {
                let details = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                throw ArchiveWriterError.verificationFailed(details.isEmpty ? "tar exited with status \(result.status)" : details)
            }
        } catch let error as ArchiveWriterError {
            throw error
        } catch {
            throw ArchiveWriterError.verificationFailed(error.localizedDescription)
        }
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? NSNumber
        return size?.int64Value ?? 0
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
            return (process.terminationStatus, "", "")
        }

        return (process.terminationStatus, stdout, stderr)
    }
}
