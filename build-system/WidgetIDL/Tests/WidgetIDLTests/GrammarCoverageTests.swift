import XCTest
@testable import WidgetIDLCore

final class GrammarCoverageTests: XCTestCase {
    private func iface(_ source: String) throws -> Interface {
        let defs = try parseIDL(source, file: "t.webidl")
        guard case let .interface(i) = defs[0] else { throw IDLError(file: "t", line: 0, message: "not an interface") }
        return i
    }

    func testCRLFInput() throws {
        let source = "interface A {\r\n // c\r\n attribute long x;\r\n};\r\ninterface B {};"
        let defs = try parseIDL(source, file: "crlf.webidl")
        XCTAssertEqual(defs.count, 2)
        guard case let .interface(b) = defs[1] else { return XCTFail() }
        XCTAssertEqual(b.name, "B")

        let bad = "interface A {\r\n // c\r\n /* x\r\n y */\r\n attribute long x\r\n};"
        XCTAssertThrowsError(try parseIDL(bad, file: "crlf.webidl")) { error in
            let e = error as! IDLError
            XCTAssertEqual(e.line, 6)
            XCTAssertTrue(e.message.contains("expected ';'"), e.message)
        }
    }

    func testExtendedAttributeForms() throws {
        let i = try iface("""
        [A=(B,C), D=*, E(long x, optional DOMString y), F=G(any z), H="s"]
        interface X {};
        """)
        let a = i.extendedAttributes
        XCTAssertEqual(a.map(\.name), ["A", "D", "E", "F", "H"])
        XCTAssertEqual(a[0].value, "B, C")
        XCTAssertNil(a[0].arguments)
        XCTAssertEqual(a[1].value, "*")
        XCTAssertNil(a[2].value)
        XCTAssertEqual(a[2].arguments?.map(\.name), ["x", "y"])
        XCTAssertEqual(a[2].arguments?[1].optional, true)
        XCTAssertEqual(a[3].value, "G")
        XCTAssertEqual(a[3].arguments?.map(\.name), ["z"])
        XCTAssertEqual(a[3].arguments?[0].type, .any)
        XCTAssertEqual(a[4].value, "s")
        XCTAssertTrue(a.has("D"))
        XCTAssertEqual(a.value("D"), "*")
    }

    func testInheritAttributeAndNewTypes() throws {
        let i = try iface("""
        interface X {
          inherit attribute DOMString name;
          attribute ObservableArray<DOMString> list;
          Promise<undefined> go();
          Promise<sequence<long>> more();
          undefined u((Node? or DOMString) v);
        };
        """)
        guard case let .attribute(inh) = i.members[0] else { return XCTFail() }
        XCTAssertTrue(inh.inherit)
        XCTAssertFalse(inh.readonly)
        guard case let .attribute(list) = i.members[1] else { return XCTFail() }
        XCTAssertEqual(list.type, .observableArray(.string("DOMString")))
        guard case let .operation(go) = i.members[2] else { return XCTFail() }
        XCTAssertEqual(go.returnType, .promise(.undefined))
        guard case let .operation(more) = i.members[3] else { return XCTFail() }
        XCTAssertEqual(more.returnType, .promise(.sequence(.primitive("long"))))
        guard case let .operation(u) = i.members[4] else { return XCTFail() }
        XCTAssertEqual(u.arguments[0].type, .union([.nullable(.named("Node")), .string("DOMString")]))
    }

    func testCallbackInterfaceWithMembers() throws {
        let defs = try parseIDL("""
        callback interface NodeFilter {
          const unsigned short FILTER_ACCEPT = 1;
          unsigned short acceptNode(Node node);
        };
        interface After {};
        """, file: "t.webidl")
        XCTAssertEqual(defs.count, 2)
        XCTAssertEqual(defs[0], .callback(CallbackDefinition(name: "NodeFilter", isInterface: true, extendedAttributes: [])))
        guard case let .interface(a) = defs[1] else { return XCTFail() }
        XCTAssertEqual(a.name, "After")
    }

    func testDefaultValues() throws {
        let i = try iface("""
        interface X {
          undefined f(optional double a = -Infinity, optional double b = Infinity, optional double c = NaN,
                      optional long d = 0x1F, optional long e = -5, optional double g = 1., optional double h = .5,
                      optional long i = 010, optional any j = null);
        };
        """)
        guard case let .operation(f) = i.members[0] else { return XCTFail() }
        let d = f.arguments.map(\.defaultValue)
        XCTAssertEqual(d[0], .decimal(-.infinity))
        XCTAssertEqual(d[1], .decimal(.infinity))
        guard case .decimal(let nan)? = d[2] else { return XCTFail() }
        XCTAssertTrue(nan.isNaN)
        XCTAssertEqual(d[3], .integer(31))
        XCTAssertEqual(d[4], .integer(-5))
        XCTAssertEqual(d[5], .decimal(1.0))
        XCTAssertEqual(d[6], .decimal(0.5))
        XCTAssertEqual(d[7], .integer(8))
        XCTAssertEqual(d[8], .null)
    }

    func testAnonymousSpecialOperations() throws {
        let i = try iface("""
        interface X {
          getter DOMString (DOMString name);
          setter undefined (DOMString name, any value);
          deleter undefined (DOMString name);
        };
        """)
        guard case let .operation(g) = i.members[0] else { return XCTFail() }
        XCTAssertNil(g.name)
        XCTAssertEqual(g.special, .getter)
        XCTAssertEqual(g.returnType, .string("DOMString"))
        XCTAssertEqual(g.arguments.map(\.name), ["name"])
        guard case let .operation(s) = i.members[1] else { return XCTFail() }
        XCTAssertNil(s.name)
        XCTAssertEqual(s.special, .setter)
        XCTAssertEqual(s.arguments.map(\.name), ["name", "value"])
        guard case let .operation(d) = i.members[2] else { return XCTFail() }
        XCTAssertEqual(d.special, .deleter)
    }

    func testUnsupportedConstructsNameTheLine() {
        XCTAssertThrowsError(try parseIDL("interface A {\n  setlike<long>;\n};", file: "s.webidl")) { error in
            let e = error as! IDLError
            XCTAssertEqual(e.line, 2)
            XCTAssertTrue(e.message.contains("setlike"), e.message)
        }
        XCTAssertThrowsError(try parseIDL("interface A {\n\n  async iterable<long>;\n};", file: "a.webidl")) { error in
            let e = error as! IDLError
            XCTAssertEqual(e.line, 3)
            XCTAssertTrue(e.message.contains("async"), e.message)
        }
    }
}
