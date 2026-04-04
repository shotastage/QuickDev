//
//  MainCLI.swift
//
//
//  Created by Shota Shimazu on 2026/04/03.
//

import ArgumentParser

#if os(macOS)

    @main
    struct MainCLI: ParsableCommand {
        static let configuration: CommandConfiguration = {
            CommandConfiguration(
                commandName: "qd",
                abstract: "QuickDev is a tool to quickly create and manage development packages.",
                version: "0.0.1",
                subcommands: [
                    ScanCommand.self,
                    ListCommand.self,
                ],
                defaultSubcommand: ScanCommand.self
            )
        }()
    }

#else

    @main
    enum MainCLI {
        static func main() {
            print("This tool is only supported on macOS.")
        }
    }

#endif
