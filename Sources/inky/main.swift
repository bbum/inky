import Ink
import Basic
import SPMUtility

let arguments = Array(CommandLine.arguments.dropFirst())

let parser = ArgumentParser(usage: "<file1> [<file2 [...]]", overview: "Convert one or more markdown files to html via Ink." )

let destinationPath: OptionArgument<String> = parser.add(option: "--destination", shortName: "-d", kind: String.self, usage: "Write output to <dir>.  Will duplicate hierarchy when --recursive is enabled.")
let directoryMode: OptionArgument<Bool> = parser.add(option: "--directory", shortName: "-D", kind: Bool.self, usage: "Treat argument(s) as directories, converting all files within.")
let overwriteMode: OptionArgument<Bool> = parser.add(option: "--overwrite", shortName: "-o", kind: Bool.self, usage: "Overwrite existing HTML files.")
let recursiveMode: OptionArgument<Bool> = parser.add(option: "--recursive", shortName: "-r", kind: Bool.self, usage: "When in --directory mode, recurse directories fully, conveting any markdown files found.")

let parsedArguments: ArgumentParser.Result
do {
    parsedArguments = try parser.parse(arguments)
}
catch {
    print("Error: \(error)", to: &stdoutStream)
    parser.printUsage(on: stdoutStream)
}

