import Foundation

private extension String {
    var camelCased: String {
        var result = ""
        var capitalizeNext = false
        for c in self {
            if c == "_" {
                capitalizeNext = true
            } else {
                if capitalizeNext {
                    capitalizeNext = false
                    result.append(c.uppercased())
                } else {
                    result.append(c)
                }
            }
        }
        return result
    }
}

if CommandLine.arguments.count < 3 {
    print("Usage: SwiftTL path-to-scheme.tl path-to-output-folder [--stub-functions] [--print-constructors=N-M]")
    exit(0)
}

let schemeFilePath = CommandLine.arguments[1]
let outputDirectoryPath = CommandLine.arguments[2]

var stubFunctions = false
var printConstructorsRange: (start: Int, end: Int)? = nil
for arg in CommandLine.arguments {
    if arg == "--stub-functions" {
        stubFunctions = true
    }
    if arg.hasPrefix("--print-constructors=") {
        let value = String(arg.dropFirst("--print-constructors=".count))
        let parts = value.split(separator: "-")
        if parts.count == 2, let start = Int(parts[0]), let end = Int(parts[1]) {
            if start > end {
                print("Error: Invalid range for --print-constructors: start (\(start)) must be <= end (\(end))")
                exit(1)
            }
            printConstructorsRange = (start, end)
        } else {
            print("Error: Invalid format for --print-constructors. Expected: --print-constructors=N-M (e.g., --print-constructors=0-10)")
            exit(1)
        }
    }
}

guard let data = try? String(contentsOfFile: schemeFilePath) else {
    print("Could not open scheme file \(schemeFilePath)")
    exit(1)
}

do {    
    let parsedData = try DescriptionParser.parse(data: data)
    let resolvedTypes = try Resolver.resolveTypes(constructors: parsedData.constructors)
    var resolvedFunctions = try Resolver.resolveFunctions(types: resolvedTypes, functionDescriptions: parsedData.functions)
    
    resolvedFunctions.append(Resolver.Function(name: QualifiedName(namespace: "help", value: "test"), id: 0xc0e202f7, arguments: [], result: .boxedType(QualifiedName(namespace: nil, value: "Bool"))))
    
    var constructorOrder: [(typeName: QualifiedName, constructorName: String)] = []
    var typeOrder: [(types: [(typeName: QualifiedName, constructorNames: [String])], functions: [QualifiedName])] = []
    
    let sortedTypes = resolvedTypes.sorted(by: { $0.name < $1.name })

    if let range = printConstructorsRange {
        print("--- CONSTRUCTORS ---")
        for (index, type) in sortedTypes.enumerated() {
            if index >= range.start && index < range.end {
                for constructor in type.constructors.values.sorted(by: { $0.name < $1.name }) {
                    let storedArguments = constructor.arguments.filter {
                        if case .boolTrue = $0.type { return false }
                        return true
                    }
                    if !storedArguments.isEmpty {
                        let fieldNames = storedArguments.map { $0.name.camelCased }
                        print("\(constructor.name.value):\(fieldNames.joined(separator: ","))")
                    }
                }
            }
        }
        print("--- END CONSTRUCTORS ---")
        print("Total types: \(sortedTypes.count)")
        exit(0)
    }

    for type in sortedTypes {
        for constructor in type.constructors.values.sorted(by: { $0.name < $1.name }) {
            constructorOrder.append((type.name, constructor.name.value))
        }
    }
    
    var totalConstructorCount = 0
    var currentConstructorCount = 0
    for type in sortedTypes {
        if typeOrder.isEmpty || currentConstructorCount >= 32 {
            typeOrder.append(([], []))
            currentConstructorCount = 0
        }
        
        typeOrder[typeOrder.count - 1].types.append((type.name, type.constructors.values.sorted(by: { $0.name < $1.name }).map(\.name.value)))
        
        currentConstructorCount += type.constructors.count
        totalConstructorCount += type.constructors.count
        
        if totalConstructorCount > 40 {
        }
    }
    
    typeOrder.append(([], []))
    for function in resolvedFunctions.sorted(by: { $0.name < $1.name }) {
        typeOrder[typeOrder.count - 1].functions.append(function.name)
    }
    
    try FileManager.default.createDirectory(at: URL(fileURLWithPath: outputDirectoryPath), withIntermediateDirectories: true, attributes: nil)
    
    let generatedFiles = try CodeGenerator.generate(types: resolvedTypes, functions: resolvedFunctions, constructorOrder: constructorOrder, typeOrder: typeOrder, stubFunctions: stubFunctions)
    
    for (name, fileData) in generatedFiles {
        let filePath = URL(fileURLWithPath: outputDirectoryPath).appendingPathComponent(name).path
        let _ = try? FileManager.default.removeItem(atPath: filePath)
        try fileData.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
} catch let e {
    print("\(e)")
}
