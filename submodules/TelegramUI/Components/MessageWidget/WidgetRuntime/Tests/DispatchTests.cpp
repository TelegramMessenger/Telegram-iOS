// DOM's dispatch (M1b plan, Task 7): the path, the phases, listener-list changes during dispatch (Review Focus 1),
// propagation and cancelation, handleEvent objects, reported exceptions, CPU stops, trusted events and the
// listened-types registry.
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Sources/Events/Events.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"

namespace {

wr::Value global(JSContext* ctx, const char* name) {
    wr::Value g = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    return wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, g.get(), name));
}

} // namespace

WR_TEST(testDispatchVisitsCaptureTargetBubbleInDOMOrder) {
    wr_test::DOMEnv env("<!doctype html><body><div id=a><span id=b></span></div>");
    env.eval("var log = []; var a = document.getElementById('a'), b = document.getElementById('b');"
             "a.addEventListener('e', () => log.push('a-bubble'));"
             "a.addEventListener('e', () => log.push('a-capture'), true);"
             "b.addEventListener('e', e => log.push('b-bubble:' + e.eventPhase));"
             "b.addEventListener('e', e => log.push('b-capture:' + e.eventPhase), true);"
             "document.addEventListener('e', e => log.push('doc-capture:' + e.eventPhase), true);"
             "document.addEventListener('e', e => log.push('doc-bubble:' + e.eventPhase));");
    env.eval("b.dispatchEvent(new Event('e', { bubbles: true }))");
    // At the target, the capture listener runs first although it was added second (DOM, not today's order).
    CHECK_JS_EQ(env, "log.join()", "doc-capture:1,a-capture,b-capture:2,b-bubble:2,a-bubble,doc-bubble:3");
    env.eval("log = []; b.dispatchEvent(new Event('e'))");
    CHECK_JS_EQ(env, "log.join()", "doc-capture:1,a-capture,b-capture:2,b-bubble:2");
}

WR_TEST(testListenerListChangesDuringDispatch) {
    wr_test::DOMEnv env;
    // A listener removed by an earlier one never runs; one added during dispatch waits for the next.
    env.eval("var log = [], t = document.createElement('div');"
             "function b() { log.push('b') } function c() { log.push('c') }"
             "t.addEventListener('x', function a() { log.push('a'); t.removeEventListener('x', b); t.addEventListener('x', c) });"
             "t.addEventListener('x', b);"
             "t.dispatchEvent(new Event('x')); log.push('|'); t.dispatchEvent(new Event('x'))");
    CHECK_JS_EQ(env, "log.join()", "a,|,a,c");
    // once
    env.eval("var n = 0; t.addEventListener('y', () => n++, { once: true }); t.dispatchEvent(new Event('y')); t.dispatchEvent(new Event('y'))");
    CHECK_JS_EQ(env, "n", "1");
    // A listener that removes itself still finishes; the next one runs.
    env.eval("var order = []; function self() { order.push('self'); t.removeEventListener('z', self) }"
             "t.addEventListener('z', self); t.addEventListener('z', () => order.push('next'));"
             "t.dispatchEvent(new Event('z')); t.dispatchEvent(new Event('z'))");
    CHECK_JS_EQ(env, "order.join()", "self,next,next");
    // Re-entrant dispatch of the event being dispatched throws; of another event it nests.
    env.eval("var e = new Event('r'), name = null; t.addEventListener('r', () => { try { t.dispatchEvent(e) } catch (x) { name = x.name } });"
             "t.dispatchEvent(e)");
    CHECK_JS_EQ(env, "name", "InvalidStateError");
    env.eval("var nest = []; t.addEventListener('outer', () => { t.dispatchEvent(new Event('inner')); nest.push('outer-after') });"
             "t.addEventListener('inner', () => nest.push('inner')); t.dispatchEvent(new Event('outer'))");
    CHECK_JS_EQ(env, "nest.join()", "inner,outer-after");
    // A once listener that dispatches the same type re-entrantly runs once.
    env.eval("var reentered = 0; t.addEventListener('o', () => { reentered++; t.dispatchEvent(new Event('o')) }, { once: true });"
             "t.dispatchEvent(new Event('o'))");
    CHECK_JS_EQ(env, "reentered", "1");
}

WR_TEST(testPropagationStops) {
    wr_test::DOMEnv env("<!doctype html><body><div id=a><span id=b></span></div>");
    env.eval("var log = [], a = document.getElementById('a'), b = document.getElementById('b');"
             "a.addEventListener('s', e => { log.push('a1'); e.stopPropagation() }, true);"
             "a.addEventListener('s', () => log.push('a2'), true);"
             "b.addEventListener('s', () => log.push('b'));"
             "b.dispatchEvent(new Event('s', { bubbles: true }))");
    // The other listeners on the node that stopped still run; later nodes do not.
    CHECK_JS_EQ(env, "log.join()", "a1,a2");
    env.eval("log = []; b.addEventListener('i', e => { log.push('i1'); e.stopImmediatePropagation() }); b.addEventListener('i', () => log.push('i2'));"
             "a.addEventListener('i', () => log.push('a')); b.dispatchEvent(new Event('i', { bubbles: true }))");
    CHECK_JS_EQ(env, "log.join()", "i1");
    env.eval("log = []; b.addEventListener('c', e => { e.cancelBubble = true }); a.addEventListener('c', () => log.push('a'));"
             "var c = new Event('c', { bubbles: true }); b.dispatchEvent(c)");
    CHECK_JS_EQ(env, "log.length", "0");
    CHECK_JS(env, "c.cancelBubble === false && c.eventPhase === 0 && c.currentTarget === null && c.target === b");
}

WR_TEST(testCancelationAndPassiveListeners) {
    wr_test::DOMEnv env;
    env.eval("var t = document.createElement('div'); t.addEventListener('p', e => e.preventDefault())");
    CHECK_JS(env, "t.dispatchEvent(new Event('p', { cancelable: true })) === false");
    CHECK_JS(env, "t.dispatchEvent(new Event('p')) === true");
    env.eval("t.addEventListener('q', e => e.preventDefault(), { passive: true })");
    CHECK_JS(env, "(e => t.dispatchEvent(e) === true && e.defaultPrevented === false)(new Event('q', { cancelable: true }))");
    // The default passive value: a document's touchstart listener cannot cancel; a div's can.
    env.eval("document.addEventListener('touchstart', e => e.preventDefault()); t.addEventListener('touchstart', e => e.preventDefault())");
    CHECK_JS(env, "document.dispatchEvent(new Event('touchstart', { cancelable: true })) === true");
    CHECK_JS(env, "t.dispatchEvent(new Event('touchstart', { cancelable: true })) === false");
    env.eval("t.addEventListener('rv', e => { e.returnValue = false })");
    CHECK_JS(env, "t.dispatchEvent(new Event('rv', { cancelable: true })) === false");
}

WR_TEST(testHandleEventObjectsAndThis) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    env.eval("var t = document.createElement('div'); var o = { handleEvent(e) { this.self = this; this.type = e.type } };"
             "t.addEventListener('h', o); t.dispatchEvent(new Event('h'))");
    CHECK_JS(env, "o.self === o && o.type === 'h'");
    // handleEvent is read at each dispatch, not when the listener was added.
    env.eval("var later = {}; t.addEventListener('h2', later); later.handleEvent = function () { later.ran = true }; t.dispatchEvent(new Event('h2'))");
    CHECK_JS(env, "later.ran === true");
    // A function's `this` is the current target.
    env.eval("var seenThis; t.addEventListener('h3', function () { seenThis = this }); t.dispatchEvent(new Event('h3'))");
    CHECK_JS(env, "seenThis === t");
    // A handleEvent that is not callable is a reported TypeError; dispatch goes on.
    env.eval("var after = false; t.addEventListener('h4', { handleEvent: 5 }); t.addEventListener('h4', () => { after = true }); t.dispatchEvent(new Event('h4'))");
    CHECK_JS(env, "after === true");
    CHECK(host.hasLog(wr::LogLevel::Error, "Uncaught TypeError"));
}

WR_TEST(testListenerExceptionsAreReportedAndDispatchContinues) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    env.eval("var ran = false, t = document.createElement('div');"
             "t.addEventListener('x', () => { throw new Error('boom') }); t.addEventListener('x', () => { ran = true });");
    CHECK_JS(env, "t.dispatchEvent(new Event('x')) === true");
    CHECK_JS(env, "ran === true");
    CHECK(host.hasLog(wr::LogLevel::Error, "Uncaught Error: boom"));
}

WR_TEST(testDispatchEventChecksTheEvent) {
    wr_test::DOMEnv env;
    env.eval("var t = new EventTarget()");
    CHECK_THROWS(env, "t.dispatchEvent(document.createEvent('Event'))", "InvalidStateError");
    CHECK_THROWS(env, "t.dispatchEvent(null)", "TypeError");
    CHECK_THROWS(env, "t.dispatchEvent({})", "TypeError");
    env.eval("var made = document.createEvent('Event'); made.initEvent('m', true, true); var got; t.addEventListener('m', e => { got = e })");
    CHECK_JS(env, "t.dispatchEvent(made) === true && got === made && made.isTrusted === false");
    // initEvent during dispatch does nothing.
    env.eval("var during; t.addEventListener('d', e => { e.initEvent('other', false, false); during = e.type }); t.dispatchEvent(new Event('d'))");
    CHECK_JS_EQ(env, "during", "d");
}

WR_TEST(testComposedPathDuringAndAfterDispatch) {
    wr_test::DOMEnv env("<!doctype html><body><div><span id=b></span></div>");
    env.eval("var path, b = document.getElementById('b'), e = new Event('c'); b.addEventListener('c', ev => { path = ev.composedPath().map(n => n.nodeName).join() }); b.dispatchEvent(e)");
    CHECK_JS_EQ(env, "path", "SPAN,DIV,BODY,HTML,#document");
    CHECK_JS(env, "e.composedPath().length === 0 && e.target === b");
    // A detached tree's path stops at its root.
    env.eval("var d = document.createElement('div'), i = d.appendChild(document.createElement('i')), p2; i.addEventListener('c', ev => { p2 = ev.composedPath().map(n => n.nodeName).join() }); i.dispatchEvent(new Event('c'))");
    CHECK_JS_EQ(env, "p2", "I,DIV");
    // A listener that removes the target from the tree does not change the path being dispatched.
    env.eval("var log = [], outer = document.body.appendChild(document.createElement('p')), inner = outer.appendChild(document.createElement('em'));"
             "inner.addEventListener('m', () => { outer.remove(); log.push('inner') }); document.body.addEventListener('m', () => log.push('body'));"
             "inner.dispatchEvent(new Event('m', { bubbles: true }))");
    CHECK_JS_EQ(env, "log.join()", "inner,body");
}

WR_TEST(testBudgetStopEndsDispatch) {
    wr_test::ScopedProductSlices slices;
    wr_test::TestHost host;
    {
        wr_test::DOMEnv env(host);
        env.eval("var later = false; document.body.addEventListener('k', () => { for (;;) {} }); document.body.addEventListener('k', () => { later = true })");
        wr::Runtime& runtime = env.runtime();
        wr_test::stopAfter(runtime);
        bool aborted = false;
        try {
            runtime.runScript("try { document.body.dispatchEvent(new Event('k')) } catch (e) { globalThis.caught = true }", "k.js", false);
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        CHECK(aborted);
        CHECK(runtime.stopReason() == wr::StopReason::Cpu);
        CHECK(JS_ToBool(env.ctx(), global(env.ctx(), "later").get()) == 0);
        CHECK(JS_IsUndefined(global(env.ctx(), "caught").get()));
    }
    // Aborted leaves the event reset, also from a passive listener reached through the legacy fallback: no path, no
    // phase, no current target, not dispatching, its own type back and not in a passive listener.
    wr_test::DOMEnv env(host);
    JSContext* ctx = env.ctx();
    env.eval("document.body.addEventListener('webkitAnimationEnd', () => { for (;;) {} }, { passive: true })");
    wr::Atom animationEnd = wr::Atom::fromUTF8(ctx, "animationend");
    wr::Ref<wr::Event> event = wr::create<wr::Event>(ctx, wr::idl::kEvent, ctx);
    event->initialize(ctx, animationEnd.get(), true, true);
    event->setIsTrusted(true);
    wr::Runtime& runtime = env.runtime();
    wr_test::stopAfter(runtime);
    bool aborted = false;
    try {
        wr::dispatch(ctx, *event, *wr::globalDocument(ctx).body(ctx));
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK(!event->dispatching());
    CHECK(event->pathSize() == 0);
    CHECK(event->eventPhase(ctx) == wr::Event::None);
    CHECK(event->currentTarget(ctx) == nullptr);
    CHECK(!event->stopPropagationFlag());
    CHECK(event->typeAtom() == animationEnd.get());
    event->preventDefault(ctx);
    CHECK(event->defaultPrevented(ctx));
}

WR_TEST(testFiredEventsAreTrustedAndReachLegacyListeners) {
    wr_test::DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::EventTarget& body = *wr::globalDocument(ctx).body(ctx);
    env.eval("var seen = []; document.body.addEventListener('webkitAnimationEnd', e => seen.push(e.type + ':' + e.isTrusted));");
    wr::Atom animationEnd = wr::Atom::fromUTF8(ctx, "animationend");
    CHECK(wr::fireEvent(ctx, body, animationEnd.get(), true, false));
    CHECK_JS_EQ(env, "seen.join()", "webkitAnimationEnd:true");
    // An untrusted one does not fall back; a listener for the unprefixed type wins.
    env.eval("document.body.dispatchEvent(new Event('animationend'))");
    CHECK_JS_EQ(env, "seen.length", "1");
    env.eval("var plain = 0; document.body.addEventListener('animationend', () => plain++)");
    wr::fireEvent(ctx, body, animationEnd.get(), true, false);
    CHECK_JS(env, "plain === 1 && seen.length === 1");
}

WR_TEST(testListenedTypesRecordsNewTypes) {
    wr_test::DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::ListenedTypes& types = wr::DOMState::of(ctx).listenedTypes();
    types.takeIfChanged(ctx);
    CHECK(!types.changed());
    env.eval("document.body.addEventListener('click', () => {}); document.addEventListener('pointerdown', () => {}, true);"
             "new EventTarget().addEventListener('custom', { handleEvent() {} })");
    CHECK(types.changed());
    std::vector<std::string> expected = {"click", "pointerdown", "custom"};
    CHECK(types.takeIfChanged(ctx) == expected);
    CHECK(!types.changed());
    CHECK(types.takeIfChanged(ctx).empty());
    // A second listener of a known type, or a removal, changes nothing (the set never shrinks, as today's interest).
    env.eval("var f = () => {}; document.body.addEventListener('click', f); document.body.removeEventListener('click', f)");
    CHECK(!types.changed());
    wr::Atom click = wr::Atom::fromUTF8(ctx, "click");
    CHECK(types.contains(click.get()));
    // A take answers only the types noted since the previous one (PF8), in the order first added: the host
    // accumulates.
    env.eval("document.body.addEventListener('keydown', () => {}); document.body.addEventListener('click', () => {}, true);"
             "document.body.addEventListener('pointerup', () => {})");
    std::vector<std::string> added = {"keydown", "pointerup"};
    CHECK(types.takeIfChanged(ctx) == added);
    CHECK(types.contains(click.get()));
}
