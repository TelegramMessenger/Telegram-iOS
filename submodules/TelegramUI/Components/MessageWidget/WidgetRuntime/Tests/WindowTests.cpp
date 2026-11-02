// The Window global (M1b plan, Task 8): the global object is the Window, its members follow their IDL (unforgeable,
// replaceable), events reach it, and Location, Performance and console read the document and the host.
#include <memory>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Events/Events.h"
#include "Sources/Host/Globals.h"
#include "Tests/HostHarness.h"

WR_TEST(testTheGlobalIsTheWindow) {
    wr_test::HostEnv env;
    CHECK_JS(env, "window === globalThis && self === window && frames === window && parent === window && top === window");
    CHECK_JS(env, "window.window === window && opener === null && length === 0");
    CHECK_JS(env, "Object.getPrototypeOf(window) === Window.prototype");
    CHECK_JS(env, "Object.getPrototypeOf(Window.prototype) === EventTarget.prototype");
    CHECK_JS(env, "window instanceof Window && window instanceof EventTarget");
    CHECK_JS(env, "String(window) === '[object Window]'");
    CHECK_THROWS(env, "new Window()", "TypeError");
    JSValue g = JS_GetGlobalObject(env.ctx());
    CHECK(env.runtime().interfaceOf(g) == wr::idl::kWindow);
    JS_FreeValue(env.ctx(), g);
}

WR_TEST(testWindowMembersFollowTheirIDL) {
    wr_test::HostEnv env;
    // [LegacyUnforgeable]: own, non-configurable accessors; assignment does nothing.
    CHECK_JS(env, "(d => d.get && !d.set && d.configurable === false && d.enumerable)(Object.getOwnPropertyDescriptor(window, 'document'))");
    CHECK_JS(env, "(d => d.get && d.configurable === false)(Object.getOwnPropertyDescriptor(window, 'window'))");
    CHECK_JS(env, "(d => d.get && d.configurable === false)(Object.getOwnPropertyDescriptor(window, 'location'))");
    env.eval("window = 5; document = 6");
    CHECK_JS(env, "window === globalThis && document instanceof Document");
    CHECK_JS(env, "delete window.document === false && document === window.document");
    // [Replaceable]: assignment replaces the accessor with a data property.
    env.eval("self = 7; frames = 8");
    CHECK_JS(env, "self === 7 && frames === 8 && Object.getOwnPropertyDescriptor(window, 'self').value === 7");
    // Brand checks: the accessors refuse another `this`.
    CHECK_THROWS(env, "Object.getOwnPropertyDescriptor(window, 'document').get.call({})", "TypeError");
    // The members live on the global, not on the prototype.
    CHECK_JS(env, "!Window.prototype.hasOwnProperty('document') && window.hasOwnProperty('performance')");
}

WR_TEST(testEventTargetMembersWorkOnTheWindow) {
    wr_test::HostEnv env;
    env.eval("var hits = []; window.addEventListener('w', e => hits.push(e.currentTarget === window));"
             "window.dispatchEvent(new Event('w'))");
    CHECK_JS_EQ(env, "hits.join()", "true");
    // Bare calls: an undefined `this` is the global (WebIDL).
    env.eval("var bare = false; addEventListener('bare', () => { bare = true }); dispatchEvent(new Event('bare'))");
    CHECK_JS(env, "bare === true");
    env.eval("removeEventListener('bare', null)");
}

WR_TEST(testEventsReachTheWindowExceptLoad) {
    wr_test::HostEnv env;
    env.eval("var seen = []; window.addEventListener('x', e => seen.push('x:' + e.eventPhase)); window.addEventListener('load', () => seen.push('load'));"
             "document.body.dispatchEvent(new Event('x', { bubbles: true }));"
             "document.body.dispatchEvent(new Event('load', { bubbles: true }));"
             "document.createElement('div').dispatchEvent(new Event('x', { bubbles: true }));"
             "var t = document.createElement('template'); t.content.appendChild(document.createElement('i')).dispatchEvent(new Event('x', { bubbles: true }));"
             "new Document().dispatchEvent(new Event('x', { bubbles: true }))");
    CHECK_JS_EQ(env, "seen.join()", "x:3");
    env.eval("var last; document.body.addEventListener('p', e => { const p = e.composedPath(); last = p[p.length - 1] }); document.body.dispatchEvent(new Event('p'))");
    CHECK_JS(env, "last === window");
    env.eval("var cap = []; window.addEventListener('c', e => cap.push(e.eventPhase), true); document.body.dispatchEvent(new Event('c'))");
    CHECK_JS_EQ(env, "cap.join()", "1");
}

WR_TEST(testLocationSplitsTheDocumentURL) {
    wr_test::HostEnv env;
    CHECK_JS(env, "location instanceof Location && window.location === location");
    CHECK_JS_EQ(env, "location.href", "about:srcdoc");
    CHECK_JS_EQ(env, "String(location)", "about:srcdoc");
    CHECK_JS_EQ(env, "[location.protocol, location.host, location.pathname, location.search, location.hash, location.origin].join('|')", "about:||srcdoc|||null");
    wr::globalDocument(env.ctx()).setURL(env.ctx(), "http://web-platform.test:8000/dom/nodes/a.html?x=1#h");
    CHECK_JS_EQ(env, "document.URL", "http://web-platform.test:8000/dom/nodes/a.html?x=1#h");
    CHECK_JS_EQ(env, "[location.protocol, location.host, location.hostname, location.port, location.pathname, location.search, location.hash].join('|')",
                "http:|web-platform.test:8000|web-platform.test|8000|/dom/nodes/a.html|?x=1|#h");
    CHECK_JS_EQ(env, "location.origin", "http://web-platform.test:8000");
    wr::globalDocument(env.ctx()).setURL(env.ctx(), "https://example.test:443/?#");
    CHECK_JS_EQ(env, "[location.host, location.port, location.pathname, location.search, location.hash, location.origin].join('|')",
                "example.test||/|||https://example.test");
}

WR_TEST(testPerformanceAndTimeStampsReadTheHostClock) {
    wr_test::HostEnv env;
    env.host().now = 1500;
    CHECK_JS_EQ(env, "performance.now()", "1500");
    CHECK_JS_EQ(env, "new Event('x').timeStamp", "1500");
    CHECK_JS_EQ(env, "performance.timeOrigin", "1767225600000");
    CHECK_JS(env, "performance instanceof Performance && performance === window.performance");
    CHECK_JS_EQ(env, "JSON.stringify(performance)", "{\"timeOrigin\":1767225600000}");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(window, 'performance').set !== undefined");
    env.eval("performance = 1");
    CHECK_JS(env, "performance === 1");

    // The origin is the host's clock when the window was installed.
    wr_test::TestHost host;
    host.now = 100;
    wr::Runtime::Options options;
    options.interfaces = &wr::idl::kTable;
    options.host = &host;
    std::unique_ptr<wr::Runtime> runtime = wr::Runtime::create(options);
    JSContext* ctx = runtime->context();
    wr::installDOM(ctx, wr::Document::createHTML(ctx));
    wr::installHost(ctx);
    host.now = 150;
    bool threw = false;
    CHECK(runtime->evaluateToString("performance.now()", "<test>", &threw) == "50");
    CHECK(runtime->evaluateToString("new Event('e').timeStamp", "<test>", &threw) == "50");
    CHECK(runtime->evaluateToString("performance.timeOrigin", "<test>", &threw) == "1767225600100");
}

WR_TEST(testConsoleWritesToTheHostLog) {
    wr_test::HostEnv env;
    env.eval("console.log('a', 1, {}); console.error(new Error('e')); console.warn(Symbol('s')); console.info(); console.debug(null, undefined)");
    const auto& logs = env.host().logs;
    CHECK_EQ(logs.size(), size_t(5));
    CHECK(logs[0].first == wr::LogLevel::Log && logs[0].second == "a 1 [object Object]");
    CHECK(logs[1].first == wr::LogLevel::Error && logs[1].second == "Error: e");
    CHECK(logs[2].first == wr::LogLevel::Warn && logs[2].second == "Symbol(s)");
    CHECK(logs[3].first == wr::LogLevel::Info && logs[3].second.empty());
    CHECK(logs[4].first == wr::LogLevel::Debug && logs[4].second == "null undefined");
    CHECK_JS(env, "(d => d.writable && d.configurable && !d.enumerable)(Object.getOwnPropertyDescriptor(window, 'console'))");
}

WR_TEST(testNodeConstructorsUseTheMainDocument) {
    wr_test::HostEnv env("<!doctype html><title>t</title>");
    CHECK_JS(env, "new Text('x').ownerDocument === document && new DocumentFragment().ownerDocument === document");
    CHECK_JS_EQ(env, "document.title", "t");
    CHECK(wr::HostState::find(env.ctx()) == &wr::HostState::of(env.ctx()));
    CHECK(&wr::HostState::of(env.ctx()).listenedTypes() == &wr::DOMState::of(env.ctx()).listenedTypes());
}

// Ruling 14's cut: a console line is the first kMaxDiagnosticBytes UTF-8 bytes of the whole line, ending at a character
// boundary, and the arguments after the cut are not converted.
WR_TEST(testConsoleLineIsCutAtTheCap) {
    CHECK_EQ(wr::kMaxDiagnosticBytes, size_t(4000));
    wr_test::HostEnv env;
    const auto& logs = env.host().logs;
    env.eval("var calls = 0; var counted = { toString() { calls++; return 'c'; } };"
             "console.log('a'.repeat(3000), 'b'.repeat(3000), counted)");
    CHECK_EQ(logs.size(), size_t(1));
    CHECK(logs[0].second == std::string(3000, 'a') + " " + std::string(999, 'b'));
    CHECK_JS(env, "calls === 0");
    // A three-byte character that does not fit is left out whole: the line stops one byte short of the cap.
    env.eval("console.log('a'.repeat(3999) + '\\u20ac', counted)");
    CHECK_EQ(logs.size(), size_t(2));
    CHECK(logs[1].second == std::string(3999, 'a'));
    CHECK_JS(env, "calls === 0");
    // The separator that fills the line is kept; the next argument is not converted.
    env.eval("console.log('a'.repeat(3999), counted)");
    CHECK(logs.size() == 3 && logs[2].second == std::string(3999, 'a') + " ");
    CHECK_JS(env, "calls === 0");
    // A symbol's text is cut the same way.
    env.eval("console.log('a'.repeat(3995), Symbol('desc'))");
    CHECK(logs.size() == 4 && logs[3].second == std::string(3995, 'a') + " Symb");
}

// A symbol description is converted as text, never as another argument: a symbol there is ToString's TypeError, not a
// recursion without bound.
WR_TEST(testConsoleSymbolDescriptionDoesNotRecurse) {
    wr_test::HostEnv env;
    CHECK_THROWS(env, "Object.defineProperty(Symbol.prototype, 'description', { value: Symbol('z') }); console.log(Symbol('s'))", "TypeError");
    CHECK(env.host().logs.empty());
}

WR_TEST(testTopAndLocationAreUnforgeable) {
    wr_test::HostEnv env;
    CHECK_JS(env, "(d => d.get && !d.set && d.configurable === false)(Object.getOwnPropertyDescriptor(window, 'top'))");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(window, 'location').set === undefined");
    env.eval("var before = location; location = 'x'; top = 5");
    CHECK_JS(env, "window.location === before && location instanceof Location && top === window");
}
