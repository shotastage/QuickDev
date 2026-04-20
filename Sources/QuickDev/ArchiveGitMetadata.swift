import Foundation

public struct ArchiveGitMetadataResult: Equatable, Sendable {
    public let gitInfo: ArchiveGitInfo
    public let warnings: [ArchiveWarningEntry]

    public init(gitInfo: ArchiveGitInfo, warnings: [ArchiveWarningEntry]) {
        self.gitInfo = gitInfo
        self.warnings = warnings
    }
}

public struct ArchiveGitMetadataCollector {
    private let fileManager: FileManager
    private let gitInspector: GitInspector

    public init(fileManager: FileManager = .default, gitInspector: GitInspector = GitInspector()) {
        self.fileManager = fileManager
        self.gitInspector = gitInspector
    }

    /// Collects git metadata for manifest generation and emits soft warnings if metadata is unavailable.
    public func collect(projectRootURL: URL, includeGitDirectory: Bool) -> ArchiveGitMetadataResult {
        guard includeGitDirectory else {
            return ArchiveGitMetadataResult(gitInfo: ArchiveGitInfo(included: false, headCommit: nil, branch: nil, dirty: nil), warnings: [])
        }

        let gitDirectoryURL = projectRootURL.appendingPathComponent(".git", isDirectory: true)
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: gitDirectoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ArchiveGitMetadataResult(gitInfo: ArchiveGitInfo(included: false, headCommit: nil, branch: nil, dirty: nil), warnings: [])
        }

        let result = gitInspector.inspect(directoryURL: projectRootURL)
        let gitInfo = ArchiveGitInfo(
            included: true,
            headCommit: result.headCommit,
            branch: result.branch,
            dirty: result.hasUncommittedChanges
        )

        if result.headCommit == nil, result.branch == nil, result.hasUncommittedChanges == nil {
            return ArchiveGitMetadataResult(
                gitInfo: gitInfo,
                warnings: [
                    ArchiveWarningEntry(path: ".git", reason: "git_metadata_unavailable"),
                ]
            )
        }

        return ArchiveGitMetadataResult(gitInfo: gitInfo, warnings: [])
    }
}
