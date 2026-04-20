import Foundation

public enum ArchiveProjectDetectorError: LocalizedError, Equatable {
    case targetPathDoesNotExist(String)
    case targetPathIsNotDirectory(String)
    case targetPathIsNotReadable(String)

    public var errorDescription: String? {
        switch self {
        case .targetPathDoesNotExist(let path):
            return "Target path does not exist: \(path)"
        case .targetPathIsNotDirectory(let path):
            return "Target path is not a directory: \(path)"
        case .targetPathIsNotReadable(let path):
            return "Target path is not readable: \(path)"
        }
    }
}

public struct ArchiveProjectDetector {
    private let fileManager: FileManager
    private let currentDirectoryProvider: () -> URL

    public init(
        fileManager: FileManager = .default,
        currentDirectoryProvider: @escaping () -> URL = {
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        }
    ) {
        self.fileManager = fileManager
        self.currentDirectoryProvider = currentDirectoryProvider
    }

    /// Resolves a command argument path and returns normalized archive project metadata.
    public func detectProject(targetPath: String?) throws -> ArchiveProjectInfo {
        let targetURL = try resolveTargetURL(targetPath)
        let rootURL = detectProjectRoot(from: targetURL)
        let projectName = rootURL.lastPathComponent

        let hasPackageJSON = fileExists(in: rootURL, name: "package.json")
        let hasPNPMWorkspace = fileExists(in: rootURL, name: "pnpm-workspace.yaml")

        let packageJSONWorkspaces = hasPackageJSON ? (try packageJSONContainsWorkspaces(in: rootURL) ?? false) : false
        let isMonorepo = hasPNPMWorkspace || packageJSONWorkspaces

        let projectType: ArchiveProjectType = (hasPackageJSON || hasPNPMWorkspace) ? .node : .unknown

        return ArchiveProjectInfo(
            rootURL: rootURL,
            name: projectName,
            type: projectType,
            isMonorepo: isMonorepo,
            packageManager: detectPackageManager(in: rootURL)
        )
    }

    /// Normalizes a target path to an absolute, standardized directory URL.
    public func resolveTargetURL(_ targetPath: String?) throws -> URL {
        let fallback = currentDirectoryProvider().standardizedFileURL
        guard let targetPath else {
            return try validateDirectoryURL(fallback)
        }

        let trimmedPath = targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.isEmpty == false else {
            return try validateDirectoryURL(fallback)
        }

        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
        let resolvedURL: URL

        if expandedPath.hasPrefix("/") {
            resolvedURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        } else {
            resolvedURL = URL(fileURLWithPath: expandedPath, relativeTo: fallback)
        }

        return try validateDirectoryURL(resolvedURL.standardizedFileURL)
    }

    /// Walks up from the target path and picks the nearest directory that contains project markers.
    func detectProjectRoot(from targetURL: URL) -> URL {
        var currentURL = targetURL.standardizedFileURL

        while true {
            if fileExists(in: currentURL, name: "package.json") || fileExists(in: currentURL, name: "pnpm-workspace.yaml") {
                return currentURL
            }

            let parentURL = currentURL.deletingLastPathComponent().standardizedFileURL
            if parentURL.path == currentURL.path {
                break
            }

            currentURL = parentURL
        }

        return targetURL.standardizedFileURL
    }

    /// Estimates package manager from lock files with explicit precedence.
    public func detectPackageManager(in projectRootURL: URL) -> ArchivePackageManager {
        if fileExists(in: projectRootURL, name: "pnpm-lock.yaml") {
            return .pnpm
        }

        if fileExists(in: projectRootURL, name: "yarn.lock") {
            return .yarn
        }

        if fileExists(in: projectRootURL, name: "package-lock.json") {
            return .npm
        }

        return .npm
    }

    private func validateDirectoryURL(_ url: URL) throws -> URL {
        let normalizedURL = url.standardizedFileURL
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: normalizedURL.path, isDirectory: &isDirectory) else {
            throw ArchiveProjectDetectorError.targetPathDoesNotExist(normalizedURL.path)
        }

        guard isDirectory.boolValue else {
            throw ArchiveProjectDetectorError.targetPathIsNotDirectory(normalizedURL.path)
        }

        guard fileManager.isReadableFile(atPath: normalizedURL.path) else {
            throw ArchiveProjectDetectorError.targetPathIsNotReadable(normalizedURL.path)
        }

        return normalizedURL
    }

    private func fileExists(in directoryURL: URL, name: String) -> Bool {
        fileManager.fileExists(atPath: directoryURL.appendingPathComponent(name, isDirectory: false).path)
    }

    private func packageJSONContainsWorkspaces(in projectRootURL: URL) throws -> Bool? {
        let packageJSONURL = projectRootURL.appendingPathComponent("package.json", isDirectory: false)
        guard fileManager.fileExists(atPath: packageJSONURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: packageJSONURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let workspaces = object["workspaces"] as? [Any] {
            return workspaces.isEmpty == false
        }

        if let workspacesObject = object["workspaces"] as? [String: Any] {
            return workspacesObject.isEmpty == false
        }

        return false
    }
}
