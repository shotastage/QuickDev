import Foundation

public enum ProjectType: String, Codable, Sendable {
    case swiftPackage
    case nodePackage
    case goModule
    case rustCrate
    case javaGradle
    case javaMaven
    case xcodeProject
    case gitRepository
    case unknown
}

public extension ProjectType {
    var displayName: String {
        switch self {
        case .swiftPackage:
            return "Swift"
        case .nodePackage:
            return "Node"
        case .goModule:
            return "Go"
        case .rustCrate:
            return "Rust"
        case .javaGradle:
            return "Gradle"
        case .javaMaven:
            return "Maven"
        case .xcodeProject:
            return "Xcode"
        case .gitRepository:
            return "Git"
        case .unknown:
            return "Unknown"
        }
    }
}

public enum ProjectStatus: String, Codable, Sendable {
    case active
    case archived
    case trashed
    case ignored
}

public struct ProjectRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let relativePathFromRoot: String
    public let lastModifiedAt: Date
    public let detectedTypes: [ProjectType]
    public let isGitRepository: Bool
    public let gitRemoteURL: String?
    public let hasUncommittedChanges: Bool?
    public let primaryLanguage: String?
    public let sizeBytes: Int64?
    public let status: ProjectStatus
    public let scannedAt: Date

    public init(
        id: UUID,
        name: String,
        path: String,
        relativePathFromRoot: String,
        lastModifiedAt: Date,
        detectedTypes: [ProjectType],
        isGitRepository: Bool,
        gitRemoteURL: String?,
        hasUncommittedChanges: Bool?,
        primaryLanguage: String?,
        sizeBytes: Int64?,
        status: ProjectStatus,
        scannedAt: Date
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.relativePathFromRoot = relativePathFromRoot
        self.lastModifiedAt = lastModifiedAt
        self.detectedTypes = detectedTypes
        self.isGitRepository = isGitRepository
        self.gitRemoteURL = gitRemoteURL
        self.hasUncommittedChanges = hasUncommittedChanges
        self.primaryLanguage = primaryLanguage
        self.sizeBytes = sizeBytes
        self.status = status
        self.scannedAt = scannedAt
    }
}

public struct ProjectIndex: Codable, Equatable, Sendable {
    public let version: Int
    public let rootPath: String
    public let scannedAt: Date
    public let projects: [ProjectRecord]

    public init(version: Int, rootPath: String, scannedAt: Date, projects: [ProjectRecord]) {
        self.version = version
        self.rootPath = rootPath
        self.scannedAt = scannedAt
        self.projects = projects
    }
}

public enum ProjectScannerError: LocalizedError, Equatable {
    case rootDoesNotExist(String)
    case rootIsNotDirectory(String)
    case rootIsNotReadable(String)

    public var errorDescription: String? {
        switch self {
        case .rootDoesNotExist(let path):
            return "Scan root does not exist: \(path)"
        case .rootIsNotDirectory(let path):
            return "Scan root is not a directory: \(path)"
        case .rootIsNotReadable(let path):
            return "Scan root is not readable: \(path)"
        }
    }
}

protocol ProjectClassifying {
    func classify(directoryURL: URL) throws -> ProjectClassification
}

protocol GitInspecting {
    func inspect(directoryURL: URL) -> GitInspectionResult
}

public struct ProjectScanner {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .nameKey,
        .contentModificationDateKey,
    ]

    private let fileManager: FileManager
    private let classifier: any ProjectClassifying
    private let gitInspector: any GitInspecting
    private let maximumDepth: Int
    private let now: () -> Date
    private let warningHandler: (String) -> Void

    public init(fileManager: FileManager = .default, maximumDepth: Int = 2) {
        self.fileManager = fileManager
        self.classifier = ProjectClassifier(fileManager: fileManager)
        self.gitInspector = GitInspector()
        self.maximumDepth = maximumDepth
        self.now = Date.init
        self.warningHandler = { _ in }
    }

    init(
        fileManager: FileManager,
        classifier: any ProjectClassifying,
        gitInspector: any GitInspecting,
        maximumDepth: Int = 2,
        now: @escaping () -> Date,
        warningHandler: @escaping (String) -> Void = { _ in }
    ) {
        self.fileManager = fileManager
        self.classifier = classifier
        self.gitInspector = gitInspector
        self.maximumDepth = maximumDepth
        self.now = now
        self.warningHandler = warningHandler
    }

    /// Scans the provided root directory and returns a snapshot of detected projects.
    public func scan(rootURL: URL) throws -> ProjectIndex {
        let normalizedRootURL = rootURL.standardizedFileURL
        try validate(rootURL: normalizedRootURL)

        let scannedAt = now()
        var projects: [ProjectRecord] = []

        if let rootRecord = try makeRecordIfProject(
            at: normalizedRootURL,
            rootURL: normalizedRootURL,
            scannedAt: scannedAt
        ) {
            projects.append(rootRecord)
        }

        guard let enumerator = fileManager.enumerator(
            at: normalizedRootURL,
            includingPropertiesForKeys: Array(Self.resourceKeys),
            options: [],
            errorHandler: { url, error in
                warningHandler("Skipping \(url.path): \(error.localizedDescription)")
                return true
            }
        ) else {
            throw ProjectScannerError.rootIsNotReadable(normalizedRootURL.path)
        }

        while let candidateURL = enumerator.nextObject() as? URL {
            let standardizedURL = candidateURL.standardizedFileURL

            do {
                let resourceValues = try standardizedURL.resourceValues(forKeys: Self.resourceKeys)
                guard resourceValues.isDirectory == true else {
                    continue
                }

                if resourceValues.isSymbolicLink == true {
                    enumerator.skipDescendants()
                    continue
                }

                let directoryName = resourceValues.name ?? standardizedURL.lastPathComponent
                if ProjectScannerDefaults.skippedDirectoryNames.contains(directoryName) {
                    enumerator.skipDescendants()
                    continue
                }

                let depth = standardizedURL.relativeDepth(from: normalizedRootURL)
                if depth > maximumDepth {
                    enumerator.skipDescendants()
                    continue
                }

                if let record = try makeRecordIfProject(
                    at: standardizedURL,
                    rootURL: normalizedRootURL,
                    scannedAt: scannedAt,
                    resourceValues: resourceValues
                ) {
                    projects.append(record)
                    enumerator.skipDescendants()
                }
            } catch {
                warningHandler("Skipping \(standardizedURL.path): \(error.localizedDescription)")
                enumerator.skipDescendants()
            }
        }

        return ProjectIndex(
            version: 1,
            rootPath: normalizedRootURL.path,
            scannedAt: scannedAt,
            projects: projects.sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
        )
    }

    private func validate(rootURL: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            throw ProjectScannerError.rootDoesNotExist(rootURL.path)
        }

        guard isDirectory.boolValue else {
            throw ProjectScannerError.rootIsNotDirectory(rootURL.path)
        }

        guard fileManager.isReadableFile(atPath: rootURL.path) else {
            throw ProjectScannerError.rootIsNotReadable(rootURL.path)
        }
    }

    private func makeRecordIfProject(
        at directoryURL: URL,
        rootURL: URL,
        scannedAt: Date,
        resourceValues: URLResourceValues? = nil
    ) throws -> ProjectRecord? {
        let classification = try classifier.classify(directoryURL: directoryURL)
        guard classification.isProject else {
            return nil
        }

        let metadata = classification.isGitRepository
            ? gitInspector.inspect(directoryURL: directoryURL)
            : GitInspectionResult(remoteURL: nil, hasUncommittedChanges: nil)

        let resolvedResourceValues = try directoryURL.resourceValues(forKeys: [.contentModificationDateKey])
        let lastModifiedAt = resourceValues?.contentModificationDate
            ?? resolvedResourceValues.contentModificationDate
            ?? scannedAt

        return ProjectRecord(
            id: UUID(),
            name: directoryURL.lastPathComponent,
            path: directoryURL.path,
            relativePathFromRoot: directoryURL.relativePath(from: rootURL),
            lastModifiedAt: lastModifiedAt,
            detectedTypes: classification.types,
            isGitRepository: classification.isGitRepository,
            gitRemoteURL: metadata.remoteURL,
            hasUncommittedChanges: metadata.hasUncommittedChanges,
            primaryLanguage: ProjectLanguageMapper.primaryLanguage(for: classification.types),
            sizeBytes: nil,
            status: .active,
            scannedAt: scannedAt
        )
    }
}

enum ProjectScannerDefaults {
    static let skippedDirectoryNames: Set<String> = [
        ".git",
        "node_modules",
        ".build",
        ".swiftpm",
        "DerivedData",
        "dist",
        "build",
        "target",
        ".next",
        ".turbo",
        "Pods",
        ".gradle",
        ".venv",
        "venv",
        "__pycache__",
    ]
}

enum ProjectLanguageMapper {
    static func primaryLanguage(for types: [ProjectType]) -> String? {
        if types.contains(.swiftPackage) {
            return "Swift"
        }

        if types.contains(.nodePackage) {
            return "JavaScript"
        }

        if types.contains(.goModule) {
            return "Go"
        }

        if types.contains(.rustCrate) {
            return "Rust"
        }

        if types.contains(.javaGradle) || types.contains(.javaMaven) {
            return "Java"
        }

        return nil
    }
}

private extension URL {
    func relativeDepth(from rootURL: URL) -> Int {
        let relativePath = relativePath(from: rootURL)
        guard relativePath != "." else {
            return 0
        }

        return relativePath.split(separator: "/").count
    }

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
