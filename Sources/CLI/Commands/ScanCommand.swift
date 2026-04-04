import ArgumentParser
import Foundation
import QuickDev

struct ScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan a development root and cache detected project metadata."
    )

    @Option(name: .long, help: "Root directory to scan. Defaults to ~/Developer.")
    var root: String?

    @Flag(name: .long, help: "Print the full project index as JSON.")
    var json: Bool = false

    @Flag(name: .long, help: "Ignore any existing cache and perform a full scan.")
    var force: Bool = false

    mutating func run() throws {
        let fileManager = FileManager.default
        let rootURL = resolvedRootURL(fileManager: fileManager)
        let scanner = ProjectScanner(fileManager: fileManager)
        let store = ProjectIndexStore(fileManager: fileManager)

        let index = try scanner.scan(rootURL: rootURL)
        let saveResult = try store.save(index)

        if json {
            print(try renderJSON(index))
            return
        }

        print("Scanned root: \(rootURL.path)")
        print("Projects found: \(index.projects.count)")
        print("Saved index: \(saveResult.indexFileURL.path)")

        if force {
            print("Scan mode: full")
        }

        guard index.projects.isEmpty == false else {
            return
        }

        print("")
        print(renderTable(for: index.projects))
    }

    private func resolvedRootURL(fileManager: FileManager) -> URL {
        guard let root else {
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer", isDirectory: true)
                .standardizedFileURL
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

    private func renderJSON(_ index: ProjectIndex) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(index), as: UTF8.self)
    }

    private func renderTable(for projects: [ProjectRecord]) -> String {
        let rows = projects.map { project in
            ScanTableRow(
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

    private func iso8601String(from date: Date) -> String {
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

private struct ScanTableRow {
    let name: String
    let type: String
    let modified: String
}