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

        if force {
            print("Scan mode: full")
        }

        guard index.projects.isEmpty == false else {
            return
        }

        print("")
        print(support.renderTable(for: index.projects))
    }
}