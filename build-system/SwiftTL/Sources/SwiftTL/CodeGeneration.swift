import Foundation

private let reservedIdentifiers: [String] = [
    "protocol",
    "private"
]

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

    var camelCasedAndEscaped: String {
        var result = self.camelCased

        if reservedIdentifiers.contains(result) {
            result = "`\(result)`"
        }

        return result
    }
}

private struct CodeWriter {
    private var code: String = ""
    private var indentLevel: Int = 0
    private let indentString: String = "    "

    private var currentIndent: String {
        String(repeating: indentString, count: indentLevel)
    }

    mutating func indent() {
        indentLevel += 1
    }

    mutating func dedent() {
        indentLevel = max(0, indentLevel - 1)
    }

    mutating func line(_ text: String = "") {
        if text.isEmpty {
            code += "\n"
        } else {
            code += currentIndent + text + "\n"
        }
    }

    mutating func lines(_ text: String) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty {
                code += "\n"
            } else {
                code += currentIndent + line + "\n"
            }
        }
    }

    func output() -> String {
        return code
    }
}

/*private extension QualifiedName {
    var camelCased: String {
        if let namespace = self.namespace {
            return "\(namespace).\(self.value.camelCased)"
        } else {
            return self.value.camelCased
        }
    }
}*/

private func typeReferenceRepresentation(_ type: Resolver.TypeReference) -> String {
    switch type {
    case .int32:
        return "Int32"
    case .int64:
        return "Int64"
    case .int256:
        return "Int256"
    case .double:
        return "Double"
    case .bytes:
        return "Buffer"
    case .string:
        return "String"
    case .bool:
        return "Bool"
    case .boolTrue:
        return "bool"
    case let .bareVector(elementType):
        return "[\(typeReferenceRepresentation(elementType))]"
    case let .boxedVector(elementType):
        return "[\(typeReferenceRepresentation(elementType))]"
    case let .bareConstructor(typeName, _):
        return "Api.\(typeName)"
    case let .boxedType(typeName):
        return "Api.\(typeName)"
    }
}

private extension Resolver.SumType {
    func hasDirectReference(to otherTypes: [Resolver.SumType], typeMap: [QualifiedName: Resolver.SumType]) throws -> Bool {
        for (_, constructor) in self.constructors {
            for argument in constructor.arguments {
                switch argument.type {
                case .int32:
                    break
                case .int64:
                    break
                case .int256:
                    break
                case .double:
                    break
                case .bytes:
                    break
                case .string:
                    break
                case .bool:
                    break
                case .boolTrue:
                    break
                case .bareVector:
                    break
                case .boxedVector:
                    break
                case .bareConstructor(let typeName, _), .boxedType(let typeName):
                    for otherType in otherTypes {
                        if typeName == otherType.name {
                            return true
                        }
                    }
                    
                    guard let referencedType = typeMap[typeName] else {
                        throw CodeGenerator.CodeGenerationError(text: "Type \(typeName) not found")
                    }
                    
                    var mergedTypes = otherTypes
                    if !mergedTypes.contains(where: { $0.name == self.name }) {
                        mergedTypes.append(self)
                    }
                    
                    if try referencedType.hasDirectReference(to: mergedTypes, typeMap: typeMap) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
}

private extension Sequence where Iterator.Element: Hashable {
    func unique() -> [Iterator.Element] {
        var seen: Set<Iterator.Element> = []
        return filter { seen.insert($0).inserted }
    }
}

enum CodeGenerator {
    struct CodeGenerationError: Error, CustomStringConvertible {
        var text: String
        
        var description: String {
            return self.text
        }
    }
    
    static func generate(types: [Resolver.SumType], functions: [Resolver.Function], constructorOrder: [(typeName: QualifiedName, constructorName: String)], typeOrder: [(types: [(typeName: QualifiedName, constructorNames: [String])], functions: [QualifiedName])], stubFunctions: Bool = false) throws -> [String: String] {
        var files: [String: String] = [:]
        
        var functions = functions
        functions.append(Resolver.Function(name: QualifiedName(namespace: "help", value: "test"), id: UInt32(bitPattern: -1058929929), arguments: [], result: .boxedType(QualifiedName(namespace: nil, value: "Bool"))))

        files["Api0.swift"] = try generateMainFile(types: types, functions: functions, constructorOrder: constructorOrder)
        
        for index in 0 ..< typeOrder.count {
            files["Api\(index + 1).swift"] = try generateImplFile(types: types, functions: functions, typeOrder: typeOrder[index], stubFunctions: stubFunctions)
        }
        
        return files
    }
    
    private static func generateMainFile(types: [Resolver.SumType], functions: [Resolver.Function], constructorOrder: [(typeName: QualifiedName, constructorName: String)]) throws -> String {
        var writer = CodeWriter()

        writer.line()

        var namespaces = Set<String>()
        for type in types {
            if let namespace = type.name.namespace {
                namespaces.insert(namespace)
            }
        }

        var functionNamespaces = Set<String>()
        for function in functions {
            if let namespace = function.name.namespace {
                functionNamespaces.insert(namespace)
            }
        }

        writer.line("public enum Api {")
        writer.indent()
        for namespace in namespaces.sorted(by: { $0 < $1 }) {
            writer.line("public enum \(namespace) {}")
        }
        writer.line("public enum functions {")
        writer.indent()
        for namespace in functionNamespaces.sorted(by: { $0 < $1 }) {
            writer.line("public enum \(namespace) {}")
        }
        writer.dedent()
        writer.line("}")
        writer.dedent()
        writer.line("}")

        writer.line()

        var typeMap: [QualifiedName: Resolver.SumType] = [:]
        for type in types {
            typeMap[type.name] = type
        }

        writer.line("fileprivate let parsers: [Int32 : (BufferReader) -> Any?] = {")
        writer.indent()
        writer.line("var dict: [Int32 : (BufferReader) -> Any?] = [:]")
        writer.line("dict[-1471112230] = { return $0.readInt32() }")
        writer.line("dict[570911930] = { return $0.readInt64() }")
        writer.line("dict[571523412] = { return $0.readDouble() }")
        writer.line("dict[0x0929C32F] = { return parseInt256($0) }")
        writer.line("dict[-1255641564] = { return parseString($0) }")

        for (typeName, constructorName) in constructorOrder {
            guard let type = typeMap[typeName] else {
                throw CodeGenerationError(text: "Type \(typeName) not found")
            }

            var found = false
            for (_, constructor) in type.constructors {
                if constructor.name.value == constructorName {
                    found = true
                    writer.line("dict[\(Int32(bitPattern: constructor.id))] = { return Api.\(type.name).parse_\(constructor.name.value)($0) }")
                    break
                }
            }

            if !found {
                throw CodeGenerationError(text: "Constructor \(constructorName) not found")
            }
        }

        writer.line("return dict")
        writer.dedent()
        writer.line("}()")

        writer.line()

        writer.line("public extension Api {")
        writer.indent()

        writer.line("static func parse(_ buffer: Buffer) -> Any? {")
        writer.indent()
        writer.line("let reader = BufferReader(buffer)")
        writer.line("if let signature = reader.readInt32() {")
        writer.indent()
        writer.line("return parse(reader, signature: signature)")
        writer.dedent()
        writer.line("}")
        writer.line("return nil")
        writer.dedent()
        writer.line("}")

        writer.line()

        writer.line("static func parse(_ reader: BufferReader, signature: Int32) -> Any? {")
        writer.indent()
        writer.line("if let parser = parsers[signature] {")
        writer.indent()
        writer.line("return parser(reader)")
        writer.dedent()
        writer.line("} else {")
        writer.indent()
        writer.line("telegramApiLog(\"Type constructor \\(String(UInt32(bitPattern: signature), radix: 16, uppercase: false)) not found\")")
        writer.line("return nil")
        writer.dedent()
        writer.line("}")
        writer.dedent()
        writer.line("}")

        writer.line()

        writer.line("static func parseVector<T>(_ reader: BufferReader, elementSignature: Int32, elementType: T.Type) -> [T]? {")
        writer.indent()
        writer.line("if let count = reader.readInt32() {")
        writer.indent()
        writer.line("var array = [T]()")
        writer.line("var i: Int32 = 0")
        writer.line("while i < count {")
        writer.indent()
        writer.line("var signature = elementSignature")
        writer.line("if elementSignature == 0 {")
        writer.indent()
        writer.line("if let unboxedSignature = reader.readInt32() {")
        writer.indent()
        writer.line("signature = unboxedSignature")
        writer.dedent()
        writer.line("} else {")
        writer.indent()
        writer.line("return nil")
        writer.dedent()
        writer.line("}")
        writer.dedent()
        writer.line("}")
        writer.line("if elementType == Buffer.self {")
        writer.indent()
        writer.line("if let item = parseBytes(reader) as? T {")
        writer.indent()
        writer.line("array.append(item)")
        writer.dedent()
        writer.line("} else {")
        writer.indent()
        writer.line("return nil")
        writer.dedent()
        writer.line("}")
        writer.dedent()
        writer.line("} else {")
        writer.indent()
        writer.line("if let item = Api.parse(reader, signature: signature) as? T {")
        writer.indent()
        writer.line("array.append(item)")
        writer.dedent()
        writer.line("} else {")
        writer.indent()
        writer.line("return nil")
        writer.dedent()
        writer.line("}")
        writer.dedent()
        writer.line("}")
        writer.line("i += 1")
        writer.dedent()
        writer.line("}")
        writer.line("return array")
        writer.dedent()
        writer.line("}")
        writer.line("return nil")
        writer.dedent()
        writer.line("}")

        writer.line()

        writer.line("static func serializeObject(_ object: Any, buffer: Buffer, boxed: Swift.Bool) {")
        writer.indent()
        writer.line("switch object {")

        let typeOrder = constructorOrder.map(\.typeName).unique()

        for typeName in typeOrder {
            guard let type = typeMap[typeName] else {
                throw CodeGenerationError(text: "Type \(typeName) not found")
            }

            writer.line("case let _1 as Api.\(type.name):")
            writer.indent()
            writer.line("_1.serialize(buffer, boxed)")
            writer.dedent()
        }

        writer.line("default:")
        writer.indent()
        writer.line("break")
        writer.dedent()
        writer.line("}")
        writer.dedent()
        writer.line("}")

        writer.dedent()
        writer.line("}")

        return writer.output()
    }
    
    private static func generateImplFile(types: [Resolver.SumType], functions: [Resolver.Function], typeOrder: (types: [(typeName: QualifiedName, constructorNames: [String])], functions: [QualifiedName]), stubFunctions: Bool) throws -> String {
        var writer = CodeWriter()

        var typeMap: [QualifiedName: Resolver.SumType] = [:]
        for type in types {
            typeMap[type.name] = type
        }

        for (typeName, constructorNames) in typeOrder.types {
            writer.line("public extension Api\(typeName.namespace.flatMap { "." + $0 } ?? "") {")
            writer.indent()

            guard let type = typeMap[typeName] else {
                throw CodeGenerationError(text: "Type \(typeName) not found")
            }

            let indirectPrefix = try type.hasDirectReference(to: [type], typeMap: typeMap) ? "indirect " : ""
            writer.line("\(indirectPrefix)enum \(typeName.value): TypeConstructorDescription {")
            writer.indent()

            var sortedConstructors: [Resolver.SumType.Constructor] = []
            for constructorName in constructorNames {
                var foundConstructor: Resolver.SumType.Constructor?
                for (_, constructor) in type.constructors {
                    if constructor.name.value == constructorName {
                        foundConstructor = constructor
                        break
                    }
                }
                guard let constructor = foundConstructor else {
                    throw CodeGenerationError(text: "Constructor \(constructorName) -> \(typeName) not found")
                }
                sortedConstructors.append(constructor)
            }

            let useStructPattern = true

            if useStructPattern {
                for constructor in sortedConstructors {
                    var fieldsString = ""
                    var initParamsString = ""
                    var initBodyString = ""
                    var descriptionFieldsString = ""

                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        let fieldName = argument.name.camelCasedAndEscaped
                        let fieldType = typeReferenceRepresentation(argument.type) + (argument.condition != nil ? "?" : "")

                        if !fieldsString.isEmpty {
                            fieldsString.append("\n")
                        }
                        fieldsString.append("public var \(fieldName): \(fieldType)")

                        if !initParamsString.isEmpty {
                            initParamsString.append(", ")
                        }
                        initParamsString.append("\(fieldName): \(fieldType)")

                        if !initBodyString.isEmpty {
                            initBodyString.append("\n")
                        }
                        initBodyString.append("self.\(fieldName) = \(fieldName)")

                        if !descriptionFieldsString.isEmpty {
                            descriptionFieldsString.append(", ")
                        }
                        descriptionFieldsString.append("(\"\(fieldName)\", ConstructorParameterDescription(self.\(fieldName)))")
                    }

                    if !fieldsString.isEmpty {
                        writer.line("public class Cons_\(constructor.name.value): TypeConstructorDescription {")
                        writer.indent()
                        writer.lines(fieldsString)
                        writer.line("public init(\(initParamsString)) {")
                        writer.indent()
                        writer.lines(initBodyString)
                        writer.dedent()
                        writer.line("}")
                        writer.line("public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {")
                        writer.indent()
                        writer.line("return (\"\(constructor.name.value)\", [\(descriptionFieldsString)])")
                        writer.dedent()
                        writer.line("}")
                        writer.dedent()
                        writer.line("}")
                    }
                }
            }

            for constructor in sortedConstructors {
                let hasFields = constructor.arguments.contains { if case .boolTrue = $0.type { return false } else { return true } }

                if useStructPattern && hasFields {
                    writer.line("case \(constructor.name.value)(Cons_\(constructor.name.value))")
                } else {
                    var argumentsString = ""
                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        if !argumentsString.isEmpty {
                            argumentsString.append(", ")
                        }

                        argumentsString.append(argument.name.camelCased)
                        argumentsString.append(": ")
                        argumentsString.append(typeReferenceRepresentation(argument.type))
                        if argument.condition != nil {
                            argumentsString.append("?")
                        }
                    }

                    writer.line("case \(constructor.name.value)\(argumentsString.isEmpty ? "" : "(\(argumentsString))")")
                }
            }

            writer.line()
            writer.line("public func serialize(_ buffer: Buffer, _ boxed: Swift.Bool) {")
            writer.indent()
            if stubFunctions {
                writer.line("#if DEBUG")
                writer.line("preconditionFailure()")
                writer.line("#else")
                writer.line("error")
                writer.line("#endif")
            } else {
            writer.line("switch self {")

            for constructor in sortedConstructors {
                let hasFields = constructor.arguments.contains { if case .boolTrue = $0.type { return false } else { return true } }

                if useStructPattern && hasFields {
                    writer.line("case .\(constructor.name.value)(let _data):")
                    writer.indent()
                    writer.line("if boxed {")
                    writer.indent()
                    writer.line("buffer.appendInt32(\(Int32(bitPattern: constructor.id)))")
                    writer.dedent()
                    writer.line("}")

                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        var argumentAccessor = "_data.\(argument.name.camelCasedAndEscaped)"
                        if let condition = argument.condition {
                            writer.line("if Int(_data.\(condition.fieldName.camelCasedAndEscaped)) & Int(1 << \(condition.bitIndex)) != 0 {")
                            writer.indent()
                            argumentAccessor.append("!")
                            generateFieldSerialization(writer: &writer, argument: argument, argumentAccessor: argumentAccessor)
                            writer.dedent()
                            writer.line("}")
                        } else {
                            generateFieldSerialization(writer: &writer, argument: argument, argumentAccessor: argumentAccessor)
                        }
                    }
                    writer.line("break")
                    writer.dedent()
                } else {
                    var argumentsString = ""
                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        if !argumentsString.isEmpty {
                            argumentsString.append(", ")
                        }

                        argumentsString.append("let ")
                        argumentsString.append(argument.name.camelCasedAndEscaped)
                    }

                    writer.line("case .\(constructor.name.value)\(argumentsString.isEmpty ? "" : "(\(argumentsString))"):")
                    writer.indent()
                    writer.line("if boxed {")
                    writer.indent()
                    writer.line("buffer.appendInt32(\(Int32(bitPattern: constructor.id)))")
                    writer.dedent()
                    writer.line("}")

                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        var argumentAccessor = "\(argument.name.camelCasedAndEscaped)"
                        if let condition = argument.condition {
                            writer.line("if Int(\(condition.fieldName)) & Int(1 << \(condition.bitIndex)) != 0 {")
                            writer.indent()
                            argumentAccessor.append("!")
                            generateFieldSerialization(writer: &writer, argument: argument, argumentAccessor: argumentAccessor)
                            writer.dedent()
                            writer.line("}")
                        } else {
                            generateFieldSerialization(writer: &writer, argument: argument, argumentAccessor: argumentAccessor)
                        }
                    }
                    writer.line("break")
                    writer.dedent()
                }
            }

            writer.line("}")
            } // end if !stubFunctions
            writer.dedent()
            writer.line("}")

            writer.line()
            writer.line("public func descriptionFields() -> (String, [(String, ConstructorParameterDescription)]) {")
            writer.indent()
            if stubFunctions {
                writer.line("#if DEBUG")
                writer.line("preconditionFailure()")
                writer.line("#else")
                writer.line("error")
                writer.line("#endif")
            } else {
            writer.line("switch self {")

            for constructor in sortedConstructors {
                let hasFields = constructor.arguments.contains { if case .boolTrue = $0.type { return false } else { return true } }

                if useStructPattern && hasFields {
                    var argumentSerializationString = ""
                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        if !argumentSerializationString.isEmpty {
                            argumentSerializationString.append(", ")
                        }
                        argumentSerializationString.append("(\"\(argument.name.camelCasedAndEscaped)\", ConstructorParameterDescription(_data.\(argument.name.camelCasedAndEscaped)))")
                    }

                    writer.line("case .\(constructor.name.value)(let _data):")
                    writer.indent()
                    writer.line("return (\"\(constructor.name.value)\", [\(argumentSerializationString)])")
                    writer.dedent()
                } else {
                    var argumentsString = ""
                    var argumentSerializationString = ""
                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        if !argumentsString.isEmpty {
                            argumentsString.append(", ")
                        }
                        if !argumentSerializationString.isEmpty {
                            argumentSerializationString.append(", ")
                        }

                        argumentsString.append("let ")
                        argumentsString.append(argument.name.camelCasedAndEscaped)

                        argumentSerializationString.append("(\"\(argument.name.camelCasedAndEscaped)\", \(argument.name.camelCasedAndEscaped) as Any)")
                    }

                    writer.line("case .\(constructor.name.value)\(argumentsString.isEmpty ? "" : "(\(argumentsString))"):")
                    writer.indent()
                    writer.line("return (\"\(constructor.name.value)\", [\(argumentSerializationString)])")
                    writer.dedent()
                }
            }

            writer.line("}")
            } // end if !stubFunctions for descriptionFields
            writer.dedent()
            writer.line("}")

            writer.line()

            for constructor in sortedConstructors {
                writer.line("public static func parse_\(constructor.name.value)(_ reader: BufferReader) -> \(typeName.value)? {")
                writer.indent()
                if stubFunctions {
                    writer.line("#if DEBUG")
                    writer.line("preconditionFailure()")
                    writer.line("#else")
                    writer.line("error")
                    writer.line("#endif")
                } else {

                if constructor.arguments.contains(where: { if case .boolTrue = $0.type { return false } else { return true } }) {
                    var argumentIndex = 0
                    var argumentCheckString = ""
                    var argumentCollectionString = ""
                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        writer.line("var _\(argumentIndex + 1): \(typeReferenceRepresentation(argument.type))?")

                        if let condition = argument.condition {
                            guard let fieldIndex = constructor.arguments.filter({ if case .boolTrue = $0.type { return false } else { return true } }).firstIndex(where: { $0.name == condition.fieldName }) else {
                                throw CodeGenerationError(text: "Condition field \(condition.fieldName) not found")
                            }

                            writer.line("if Int(_\(fieldIndex + 1)!) & Int(1 << \(condition.bitIndex)) != 0 {")
                            writer.indent()
                            try generateFieldParsing(writer: &writer, typeMap: typeMap, argument: argument, argumentAccessor: "_\(argumentIndex + 1)")
                            writer.dedent()
                            writer.line("}")
                        } else {
                            try generateFieldParsing(writer: &writer, typeMap: typeMap, argument: argument, argumentAccessor: "_\(argumentIndex + 1)")
                        }

                        if !argumentCheckString.isEmpty {
                            argumentCheckString.append(" && ")
                        }
                        argumentCheckString.append("_c\(argumentIndex + 1)")

                        if !argumentCollectionString.isEmpty {
                            argumentCollectionString.append(", ")
                        }
                        argumentCollectionString.append("\(argument.name.camelCased): _\(argumentIndex + 1)")
                        if argument.condition == nil {
                            argumentCollectionString.append("!")
                        }

                        argumentIndex += 1
                    }

                    var checkIndex = 0
                    for argument in constructor.arguments {
                        if case .boolTrue = argument.type {
                            continue
                        }

                        if let condition = argument.condition {
                            guard let fieldIndex = constructor.arguments.filter({ if case .boolTrue = $0.type { return false } else { return true } }).firstIndex(where: { $0.name == condition.fieldName }) else {
                                throw CodeGenerationError(text: "Condition field \(condition.fieldName) not found")
                            }

                            writer.line("let _c\(checkIndex + 1) = (Int(_\(fieldIndex + 1)!) & Int(1 << \(condition.bitIndex)) == 0) || _\(checkIndex + 1) != nil")
                        } else {
                            writer.line("let _c\(checkIndex + 1) = _\(checkIndex + 1) != nil")
                        }

                        checkIndex += 1
                    }

                    writer.line("if \(argumentCheckString) {")
                    writer.indent()
                    if useStructPattern && !argumentCollectionString.isEmpty {
                        writer.line("return Api.\(typeName).\(constructor.name.value)(Cons_\(constructor.name.value)(\(argumentCollectionString)))")
                    } else {
                        writer.line("return Api.\(typeName).\(constructor.name.value)\(argumentCollectionString.isEmpty ? "" : "(\(argumentCollectionString))")")
                    }
                    writer.dedent()
                    writer.line("}")
                    writer.line("else {")
                    writer.indent()
                    writer.line("return nil")
                    writer.dedent()
                    writer.line("}")
                } else {
                    writer.line("return Api.\(typeName).\(constructor.name.value)")
                }

                } // end if !stubFunctions
                writer.dedent()
                writer.line("}")
            }

            writer.dedent()
            writer.line("}")
            writer.dedent()
            writer.line("}")
        }

        if !typeOrder.functions.isEmpty {
            for functionName in typeOrder.functions {
                writer.line("public extension Api.functions\(functionName.namespace.flatMap { "." + $0 } ?? "") {")
                writer.indent()

                var foundFunction: Resolver.Function?
                for function in functions {
                    if function.name == functionName {
                        foundFunction = function
                        break
                    }
                }
                guard let function = foundFunction else {
                    throw CodeGenerationError(text: "Function \(functionName) not found")
                }

                var argumentsString = ""
                for argument in function.arguments {
                    if case .boolTrue = argument.type {
                        continue
                    }

                    if !argumentsString.isEmpty {
                        argumentsString.append(", ")
                    }

                    argumentsString.append(argument.name.camelCasedAndEscaped)
                    argumentsString.append(": ")
                    argumentsString.append(typeReferenceRepresentation(argument.type))
                    if argument.condition != nil {
                        argumentsString.append("?")
                    }
                }

                writer.line("static func \(function.name.value)(\(argumentsString)) -> (FunctionDescription, Buffer, DeserializeFunctionResponse<\(typeReferenceRepresentation(function.result))>) {")
                writer.indent()
                writer.line("let buffer = Buffer()")
                writer.line("buffer.appendInt32(\(Int32(bitPattern: function.id)))")

                var argumentSerializationString = ""
                for argument in function.arguments {
                    if case .boolTrue = argument.type {
                        continue
                    }

                    var argumentAccessor = "\(argument.name.camelCasedAndEscaped)"
                    if let condition = argument.condition {
                        guard let _ = function.arguments.filter({ if case .boolTrue = $0.type { return false } else { return true } }).firstIndex(where: { $0.name == condition.fieldName }) else {
                            throw CodeGenerationError(text: "Condition field \(condition.fieldName) not found")
                        }

                        writer.line("if Int(\(condition.fieldName)) & Int(1 << \(condition.bitIndex)) != 0 {")
                        writer.indent()
                        argumentAccessor.append("!")
                        generateFieldSerialization(writer: &writer, argument: argument, argumentAccessor: argumentAccessor)
                        writer.dedent()
                        writer.line("}")
                    } else {
                        generateFieldSerialization(writer: &writer, argument: argument, argumentAccessor: argumentAccessor)
                    }

                    if !argumentSerializationString.isEmpty {
                        argumentSerializationString.append(", ")
                    }

                    argumentSerializationString.append("(\"\(argument.name.camelCasedAndEscaped)\", ConstructorParameterDescription(\(argument.name.camelCasedAndEscaped)))")
                }

                writer.line("return (FunctionDescription(name: \"\(function.name)\", parameters: [\(argumentSerializationString)]), buffer, DeserializeFunctionResponse { (buffer: Buffer) -> \(typeReferenceRepresentation(function.result))? in")
                writer.indent()
                writer.line("let reader = BufferReader(buffer)")
                writer.line("var result: \(typeReferenceRepresentation(function.result))?")

                try generateFieldParsing(writer: &writer, typeMap: typeMap, argument: Resolver.Argument(name: "result", type: function.result, condition: nil), argumentAccessor: "result")

                writer.line("return result")
                writer.dedent()
                writer.line("})")

                writer.dedent()
                writer.line("}")

                writer.dedent()
                writer.line("}")
            }
        }

        return writer.output()
    }
    
    private static func generateFieldSerialization(writer: inout CodeWriter, argument: Resolver.Argument, argumentAccessor: String) {
        switch argument.type {
        case .int32:
            writer.line("serializeInt32(\(argumentAccessor), buffer: buffer, boxed: false)")
        case .int64:
            writer.line("serializeInt64(\(argumentAccessor), buffer: buffer, boxed: false)")
        case .int256:
            writer.line("serializeInt256(\(argumentAccessor), buffer: buffer, boxed: false)")
        case .double:
            writer.line("serializeDouble(\(argumentAccessor), buffer: buffer, boxed: false)")
        case .bytes:
            writer.line("serializeBytes(\(argumentAccessor), buffer: buffer, boxed: false)")
        case .string:
            writer.line("serializeString(\(argumentAccessor), buffer: buffer, boxed: false)")
        case .bool:
            preconditionFailure()
        case .boolTrue:
            preconditionFailure()
        case .bareVector(let elementType), .boxedVector(let elementType):
            if case .boxedVector = argument.type {
                writer.line("buffer.appendInt32(481674261)")
            }
            writer.line("buffer.appendInt32(Int32(\(argumentAccessor).count))")
            writer.line("for item in \(argumentAccessor) {")
            writer.indent()
            generateFieldSerialization(writer: &writer, argument: Resolver.Argument(name: "item", type: elementType, condition: nil), argumentAccessor: "item")
            writer.dedent()
            writer.line("}")
        case .bareConstructor:
            writer.line("\(argumentAccessor).serialize(buffer, false)")
        case .boxedType:
            writer.line("\(argumentAccessor).serialize(buffer, true)")
        }
    }
    
    private static func generateFieldParsing(writer: inout CodeWriter, typeMap: [QualifiedName: Resolver.SumType], argument: Resolver.Argument, argumentAccessor: String) throws {
        switch argument.type {
        case .int32:
            writer.line("\(argumentAccessor) = reader.readInt32()")
        case .int64:
            writer.line("\(argumentAccessor) = reader.readInt64()")
        case .int256:
            writer.line("\(argumentAccessor) = parseInt256(reader)")
        case .double:
            writer.line("\(argumentAccessor) = reader.readDouble()")
        case .bytes:
            writer.line("\(argumentAccessor) = parseBytes(reader)")
        case .string:
            writer.line("\(argumentAccessor) = parseString(reader)")
        case .bool:
            preconditionFailure()
        case .boolTrue:
            preconditionFailure()
        case .bareVector(let elementType), .boxedVector(let elementType):
            var elementSignature: Int32 = 0

            switch elementType {
            case .int32:
                elementSignature = -1471112230
            case .int64:
                elementSignature = 570911930
            case .int256:
                elementSignature = 0x0929C32F
            case .double:
                elementSignature = 571523412
            case .bytes:
                elementSignature = -1255641564
            case .string:
                elementSignature = -1255641564
            case .bool:
                elementSignature = 0
            case .boolTrue:
                elementSignature = 0
            case .bareVector:
                elementSignature = 0
            case .boxedVector:
                elementSignature = 0
            case let .bareConstructor(typeName, name):
                guard let type = typeMap[typeName] else {
                    throw CodeGenerationError(text: "Type \(typeName) not found")
                }
                guard let constructor = type.constructors[name] else {
                    throw CodeGenerationError(text: "Type \(typeName) not found")
                }
                elementSignature = Int32(bitPattern: constructor.id)
            case .boxedType:
                elementSignature = 0
            }

            if case .boxedVector = argument.type {
                writer.line("if let _ = reader.readInt32() {")
                writer.indent()
                writer.line("\(argumentAccessor) = Api.parseVector(reader, elementSignature: \(elementSignature), elementType: \(typeReferenceRepresentation(elementType)).self)")
                writer.dedent()
                writer.line("}")
            } else {
                writer.line("\(argumentAccessor) = Api.parseVector(reader, elementSignature: \(elementSignature), elementType: \(typeReferenceRepresentation(elementType)).self)")
            }
        case let .bareConstructor(typeName, name):
            guard let type = typeMap[typeName] else {
                throw CodeGenerationError(text: "Type \(typeName) not found")
            }
            guard let constructor = type.constructors[name] else {
                throw CodeGenerationError(text: "Type \(typeName) not found")
            }
            writer.line("\(argumentAccessor) = Api.parse(reader, signature: \(Int32(bitPattern: constructor.id)) as? \(typeReferenceRepresentation(argument.type))")
        case .boxedType:
            writer.line("if let signature = reader.readInt32() {")
            writer.indent()
            writer.line("\(argumentAccessor) = Api.parse(reader, signature: signature) as? \(typeReferenceRepresentation(argument.type))")
            writer.dedent()
            writer.line("}")
        }
    }
}
