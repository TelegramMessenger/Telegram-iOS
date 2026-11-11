import XCTest
@testable import WidgetIDLCore

final class WebIDLExtendedAttributeTests: XCTestCase {
    private let options = EmitterOptions(implNamespace: "wr::testidl", tableNamespace: "wr::testidl", headerName: "TestBindings.h")

    private func emit(_ source: String) throws -> (header: String, source: String) {
        return try emitCpp(try resolve([try parseIDL(source, file: "t.webidl")]), options: self.options)
    }

    func testLegacyUnforgeableMarksTheMember() throws {
        let out = try emit("""
        interface T { [LegacyUnforgeable] readonly attribute DOMString serial; [LegacyUnforgeable] DOMString stamp(); readonly attribute DOMString plain; const long K = 1; };
        """)
        XCTAssertTrue(out.source.contains("{\"serial\", wr::MemberKind::Attribute, nullptr, T_get_serial, nullptr, 0, 0, false, false, true},"), out.source)
        XCTAssertTrue(out.source.contains("{\"stamp\", wr::MemberKind::Method, T_stamp, nullptr, nullptr, 0, 0, false, false, true},"), out.source)
        XCTAssertTrue(out.source.contains("{\"plain\", wr::MemberKind::Attribute, nullptr, T_get_plain, nullptr, 0, 0, false, false, false},"), out.source)
        XCTAssertTrue(out.source.contains("{\"K\", wr::MemberKind::Constant, nullptr, nullptr, nullptr, 0, 1, false, false, false},"), out.source)
        XCTAssertTrue(out.source.contains("{nullptr, wr::MemberKind::Method, nullptr, nullptr, nullptr, 0, 0, false, false, false},"), out.source)
    }

    func testAnUnforgeableStringifierMakesAnUnforgeableToString() throws {
        let out = try emit("interface L { [LegacyUnforgeable] stringifier attribute DOMString href; };")
        XCTAssertTrue(out.source.contains("{\"toString\", wr::MemberKind::Method, L_toString, nullptr, nullptr, 0, 0, false, false, true},"), out.source)
    }

    func testGlobalIsInTheTable() throws {
        let out = try emit("[Global=W, Exposed=W] interface W { readonly attribute DOMString name; }; interface Other {};")
        func entry(_ name: String) -> String {
            return out.source.components(separatedBy: "\n").first(where: { $0.contains("{\"\(name)\", /* parent */") }) ?? ""
        }
        XCTAssertTrue(entry("W").contains("/* exposed */ true, /* global */ true,"), entry("W"))
        XCTAssertTrue(entry("Other").contains("/* exposed */ true, /* global */ false,"), entry("Other"))
    }

    func testTwoGlobalsAreAnError() {
        XCTAssertThrowsError(try emit("[Global=A] interface A {}; [Global=B] interface B {};")) { error in
            XCTAssertTrue("\(error)".contains("[Global]"), "\(error)")
        }
    }

    func testReplaceableGetsADataPropertySetter() throws {
        let out = try emit("interface W { [Replaceable] readonly attribute W self; };")
        XCTAssertTrue(out.source.contains("static JSValue W_set_self(JSContext* ctx, JSValueConst thisVal, JSValueConst value)"), out.source)
        XCTAssertTrue(out.source.contains("wr::replaceAttribute(ctx, thisVal, \"self\", value);"), out.source)
        XCTAssertTrue(out.source.contains("{\"self\", wr::MemberKind::Attribute, nullptr, W_get_self, W_set_self, 0, 0, false, false, false},"), out.source)
    }

    func testEventHandlerAttributesCallTheHandlerHooks() throws {
        let out = try emit("""
        [LegacyTreatNonObjectAsNull] callback EventHandlerNonNull = any (Event event);
        typedef EventHandlerNonNull? EventHandler;
        [LegacyTreatNonObjectAsNull] callback OnErrorEventHandlerNonNull = any ((Event or DOMString) event);
        typedef OnErrorEventHandlerNonNull? OnErrorEventHandler;
        interface T { attribute EventHandler onclick; attribute OnErrorEventHandler onerror; };
        """)
        XCTAssertTrue(out.source.contains("return wr::getEventHandler(ctx, self, wr::tableAtom(ctx, 0));"), out.source)
        XCTAssertTrue(out.source.contains("wr::setEventHandler(ctx, self, wr::tableAtom(ctx, 0), value);"), out.source)
        XCTAssertTrue(out.source.contains("wr::setEventHandler(ctx, self, wr::tableAtom(ctx, 1), value);"), out.source)
        XCTAssertTrue(out.source.contains("    \"click\",\n    \"error\","), out.source)
        XCTAssertTrue(out.source.contains("{\"onclick\", wr::MemberKind::Attribute, nullptr, T_get_onclick, T_set_onclick, 0, 0, false, false, false},"), out.source)
    }

    func testEventHandlerAttributesMustBeWritableAndNamedOn() {
        let prelude = "[LegacyTreatNonObjectAsNull] callback EventHandlerNonNull = any (Event event); typedef EventHandlerNonNull? EventHandler; "
        XCTAssertThrowsError(try emit(prelude + "interface T { readonly attribute EventHandler onclick; };")) { error in
            XCTAssertTrue("\(error)".contains("T.onclick"), "\(error)")
        }
        XCTAssertThrowsError(try emit(prelude + "interface T { attribute EventHandler handler; };")) { error in
            XCTAssertTrue("\(error)".contains("T.handler"), "\(error)")
        }
    }
}
