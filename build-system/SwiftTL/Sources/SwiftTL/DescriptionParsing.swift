import Foundation

enum DescriptionParser {
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
    
    static func parse(data: String) throws -> (constructors: [ConstructorDescription], functions: [ConstructorDescription]) {
        let lines = data.components(separatedBy: "\n")
        
        var typeLines: [String] = []
        var functionLines: [String] = []
        
        let skipPrefixes: [String] = [
            //"boolFalse#bc799737 = Bool;",
            //"boolTrue#997275b5 = Bool;",
            "true#3fedd339 = True;",
            "vector#1cb5c415 {t:Type} # [ t ] = Vector t;",
            "error#c4b9f9bb code:int text:string = Error;",
            "null#56730bcc = Null;"
        ]
        
        let skipContains: [String] = [
            "{X:Type}"
        ]
        
        var isParsingFunctions = false
        loop: for line in lines {
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                // skip
            } else if line == "---functions---" {
                isParsingFunctions = true
            } else {
                for string in skipPrefixes {
                    if line.hasPrefix(string) {
                        continue loop
                    }
                }
                
                for string in skipContains {
                    if line.contains(string) {
                        continue loop
                    }
                }
                
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
                let constructor = try self.parseConstructor(string: line)
                constructors.append(constructor)
            } catch let e {
                print("Error while parsing line:\n\(line)\n")
                print("\(e)")
                
                throw e
            }
        }
        
        for line in functionLines {
            do {
                let constructor = try parseConstructor(string: line)
                functions.append(constructor)
            } catch let e {
                print("Error while parsing line:\n\(line)\n")
                print("\(e)")
                
                throw e
            }
        }
        
        return (constructors, functions)
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
