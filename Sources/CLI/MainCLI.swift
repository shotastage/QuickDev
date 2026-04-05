//
//  MainCLI.swift
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
                version: quickDevCLIVersion,
                subcommands: [
                    ScanCommand.self,
                    ListCommand.self,
                    OpenCommand.self,
                    SelfUpdateCommand.self,
                ],
                defaultSubcommand: ScanCommand.self
            )
        }()
    }

#else

    @main
    enum MainCLI {
        static func main() {
            print("unsupported platform: qd is currently supported only on macOS.")
        }
    }

#endif
