import XCTest
@testable import WidgetIDLCore

final class CallbackTests: XCTestCase {
    private let options = EmitterOptions(implNamespace: "wr::testidl", tableNamespace: "wr::testidl", headerName: "TestBindings.h")

    private func emit(_ source: String) throws -> (header: String, source: String) {
        return try emitCpp(try resolve([try parseIDL(source, file: "t.webidl")]), options: self.options)
    }

    func testCallbacksKeepTheirKindAndAttributes() throws {
        let defs = try parseIDL("""
        [LegacyTreatNonObjectAsNull] callback EventHandlerNonNull = any (Event event);
        callback interface EventListener { undefined handleEvent(Event event); };
        """, file: "t.webidl")
        XCTAssertEqual(defs[0], .callback(CallbackDefinition(name: "EventHandlerNonNull", isInterface: false, extendedAttributes: [ExtendedAttribute(name: "LegacyTreatNonObjectAsNull")])))
        XCTAssertEqual(defs[1], .callback(CallbackDefinition(name: "EventListener", isInterface: true, extendedAttributes: [])))
        let model = try resolve([defs])
        XCTAssertEqual(model.callbacks["EventHandlerNonNull"]?.extendedAttributes.has("LegacyTreatNonObjectAsNull"), true)
        XCTAssertEqual(model.callbacks["EventListener"]?.isInterface, true)
    }

    func testCallbackFunctionsAndInterfacesConvert() throws {
        let out = try emit("""
        callback Fn = undefined (DOMString s);
        callback interface Listener { undefined handleEvent(DOMString s); };
        interface S { undefined call(Fn f); undefined listen(Listener? l); attribute Fn? stored; };
        """)
        XCTAssertTrue(out.header.contains("#include \"Sources/Support/Callbacks.h\""), out.header)
        XCTAssertTrue(out.source.contains("wr::convert<wr::Callback>(ctx, argv[0], wr::ArgInfo{\"S\", \"call\", 0})"), out.source)
        XCTAssertTrue(out.source.contains("wr::convert<std::optional<wr::CallbackInterface>>(ctx, argv[0], wr::ArgInfo{\"S\", \"listen\", 0})"), out.source)
        XCTAssertTrue(out.source.contains("self.setStored(ctx, wr::convert<std::optional<wr::Callback>>(ctx, value, wr::ArgInfo{\"S\", \"stored\", 0}));"), out.source)
    }

    func testLegacyTreatNonObjectAsNullIsNullableOnly() throws {
        let out = try emit("[LegacyTreatNonObjectAsNull] callback H = any (any e); interface S { attribute H? h; };")
        XCTAssertTrue(out.source.contains("wr::convert<std::optional<wr::LegacyCallback>>(ctx, value, "), out.source)
        XCTAssertThrowsError(try emit("[LegacyTreatNonObjectAsNull] callback H = any (any e); interface S { attribute H h; };")) { error in
            XCTAssertTrue("\(error)".contains("S.h"), "\(error)")
        }
    }

    func testUnionsTryACallableBeforeAString() throws {
        let out = try emit("callback Fn = any (); interface S { undefined f((DOMString or Fn) handler); };")
        let callable = try XCTUnwrap(out.source.range(of: "if (JS_IsFunction(ctx, v)) return std::variant<wr::String, wr::Callback>(wr::Callback(wr::Value::dup(ctx, v)));"), out.source)
        let string = try XCTUnwrap(out.source.range(of: "return std::variant<wr::String, wr::Callback>(wr::Converter<wr::String>::from(ctx, v, info));"), out.source)
        XCTAssertTrue(callable.lowerBound < string.lowerBound)
    }

    func testAnyDefaultsToNull() throws {
        let out = try emit("dictionary D { any detail = null; }; interface S { undefined f(optional any x = null); undefined g(optional D d = {}); };")
        XCTAssertTrue(out.header.contains("wr::Value detail{};"), out.header)
        XCTAssertTrue(out.source.contains(": wr::Value::adopt(ctx, JS_NULL)"), out.source)
        XCTAssertTrue(out.source.contains("result.detail = wr::Value::adopt(ctx, JS_NULL);"), out.source)
    }

    func testAnUnknownNameIsStillAnError() {
        XCTAssertThrowsError(try emit("interface S { undefined f(Nowhere n); };")) { error in
            XCTAssertTrue("\(error)".contains("S.f"), "\(error)")
        }
    }
}
