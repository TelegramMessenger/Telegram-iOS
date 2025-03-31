import Foundation
import Darwin
import XcodeProj
import PathKit
import ArgumentParser

// Custom error types for the command
enum XcodeParseError: Error, LocalizedError {
    case missingBuildSetting(String)
    case unresolvableBuildSetting(String, String)
    case swiftFlagProcessingError(String, Error)
    case unresolvableSwiftFlag(String, String)
    
    var errorDescription: String? {
        switch self {
        case .missingBuildSetting(let setting):
            return "Project does not contain required build setting: \(setting)"
        case .unresolvableBuildSetting(let name, let value):
            return "Could not resolve build setting value: \(name) = \(value)"
        case .swiftFlagProcessingError(let target, let error):
            return "Error processing swift flags for \(target): \(error)"
        case .unresolvableSwiftFlag(let target, let flag):
            return "Unresolved variable in swift flags for \(target): \(flag)"
        }
    }
}

struct XcodeParse: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xcodeparse",
        abstract: "Extract file sets and Swift flags from an Xcode project",
        version: "1.0.0"
    )

    // Extract all variable references like $(VARIABLE_NAME)
    // private static let variablePatternRegex = try! NSRegularExpression(pattern: "\\$\\(([^)]+)\\)", options: [])
    
    // Update the class-level regex to handle simple variables
    private static let simpleVariableRegex = try! NSRegularExpression(pattern: "\\$\\(([^$)]+)\\)", options: [])
    
    // Add another regex for variables that contain exactly one nested variable
    private static let nestedVariableRegex = try! NSRegularExpression(pattern: "\\$\\(([^$)]*\\$\\([^)]+\\)[^)]*)\\)", options: [])
    
    @Option(name: .shortAndLong, help: "Path to the Xcode project (.xcodeproj) file")
    var projectPath: String
    
    @Option(name: .shortAndLong, help: "Output path for the JSON file")
    var outputPath: String
    
    func run() throws {
        let projectPathObj = Path(projectPath)
        
        let xcodeproj = try XcodeProj(path: projectPathObj)

        func absolutePath(file: PBXFileElement) -> String? {
            guard let path = file.path else {
                return nil
            }
            if let parent = file.parent {
                if let parentPath = absolutePath(file: parent) {
                    return parentPath + "/" + path
                } else {
                    return path
                }
            } else {
                return path
            }
        }

        func localPath(projectRoot: String, file: PBXFileElement) -> String? {
            guard let path = absolutePath(file: file) else {
                return nil
            }
            if path.hasPrefix(projectRoot) {
                return String(path[path.index(path.startIndex, offsetBy: projectRoot.count)...])
            } else {
                return path
            }
        }

        var rawVariables: [String: String] = [:]
        let requiredBuildSettings: [String] = ["SRCROOT", "PROJECT_DIR", "BAZEL_OUT"]
        for buildConfiguration in xcodeproj.pbxproj.buildConfigurations {
            if buildConfiguration.name == "Debug" {
                for name in requiredBuildSettings {
                    if let value = buildConfiguration.buildSettings[name]?.stringValue {
                        rawVariables[name] = value
                    }
                }
            }
        }
        
        for name in requiredBuildSettings {
            if rawVariables[name] == nil {
                throw XcodeParseError.missingBuildSetting(name)
            }
        }

        while true {
            var hasSubstitutions: Bool = false
            inner: for (name, value) in rawVariables {
                for (otherName, otherValue) in rawVariables {
                    if name == otherName {
                        continue
                    }
                    if value.contains("$(\(otherName))") {
                        rawVariables[name] = value.replacingOccurrences(of: "$(\(otherName))", with: otherValue)
                        hasSubstitutions = true
                        break inner
                    }
                }
            }
            if !hasSubstitutions {
                break
            }
        }
        
        for (name, value) in rawVariables {
            if value.contains("$(") {
                throw XcodeParseError.unresolvableBuildSetting(name, value)
            }
        }

        rawVariables["ENABLE_PREVIEWS"] = ""

        let variables = rawVariables

        let projectRoot = variables["SRCROOT"]! + "/"

        enum ShlexError: Error {
            case unmatchedQuote
        }

        func shlexSplit(_ input: String) throws -> [String] {
            var tokens = [String]()
            var current = ""
            var inSingleQuote = false
            var inDoubleQuote = false
            var escapeNext = false

            for char in input {
                if escapeNext {
                    current.append(char)
                    escapeNext = false
                    continue
                }
                
                if char == "\\" {
                    // In single quotes, backslashes are taken literally.
                    if inSingleQuote {
                        current.append(char)
                    } else {
                        escapeNext = true
                    }
                } else if char == "'" && !inDoubleQuote {
                    inSingleQuote.toggle()
                } else if char == "\"" && !inSingleQuote {
                    inDoubleQuote.toggle()
                } else if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                } else {
                    current.append(char)
                }
            }
            
            if escapeNext {
                // A trailing backslash is taken as a literal backslash.
                current.append("\\")
            }
            
            if inSingleQuote || inDoubleQuote {
                throw ShlexError.unmatchedQuote
            }
            
            if !current.isEmpty {
                tokens.append(current)
            }
            
            return tokens
        }

        struct FileSet {
            var files: [String]
            var swiftFlags: [String]
        }

        var fileSets: [FileSet] = []

        for target in xcodeproj.pbxproj.nativeTargets {
            var files: [String] = []
            for sourceFile in try target.sourceFiles() {
                if let path = localPath(projectRoot: projectRoot, file: sourceFile) {
                    files.append(path)
                }
            }
            
            var swiftFlags: [String] = []
            if let buildConfigurationList = target.buildConfigurationList {
                for buildConfiguration in buildConfigurationList.buildConfigurations {
                    if buildConfiguration.name == "Debug" {
                        if let swiftFlagsString = buildConfiguration.buildSettings["OTHER_SWIFT_FLAGS[sdk=iphonesimulator*]"]?.stringValue {
                            do {
                                swiftFlags = try shlexSplit(swiftFlagsString)
                            } catch let error {
                                throw XcodeParseError.swiftFlagProcessingError(target.name, error)
                            }
                        }
                        
                        for i in 0 ..< swiftFlags.count {
                            if swiftFlags[i].contains("$(") {
                                var flag = swiftFlags[i]
                                var madeProgress = true
                                
                                // Keep resolving variables until no more progress can be made
                                while flag.contains("$(") && madeProgress {
                                    madeProgress = false
                                    
                                    let nsString = flag as NSString
                                    let matches = XcodeParse.simpleVariableRegex.matches(in: flag, options: [], range: NSRange(location: 0, length: nsString.length))
                                    
                                    // Try to resolve variables that don't contain other variables
                                    for match in matches.reversed() {
                                        let variableRange = match.range(at: 1)
                                        let variableName = nsString.substring(with: variableRange)
                                        
                                        // Skip this variable if it contains another variable reference
                                        // (we'll get it in a later iteration after inner variables are resolved)
                                        if variableName.contains("$(") {
                                            continue
                                        }
                                        
                                        // Look up the variable directly by name
                                        var variableValue: String? = variables[variableName]
                                        
                                        // If not found in variables, check build settings
                                        if variableValue == nil, let value = buildConfiguration.buildSettings[variableName]?.stringValue {
                                            variableValue = value
                                        }
                                        
                                        // If variable found, do the replacement
                                        if let value = variableValue {
                                            let fullRange = match.range(at: 0) // The full $(VARIABLE_NAME) pattern
                                            flag = (flag as NSString).replacingCharacters(in: fullRange, with: value)
                                            madeProgress = true
                                        }
                                    }
                                }
                                
                                // Check if there are still unresolved variables
                                if flag.contains("$(") {
                                    throw XcodeParseError.unresolvableSwiftFlag(target.name, flag)
                                }
                                
                                swiftFlags[i] = flag
                            }
                        }
                    }
                }
            }
            
            if !files.isEmpty && !swiftFlags.isEmpty {
                fileSets.append(FileSet(
                    files: files,
                    swiftFlags: swiftFlags
                ))
            }
        }

        do {
            let fileSetDicts = fileSets.map { fileSet -> [String: Any] in
                return [
                    "files": fileSet.files,
                    "swiftFlags": fileSet.swiftFlags
                ]
            }
            let jsonData = try JSONSerialization.data(withJSONObject: fileSetDicts, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: outputPath))
            print("Successfully wrote output to \(outputPath)")
        } catch let error {
            throw error
        }
    }
}

XcodeParse.main()
