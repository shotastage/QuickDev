//
//  ProjectClassifier.swift
//
//  Created by Shota Shimazu on 2026/04/03.
//

import Foundation

struct ProjectClassification: Equatable {
    let types: [ProjectType]
    let isProject: Bool
    let isGitRepository: Bool
}

public struct ProjectClassifier {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Returns whether a directory is likely a development project based on known markers.
    /// - Parameter directoryURL: Directory URL to evaluate.
    /// - Returns: `true` when the directory contains one or more known project markers.
    /// - Throws: Any filesystem error encountered while reading the directory contents.
    public func isLikelyProject(directoryURL: URL) throws -> Bool {
        try classify(directoryURL: directoryURL).isProject
    }
}

extension ProjectClassifier: ProjectClassifying {
    func classify(directoryURL: URL) throws -> ProjectClassification {
        let items = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: []
        )

        let itemNames = Set(items.map(\.lastPathComponent))
        let containsGitMarker = itemNames.contains(".git")
        var types: [ProjectType] = []

        if itemNames.contains("Package.swift") {
            types.append(.swiftPackage)
        }

        if itemNames.contains("package.json") {
            types.append(.nodePackage)
        }

        if itemNames.contains("go.mod") {
            types.append(.goModule)
        }

        if itemNames.contains("Cargo.toml") {
            types.append(.rustCrate)
        }

        if itemNames.contains("pom.xml") {
            types.append(.javaMaven)
        }

        if itemNames.contains("build.gradle") || itemNames.contains("build.gradle.kts") {
            types.append(.javaGradle)
        }

        if items.contains(where: { ["xcodeproj", "xcworkspace"].contains($0.pathExtension) }) {
            types.append(.xcodeProject)
        }

        if containsGitMarker {
            types.append(.gitRepository)
        }

        return ProjectClassification(
            types: types,
            isProject: !types.isEmpty,
            isGitRepository: containsGitMarker
        )
    }
}
