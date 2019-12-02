import Ink
import Basic
import SPMUtility
import Foundation

// MARK: Constants
let MarkdownExtensions = ["markdown", "mdown", "mkdn", "md", "mkd", "mdwn", "mdtxt", "mdtext"]
let fileManager = FileManager()
let markdownEngine = MarkdownParser()

// MARK: Argument Parsing
let arguments = Array(CommandLine.arguments.dropFirst())

let parser = ArgumentParser(usage: "<file1> [<file2 [...]]", overview: "Convert one or more markdown files to html via Ink." )

let destinationPathArg: OptionArgument<String> = parser.add(option: "--destination", shortName: "-d", kind: String.self, usage: "Write output to <dir>.  Will duplicate hierarchy when --recursive is enabled.")
let directoryModeArg: OptionArgument<Bool> = parser.add(option: "--directory", shortName: "-D", kind: Bool.self, usage: "Treat argument(s) as directories, converting all files within.")
let overwriteModeArg: OptionArgument<Bool> = parser.add(option: "--overwrite", shortName: "-o", kind: Bool.self, usage: "Overwrite existing HTML files.")
let recursiveModeArg: OptionArgument<Bool> = parser.add(option: "--recursive", shortName: "-r", kind: Bool.self, usage: "When in --directory mode, recurse directories fully, conveting any markdown files found.")
let verboseModeArg: OptionArgument<Bool> = parser.add(option: "--verbose", shortName: "-v", kind: Bool.self, usage: "Enable verbose logging.")

let pathArguments:PositionalArgument<[String]> = parser.add(positional: "paths", kind: [String].self, optional: false, usage: "Paths to process")

let parsedArguments: ArgumentParser.Result
do {
    parsedArguments = try parser.parse(arguments)
}
catch {
    print("Error: \(error)", to: &stdoutStream)
    parser.printUsage(on: stdoutStream)
    exit(1)
}

// MARK: Global State
let directoryMode = parsedArguments.get(directoryModeArg) ?? false
let overwriteMode = parsedArguments.get(overwriteModeArg) ?? false
let recursiveMode = parsedArguments.get(recursiveModeArg) ?? false
let verboseMode = parsedArguments.get(verboseModeArg) ?? false


let destinationPath: Foundation.URL?
if let destinationPathRawValue = parsedArguments.get(destinationPathArg) {
    destinationPath = Foundation.URL(fileURLWithPath: destinationPathRawValue)
    guard destinationPath != nil else {
        print("Error: destination path could not be represented as an URL.")
        exit(1)
    }
    var isDir : ObjCBool = false
    guard fileManager.fileExists(atPath: destinationPath!.path, isDirectory: &isDir) else {
        print("Error: destination directory does not exist.")
        exit(1)
    }
    guard isDir.boolValue else {
        print("Error: destination path is not a directory.")
        exit(1)
    }
} else {
    destinationPath = nil
}

// MARK: Configuration Validation
struct PathError: Error {
    let path: Foundation.URL?
    let message: String
    let showUsage: Bool
    
    func printError() {
        if let path = path {
            print("Failed to process \(path): \(message)")
        } else {
            print("Error: \(message)")
        }
        
        if showUsage {
            parser.printUsage(on: stdoutStream)
        }
        exit(1)
    }
}

// MARK: Extensions
extension Foundation.URL {
    func relativePath(parent:Foundation.URL) -> String? {
        let parentABS = parent.path
        let selfABS = self.path
        
        if selfABS == parentABS {
            return selfABS
        }
        if (selfABS.hasPrefix(parentABS)) {
            return String(selfABS.dropFirst(parentABS.count + 1))
        } else {
            return nil
        }
    }
}

// MARK: Markdown processing via Ink
struct MarkdownFile {
    let directoryURL: Foundation.URL
    let relativePath: String
    
    func fileURL() -> Foundation.URL {
        return directoryURL.appendingPathComponent(relativePath, isDirectory: false)
    }
    
    func outputURL(relativeTo: Foundation.URL?, createIfNeeded: Bool) throws -> Foundation.URL  {
        var destinationURL: Foundation.URL
        if relativeTo != nil {
            destinationURL = relativeTo!
        } else {
            destinationURL = directoryURL
        }

        destinationURL.appendPathComponent(relativePath, isDirectory: false)
        destinationURL.deletePathExtension()
        destinationURL.appendPathExtension("html")
        
        if createIfNeeded {
            let destinationDirectoryURL = destinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        return destinationURL
    }
}

// MARK: Command line driver
func scanForMarkdownFiles(inDirectory: Foundation.URL) throws -> [MarkdownFile] {
    guard let directoryEnumerator = fileManager.enumerator(at: inDirectory, includingPropertiesForKeys: nil) else {
        throw PathError(path: inDirectory, message: "Failed to create enumerator for path.", showUsage: false)
    }
    var markdownFiles = [MarkdownFile]()
    while let file = directoryEnumerator.nextObject() as? Foundation.URL {
        if MarkdownExtensions.contains(file.pathExtension) {
            guard let relativcePath = file.relativePath(parent: inDirectory) else {
                throw PathError(path: file, message: "Somehow, path to file is not in \(inDirectory).", showUsage: false)
            }
            markdownFiles.append(MarkdownFile(directoryURL: inDirectory, relativePath: relativcePath))
        }
    }

    return markdownFiles
}

func findMarkdownFiles(onPaths: [String]) throws -> [MarkdownFile] {
    var markdownFiles = [MarkdownFile]()
    for path in onPaths {
        let pathURL = Foundation.URL(fileURLWithPath: path)
        var isDir : ObjCBool = false
        guard fileManager.fileExists(atPath: pathURL.path, isDirectory: &isDir) else {
            throw PathError(path: pathURL, message: "Path does not exist.", showUsage: false)
        }
        
        guard isDir.boolValue == directoryMode else {
            let msg = directoryMode ? "Path exists, but is file with directory mode enabled." : "Path exists, but is directory with file mode enabled."
            throw PathError(path: pathURL, message: msg, showUsage: false)
        }
        
        if directoryMode {
            try markdownFiles.append(contentsOf: scanForMarkdownFiles(inDirectory: pathURL))
        } else {
            let fileExt = pathURL.pathExtension
            guard MarkdownExtensions.contains(fileExt) else {
                throw PathError(path: pathURL, message: "Path does not have a markdown extension.", showUsage: false)
            }
            
            let directory = pathURL.deletingLastPathComponent()
            let mdFile = pathURL.lastPathComponent
             markdownFiles.append(MarkdownFile(directoryURL: directory, relativePath: mdFile))
        }
    }
    return markdownFiles
}

do {
    let validatedPaths: [MarkdownFile]
    guard let paths = parsedArguments.get(pathArguments) else {
        throw PathError(path: nil, message: "Requires at least one path argument.", showUsage: true)
    }
    validatedPaths = try findMarkdownFiles(onPaths: paths)
    for markdownFile in validatedPaths {
        let contents = try String(contentsOf: markdownFile.fileURL())
        let html = markdownEngine.html(from: contents)
        let destinationURL = try markdownFile.outputURL(relativeTo: destinationPath, createIfNeeded: destinationPath != nil)
        if !overwriteMode {
            guard !fileManager.fileExists(atPath: destinationURL.path, isDirectory: nil) else {
                throw PathError(path: destinationPath, message: "File already exists at path, but --overwrite mode not enabled.", showUsage: false)
            }
        }
        if verboseMode {
            print("Processing \(markdownFile.fileURL().path) -> \(destinationURL.path)")
        }
        try html.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
} catch let e as PathError {
    e.printError()
} catch {
    print("Error: \(error)")
}

