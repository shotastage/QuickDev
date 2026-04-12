//
//  TransferCommand.swift
//
//  Created by Codex on 2026/04/12.
//

import ArgumentParser
import Foundation
import QuickDev
import SwiftCLIKit

struct TransferCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transfer",
        abstract: "Move an existing directory into ~/Developer and refresh the project index."
    )

    @Argument(help: "Directory path to move into ~/Developer.")
    var directoryPath: String

    mutating func run() throws {
        let fileManager = FileManager.default
        let homeDirectoryURL = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
        let support = ProjectIndexCommandSupport(fileManager: fileManager)
        let classifier = ProjectClassifier(fileManager: fileManager)
        let scanner = ProjectScanner(fileManager: fileManager)
        let store = ProjectIndexStore(fileManager: fileManager)

        do {
            let sourceDirectoryURL = try TransferCommandSupport.resolveSourceDirectoryURL(
                from: directoryPath,
                fileManager: fileManager
            )

            let destinationDirectoryURL = try TransferCommandSupport.buildTransferDestinationPath(
                for: sourceDirectoryURL,
                fileManager: fileManager,
                homeDirectoryURL: homeDirectoryURL
            )

            if try classifier.isLikelyProject(directoryURL: sourceDirectoryURL) == false {
                let shouldContinue = confirmTransferForNonProject(directoryURL: sourceDirectoryURL)
                guard shouldContinue else {
                    print("Transfer cancelled.")
                    return
                }
            }

            try moveDirectory(
                from: sourceDirectoryURL,
                to: destinationDirectoryURL,
                fileManager: fileManager
            )

            let rootURL = support.defaultRootURL
            let index = try scanner.scan(rootURL: rootURL)
            let saveResult = try store.save(index)

            let sourcePath = TransferCommandSupport.displayPath(sourceDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            let destinationPath = TransferCommandSupport.displayPath(
                destinationDirectoryURL,
                homeDirectoryURL: homeDirectoryURL
            )

            print("Transferred: \(sourcePath)")
            print("Destination: \(destinationPath)")
            print("Scanned root: \(rootURL.path)")
            print("Projects found: \(index.projects.count)")
            print("Saved index: \(saveResult.indexFileURL.path)")
        } catch let error as TransferCommandError {
            printFailureMessage(for: error, homeDirectoryURL: homeDirectoryURL)
            throw ExitCode.failure
        }
    }

    // MARK: - User Confirmation

    /// Prompts the user when a directory does not match known project markers.
    /// - Parameter directoryURL: Candidate source directory supplied to `transfer`.
    /// - Returns: `true` when the user confirms transfer should continue.
    private func confirmTransferForNonProject(directoryURL: URL) -> Bool {
        print("Directory '\(directoryURL.path)' does not look like a known project.")
        return ConfirmationPrompt.ask(prompt: "Transfer anyway to ~/Developer? [y/N]: ")
    }

    // MARK: - Filesystem Operations

    /// Moves a directory on disk, translating filesystem failures into deterministic CLI errors.
    /// - Parameters:
    ///   - sourceDirectoryURL: Existing directory chosen by the user.
    ///   - destinationDirectoryURL: Target location under `~/Developer`.
    ///   - fileManager: File manager used for filesystem operations.
    /// - Throws: `TransferCommandError.failedToMoveDirectory` when move fails.
    private func moveDirectory(from sourceDirectoryURL: URL, to destinationDirectoryURL: URL, fileManager: FileManager)
        throws
    {
        do {
            try fileManager.moveItem(at: sourceDirectoryURL, to: destinationDirectoryURL)
        } catch {
            throw TransferCommandError.failedToMoveDirectory(
                source: sourceDirectoryURL,
                destination: destinationDirectoryURL
            )
        }
    }

    // MARK: - Messaging

    private func printFailureMessage(for error: TransferCommandError, homeDirectoryURL: URL) {
        switch error {
        case .emptyDirectoryPath:
            printUserMessage("Directory path is required.", isError: true)
        case .sourceDirectoryDoesNotExist(let sourceDirectoryURL):
            let displayPath = TransferCommandSupport.displayPath(sourceDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Directory does not exist: \(displayPath)", isError: true)
        case .sourcePathIsNotDirectory(let sourceURL):
            let displayPath = TransferCommandSupport.displayPath(sourceURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Path is not a directory: \(displayPath)", isError: true)
        case .sourceAlreadyInDeveloperRoot(let sourceDirectoryURL):
            let displayPath = TransferCommandSupport.displayPath(sourceDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Directory is already inside ~/Developer: \(displayPath)", isError: true)
        case .sourceContainsDestination(let sourceDirectoryURL):
            let displayPath = TransferCommandSupport.displayPath(sourceDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Refusing to move \(displayPath) into one of its descendants.", isError: true)
        case .failedToCreateDeveloperDirectory(let developerRootURL):
            let displayPath = TransferCommandSupport.displayPath(developerRootURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Failed to create destination root: \(displayPath)", isError: true)
        case .targetDirectoryAlreadyExists(let targetDirectoryURL):
            let displayPath = TransferCommandSupport.displayPath(targetDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Target directory already exists: \(displayPath)", isError: true)
        case .failedToMoveDirectory(let sourceDirectoryURL, let destinationDirectoryURL):
            let sourcePath = TransferCommandSupport.displayPath(sourceDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            let destinationPath = TransferCommandSupport.displayPath(destinationDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Failed to move \(sourcePath) to \(destinationPath).", isError: true)
        }
    }

    /// Prints user-facing messages to stdout or stderr.
    private func printUserMessage(_ message: String, isError: Bool = false) {
        if isError {
            fputs("\(message)\n", stderr)
            return
        }

        print(message)
    }
}

enum TransferCommandSupport {
    /// Resolves and validates the source directory path supplied to the transfer command.
    /// - Parameters:
    ///   - directoryPath: User-provided path, absolute, relative, or `~`-expanded.
    ///   - fileManager: File manager used for validation and relative path resolution.
    /// - Returns: Standardized absolute URL of the source directory.
    /// - Throws: `TransferCommandError.emptyDirectoryPath`, `.sourceDirectoryDoesNotExist`, or `.sourcePathIsNotDirectory`.
    static func resolveSourceDirectoryURL(from directoryPath: String, fileManager: FileManager) throws -> URL {
        let trimmedPath = directoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.isEmpty == false else {
            throw TransferCommandError.emptyDirectoryPath
        }

        let expandedPath = NSString(string: trimmedPath).expandingTildeInPath
        let sourceDirectoryURL: URL

        if expandedPath.hasPrefix("/") {
            sourceDirectoryURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        } else {
            sourceDirectoryURL = URL(
                fileURLWithPath: expandedPath,
                relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
            )
        }

        let normalizedURL = sourceDirectoryURL.standardizedFileURL
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: normalizedURL.path, isDirectory: &isDirectory) else {
            throw TransferCommandError.sourceDirectoryDoesNotExist(normalizedURL)
        }

        guard isDirectory.boolValue else {
            throw TransferCommandError.sourcePathIsNotDirectory(normalizedURL)
        }

        return normalizedURL
    }

    /// Builds a safe destination path under `~/Developer`.
    /// - Parameters:
    ///   - sourceDirectoryURL: Existing directory to transfer.
    ///   - fileManager: File manager used to create and validate destination directories.
    ///   - homeDirectoryURL: Home directory used to derive the `~/Developer` root.
    /// - Returns: Destination directory URL under `~/Developer`.
    /// - Throws: `TransferCommandError` when source/destination invariants are unsafe.
    static func buildTransferDestinationPath(for sourceDirectoryURL: URL, fileManager: FileManager, homeDirectoryURL: URL)
        throws -> URL
    {
        let developerRootURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .standardizedFileURL

        if sourceDirectoryURL.path == developerRootURL.path || sourceDirectoryURL.path.hasPrefix(developerRootURL.path + "/") {
            throw TransferCommandError.sourceAlreadyInDeveloperRoot(sourceDirectoryURL)
        }

        do {
            try fileManager.createDirectory(at: developerRootURL, withIntermediateDirectories: true)
        } catch {
            throw TransferCommandError.failedToCreateDeveloperDirectory(developerRootURL)
        }

        let destinationDirectoryURL = developerRootURL
            .appendingPathComponent(sourceDirectoryURL.lastPathComponent, isDirectory: true)
            .standardizedFileURL

        if destinationDirectoryURL.path == sourceDirectoryURL.path {
            throw TransferCommandError.sourceAlreadyInDeveloperRoot(sourceDirectoryURL)
        }

        if destinationDirectoryURL.path.hasPrefix(sourceDirectoryURL.path + "/") {
            throw TransferCommandError.sourceContainsDestination(sourceDirectoryURL)
        }

        guard fileManager.fileExists(atPath: destinationDirectoryURL.path) == false else {
            throw TransferCommandError.targetDirectoryAlreadyExists(destinationDirectoryURL)
        }

        return destinationDirectoryURL
    }

    /// Converts an absolute path to a `~`-prefixed path when it is inside the home directory.
    static func displayPath(_ url: URL, homeDirectoryURL: URL) -> String {
        let standardizedPath = url.standardizedFileURL.path
        let homePath = homeDirectoryURL.standardizedFileURL.path

        if standardizedPath == homePath {
            return "~"
        }

        if standardizedPath.hasPrefix(homePath + "/") {
            let relativePath = String(standardizedPath.dropFirst(homePath.count))
            return "~\(relativePath)"
        }

        return standardizedPath
    }
}

enum TransferCommandError: Error, Equatable {
    case emptyDirectoryPath
    case sourceDirectoryDoesNotExist(URL)
    case sourcePathIsNotDirectory(URL)
    case sourceAlreadyInDeveloperRoot(URL)
    case sourceContainsDestination(URL)
    case failedToCreateDeveloperDirectory(URL)
    case targetDirectoryAlreadyExists(URL)
    case failedToMoveDirectory(source: URL, destination: URL)
}
