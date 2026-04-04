//
//  Shell.swift
//
//  Created by Shota Shimazu on 2026/04/03.
//

import Foundation

enum ShellError: Error {
    case unsupportedPlatform
    case invalidUTF8Output
}

struct ShellResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

enum Shell {
    static func run(
        _ executable: String,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil
    ) throws -> ShellResult {
        #if os(iOS) || os(watchOS) || os(tvOS)
            throw ShellError.unsupportedPlatform
        #else
            let task = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = [executable] + arguments
            task.currentDirectoryURL = currentDirectoryURL
            task.environment = environment
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe

            try task.run()
            task.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            guard
                let stdout = String(data: stdoutData, encoding: .utf8),
                let stderr = String(data: stderrData, encoding: .utf8)
            else {
                throw ShellError.invalidUTF8Output
            }

            return ShellResult(
                status: task.terminationStatus,
                stdout: stdout,
                stderr: stderr
            )
        #endif
    }

    static func runInShell(
        _ command: String,
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil
    ) throws -> ShellResult {
        try run(
            "zsh",
            arguments: ["-lc", command],
            currentDirectoryURL: currentDirectoryURL,
            environment: environment
        )
    }
}
