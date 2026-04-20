import Foundation

public enum ArchiveOutputPathResolverError: LocalizedError, Equatable {
    case homeDirectoryUnavailable
    case failedToCreateArchiveDirectory(String)
    case failedToResolveOutputPath(String)

    public var errorDescription: String? {
        switch self {
        case .homeDirectoryUnavailable:
            return "Could not resolve the current user's home directory."
        case .failedToCreateArchiveDirectory(let path):
            return "Failed to create archive directory: \(path)"
        case .failedToResolveOutputPath(let path):
            return "Failed to resolve output path: \(path)"
        }
    }
}

public struct ArchiveOutputPathResolver {
    private let fileManager: FileManager
    private let now: () -> Date
    private let homeDirectoryProvider: () -> URL?
    private let currentDirectoryProvider: () -> URL

    public init(
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        homeDirectoryProvider: @escaping () -> URL? = {
            FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        },
        currentDirectoryProvider: @escaping () -> URL = {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true).standardizedFileURL
        }
    ) {
        self.fileManager = fileManager
        self.now = now
        self.homeDirectoryProvider = homeDirectoryProvider
        self.currentDirectoryProvider = currentDirectoryProvider
    }

    /// Resolves an output archive path, defaulting to ~/.quickdev/archive when --output is omitted.
    public func resolveOutputPath(projectName: String, outputPath: String?) throws -> URL {
        if let outputPath, outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return try resolveExplicitOutputPath(outputPath)
        }

        guard let homeDirectoryURL = homeDirectoryProvider()?.standardizedFileURL else {
            throw ArchiveOutputPathResolverError.homeDirectoryUnavailable
        }

        let archiveDirectoryURL = homeDirectoryURL
            .appendingPathComponent(".quickdev", isDirectory: true)
            .appendingPathComponent("archive", isDirectory: true)
            .standardizedFileURL

        do {
            try fileManager.createDirectory(
                at: archiveDirectoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
            )
        } catch {
            throw ArchiveOutputPathResolverError.failedToCreateArchiveDirectory(archiveDirectoryURL.path)
        }

        let timestamp = timestampString(from: now())
        let sanitizedName = sanitizeFileName(projectName)
        let baseFileName = "\(sanitizedName)-\(timestamp).qda"
        let defaultOutputURL = archiveDirectoryURL.appendingPathComponent(baseFileName, isDirectory: false)

        return resolveUniquePath(defaultOutputURL)
    }

    /// Sanitizes project names for filesystem-safe archive file names.
    public func sanitizeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return "project"
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleanedScalars = trimmed.unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }

            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return "-"
            }

            if scalar == "/" || scalar == "\\" || scalar == ":" {
                return "-"
            }

            return "-"
        }

        var sanitized = String(cleanedScalars)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_."))

        while sanitized.contains("--") {
            sanitized = sanitized.replacingOccurrences(of: "--", with: "-")
        }

        return sanitized.isEmpty ? "project" : sanitized
    }

    private func resolveExplicitOutputPath(_ outputPath: String) throws -> URL {
        let expandedPath = NSString(string: outputPath).expandingTildeInPath
        let baseCurrentDirectory = currentDirectoryProvider().standardizedFileURL
        let resolvedURL: URL

        if expandedPath.hasPrefix("/") {
            resolvedURL = URL(fileURLWithPath: expandedPath, isDirectory: false)
        } else {
            resolvedURL = URL(fileURLWithPath: expandedPath, relativeTo: baseCurrentDirectory)
        }

        let standardized = resolvedURL.standardizedFileURL
        guard standardized.path.isEmpty == false else {
            throw ArchiveOutputPathResolverError.failedToResolveOutputPath(outputPath)
        }

        return standardized
    }

    private func resolveUniquePath(_ url: URL) -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }

        let directoryURL = url.deletingLastPathComponent()
        let originalFileName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        var counter = 2
        while true {
            let candidateName = "\(originalFileName)-\(counter)"
            let candidateURL = directoryURL
                .appendingPathComponent(candidateName, isDirectory: false)
                .appendingPathExtension(fileExtension)

            if fileManager.fileExists(atPath: candidateURL.path) == false {
                return candidateURL
            }

            counter += 1
        }
    }

    private func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
