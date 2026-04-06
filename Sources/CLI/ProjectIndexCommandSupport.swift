//
//  ProjectIndexCommandSupport.swift
//
//  Created by Shota Shimazu on 2026/04/03.
//

import Foundation
import QuickDev

struct ProjectIndexCommandSupport {
    private let fileManager: FileManager
    private let now: () -> Date

    init(fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
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
                type: project.detectedTypes.map(\.displayName).joined(separator: ","),
                modified: relativeTimeString(from: project.lastModifiedAt)
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

    func relativeTimeString(from date: Date) -> String {
        let interval = date.timeIntervalSince(now())
        let isFuture = interval > 0
        let absoluteSeconds = Int(abs(interval))

        guard absoluteSeconds >= 60 else {
            return "just now"
        }

        let valueAndUnit: (Int, String)
        switch absoluteSeconds {
        case 31_536_000...:
            valueAndUnit = (absoluteSeconds / 31_536_000, "year")
        case 2_592_000...:
            valueAndUnit = (absoluteSeconds / 2_592_000, "month")
        case 86_400...:
            valueAndUnit = (absoluteSeconds / 86_400, "day")
        case 3_600...:
            valueAndUnit = (absoluteSeconds / 3_600, "hour")
        default:
            valueAndUnit = (absoluteSeconds / 60, "minute")
        }

        let (value, unit) = valueAndUnit
        let pluralizedUnit = value == 1 ? unit : unit + "s"
        return isFuture ? "in \(value) \(pluralizedUnit)" : "\(value) \(pluralizedUnit) ago"
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
