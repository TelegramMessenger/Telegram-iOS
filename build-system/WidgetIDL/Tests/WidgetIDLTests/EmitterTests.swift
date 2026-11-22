import XCTest
@testable import WidgetIDLCore

final class EmitterTests: XCTestCase {
    private let options = EmitterOptions(implNamespace: "wr::testidl", tableNamespace: "wr::testidl", headerName: "TestBindings.h")

    private func emit(_ source: String) throws -> (header: String, source: String) {
        return try emitCpp(try resolve([try parseIDL(source, file: "t.webidl")]), options: self.options)
    }

    func testTableIndicesAndEntries() throws {
        let out = try emit("""
        interface Base {};
        [LegacyNoInterfaceObject] interface Sample : Base {
          const unsigned short ONE = 1;
          readonly attribute unsigned long count;
          attribute DOMString? label;
          Base? find(DOMString name, optional boolean deep = false);
          static double half(unrestricted double x);
        };
        """)
        XCTAssertTrue(out.header.contains("inline constexpr uint16_t kBase = 0;"), out.header)
        XCTAssertTrue(out.header.contains("inline constexpr uint16_t kSample = 1;"))
        XCTAssertTrue(out.header.contains("extern const wr::InterfaceTable kTable;"))
        XCTAssertTrue(out.header.contains("template <> struct wr::InterfaceIndexOf<wr::testidl::Sample> { static constexpr uint16_t value = wr::testidl::kSample; };"), out.header)
        XCTAssertTrue(out.source.contains("static JSValue Sample_get_count(JSContext* ctx, JSValueConst thisVal)"))
        XCTAssertTrue(out.source.contains("static JSValue Sample_set_label(JSContext* ctx, JSValueConst thisVal, JSValueConst value)"))
        XCTAssertTrue(out.source.contains("self.setLabel(ctx, wr::convert<std::optional<wr::String>>(ctx, value, wr::ArgInfo{\"Sample\", \"label\", 0}));"), out.source)
        XCTAssertTrue(out.source.contains("static JSValue Sample_find(JSContext* ctx, JSValueConst thisVal, int argc, JSValueConst* argv)"))
        XCTAssertTrue(out.source.contains("argc > 1 && !JS_IsUndefined(argv[1]) ? wr::convert<bool>(ctx, argv[1], wr::ArgInfo{\"Sample\", \"find\", 1}) : false"), out.source)
        XCTAssertTrue(out.source.contains("wr::testidl::Sample::half(ctx, "), out.source)
        XCTAssertTrue(out.source.contains("{\"ONE\", wr::MemberKind::Constant"), out.source)
        XCTAssertTrue(out.source.contains("/* exposed */ false"), out.source)
        XCTAssertTrue(out.source.contains("/* parent */ 0"), out.source)
    }

    func testReflectNeedsNoImplementation() throws {
        let out = try emit("""
        interface Element { [Reflect] attribute DOMString title; [Reflect=data-flag] attribute boolean flag; };
        """)
        XCTAssertTrue(out.source.contains("wr::reflect::getString(ctx, self, "), out.source)
        XCTAssertTrue(out.source.contains("wr::reflect::setBoolean(ctx, self, "), out.source)
        XCTAssertTrue(out.source.contains("\"title\""))
        XCTAssertTrue(out.source.contains("\"data-flag\""))
    }

    /// CSSOM's camel-cased and dashed attributes (CSSStyleProperties): each goes to the declaration block's generic
    /// accessors with the property's name, and a dashed name is an attribute of its own on the same accessors.
    func testCSSPropertyGoesToTheDeclarationBlock() throws {
        let out = try emit("""
        interface CSSStyleDeclaration {
          [CEReactions, CSSProperty=background-color] attribute [LegacyNullToEmptyString] DOMString backgroundColor;
          [CEReactions, CSSProperty=width] attribute [LegacyNullToEmptyString] DOMString width;
          [CEReactions, CSSProperty=-webkit-line-clamp] attribute [LegacyNullToEmptyString] DOMString WebkitLineClamp;
          [CEReactions, CSSProperty=-webkit-line-clamp] attribute [LegacyNullToEmptyString] DOMString webkitLineClamp;
        };
        """)
        XCTAssertTrue(out.source.contains("return wr::toJS(ctx, self.propertyValue(ctx, wr::tableAtom(ctx, "), out.source)
        XCTAssertTrue(out.source.contains("self.setPropertyValue(ctx, wr::tableAtom(ctx, "), out.source)
        XCTAssertTrue(out.source.contains("\"background-color\","), out.source)
        XCTAssertTrue(out.source.contains("{\"backgroundColor\", wr::MemberKind::Attribute, nullptr, CSSStyleDeclaration_get_backgroundColor, CSSStyleDeclaration_set_backgroundColor,"), out.source)
        XCTAssertTrue(out.source.contains("{\"background-color\", wr::MemberKind::Attribute, nullptr, CSSStyleDeclaration_get_backgroundColor, CSSStyleDeclaration_set_backgroundColor,"), out.source)
        XCTAssertEqual(out.source.components(separatedBy: "{\"width\", wr::MemberKind::Attribute").count, 2, "a name without a dash has one attribute")
        XCTAssertEqual(out.source.components(separatedBy: "{\"-webkit-line-clamp\", wr::MemberKind::Attribute").count, 2, "two attributes of one property, one dashed attribute")
    }

    /// An optional argument of an annotated string type gets its default as that type.
    func testAnAnnotatedStringDefaultIsOfItsType() throws {
        let out = try emit("""
        interface CSSStyleDeclaration {
          undefined setProperty(DOMString property, [LegacyNullToEmptyString] DOMString value, optional [LegacyNullToEmptyString] DOMString priority = "");
        };
        """)
        XCTAssertTrue(out.source.contains(": wr::LegacyNullToEmptyString(wr::String::fromUTF8(ctx, \"\"))"), out.source)
        XCTAssertTrue(out.source.contains("wr::convert<wr::LegacyNullToEmptyString>(ctx, argv[1]"), out.source)
    }

    func testUnionsVariadicsDictionariesAndGetters() throws {
        let out = try emit("""
        dictionary Options { DOMString is; };
        interface Node {};
        interface Sample {
          undefined add((Node or DOMString)... items);
          undefined make(optional (DOMString or Options) options = {});
          getter Node? item(unsigned long index);
          readonly attribute unsigned long length;
          iterable<Node>;
          stringifier attribute DOMString value;
        };
        """)
        XCTAssertTrue(out.header.contains("struct Options {"), out.header)
        XCTAssertTrue(out.source.contains("wr::convertRest<std::variant<wr::testidl::Node*, wr::String>>(ctx, argc, argv, 0, "), out.source)
        XCTAssertTrue(out.source.contains("std::variant<wr::String, wr::testidl::Options>"), out.source)
        XCTAssertTrue(out.source.contains("&wr::IndexedExotic<wr::testidl::Sample>::methods"), out.source)
        XCTAssertTrue(out.source.contains("/* valueIterable */ true"), out.source)
        XCTAssertTrue(out.source.contains("Sample_toString"), out.source)
    }

    func testPutForwardsSequencesAndOptionalsWithoutDefault() throws {
        let out = try emit("""
        interface List { attribute DOMString value; };
        interface Sample {
          [SameObject, PutForwards=value] readonly attribute List list;
          sequence<DOMString> names();
          boolean toggle(DOMString token, optional boolean force);
        };
        """)
        XCTAssertTrue(out.source.contains("JS_SetPropertyStr(ctx, target, \"value\", JS_DupValue(ctx, value))"), out.source)
        XCTAssertTrue(out.source.contains("Sample_set_list"), out.source)
        XCTAssertTrue(out.source.contains("self.names(ctx)"), out.source)
        XCTAssertTrue(out.source.contains("std::optional<bool>(wr::convert<bool>(ctx, argv[1], "), out.source)
    }

    func testUnsupportedTypesNameTheMember() {
        XCTAssertThrowsError(try emit("interface A { undefined f(record<DOMString, long> r); };")) { error in
            XCTAssertTrue("\(error)".contains("A.f"), "\(error)")
        }
        XCTAssertThrowsError(try emit("interface A { undefined f(long x); undefined f(DOMString y); };")) { error in
            XCTAssertTrue("\(error)".contains("overload"), "\(error)")
        }
    }
}

final class EmitterFixRound1Tests: XCTestCase {
    private let options = EmitterOptions(implNamespace: "wr::testidl", tableNamespace: "wr::testidl", headerName: "TestBindings.h")

    private func emit(_ source: String) throws -> (header: String, source: String) {
        return try emitCpp(try resolve([try parseIDL(source, file: "t.webidl")]), options: self.options)
    }

    func testOptionalInterfaceWithoutDefaultIsNullptr() throws {
        let out = try emit("interface Node {}; interface S { undefined f(optional Node n); };")
        XCTAssertTrue(out.source.contains(": nullptr"), out.source)
        XCTAssertFalse(out.source.contains("Node*{}"), out.source)
    }

    func testDictionariesFollowForwardDeclarationsAndDependencyOrder() throws {
        let out = try emit("""
        dictionary Outer { Inner inner = {}; Node node; };
        dictionary Inner { DOMString s; };
        interface Node {};
        """)
        let fwd = try XCTUnwrap(out.header.range(of: "class Node;"), out.header)
        let inner = try XCTUnwrap(out.header.range(of: "struct Inner {"), out.header)
        let outer = try XCTUnwrap(out.header.range(of: "struct Outer {"), out.header)
        XCTAssertTrue(fwd.lowerBound < inner.lowerBound)
        XCTAssertTrue(inner.lowerBound < outer.lowerBound)
    }

    func testEnumsAreChecked() throws {
        let out = try emit("""
        enum Mode { "a", "b" };
        interface S { attribute Mode mode; undefined f(Mode m); };
        """)
        XCTAssertTrue(out.source.contains("enumValid_Mode"), out.source)
        XCTAssertTrue(out.source.contains("enumChecked_Mode(wr::convert<wr::String>(ctx, argv[0]"), out.source)
        XCTAssertTrue(out.source.contains("if (!enumValid_Mode(converted)) return JS_UNDEFINED;"), out.source)
    }

    /// WebIDL's "define the iteration methods": indexed properties (an indexed getter and an integer `length`) give
    /// @@iterator alone; a value iterator adds entries, keys, values and forEach; named properties give nothing.
    func testIndexedPropertiesGetAnIterator() throws {
        let out = try emit("""
        interface Node {};
        interface Plain { readonly attribute unsigned long length; getter Node? item(unsigned long index); getter Node? namedItem(DOMString name); };
        interface Iter { getter Node? item(unsigned long index); readonly attribute unsigned long length; iterable<Node>; };
        interface Named { getter DOMString (DOMString name); };
        interface NoLength { getter Node? item(unsigned long index); };
        """)
        func entry(_ name: String) -> String {
            return out.source.components(separatedBy: "\n").first(where: { $0.contains("{\"\(name)\", /* parent */") }) ?? ""
        }
        XCTAssertTrue(entry("Plain").hasSuffix("/* valueIterable */ false, /* indexedIterator */ true, /* pairIteration */ nullptr},"), entry("Plain"))
        XCTAssertTrue(entry("Iter").hasSuffix("/* valueIterable */ true, /* indexedIterator */ true, /* pairIteration */ nullptr},"), entry("Iter"))
        XCTAssertTrue(entry("Named").hasSuffix("/* valueIterable */ false, /* indexedIterator */ false, /* pairIteration */ nullptr},"), entry("Named"))
        XCTAssertTrue(entry("NoLength").hasSuffix("/* valueIterable */ false, /* indexedIterator */ false, /* pairIteration */ nullptr},"), entry("NoLength"))
        // A value iterator needs indexed properties to iterate.
        XCTAssertThrowsError(try emit("interface Node {}; interface A { getter Node? item(unsigned long index); iterable<Node>; };")) { error in
            XCTAssertTrue("\(error)".contains("A: a value iterator"), "\(error)")
        }
    }

    /// V5a plan, Task 5: a pair iterator (`iterable<K, V>`) gets its two adapters, which call the implementation's
    /// iterationLength and iterationPair, and a PairIteration the runtime defines the methods and iterators from.
    func testPairIterableEmitsItsAdapters() throws {
        let out = try emit("interface P { iterable<DOMString, long>; };")
        let entry = out.source.components(separatedBy: "\n").first(where: { $0.contains("{\"P\", /* parent */") }) ?? ""
        XCTAssertTrue(entry.hasSuffix("/* valueIterable */ false, /* indexedIterator */ false, /* pairIteration */ &P_pairIteration},"), entry)
        XCTAssertTrue(out.source.contains("static const wr::PairIteration P_pairIteration"), out.source)
        XCTAssertTrue(out.source.contains("self.iterationLength(ctx)"), out.source)
        XCTAssertTrue(out.source.contains("self.iterationPair(ctx, index)"), out.source)
    }

    /// A member named with a C++ keyword (URLSearchParams.delete) calls the implementation's name with a trailing "_".
    func testACppKeywordNameIsEscaped() throws {
        let out = try emit("interface A { undefined delete(DOMString name); readonly attribute long default; };")
        XCTAssertTrue(out.source.contains("self.delete_(ctx"), out.source)
        XCTAssertTrue(out.source.contains("self.default_(ctx)"), out.source)
        XCTAssertTrue(out.source.contains("{\"delete\", wr::MemberKind::Method"), out.source)
    }

    func testAPairIterableBesideIndexedPropertiesIsAnError() {
        XCTAssertThrowsError(try emit("interface Node {}; interface A { getter Node? item(unsigned long index); readonly attribute unsigned long length; iterable<DOMString, long>; };")) { error in
            XCTAssertTrue("\(error)".contains("A: a pair iterator"), "\(error)")
        }
    }

    func testSequenceArgumentsAndMembersAreRejected() {
        XCTAssertThrowsError(try emit("interface A { undefined f(sequence<DOMString> s); };")) { error in
            XCTAssertTrue("\(error)".contains("A.f"), "\(error)")
        }
        XCTAssertThrowsError(try emit("dictionary D { sequence<DOMString> s; }; interface A { undefined f(optional D d = {}); };")) { error in
            XCTAssertTrue("\(error)".contains("D.s"), "\(error)")
        }
    }

    /// The V3b review's C1: a dictionary member of interface type keeps its object alive with the dictionary.
    func testAnInterfaceMemberOfADictionaryKeepsItsObject() throws {
        let out = try emit("""
        interface Node {};
        dictionary Options { Node? root = null; required Node target; DOMString name = ""; };
        interface Uses { undefined take(optional Options options = {}); };
        """)
        XCTAssertTrue(out.header.contains("    wr::Value root_keep;"), out.header)
        XCTAssertTrue(out.header.contains("    wr::Value target_keep;"), out.header)
        XCTAssertFalse(out.header.contains("name_keep"), out.header)
        XCTAssertTrue(out.source.contains("result.root_keep = m;"), out.source)
        XCTAssertTrue(out.source.contains("result.target_keep = m;"), out.source)
    }
}
