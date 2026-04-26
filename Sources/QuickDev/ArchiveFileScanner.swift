import Foundation

public enum ArchiveFileScannerError: LocalizedError, Equatable {
    case rootDoesNotExist(String)
    case rootIsNotDirectory(String)
    case rootIsNotReadable(String)

    public var errorDescription: String? {
        switch self {
        case .rootDoesNotExist(let path):
            return "Archive root does not exist: \(path)"
        case .rootIsNotDirectory(let path):
            return "Archive root is not a directory: \(path)"
        case .rootIsNotReadable(let path):
            return "Archive root is not readable: \(path)"
        }
    }
}

public struct ArchiveFileScanner {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .fileSizeKey,
        .nameKey,
    ]

    private let fileManager: FileManager
    private let warningHandler: (String) -> Void

    public init(fileManager: FileManager = .default, warningHandler: @escaping (String) -> Void = { _ in }) {
        self.fileManager = fileManager
        self.warningHandler = warningHandler
    }

    /// Recursively scans a project directory and returns deterministic relative entries.
    public func scan(projectRootURL: URL) throws -> [ArchiveScannedEntry] {
        let rootURL = projectRootURL.standardizedFileURL
        try validate(rootURL: rootURL)

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: [],
            errorHandler: { url, error in
                warningHandler("Skipping \(url.path): \(error.localizedDescription)")
                return true
            }
        ) else {
            throw ArchiveFileScannerError.rootIsNotReadable(rootURL.path)
        }

        var entries: [ArchiveScannedEntry] = []

        while let candidateURL = enumerator.nextObject() as? URL {
            let normalizedURL = candidateURL.standardizedFileURL

            do {
                let values = try normalizedURL.resourceValues(forKeys: Self.resourceKeys)
                let relativePath = normalizedURL.relativePath(from: rootURL)

                guard relativePath != "." else {
                    continue
                }

                if values.isSymbolicLink == true {
                    entries.append(
                        ArchiveScannedEntry(
                            relativePath: relativePath,
                            absolutePath: normalizedURL.path,
                            type: .symlink,
                            size: 0
                        )
                    )
                    enumerator.skipDescendants()
                    continue
                }

                if values.isDirectory == true {
                    entries.append(
                        ArchiveScannedEntry(
                            relativePath: relativePath,
                            absolutePath: normalizedURL.path,
                            type: .dir,
                            size: 0
                        )
                    )
                    continue
                }

                if values.isRegularFile == true {
                    entries.append(
                        ArchiveScannedEntry(
                            relativePath: relativePath,
                            absolutePath: normalizedURL.path,
                            type: .file,
                            size: Int64(values.fileSize ?? 0)
                        )
                    )
                }
            } catch {
                warningHandler("Skipping \(normalizedURL.path): \(error.localizedDescription)")
                enumerator.skipDescendants()
            }
        }

        return entries.sorted { lhs, rhs in
            lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
        }
    }

    private func validate(rootURL: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            throw ArchiveFileScannerError.rootDoesNotExist(rootURL.path)
        }

        guard isDirectory.boolValue else {
            throw ArchiveFileScannerError.rootIsNotDirectory(rootURL.path)
        }

        guard fileManager.isReadableFile(atPath: rootURL.path) else {
            throw ArchiveFileScannerError.rootIsNotReadable(rootURL.path)
        }
    }
}

private extension URL {
    func relativePath(from rootURL: URL) -> String {
        let rootComponents = rootURL.standardizedFileURL.pathComponents
        let targetComponents = standardizedFileURL.pathComponents

        guard targetComponents.starts(with: rootComponents) else {
            return path
        }

        let suffix = targetComponents.dropFirst(rootComponents.count)
        return suffix.isEmpty ? "." : suffix.joined(separator: "/")
    }
}
