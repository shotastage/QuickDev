//
//  CloneCommand.swift
//
//  Created by Codex on 2026/04/08.
//

import ArgumentParser
import Foundation

struct CloneCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clone",
        abstract: "Clone a Git repository into ~/Developer regardless of the current directory."
    )

    @Argument(help: "Git repository URL (HTTPS or SSH).")
    var repositoryURL: String

    mutating func run() throws {
        let fileManager = FileManager.default
        let homeDirectoryURL = fileManager.homeDirectoryForCurrentUser

        do {
            let repositoryName = try CloneCommandSupport.extractRepositoryName(from: repositoryURL)
            let targetDirectoryURL = try CloneCommandSupport.buildCloneTargetPath(
                for: repositoryName,
                fileManager: fileManager,
                homeDirectoryURL: homeDirectoryURL
            )

            try executeClone(repositoryURL: repositoryURL, targetDirectoryURL: targetDirectoryURL)
            let displayPath = CloneCommandSupport.displayPath(targetDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Cloned to \(displayPath)")
        } catch let error as CloneCommandError {
            printFailureMessage(for: error, homeDirectoryURL: homeDirectoryURL)
            throw ExitCode.failure
        }
    }

    // MARK: - Clone Execution

    /// Executes `/usr/bin/git clone <url> <target path>` and validates the exit status.
    /// - Parameters:
    ///   - repositoryURL: Git repository URL provided by the user.
    ///   - targetDirectoryURL: Absolute destination path under `~/Developer`.
    /// - Throws: `CloneCommandError.failedToRunGit` if process launch fails, or
    ///   `CloneCommandError.cloneFailed` when git returns a non-zero status.
    private func executeClone(repositoryURL: String, targetDirectoryURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["clone", repositoryURL, targetDirectoryURL.path]

        do {
            try process.run()
        } catch {
            throw CloneCommandError.failedToRunGit
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CloneCommandError.cloneFailed(status: process.terminationStatus)
        }
    }

    // MARK: - Messaging

    /// Prints user-facing messages to stdout or stderr.
    private func printUserMessage(_ message: String, isError: Bool = false) {
        if isError {
            fputs("\(message)\n", stderr)
            return
        }

        print(message)
    }

    private func printFailureMessage(for error: CloneCommandError, homeDirectoryURL: URL) {
        switch error {
        case .invalidRepositoryURL:
            printUserMessage("Invalid repository URL", isError: true)
        case .failedToCreateDeveloperDirectory(let directoryURL):
            let displayPath = CloneCommandSupport.displayPath(directoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Failed to create \(displayPath)", isError: true)
        case .targetDirectoryAlreadyExists(let targetDirectoryURL):
            let displayPath = CloneCommandSupport.displayPath(targetDirectoryURL, homeDirectoryURL: homeDirectoryURL)
            printUserMessage("Target directory already exists", isError: true)
            printUserMessage("Repository already exists at \(displayPath)", isError: true)
        case .failedToRunGit:
            printUserMessage("Failed to run git", isError: true)
        case .cloneFailed(let status):
            printUserMessage("Clone failed", isError: true)
            printUserMessage("git exited with status \(status)", isError: true)
        }
    }
}

enum CloneCommandSupport {
    /// Extracts a repository name from a Git URL and removes an optional `.git` suffix.
    /// - Parameter repositoryURL: Git URL in HTTPS or SSH form.
    /// - Returns: Repository directory name.
    /// - Throws: `CloneCommandError.invalidRepositoryURL` when extraction fails.
    static func extractRepositoryName(from repositoryURL: String) throws -> String {
        let trimmedURL = repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURL.isEmpty == false else {
            throw CloneCommandError.invalidRepositoryURL
        }

        guard let path = repositoryPathComponent(from: trimmedURL) else {
            throw CloneCommandError.invalidRepositoryURL
        }

        guard var repositoryName = path
            .split(separator: "/", omittingEmptySubsequences: true)
            .last
            .map(String.init)
        else {
            throw CloneCommandError.invalidRepositoryURL
        }

        if repositoryName.hasSuffix(".git") {
            repositoryName.removeLast(4)
        }

        repositoryName = repositoryName.removingPercentEncoding ?? repositoryName
        repositoryName = repositoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard repositoryName.isEmpty == false, repositoryName != ".", repositoryName != ".." else {
            throw CloneCommandError.invalidRepositoryURL
        }

        return repositoryName
    }

    /// Builds a clone destination path under `~/Developer`, creating the root if needed.
    /// - Parameters:
    ///   - repositoryName: Parsed repository name.
    ///   - fileManager: File manager used for filesystem operations.
    ///   - homeDirectoryURL: Home directory used to resolve `~/Developer`.
    /// - Returns: Absolute clone destination URL under `~/Developer`.
    /// - Throws: `CloneCommandError.failedToCreateDeveloperDirectory` or
    ///   `CloneCommandError.targetDirectoryAlreadyExists`.
    static func buildCloneTargetPath(
        for repositoryName: String,
        fileManager: FileManager,
        homeDirectoryURL: URL
    ) throws -> URL {
        let developerRootURL = homeDirectoryURL
            .appendingPathComponent("Developer", isDirectory: true)
            .standardizedFileURL

        do {
            try fileManager.createDirectory(at: developerRootURL, withIntermediateDirectories: true)
        } catch {
            throw CloneCommandError.failedToCreateDeveloperDirectory(developerRootURL)
        }

        let targetDirectoryURL = developerRootURL
            .appendingPathComponent(repositoryName, isDirectory: true)
            .standardizedFileURL

        guard fileManager.fileExists(atPath: targetDirectoryURL.path) == false else {
            throw CloneCommandError.targetDirectoryAlreadyExists(targetDirectoryURL)
        }

        return targetDirectoryURL
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

    private static func repositoryPathComponent(from repositoryURL: String) -> String? {
        if repositoryURL.contains("://") {
            return URLComponents(string: repositoryURL)?.path
        }

        let components = repositoryURL.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard
            repositoryURL.contains("@"),
            components.count == 2
        else {
            return nil
        }

        return String(components[1])
    }
}

enum CloneCommandError: Error, Equatable {
    case invalidRepositoryURL
    case failedToCreateDeveloperDirectory(URL)
    case targetDirectoryAlreadyExists(URL)
    case failedToRunGit
    case cloneFailed(status: Int32)
}
