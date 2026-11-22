import Foundation

/// Emits `SchemaFixtures.swift` for the TelegramApi tests: deterministic values for every constructor
/// (all optionals present / all absent) and a call of every function, which the accessor-probe and leak
/// tests run through every path.
enum FixtureGenerator {
    struct FixtureError: Error, CustomStringConvertible {
        var text: String
        var description: String { return self.text }
    }

    private enum Variant {
        case full
        case minimal
    }

    private struct Seed {
        var next = 0
        var usedLongString = false
        var usedLongBytes = false

        mutating func advance() -> Int {
            self.next += 1
            return self.next
        }
    }

    static func helperName(_ name: QualifiedName) -> String {
        return "fx_" + name.description.replacingOccurrences(of: ".", with: "_")
    }

    static func bareHelperName(_ typeName: QualifiedName, _ constructorName: QualifiedName) -> String {
        return "fxc_" + typeName.description.replacingOccurrences(of: ".", with: "_") + "_" + constructorName.value
    }

    private static func storedArguments(_ arguments: [Resolver.Argument]) -> [Resolver.Argument] {
        return arguments.filter { if case .boolTrue = $0.type { return false } else { return true } }
    }

    /// Cheapest constructor per type: required object fields cost their type's cost,
    /// optionals are absent and vectors are empty in a minimal value. Strictly decreasing
    /// costs along any chain guarantee the helpers never recurse forever.
    private static func minimalConstructors(_ types: [Resolver.SumType]) throws -> [QualifiedName: Resolver.SumType.Constructor] {
        var cost: [QualifiedName: Int] = [:]
        var chosen: [QualifiedName: Resolver.SumType.Constructor] = [:]
        var changed = true
        while changed {
            changed = false
            for type in types {
                for constructor in type.constructors.values.sorted(by: { $0.name < $1.name }) {
                    var total = 1
                    var resolvable = true
                    for argument in storedArguments(constructor.arguments) where argument.condition == nil {
                        switch argument.type {
                        case let .boxedType(name), let .bareConstructor(name, _):
                            if let value = cost[name] {
                                total += value
                            } else {
                                resolvable = false
                            }
                        default:
                            break
                        }
                    }
                    if resolvable, cost[type.name].map({ total < $0 }) ?? true {
                        cost[type.name] = total
                        chosen[type.name] = constructor
                        changed = true
                    }
                }
            }
        }
        for type in types where chosen[type.name] == nil {
            throw FixtureError(text: "no finite value for type \(type.name)")
        }
        return chosen
    }

    private static func value(_ apiPrefix: String, _ type: Resolver.TypeReference, _ variant: Variant, _ seed: inout Seed) throws -> String {
        switch type {
        case .int32:
            let n = seed.advance()
            return "Int32(\(n * 37 % 2001 - 1000))"
        case .int64:
            let n = seed.advance()
            return "Int64(\(Int64(n) * 1_000_003 + (1 << 40)))"
        case .double:
            let n = seed.advance()
            return "Double(\(n)) + 0.25"
        case .int256:
            return "Int256(_0: 1, _1: -2, _2: 3, _3: Int64.max)"
        case .string:
            if variant == .minimal {
                return "\"\""
            }
            if !seed.usedLongString {
                seed.usedLongString = true
                return "String(repeating: \"aü🙂\", count: 100) + \"b\""
            }
            return "\"s\(seed.advance())\""
        case .bytes:
            if variant == .minimal {
                return "Buffer()"
            }
            if !seed.usedLongBytes {
                seed.usedLongBytes = true
                return "Buffer(data: Data((0 ..< 301).map { UInt8(truncatingIfNeeded: $0) }))"
            }
            return "Buffer(data: Data([\(seed.advance() & 0xff), 0, 255]))"
        case let .boxedType(name):
            return "\(helperName(name))()"
        case let .bareConstructor(typeName, constructorName):
            return "\(bareHelperName(typeName, constructorName))()"
        case let .bareVector(element), let .boxedVector(element):
            if variant == .minimal {
                return "[]"
            }
            let first = try value(apiPrefix, element, .full, &seed)
            let second = try value(apiPrefix, element, .full, &seed)
            return "[\(first), \(second)]"
        case .bool, .boolTrue:
            throw FixtureError(text: "unsupported field type \(type)")
        }
    }

    private static func argumentList(_ apiPrefix: String, _ arguments: [Resolver.Argument], _ variant: Variant, _ seed: inout Seed) throws -> String {
        var masks: [String: UInt32] = [:]
        for argument in arguments {
            if let condition = argument.condition {
                masks[condition.fieldName, default: 0] |= UInt32(1) << UInt32(condition.bitIndex)
            }
        }
        var parts: [String] = []
        for argument in storedArguments(arguments) {
            let label = argument.name.camelCased
            let expression: String
            if argument.condition != nil && variant == .minimal {
                expression = "nil"
            } else if let mask = masks[argument.name] {
                expression = variant == .full ? "Int32(bitPattern: UInt32(\(mask)))" : "0"
            } else {
                expression = try value(apiPrefix, argument.type, variant, &seed)
            }
            parts.append("\(label): \(expression)")
        }
        return parts.joined(separator: ", ")
    }

    private static func constructorExpression(_ apiPrefix: String, _ typeName: QualifiedName, _ constructor: Resolver.SumType.Constructor, _ variant: Variant) throws -> String {
        let prefix = "\(apiPrefix).\(typeName).\(constructor.name.value)"
        if storedArguments(constructor.arguments).isEmpty {
            return prefix
        }
        var seed = Seed(next: Int(constructor.id % 997))
        let arguments = try argumentList(apiPrefix, constructor.arguments, variant, &seed)
        return "\(prefix)(\(apiPrefix).\(typeName).Cons_\(constructor.name.value)(\(arguments)))"
    }

    private static func resultBytes(_ result: Resolver.TypeReference) throws -> String {
        var lines = ["let b = Buffer()"]
        func element(_ type: Resolver.TypeReference, _ index: Int) throws -> String {
            switch type {
            case .int32: return index == 0 ? "b.appendInt32(7)" : "b.appendInt32(-8)"
            case .int64: return index == 0 ? "b.appendInt64(9)" : "b.appendInt64(-10)"
            case .string: return "serializeString(\"r\(index)\", buffer: b, boxed: false)"
            case let .boxedType(name): return "\(helperName(name))().serialize(b, true)"
            default: throw FixtureError(text: "unsupported result element \(type)")
            }
        }
        switch result {
        case let .boxedType(name):
            lines.append("\(helperName(name))().serialize(b, true)")
        case let .boxedVector(elementType):
            lines.append("b.appendInt32(481674261)")
            lines.append("b.appendInt32(2)")
            lines.append(try element(elementType, 0))
            lines.append(try element(elementType, 1))
        default:
            throw FixtureError(text: "unsupported function result \(result)")
        }
        lines.append("return b")
        return lines.joined(separator: "; ")
    }

    static func generate(apiPrefix: String, types: [Resolver.SumType], functions: [Resolver.Function]) throws -> String {
        let sortedTypes = types.sorted(by: { $0.name < $1.name })
        let minimal = try minimalConstructors(sortedTypes)

        var out = """
        // Generated by SwiftTL from the schema. Do not edit.
        // Deterministic values for every constructor and a call of every function, built only
        // through APIs that exist both before and after the table-driven engine.
        import Foundation
        @testable import TelegramApi

        struct SchemaConstructorFixture {
            let name: String
            let make: () -> Any
        }

        struct SchemaFunctionFixture {
            let name: String
            let make: () -> (FunctionDescription, Buffer, (Buffer) -> Any?)
            let resultBytes: () -> Buffer
        }


        """

        for type in sortedTypes {
            out += "func \(helperName(type.name))() -> \(apiPrefix).\(type.name) {\n"
            out += "    return \(try constructorExpression(apiPrefix, type.name, minimal[type.name]!, .minimal))\n"
            out += "}\n\n"
        }

        var bareUses: Set<String> = []
        var bareHelpers = ""
        func collectBare(_ type: Resolver.TypeReference) throws {
            switch type {
            case let .bareConstructor(typeName, constructorName):
                let name = bareHelperName(typeName, constructorName)
                guard !bareUses.contains(name), let owner = sortedTypes.first(where: { $0.name == typeName }), let constructor = owner.constructors[constructorName] else { return }
                bareUses.insert(name)
                bareHelpers += "func \(name)() -> \(apiPrefix).\(typeName) {\n    return \(try constructorExpression(apiPrefix, typeName, constructor, .minimal))\n}\n\n"
            case let .bareVector(element), let .boxedVector(element):
                try collectBare(element)
            default:
                break
            }
        }
        for type in sortedTypes {
            for constructor in type.constructors.values.sorted(by: { $0.name < $1.name }) {
                for argument in constructor.arguments {
                    try collectBare(argument.type)
                }
            }
        }
        for function in functions {
            for argument in function.arguments {
                try collectBare(argument.type)
            }
        }
        out += bareHelpers

        var constructorLines: [String] = []
        for type in sortedTypes {
            for constructor in type.constructors.values.sorted(by: { $0.name < $1.name }) {
                let base = "\(type.name).\(constructor.name.value)"
                if storedArguments(constructor.arguments).isEmpty {
                    constructorLines.append("f.append(SchemaConstructorFixture(name: \"\(base)\", make: { \(try constructorExpression(apiPrefix, type.name, constructor, .full)) }))")
                } else {
                    constructorLines.append("f.append(SchemaConstructorFixture(name: \"\(base)#full\", make: { \(try constructorExpression(apiPrefix, type.name, constructor, .full)) }))")
                    constructorLines.append("f.append(SchemaConstructorFixture(name: \"\(base)#empty\", make: { \(try constructorExpression(apiPrefix, type.name, constructor, .minimal)) }))")
                }
            }
        }

        var functionLines: [String] = []
        for function in functions.sorted(by: { $0.name < $1.name }) {
            let path = "\(apiPrefix).functions" + (function.name.namespace.map { ".\($0)" } ?? "") + ".\(function.name.value)"
            let results = try resultBytes(function.result)
            for (suffix, variant) in [("full", Variant.full), ("empty", Variant.minimal)] {
                var seed = Seed(next: Int(function.id % 997))
                let arguments = try argumentList(apiPrefix, function.arguments, variant, &seed)
                functionLines.append("f.append(SchemaFunctionFixture(name: \"\(function.name)#\(suffix)\", make: {\n        let call = \(path)(\(arguments))\n        return (call.0, call.1, { call.2.parse($0) })\n    }, resultBytes: { \(results) }))")
            }
        }

        func chunked(_ lines: [String], _ fixtureType: String, _ prefix: String) -> String {
            var text = ""
            var names: [String] = []
            for (index, start) in stride(from: 0, to: lines.count, by: 200).enumerated() {
                let name = "\(prefix)\(index)"
                names.append(name)
                text += "func \(name)() -> [\(fixtureType)] {\n    var f: [\(fixtureType)] = []\n"
                for line in lines[start ..< min(start + 200, lines.count)] {
                    text += "    \(line)\n"
                }
                text += "    return f\n}\n\n"
            }
            text += "func all\(prefix.prefix(1).uppercased() + prefix.dropFirst())() -> [\(fixtureType)] {\n    var all: [\(fixtureType)] = []\n"
            for name in names {
                text += "    all += \(name)()\n"
            }
            text += "    return all\n}\n\n"
            return text
        }
        out += chunked(constructorLines, "SchemaConstructorFixture", "schemaConstructorFixtures")
        out += chunked(functionLines, "SchemaFunctionFixture", "schemaFunctionFixtures")
        out += "let schemaConstructorFixtures: [SchemaConstructorFixture] = allSchemaConstructorFixtures()\n"
        out += "let schemaFunctionFixtures: [SchemaFunctionFixture] = allSchemaFunctionFixtures()\n"
        return out
    }
}
