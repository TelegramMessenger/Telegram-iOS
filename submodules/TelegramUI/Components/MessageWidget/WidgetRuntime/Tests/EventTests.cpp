// Event, its M1b subclasses and EventTarget's listener lists (M1b plan, Task 6; DOM "Events", HTML's event
// interfaces). Dispatch is DispatchTests.cpp's.
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Events/Events.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"

namespace {

/// The EventTarget a global names (the global holds it alive).
wr::EventTarget* targetNamed(JSContext* ctx, const char* name) {
    wr::Value g = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    wr::Value v = wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, g.get(), name));
    return static_cast<wr::EventTarget*>(wr::payloadImplementing(ctx, v.get(), wr::idl::kEventTarget));
}

size_t listenerCount(JSContext* ctx, const char* name) {
    const wr::Vector<wr::ListenerRef>* list = targetNamed(ctx, name)->listeners();
    return list ? list->size() : 0;
}

} // namespace

WR_TEST(testEventConstructorAndDefaults) {
    wr_test::DOMEnv env;
    env.eval("var e = new Event('x')");
    CHECK_JS_EQ(env, "e.type", "x");
    CHECK_JS(env, "e.bubbles === false && e.cancelable === false && e.composed === false");
    CHECK_JS(env, "e.target === null && e.currentTarget === null && e.srcElement === null");
    CHECK_JS(env, "e.eventPhase === Event.NONE && Event.AT_TARGET === 2 && e.BUBBLING_PHASE === 3");
    CHECK_JS(env, "e.defaultPrevented === false && e.returnValue === true && e.isTrusted === false");
    CHECK_JS(env, "typeof e.timeStamp === 'number'");
    CHECK_JS(env, "e.composedPath().length === 0");
    env.eval("var f = new Event('y', { bubbles: true, cancelable: true, composed: true })");
    CHECK_JS(env, "f.bubbles && f.cancelable && f.composed");
    CHECK_THROWS(env, "Event('x')", "TypeError");
    CHECK_THROWS(env, "new Event()", "TypeError");
    CHECK_JS(env, "String(e) === '[object Event]' && e instanceof Event");
}

WR_TEST(testIsTrustedIsAnOwnUnforgeableAccessor) {
    wr_test::DOMEnv env;
    env.eval("var a = new Event('a'), b = new CustomEvent('b')");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(a, 'isTrusted').configurable === false");
    CHECK_JS(env, "typeof Object.getOwnPropertyDescriptor(a, 'isTrusted').get === 'function'");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(a, 'isTrusted').get === Object.getOwnPropertyDescriptor(b, 'isTrusted').get");
    CHECK_JS(env, "!('isTrusted' in Event.prototype)");
}

WR_TEST(testCancelationNeedsCancelable) {
    wr_test::DOMEnv env;
    env.eval("var n = new Event('n'); n.preventDefault(); var c = new Event('c', { cancelable: true }); c.preventDefault()");
    CHECK_JS(env, "n.defaultPrevented === false && n.returnValue === true");
    CHECK_JS(env, "c.defaultPrevented === true && c.returnValue === false");
    env.eval("var r = new Event('r', { cancelable: true }); r.returnValue = true; var before = r.defaultPrevented; r.returnValue = false");
    CHECK_JS(env, "before === false && r.defaultPrevented === true");
}

WR_TEST(testPropagationFlagsAndInitEvent) {
    wr_test::DOMEnv env;
    env.eval("var e = new Event('x'); e.stopPropagation()");
    CHECK_JS(env, "e.cancelBubble === true");
    env.eval("e.cancelBubble = false");
    CHECK_JS(env, "e.cancelBubble === true");  // setting false does nothing
    env.eval("e.initEvent('y', true, true)");
    CHECK_JS(env, "e.type === 'y' && e.bubbles && e.cancelable && e.cancelBubble === false");
    env.eval("var s = new Event('s'); s.stopImmediatePropagation()");
    CHECK_JS(env, "s.cancelBubble === true");
    env.eval("var made = document.createEvent('Event')");
    CHECK_JS(env, "made.type === '' && made.isTrusted === false && made instanceof Event");
}

WR_TEST(testCustomEventDetail) {
    wr_test::DOMEnv env;
    CHECK_JS(env, "new CustomEvent('c').detail === null");
    CHECK_JS(env, "(o => new CustomEvent('c', { detail: o }).detail === o)({})");
    env.eval("var c = document.createEvent('CustomEvent'); c.initCustomEvent('d', true, false, 7)");
    CHECK_JS(env, "c.type === 'd' && c.bubbles === true && c.cancelable === false && c.detail === 7");
    CHECK_JS(env, "c instanceof CustomEvent && c instanceof Event");
}

WR_TEST(testErrorPromiseRejectionAndPageTransitionEvents) {
    wr_test::DOMEnv env;
    env.eval("var err = new Error('x'); var e = new ErrorEvent('error', { message: 'm', filename: 'f.js', lineno: 3, colno: 4, error: err })");
    CHECK_JS(env, "e.message === 'm' && e.filename === 'f.js' && e.lineno === 3 && e.colno === 4 && e.error === err");
    CHECK_JS(env, "(d => d.message === '' && d.filename === '' && d.lineno === 0 && d.error === undefined)(new ErrorEvent('error'))");
    env.eval("var p = Promise.resolve(1); var r = new PromiseRejectionEvent('unhandledrejection', { promise: p, reason: 2 })");
    CHECK_JS(env, "r.promise === p && r.reason === 2");
    CHECK_THROWS(env, "new PromiseRejectionEvent('x', {})", "TypeError");
    CHECK_JS(env, "new PageTransitionEvent('pageshow').persisted === false");
    CHECK_JS(env, "new PageTransitionEvent('pageshow', { persisted: true }).persisted === true");
}

WR_TEST(testCreateEventSupportsEventAndCustomEvent) {
    wr_test::DOMEnv env;
    for (const char* name : {"Event", "events", "HTMLEvents", "SVGEvents"}) {
        CHECK_JS(env, (std::string("document.createEvent('") + name + "').constructor === Event").c_str());
    }
    CHECK_JS(env, "document.createEvent('customevent') instanceof CustomEvent");
    // The UI events arrived with M1d's taps (TapTests); a keyboard has no path into widgets.
    CHECK_THROWS(env, "document.createEvent('KeyboardEvent')", "NotSupportedError");
    CHECK_THROWS(env, "document.createEvent('Nope')", "NotSupportedError");
}

WR_TEST(testTimeStampReadsTheHostClock) {
    wr_test::TestHost host;
    host.now = 1234.5;
    wr_test::DOMEnv env(host);
    CHECK_JS_EQ(env, "new Event('x').timeStamp", "1234.5");
    host.now = 2000;
    CHECK_JS_EQ(env, "document.createEvent('Event').timeStamp", "2000");
}

WR_TEST(testListenerListsFollowDOM) {
    wr_test::DOMEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var t = new EventTarget(); function f() {} function g() {}");
    CHECK_EQ(listenerCount(ctx, "t"), size_t(0));
    CHECK(targetNamed(ctx, "t")->listeners() == nullptr);  // allocated on the first add
    env.eval("t.addEventListener('x', f); t.addEventListener('x', f); t.addEventListener('x', f, true); t.addEventListener('x', g)");
    CHECK_EQ(listenerCount(ctx, "t"), size_t(3));           // the duplicate is ignored; capture tells two apart
    env.eval("t.addEventListener('x', null); t.removeEventListener('x', null)");
    CHECK_EQ(listenerCount(ctx, "t"), size_t(3));
    env.eval("t.removeEventListener('x', f)");
    CHECK_EQ(listenerCount(ctx, "t"), size_t(2));           // the non-capture one only
    env.eval("t.removeEventListener('x', f, { capture: true })");
    CHECK_EQ(listenerCount(ctx, "t"), size_t(1));
    CHECK_THROWS(env, "t.addEventListener('x', 5)", "TypeError");
    env.eval("t.addEventListener('y', { handleEvent() {} }, { once: true, passive: true })");
    const wr::EventListener& y = *targetNamed(ctx, "t")->listeners()->back();
    CHECK(y.once && y.passive && !y.capture && !y.removed);
    // The default passive value: touch and wheel listeners on the document, its element and its body.
    env.eval("var body = document.body; body.addEventListener('touchstart', f); document.addEventListener('wheel', f); "
             "var div = document.createElement('div'); div.addEventListener('touchmove', f); div.addEventListener('click', f)");
    CHECK(targetNamed(ctx, "body")->listeners()->back()->passive);
    CHECK(targetNamed(ctx, "document")->listeners()->back()->passive);
    CHECK(!(*targetNamed(ctx, "div")->listeners())[0]->passive);
    CHECK(!(*targetNamed(ctx, "div")->listeners())[1]->passive);
    env.eval("body.addEventListener('touchstart', g, { passive: false })");
    CHECK(!targetNamed(ctx, "body")->listeners()->back()->passive);
}

WR_TEST(testListenerCyclesAreCollected) {
    wr_test::DOMEnv env;
    wr::Runtime& runtime = env.runtime();
    // Materialize everything the loop makes, so the count below holds only the loop's objects.
    env.eval("(() => { const d = document.createElement('div'); d.addEventListener('click', () => d); "
             "const t = new EventTarget(); t.addEventListener('x', { handleEvent() { return t } }); })(); gc()");
    size_t before = runtime.liveObjects();
    env.eval("(() => { for (let i = 0; i < 200; i++) { const d = document.createElement('div'); d.addEventListener('click', () => d.id); "
             "const t = new EventTarget(); t.addEventListener('x', { handleEvent() { return t } }); } })()");
    CHECK(runtime.liveObjects() > before);
    env.eval("gc()");
    CHECK_EQ(runtime.liveObjects(), before);
    // A connected node keeps its listener, and so its closure, alive.
    env.eval("(() => { const d = document.body.appendChild(document.createElement('div')); d.addEventListener('click', () => d); })(); gc()");
    wr::Node* div = wr::globalDocument(env.ctx()).body(env.ctx())->lastChildNode();
    CHECK(div && div->listeners() && div->listeners()->size() == 1);
}

WR_TEST(testNodesAreEventTargets) {
    wr_test::DOMEnv env;
    CHECK_JS(env, "Object.getPrototypeOf(Node.prototype) === EventTarget.prototype");
    CHECK_JS(env, "document instanceof EventTarget && document.body instanceof EventTarget && new Text('') instanceof EventTarget");
    CHECK_JS(env, "new EventTarget() instanceof EventTarget && String(new EventTarget()) === '[object EventTarget]'");
    CHECK_THROWS(env, "EventTarget.prototype.addEventListener.call({}, 'x', null)", "TypeError");
    CHECK_THROWS(env, "EventTarget()", "TypeError");
}
