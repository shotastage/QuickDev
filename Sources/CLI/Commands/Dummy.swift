//
//  Create.swift
//
//
//  Created by Shota Shimazu on 2026/04/03.
//

import ArgumentParser
import Foundation

struct Dummy: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Dummy command for testing purposes."
    )

    func run() throws {
        do {
            try Shell.run("echo Hello, World!")
        } catch {
            print("Some command has been finished in fail.")
        }
    }
}
