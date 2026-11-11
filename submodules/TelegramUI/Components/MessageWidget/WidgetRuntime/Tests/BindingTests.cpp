// End to end through the generator: Tests/IDL/test.webidl → Generated/TestBindings.{h,cpp} → Tests/TestImpl.
#include "Tests/JSHarness.h"
#include "Tests/TestImpl.h"

#include <stdexcept>
#include <type_traits>
#include <vector>

using wr_test::JSEnv;

namespace {

struct Env : JSEnv {
    Env() : JSEnv(wr::testidl::kTable) { wr::testidl::installTestGlobals(this->ctx()); }
};

/// The binding table with its [Global] interface installed: the global object is a TestGlobal.
struct GlobalEnv : JSEnv {
    GlobalEnv() : JSEnv(wr::testidl::kTable) {
        wr::testidl::installTestGlobals(this->ctx());
        wr::testidl::installTestGlobal(this->ctx());
    }
};

} // namespace

WR_TEST(testInterfaceObjectsAreLazyAndLookLikeDataProperties) {
    Env env;
    CHECK_EQ(env.runtime().materializedCount(), size_t(0));
    CHECK_JS(env, "'TestSample' in globalThis");
    CHECK_JS(env, "!Object.keys(globalThis).includes('TestSample')");
    CHECK_EQ(env.runtime().materializedCount(), size_t(0));
    CHECK_JS_EQ(env, "typeof TestSample", "function");
    CHECK_EQ(env.runtime().materializedCount(), size_t(2)); // TestSample and its parent TestBase
    CHECK_JS(env, "(d => d.writable && d.configurable && !d.enumerable && d.value === TestSample)(Object.getOwnPropertyDescriptor(globalThis, 'TestSample'))");
    CHECK_JS(env, "!('TestHidden' in globalThis)");
}

WR_TEST(testPrototypeChainsAndPropertyShapes) {
    Env env;
    CHECK_JS(env, "Object.getPrototypeOf(TestSample.prototype) === TestBase.prototype");
    CHECK_JS(env, "Object.getPrototypeOf(TestSample) === TestBase");
    CHECK_JS(env, "Object.getPrototypeOf(TestBase.prototype) === Object.prototype");
    CHECK_JS(env, "Object.getPrototypeOf(TestBase) === Function.prototype");
    CHECK_JS(env, "(d => d.writable && d.enumerable && d.configurable)(Object.getOwnPropertyDescriptor(TestSample.prototype, 'find'))");
    CHECK_JS(env, "(d => d.enumerable && d.configurable && typeof d.get === 'function' && typeof d.set === 'function')(Object.getOwnPropertyDescriptor(TestSample.prototype, 'label'))");
    CHECK_JS(env, "(d => d.enumerable && d.configurable && d.set === undefined)(Object.getOwnPropertyDescriptor(TestSample.prototype, 'count'))");
    CHECK_JS(env, "(d => !d.writable && d.enumerable && !d.configurable && d.value === 1)(Object.getOwnPropertyDescriptor(TestSample.prototype, 'ONE'))");
    CHECK_JS(env, "TestSample.ONE === 1");
    CHECK_JS(env, "(d => !d.writable && !d.enumerable && !d.configurable)(Object.getOwnPropertyDescriptor(TestSample, 'prototype'))");
    CHECK_JS(env, "(d => d.writable && !d.enumerable && d.configurable)(Object.getOwnPropertyDescriptor(TestSample.prototype, 'constructor'))");
    CHECK_JS_EQ(env, "Object.prototype.toString.call(new TestSample())", "[object TestSample]");
    CHECK_JS_EQ(env, "TestSample.name + TestSample.length", "TestSample0");
    CHECK_JS_EQ(env, "Object.getOwnPropertyDescriptor(TestSample.prototype, 'label').get.name", "get label");
}

WR_TEST(testConstructors) {
    Env env;
    CHECK_JS_EQ(env, "new TestSample().label", "unnamed");
    CHECK_JS_EQ(env, "new TestSample('x').label", "x");
    CHECK_THROWS(env, "TestSample()", "TypeError");
    CHECK_THROWS(env, "new TestBase()", "TypeError");
    CHECK_JS(env, "(() => { class Sub extends TestSample {}; const s = new Sub('y'); return s instanceof Sub && s instanceof TestSample && s.label === 'y'; })()");
}

WR_TEST(testBrandChecks) {
    Env env;
    CHECK_THROWS(env, "Object.getOwnPropertyDescriptor(TestSample.prototype, 'count').get.call({})", "TypeError");
    CHECK_THROWS(env, "TestSample.prototype.find.call(makeList(1), 'a')", "TypeError");
    CHECK_JS_EQ(env, "Object.getOwnPropertyDescriptor(TestBase.prototype, 'baseName').get.call(new TestSample())", "base");
}

WR_TEST(testArgumentConversion) {
    Env env;
    env.eval("var s = new TestSample('a')");
    CHECK_THROWS(env, "s.find()", "TypeError");
    CHECK_JS(env, "s.find('a') === s");
    CHECK_JS(env, "s.find('b') === null");
    CHECK_JS(env, "s.find('b', true) === s");
    CHECK_JS(env, "(s.label = null, s.label === null)");
    CHECK_JS(env, "(s.text = null, s.text === '')");
    CHECK_JS(env, "(s.text = 12, s.text === '12')");
    CHECK_JS(env, "(s.add(new TestSample(), 'x', new TestSample()), s.count === 3)");
    CHECK_JS(env, "(s.add(), s.count === 3)");
    env.eval("s.label = 'L'");
    CHECK_JS_EQ(env, "s.describe()", ">L");
    CHECK_JS_EQ(env, "s.describe({prefix: '#', loud: true})", "#L");
    CHECK_JS_EQ(env, "s.describe({loud: true})", ">L");
    CHECK_JS_EQ(env, "s.describe('plain')", "plain:L");
    CHECK_JS(env, "TestSample.half(Infinity) === Infinity");
    CHECK_JS(env, "TestSample.half(3) === 1.5");
    CHECK_THROWS(env, "s.find(Symbol())", "TypeError");
}

WR_TEST(testDOMErrorsBecomeDOMExceptions) {
    Env env;
    CHECK_JS(env, "(() => { try { new TestSample().fail('x'); } catch (e) { return e instanceof DOMException && e.name === 'NotFoundError' && e.message === 'no x'; } })()");
}

WR_TEST(testIndexedGetterAndValueIteration) {
    Env env;
    env.eval("var l = makeList(3)");
    CHECK_JS(env, "l.length === 3");
    CHECK_JS(env, "l[0] instanceof TestSample && l[0].label === 'item0'");
    CHECK_JS(env, "l[0] === l.item(0)");
    CHECK_JS(env, "l[3] === undefined && l.item(3) === null");
    CHECK_JS(env, "2 in l && !(3 in l)");
    CHECK_JS_EQ(env, "Object.keys(l).join()", "0,1,2");
    CHECK_JS_EQ(env, "[...l].map(x => x.label).join()", "item0,item1,item2");
    CHECK_JS(env, "TestList.prototype[Symbol.iterator] === Array.prototype.values");
    CHECK_JS(env, "TestList.prototype.forEach === Array.prototype.forEach");
}

/// V5a plan, Task 5: WebIDL's pair iterator. entries/keys/values/forEach and @@iterator (= entries); iterator objects
/// with next, "<Interface> Iterator" and %IteratorPrototype%, reading the live list by index on every next.
WR_TEST(testPairIteration) {
    Env env;
    env.eval("var p = new TestPairs(); p.append('a', 1); p.append('b', 2)");
    CHECK_JS_EQ(env, "JSON.stringify([...p])", "[[\"a\",1],[\"b\",2]]");
    CHECK_JS_EQ(env, "[...p.keys()].join() + '|' + [...p.values()].join() + '|' + JSON.stringify([...p.entries()])", "a,b|1,2|[[\"a\",1],[\"b\",2]]");
    CHECK_JS(env, "TestPairs.prototype[Symbol.iterator] === TestPairs.prototype.entries");
    CHECK_JS_EQ(env, "(() => { const t = {}, seen = []; p.forEach(function (v, k, o) { seen.push(k + v + (o === p) + (this === t)) }, t); return seen.join() })()",
                "a1truetrue,b2truetrue");
    CHECK_JS_EQ(env, "Object.prototype.toString.call(p.entries())", "[object TestPairs Iterator]");
    CHECK_JS(env, "Object.getPrototypeOf(Object.getPrototypeOf(p.keys())) === Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]()))");
    CHECK_JS_EQ(env, "JSON.stringify(p.entries().next())", "{\"value\":[\"a\",1],\"done\":false}");
    // Index-based: removing the first pair after one step leaves nothing at index 1.
    CHECK_JS_EQ(env, "(() => { const k = p.keys(); k.next(); p.removeFirst(); return JSON.stringify(k.next()) })()", "{\"done\":true}");
    CHECK_JS_EQ(env, "(() => { try { Object.getPrototypeOf(p.keys()).next.call({}); return 'no' } catch (e) { return e.name } })()", "TypeError");
    CHECK_JS_EQ(env, "(() => { try { p.forEach(1); return 'no' } catch (e) { return e.name } })()", "TypeError");
}

WR_TEST(testTamperedGlobalsKeepPrototypes) {
    Env env;
    env.eval("var P = TestSample.prototype; var describe = P.describe; globalThis.TestSample = 1; delete P.find;");
    CHECK_JS(env, "Object.getPrototypeOf(makeList(1)[0]) === P");
    CHECK_JS(env, "(() => { const s = makeList(1)[0]; Object.setPrototypeOf(s, null); return describe.call(s, 'k') === 'k:item0'; })()");
}

WR_TEST(testIndexedReadsLeaveAnUncatchableErrorAlone) {
    // A stop leaves an uncatchable error pending. An exotic read whose impl hits it must hand it on as it is,
    // as glue does for the length attribute, not replace it with an error script can catch.
    Env env;
    env.eval("var bad = makeInterruptingList(3)");
    CHECK_JS_EQ(env, "(() => { try { bad.length; return 'not thrown'; } catch (e) { return 'caught ' + e; } })()", "THROW InternalError: interrupted");
    CHECK_JS_EQ(env, "(() => { try { bad[0]; return 'not thrown'; } catch (e) { return 'caught ' + e; } })()", "THROW InternalError: interrupted");
    CHECK_JS_EQ(env, "(() => { try { 1 in bad; return 'not thrown'; } catch (e) { return 'caught ' + e; } })()", "THROW InternalError: interrupted");
    CHECK_JS_EQ(env, "(() => { try { Object.keys(bad); return 'not thrown'; } catch (e) { return 'caught ' + e; } })()", "THROW InternalError: interrupted");
}

namespace {

/// What running `code` leaves behind once a full GC has collected everything it dropped. `code` runs once first, so
/// what a first use builds and keeps (interfaces, atoms, shapes) is not counted. These are counters, not asserts: they
/// hold where NDEBUG removes JS_FreeRuntime's assert, and they see a held string, which that assert cannot.
struct Leftover {
    int64_t objects;
    int64_t allocations;
    int64_t bytes;
};

Leftover leftoverAfter(JSEnv& env, const char* code) {
    JSRuntime* rt = env.runtime().jsRuntime();
    env.eval(code);
    JS_RunGC(rt);
    JSMemoryUsage before;
    JS_ComputeMemoryUsage(rt, &before);
    env.eval(code);
    JS_RunGC(rt);
    JSMemoryUsage after;
    JS_ComputeMemoryUsage(rt, &after);
    return {after.obj_count - before.obj_count, after.malloc_count - before.malloc_count, after.malloc_size - before.malloc_size};
}

void checkNothingLeft(const Leftover& left, const char* what) {
    if (left.objects != 0 || left.allocations != 0 || left.bytes != 0) {
        wr_test::failures()++;
        std::printf("  %s left %lld objects, %lld allocations, %lld bytes\n", what, (long long)left.objects, (long long)left.allocations, (long long)left.bytes);
    }
}

} // namespace

WR_TEST(testDroppedObjectsReleaseWhatTheyHold) {
    Env env;
    // Freed by their counts, outside any cycle: each payload's dispose releases the objects and strings it holds.
    checkNothingLeft(leftoverAfter(env, "(() => { makeList(5); const s = new TestSample('label'); s.text = 'held'; })()"), "dropped objects");
    // A cycle through a payload (an item pointing back at its list) is collected only when trace reports the items.
    checkNothingLeft(leftoverAfter(env, "(() => { const l = makeList(2); l[0].owner = l; })()"), "a cycle through a payload");
}

WR_TEST(testObjectsAreFreedWithTheRuntime) {
    // JS_FreeRuntime asserts that no object is left (in builds without NDEBUG). Everything here dies as one cycle,
    // which the collector frees whole, so a payload that never releases what it traces passes this case:
    // testDroppedObjectsReleaseWhatTheyHold is the one that catches that, and held strings.
    Env env;
    env.eval("var keep = [makeList(5), new TestSample('x')]; keep.push(keep)");
}

WR_TEST(testCallbackFunctionsConvertAndKeepTheirIdentity) {
    Env env;
    env.eval("var c = new TestCallbacks(), f = v => v + '!'");
    CHECK_JS(env, "c.stored === null");
    CHECK_JS(env, "(c.stored = f, c.stored === f)");
    CHECK_JS(env, "(c.stored = null, c.stored === null)");
    CHECK_THROWS(env, "c.stored = 5", "TypeError");
    CHECK_THROWS(env, "c.stored = {}", "TypeError");
    CHECK_JS_EQ(env, "c.invoke(f, 'hi')", "hi!");
    CHECK_THROWS(env, "c.invoke({}, 'hi')", "TypeError");
    CHECK_THROWS(env, "c.invoke(undefined, 'hi')", "TypeError");
}

WR_TEST(testUnionsPreferACallableToAString) {
    Env env;
    env.eval("var c = new TestCallbacks()");
    CHECK_JS_EQ(env, "c.handlerKind(() => 1)", "function");
    CHECK_JS_EQ(env, "c.handlerKind(function named() {})", "function");
    CHECK_JS_EQ(env, "c.handlerKind('x = 1')", "string:x = 1");
    CHECK_JS_EQ(env, "c.handlerKind(5)", "string:5");
    // A non-callable object is not the callback alternative: it converts to the string.
    CHECK_JS_EQ(env, "c.handlerKind({})", "string:[object Object]");
}

/// WebIDL's union conversion: a Number takes the numeric alternative and a Boolean the boolean one, before the string
/// (V5e plan, Task 2: EffectTiming's `(unrestricted double or DOMString) duration`).
WR_TEST(testUnionsTakeANumberOrABooleanBeforeAString) {
    Env env;
    env.eval("var s = new TestSample()");
    CHECK_JS_EQ(env, "s.primitiveKind(5)", "number:5");
    CHECK_JS_EQ(env, "s.primitiveKind(NaN)", "number:nan");
    CHECK_JS_EQ(env, "s.primitiveKind(true)", "boolean:true");
    CHECK_JS_EQ(env, "s.primitiveKind('5')", "string:5");
    CHECK_JS_EQ(env, "s.primitiveKind({})", "string:[object Object]");
    CHECK_JS_EQ(env, "s.primitiveKind(null)", "string:null");
}

WR_TEST(testCallbackInterfacesTakeAnyObject) {
    Env env;
    env.eval("var c = new TestCallbacks()");
    CHECK_JS(env, "(c.listen(function () {}), c.listenerIsFunction)");
    CHECK_JS(env, "(c.listen({handleEvent() {}}), !c.listenerIsFunction)");
    // The operation is looked up only when the listener is called, so an object without it converts.
    CHECK_JS(env, "(c.listen({}), !c.listenerIsFunction)");
    CHECK_THROWS(env, "c.listen(5)", "TypeError");
    CHECK_THROWS(env, "c.listen(null)", "TypeError");
}

WR_TEST(testLegacyTreatNonObjectAsNull) {
    Env env;
    env.eval("var c = new TestCallbacks(), g = () => 2, o = {}");
    CHECK_JS(env, "(c.legacy = g, c.legacy === g)");
    CHECK_JS(env, "(c.legacy = o, c.legacy === o)");
    CHECK_JS(env, "(c.legacy = 5, c.legacy === null)");
    CHECK_JS(env, "(c.legacy = 'code', c.legacy === null)");
}

WR_TEST(testAnyMembersDefaultToNull) {
    Env env;
    env.eval("var c = new TestCallbacks()");
    CHECK_JS(env, "c.detailOf() === null");
    CHECK_JS(env, "c.detailOf({}) === null");
    CHECK_JS(env, "c.detailOf({detail: undefined}) === null");
    CHECK_JS(env, "c.detailOf({detail: 7}) === 7");
    CHECK_THROWS(env, "c.detailOf({onDone: 5})", "TypeError");
}

WR_TEST(testHeldCallbackMovesWithoutCopying) {
    Env env;
    JSContext* ctx = env.ctx();
    JSRuntime* rt = env.runtime().jsRuntime();
    static_assert(!std::is_copy_constructible_v<wr::HeldCallback>);
    static_assert(!std::is_copy_assignable_v<wr::HeldCallback>);
    static_assert(std::is_nothrow_move_constructible_v<wr::HeldCallback>);
    wr::HeldCallback a;
    CHECK(a.empty());
    a.set(rt, JS_NewObject(ctx));
    wr::HeldCallback b(std::move(a));
    CHECK(a.empty());
    CHECK(!b.empty());
    // A growing vector moves its elements: none is released twice, none is lost.
    std::vector<wr::HeldCallback> list;
    list.push_back(std::move(b));
    for (int i = 0; i < 20; i++) {
        wr::HeldCallback h;
        h.set(rt, JS_NewObject(ctx));
        list.push_back(std::move(h));
    }
    CHECK(b.empty());
    for (wr::HeldCallback& h : list) {
        CHECK(!h.empty());
        h.clear(rt);
    }
}

WR_TEST(testHeldCallbacksAreTracedAndReleased) {
    Env env;
    // A stored callback that captures its holder is a cycle the collector frees only if trace reports it.
    checkNothingLeft(leftoverAfter(env, "(() => { const c = new TestCallbacks(); c.stored = () => c; c.listen({handleEvent() { return c; }}); c.legacy = {c}; })()"), "cycles through held callbacks");
    // Replacing and clearing release the old value.
    checkNothingLeft(leftoverAfter(env, "(() => { const c = new TestCallbacks(); c.stored = () => 1; c.stored = () => 2; c.stored = null; })()"), "replaced callbacks");
}

WR_TEST(testGlobalInterfaceMembersLiveOnTheGlobal) {
    GlobalEnv env;
    CHECK_JS(env, "Object.getPrototypeOf(globalThis) === TestGlobal.prototype");
    CHECK_JS(env, "Object.getPrototypeOf(TestGlobal.prototype) === TestTarget.prototype");
    CHECK_JS(env, "globalThis instanceof TestTarget");
    CHECK_JS_EQ(env, "Object.prototype.toString.call(globalThis)", "[object TestGlobal]");
    // A [Global] interface's regular members are own properties of the global, not of its prototype.
    CHECK_JS(env, "Object.prototype.hasOwnProperty.call(globalThis, 'tick') && !Object.prototype.hasOwnProperty.call(TestGlobal.prototype, 'tick')");
    CHECK_JS(env, "Object.prototype.hasOwnProperty.call(globalThis, 'ticks') && !Object.prototype.hasOwnProperty.call(TestGlobal.prototype, 'ticks')");
    // Constants stay on the prototype and the interface object.
    CHECK_JS(env, "TestGlobal.TEN === 10 && TestGlobal.prototype.TEN === 10 && TEN === 10");
    // An operation is a data property (made lazily): writable, enumerable, configurable, a function of its name.
    CHECK_JS(env, "(d => d.writable && d.enumerable && d.configurable && typeof d.value === 'function' && d.value.name === 'tick')(Object.getOwnPropertyDescriptor(globalThis, 'tick'))");
    // An attribute is an accessor, enumerable and configurable.
    CHECK_JS(env, "(d => d.enumerable && d.configurable && typeof d.get === 'function' && d.set === undefined)(Object.getOwnPropertyDescriptor(globalThis, 'ticks'))");
    CHECK_JS_EQ(env, "tick() + tick()", "3");
    CHECK_JS_EQ(env, "ticks", "2");
    // Members of the parent interface stay on its prototype and work on the global.
    CHECK_JS(env, "!Object.prototype.hasOwnProperty.call(globalThis, 'onping') && Object.prototype.hasOwnProperty.call(TestTarget.prototype, 'onping')");
    CHECK_JS(env, "(onping = () => 1, typeof onping === 'function')");
}

WR_TEST(testUndefinedThisMeansTheGlobal) {
    GlobalEnv env;
    CHECK_JS_EQ(env, "(function () { 'use strict'; return tick.call(undefined); })()", "1");
    CHECK_JS_EQ(env, "(function () { 'use strict'; const t = tick; return t(); })()", "2");
    CHECK_JS_EQ(env, "Object.getOwnPropertyDescriptor(globalThis, 'ticks').get.call(null)", "2");
    // An inherited member called bare finds the global through its prototype chain, and its brand check passes.
    CHECK_JS_EQ(env, "(function () { 'use strict'; return TestTarget.prototype.handlerTypes.call(undefined); })()", "");
    CHECK_THROWS(env, "tick.call({})", "TypeError");
    // An interface the global does not implement still fails its brand check.
    CHECK_THROWS(env, "(function () { 'use strict'; return TestSample.prototype.find.call(undefined, 'a'); })()", "TypeError");
}

WR_TEST(testLegacyUnforgeableMembersAreOwnAndFixed) {
    GlobalEnv env;
    CHECK_JS(env, "window === globalThis");
    CHECK_JS(env, "(d => !d.configurable && d.enumerable && typeof d.get === 'function' && d.set === undefined)(Object.getOwnPropertyDescriptor(globalThis, 'window'))");
    CHECK_JS(env, "!Object.prototype.hasOwnProperty.call(TestGlobal.prototype, 'window')");
    CHECK_JS(env, "delete globalThis.window === false && window === globalThis");
    CHECK_THROWS(env, "Object.defineProperty(globalThis, 'window', {value: 1})", "TypeError");
    // On every instance: an own property whose getter all instances share, and none on the prototype.
    env.eval("var a = new TestTarget(), b = new TestTarget()");
    CHECK_JS(env, "Object.prototype.hasOwnProperty.call(a, 'serial') && !Object.prototype.hasOwnProperty.call(TestTarget.prototype, 'serial')");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(a, 'serial').get === Object.getOwnPropertyDescriptor(b, 'serial').get");
    CHECK_JS(env, "(d => !d.configurable && d.enumerable)(Object.getOwnPropertyDescriptor(a, 'serial'))");
    CHECK_JS(env, "a.serial !== b.serial");
    CHECK_JS(env, "(d => !d.writable && !d.configurable && d.enumerable && d.value === b.stamp)(Object.getOwnPropertyDescriptor(a, 'stamp'))");
    CHECK_JS_EQ(env, "a.stamp()", "stamped");
    // The global has its parent's unforgeable members too, with the same shared functions.
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(globalThis, 'serial').get === Object.getOwnPropertyDescriptor(a, 'serial').get");
    // The shared getter still brand-checks.
    CHECK_THROWS(env, "Object.getOwnPropertyDescriptor(a, 'serial').get.call({})", "TypeError");
}

WR_TEST(testReplaceableAttributesCanBeShadowed) {
    GlobalEnv env;
    CHECK_JS(env, "self === globalThis");
    env.eval("var setSelf = Object.getOwnPropertyDescriptor(globalThis, 'self').set");
    CHECK_JS(env, "typeof setSelf === 'function'");
    CHECK_THROWS(env, "setSelf.call({}, 1)", "TypeError");
    env.eval("self = 5");
    CHECK_JS(env, "self === 5");
    CHECK_JS(env, "(d => d.value === 5 && d.writable && d.enumerable && d.configurable)(Object.getOwnPropertyDescriptor(globalThis, 'self'))");
}

WR_TEST(testEventHandlerAttributesGoThroughTheHandlerHooks) {
    Env env;
    env.eval("var t = new TestTarget(), f = () => 1");
    CHECK_JS(env, "t.onping === null");
    CHECK_JS(env, "(t.onping = f, t.onping === f)");
    CHECK_JS(env, "(t.onerror = f, t.onerror === f)");
    // The glue passed each attribute's event type: its name without "on".
    CHECK_JS_EQ(env, "t.handlerTypes()", "ping,error");
    CHECK_JS(env, "(t.onping = 5, t.onping === null)");
    CHECK_JS(env, "(d => d.enumerable && d.configurable && typeof d.get === 'function' && typeof d.set === 'function')(Object.getOwnPropertyDescriptor(TestTarget.prototype, 'onping'))");
    CHECK_THROWS(env, "Object.getOwnPropertyDescriptor(TestTarget.prototype, 'onping').get.call({})", "TypeError");
}

WR_TEST(testTheGlobalTakesOnePayload) {
    GlobalEnv env;
    bool threw = false;
    try {
        wr::createGlobal<wr::testidl::TestGlobal>(env.ctx());
    } catch (const std::logic_error&) {
        threw = true;
    }
    CHECK(threw);
}

WR_TEST(testTheGlobalPayloadIsFinalizedWithTheContext) {
    int before = wr::testidl::TestGlobal::destroyed();
    {
        GlobalEnv env;
        env.eval("tick(); onping = () => window");
    }
    CHECK_EQ(wr::testidl::TestGlobal::destroyed(), before + 1);
}

WR_TEST(testUnforgeableAndHandlerStateIsCollected) {
    Env env;
    checkNothingLeft(leftoverAfter(env, "(() => { const t = new TestTarget(); t.onping = () => t; t.serial; })()"), "a cycle through an event handler");
    checkNothingLeft(leftoverAfter(env, "(() => { for (let i = 0; i < 10; i++) new TestTarget().stamp(); })()"), "instances with unforgeable members");
}
