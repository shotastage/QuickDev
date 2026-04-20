//
//  GitInspector.swift
//
//  Created by Shota Shimazu on 2026/04/03.
//

import Foundation

struct GitInspectionResult: Equatable, Sendable {
    let remoteURL: String?
    let hasUncommittedChanges: Bool?
    let headCommit: String?
    let branch: String?

    init(
        remoteURL: String?,
        hasUncommittedChanges: Bool?,
        headCommit: String? = nil,
        branch: String? = nil
    ) {
        self.remoteURL = remoteURL
        self.hasUncommittedChanges = hasUncommittedChanges
        self.headCommit = headCommit
        self.branch = branch
    }
}

public struct GitInspector {
    public init() {}
}

extension GitInspector: GitInspecting {
    func inspect(directoryURL: URL) -> GitInspectionResult {
        let remoteURL = trimmedStdout(
            for: ["-C", directoryURL.path, "remote", "get-url", "origin"]
        )
        let headCommit = trimmedStdout(
            for: ["-C", directoryURL.path, "rev-parse", "HEAD"]
        )
        let branch = trimmedStdout(
            for: ["-C", directoryURL.path, "rev-parse", "--abbrev-ref", "HEAD"]
        )

        let dirtyResult = runGit(arguments: ["-C", directoryURL.path, "status", "--porcelain"])
        let hasUncommittedChanges: Bool?

        if let dirtyResult, dirtyResult.status == 0 {
            hasUncommittedChanges = dirtyResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        } else {
            hasUncommittedChanges = nil
        }

        return GitInspectionResult(
            remoteURL: remoteURL,
            hasUncommittedChanges: hasUncommittedChanges,
            headCommit: headCommit,
            branch: branch
        )
    }

    private func trimmedStdout(for arguments: [String]) -> String? {
        guard let result = runGit(arguments: arguments), result.status == 0 else {
            return nil
        }

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }

    private func runGit(arguments: [String]) -> GitProcessResult? {
        do {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["git"] + arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            guard
                let stdout = String(data: stdoutData, encoding: .utf8),
                let stderr = String(data: stderrData, encoding: .utf8)
            else {
                return nil
            }

            return GitProcessResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
        } catch {
            return nil
        }
    }
}

private struct GitProcessResult {
    let status: Int32
    let stdout: String
    let stderr: String
}
