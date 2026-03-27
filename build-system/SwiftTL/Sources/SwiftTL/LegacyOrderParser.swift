import Foundation

enum LegacyOrderParser {
    struct LegacyOrderParsingError: Error, CustomStringConvertible {
        var text: String
        
        var description: String {
            return self.text
        }
    }
    
    static func parseConstructorOrder(data: String) throws -> [(typeName: QualifiedName, constructorName: String)] {
        let lines = data.split(separator: "\n")
        
        var result: [(typeName: QualifiedName, constructorName: String)] = []
        
        for line in lines {
            if let startRange = line.range(of: " = { return Api."), let endRange = line.range(of: "($0) }", options: [.backwards], range: nil) {
                let parseString = line[startRange.upperBound ..< endRange.lowerBound]
                let components = parseString.components(separatedBy: ".parse_")
                if components.count != 2 {
                    continue
                }
                
                result.append((QualifiedName(string: components[0]), components[1]))
            }
        }
        
        return result
    }
    
    static func parseTypeOrder(data: String) throws -> (types: [(typeName: QualifiedName, constructorNames: [String])], functions: [QualifiedName]) {
        var resultTypes: [(typeName: QualifiedName, constructorNames: [String])] = []
        var resultFunctions: [QualifiedName] = []
        
        let namespaces = data.components(separatedBy: "public extension Api {\n")
        
        enum ParseSection {
            case types
            case functions
        }
        
        for namespaceData in namespaces {
            if namespaceData.isEmpty {
                continue
            }
            guard let firstNewline = namespaceData.range(of: "\n") else {
                throw LegacyOrderParsingError(text: "No newline in the beginning of the namespace section")
            }
            let namespaceName: String?
            let namespaceContentData: String
            let parseSection: ParseSection
            if let prefixRange = namespaceData.range(of: "    public enum ", options: [], range: namespaceData.startIndex ..< firstNewline.lowerBound), prefixRange.lowerBound == namespaceData.startIndex {
                namespaceName = nil
                namespaceContentData = namespaceData
                parseSection = .types
            } else if let prefixRange = namespaceData.range(of: "    indirect public enum ", options: [], range: namespaceData.startIndex ..< firstNewline.lowerBound), prefixRange.lowerBound == namespaceData.startIndex {
                namespaceName = nil
                namespaceContentData = namespaceData
                parseSection = .types
            } else if let prefixRange = namespaceData.range(of: "    public struct functions {", options: [], range: namespaceData.startIndex ..< firstNewline.lowerBound), prefixRange.upperBound == firstNewline.lowerBound {
                namespaceName = nil
                namespaceContentData = namespaceData
                parseSection = .functions
            } else {
                guard let prefixRange = namespaceData.range(of: "public struct ", options: [], range: namespaceData.startIndex ..< firstNewline.lowerBound), prefixRange.lowerBound == namespaceData.startIndex else {
                    throw LegacyOrderParsingError(text: "Missing header prefix in the beginning of the namespace section")
                }
                guard let trailerRange = namespaceData.range(of: " {", options: [], range: prefixRange.upperBound ..< firstNewline.lowerBound) else {
                    throw LegacyOrderParsingError(text: "Missing trailing suffix in the beginning of the namespace section")
                }
                namespaceName = String(namespaceData[prefixRange.upperBound ..< trailerRange.lowerBound])
                namespaceContentData = String(namespaceData[firstNewline.upperBound...])
                parseSection = .types
            }
            
            let namespaceContentLines = namespaceContentData.split(separator: "\n")
            
            switch parseSection {
            case .types:
                var currentType: (typeName: QualifiedName, constructorNames: [String])?
                for line in namespaceContentLines {
                    if let typePrefixRange = line.range(of: "    public enum "), typePrefixRange.lowerBound == line.startIndex, let typeSuffixRange = line.range(of: ": TypeConstructorDescription {"), typeSuffixRange.upperBound == line.endIndex {
                        let typeName = String(line[typePrefixRange.upperBound ..< typeSuffixRange.lowerBound])
                        if let currentType = currentType {
                            resultTypes.append(currentType)
                        }
                        currentType = (QualifiedName(namespace: namespaceName, value: typeName), [])
                    } else if let typePrefixRange = line.range(of: "    indirect public enum "), typePrefixRange.lowerBound == line.startIndex, let typeSuffixRange = line.range(of: ": TypeConstructorDescription {"), typeSuffixRange.upperBound == line.endIndex {
                        let typeName = String(line[typePrefixRange.upperBound ..< typeSuffixRange.lowerBound])
                        if let currentType = currentType {
                            resultTypes.append(currentType)
                        }
                        currentType = (QualifiedName(namespace: namespaceName, value: typeName), [])
                    } else if currentType != nil, let constructorPrefixRange = line.range(of: "        case "), constructorPrefixRange.lowerBound == line.startIndex {
                        let constructorName: String
                        if let bracketRange = line.range(of: "(") {
                            constructorName = String(line[constructorPrefixRange.upperBound ..< bracketRange.lowerBound])
                        } else {
                            constructorName = String(line[constructorPrefixRange.upperBound...])
                        }
                        currentType?.constructorNames.append(constructorName)
                    }
                }
                if let currentType = currentType {
                    resultTypes.append(currentType)
                }
            case .functions:
                var currentNamespace: String?
                for line in namespaceContentLines {
                    if let namespacePrefixRange = line.range(of: "            public struct "), namespacePrefixRange.lowerBound == line.startIndex, let namespaceSuffixRange = line.range(of: " {"), namespaceSuffixRange.upperBound == line.endIndex {
                        currentNamespace = String(line[namespacePrefixRange.upperBound ..< namespaceSuffixRange.lowerBound])
                    } else if let functionPrefixRange = line.range(of: "                public static func "), functionPrefixRange.lowerBound == line.startIndex {
                        let functionName: String
                        if let bracketRange = line.range(of: "(") {
                            functionName = String(line[functionPrefixRange.upperBound ..< bracketRange.lowerBound])
                        } else {
                            functionName = String(line[functionPrefixRange.upperBound...])
                        }
                        resultFunctions.append(QualifiedName(namespace: currentNamespace, value: functionName))
                    }
                }
            }
        }
        
        return (resultTypes, resultFunctions)
    }
}
