import Foundation

public struct ProjectScanState: Codable, Equatable, Sendable {
    public let version: Int
    public let rootPath: String
    public let scannedAt: Date

    public init(version: Int, rootPath: String, scannedAt: Date) {
        self.version = version
        self.rootPath = rootPath
        self.scannedAt = scannedAt
    }
}

public struct ProjectIndexStoreSaveResult: Equatable, Sendable {
    public let indexFileURL: URL
    public let scanStateFileURL: URL

    public init(indexFileURL: URL, scanStateFileURL: URL) {
        self.indexFileURL = indexFileURL
        self.scanStateFileURL = scanStateFileURL
    }
}

public enum ProjectIndexStoreError: LocalizedError, Equatable {
    case failedToCreateDirectory(String)
    case failedToEncodeIndex
    case failedToWriteIndex(String)
    case failedToWriteScanState(String)
    case failedToReadIndex(String)
    case failedToDecodeIndex(String)

    public var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let path):
            return "Failed to create store directory: \(path)"
        case .failedToEncodeIndex:
            return "Failed to encode project index."
        case .failedToWriteIndex(let path):
            return "Failed to write project index: \(path)"
        case .failedToWriteScanState(let path):
            return "Failed to write scan state: \(path)"
        case .failedToReadIndex(let path):
            return "Failed to read project index: \(path)"
        case .failedToDecodeIndex(let path):
            return "Failed to decode project index: \(path)"
        }
    }
}

public struct ProjectIndexStore {
    private let directoryURL: URL
    private let fileManager: FileManager

    public init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".devctl", isDirectory: true)
    }

    public var indexFileURL: URL {
        directoryURL.appendingPathComponent("projects.json")
    }

    public var scanStateFileURL: URL {
        directoryURL.appendingPathComponent("scan-state.json")
    }

    /// Saves the latest scan snapshot and accompanying scan metadata using atomic writes.
    public func save(_ index: ProjectIndex) throws -> ProjectIndexStoreSaveResult {
        try createDirectoryIfNeeded()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let indexData = try? encoder.encode(index) else {
            throw ProjectIndexStoreError.failedToEncodeIndex
        }

        do {
            try indexData.write(to: indexFileURL, options: [.atomic])
        } catch {
            throw ProjectIndexStoreError.failedToWriteIndex(indexFileURL.path)
        }

        let state = ProjectScanState(version: index.version, rootPath: index.rootPath, scannedAt: index.scannedAt)

        do {
            let stateData = try encoder.encode(state)
            try stateData.write(to: scanStateFileURL, options: [.atomic])
        } catch {
            throw ProjectIndexStoreError.failedToWriteScanState(scanStateFileURL.path)
        }

        return ProjectIndexStoreSaveResult(indexFileURL: indexFileURL, scanStateFileURL: scanStateFileURL)
    }

    public func loadIndex() throws -> ProjectIndex? {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data: Data
        do {
            data = try Data(contentsOf: indexFileURL)
        } catch {
            throw ProjectIndexStoreError.failedToReadIndex(indexFileURL.path)
        }

        do {
            return try decoder.decode(ProjectIndex.self, from: data)
        } catch {
            throw ProjectIndexStoreError.failedToDecodeIndex(indexFileURL.path)
        }
    }

    private func createDirectoryIfNeeded() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) == false else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            throw ProjectIndexStoreError.failedToCreateDirectory(directoryURL.path)
        }
    }
}