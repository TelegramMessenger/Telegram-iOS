/// The WebIDL model the parser produces and the resolver and emitter read.
public struct IDLError: Error, Equatable, CustomStringConvertible {
    public var file: String
    public var line: Int
    public var message: String

    public init(file: String, line: Int, message: String) {
        self.file = file
        self.line = line
        self.message = message
    }

    public var description: String {
        return "\(self.file):\(self.line): \(self.message)"
    }
}

public struct ExtendedAttribute: Equatable {
    public var name: String
    /// `B` in `[A=B]`, `B` in `[A=B(args)]`, `*` in `[A=*]`, `B, C` in `[A=(B, C)]`.
    public var value: String?
    /// The arguments of `[A(args)]` or `[A=B(args)]`.
    public var arguments: [Argument]?

    public init(name: String, value: String? = nil, arguments: [Argument]? = nil) {
        self.name = name
        self.value = value
        self.arguments = arguments
    }
}

public extension Array where Element == ExtendedAttribute {
    func has(_ name: String) -> Bool {
        return self.contains { $0.name == name }
    }

    func value(_ name: String) -> String? {
        return self.first { $0.name == name }?.value
    }
}

public indirect enum IDLType: Equatable {
    /// boolean, byte, octet, short, unsigned short, long, unsigned long, long long, unsigned long long, float,
    /// unrestricted float, double, unrestricted double, bigint.
    case primitive(String)
    /// DOMString, USVString, ByteString.
    case string(String)
    case any
    case object
    case undefined
    /// An interface, dictionary, enum, typedef or callback name.
    case named(String)
    case sequence(IDLType)
    case frozenArray(IDLType)
    case observableArray(IDLType)
    case promise(IDLType)
    case record(IDLType, IDLType)
    case union([IDLType])
    case nullable(IDLType)
    /// A type with extended attributes (`[LegacyNullToEmptyString] DOMString`).
    case annotated([ExtendedAttribute], IDLType)
}

public enum Literal: Equatable {
    case string(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case null
    case emptyDictionary
    case emptySequence
}

public struct Argument: Equatable {
    public var name: String
    public var type: IDLType
    public var optional: Bool
    public var variadic: Bool
    public var defaultValue: Literal?
    public var extendedAttributes: [ExtendedAttribute]
}

public struct Attribute: Equatable {
    public var name: String
    public var type: IDLType
    public var readonly: Bool
    public var isStatic: Bool
    public var stringifier: Bool
    public var inherit: Bool
    public var extendedAttributes: [ExtendedAttribute]
}

public enum Special: Equatable {
    case getter
    case setter
    case deleter
}

public struct Operation: Equatable {
    /// nil for an anonymous special operation (`getter DOMString (DOMString name);`).
    public var name: String?
    public var returnType: IDLType
    public var arguments: [Argument]
    public var special: Special?
    public var isStatic: Bool
    public var stringifier: Bool
    public var extendedAttributes: [ExtendedAttribute]
}

public enum Member: Equatable {
    case constant(name: String, type: IDLType, value: Literal, extendedAttributes: [ExtendedAttribute])
    case attribute(Attribute)
    case operation(Operation)
    case constructor(arguments: [Argument], extendedAttributes: [ExtendedAttribute])
    case iterable(key: IDLType?, value: IDLType)
    /// A bare `stringifier;`.
    case stringifier
}

public struct Interface: Equatable {
    public var name: String
    public var inherits: String?
    public var members: [Member]
    public var extendedAttributes: [ExtendedAttribute]
    public var isPartial: Bool
    public var isMixin: Bool
}

public struct DictionaryMember: Equatable {
    public var name: String
    public var type: IDLType
    public var required: Bool
    public var defaultValue: Literal?
    public var extendedAttributes: [ExtendedAttribute]
}

public struct Dictionary: Equatable {
    public var name: String
    public var inherits: String?
    public var members: [DictionaryMember]
    public var isPartial: Bool
}

/// `callback X = R (args);` (a callback function) or `callback interface X { … };`. The signature is not kept: the
/// runtime calls a callback with arguments it makes itself. Only the kind and the definition's own extended attributes
/// ([LegacyTreatNonObjectAsNull]) decide how a value converts.
public struct CallbackDefinition: Equatable {
    public var name: String
    public var isInterface: Bool
    public var extendedAttributes: [ExtendedAttribute]

    public init(name: String, isInterface: Bool, extendedAttributes: [ExtendedAttribute]) {
        self.name = name
        self.isInterface = isInterface
        self.extendedAttributes = extendedAttributes
    }
}

public enum Definition: Equatable {
    case interface(Interface)
    case includes(target: String, mixin: String)
    case dictionary(Dictionary)
    case typedef(name: String, type: IDLType)
    case enumeration(name: String, values: [String])
    /// `callback` and `callback interface`: a value of the type converts to wr::Callback, wr::LegacyCallback or
    /// wr::CallbackInterface (Sources/Support/Callbacks.h).
    case callback(CallbackDefinition)
    /// Parsed so the files read, never bound.
    case namespace(name: String)
}
