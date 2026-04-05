import Foundation

public enum ProjectIndexLookupError: LocalizedError, Equatable, Sendable {
    case projectNotFound(String)
    case ambiguousProjectName(String, matches: [String])

    public var errorDescription: String? {
        switch self {
        case .projectNotFound(let name):
            return "Project not found in the current index: \(name)"
        case .ambiguousProjectName(let name, let matches):
            let renderedMatches = matches.joined(separator: ", ")
            return "Multiple projects match '\(name)': \(renderedMatches)"
        }
    }
}

public extension ProjectIndex {
    /// Resolves a project by name from the current index.
    /// Matching first tries case-sensitive names, then case-insensitive names.
    /// - Parameter name: Project directory name shown by `qd list`.
    /// - Returns: The uniquely matched project record.
    /// - Throws: `ProjectIndexLookupError` when there is no match or the result is ambiguous.
    func project(named name: String) throws -> ProjectRecord {
        let exactMatches = projects.filter { $0.name == name }
        if exactMatches.count == 1 {
            return exactMatches[0]
        }

        if exactMatches.count > 1 {
            throw ProjectIndexLookupError.ambiguousProjectName(
                name,
                matches: renderAmbiguousMatches(exactMatches)
            )
        }

        let lowercaseName = name.lowercased()
        let caseInsensitiveMatches = projects.filter { $0.name.lowercased() == lowercaseName }

        if caseInsensitiveMatches.count == 1 {
            return caseInsensitiveMatches[0]
        }

        if caseInsensitiveMatches.count > 1 {
            throw ProjectIndexLookupError.ambiguousProjectName(
                name,
                matches: renderAmbiguousMatches(caseInsensitiveMatches)
            )
        }

        throw ProjectIndexLookupError.projectNotFound(name)
    }

    private func renderAmbiguousMatches(_ matches: [ProjectRecord]) -> [String] {
        matches
            .sorted { lhs, rhs in
                lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
            .map { "\($0.name) (\($0.relativePathFromRoot))" }
    }
}
