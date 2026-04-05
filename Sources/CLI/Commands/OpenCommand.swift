//
//  OpenCommand.swift
//
//  Created by Shota Shimazu on 2026/04/05.
//

import ArgumentParser
import Foundation
import QuickDev

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open an indexed project in Visual Studio Code."
    )

    @Argument(help: "Project directory name shown by `qd list`.")
    var projectName: String

    @Option(name: .long, help: "Root directory to resolve against. Defaults to the cached index root, then ~/Developer.")
    var root: String?

    mutating func run() throws {
        let fileManager = FileManager.default
        let support = ProjectIndexCommandSupport(fileManager: fileManager)
        let store = ProjectIndexStore(fileManager: fileManager)
        let requestedRootURL = root.map { support.resolvedRootURL(from: $0) }
        let index = try loadIndexOrScanIfNeeded(
            fileManager: fileManager,
            support: support,
            store: store,
            requestedRootURL: requestedRootURL
        )
        let project = try resolveProject(named: projectName, in: index)
        let projectDirectoryURL = URL(fileURLWithPath: project.path, isDirectory: true)

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: projectDirectoryURL.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ValidationError(
                "Project directory no longer exists: \(projectDirectoryURL.path). Run `qd scan` to refresh the index."
            )
        }

        let openResult = try Shell.run(
            "open",
            arguments: ["-a", "Visual Studio Code", projectDirectoryURL.path]
        )

        guard openResult.status == 0 else {
            let stderr = openResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let details = stderr.isEmpty ? "Exit status: \(openResult.status)." : stderr
            throw ValidationError(
                "Failed to launch Visual Studio Code for '\(project.name)' at \(projectDirectoryURL.path). \(details)"
            )
        }

        print("Opened '\(project.name)' in Visual Studio Code.")
        print("Path: \(projectDirectoryURL.path)")
    }

    // MARK: - Helpers

    /// Loads the cached index when available, otherwise performs a scan and updates the cache.
    private func loadIndexOrScanIfNeeded(
        fileManager: FileManager,
        support: ProjectIndexCommandSupport,
        store: ProjectIndexStore,
        requestedRootURL: URL?
    ) throws -> ProjectIndex {
        if let cachedIndex = try store.loadIndex(matchingRootPath: requestedRootURL?.path) {
            return cachedIndex
        }

        let rootURL = requestedRootURL ?? support.defaultRootURL
        let scanner = ProjectScanner(fileManager: fileManager)
        let index = try scanner.scan(rootURL: rootURL)
        _ = try store.save(index)
        return index
    }

    /// Resolves a project name from the index and transforms lookup errors into actionable CLI messages.
    private func resolveProject(named name: String, in index: ProjectIndex) throws -> ProjectRecord {
        do {
            return try index.project(named: name)
        } catch let error as ProjectIndexLookupError {
            switch error {
            case .projectNotFound:
                let candidates = suggestedProjectNames(for: name, in: index.projects)
                if candidates.isEmpty {
                    throw ValidationError(
                        "Project '\(name)' was not found in the cached index (root: \(index.rootPath)). Run `qd list` to inspect available names."
                    )
                }

                throw ValidationError(
                    "Project '\(name)' was not found. Did you mean: \(candidates.joined(separator: ", "))?"
                )
            case .ambiguousProjectName(_, let matches):
                throw ValidationError(
                    "Project name '\(name)' is ambiguous. Matches: \(matches.joined(separator: ", ")). Use a more specific root with `--root`."
                )
            }
        } catch {
            throw error
        }
    }

    /// Returns deterministic suggestions based on prefix and substring matching.
    private func suggestedProjectNames(for query: String, in projects: [ProjectRecord]) -> [String] {
        let normalizedQuery = query.lowercased()
        let sortedNames = Array(Set(projects.map(\.name))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }

        let prefixMatches = sortedNames.filter { $0.lowercased().hasPrefix(normalizedQuery) }
        if prefixMatches.isEmpty == false {
            return Array(prefixMatches.prefix(5))
        }

        let containsMatches = sortedNames.filter { $0.lowercased().contains(normalizedQuery) }
        return Array(containsMatches.prefix(5))
    }
}
