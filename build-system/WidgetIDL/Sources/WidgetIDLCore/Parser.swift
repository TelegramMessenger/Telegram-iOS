/// Parses one WebIDL file. See Task 4 of the M1a plan for the grammar covered.
public func parseIDL(_ source: String, file: String) throws -> [Definition] {
    var parser = Parser(tokens: try tokenize(source, file: file), file: file)
    return try parser.definitions()
}

private let primitiveStarts: Set<String> = ["boolean", "byte", "octet", "short", "long", "unsigned", "float", "double", "unrestricted", "bigint"]
private let stringTypes: Set<String> = ["DOMString", "USVString", "ByteString"]

struct Parser {
    var tokens: [Token]
    var position = 0
    let file: String

    init(tokens: [Token], file: String) {
        self.tokens = tokens
        self.file = file
    }

    // MARK: tokens

    var current: Token {
        return self.tokens[self.position]
    }

    func error(_ message: String) -> IDLError {
        return IDLError(file: self.file, line: self.current.line, message: message)
    }

    func peek(_ text: String, offset: Int = 0) -> Bool {
        let i = self.position + offset
        return i < self.tokens.count && self.tokens[i].kind != .string && self.tokens[i].text == text
    }

    @discardableResult
    mutating func advance() -> Token {
        let token = self.current
        if token.kind != .end {
            self.position += 1
        }
        return token
    }

    mutating func accept(_ text: String) -> Bool {
        if self.peek(text) {
            self.advance()
            return true
        }
        return false
    }

    mutating func expect(_ text: String) throws {
        guard self.accept(text) else {
            throw self.error("expected '\(text)', found '\(self.current.text)'")
        }
    }

    mutating func identifier() throws -> String {
        guard self.current.kind == .identifier else {
            throw self.error("expected an identifier, found '\(self.current.text)'")
        }
        return self.advance().text
    }

    // MARK: definitions

    mutating func definitions() throws -> [Definition] {
        var result: [Definition] = []
        while self.current.kind != .end {
            let attributes = try self.extendedAttributeList()
            result.append(try self.definition(attributes))
        }
        return result
    }

    mutating func definition(_ attributes: [ExtendedAttribute]) throws -> Definition {
        if self.accept("callback") {
            if self.accept("interface") {
                let name = try self.identifier()
                try self.skipBlock()
                try self.expect(";")
                return .callback(CallbackDefinition(name: name, isInterface: true, extendedAttributes: attributes))
            }
            let name = try self.identifier()
            try self.expect("=")
            _ = try self.type()
            try self.expect("(")
            _ = try self.argumentList()
            try self.expect(")")
            try self.expect(";")
            return .callback(CallbackDefinition(name: name, isInterface: false, extendedAttributes: attributes))
        }
        let partial = self.accept("partial")
        if self.accept("interface") {
            let mixin = self.accept("mixin")
            let name = try self.identifier()
            var inherits: String?
            if !mixin && !partial && self.accept(":") {
                inherits = try self.identifier()
            }
            try self.expect("{")
            var members: [Member] = []
            while !self.accept("}") {
                let memberAttributes = try self.extendedAttributeList()
                members.append(try self.member(memberAttributes))
            }
            try self.expect(";")
            return .interface(Interface(name: name, inherits: inherits, members: members, extendedAttributes: attributes, isPartial: partial, isMixin: mixin))
        }
        if self.accept("dictionary") {
            let name = try self.identifier()
            var inherits: String?
            if !partial && self.accept(":") {
                inherits = try self.identifier()
            }
            try self.expect("{")
            var members: [DictionaryMember] = []
            while !self.accept("}") {
                let memberAttributes = try self.extendedAttributeList()
                let required = self.accept("required")
                let type = try self.type()
                let memberName = try self.identifier()
                var defaultValue: Literal?
                if self.accept("=") {
                    defaultValue = try self.literal()
                }
                try self.expect(";")
                members.append(DictionaryMember(name: memberName, type: type, required: required, defaultValue: defaultValue, extendedAttributes: memberAttributes))
            }
            try self.expect(";")
            return .dictionary(Dictionary(name: name, inherits: inherits, members: members, isPartial: partial))
        }
        if partial {
            throw self.error("expected 'interface' or 'dictionary' after 'partial'")
        }
        if self.accept("namespace") {
            let name = try self.identifier()
            try self.skipBlock()
            try self.expect(";")
            return .namespace(name: name)
        }
        if self.accept("typedef") {
            let type = try self.type()
            let name = try self.identifier()
            try self.expect(";")
            return .typedef(name: name, type: type)
        }
        if self.accept("enum") {
            let name = try self.identifier()
            try self.expect("{")
            var values: [String] = []
            while !self.accept("}") {
                guard self.current.kind == .string else {
                    throw self.error("expected a string in enum \(name)")
                }
                values.append(self.advance().text)
                _ = self.accept(",")
            }
            try self.expect(";")
            return .enumeration(name: name, values: values)
        }
        let target = try self.identifier()
        if self.accept("includes") {
            let mixin = try self.identifier()
            try self.expect(";")
            return .includes(target: target, mixin: mixin)
        }
        throw self.error("unexpected '\(target)'")
    }

    /// Skips a `{ … }` block with nesting (callback interfaces and namespaces are never bound).
    mutating func skipBlock() throws {
        try self.expect("{")
        var depth = 1
        while depth > 0 {
            guard self.current.kind != .end else {
                throw self.error("unterminated block")
            }
            let token = self.advance()
            if token.kind == .punctuation && token.text == "{" {
                depth += 1
            } else if token.kind == .punctuation && token.text == "}" {
                depth -= 1
            }
        }
    }

    // MARK: members

    mutating func member(_ attributes: [ExtendedAttribute]) throws -> Member {
        if self.peek("maplike") || self.peek("setlike") || (self.peek("async") && self.peek("iterable", offset: 1)) {
            throw self.error("'\(self.current.text)' is not supported")
        }
        if self.accept("const") {
            let type = try self.type()
            let name = try self.identifier()
            try self.expect("=")
            let value = try self.literal()
            try self.expect(";")
            return .constant(name: name, type: type, value: value, extendedAttributes: attributes)
        }
        if self.accept("constructor") {
            try self.expect("(")
            let arguments = try self.argumentList()
            try self.expect(")")
            try self.expect(";")
            return .constructor(arguments: arguments, extendedAttributes: attributes)
        }
        if self.accept("iterable") {
            try self.expect("<")
            let first = try self.type()
            var second: IDLType?
            if self.accept(",") {
                second = try self.type()
            }
            try self.expect(">")
            try self.expect(";")
            if let second {
                return .iterable(key: first, value: second)
            }
            return .iterable(key: nil, value: first)
        }
        if self.peek("stringifier") && self.peek(";", offset: 1) {
            self.advance()
            self.advance()
            return .stringifier
        }
        let isStatic = self.accept("static")
        let stringifier = self.accept("stringifier")
        let inherit = self.accept("inherit")
        let readonly = self.accept("readonly")
        if self.accept("attribute") {
            let type = try self.type()
            let name = try self.identifier()
            try self.expect(";")
            return .attribute(Attribute(name: name, type: type, readonly: readonly, isStatic: isStatic, stringifier: stringifier, inherit: inherit, extendedAttributes: attributes))
        }
        if readonly || inherit {
            throw self.error("expected 'attribute'")
        }
        var special: Special?
        if self.accept("getter") {
            special = .getter
        } else if self.accept("setter") {
            special = .setter
        } else if self.accept("deleter") {
            special = .deleter
        }
        let returnType = try self.type()
        var name: String?
        if self.current.kind == .identifier {
            name = self.advance().text
        }
        try self.expect("(")
        let arguments = try self.argumentList()
        try self.expect(")")
        try self.expect(";")
        if name == nil && special == nil && !stringifier {
            throw self.error("an operation needs a name")
        }
        return .operation(Operation(name: name, returnType: returnType, arguments: arguments, special: special, isStatic: isStatic, stringifier: stringifier, extendedAttributes: attributes))
    }

    /// WebIDL's extended attributes that apply to types (an argument's carry over to its type).
    static let typeExtendedAttributes: Set<String> = ["AllowResizable", "AllowShared", "Clamp", "EnforceRange", "LegacyNullToEmptyString"]

    mutating func argumentList() throws -> [Argument] {
        var arguments: [Argument] = []
        if self.peek(")") {
            return arguments
        }
        repeat {
            let attributes = try self.extendedAttributeList()
            let optional = self.accept("optional")
            let type = try self.type()
            let variadic = !optional && self.accept("...")
            // Argument names may be keywords (`namespace`, `interface`, `required`, …): any identifier will do.
            let name = try self.identifier()
            var defaultValue: Literal?
            if optional && self.accept("=") {
                defaultValue = try self.literal()
            }
            // WebIDL: the extended attributes that apply to types, written on the argument, apply to its type.
            let typeAttributes = attributes.filter { Parser.typeExtendedAttributes.contains($0.name) }
            let argumentType: IDLType = typeAttributes.isEmpty ? type : .annotated(typeAttributes, type)
            let argumentAttributes = attributes.filter { !Parser.typeExtendedAttributes.contains($0.name) }
            arguments.append(Argument(name: name, type: argumentType, optional: optional, variadic: variadic, defaultValue: defaultValue, extendedAttributes: argumentAttributes))
        } while self.accept(",")
        return arguments
    }

    // MARK: types

    mutating func type() throws -> IDLType {
        if self.peek("[") {
            let attributes = try self.extendedAttributeList()
            return .annotated(attributes, try self.type())
        }
        var base: IDLType
        if self.accept("(") {
            var alternatives = [try self.type()]
            while self.accept("or") {
                alternatives.append(try self.type())
            }
            try self.expect(")")
            base = .union(alternatives)
        } else {
            base = try self.nonUnionType()
        }
        if self.accept("?") {
            base = .nullable(base)
        }
        return base
    }

    mutating func nonUnionType() throws -> IDLType {
        let word = try self.identifier()
        if primitiveStarts.contains(word) {
            switch word {
            case "unsigned":
                let next = try self.identifier()
                if next == "long" && self.accept("long") {
                    return .primitive("unsigned long long")
                }
                guard next == "short" || next == "long" else {
                    throw self.error("expected 'short' or 'long' after 'unsigned'")
                }
                return .primitive("unsigned \(next)")
            case "unrestricted":
                let next = try self.identifier()
                guard next == "float" || next == "double" else {
                    throw self.error("expected 'float' or 'double' after 'unrestricted'")
                }
                return .primitive("unrestricted \(next)")
            case "long":
                return self.accept("long") ? .primitive("long long") : .primitive("long")
            default:
                return .primitive(word)
            }
        }
        if stringTypes.contains(word) {
            return .string(word)
        }
        switch word {
        case "any":
            return .any
        case "object":
            return .object
        case "undefined":
            return .undefined
        case "sequence", "FrozenArray", "ObservableArray", "Promise":
            try self.expect("<")
            let inner = try self.type()
            try self.expect(">")
            switch word {
            case "sequence":
                return .sequence(inner)
            case "FrozenArray":
                return .frozenArray(inner)
            case "ObservableArray":
                return .observableArray(inner)
            default:
                return .promise(inner)
            }
        case "record":
            try self.expect("<")
            let key = try self.type()
            try self.expect(",")
            let value = try self.type()
            try self.expect(">")
            return .record(key, value)
        default:
            return .named(word)
        }
    }

    // MARK: literals and extended attributes

    mutating func literal() throws -> Literal {
        let token = self.current
        switch token.kind {
        case .string:
            self.advance()
            return .string(token.text)
        case .integer:
            self.advance()
            let negative = token.text.hasPrefix("-")
            let digits = negative ? String(token.text.dropFirst()) : token.text
            let value: Int64?
            if digits.hasPrefix("0x") || digits.hasPrefix("0X") {
                value = Int64(digits.dropFirst(2), radix: 16)
            } else if digits.count > 1 && digits.hasPrefix("0") {
                value = Int64(digits.dropFirst(), radix: 8)
            } else {
                value = Int64(digits)
            }
            guard let value else {
                throw self.error("bad integer '\(token.text)'")
            }
            return .integer(negative ? -value : value)
        case .decimal:
            self.advance()
            return .decimal(Double(token.text) ?? 0)
        default:
            break
        }
        if self.accept("true") {
            return .boolean(true)
        }
        if self.accept("false") {
            return .boolean(false)
        }
        if self.accept("null") {
            return .null
        }
        if self.accept("{") {
            try self.expect("}")
            return .emptyDictionary
        }
        if self.accept("[") {
            try self.expect("]")
            return .emptySequence
        }
        if self.accept("Infinity") {
            return .decimal(.infinity)
        }
        if self.accept("-Infinity") {
            return .decimal(-.infinity)
        }
        if self.accept("NaN") {
            return .decimal(.nan)
        }
        throw self.error("expected a value, found '\(token.text)'")
    }

    mutating func extendedAttributeList() throws -> [ExtendedAttribute] {
        guard self.accept("[") else {
            return []
        }
        var result: [ExtendedAttribute] = []
        repeat {
            let name = try self.identifier()
            var attribute = ExtendedAttribute(name: name)
            if self.accept("=") {
                if self.accept("(") {
                    var names: [String] = []
                    repeat {
                        names.append(try self.identifier())
                    } while self.accept(",")
                    try self.expect(")")
                    attribute.value = names.joined(separator: ", ")
                } else if self.accept("*") {
                    attribute.value = "*"
                } else if self.current.kind == .string || self.current.kind == .integer {
                    attribute.value = self.advance().text
                } else {
                    attribute.value = try self.identifier()
                }
            }
            if self.accept("(") {
                attribute.arguments = try self.argumentList()
                try self.expect(")")
            }
            result.append(attribute)
        } while self.accept(",")
        try self.expect("]")
        return result
    }
}
