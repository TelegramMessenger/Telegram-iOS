import XCTest
@testable import WidgetIDLCore

final class ResolverTests: XCTestCase {
    private func model(_ source: String) throws -> ResolvedModel {
        return try resolve([try parseIDL(source, file: "t.webidl")])
    }

    func testPartialsMixinsAndTypedefsMerge() throws {
        let m = try model("""
        typedef (Node or DOMString) NodeOrString;
        interface Node { readonly attribute unsigned short nodeType; };
        interface Element : Node { attribute DOMString id; };
        partial interface Element { undefined late(); };
        interface mixin ChildNode { undefined before(NodeOrString... nodes); };
        Element includes ChildNode;
        """)
        XCTAssertEqual(m.interfaces.map(\.name), ["Node", "Element"])
        let element = m.interfaces[1]
        XCTAssertEqual(element.parent, "Node")
        XCTAssertEqual(element.parentIndex, 0)
        XCTAssertEqual(element.members.count, 3)
        guard case let .operation(before) = element.members[2] else { return XCTFail() }
        XCTAssertEqual(before.arguments[0].type, .union([.named("Node"), .string("DOMString")]))
    }

    func testParentsComeFirstWhateverTheFileOrder() throws {
        let m = try model("""
        interface HTMLElement : Element {};
        interface Element : Node {};
        interface Node : EventTarget {};
        interface EventTarget {};
        """)
        XCTAssertEqual(m.interfaces.map(\.name), ["EventTarget", "Node", "Element", "HTMLElement"])
        XCTAssertEqual(m.interfaces.map(\.parentIndex), [nil, 0, 1, 2])
    }

    func testDictionariesFlattenAncestorsFirstSortedPerLevel() throws {
        let m = try model("""
        dictionary Base { long z; long a; };
        dictionary Derived : Base { boolean y; boolean b; };
        """)
        let derived = m.dictionaries.first { $0.name == "Derived" }!
        XCTAssertEqual(derived.members.map(\.name), ["a", "z", "b", "y"])
        XCTAssertNil(derived.inherits)
    }

    func testLegacyNoInterfaceObjectIsNotExposed() throws {
        let m = try model("[LegacyNoInterfaceObject] interface Hidden {}; interface Shown {};")
        XCTAssertEqual(m.interfaces.map(\.exposed), [false, true])
    }

    func testErrors() {
        XCTAssertThrowsError(try model("interface A : Missing {};"))
        XCTAssertThrowsError(try model("interface A {}; A includes Nope;"))
        XCTAssertThrowsError(try model("partial interface Ghost { undefined f(); };"))
        XCTAssertThrowsError(try model("interface A : B {}; interface B : A {};"))
        XCTAssertThrowsError(try model("interface A { attribute long x; attribute long x; };"))
    }
}
