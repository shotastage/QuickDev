//
//  SelfUpdateCommand.swift
//
//  Created by GitHub Copilot on 2026/04/05.
//

import ArgumentParser
import Foundation

struct SelfUpdateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "self-update",
        abstract: "Update qd by running the official installer script from GitHub."
    )

    @Option(name: .customLong("target-version"), help: "Git tag to install. Defaults to latest source from main.")
    var targetVersion: String = "latest"

    @Option(name: .long, help: "GitHub repository slug to update from.")
    var repo: String = "shotastage/QuickDev"

    @Option(name: .long, help: "Branch used when --version is not specified.")
    var branch: String = "main"

    @Option(name: .long, help: "Installation target directory for qd.")
    var installDir: String?

    @Flag(name: .long, help: "Only check and print available update metadata without installing.")
    var check: Bool = false

    @Flag(name: .long, help: "Skip confirmation prompt and run update immediately.")
    var yes: Bool = false

    mutating func run() throws {
        let currentVersion = quickDevCLIVersion

        if check {
            try runCheck(currentVersion: currentVersion)
            return
        }

        if yes == false {
            print("Current version: \(currentVersion)")
            print("Update source: \(repo) (version: \(targetVersion), branch: \(branch))")
            print("Proceed with self-update? [y/N]: ", terminator: "")

            guard let response = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                throw ValidationError("Update cancelled.")
            }

            if response != "y" && response != "yes" {
                throw ValidationError("Update cancelled.")
            }
        }

        try runInstaller()
        print("Self-update completed. Verify with: qd --help")
    }

    private func runCheck(currentVersion: String) throws {
        let scriptURL = installerScriptURL
        let result = try Shell.run("curl", arguments: ["-fsIL", scriptURL.absoluteString])

        if result.status != 0 {
            throw ValidationError("Could not reach installer URL: \(scriptURL.absoluteString)")
        }

        print("Current version: \(currentVersion)")
        do {
            let remoteVersion = try fetchRequestedRemoteVersion()
            let comparison = compareVersions(currentVersion: currentVersion, remoteVersion: remoteVersion)
            print("Remote version: \(remoteVersion)")
            print(comparison)
        } catch {
            print("Remote version: unavailable")
            print("Version comparison unavailable: could not read VERSION from source.")
        }

        if let installDir {
            print("Install dir override: \(installDir)")
        }
    }

    private func fetchRequestedRemoteVersion() throws -> String {
        let candidates = remoteVersionFileURLs

        for url in candidates {
            let result = try Shell.run("curl", arguments: ["-fsSL", url.absoluteString])
            if result.status != 0 {
                continue
            }

            let value = result.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if value.isEmpty == false {
                return value
            }
        }

        throw ValidationError("Could not read VERSION from the requested source.")
    }

    private func compareVersions(currentVersion: String, remoteVersion: String) -> String {
        guard
            let current = SemanticVersion(parsing: currentVersion),
            let remote = SemanticVersion(parsing: remoteVersion)
        else {
            return "Version comparison unavailable: non-semver format detected."
        }

        if remote > current {
            return "Update available."
        }

        if remote == current {
            return "Already up to date."
        }

        return "Installed version is newer than requested source."
    }

    /// Downloads the installer script and executes it in a temporary directory.
    private func runInstaller() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("quickdev-self-update", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempRoot)
        }

        let scriptPath = tempRoot.appendingPathComponent("installer.sh")
        let downloadResult = try Shell.run(
            "curl",
            arguments: ["-fsSL", installerScriptURL.absoluteString, "-o", scriptPath.path]
        )

        if downloadResult.status != 0 {
            let message = downloadResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ValidationError("Failed to download installer. \(message)")
        }

        let chmodResult = try Shell.run("chmod", arguments: ["+x", scriptPath.path])
        if chmodResult.status != 0 {
            let message = chmodResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ValidationError("Failed to set installer executable permission. \(message)")
        }

        var installerArguments = ["--version", targetVersion, "--repo", repo, "--branch", branch]
        if let installDir {
            installerArguments.append(contentsOf: ["--install-dir", installDir])
        }

        print("Running installer...")
        let installResult = try Shell.run("bash", arguments: [scriptPath.path] + installerArguments)

        if installResult.stdout.isEmpty == false {
            print(installResult.stdout, terminator: "")
        }

        if installResult.status != 0 {
            let message = installResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ValidationError("Self-update failed. \(message)")
        }

        if installResult.stderr.isEmpty == false {
            fputs(installResult.stderr, stderr)
        }
    }

    private var installerScriptURL: URL {
        URL(string: "https://raw.githubusercontent.com/\(repo)/\(branch)/Tools/installer.sh")!
    }

    private var remoteVersionFileURLs: [URL] {
        if targetVersion == "latest" {
            return [URL(string: "https://raw.githubusercontent.com/\(repo)/\(branch)/VERSION")!]
        }

        var refs = [targetVersion]
        if targetVersion.hasPrefix("v") {
            refs.append(String(targetVersion.dropFirst()))
        } else {
            refs.append("v\(targetVersion)")
        }

        return refs.map {
            URL(string: "https://raw.githubusercontent.com/\(repo)/\($0)/VERSION")!
        }
    }
}

private struct SemanticVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(parsing raw: String) {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = normalized.hasPrefix("v") ? String(normalized.dropFirst()) : normalized
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count == 3 else {
            return nil
        }

        guard
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2])
        else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}
