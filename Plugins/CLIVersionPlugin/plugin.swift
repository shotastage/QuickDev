import Foundation
import PackagePlugin

@main
struct CLIVersionPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard target.name == "CLI" else {
            return []
        }

        let scriptPath = context.package.directoryURL.appending(path: "Tools/generate-cli-version-source.sh")
        let versionFilePath = context.package.directoryURL.appending(path: "VERSION")
        let outputDirectory = context.pluginWorkDirectoryURL.appending(path: "Generated")

        return [
            .prebuildCommand(
                displayName: "Generate CLI version source from VERSION",
                executable: URL(filePath: "/bin/bash"),
                arguments: [
                    scriptPath.path(percentEncoded: false),
                    versionFilePath.path(percentEncoded: false),
                    outputDirectory.path(percentEncoded: false),
                ],
                outputFilesDirectory: outputDirectory
            )
        ]
    }
}
