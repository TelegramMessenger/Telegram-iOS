public struct ResolvedInterface: Equatable {
    public var name: String
    public var parent: String?
    public var parentIndex: Int?
    public var members: [Member]
    public var extendedAttributes: [ExtendedAttribute]
    /// Whether the global object gets an interface object (false for [LegacyNoInterfaceObject]).
    public var exposed: Bool
}

public struct ResolvedModel: Equatable {
    public var interfaces: [ResolvedInterface]
    public var dictionaries: [Dictionary]
    public var enums: [String: [String]]
    public var callbacks: [String: CallbackDefinition]
}

public func resolve(_ files: [[Definition]], file: String = "<idl>") throws -> ResolvedModel {
    func fail(_ message: String) -> IDLError {
        return IDLError(file: file, line: 0, message: message)
    }
    var interfaces: [String: Interface] = [:]
    var interfaceOrder: [String] = []
    var mixins: [String: Interface] = [:]
    var partials: [Interface] = []
    var includes: [(target: String, mixin: String)] = []
    var dictionaries: [String: Dictionary] = [:]
    var dictionaryOrder: [String] = []
    var partialDictionaries: [Dictionary] = []
    var typedefs: [String: IDLType] = [:]
    var enums: [String: [String]] = [:]
    var callbacks: [String: CallbackDefinition] = [:]

    for definitions in files {
        for definition in definitions {
            switch definition {
            case let .interface(i) where i.isPartial:
                partials.append(i)
            case let .interface(i) where i.isMixin:
                mixins[i.name] = i
            case let .interface(i):
                guard interfaces[i.name] == nil else {
                    throw fail("interface \(i.name) is defined twice")
                }
                interfaces[i.name] = i
                interfaceOrder.append(i.name)
            case let .includes(target, mixin):
                includes.append((target, mixin))
            case let .dictionary(d) where d.isPartial:
                partialDictionaries.append(d)
            case let .dictionary(d):
                dictionaries[d.name] = d
                dictionaryOrder.append(d.name)
            case let .typedef(name, type):
                typedefs[name] = type
            case let .enumeration(name, values):
                enums[name] = values
            case let .callback(c):
                callbacks[c.name] = c
            case .namespace:
                break
            }
        }
    }

    for partial in partials {
        if partial.isMixin {
            guard var mixin = mixins[partial.name] else {
                throw fail("partial interface mixin \(partial.name) has no definition")
            }
            mixin.members += partial.members
            mixins[partial.name] = mixin
        } else {
            guard var target = interfaces[partial.name] else {
                throw fail("partial interface \(partial.name) has no definition")
            }
            target.members += partial.members
            interfaces[partial.name] = target
        }
    }
    for (target, mixinName) in includes {
        guard var host = interfaces[target] else {
            throw fail("\(target) includes \(mixinName): no interface \(target)")
        }
        guard let mixin = mixins[mixinName] else {
            throw fail("\(target) includes \(mixinName): no mixin \(mixinName)")
        }
        host.members += mixin.members
        interfaces[target] = host
    }
    for partial in partialDictionaries {
        guard var target = dictionaries[partial.name] else {
            throw fail("partial dictionary \(partial.name) has no definition")
        }
        target.members += partial.members
        dictionaries[partial.name] = target
    }

    func resolveType(_ type: IDLType, _ seen: Set<String> = []) throws -> IDLType {
        switch type {
        case let .named(name):
            if let target = typedefs[name] {
                guard !seen.contains(name) else {
                    throw fail("typedef cycle at \(name)")
                }
                return try resolveType(target, seen.union([name]))
            }
            return type
        case let .sequence(t):
            return .sequence(try resolveType(t, seen))
        case let .frozenArray(t):
            return .frozenArray(try resolveType(t, seen))
        case let .observableArray(t):
            return .observableArray(try resolveType(t, seen))
        case let .promise(t):
            return .promise(try resolveType(t, seen))
        case let .record(k, v):
            return .record(try resolveType(k, seen), try resolveType(v, seen))
        case let .union(ts):
            return .union(try ts.map { try resolveType($0, seen) })
        case let .nullable(t):
            return .nullable(try resolveType(t, seen))
        case let .annotated(a, t):
            return .annotated(a, try resolveType(t, seen))
        default:
            return type
        }
    }

    func resolveArguments(_ arguments: [Argument]) throws -> [Argument] {
        return try arguments.map { argument in
            var a = argument
            a.type = try resolveType(a.type)
            return a
        }
    }

    func resolveMember(_ member: Member) throws -> Member {
        switch member {
        case let .constant(name, type, value, attributes):
            return .constant(name: name, type: try resolveType(type), value: value, extendedAttributes: attributes)
        case var .attribute(a):
            a.type = try resolveType(a.type)
            return .attribute(a)
        case var .operation(o):
            o.returnType = try resolveType(o.returnType)
            o.arguments = try resolveArguments(o.arguments)
            return .operation(o)
        case let .constructor(arguments, attributes):
            return .constructor(arguments: try resolveArguments(arguments), extendedAttributes: attributes)
        case let .iterable(key, value):
            return .iterable(key: try key.map { try resolveType($0) }, value: try resolveType(value))
        case .stringifier:
            return .stringifier
        }
    }

    // Parents first: a depth-first walk up each interface's chain, in definition order.
    var ordered: [String] = []
    var state: [String: Int] = [:] // 1 visiting, 2 done
    func visit(_ name: String) throws {
        if state[name] == 2 {
            return
        }
        guard state[name] != 1 else {
            throw fail("inheritance cycle at \(name)")
        }
        guard let i = interfaces[name] else {
            throw fail("unknown interface \(name)")
        }
        state[name] = 1
        if let parent = i.inherits {
            guard interfaces[parent] != nil else {
                throw fail("\(name) inherits from unknown \(parent)")
            }
            try visit(parent)
        }
        state[name] = 2
        ordered.append(name)
    }
    for name in interfaceOrder {
        try visit(name)
    }

    var index: [String: Int] = [:]
    var resolvedInterfaces: [ResolvedInterface] = []
    for name in ordered {
        let i = interfaces[name]!
        let members = try i.members.map(resolveMember)
        var seen: [String: Bool] = [:] // name -> is an operation
        for member in members {
            let memberName: String?
            let isOperation: Bool
            switch member {
            case let .constant(n, _, _, _):
                memberName = n
                isOperation = false
            case let .attribute(a):
                memberName = a.name
                isOperation = false
            case let .operation(o):
                memberName = o.name
                isOperation = true
            default:
                memberName = nil
                isOperation = false
            }
            guard let memberName else {
                continue
            }
            if let previous = seen[memberName], !(previous && isOperation) {
                throw fail("\(name).\(memberName) is defined twice")
            }
            seen[memberName] = isOperation
        }
        index[name] = resolvedInterfaces.count
        resolvedInterfaces.append(ResolvedInterface(
            name: name,
            parent: i.inherits,
            parentIndex: i.inherits.flatMap { index[$0] },
            members: members,
            extendedAttributes: i.extendedAttributes,
            exposed: !i.extendedAttributes.has("LegacyNoInterfaceObject")
        ))
    }

    func flatten(_ name: String, _ seen: Set<String> = []) throws -> [DictionaryMember] {
        guard let d = dictionaries[name] else {
            throw fail("unknown dictionary \(name)")
        }
        guard !seen.contains(name) else {
            throw fail("dictionary inheritance cycle at \(name)")
        }
        let inherited = try d.inherits.map { try flatten($0, seen.union([name])) } ?? []
        let own = try d.members.sorted { $0.name < $1.name }.map { member -> DictionaryMember in
            var m = member
            m.type = try resolveType(m.type)
            return m
        }
        return inherited + own
    }
    var resolvedDictionaries: [Dictionary] = []
    for name in dictionaryOrder {
        var d = dictionaries[name]!
        d.members = try flatten(name)
        d.inherits = nil
        resolvedDictionaries.append(d)
    }

    return ResolvedModel(interfaces: resolvedInterfaces, dictionaries: resolvedDictionaries, enums: enums, callbacks: callbacks)
}
