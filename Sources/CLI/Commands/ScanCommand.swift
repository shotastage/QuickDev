//
//  ScanCommand.swift
//
//  Created by Shota Shimazu on 2026/04/03.
//

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

    mutating func run() throws {
        let fileManager = FileManager.default
        let support = ProjectIndexCommandSupport(fileManager: fileManager)
        let rootURL = support.resolvedRootURL(from: root)
        let scanner = ProjectScanner(fileManager: fileManager)
        let store = ProjectIndexStore(fileManager: fileManager)

        let index = try scanner.scan(rootURL: rootURL)
        let saveResult = try store.save(index)

        if json {
            print(try support.renderJSON(index))
            return
        }

        print("Scanned root: \(rootURL.path)")
        print("Projects found: \(index.projects.count)")
        print("Saved index: \(saveResult.indexFileURL.path)")

        guard index.projects.isEmpty == false else {
            return
        }

        print("")
        print(support.renderTable(for: index.projects))
    }
}
