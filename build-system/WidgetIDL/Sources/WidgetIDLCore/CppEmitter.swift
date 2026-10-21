public struct EmitterOptions {
    public var implNamespace: String
    public var tableNamespace: String
    /// How the source includes the header, e.g. `Generated/Bindings.h` (relative to the package, which is on the
    /// include path through the library's `includes = ["."]`).
    public var headerName: String
    /// Headers declaring the impl classes, included by the source after the generated header.
    public var sourceIncludes: [String]

    public init(implNamespace: String, tableNamespace: String, headerName: String, sourceIncludes: [String] = []) {
        self.implNamespace = implNamespace
        self.tableNamespace = tableNamespace
        self.headerName = headerName
        self.sourceIncludes = sourceIncludes
    }
}

private struct EmitError: Error, CustomStringConvertible {
    var description: String
}

private func upperFirst(_ s: String) -> String {
    return s.prefix(1).uppercased() + s.dropFirst()
}

private func cppString(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\"":
            out += "\\\""
        case "\\":
            out += "\\\\"
        case "\n":
            out += "\\n"
        default:
            if scalar.isASCII && scalar.value >= 0x20 {
                out.unicodeScalars.append(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    let digits = String(byte, radix: 8)
                    out += "\\" + String(repeating: "0", count: 3 - digits.count) + digits
                }
            }
        }
    }
    return out + "\""
}

public func emitCpp(_ model: ResolvedModel, options: EmitterOptions) throws -> (header: String, source: String) {
    var emitter = CppEmitter(model: model, options: options)
    return try emitter.run()
}

struct CppEmitter {
    let model: ResolvedModel
    let options: EmitterOptions
    var interfaceNames: Set<String>
    var dictionaryNames: Set<String>
    var reflected: [String] = []
    var unions: [String: String] = [:] // C++ variant spelling -> converter function name
    var unionFunctions: [String] = []

    init(model: ResolvedModel, options: EmitterOptions) {
        self.model = model
        self.options = options
        self.interfaceNames = Set(model.interfaces.map(\.name))
        self.dictionaryNames = Set(model.dictionaries.map(\.name))
    }

    func impl(_ name: String) -> String {
        return "\(self.options.implNamespace)::\(name)"
    }

    // MARK: types

    /// The enum a (possibly nullable or annotated) type names, if it does.
    func enumName(_ type: IDLType) -> String? {
        switch type {
        case let .named(n):
            return self.model.enums[n] != nil ? n : nil
        case let .nullable(inner), let .annotated(_, inner):
            return self.enumName(inner)
        default:
            return nil
        }
    }

    /// Whether a sequence appears anywhere in a type: sequences are return values only in M1a.
    func containsSequence(_ type: IDLType) -> Bool {
        switch type {
        case .sequence:
            return true
        case let .nullable(inner), let .annotated(_, inner):
            return self.containsSequence(inner)
        case let .union(alternatives):
            return alternatives.contains { self.containsSequence($0) }
        default:
            return false
        }
    }

    /// The dictionaries a type needs complete (members are held by value).
    func dictionaryDependencies(_ type: IDLType, into out: inout [String]) {
        switch type {
        case let .named(n):
            if self.dictionaryNames.contains(n) {
                out.append(n)
            }
        case let .nullable(inner), let .annotated(_, inner), let .sequence(inner):
            self.dictionaryDependencies(inner, into: &out)
        case let .union(alternatives):
            for a in alternatives {
                self.dictionaryDependencies(a, into: &out)
            }
        default:
            break
        }
    }

    /// `expr` (a conversion of an argument of `type`), checked against the enum's values when `type` is an enum.
    func checkedConversion(_ type: IDLType, _ expr: String, _ info: String) -> String {
        if let e = self.enumName(type) {
            return "enumChecked_\(e)(\(expr), \(info))"
        }
        return expr
    }

    func enumHelpers() -> [String] {
        var lines: [String] = []
        for (name, values) in self.model.enums.sorted(by: { $0.key < $1.key }) {
            let tests = values.map { "s.equalsASCII(\(cppString($0)))" }.joined(separator: " || ")
            lines.append("[[maybe_unused]] static bool enumValid_\(name)(const wr::String& s) { return \(tests.isEmpty ? "false" : tests); }")
            lines.append("[[maybe_unused]] static bool enumValid_\(name)(const std::optional<wr::String>& s) { return !s || enumValid_\(name)(*s); }")
            lines.append("[[maybe_unused]] static wr::String enumChecked_\(name)(wr::String s, const wr::ArgInfo& info) {")
            lines.append("    if (!enumValid_\(name)(s)) throw wr::TypeError{wr::argumentMessage(info, \"is not a valid \(name) value\")};")
            lines.append("    return s;")
            lines.append("}")
            lines.append("[[maybe_unused]] static std::optional<wr::String> enumChecked_\(name)(std::optional<wr::String> s, const wr::ArgInfo& info) {")
            lines.append("    if (!enumValid_\(name)(s)) throw wr::TypeError{wr::argumentMessage(info, \"is not a valid \(name) value\")};")
            lines.append("    return s;")
            lines.append("}")
        }
        return lines
    }

    /// The C++ type an IDL type converts to. `context` names the member for errors.
    mutating func cppType(_ type: IDLType, _ context: String) throws -> String {
        switch type {
        case let .primitive(p):
            switch p {
            case "boolean": return "bool"
            case "byte": return "int8_t"
            case "octet": return "uint8_t"
            case "short": return "int16_t"
            case "unsigned short": return "uint16_t"
            case "long": return "int32_t"
            case "unsigned long": return "uint32_t"
            case "long long": return "int64_t"
            case "unsigned long long": return "uint64_t"
            case "float", "double": return "double"
            case "unrestricted float", "unrestricted double": return "wr::Unrestricted"
            default: throw EmitError(description: "\(context): type \(p) is not supported")
            }
        case let .string(s):
            switch s {
            case "DOMString": return "wr::String"
            case "USVString": return "wr::USVString"
            default: throw EmitError(description: "\(context): type \(s) is not supported")
            }
        case .any:
            return "wr::Value"
        case .object:
            return "wr::Object"
        case .undefined:
            return "void"
        case let .named(n):
            if self.interfaceNames.contains(n) {
                return "\(self.impl(n))*"
            }
            if self.dictionaryNames.contains(n) {
                return "\(self.options.tableNamespace)::\(n)"
            }
            if self.model.enums[n] != nil {
                return "wr::String"
            }
            if let callback = self.model.callbacks[n] {
                if callback.isInterface {
                    return "wr::CallbackInterface"
                }
                if callback.extendedAttributes.has("LegacyTreatNonObjectAsNull") {
                    // WebIDL gives [LegacyTreatNonObjectAsNull] meaning only where null is a value.
                    throw EmitError(description: "\(context): [LegacyTreatNonObjectAsNull] callback \(n) is only supported nullable")
                }
                return "wr::Callback"
            }
            throw EmitError(description: "\(context): type \(n) is not supported (unknown)")
        case let .nullable(inner):
            if case let .named(n) = inner, let callback = self.model.callbacks[n], !callback.isInterface,
               callback.extendedAttributes.has("LegacyTreatNonObjectAsNull") {
                // A non-object converts to null, and any object is kept, callable or not.
                return "std::optional<wr::LegacyCallback>"
            }
            let t = try self.cppType(inner, context)
            // A nullable interface converts to wr::OrNull<Impl> (implicitly an Impl*, null allowed); a plain `Impl*`
            // argument rejects null with TypeError.
            return t.hasSuffix("*") ? "wr::OrNull<\(t.dropLast())>" : "std::optional<\(t)>"
        case let .annotated(attributes, inner):
            if attributes.has("LegacyNullToEmptyString") {
                return "wr::LegacyNullToEmptyString"
            }
            return try self.cppType(inner, context)
        case let .union(alternatives):
            let parts = try alternatives.map { try self.cppType($0, context) }
            let spelling = "std::variant<\(parts.joined(separator: ", "))>"
            if self.unions[spelling] == nil {
                let name = "convertUnion\(self.unions.count)"
                self.unions[spelling] = name
                self.unionFunctions.append(try self.unionConverter(name, spelling, alternatives, context))
            }
            return spelling
        case let .sequence(inner):
            // Returned as an array (wr::toJS of a std::vector); not accepted as an argument in M1a.
            return "std::vector<\(try self.cppType(inner, context))>"
        default:
            throw EmitError(description: "\(context): type \(type) is not supported")
        }
    }

    /// A converter for one union, by WebIDL's union conversion (https://webidl.spec.whatwg.org/#es-union) for the
    /// alternatives M1a uses: interfaces first (a platform object implementing one), then a callback function (a
    /// callable value), then a dictionary (undefined, null or a non-platform object) or a callback interface (an object),
    /// then a Boolean value to a boolean alternative and a Number value to a numeric one (steps 10 and 11), then a
    /// string, then numbers and booleans.
    mutating func unionConverter(_ name: String, _ spelling: String, _ alternatives: [IDLType], _ context: String) throws -> String {
        var lines: [String] = []
        lines.append("template <> \(spelling) wr::Converter<\(spelling)>::from(JSContext* ctx, JSValueConst v, const wr::ArgInfo& info) {")
        for alternative in alternatives {
            if case let .named(n) = alternative, self.interfaceNames.contains(n) {
                lines.append("    if (auto* p = wr::unwrap<\(self.impl(n))>(ctx, v, \(self.options.tableNamespace)::k\(n))) return \(spelling)(p);")
            }
        }
        for alternative in alternatives {
            if case let .named(n) = alternative, let callback = self.model.callbacks[n], !callback.isInterface {
                // WebIDL union conversion: a callable value is the callback function, before any dictionary, string
                // or primitive alternative.
                lines.append("    if (JS_IsFunction(ctx, v)) return \(spelling)(wr::Callback(wr::Value::dup(ctx, v)));")
            }
        }
        for alternative in alternatives {
            if case let .named(n) = alternative, self.dictionaryNames.contains(n) {
                lines.append("    if (JS_IsUndefined(v) || JS_IsNull(v) || (JS_IsObject(v) && !wr::isPlatformObject(ctx, v))) return \(spelling)(wr::Converter<\(self.options.tableNamespace)::\(n)>::from(ctx, v, info));")
            }
        }
        for alternative in alternatives {
            if case let .named(n) = alternative, let callback = self.model.callbacks[n], callback.isInterface {
                lines.append("    if (JS_IsObject(v)) return \(spelling)(wr::CallbackInterface(wr::Value::dup(ctx, v)));")
            }
        }
        for alternative in alternatives {
            // Steps 10 and 11: a Boolean is the boolean alternative and a Number a numeric one, before any string.
            if case let .primitive(name) = alternative, name != "bigint" {
                let t = try self.cppType(alternative, context)
                let test = name == "boolean" ? "JS_IsBool(v)" : "JS_IsNumber(v)"
                lines.append("    if (\(test)) return \(spelling)(wr::Converter<\(t)>::from(ctx, v, info));")
            }
        }
        for alternative in alternatives {
            switch alternative {
            case .string:
                let t = try self.cppType(alternative, context)
                lines.append("    return \(spelling)(wr::Converter<\(t)>::from(ctx, v, info));")
                lines.append("}")
                return lines.joined(separator: "\n")
            default:
                continue
            }
        }
        for alternative in alternatives {
            if case .primitive = alternative {
                let t = try self.cppType(alternative, context)
                lines.append("    return \(spelling)(wr::Converter<\(t)>::from(ctx, v, info));")
                lines.append("}")
                return lines.joined(separator: "\n")
            }
        }
        lines.append("    throw wr::TypeError{wr::argumentMessage(info, \"is not of any type in the union\")};")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    /// A default value. `{}` converts undefined, as WebIDL does: a dictionary gets its member defaults, and a union
    /// holding a dictionary picks the dictionary.
    func defaultExpression(_ literal: Literal, _ cpp: String, _ info: String) -> String {
        switch literal {
        case let .string(s):
            if cpp.contains("optional") {
                return "std::optional<wr::String>(wr::String::fromUTF8(ctx, \(cppString(s))))"
            }
            // A string type of its own (wr::LegacyNullToEmptyString, wr::USVString) is constructed from the String.
            return cpp == "wr::String" ? "wr::String::fromUTF8(ctx, \(cppString(s)))" : "\(cpp)(wr::String::fromUTF8(ctx, \(cppString(s))))"
        case let .integer(i):
            return "\(cpp)(\(i))"
        case let .decimal(d):
            return "\(cpp)(\(d))"
        case let .boolean(b):
            return b ? "true" : "false"
        case .null:
            if cpp == "wr::Value" {
                // `any x = null`: the value null, not an absent optional.
                return "wr::Value::adopt(ctx, JS_NULL)"
            }
            return cpp.hasPrefix("wr::OrNull<") ? "\(cpp){}" : "std::nullopt"
        case .emptyDictionary:
            return "wr::convert<\(cpp)>(ctx, JS_UNDEFINED, \(info))"
        case .emptySequence:
            return "\(cpp){}"
        }
    }

    /// A dictionary member's C++ type that points at a platform object without holding it: `wr::X*` or
    /// `wr::OrNull<wr::X>`.
    func isInterfacePointer(_ cpp: String) -> Bool {
        return cpp.hasSuffix("*") || cpp.hasPrefix("wr::OrNull<")
    }

    // MARK: members

    func info(_ interface: String, _ member: String, _ index: Int) -> String {
        return "wr::ArgInfo{\(cppString(interface)), \(cppString(member)), \(index)}"
    }

    /// The index of `name` in the table's name list (reflected content attribute names, event handler types), added
    /// once.
    mutating func reflectedIndex(_ name: String) -> Int {
        if let i = self.reflected.firstIndex(of: name) {
            return i
        }
        self.reflected.append(name)
        return self.reflected.count - 1
    }

    /// Whether an attribute's resolved type is one of HTML's event handler types: `EventHandler`,
    /// `OnErrorEventHandler` and `OnBeforeUnloadEventHandler` are typedefs of these nullable callbacks.
    func isEventHandlerType(_ type: IDLType) -> Bool {
        guard case let .nullable(inner) = type, case let .named(n) = inner else {
            return false
        }
        return n == "EventHandlerNonNull" || n == "OnErrorEventHandlerNonNull" || n == "OnBeforeUnloadEventHandlerNonNull"
    }

    mutating func argumentExpressions(_ arguments: [Argument], _ interface: String, _ member: String) throws -> (required: Int, expressions: [String]) {
        var expressions: [String] = []
        var required = 0
        for (i, argument) in arguments.enumerated() {
            if self.containsSequence(argument.type) {
                throw EmitError(description: "\(interface).\(member): sequence arguments are not supported in M1a (trim it from the IDL or extend the emitter)")
            }
            let t = try self.cppType(argument.type, "\(interface).\(member)")
            let info = self.info(interface, member, i)
            if argument.variadic {
                expressions.append("wr::convertRest<\(t)>(ctx, argc, argv, \(i), \(info))")
            } else if argument.optional {
                let present = "argc > \(i) && !JS_IsUndefined(argv[\(i)])"
                if let d = argument.defaultValue {
                    expressions.append("\(present) ? \(self.checkedConversion(argument.type, "wr::convert<\(t)>(ctx, argv[\(i)], \(info))", info)) : \(self.defaultExpression(d, t, info))")
                } else if t.hasSuffix("*") {
                    expressions.append("\(present) ? wr::convert<\(t)>(ctx, argv[\(i)], \(info)) : nullptr")
                } else if t.hasPrefix("wr::OrNull<") || t.hasPrefix("std::optional<") {
                    expressions.append("\(present) ? \(self.checkedConversion(argument.type, "wr::convert<\(t)>(ctx, argv[\(i)], \(info))", info)) : \(t){}")
                } else {
                    // No default: the impl tells an absent argument from any value (toggleAttribute's force).
                    expressions.append("\(present) ? std::optional<\(t)>(\(self.checkedConversion(argument.type, "wr::convert<\(t)>(ctx, argv[\(i)], \(info))", info))) : std::optional<\(t)>()")
                }
            } else {
                required = i + 1
                expressions.append(self.checkedConversion(argument.type, "wr::convert<\(t)>(ctx, argv[\(i)], \(info))", info))
            }
        }
        return (required, expressions)
    }

    func returnStatement(_ call: String, _ type: IDLType) -> String {
        if type == .undefined {
            return "\(call);\n        return JS_UNDEFINED;"
        }
        return "return wr::toJS(ctx, \(call));"
    }

    mutating func run() throws -> (header: String, source: String) {
        let ns = self.options.tableNamespace
        var header: [String] = [
            "// Generated by //build-system/WidgetIDL. Do not edit.",
            "#pragma once",
            "",
            "#include \"Sources/Support/Bindings.h\"",
            "#include \"Sources/Support/Callbacks.h\"",
            "",
            "namespace \(ns) {",
        ]
        for (i, interface) in self.model.interfaces.enumerated() {
            header.append("inline constexpr uint16_t k\(interface.name) = \(i);")
        }
        header.append("inline constexpr uint16_t kInterfaceCount = \(self.model.interfaces.count);")
        header.append("")
        header.append("} // namespace \(ns)")
        // Every impl type, forward-declared before the dictionaries that point to them.
        header.append("namespace \(self.options.implNamespace) {")
        for interface in self.model.interfaces {
            header.append("class \(interface.name);")
        }
        header.append("} // namespace \(self.options.implNamespace)")
        header.append("namespace \(ns) {")
        // Dictionaries in dependency order: a member is held by value, so its dictionary comes first.
        var ordered: [Dictionary] = []
        var state: [String: Int] = [:] // 1 visiting, 2 done
        var byName: [String: Dictionary] = [:]
        for d in self.model.dictionaries { byName[d.name] = d }
        func visit(_ d: Dictionary) throws {
            if state[d.name] == 2 { return }
            if state[d.name] == 1 {
                throw EmitError(description: "dictionary \(d.name): members refer to each other in a cycle")
            }
            state[d.name] = 1
            for member in d.members {
                var deps: [String] = []
                self.dictionaryDependencies(member.type, into: &deps)
                for dep in deps {
                    if let next = byName[dep] { try visit(next) }
                }
            }
            state[d.name] = 2
            ordered.append(d)
        }
        for d in self.model.dictionaries { try visit(d) }
        for dictionary in ordered {
            header.append("struct \(dictionary.name) {")
            for member in dictionary.members {
                if self.containsSequence(member.type) {
                    throw EmitError(description: "\(dictionary.name).\(member.name): sequence members are not supported in M1a (trim it from the IDL or extend the emitter)")
                }
                let t = try self.cppType(member.type, "\(dictionary.name).\(member.name)")
                if member.required || member.defaultValue != nil {
                    header.append("    \(t) \(member.name){};")
                } else {
                    header.append("    std::optional<\(t)> \(member.name);")
                }
                if self.isInterfacePointer(t) {
                    // The pointer is not a reference: the dictionary keeps the object alive while it lives, as a
                    // getter may return the object's only reference and later members run script.
                    header.append("    wr::Value \(member.name)_keep;")
                }
            }
            header.append("};")
        }
        header.append("extern const wr::InterfaceTable kTable;")
        header.append("} // namespace \(ns)")
        for interface in self.model.interfaces {
            header.append("template <> struct wr::InterfaceIndexOf<\(self.impl(interface.name))> { static constexpr uint16_t value = \(ns)::k\(interface.name); };")
        }
        for dictionary in self.model.dictionaries {
            header.append("template <> \(ns)::\(dictionary.name) wr::Converter<\(ns)::\(dictionary.name)>::from(JSContext* ctx, JSValueConst v, const wr::ArgInfo& info);")
        }

        var body: [String] = []
        var tableEntries: [String] = []
        let globals = self.model.interfaces.filter { $0.extendedAttributes.has("Global") }
        if globals.count > 1 {
            throw EmitError(description: "more than one [Global] interface: \(globals.map(\.name).joined(separator: ", "))")
        }
        for interface in self.model.interfaces {
            let x = interface.name
            let implType = self.impl(x)
            var members: [String] = []
            var constructorName = "nullptr"
            var constructorLength = 0
            var exotic = "nullptr"
            var valueIterable = false
            var pairIterable: (key: IDLType, value: IDLType)?
            var stringifier = "nullptr"
            var operationNames: Set<String> = []
            /// The [CSSProperty] names given a dashed attribute already (a -webkit- property has two attributes, one alias).
            var cssAliases: Set<String> = []
            var hasIndexedGetter = false
            var stringifierUnforgeable = false
            let isGlobal = interface.extendedAttributes.has("Global")

            for member in interface.members {
                switch member {
                case let .constant(name, _, value, _):
                    guard case let .integer(v) = value else {
                        throw EmitError(description: "\(x).\(name): only integer constants are supported")
                    }
                    members.append("    {\(cppString(name)), wr::MemberKind::Constant, nullptr, nullptr, nullptr, 0, \(v), false, false, false},")
                case let .attribute(a):
                    let context = "\(x).\(a.name)"
                    let getter = "\(x)_get_\(a.name)"
                    var setter = "nullptr"
                    let unforgeable = a.extendedAttributes.has("LegacyUnforgeable")
                    var cssAlias: String?
                    if self.isEventHandlerType(a.type) {
                        // HTML's event handler IDL attributes go to the runtime's event handler hooks, by event type.
                        guard !a.readonly && !a.isStatic else {
                            throw EmitError(description: "\(context): an event handler attribute must be a writable regular attribute")
                        }
                        guard a.name.hasPrefix("on") && a.name.count > 2 else {
                            throw EmitError(description: "\(context): an event handler attribute must be named on<type>")
                        }
                        let id = self.reflectedIndex(String(a.name.dropFirst(2)))
                        setter = "\(x)_set_\(a.name)"
                        body.append("""
                        static JSValue \(getter)(JSContext* ctx, JSValueConst thisVal) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                return wr::getEventHandler(ctx, self, wr::tableAtom(ctx, \(id)));
                            });
                        }
                        """)
                        body.append("""
                        static JSValue \(setter)(JSContext* ctx, JSValueConst thisVal, JSValueConst value) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                wr::setEventHandler(ctx, self, wr::tableAtom(ctx, \(id)), value);
                                return JS_UNDEFINED;
                            });
                        }
                        """)
                    } else if let css = a.extendedAttributes.first(where: { $0.name == "CSSProperty" }) {
                        // CSSOM's CSSStyleProperties: a camel-cased attribute per property, read and written through the
                        // declaration block's generic accessors by the property's name (an atom of the table).
                        guard let property = css.value, !property.isEmpty else {
                            throw EmitError(description: "\(context): [CSSProperty] needs the property's name")
                        }
                        guard !a.readonly, !a.isStatic else {
                            throw EmitError(description: "\(context): a [CSSProperty] attribute must be a writable regular attribute")
                        }
                        let id = self.reflectedIndex(property)
                        let t = try self.cppType(a.type, context)
                        setter = "\(x)_set_\(a.name)"
                        body.append("""
                        static JSValue \(getter)(JSContext* ctx, JSValueConst thisVal) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                return wr::toJS(ctx, self.propertyValue(ctx, wr::tableAtom(ctx, \(id))));
                            });
                        }
                        """)
                        body.append("""
                        static JSValue \(setter)(JSContext* ctx, JSValueConst thisVal, JSValueConst value) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                self.setPropertyValue(ctx, wr::tableAtom(ctx, \(id)), wr::convert<\(t)>(ctx, value, \(self.info(x, a.name, 0))));
                                return JS_UNDEFINED;
                            });
                        }
                        """)
                        if property.contains("-") && property != a.name && cssAliases.insert(property).inserted {
                            // The dashed attribute (`style['background-color']`): the same accessors under the property's name.
                            cssAlias = property
                        }
                    } else if let reflect = a.extendedAttributes.first(where: { $0.name == "Reflect" }) {
                        let contentName = reflect.value ?? a.name.lowercased()
                        let id = self.reflectedIndex(contentName)
                        let kind: String
                        switch a.type {
                        case .string("DOMString"): kind = "String"
                        case .primitive("boolean"): kind = "Boolean"
                        case .primitive("long"): kind = "Long"
                        case .primitive("unsigned long"): kind = "UnsignedLong"
                        default: throw EmitError(description: "\(context): [Reflect] supports DOMString, boolean, long and unsigned long")
                        }
                        body.append("""
                        static JSValue \(getter)(JSContext* ctx, JSValueConst thisVal) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<wr::Element>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                return wr::toJS(ctx, wr::reflect::get\(kind)(ctx, self, \(id)));
                            });
                        }
                        """)
                        if !a.readonly {
                            setter = "\(x)_set_\(a.name)"
                            let t = try self.cppType(a.type, context)
                            body.append("""
                            static JSValue \(setter)(JSContext* ctx, JSValueConst thisVal, JSValueConst value) {
                                return wr::glue(ctx, [&]() -> JSValue {
                                    auto& self = wr::thisAs<wr::Element>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                    wr::reflect::set\(kind)(ctx, self, \(id), wr::convert<\(t)>(ctx, value, \(self.info(x, a.name, 0))));
                                    return JS_UNDEFINED;
                                });
                            }
                            """)
                        }
                    } else {
                        let t = try self.cppType(a.type, context)
                        _ = t
                        body.append("""
                        static JSValue \(getter)(JSContext* ctx, JSValueConst thisVal) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                return wr::toJS(ctx, self.\(cppMemberName(a.name))(ctx));
                            });
                        }
                        """)
                        if a.readonly, let forward = a.extendedAttributes.value("PutForwards") {
                            // [PutForwards=name]: assigning the attribute assigns `name` on the object it returns.
                            setter = "\(x)_set_\(a.name)"
                            body.append("""
                            static JSValue \(setter)(JSContext* ctx, JSValueConst thisVal, JSValueConst value) {
                                JSValue target = \(getter)(ctx, thisVal);
                                if (JS_IsException(target)) return JS_EXCEPTION;
                                int status = JS_SetPropertyStr(ctx, target, \(cppString(forward)), JS_DupValue(ctx, value));
                                JS_FreeValue(ctx, target);
                                return status < 0 ? JS_EXCEPTION : JS_UNDEFINED;
                            }
                            """)
                        } else if a.readonly && a.extendedAttributes.has("Replaceable") {
                            // [Replaceable]: assigning makes an own data property that shadows the attribute (WebIDL 3.7.6).
                            setter = "\(x)_set_\(a.name)"
                            body.append("""
                            static JSValue \(setter)(JSContext* ctx, JSValueConst thisVal, JSValueConst value) {
                                return wr::glue(ctx, [&]() -> JSValue {
                                    wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                    wr::replaceAttribute(ctx, thisVal, \(cppString(a.name)), value);
                                    return JS_UNDEFINED;
                                });
                            }
                            """)
                        }
                        if !a.readonly {
                            setter = "\(x)_set_\(a.name)"
                            if self.containsSequence(a.type) {
                                throw EmitError(description: "\(context): sequence attributes are not supported in M1a (trim it from the IDL or extend the emitter)")
                            }
                            let st = try self.cppType(a.type, context)
                            body.append("""
                            static JSValue \(setter)(JSContext* ctx, JSValueConst thisVal, JSValueConst value) {
                                return wr::glue(ctx, [&]() -> JSValue {
                                    auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(a.name)));
                                    \(self.enumName(a.type) != nil ? "auto converted = wr::convert<\(st)>(ctx, value, \(self.info(x, a.name, 0)));\n        if (!enumValid_\(self.enumName(a.type)!)(converted)) return JS_UNDEFINED;\n        self.set\(upperFirst(a.name))(ctx, std::move(converted));" : "self.set\(upperFirst(a.name))(ctx, wr::convert<\(st)>(ctx, value, \(self.info(x, a.name, 0))));")
                                    return JS_UNDEFINED;
                                });
                            }
                            """)
                        }
                    }
                    if a.stringifier {
                        stringifier = "\(x)_toString"
                        stringifierUnforgeable = unforgeable
                        body.append("""
                        static JSValue \(x)_toString(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
                            return \(getter)(ctx, thisVal);
                        }
                        """)
                    }
                    let unscopable = a.extendedAttributes.has("Unscopable") || a.extendedAttributes.has("LegacyUnscopable")
                    members.append("    {\(cppString(a.name)), wr::MemberKind::Attribute, nullptr, \(getter), \(setter), 0, 0, \(unscopable), \(a.isStatic), \(unforgeable)},")
                    if let alias = cssAlias {
                        members.append("    {\(cppString(alias)), wr::MemberKind::Attribute, nullptr, \(getter), \(setter), 0, 0, false, false, false},")
                    }
                case let .operation(o):
                    if o.special == .getter {
                        let isIndexed = o.arguments.first?.type == .primitive("unsigned long")
                        if isIndexed {
                            hasIndexedGetter = true
                            exotic = "&wr::IndexedExotic<\(implType)>::methods"
                        } else if !hasIndexedGetter && !interface.members.contains(where: { if case let .operation(g) = $0 { return g.special == .getter && g.arguments.first?.type == .primitive("unsigned long") } else { return false } }) {
                            // Named properties only for an interface without an indexed getter (DOMStringMap). An
                            // interface with both (NamedNodeMap) keeps its indices; its named properties are not in M1a.
                            exotic = "&wr::NamedExotic<\(implType)>::methods"
                        }
                    }
                    if o.special == .setter || o.special == .deleter {
                        // Named setters and deleters are part of the NamedExotic contract.
                        if o.name == nil {
                            continue
                        }
                    }
                    if o.stringifier && o.name == nil {
                        stringifier = "\(x)_toString"
                        stringifierUnforgeable = o.extendedAttributes.has("LegacyUnforgeable")
                        body.append("""
                        static JSValue \(x)_toString(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
                            return wr::glue(ctx, [&]() -> JSValue {
                                auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), "toString");
                                return wr::toJS(ctx, self.toString(ctx));
                            });
                        }
                        """)
                        continue
                    }
                    guard let name = o.name else {
                        continue
                    }
                    guard !operationNames.contains(name) else {
                        throw EmitError(description: "\(x).\(name): overloads are not supported")
                    }
                    operationNames.insert(name)
                    let fn = "\(x)_\(name)"
                    let (required, expressions) = try self.argumentExpressions(o.arguments, x, name)
                    _ = try self.cppType(o.returnType, "\(x).\(name)")
                    let receiver = o.isStatic ? "\(implType)::\(cppMemberName(name))" : "self.\(cppMemberName(name))"
                    let call = "\(receiver)(\((["ctx"] + expressions).joined(separator: ", ")))"
                    let thisLine = o.isStatic ? "" : "auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), \(cppString(name)));\n        "
                    body.append("""
                    static JSValue \(fn)(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
                        return wr::glue(ctx, [&]() -> JSValue {
                            \(thisLine)wr::requireArguments(argc, \(required), \(cppString(x)), \(cppString(name)));
                            \(self.returnStatement(call, o.returnType))
                        });
                    }
                    """)
                    let unscopable = o.extendedAttributes.has("Unscopable") || o.extendedAttributes.has("LegacyUnscopable")
                    let unforgeable = o.extendedAttributes.has("LegacyUnforgeable")
                    members.append("    {\(cppString(name)), wr::MemberKind::Method, \(fn), nullptr, nullptr, \(required), 0, \(unscopable), \(o.isStatic), \(unforgeable)},")
                case let .constructor(arguments, _):
                    guard constructorName == "nullptr" else {
                        throw EmitError(description: "\(x).constructor: overloads are not supported")
                    }
                    constructorName = "\(x)_construct"
                    let (required, expressions) = try self.argumentExpressions(arguments, x, "constructor")
                    constructorLength = required
                    body.append("""
                    static JSValue \(x)_construct(JSContext* ctx, JSValueConst newTarget, int argc, JSValueConst* argv) {
                        return wr::glue(ctx, [&]() -> JSValue {
                            wr::requireArguments(argc, \(required), \(cppString(x)), "constructor");
                            auto made = \(implType)::construct(\((["ctx"] + expressions).joined(separator: ", ")));
                            return wr::applyNewTarget(ctx, made.release(), newTarget, \(ns)::k\(x));
                        });
                    }
                    """)
                case let .iterable(key, value):
                    if let key = key {
                        pairIterable = (key, value)
                    } else {
                        valueIterable = true
                    }
                case .stringifier:
                    stringifier = "\(x)_toString"
                    body.append("""
                    static JSValue \(x)_toString(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv) {
                        return wr::glue(ctx, [&]() -> JSValue {
                            auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), "toString");
                            return wr::toJS(ctx, self.toString(ctx));
                        });
                    }
                    """)
                }
            }
            // WebIDL "define the iteration methods": an interface that supports indexed properties (an indexed getter and
            // an integer-typed `length`) gets @@iterator, %Array.prototype.values%; a value iterator also gets entries,
            // keys, values and forEach, and needs indexed properties to iterate over.
            let integerTypes: Set<String> = ["byte", "octet", "short", "unsigned short", "long", "unsigned long", "long long", "unsigned long long"]
            let hasIntegerLength = interface.members.contains(where: {
                if case let .attribute(a) = $0, a.name == "length", !a.isStatic, case let .primitive(p) = a.type {
                    return integerTypes.contains(p)
                }
                return false
            })
            let indexedIterator = hasIndexedGetter && hasIntegerLength
            if valueIterable && !indexedIterator {
                throw EmitError(description: "\(x): a value iterator needs indexed properties (an indexed getter and an integer length)")
            }
            // WebIDL: an interface that supports indexed properties has a value iterator, never a pair iterator. A pair
            // iterator's methods and iterator objects are the runtime's (Runtime::definePairIteration); the adapters
            // below give it the implementation's live list.
            if let pair = pairIterable {
                if hasIndexedGetter {
                    throw EmitError(description: "\(x): a pair iterator needs an interface without indexed properties")
                }
                _ = try self.cppType(pair.key, "\(x) iterable key")
                _ = try self.cppType(pair.value, "\(x) iterable value")
                body.append("""
                static uint32_t \(x)_iterationLength(JSContext* ctx, JSValueConst thisVal) {
                    auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), "entries");
                    return self.iterationLength(ctx);
                }
                static void \(x)_iterationPair(JSContext* ctx, JSValueConst thisVal, uint32_t index, JSValue* key, JSValue* value) {
                    auto& self = wr::thisAs<\(implType)>(ctx, thisVal, \(ns)::k\(x), "entries");
                    auto pair = self.iterationPair(ctx, index);
                    wr::Value k = wr::Value::adopt(ctx, wr::toJS(ctx, pair.first));
                    wr::Value v = wr::Value::adopt(ctx, wr::toJS(ctx, pair.second));
                    *key = k.release();
                    *value = v.release();
                }
                static const wr::PairIteration \(x)_pairIteration = {\(x)_iterationLength, \(x)_iterationPair};
                """)
            }
            if stringifier != "nullptr" && !members.contains(where: { $0.contains("\"toString\"") }) {
                members.append("    {\"toString\", wr::MemberKind::Method, \(stringifier), nullptr, nullptr, 0, 0, false, false, \(stringifierUnforgeable)},")
            }
            body.append("static const wr::MemberDef \(x)_members[] = {")
            body.append(contentsOf: members)
            body.append("    {nullptr, wr::MemberKind::Method, nullptr, nullptr, nullptr, 0, 0, false, false, false},")
            body.append("};")
            let memberCount = members.count
            tableEntries.append("""
                {\(cppString(x)), /* parent */ \(interface.parentIndex.map(String.init) ?? "-1"), /* exposed */ \(interface.exposed), /* global */ \(isGlobal), \(x)_members, \(memberCount), \(constructorName), \(constructorLength), \(exotic), /* valueIterable */ \(valueIterable), /* indexedIterator */ \(indexedIterator), /* pairIteration */ \(pairIterable != nil ? "&\(x)_pairIteration" : "nullptr")},
            """)
        }

        var source: [String] = [
            "// Generated by //build-system/WidgetIDL. Do not edit.",
            "#include \"\(self.options.headerName)\"",
        ] + self.options.sourceIncludes.map { "#include \"\($0)\"" } + [
            "",
            "#include <optional>",
            "#include <variant>",
            "#include <vector>",
            "",
        ]
        source.append(contentsOf: self.enumHelpers())
        source.append(contentsOf: self.unionFunctions)
        for dictionary in self.model.dictionaries {
            var lines = ["template <> \(ns)::\(dictionary.name) wr::Converter<\(ns)::\(dictionary.name)>::from(JSContext* ctx, JSValueConst v, const wr::ArgInfo& info) {"]
            lines.append("    \(ns)::\(dictionary.name) result;")
            lines.append("    if (JS_IsUndefined(v) || JS_IsNull(v)) {")
            for member in dictionary.members where member.required {
                lines.append("        throw wr::TypeError{wr::argumentMessage(info, \"is missing required member \(member.name)\")};")
            }
            for member in dictionary.members {
                if let d = member.defaultValue {
                    let t = try self.cppType(member.type, "\(dictionary.name).\(member.name)")
                    lines.append("        result.\(member.name) = \(self.defaultExpression(d, t, "info"));")
                }
            }
            lines.append("        return result;")
            lines.append("    }")
            lines.append("    if (!JS_IsObject(v)) throw wr::TypeError{wr::argumentMessage(info, \"is not an object\")};")
            for member in dictionary.members {
                let t = try self.cppType(member.type, "\(dictionary.name).\(member.name)")
                lines.append("    {")
                lines.append("        wr::Value m = wr::Value::adopt(ctx, wr::checked(ctx, JS_GetPropertyStr(ctx, v, \(cppString(member.name)))));")
                let conversion = self.checkedConversion(member.type, "wr::convert<\(t)>(ctx, m.get(), info)", "info")
                if self.isInterfacePointer(t) {
                    lines.append("        if (!JS_IsUndefined(m.get())) { result.\(member.name) = \(conversion); result.\(member.name)_keep = m; }")
                } else {
                    lines.append("        if (!JS_IsUndefined(m.get())) result.\(member.name) = \(conversion);")
                }
                if member.required {
                    lines.append("        else throw wr::TypeError{wr::argumentMessage(info, \"is missing required member \(member.name)\")};")
                } else if let d = member.defaultValue {
                    lines.append("        else result.\(member.name) = \(self.defaultExpression(d, t, "info"));")
                }
                lines.append("    }")
            }
            lines.append("    return result;")
            lines.append("}")
            source.append(lines.joined(separator: "\n"))
        }
        source.append("namespace {")
        source.append(contentsOf: body)
        source.append("const char* const kReflectedNames[] = {")
        source.append(contentsOf: self.reflected.map { "    \(cppString($0))," })
        source.append("    nullptr,")
        source.append("};")
        source.append("const wr::InterfaceInfo kInterfaces[] = {")
        source.append(contentsOf: tableEntries)
        source.append("};")
        source.append("} // namespace")
        source.append("const wr::InterfaceTable \(ns)::kTable = {kInterfaces, \(ns)::kInterfaceCount, kReflectedNames, \(self.reflected.count)};")
        return (header.joined(separator: "\n") + "\n", source.joined(separator: "\n") + "\n")
    }
}

/// C++ keywords an IDL member may be named (URLSearchParams.delete): the implementation's member takes a trailing "_".
private let cppKeywords: Set<String> = ["delete", "default", "new", "class", "template", "operator", "this", "union", "register", "namespace", "typename", "private", "public", "protected", "virtual", "explicit", "friend", "mutable", "export"]

func cppMemberName(_ name: String) -> String {
    return cppKeywords.contains(name) ? name + "_" : name
}
