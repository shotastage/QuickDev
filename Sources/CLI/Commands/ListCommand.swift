import ArgumentParser
import Foundation
import QuickDev

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Display the cached project index, scanning only when no compatible index exists."
    )

    @Option(name: .long, help: "Root directory to list. Defaults to the cached index root, then ~/Developer.")
    var root: String?

    @Flag(name: .long, help: "Print the full project index as JSON.")
    var json: Bool = false

    mutating func run() throws {
        let fileManager = FileManager.default
        let support = ProjectIndexCommandSupport(fileManager: fileManager)
        let store = ProjectIndexStore(fileManager: fileManager)
        let requestedRootURL = root.map { support.resolvedRootURL(from: $0) }

        if let cachedIndex = try store.loadIndex(matchingRootPath: requestedRootURL?.path) {
            try printCachedIndex(cachedIndex, store: store, support: support)
            return
        }

        let rootURL = requestedRootURL ?? support.defaultRootURL
        let scanner = ProjectScanner(fileManager: fileManager)
        let index = try scanner.scan(rootURL: rootURL)
        let saveResult = try store.save(index)

        if json {
            print(try support.renderJSON(index))
            return
        }

        if let requestedRootURL {
            print("No cached index found for root: \(requestedRootURL.path)")
        } else {
            print("No cached index found. Performed a fresh scan.")
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

    private func printCachedIndex(
        _ index: ProjectIndex,
        store: ProjectIndexStore,
        support: ProjectIndexCommandSupport
    ) throws {
        if json {
            print(try support.renderJSON(index))
            return
        }

        print("Indexed root: \(index.rootPath)")
        print("Scanned at: \(support.iso8601String(from: index.scannedAt))")
        print("Projects found: \(index.projects.count)")
        print("Loaded index: \(store.indexFileURL.path)")

        guard index.projects.isEmpty == false else {
            return
        }

        print("")
        print(support.renderTable(for: index.projects))
    }
}
