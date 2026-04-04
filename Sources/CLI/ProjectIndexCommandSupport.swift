import Foundation
import QuickDev

struct ProjectIndexCommandSupport {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var defaultRootURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Developer", isDirectory: true)
            .standardizedFileURL
    }

    func resolvedRootURL(from root: String?) -> URL {
        guard let root else {
            return defaultRootURL
        }

        let expandedPath = NSString(string: root).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath, isDirectory: true).standardizedFileURL
        }

        return URL(
            fileURLWithPath: expandedPath,
            relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        ).standardizedFileURL
    }

    func renderJSON(_ index: ProjectIndex) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(index), as: UTF8.self)
    }

    func renderTable(for projects: [ProjectRecord]) -> String {
        let rows = projects.map { project in
            ProjectIndexTableRow(
                name: project.name,
                type: project.detectedTypes.map(\.rawValue).joined(separator: ","),
                modified: iso8601String(from: project.lastModifiedAt)
            )
        }

        let nameWidth = max("NAME".count, rows.map(\.name.count).max() ?? 0)
        let typeWidth = max("TYPE".count, rows.map(\.type.count).max() ?? 0)

        var lines = [
            pad("NAME", to: nameWidth) + "  " + pad("TYPE", to: typeWidth) + "  MODIFIED",
        ]

        lines.append(contentsOf: rows.map { row in
            pad(row.name, to: nameWidth) + "  " + pad(row.type, to: typeWidth) + "  " + row.modified
        })

        return lines.joined(separator: "\n")
    }

    func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func pad(_ value: String, to width: Int) -> String {
        let paddingCount = max(0, width - value.count)
        guard paddingCount > 0 else {
            return value
        }

        return value + String(repeating: " ", count: paddingCount)
    }
}

private struct ProjectIndexTableRow {
    let name: String
    let type: String
    let modified: String
}
