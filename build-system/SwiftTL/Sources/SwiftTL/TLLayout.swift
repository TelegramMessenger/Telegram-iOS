import Foundation

enum TLKind: Equatable {
    case int32, int64, int256, double, string, bytes, object, vector

    var cEnumName: String {
        switch self {
        case .int32: return "TLFieldKindInt32"
        case .int64: return "TLFieldKindInt64"
        case .int256: return "TLFieldKindInt256"
        case .double: return "TLFieldKindDouble"
        case .string: return "TLFieldKindString"
        case .bytes: return "TLFieldKindBytes"
        case .object: return "TLFieldKindObject"
        case .vector: return "TLFieldKindVector"
        }
    }

    var isScalar: Bool {
        switch self {
        case .int32, .int64, .int256, .double: return true
        default: return false
        }
    }
}

struct TLFieldLayout {
    var swiftName: String          // camelCased, unescaped: "gB", "protocol", "id"
    var descriptionName: String    // camelCasedAndEscaped: what descriptionFields() prints
    var objcName: String           // objcFieldName(for: swiftName)
    var kind: TLKind
    var elementKind: TLKind?       // vectors only
    var isBoxedVector: Bool
    var isOptional: Bool
    var flagsFieldIndex: Int?      // index into `fields` of the controlling flags field
    var flagBit: Int
    var presenceBit: Int?          // optional scalars only
    var objectType: QualifiedName? // object fields and vector<object> elements
    var bareConstructorIndex: Int? // bare-constructor fields/elements: the fixed constructor's case index
    var swiftType: String          // today's Swift type incl. "?", e.g. "[Api.User]?"
    var offset: Int = 0            // storage offset (see TLSchemaLayout.storageLayout)

    var ivarName: String {
        return "_" + objcName
    }

    /// Swift cannot bridge the ObjC property type to today's Swift type, so the property
    /// is NS_REFINED_FOR_SWIFT and a generated getter/initializer converts it.
    var needsSwiftConversion: Bool {
        switch kind {
        case .int256:
            return true
        case .int32, .int64, .double:
            return isOptional
        case .string:
            return false
        case .bytes, .object:
            return true
        case .vector:
            return elementKind != .string
        }
    }
}

struct TLConstructorLayout {
    var constructor: Resolver.SumType.Constructor
    var typeName: QualifiedName
    var typeIndex: Int
    var caseIndex: Int
    var objcClassName: String      // "TLApi_Peer_peerUser"
    var fields: [TLFieldLayout]    // `flags.N?true` arguments excluded
    var hasPresent: Bool           // has optional scalars → `present` bitmask
    var instanceSize: Int
    var presentOffset: Int         // -1 without a presence mask

    var isDirectlyImported: Bool {
        return !fields.isEmpty && !fields.contains(where: \.needsSwiftConversion)
    }
}

struct TLFunctionLayout {
    var function: Resolver.Function
    var objcClassName: String       // "TLApiFunction_messages_sendReaction"
    var fields: [TLFieldLayout]     // arguments, `flags.N?true` excluded
    var hasPresent: Bool
    var instanceSize: Int
    var presentOffset: Int
    var result: TLFieldLayout       // swiftName "result"
}

struct TLTypeLayout {
    var type: Resolver.SumType
    var typeIndex: Int
    var objcClassName: String      // "TLApi_Peer"
    var constructors: [TLConstructorLayout]   // in case order (sorted by name)

    var payloadCaseCount: Int {
        return constructors.filter { !$0.fields.isEmpty }.count
    }
}

struct TLSchemaLayout {
    var apiPrefix: String
    var classPrefix: String        // "TL" + apiPrefix
    var types: [TLTypeLayout]      // sorted by type name; index == typeIndex
    var functions: [TLFunctionLayout] = []   // sorted by name

    struct LayoutError: Error, CustomStringConvertible {
        var text: String
        var description: String { return self.text }
    }

    static func className(prefix: String, _ name: QualifiedName) -> String {
        return "\(prefix)_" + name.description.replacingOccurrences(of: ".", with: "_")
    }

    func className(for name: QualifiedName) -> String {
        return TLSchemaLayout.className(prefix: self.classPrefix, name)
    }

    static let headerSize = 24

    /// The layout clang gives today's synthesized ivars, so stage 1 can verify it against the
    /// runtime: int32 fields first, then everything else (8-aligned, int256 32 bytes), each
    /// group in schema order, then the presence mask. `fields` keeps schema order.
    static func storageLayout(_ fields: inout [TLFieldLayout], hasPresent: Bool) -> (instanceSize: Int, presentOffset: Int) {
        var offset = headerSize
        func place(_ size: Int, _ alignment: Int) -> Int {
            offset = (offset + alignment - 1) / alignment * alignment
            let placed = offset
            offset += size
            return placed
        }
        for index in fields.indices where fields[index].kind == .int32 {
            fields[index].offset = place(4, 4)
        }
        for index in fields.indices where fields[index].kind != .int32 {
            fields[index].offset = place(fields[index].kind == .int256 ? 32 : 8, 8)
        }
        let presentOffset = hasPresent ? place(8, 8) : -1
        return ((offset + 7) / 8 * 8, presentOffset)
    }

    static func fieldLayouts(apiPrefix: String, arguments: [Resolver.Argument], context: String, allowInt256: Bool, sortedTypes: [Resolver.SumType]) throws -> (fields: [TLFieldLayout], hasPresent: Bool) {
        let stored = arguments.filter { if case .boolTrue = $0.type { return false } else { return true } }
        var fields: [TLFieldLayout] = []
        var nextPresenceBit = 0
        for argument in stored {
            let isOptional = argument.condition != nil
            var flagsFieldIndex: Int?
            var flagBit = 0
            if let condition = argument.condition {
                guard let index = stored.firstIndex(where: { $0.name == condition.fieldName }) else {
                    throw LayoutError(text: "\(context): condition field \(condition.fieldName) not found")
                }
                flagsFieldIndex = index
                flagBit = condition.bitIndex
            }
            let (kind, elementKind, isBoxedVector, objectType, bareConstructor) = try classify(argument.type, context: "\(context).\(argument.name)", allowInt256: allowInt256)
            var bareConstructorIndex: Int?
            if let bareConstructor = bareConstructor, let objectType = objectType {
                guard let referenced = sortedTypes.first(where: { $0.name == objectType }),
                      let index = referenced.constructors.values.sorted(by: { $0.name < $1.name }).firstIndex(where: { $0.name == bareConstructor }) else {
                    throw LayoutError(text: "\(context).\(argument.name): bare constructor \(bareConstructor) not found")
                }
                bareConstructorIndex = index
            }
            var presenceBit: Int?
            if isOptional && kind.isScalar {
                presenceBit = nextPresenceBit
                nextPresenceBit += 1
                if nextPresenceBit > 64 {
                    throw LayoutError(text: "\(context): more than 64 optional scalar fields")
                }
            }
            let swiftName = argument.name.camelCased
            fields.append(TLFieldLayout(
                swiftName: swiftName,
                descriptionName: argument.name.camelCasedAndEscaped,
                objcName: objcFieldName(for: swiftName),
                kind: kind,
                elementKind: elementKind,
                isBoxedVector: isBoxedVector,
                isOptional: isOptional,
                flagsFieldIndex: flagsFieldIndex,
                flagBit: flagBit,
                presenceBit: presenceBit,
                objectType: objectType,
                bareConstructorIndex: bareConstructorIndex,
                swiftType: swiftTypeRepresentation(apiPrefix, argument.type) + (isOptional ? "?" : "")
            ))
        }
        return (fields, nextPresenceBit > 0)
    }

    static func build(apiPrefix: String, types: [Resolver.SumType], functions: [Resolver.Function] = []) throws -> TLSchemaLayout {
        let classPrefix = "TL\(apiPrefix)"
        let sortedTypes = types.sorted(by: { $0.name < $1.name })
        var typeLayouts: [TLTypeLayout] = []
        for (typeIndex, type) in sortedTypes.enumerated() {
            let objcClassName = className(prefix: classPrefix, type.name)
            var constructors: [TLConstructorLayout] = []
            for (caseIndex, constructor) in type.constructors.values.sorted(by: { $0.name < $1.name }).enumerated() {
                var (fields, hasPresent) = try fieldLayouts(apiPrefix: apiPrefix, arguments: constructor.arguments, context: "\(constructor.name)", allowInt256: false, sortedTypes: sortedTypes)
                let storage = storageLayout(&fields, hasPresent: hasPresent)
                constructors.append(TLConstructorLayout(
                    constructor: constructor,
                    typeName: type.name,
                    typeIndex: typeIndex,
                    caseIndex: caseIndex,
                    objcClassName: "\(objcClassName)_\(constructor.name.value)",
                    fields: fields,
                    hasPresent: hasPresent,
                    instanceSize: storage.instanceSize,
                    presentOffset: storage.presentOffset
                ))
            }
            typeLayouts.append(TLTypeLayout(type: type, typeIndex: typeIndex, objcClassName: objcClassName, constructors: constructors))
        }
        var functionLayouts: [TLFunctionLayout] = []
        var seenFunctions: Set<QualifiedName> = []
        for function in functions.sorted(by: { $0.name < $1.name }) where seenFunctions.insert(function.name).inserted {
            let context = "\(function.name)"
            var (fields, hasPresent) = try fieldLayouts(apiPrefix: apiPrefix, arguments: function.arguments, context: context, allowInt256: true, sortedTypes: sortedTypes)
            let storage = storageLayout(&fields, hasPresent: hasPresent)
            let resultArgument = Resolver.Argument(name: "result", type: function.result, condition: nil)
            let (resultFields, _) = try fieldLayouts(apiPrefix: apiPrefix, arguments: [resultArgument], context: context, allowInt256: false, sortedTypes: sortedTypes)
            functionLayouts.append(TLFunctionLayout(
                function: function,
                objcClassName: "\(classPrefix)Function_" + function.name.description.replacingOccurrences(of: ".", with: "_"),
                fields: fields,
                hasPresent: hasPresent,
                instanceSize: storage.instanceSize,
                presentOffset: storage.presentOffset,
                result: resultFields[0]
            ))
        }
        return TLSchemaLayout(apiPrefix: apiPrefix, classPrefix: classPrefix, types: typeLayouts, functions: functionLayouts)
    }

    /// (kind, elementKind, isBoxedVector, objectType, bareConstructorName)
    private static func classify(_ type: Resolver.TypeReference, context: String, allowInt256: Bool) throws -> (TLKind, TLKind?, Bool, QualifiedName?, QualifiedName?) {
        switch type {
        case .int256 where allowInt256: return (.int256, nil, false, nil, nil)
        case .int32: return (.int32, nil, false, nil, nil)
        case .int64: return (.int64, nil, false, nil, nil)
        case .double: return (.double, nil, false, nil, nil)
        case .string: return (.string, nil, false, nil, nil)
        case .bytes: return (.bytes, nil, false, nil, nil)
        case let .boxedType(name): return (.object, nil, false, name, nil)
        case let .bareConstructor(typeName, name): return (.object, nil, false, typeName, name)
        case let .bareVector(element), let .boxedVector(element):
            let isBoxed: Bool
            if case .boxedVector = type { isBoxed = true } else { isBoxed = false }
            switch element {
            case .int32: return (.vector, .int32, isBoxed, nil, nil)
            case .int64: return (.vector, .int64, isBoxed, nil, nil)
            case .string: return (.vector, .string, isBoxed, nil, nil)
            case .bytes: return (.vector, .bytes, isBoxed, nil, nil)
            case let .boxedType(name): return (.vector, .object, isBoxed, name, nil)
            case let .bareConstructor(typeName, name): return (.vector, .object, isBoxed, typeName, name)
            default:
                throw LayoutError(text: "\(context): unsupported vector element type in a constructor")
            }
        case .int256, .bool, .boolTrue:
            throw LayoutError(text: "\(context): unsupported field type in a constructor (\(type))")
        }
    }

    func typeLayout(for typeName: QualifiedName) -> TLTypeLayout {
        return self.types.first(where: { $0.type.name == typeName })!
    }

    func constructorLayout(for typeName: QualifiedName, constructorName: String) -> TLConstructorLayout {
        return self.typeLayout(for: typeName).constructors.first(where: { $0.constructor.name.value == constructorName })!
    }
}

/// Mirrors CodeGeneration.swift's typeReferenceRepresentation for field types.
func swiftTypeRepresentation(_ apiPrefix: String, _ type: Resolver.TypeReference) -> String {
    switch type {
    case .int32: return "Int32"
    case .int64: return "Int64"
    case .int256: return "Int256"
    case .double: return "Double"
    case .bytes: return "Buffer"
    case .string: return "String"
    case .bool: return "Bool"
    case .boolTrue: return "bool"
    case let .bareVector(element), let .boxedVector(element): return "[\(swiftTypeRepresentation(apiPrefix, element))]"
    case let .bareConstructor(typeName, _), let .boxedType(typeName): return "\(apiPrefix).\(typeName)"
    }
}
