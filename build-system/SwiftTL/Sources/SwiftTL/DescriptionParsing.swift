import Foundation

enum DescriptionParser {
    enum ParsedSchema {
        case flat(constructors: [ConstructorDescription], functions: [ConstructorDescription])
        case layered(layers: [(layerNumber: Int, constructors: [ConstructorDescription])])
    }

    struct SchemaParsingError: Error, CustomStringConvertible {
        var text: String
        var description: String { text }
    }

    private static let skipPrefixes: [String] = [
        "true#3fedd339 = True;",
        "vector#1cb5c415 {t:Type} # [ t ] = Vector t;",
        "error#c4b9f9bb code:int text:string = Error;",
        "null#56730bcc = Null;"
    ]
    private static let skipContains: [String] = ["{X:Type}"]

    private static func shouldSkipLine(_ line: String) -> Bool {
        skipPrefixes.contains { line.hasPrefix($0) } ||
        skipContains.contains { line.contains($0) }
    }

    enum TypeReferenceDescription {
        case generic(name: String, argumentType: QualifiedName)
        case type(name: QualifiedName)
    }
    
    struct ArgumentDescription {
        struct ConditionDescription {
            var fieldName: String
            var bitIndex: Int
        }
        
        var name: String
        var type: TypeReferenceDescription
        var condition: ConditionDescription?
    }
    
    struct ConstructorDescription {
        var name: QualifiedName
        var explicitId: UInt32?
        var arguments: [ArgumentDescription]
        var type: TypeReferenceDescription
    }
    
    static func parse(data: String) throws -> ParsedSchema {
        let lines = data.components(separatedBy: "\n")

        // Single compiled regex used for both detection and layer-number extraction.
        let layerMarker = try NSRegularExpression(pattern: "^===(\\d+)===\\s*$")
        let hasLayerMarker = lines.contains { line in
            let range = NSRange(line.startIndex..., in: line)
            return layerMarker.firstMatch(in: line, range: range) != nil
        }

        if hasLayerMarker {
            return try parseLayered(lines: lines, layerMarker: layerMarker)
        } else {
            return try parseFlat(lines: lines)
        }
    }

    private static func parseFlat(lines: [String]) throws -> ParsedSchema {
        var typeLines: [String] = []
        var functionLines: [String] = []

        var isParsingFunctions = false
        for line in lines {
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                continue
            } else if line == "---functions---" {
                isParsingFunctions = true
            } else {
                if shouldSkipLine(line) { continue }
                if isParsingFunctions {
                    functionLines.append(line)
                } else {
                    typeLines.append(line)
                }
            }
        }

        var constructors: [ConstructorDescription] = []
        var functions: [ConstructorDescription] = []

        for line in typeLines {
            do {
                constructors.append(try parseConstructor(string: line))
            } catch let e {
                print("Error while parsing line:\n\(line)\n")
                print("\(e)")
                throw e
            }
        }
        for line in functionLines {
            do {
                functions.append(try parseConstructor(string: line))
            } catch let e {
                print("Error while parsing line:\n\(line)\n")
                print("\(e)")
                throw e
            }
        }

        return .flat(constructors: constructors, functions: functions)
    }

    private static func parseLayered(lines: [String], layerMarker: NSRegularExpression) throws -> ParsedSchema {
        // Pre-marker constructor lines accumulate here and are attached to the first declared layer.
        var preMarkerLines: [String] = []
        var sections: [(layerNumber: Int, lines: [String])] = []
        var lastLayerNumber: Int? = nil

        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if line == "---functions---" {
                throw SchemaParsingError(text: "Layered schemas may not declare ---functions---; secret/layered schemas are types-only.")
            }

            let range = NSRange(line.startIndex..., in: line)
            if let match = layerMarker.firstMatch(in: line, range: range),
               let numberRange = Range(match.range(at: 1), in: line),
               let layerNumber = Int(line[numberRange])
            {
                if let previous = lastLayerNumber, layerNumber <= previous {
                    throw SchemaParsingError(text: "Layer markers must appear in strictly ascending order; found ===\(layerNumber)=== after ===\(previous)===.")
                }
                sections.append((layerNumber, []))
                lastLayerNumber = layerNumber
                continue
            }

            // Apply the same skip rules as flat mode.
            if shouldSkipLine(line) { continue }

            if sections.isEmpty {
                preMarkerLines.append(line)
            } else {
                sections[sections.count - 1].lines.append(line)
            }
        }

        if sections.isEmpty {
            throw SchemaParsingError(text: "Layered schema has a layer marker regex match but no ===N=== sections were extracted; this indicates a parser bug.")
        }

        // Attach pre-marker lines to the first (lowest) declared layer.
        if !preMarkerLines.isEmpty {
            sections[0].lines.insert(contentsOf: preMarkerLines, at: 0)
        }

        var layers: [(layerNumber: Int, constructors: [ConstructorDescription])] = []
        for (layerNumber, sectionLines) in sections {
            var constructors: [ConstructorDescription] = []
            for line in sectionLines {
                do {
                    constructors.append(try parseConstructor(string: line))
                } catch let e {
                    print("Error while parsing line (layer \(layerNumber)):\n\(line)\n")
                    print("\(e)")
                    throw e
                }
            }
            layers.append((layerNumber, constructors))
        }

        return .layered(layers: layers)
    }
    
    private static func parseConstructor(string: String) throws -> ConstructorDescription {
        let parseIdentifier = Parse {
            Prefix<Substring>(minLength: 1, while: { $0.isLetter || $0.isNumber || $0 == "_" })
        }.map { String($0) }
        
        let parseConditionDescription = Parse {
            parseIdentifier
            "."
            Int.parser(of: Substring.self)
            "?"
        }.map { fieldName, bitIndex -> ArgumentDescription.ConditionDescription in
            ArgumentDescription.ConditionDescription(fieldName: fieldName, bitIndex: bitIndex)
        }
        
        let parseQualifiedName = Parse {
            parseIdentifier
            Optionally {
                "."
                parseIdentifier
            }
        }.map { first, second -> QualifiedName in
            if let second = second {
                return QualifiedName(namespace: first, value: second)
            } else {
                return QualifiedName(namespace: nil, value: first)
            }
        }
        
        let parseGenericTypeReference = Parse {
            parseIdentifier
            "<"
            parseQualifiedName
            ">"
        }.map { name, argumentType -> TypeReferenceDescription in
            return .generic(name: name, argumentType: argumentType)
        }
        
        let parseDirectTypeReference = Parse {
            parseQualifiedName
        }.map { name -> TypeReferenceDescription in
            return .type(name: name)
        }
        
        let parseFlagsTypeReference = Parse {
            "#"
        }.map { () -> TypeReferenceDescription in
            return .type(name: QualifiedName(namespace: nil, value: "int"))
        }
        
        let parseTypeReference = Parse {
            OneOf {
                parseFlagsTypeReference
                parseGenericTypeReference
                parseDirectTypeReference
            }
        }
        
        let parseArgument = Parse {
            parseIdentifier
            ":"
            Optionally {
                parseConditionDescription
            }
            parseTypeReference
        }.map { name, condition, type -> ArgumentDescription in
            return ArgumentDescription(name: name, type: type, condition: condition)
        }
        
        let parseExplicitId = Parse {
            "#"
            Prefix<Substring> { $0.isHexDigit }
        }.map { UInt32($0, radix: 16)! }
        
        let optionalExplicitId = Optionally {
            parseExplicitId
        }
        
        let manyArguments = Many {
            parseArgument
        } separator: {
            Whitespace()
        }
        
        let nameAndConstructor = Parse {
            parseQualifiedName
            optionalExplicitId
            Whitespace()
        }.map { name, explicitId, _ -> (name: QualifiedName, explicitId: UInt32?) in
            return (name, explicitId)
        }
        
        let typeSeparator = Parse {
            Whitespace()
            "="
            Whitespace()
        }
        
        let trailerParser = Parse {
            Whitespace()
            ";"
            Whitespace()
            End()
        }.map { _ -> Void in
        }
        
        let parseConstructor = Parse {
            nameAndConstructor
            manyArguments
            typeSeparator
            parseTypeReference
            trailerParser
        }.map { nameAndConstructor, arguments, _, type -> ConstructorDescription in
            return ConstructorDescription(
                name: nameAndConstructor.name,
                explicitId: nameAndConstructor.explicitId,
                arguments: arguments,
                type: type
            )
        }
        
        var data = string[...]
        let result = try parseConstructor.parse(&data)
        
        return result
    }
}
