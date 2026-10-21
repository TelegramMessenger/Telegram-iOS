// Event handler IDL attributes and inline on* content attributes (M1b plan, Task 12).
#include <algorithm>
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/HostState.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"

WR_TEST(testEventHandlerAttributeGetSet) {
    wr_test::HostEnv env;
    env.eval("var d = document.createElement('div'); var f = () => {};");
    CHECK_JS(env, "d.onclick === null");
    CHECK_JS(env, "(d.onclick = f, d.onclick === f)");
    // [LegacyTreatNonObjectAsNull]: a non-object is null; any object is kept.
    CHECK_JS(env, "(d.onclick = 5, d.onclick === null)");
    CHECK_JS(env, "(() => { const o = {}; d.onclick = o; return d.onclick === o; })()");
    // Invoking a non-callable object does nothing (WebIDL returns undefined).
    CHECK_JS(env, "d.dispatchEvent(new Event('click', {cancelable: true}))");
    CHECK_JS(env, "'onclick' in HTMLElement.prototype && 'onclick' in Document.prototype");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(globalThis, 'onclick') !== undefined");
    CHECK_JS(env, "'onvisibilitychange' in Document.prototype && 'onreadystatechange' in Document.prototype");
}

WR_TEST(testHandlerKeepsItsPositionInTheListenerList) {
    wr_test::HostEnv env;
    env.eval("var log = []; var d = document.createElement('div');"
             "d.addEventListener('click', () => log.push('A'));"
             "d.onclick = () => log.push('B');"
             "d.addEventListener('click', () => log.push('C'));"
             "d.onclick = () => log.push('B2');"
             "d.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "A,B2,C");
    // Deactivated, then activated again: the listener goes to the end.
    env.eval("log = []; d.onclick = null; d.onclick = () => log.push('B3'); d.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "A,C,B3");
}

WR_TEST(testContentAttributeCompilesLazilyWithScopes) {
    wr_test::HostEnv env("<!doctype html><body><div id=d onclick=\"log.push(this.id, typeof event, typeof getElementById, id)\"></div>");
    env.eval("var log = []; var d = document.getElementById('d');");
    CHECK_JS(env, "typeof d.onclick === 'function' && d.onclick.name === 'onclick'");
    env.eval("d.dispatchEvent(new Event('click'))");
    CHECK_JS_EQ(env, "log.join()", "d,object,function,d");
    // Compiled when read: a syntax error is reported then, and the handler is null.
    env.eval("var errors = []; addEventListener('error', e => errors.push(e.error.name)); d.setAttribute('onmouseover', 'this is not js');");
    CHECK_JS_EQ(env, "errors.length", "0");
    CHECK_JS(env, "d.onmouseover === null");
    CHECK_JS_EQ(env, "errors.join()", "SyntaxError");
    // A new body replaces the value; the listener it had stays.
    env.eval("log = []; d.setAttribute('onclick', 'log.push(\"second\")'); d.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "second");
}

WR_TEST(testReturnFalseCancels) {
    wr_test::HostEnv env;
    env.eval("var d = document.createElement('div'); d.setAttribute('onclick', 'return false');");
    CHECK_JS(env, "d.dispatchEvent(new Event('click', {cancelable: true})) === false");
    env.eval("d.onclick = () => true;");
    CHECK_JS(env, "d.dispatchEvent(new Event('click', {cancelable: true})) === true");
    env.eval("d.onclick = () => 0;");
    CHECK_JS(env, "d.dispatchEvent(new Event('click', {cancelable: true})) === true");
    // The window's onerror: true cancels the ErrorEvent, false does not.
    env.eval("onerror = () => true; reportError(new Error('handled'));");
    CHECK_EQ(env.host().diagnostics.size(), size_t(0));
    env.eval("onerror = () => false; reportError(new Error('reported'));");
    CHECK_EQ(env.host().diagnostics.size(), size_t(1));
}

WR_TEST(testOnErrorGetsFiveArguments) {
    wr_test::HostEnv env;
    env.eval("var got; onerror = function (message, source, lineno, colno, error) {"
             " got = [arguments.length, message, typeof source, typeof lineno, typeof colno, error === err]; };"
             "var err = new Error('x'); reportError(err);");
    CHECK_JS_EQ(env, "got.join()", "5,Uncaught Error: x,string,number,number,true");
    // An element's onerror, and a plain Event named error at the window, get the event alone.
    env.eval("var d = document.createElement('div'); var n; d.onerror = function () { n = arguments.length; }; d.dispatchEvent(new Event('error'));");
    CHECK_JS_EQ(env, "n", "1");
    env.eval("n = 0; onerror = function () { n = arguments.length; }; dispatchEvent(new Event('error'));");
    CHECK_JS_EQ(env, "n", "1");
}

WR_TEST(testBodyHandlersReflectTheWindow) {
    wr_test::HostEnv env("<!doctype html><body onload=\"log.push('body-load')\" onclick=\"log.push('body-click')\"></body>");
    env.eval("var log = [];");
    CHECK_JS(env, "typeof window.onload === 'function' && document.body.onload === window.onload");
    CHECK_JS(env, "window.onclick === null && typeof document.body.onclick === 'function'");
    env.eval("dispatchEvent(new Event('load')); document.body.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "body-load,body-click");
    env.eval("var f = () => {}; document.body.onresize = f;");
    CHECK_JS(env, "window.onresize === f");
    // The body's onerror content attribute is the window's onerror: it compiles with five parameters.
    env.eval("document.body.setAttribute('onerror', 'log.push(arguments.length)'); reportError(new Error('e'));");
    CHECK_JS_EQ(env, "log.join()", "body-load,body-click,5");
}

WR_TEST(testContentAttributeRegistersInterest) {
    wr_test::HostEnv env("<!doctype html><body><div onpointerdown=\"x = 1\"></div>");
    std::vector<std::string> types = wr::HostState::of(env.ctx()).listenedTypes().takeIfChanged(env.ctx());
    CHECK(std::find(types.begin(), types.end(), "pointerdown") != types.end());
}

WR_TEST(testRemovingTheAttributeDeactivates) {
    wr_test::HostEnv env;
    env.eval("var log = []; var d = document.createElement('div'); d.setAttribute('onclick', 'log.push(1)');"
             "d.dispatchEvent(new Event('click')); d.removeAttribute('onclick'); d.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "1");
    CHECK_JS(env, "d.onclick === null");
    // A namespaced attribute with the same local name is not a handler.
    env.eval("d.setAttributeNS('urn:x', 'onclick', 'log.push(2)'); d.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "1");
    // Nor does changing or removing it touch the handler of the null-namespace one: the compiled function stays. (Set by
    // namespace: setAttribute('onclick') would find the urn:x attribute, whose qualified name is onclick too.)
    env.eval("d.setAttributeNS(null, 'onclick', 'log.push(3)'); var h = d.onclick; d.setAttributeNS('urn:x', 'onclick', 'log.push(4)');");
    CHECK_JS(env, "d.onclick === h");
    env.eval("d.removeAttributeNS('urn:x', 'onclick'); d.dispatchEvent(new Event('click'));");
    CHECK_JS(env, "d.onclick === h");
    CHECK_JS_EQ(env, "log.join()", "1,3");
}

// Review Focus 3 through onerror: the second exception reaches the host only.
WR_TEST(testThrowingOnErrorHandlerDoesNotRecurse) {
    wr_test::HostEnv env;
    env.eval("var n = 0; onerror = () => { n++; throw new Error('inner'); }; reportError(new Error('outer'));");
    CHECK_JS_EQ(env, "n", "1");
    CHECK_EQ(env.host().diagnostics.size(), size_t(2));
}

WR_TEST(testHandlerCyclesAreCollected) {
    wr_test::HostEnv env;
    JSRuntime* rt = env.runtime().jsRuntime();
    JS_RunGC(rt);
    size_t before = env.runtime().liveObjects();
    env.eval("(() => { const d = document.createElement('div'); for (let i = 0; i < 50; i++) d.appendChild(document.createElement('p'));"
             " d.onclick = () => d; d.setAttribute('onmouseover', 'void 0'); })()");
    JS_RunGC(rt);
    CHECK(env.runtime().liveObjects() <= before);
}

// The C++ name tables (EventHandlerAttributes.cpp) match the IDL: every on* member activates from its content
// attribute, on an element and, for the window-reflecting set, on the body.
WR_TEST(testHandlerNamesMatchTheIDL) {
    wr_test::HostEnv env;
    env.eval("var missing = []; var d = document.createElement('div');"
             "for (const name of Object.getOwnPropertyNames(HTMLElement.prototype).filter(n => n.startsWith('on'))) {"
             "  d.setAttribute(name, 'void 0'); if (typeof d[name] !== 'function') missing.push(name); d.removeAttribute(name); }"
             "var b = document.body;"
             "for (const name of ['onload', 'onerror', 'onblur', 'onfocus', 'onresize', 'onscroll', 'onpageshow', 'onpagehide', 'onunhandledrejection', 'onrejectionhandled']) {"
             "  b.setAttribute(name, 'void 0'); if (typeof window[name] !== 'function') missing.push('body.' + name); b.removeAttribute(name); }");
    CHECK_JS_EQ(env, "missing.join()", "");
    CHECK_JS(env, "Object.getOwnPropertyNames(HTMLElement.prototype).filter(n => n.startsWith('on')).length === 65");
}

// The bodies below close the function early, so they are written against the factory's text (EventHandlers.cpp,
// compile): "(function () { with (arguments[0]) with (arguments[1]) return { on<type>: function (event) {\n" + body +
// "\n} }.on<type>; })". Each one ends the factory with "} }.onclick; });" and opens a second function that the suffix
// closes; the eval's completion value, the function called as the factory, is that second one.

// Ruling R3: compiling a body is a script entry, so a stop inside it stays a stop. A body that closes the function
// early runs its own code while it compiles (Ruling 15's accepted cost); here that code never ends.
WR_TEST(testAStopWhileCompilingStaysAStop) {
    wr_test::HostEnv env;
    env.eval("var d = document.createElement('div');"
             "d.setAttribute('onclick', '} }.onclick; }); for (;;) {} (function () { return { a: function () {');");
    env.runtime().setWorkLimit(JS_GetWorkUnits(env.runtime().jsRuntime()) + 300000);
    CHECK_EQ(env.eval("try { d.onclick; } catch (e) {} 'caught'"), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Budget);
    CHECK_EQ(env.eval("1"), std::string("STOPPED"));
}

// HTML "getting the current value of the event handler": a body compiles only while its element's node document is the
// window's (Ruling 15, "fully active"). A body whose element moved into a template's contents is null when read.
WR_TEST(testABodyOutsideTheMainDocumentDoesNotCompile) {
    wr_test::HostEnv env;
    env.eval("var log = []; var d = document.createElement('div'); d.setAttribute('onclick', 'log.push(1)');"
             "var t = document.createElement('template'); t.content.appendChild(d);");
    CHECK_JS(env, "d.ownerDocument !== document && d.onclick === null");
    env.eval("d.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.length", "0");
}

// Fix round M2: a body's window-reflecting handler is the Window's, so it is compiled with the global scope alone (no
// document or element), and its document is the window's: it still compiles once the body has left the document.
// An element's handler keeps the document and the element in its scope.
WR_TEST(testWindowHandlersHaveOnlyTheGlobalScope) {
    wr_test::HostEnv env("<!doctype html><body onload=\"log.push(typeof getElementById, typeof tagName)\" onresize=\"log.push('resize')\">"
                         "<div id=d onclick=\"log.push(typeof getElementById, typeof tagName)\"></div></body>");
    env.eval("var log = []; dispatchEvent(new Event('load')); document.getElementById('d').dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "undefined,undefined,function,string");
    env.eval("log = []; var t = document.createElement('template'); t.content.appendChild(document.body); dispatchEvent(new Event('resize'));");
    CHECK_JS(env, "document.body === null && typeof onresize === 'function'");
    CHECK_JS_EQ(env, "log.join()", "resize");
}

// Fix round M1: HTML's attribute change steps return for an attribute with a namespace, so a namespaced onclick being
// set, changed and removed never touches the handler, here one set through the IDL attribute.
WR_TEST(testANamespacedAttributeLeavesTheHandlerAlone) {
    wr_test::HostEnv env;
    env.eval("var log = []; var d = document.createElement('div'); var f = () => log.push('f'); d.onclick = f;"
             "d.setAttributeNS('urn:x', 'x:onclick', 'log.push(1)');");
    CHECK_JS(env, "d.onclick === f");
    env.eval("d.setAttributeNS('urn:x', 'x:onclick', 'log.push(2)');");
    CHECK_JS(env, "d.onclick === f");
    env.eval("d.removeAttributeNS('urn:x', 'onclick'); d.dispatchEvent(new Event('click'));");
    CHECK_JS(env, "d.onclick === f && !d.hasAttributes()");
    CHECK_JS_EQ(env, "log.join()", "f");
}

// Fix round M3: an element's handler content attribute is stored whatever its document, and compiles once the element
// is in the window's document. A template's contents are inert (null when read there); a clone appended to the body,
// and the template's own button moved there, fire theirs.
WR_TEST(testHandlersInATemplateWorkOnceInTheDocument) {
    wr_test::HostEnv env("<!doctype html><body><template id=t><button onclick=\"log.push('tpl:' + this.localName)\"></button></template>");
    env.eval("var log = []; var tpl = document.getElementById('t');");
    CHECK_JS(env, "tpl.content.firstChild.localName === 'button' && tpl.content.firstChild.onclick === null");
    env.eval("document.body.appendChild(tpl.content.cloneNode(true)); document.body.lastChild.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "tpl:button");
    env.eval("var moved = tpl.content.firstChild; document.body.appendChild(moved); moved.dispatchEvent(new Event('click'));");
    CHECK_JS(env, "typeof moved.onclick === 'function'");
    CHECK_JS_EQ(env, "log.join()", "tpl:button,tpl:button");
}

// Fix round M3: a handler set while its element is in a document with no window is stored there and fires once the
// element is adopted into the window's document.
WR_TEST(testAHandlerSetInAnotherDocumentWorksOnceAdopted) {
    wr_test::HostEnv env;
    env.eval("var log = []; var b = new Document().createElementNS('http://www.w3.org/1999/xhtml', 'button');"
             "b.setAttribute('onclick', \"log.push('adopted')\");");
    CHECK_JS(env, "b.ownerDocument !== document && b.onclick === null");
    env.eval("document.adoptNode(b); document.body.appendChild(b); b.dispatchEvent(new Event('click'));");
    CHECK_JS(env, "typeof b.onclick === 'function'");
    CHECK_JS_EQ(env, "log.join()", "adopted");
}

// Fix round M8: markup set through innerHTML gives its elements their handlers.
WR_TEST(testInnerHTMLHandlers) {
    wr_test::HostEnv env;
    env.eval("var log = []; var c = document.createElement('div'); document.body.appendChild(c);"
             "c.innerHTML = '<b onclick=\"log.push(this.localName)\"></b>'; c.firstChild.dispatchEvent(new Event('click'));");
    CHECK_JS_EQ(env, "log.join()", "b");
}

// Fix round M4: the compiled function is anonymous with its `name` set (as a function's own `name` is: not writable,
// not enumerable, configurable), so the body has no binding of its own name: `onclick = null` inside it reaches the
// element's handler through the element's scope (sloppy mode) and clears it.
WR_TEST(testAHandlerDoesNotBindItsOwnName) {
    wr_test::HostEnv env;
    env.eval("var d = document.createElement('div'); d.setAttribute('onclick', 'onclick = null');");
    CHECK_JS(env, "(n => n.value === 'onclick' && !n.writable && !n.enumerable && n.configurable)(Object.getOwnPropertyDescriptor(d.onclick, 'name'))");
    env.eval("d.dispatchEvent(new Event('click'));");
    CHECK_JS(env, "d.onclick === null");
}

// Fix round M5: an early-closing body whose factory call throws is reported once and leaves the handler null (it does
// not run again on every read); one whose factory gives something that is not a function is a failure too: null, and
// a SyntaxError reported.
WR_TEST(testAFailedFactoryLeavesTheHandlerNull) {
    wr_test::HostEnv env;
    env.eval("var errors = []; addEventListener('error', e => errors.push(e.error.name + ':' + e.error.message)); var ran = 0;"
             "var d = document.createElement('div');"
             "d.setAttribute('onclick', '} }.onclick; }); (function () { ran++; throw new Error(\"factory\"); return { a: function () {');");
    CHECK_JS(env, "d.onclick === null && d.onclick === null");
    CHECK_JS_EQ(env, "ran", "1");
    CHECK_JS_EQ(env, "errors.join()", "Error:factory");
    env.eval("errors = []; d.setAttribute('onclick', '} }.onclick; }); (function () { ran++; return 5; return { a: function () {');");
    CHECK_JS(env, "d.onclick === null && d.onclick === null");
    CHECK_JS_EQ(env, "ran", "2");
    CHECK_JS(env, "errors.length === 1 && errors[0].startsWith('SyntaxError:')");
    env.eval("errors = []; d.setAttribute('onclick', '} }.onclick; }); (function () { return {}; return { a: function () {');");
    CHECK_JS(env, "d.onclick === null && errors.length === 1");
}

// HTML "determine the target of an event handler": any body element of the window's document reflects the window's
// handlers; a body of a document with no window (here `new Document()`'s) has none, so its getter reads null and its
// setter does nothing.
WR_TEST(testOnlyABodyOfTheWindowsDocumentReflectsTheWindow) {
    wr_test::HostEnv env;
    env.eval("var f = () => {}; var other = document.createElement('body'); other.onload = f;");
    CHECK_JS(env, "window.onload === f && other.onload === f");
    env.eval("var g = () => {}; var foreign = new Document().createElementNS('http://www.w3.org/1999/xhtml', 'body'); foreign.onload = g;");
    CHECK_JS(env, "foreign instanceof HTMLBodyElement && foreign.onload === null && window.onload === f");
    // Its own handlers are its own.
    CHECK_JS(env, "(foreign.onclick = g, foreign.onclick === g && window.onclick === null)");
}

// Ruling R4: a DOM-only runtime has no host state and no Window. A body's window-reflecting handlers have no owner
// there (null, and a set does nothing); every other handler works, and none dereferences a missing host state.
WR_TEST(testHandlersWithoutTheHostState) {
    wr_test::DOMEnv env;
    env.eval("var f = () => {}; var b = document.body; b.onload = f; b.onpageshow = f;");
    CHECK_JS(env, "b.onload === null && b.onpageshow === null");
    env.eval("var log = []; b.onclick = () => log.push('click'); b.dispatchEvent(new Event('click'));"
             "var d = document.createElement('div'); d.onerror = function () { log.push(arguments.length); };"
             "d.dispatchEvent(new Event('error'));");
    CHECK_JS_EQ(env, "log.join()", "click,1");
    CHECK_JS(env, "b.onclick !== null && (b.onclick = null, b.onclick === null)");
}

namespace {

enum class ChangeOutcome { Completed, StoppedInTheListener, StoppedOutside, Escaped };

/// Runs `change` on a fresh window whose `d` is a div with one click listener (and `f` a function), with the budget
/// placed to refuse the first charge `offset` work units or more into the change (allocations count, at QuickJS's
/// rate). JS_ChargeWork asks the interrupt handler only once a period, so the period is aligned first: a full period's
/// charge asks it (no limit yet), so the next check is exactly JS_WORK_CHECK_PERIOD units away; the units that put it
/// `offset` modulo the period into the change are spent; and the limit is `offset` units on, so the checks before it
/// pass. Aborted is what the attribute listener throws for a stop inside it; Thrown comes from the charges outside it
/// (the mutation's own, or the IDL setter's, which `glue` maps). After a stop the runtime must be latched. Then nothing
/// may be left over: everything the change made is reachable only from `d` and `f`, so with both dropped and a
/// collection, the object count is back where the same round without the change left it.
template <class F>
ChangeOutcome runChangeWithStopAt(uint64_t offset, F&& change) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    JSRuntime* rt = env.runtime().jsRuntime();
    wr::Value global = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    auto objects = [&] {
        JSMemoryUsage usage;
        JS_ComputeMemoryUsage(rt, &usage);
        return usage.obj_count;
    };
    auto dropAndCollect = [&] {
        // Plain data properties of the global (made by assignment): setting them runs no script, so a stopped runtime
        // allows it.
        JS_SetPropertyStr(ctx, global.get(), "d", JS_UNDEFINED);
        JS_SetPropertyStr(ctx, global.get(), "f", JS_UNDEFINED);
        JS_RunGC(rt);
        return objects();
    };
    const char* setup = "globalThis.d = document.createElement('div'); d.addEventListener('click', () => {}); globalThis.f = () => {};";
    env.eval(setup);
    int64_t baseline = dropAndCollect();
    env.eval(setup);
    ChangeOutcome outcome = ChangeOutcome::Completed;
    {
        wr::Value d = wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, global.get(), "d"));
        wr::Value f = wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, global.get(), "f"));
        wr::Element& element = *wr::unwrap<wr::Element>(ctx, d.get(), wr::idl::kElement);
        // Everything the change reads is made before the limit is set.
        wr::Atom onclick = wr::Atom::fromUTF8(ctx, "onclick");
        wr::Atom click = wr::Atom::fromUTF8(ctx, "click");
        wr::String body = wr::String::fromUTF8(ctx, "void 0");
        change(ctx, element, onclick.get(), click.get(), body, f.get(), true);
        uint64_t periods = (offset - 1) / JS_WORK_CHECK_PERIOD;
        uint64_t within = offset - periods * JS_WORK_CHECK_PERIOD;
        wr::charge(ctx, JS_WORK_CHECK_PERIOD);
        wr::charge(ctx, JS_WORK_CHECK_PERIOD - within);
        env.runtime().setWorkLimit(JS_GetWorkUnits(rt) + offset);
        try {
            change(ctx, element, onclick.get(), click.get(), body, f.get(), false);
        } catch (const wr::Aborted&) {
            outcome = ChangeOutcome::StoppedInTheListener;
        } catch (const wr::Thrown&) {
            JS_FreeValue(ctx, JS_GetException(ctx));
            outcome = ChangeOutcome::StoppedOutside;
        } catch (...) {
            JS_FreeValue(ctx, JS_GetException(ctx));
            outcome = ChangeOutcome::Escaped;
        }
    }
    if (outcome == ChangeOutcome::StoppedInTheListener || outcome == ChangeOutcome::StoppedOutside) {
        CHECK(env.runtime().stopReason() == wr::StopReason::Budget);
        CHECK_EQ(env.eval("1"), std::string("STOPPED"));
    }
    int64_t left = dropAndCollect();
    if (left != baseline) {
        wr_test::failures()++;
        std::printf("  stop at offset %llu: %lld objects left over\n", (unsigned long long)offset, (long long)(left - baseline));
    }
    return outcome;
}

/// Sweeps the stop over the first `units` units of `change` (its measured cost, with room); every offset must end in
/// completion or a latched stop, and at least one must stop inside the attribute listener when `listener` says so.
template <class F>
void sweepStops(const char* what, uint64_t units, bool listener, F&& change) {
    int inside = 0;
    int completed = 0;
    for (uint64_t offset = 1; offset <= units; offset++) {
        ChangeOutcome outcome = runChangeWithStopAt(offset, change);
        if (outcome == ChangeOutcome::Escaped) {
            wr_test::failures()++;
            std::printf("  %s: an exception other than Aborted or Thrown escaped at offset %llu\n", what, (unsigned long long)offset);
        }
        inside += outcome == ChangeOutcome::StoppedInTheListener;
        completed += outcome == ChangeOutcome::Completed;
    }
    if ((listener && inside == 0) || completed == 0) {
        wr_test::failures()++;
        std::printf("  %s: %d stops in the listener, %d completions over %llu offsets\n", what, inside, completed, (unsigned long long)units);
    }
}

} // namespace

// Ruling R6: the attribute listener allocates and registers a listener inside a mutation. A stop at any charge on the
// way (the mutation's own, the listener's, the handler map's, the listener list's) is final, Aborted when it is the
// listener's, and the unwind leaves every reference owned once. The IDL setter's paths are swept the same way.
WR_TEST(testAStopInsideAHandlerChangeIsFinal) {
    // The first activation (a map, an entry, a processing function, a listener): about 120 units.
    sweepStops("setting the content attribute", 160, true, [](JSContext* ctx, wr::Element& d, JSAtom onclick, JSAtom, const wr::String& body, JSValueConst, bool setup) {
        if (!setup) {
            d.setAttributeValue(ctx, onclick, body);
        }
    });
    sweepStops("removing the content attribute", 40, true, [](JSContext* ctx, wr::Element& d, JSAtom onclick, JSAtom, const wr::String& body, JSValueConst, bool setup) {
        if (setup) {
            d.setAttributeValue(ctx, onclick, body);
        } else {
            d.removeAttributeAtom(ctx, onclick);
        }
    });
    sweepStops("setting the IDL attribute", 120, false, [](JSContext* ctx, wr::Element& d, JSAtom, JSAtom click, const wr::String&, JSValueConst f, bool setup) {
        if (!setup) {
            wr::setEventHandler(ctx, d, click, f);
        }
    });
    sweepStops("clearing the IDL attribute", 40, false, [](JSContext* ctx, wr::Element& d, JSAtom, JSAtom click, const wr::String&, JSValueConst f, bool setup) {
        wr::setEventHandler(ctx, d, click, setup ? f : JS_NULL);
    });
}
