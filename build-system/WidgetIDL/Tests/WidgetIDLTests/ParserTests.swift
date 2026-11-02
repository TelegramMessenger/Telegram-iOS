import XCTest
@testable import WidgetIDLCore

final class ParserTests: XCTestCase {
    func testInterfaceWithEveryMemberKind() throws {
        let defs = try parseIDL("""
        // a comment
        [Exposed=Window]
        interface Sample : Base { /* block */
          constructor(optional DOMString label = "");
          const unsigned short ONE = 1;
          readonly attribute unsigned long long count;
          attribute DOMString? label;
          [CEReactions, Reflect] attribute DOMString title;
          [Reflect=data-x] attribute boolean flag;
          stringifier attribute DOMString value;
          Node? find(DOMString name, optional boolean deep = false);
          undefined add((Node or DOMString)... items);
          getter Node? item(unsigned long index);
          static double half(unrestricted double x);
          iterable<Node>;
        };
        """, file: "t.webidl")
        XCTAssertEqual(defs.count, 1)
        guard case let .interface(iface) = defs[0] else { return XCTFail("not an interface") }
        XCTAssertEqual(iface.name, "Sample")
        XCTAssertEqual(iface.inherits, "Base")
        XCTAssertEqual(iface.extendedAttributes.first?.name, "Exposed")
        XCTAssertEqual(iface.extendedAttributes.first?.value, "Window")
        XCTAssertEqual(iface.members.count, 12)

        guard case let .constructor(ctorArgs, _) = iface.members[0] else { return XCTFail() }
        XCTAssertEqual(ctorArgs.first?.optional, true)
        XCTAssertEqual(ctorArgs.first?.defaultValue, .string(""))

        guard case let .constant(name, type, value, _) = iface.members[1] else { return XCTFail() }
        XCTAssertEqual(name, "ONE")
        XCTAssertEqual(type, .primitive("unsigned short"))
        XCTAssertEqual(value, .integer(1))

        guard case let .attribute(count) = iface.members[2] else { return XCTFail() }
        XCTAssertTrue(count.readonly)
        XCTAssertEqual(count.type, .primitive("unsigned long long"))

        guard case let .attribute(label) = iface.members[3] else { return XCTFail() }
        XCTAssertEqual(label.type, .nullable(.string("DOMString")))

        guard case let .attribute(title) = iface.members[4] else { return XCTFail() }
        XCTAssertEqual(title.extendedAttributes.map(\.name), ["CEReactions", "Reflect"])

        guard case let .attribute(flag) = iface.members[5] else { return XCTFail() }
        XCTAssertEqual(flag.extendedAttributes.first?.value, "data-x")

        guard case let .attribute(value) = iface.members[6] else { return XCTFail() }
        XCTAssertTrue(value.stringifier)

        guard case let .operation(find) = iface.members[7] else { return XCTFail() }
        XCTAssertEqual(find.name, "find")
        XCTAssertEqual(find.returnType, .nullable(.named("Node")))
        XCTAssertEqual(find.arguments.map(\.name), ["name", "deep"])
        XCTAssertEqual(find.arguments[1].defaultValue, .boolean(false))

        guard case let .operation(add) = iface.members[8] else { return XCTFail() }
        XCTAssertTrue(add.arguments[0].variadic)
        XCTAssertEqual(add.arguments[0].type, .union([.named("Node"), .string("DOMString")]))

        guard case let .operation(item) = iface.members[9] else { return XCTFail() }
        XCTAssertEqual(item.special, .getter)

        guard case let .operation(half) = iface.members[10] else { return XCTFail() }
        XCTAssertTrue(half.isStatic)
        XCTAssertEqual(half.arguments[0].type, .primitive("unrestricted double"))

        guard case let .iterable(key, valueType) = iface.members[11] else { return XCTFail() }
        XCTAssertNil(key)
        XCTAssertEqual(valueType, .named("Node"))
    }

    func testOtherDefinitions() throws {
        let defs = try parseIDL("""
        partial interface Sample { undefined more(); };
        interface mixin ParentNode { readonly attribute unsigned long childElementCount; };
        Element includes ParentNode;
        dictionary ElementCreationOptions : BaseOptions { DOMString is; required boolean must; long n = 3; };
        typedef (Node or DOMString) NodeOrString;
        enum ShadowRootMode { "open", "closed" };
        callback interface NodeFilter { unsigned short acceptNode(Node node); };
        callback Fn = undefined (any x);
        namespace console { undefined log(any... data); };
        """, file: "t.webidl")
        XCTAssertEqual(defs.count, 9)
        guard case let .interface(partial) = defs[0] else { return XCTFail() }
        XCTAssertTrue(partial.isPartial)
        guard case let .interface(mixin) = defs[1] else { return XCTFail() }
        XCTAssertTrue(mixin.isMixin)
        XCTAssertEqual(defs[2], .includes(target: "Element", mixin: "ParentNode"))
        guard case let .dictionary(dict) = defs[3] else { return XCTFail() }
        XCTAssertEqual(dict.inherits, "BaseOptions")
        XCTAssertEqual(dict.members.map(\.name), ["is", "must", "n"])
        XCTAssertTrue(dict.members[1].required)
        XCTAssertEqual(dict.members[2].defaultValue, .integer(3))
        XCTAssertEqual(defs[4], .typedef(name: "NodeOrString", type: .union([.named("Node"), .string("DOMString")])))
        XCTAssertEqual(defs[5], .enumeration(name: "ShadowRootMode", values: ["open", "closed"]))
        XCTAssertEqual(defs[6], .callback(CallbackDefinition(name: "NodeFilter", isInterface: true, extendedAttributes: [])))
        XCTAssertEqual(defs[7], .callback(CallbackDefinition(name: "Fn", isInterface: false, extendedAttributes: [])))
        XCTAssertEqual(defs[8], .namespace(name: "console"))
    }

    func testKeywordArgumentNamesAndTypeAttributes() throws {
        let defs = try parseIDL("""
        interface Document {
          Element createElementNS(DOMString? namespace, DOMString qualifiedName);
          Event createEvent(DOMString interface);
          attribute [LegacyNullToEmptyString] DOMString innerHTML;
          undefined f(optional record<DOMString, sequence<long>> r = {}, optional sequence<any> s = []);
        };
        """, file: "t.webidl")
        guard case let .interface(doc) = defs[0] else { return XCTFail() }
        guard case let .operation(ns) = doc.members[0] else { return XCTFail() }
        XCTAssertEqual(ns.arguments.map(\.name), ["namespace", "qualifiedName"])
        guard case let .operation(ev) = doc.members[1] else { return XCTFail() }
        XCTAssertEqual(ev.arguments.map(\.name), ["interface"])
        guard case let .attribute(inner) = doc.members[2] else { return XCTFail() }
        XCTAssertEqual(inner.type, .annotated([ExtendedAttribute(name: "LegacyNullToEmptyString")], .string("DOMString")))
        guard case let .operation(f) = doc.members[3] else { return XCTFail() }
        XCTAssertEqual(f.arguments[0].type, .record(.string("DOMString"), .sequence(.primitive("long"))))
        XCTAssertEqual(f.arguments[0].defaultValue, .emptyDictionary)
        XCTAssertEqual(f.arguments[1].defaultValue, .emptySequence)
    }

    /// WebIDL: an extended attribute that applies to types, written on an argument, applies to the argument's type
    /// (CSSOM's `setProperty(DOMString property, [LegacyNullToEmptyString] DOMString value, …)`); others stay the argument's.
    func testTypeAttributesOnAnArgumentApplyToItsType() throws {
        let defs = try parseIDL("""
        interface CSSStyleDeclaration {
          undefined setProperty([LegacyNullToEmptyString] DOMString value, [Clamp, Other] unsigned long n, optional [LegacyNullToEmptyString] DOMString priority = "");
        };
        """, file: "t.webidl")
        guard case let .interface(css) = defs[0], case let .operation(set) = css.members[0] else { return XCTFail() }
        XCTAssertEqual(set.arguments[0].type, .annotated([ExtendedAttribute(name: "LegacyNullToEmptyString")], .string("DOMString")))
        XCTAssertEqual(set.arguments[0].extendedAttributes, [])
        XCTAssertEqual(set.arguments[1].type, .annotated([ExtendedAttribute(name: "Clamp")], .primitive("unsigned long")))
        XCTAssertEqual(set.arguments[1].extendedAttributes, [ExtendedAttribute(name: "Other")])
        XCTAssertEqual(set.arguments[2].type, .annotated([ExtendedAttribute(name: "LegacyNullToEmptyString")], .string("DOMString")))
    }

    func testErrorsCarryTheLine() {
        XCTAssertThrowsError(try parseIDL("interface A {\n  attribute long x\n};", file: "bad.webidl")) { error in
            let e = error as! IDLError
            XCTAssertEqual(e.file, "bad.webidl")
            XCTAssertEqual(e.line, 3)
            XCTAssertTrue(e.message.contains("expected ';'"), e.message)
        }
        XCTAssertThrowsError(try parseIDL("interface A { maplike<long, long>; };", file: "m.webidl")) { error in
            XCTAssertTrue((error as! IDLError).message.contains("maplike"))
        }
    }
}
