// The runtime's M1b hooks (M1b plan, Task 5): extension slots, the host, the CPU stop and its latch, script depth
// and the cleanup hook, calls into JS, uncaught exceptions, out of memory, and the document through DOMState.
#include <cstdint>
#include <cstdio>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Sources/Support/Callbacks.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"

namespace {

/// A C++ failure on the host's side of a call into JS.
enum class Failure { None, BadAlloc, Other, ThrownTypeError, ThrownOutOfMemory };

void fail(JSContext* ctx, Failure failure) {
    switch (failure) {
    case Failure::None:
        return;
    case Failure::BadAlloc:
        throw std::bad_alloc();
    case Failure::Other:
        throw std::runtime_error("host failure");
    case Failure::ThrownTypeError:
        JS_ThrowTypeError(ctx, "host failure");
        throw wr::Thrown{};
    case Failure::ThrownOutOfMemory:
        JS_ThrowOutOfMemory(ctx);
        throw wr::Thrown{};
    }
}

/// A Host-slot extension that records what the runtime hands it.
class RecordingExtension : public wr::RuntimeExtension {
public:
    int afterScripts = 0;
    /// The cleanup hook throws Aborted, as a checkpoint whose work stops the widget does.
    bool abortInCleanup = false;
    /// What the cleanup hook and the report throw instead of returning.
    Failure failInCleanup = Failure::None;
    Failure failInReport = Failure::None;
    std::vector<std::string> reported;
    wr::Runtime* runtime = nullptr;
    bool* sawDOMWhenDestroyed = nullptr;
    ~RecordingExtension() override {
        if (sawDOMWhenDestroyed) {
            *sawDOMWhenDestroyed = runtime->extension(wr::ExtensionSlot::DOM) != nullptr;
        }
    }
    void afterOutermostScript(JSContext* ctx) override {
        afterScripts++;
        if (abortInCleanup) {
            throw wr::Aborted{};
        }
        fail(ctx, failInCleanup);
    }
    void reportException(JSContext* ctx, JSValue exception) override {
        if (failInReport != Failure::None) {
            JS_FreeValue(ctx, exception);
            fail(ctx, failInReport);
        }
        const char* text = JS_ToCString(ctx, exception);
        reported.push_back(text ? text : "?");
        JS_FreeCString(ctx, text);
        JS_FreeValue(ctx, exception);
    }
};

/// globalThis.callThrough(f): calls f through wr::callFunction, as a native caller would.
JSValue callThrough(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    return wr::glue(ctx, [&]() -> JSValue {
        wr::CallResult r = wr::callFunction(ctx, argc > 0 ? argv[0] : JS_UNDEFINED, JS_UNDEFINED, 0, nullptr);
        if (r.status == wr::CallStatus::Threw) {
            return JS_Throw(ctx, r.value.release());
        }
        return r.value.release();
    });
}

/// globalThis.throwBadAlloc(): a native that runs out of C++ memory.
JSValue throwBadAlloc(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    return wr::glue(ctx, []() -> JSValue { throw std::bad_alloc(); });
}

/// globalThis.throwUncatchable(): a native that leaves an uncatchable error pending without latching anything, as
/// BindingTests' interrupting list does. Nothing in the runtime does that (its interrupt latches first), so
/// an uncatchable error with work left is an internal failure.
JSValue throwUncatchable(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    return wr::glue(ctx, [&]() -> JSValue {
        JS_ThrowInternalError(ctx, "uncatchable");
        JSValue error = JS_GetException(ctx);
        JS_SetUncatchableError(ctx, error);
        JS_Throw(ctx, error);
        throw wr::Thrown{};
    });
}

/// globalThis.squeezeMemory(): from here every allocation is refused (QuickJS refuses malloc_size + size > limit - 1),
/// so every error QuickJS throws, its out-of-memory error and the interrupt's included, is bare null.
JSValue squeezeMemory(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    JS_SetMemoryLimit(rt, size_t(usage.malloc_size));
    return JS_UNDEFINED;
}

/// globalThis.tick(): a disposer that counts its calls, and those made after the runtime stopped.
struct Ticks {
    int calls = 0;
    int afterStop = 0;
};
Ticks g_ticks;

JSValue tick(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    g_ticks.calls++;
    if (wr::Runtime::from(ctx).stopReason() != wr::StopReason::None) {
        g_ticks.afterStop++;
    }
    return JS_UNDEFINED;
}

/// globalThis.stopAfter(n): the CPU deadline n fake milliseconds (interrupt checks) from now, so a stop lands inside what
/// the script does next.
JSValue stopAfterNative(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv) {
    int32_t n = 0;
    JS_ToInt32(ctx, &n, argc > 0 ? argv[0] : JS_UNDEFINED);
    wr_test::stopAfter(wr::Runtime::from(ctx), double(n));
    return JS_UNDEFINED;
}

/// A value made by evaluating `code` directly (not a script call: no depth, no hook).
wr::Value evalValue(JSContext* ctx, const char* code) {
    std::string source(code);
    return wr::Value::adopt(ctx, wr::checked(ctx, JS_Eval(ctx, source.c_str(), source.size(), "<value>", JS_EVAL_TYPE_GLOBAL)));
}

/// A global's value, read without running script (works on a stopped runtime).
wr::Value global(JSContext* ctx, const char* name) {
    wr::Value g = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    return wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, g.get(), name));
}

/// A global's int32 value (-1 when it is not a number), with the runtime's default memory limit put back first: reading
/// may allocate.
int32_t globalInt(wr::Runtime& runtime, const char* name) {
    JS_SetMemoryLimit(runtime.jsRuntime(), wr::Runtime::Options().memoryLimitBytes);
    int32_t n = -1;
    wr::Value v = global(runtime.context(), name);
    if (JS_IsNumber(v.get())) {
        JS_ToInt32(runtime.context(), &n, v.get());
    }
    return n;
}

bool aborts(wr::Runtime& runtime, const char* code) {
    try {
        runtime.runScript(code, "<test>", false);
    } catch (const wr::Aborted&) {
        return true;
    }
    return false;
}

/// How a call into JS ended, any C++ exception included (so a wrong one fails a check instead of the process).
enum class Outcome { Completed, Reported, Aborted, Escaped };

Outcome run(wr::Runtime& runtime, const char* code, bool isModule = false) {
    try {
        return runtime.runScript(code, "<test>", isModule) ? Outcome::Completed : Outcome::Reported;
    } catch (const wr::Aborted&) {
        return Outcome::Aborted;
    } catch (...) {
        return Outcome::Escaped;
    }
}

Outcome call(JSContext* ctx, JSValueConst fn) {
    try {
        wr::CallResult r = wr::callFunction(ctx, fn, JS_UNDEFINED, 0, nullptr);
        return r.status == wr::CallStatus::Returned ? Outcome::Completed : Outcome::Reported;
    } catch (const wr::Aborted&) {
        return Outcome::Aborted;
    } catch (...) {
        return Outcome::Escaped;
    }
}

Outcome evaluate(wr::Runtime& runtime, const char* code) {
    try {
        bool threw = false;
        runtime.evaluateToString(code, "<test>", &threw);
        return threw ? Outcome::Reported : Outcome::Completed;
    } catch (const wr::Aborted&) {
        return Outcome::Aborted;
    } catch (...) {
        return Outcome::Escaped;
    }
}

/// A runtime whose CPU slice ends 200 fake milliseconds from now.
void limitWork(wr_test::DOMEnv& env) {
    wr_test::stopAfter(env.runtime());
}

} // namespace

WR_TEST(testExtensionSlotsAreIndependent) {
    bool sawDOM = false;
    {
        wr_test::DOMEnv env;
        auto extension = std::make_unique<RecordingExtension>();
        RecordingExtension* raw = extension.get();
        extension->runtime = &env.runtime();
        extension->sawDOMWhenDestroyed = &sawDOM;
        env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
        CHECK(env.runtime().extension(wr::ExtensionSlot::Host) == raw);
        CHECK(env.runtime().extension(wr::ExtensionSlot::DOM) == &wr::DOMState::of(env.ctx()));
    }
    // The host slot goes first: its state may refer to the DOM's, never the other way round.
    CHECK(sawDOM);
}

WR_TEST(testTheDocumentComesFromDOMState) {
    wr_test::DOMEnv env;
    JSContext* ctx = env.ctx();
    CHECK(wr::DOMState::of(ctx).hasDocument());
    CHECK(&wr::globalDocument(ctx) == &wr::DOMState::of(ctx).document());
    CHECK_JS(env, "new Text('x').ownerDocument === document");
    CHECK_JS(env, "new Comment('x').ownerDocument === document");
    CHECK_JS(env, "new DocumentFragment().ownerDocument === document");
}

WR_TEST(testTheCpuLimitStopsScriptsForGood) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    wr::Runtime& runtime = env.runtime();
    wr_test::stopAfter(runtime);
    CHECK(aborts(runtime, "for (;;) {}"));
    CHECK(runtime.stopReason() == wr::StopReason::Cpu);
    // Latched: a new slice does not revive it, and nothing runs.
    wr_test::stopAfter(runtime, 1e9);
    CHECK(aborts(runtime, "globalThis.ran = true"));
    CHECK(JS_IsUndefined(global(env.ctx(), "ran").get()));
    CHECK(runtime.stopReason() == wr::StopReason::Cpu);
}

WR_TEST(testTryCatchCannotSwallowTheStop) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    wr::Runtime& runtime = env.runtime();
    wr_test::stopAfter(runtime);
    CHECK(aborts(runtime, "try { for (;;) {} } catch (e) { globalThis.caught = true } globalThis.after = true"));
    CHECK(JS_IsUndefined(global(env.ctx(), "caught").get()));
    CHECK(JS_IsUndefined(global(env.ctx(), "after").get()));
}

WR_TEST(testCallFunctionHasThreeOutcomes) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    JSContext* ctx = env.ctx();
    wr::Value ok = evalValue(ctx, "(() => 42)");
    wr::CallResult r = wr::callFunction(ctx, ok.get(), JS_UNDEFINED, 0, nullptr);
    CHECK(r.status == wr::CallStatus::Returned);
    int32_t n = 0;
    JS_ToInt32(ctx, &n, r.value.get());
    CHECK_EQ(n, 42);

    wr::Value bad = evalValue(ctx, "(() => { throw new TypeError('t') })");
    wr::CallResult thrown = wr::callFunction(ctx, bad.get(), JS_UNDEFINED, 0, nullptr);
    CHECK(thrown.status == wr::CallStatus::Threw);
    CHECK(JS_IsError(thrown.value.get()));
    CHECK(env.runtime().stopReason() == wr::StopReason::None);

    wr::Value loop = evalValue(ctx, "(() => { for (;;) {} })");
    wr_test::stopAfter(env.runtime());
    bool aborted = false;
    try {
        wr::callFunction(ctx, loop.get(), JS_UNDEFINED, 0, nullptr);
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
}

WR_TEST(testCallInterfaceFollowsWebIDL) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    JSContext* ctx = env.ctx();
    wr::Value thisArg = evalValue(ctx, "({ marker: 1 })");
    JSValue five = JS_NewInt32(ctx, 5);

    // An object's operation is read at call time and called with the object as `this`.
    wr::Value object = evalValue(ctx, "globalThis.o = { handleEvent(x) { this.seen = x; return this === o } }");
    wr::CallResult r = wr::callInterface(ctx, object.get(), "handleEvent", thisArg.get(), 1, &five);
    CHECK(r.status == wr::CallStatus::Returned && JS_ToBool(ctx, r.value.get()) == 1);
    CHECK_JS_EQ(env, "o.seen", "5");

    // A function is called with the given `this`.
    wr::Value fn = evalValue(ctx, "(function () { return this.marker })");
    wr::CallResult viaFunction = wr::callInterface(ctx, fn.get(), "handleEvent", thisArg.get(), 0, nullptr);
    CHECK_EQ(JS_ToBool(ctx, viaFunction.value.get()), 1);

    // The getter runs once per call; a property that is not callable is a TypeError.
    wr::Value counted = evalValue(ctx, "globalThis.reads = 0, ({ get handleEvent() { reads++; return () => 3 } })");
    wr::callInterface(ctx, counted.get(), "handleEvent", JS_UNDEFINED, 0, nullptr);
    CHECK_JS_EQ(env, "reads", "1");
    wr::Value notCallable = evalValue(ctx, "({ handleEvent: 1 })");
    wr::CallResult typeError = wr::callInterface(ctx, notCallable.get(), "handleEvent", JS_UNDEFINED, 0, nullptr);
    CHECK(typeError.status == wr::CallStatus::Threw);
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
}

WR_TEST(testTheCleanupHookRunsWhenTheOutermostScriptReturns) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    JSContext* ctx = env.ctx();
    auto extension = std::make_unique<RecordingExtension>();
    RecordingExtension* recorder = extension.get();
    env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
    env.runtime().setGlobal("callThrough", JS_NewCFunction(ctx, callThrough, "callThrough", 1));

    // Nested calls run at depth >= 1: only the outermost one cleans up.
    CHECK(env.runtime().runScript("callThrough(() => callThrough(() => 1))", "<test>", false));
    CHECK_EQ(recorder->afterScripts, 1);
    CHECK_EQ(env.runtime().scriptDepth(), 0);

    wr::Value f = evalValue(ctx, "(() => 1)");
    wr::callFunction(ctx, f.get(), JS_UNDEFINED, 0, nullptr);
    CHECK_EQ(recorder->afterScripts, 2);

    // A stop runs no cleanup.
    wr_test::stopAfter(env.runtime());
    CHECK(aborts(env.runtime(), "callThrough(() => { for (;;) {} })"));
    CHECK_EQ(recorder->afterScripts, 2);
    CHECK_EQ(env.runtime().scriptDepth(), 0);
}

WR_TEST(testUncaughtExceptionsAreReported) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    CHECK(!env.runtime().runScript("throw new Error('boom')", "boom.js", false));
    // With no host extension the runtime logs it.
    CHECK(host.hasLog(wr::LogLevel::Error, "Uncaught Error: boom"));

    auto extension = std::make_unique<RecordingExtension>();
    RecordingExtension* recorder = extension.get();
    env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
    CHECK(!env.runtime().runScript("throw new RangeError('r')", "r.js", false));
    CHECK(recorder->reported.size() == 1 && recorder->reported[0] == "RangeError: r");
    // A syntax error is reported the same way, and the runtime keeps running.
    CHECK(!env.runtime().runScript("this is not javascript", "s.js", false));
    CHECK(recorder->reported.size() == 2);
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
}

// Final review I3: the default report's ToString counts as script. A call into JS that the exception's toString makes
// (callThrough) is not the outermost one, so the cleanup hook (the microtask checkpoint) does not run inside the
// conversion; the report's caller runs it after.
WR_TEST(testTheDefaultReportsConversionRunsNoCleanup) {
    /// A Host-slot extension that counts the cleanup hook and keeps the default report (logUncaughtException).
    class CleanupCounter : public wr::RuntimeExtension {
    public:
        int afterScripts = 0;
        void afterOutermostScript(JSContext*) override { afterScripts++; }
    };
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    JSContext* ctx = env.ctx();
    auto extension = std::make_unique<CleanupCounter>();
    CleanupCounter* counter = extension.get();
    env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
    env.runtime().setGlobal("callThrough", JS_NewCFunction(ctx, callThrough, "callThrough", 1));
    wr::Value thrown = evalValue(ctx, "({ toString() { callThrough(() => 1); return 'probe'; } })");
    env.runtime().logUncaughtException(ctx, thrown.release());
    CHECK_EQ(counter->afterScripts, 0);
    CHECK(host.hasLog(wr::LogLevel::Error, "Uncaught probe"));
    CHECK_EQ(env.runtime().scriptDepth(), 0);
    // The same call made outside a conversion is the outermost one.
    wr::Value f = evalValue(ctx, "(() => callThrough(() => 1))");
    wr::callFunction(ctx, f.get(), JS_UNDEFINED, 0, nullptr);
    CHECK_EQ(counter->afterScripts, 1);
}

WR_TEST(testTheUncaughtExceptionLogIsCut) {
    // A diagnostic's text is cut at 4,000 bytes (Ruling 14), and only that much of the exception is converted.
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    CHECK(!env.runtime().runScript("throw 'x'.repeat(1 << 20)", "big.js", false));
    CHECK(host.logs.size() == 1 && host.logs[0].second == "Uncaught " + std::string(4000, 'x'));
    // Cut at a character boundary: 1,333 three-byte characters are 3,999 bytes; one more would be 4,002.
    CHECK(!env.runtime().runScript("throw '\\u4e00'.repeat(5000)", "wide.js", false));
    CHECK(host.logs.size() == 2 && host.logs[1].second.size() == std::string("Uncaught ").size() + 3999);
    // Ropes (concatenations) are cut the same way: a thrown one, and an Error's toString.
    CHECK(!env.runtime().runScript("throw ('x'.repeat(1 << 20) + '!')", "rope.js", false));
    CHECK(host.logs.size() == 3 && host.logs[2].second == "Uncaught " + std::string(4000, 'x'));
    CHECK(!env.runtime().runScript("throw new Error('x'.repeat(1 << 20))", "error.js", false));
    CHECK(host.logs.size() == 4 && host.logs[3].second == "Uncaught Error: " + std::string(4000 - 7, 'x'));
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
}

WR_TEST(testOutOfMemoryStopsTheRuntime) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    JS_SetMemoryLimit(env.runtime().jsRuntime(), size_t(32) << 20);
    // Doubling strings: the allocator refuses the 16 MiB one and latches the stop (quickjs-ng change 9).
    CHECK(aborts(env.runtime(), "var a = []; for (let n = 1024; ; n *= 2) a.push('x'.repeat(n))"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
}

WR_TEST(testOutOfMemoryStopsAtEveryLimit) {
    // Wherever the limit falls, the widget stops with Memory. A refusal that leaves too little free to build QuickJS's
    // out-of-memory error makes QuickJS throw bare null, which reads as an ordinary exception; the latch at the
    // allocator (quickjs-ng change 9) decides instead. This loop of 160 KB arrays, the first form of the test above,
    // landed there for 29% of the limits within 160 KB of 32 MiB (Task 12).
    int failed = 0;
    for (size_t i = 0; i < 64; i++) {
        size_t limit = (size_t(32) << 20) - size_t(160) * 1024 + i * 5 * 1024;
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        JS_SetMemoryLimit(env.runtime().jsRuntime(), limit);
        Outcome outcome = run(env.runtime(), "var a = []; for (;;) a.push(new Array(10000).fill(1))");
        if (outcome != Outcome::Aborted || env.runtime().stopReason() != wr::StopReason::Memory) {
            failed++;
            std::printf("  limit %zu: outcome %d, stop reason %d\n", limit, int(outcome), int(env.runtime().stopReason()));
        }
    }
    if (failed) {
        std::printf("  %d of 64 limits did not stop with Memory\n", failed);
    }
    CHECK_EQ(failed, 0);
}

WR_TEST(testOutOfMemoryCannotBeCaught) {
    // QuickJS's out-of-memory error is an ordinary error, but the allocator latched the stop when it refused (quickjs-ng
    // change 9), and from then on no exception can be caught (change 10): the catch does not run, and the widget stops
    // there, with no other limit.
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    wr::Runtime& runtime = env.runtime();
    JS_SetMemoryLimit(runtime.jsRuntime(), size_t(32) << 20);
    CHECK(run(runtime, "try { new ArrayBuffer(256 << 20) } catch (e) { globalThis.caught = true } for (;;) {}") == Outcome::Aborted);
    CHECK(runtime.stopReason() == wr::StopReason::Memory);
    CHECK(JS_IsUndefined(global(env.ctx(), "caught").get()));
}

WR_TEST(testOutOfMemoryInAPromiseStops) {
    // The allocator latched the stop when it refused (quickjs-ng change 9), before QuickJS threw its out-of-memory error,
    // so the executor and the reaction propagate that error rather than rejecting with it (change 10): no rejection, and
    // nothing after the constructor runs.
    {
        wr_test::HostEnv env;
        JS_SetMemoryLimit(env.runtime().jsRuntime(), size_t(32) << 20);
        CHECK(run(env.runtime(), "new Promise(() => { new ArrayBuffer(256 << 20) }); globalThis.after = true") == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
        CHECK(JS_IsUndefined(global(env.ctx(), "after").get()));
        // No rejection is reported after the latch, and no uncaught exception.
        CHECK(env.host().diagnostics.empty());
    }
    {
        // A reaction runs in the microtask checkpoint after the script.
        wr_test::HostEnv env;
        JS_SetMemoryLimit(env.runtime().jsRuntime(), size_t(32) << 20);
        CHECK(run(env.runtime(), "Promise.resolve().then(() => { new ArrayBuffer(256 << 20) })") == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
        CHECK(env.host().diagnostics.empty());
    }
}

WR_TEST(testAStopIsNotCaughtWhenItsErrorCannotBeBuilt) {
    // Once a stop is latched no exception can be caught (quickjs-ng change 10), even where QuickJS cannot build the
    // interrupt's error and throws bare null. squeezeMemory leaves no room for any allocation, so every error is null:
    // the state Task 12a found at one limit of the sweep above (33,651,712, with the sweep's script in a try), where this
    // loop caught all 1,000,000 polls after the Memory latch and ran 126M units past a 50M-unit budget. Here the refused
    // ArrayBuffer latches Memory: neither its own catch nor any in the loop runs.
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    wr::Runtime& runtime = env.runtime();
    runtime.setGlobal("squeezeMemory", JS_NewCFunction(env.ctx(), squeezeMemory, "squeezeMemory", 0));
    // The globals exist before the squeeze: assigning them allocates nothing.
    CHECK(run(runtime, "var n = 0, caught = 0; squeezeMemory(); try { new ArrayBuffer(1024) } catch (e) { caught++ }"
                       " for (let i = 0; i < 100000; i++) { try { for (;;) {} } catch (e) { n++ } }") == Outcome::Aborted);
    CHECK(runtime.stopReason() == wr::StopReason::Memory);
    CHECK_EQ(globalInt(runtime, "caught"), 0);
    CHECK_EQ(globalInt(runtime, "n"), 0);
}

WR_TEST(testDisposalEndsAtTheStop) {
    // A disposal calls every remaining disposer, collecting their exceptions; once a stop is latched the first disposer to
    // throw ends it (quickjs-ng change 10): in a DisposableStack (also through `using`) and in a scope's `using`
    // declarations. Before that a stack of 100,000 defers ran millions of units past its budget's stop.
    // QuickJS polls its interrupt every 10,000 calls and jumps (stock quickjs-ng since the CPU-clock limits plan's
    // Task 2), so the scope's disposers are more than that many.
    std::string scope = "function scope() { using a0 = d";
    for (int i = 1; i < 20000; i++) {
        scope += ", a" + std::to_string(i) + " = d";
    }
    scope += "; }";
    struct Case {
        const char* setup;
        const char* dispose;
        int total;
    };
    const std::string stack = "var s = new DisposableStack(); for (let i = 0; i < 100000; i++) s.defer(tick)";
    const std::string declarations = "var d = { [Symbol.dispose]: tick }; " + scope;
    const Case cases[] = {
        {stack.c_str(), "stopAfter(1); s.dispose()", 100000},
        {stack.c_str(), "stopAfter(1); { using t = s; }", 100000},
        {declarations.c_str(), "stopAfter(1); scope()", 20000},
    };
    for (const Case& c : cases) {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        wr::Runtime& runtime = env.runtime();
        runtime.setGlobal("tick", JS_NewCFunction(env.ctx(), tick, "tick", 0));
        runtime.setGlobal("stopAfter", JS_NewCFunction(env.ctx(), stopAfterNative, "stopAfter", 1));
        CHECK(run(runtime, c.setup) == Outcome::Completed);
        g_ticks = Ticks{};
        CHECK(run(runtime, c.dispose) == Outcome::Aborted);
        CHECK(runtime.stopReason() == wr::StopReason::Cpu);
        // The stop landed inside the disposal, and at most one disposer ran after it.
        CHECK(g_ticks.calls > 0 && g_ticks.calls < c.total);
        CHECK(g_ticks.afterStop <= 1);
        if (g_ticks.afterStop > 1 || g_ticks.calls >= c.total) {
            std::printf("  `%s`: %d of %d disposers ran, %d after the stop\n", c.dispose, g_ticks.calls, c.total, g_ticks.afterStop);
        }
    }
}

WR_TEST(testACpuStopIsNotCaught) {
    // The slice's interrupt cannot be caught: with memory to spare it is QuickJS's uncatchable error; with none (the
    // squeeze) it is bare null, which only the latch's stop makes uncatchable (quickjs-ng change 10). Before that change
    // the squeezed loop caught every poll.
    for (bool squeeze : {false, true}) {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        wr::Runtime& runtime = env.runtime();
        runtime.setGlobal("squeezeMemory", JS_NewCFunction(env.ctx(), squeezeMemory, "squeezeMemory", 0));
        wr_test::stopAfter(runtime);
        std::string script = std::string("var n = 0; ") + (squeeze ? "squeezeMemory(); " : "") +
                             "for (let i = 0; i < 100000; i++) { try { for (;;) {} } catch (e) { n++ } }";
        CHECK(run(runtime, script.c_str()) == Outcome::Aborted);
        CHECK(runtime.stopReason() == wr::StopReason::Cpu);
        CHECK_EQ(globalInt(runtime, "n"), 0);
    }
}

WR_TEST(testAScriptsOwnThrowNullIsCatchable) {
    // QuickJS throws bare null when it cannot build its out-of-memory error, but the allocator's latch is what says a
    // widget ran out of memory: a script's own null stays an ordinary exception, caught or reported.
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    CHECK(run(env.runtime(), "try { throw null } catch (e) { globalThis.caught = e === null }") == Outcome::Completed);
    CHECK(JS_ToBool(env.ctx(), global(env.ctx(), "caught").get()) == 1);
    CHECK(run(env.runtime(), "throw null") == Outcome::Reported);
    CHECK(host.hasLog(wr::LogLevel::Error, "Uncaught null"));
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
}

WR_TEST(testNativeOutOfMemoryCannotBeCaught) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    env.runtime().setGlobal("throwBadAlloc", JS_NewCFunction(env.ctx(), throwBadAlloc, "throwBadAlloc", 0));
    CHECK(aborts(env.runtime(), "try { throwBadAlloc() } catch (e) { globalThis.caught = true }"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
    CHECK(JS_IsUndefined(global(env.ctx(), "caught").get()));
}

WR_TEST(testAnUncatchableErrorWithoutALatchIsInternal) {
    // One classifier serves every path that latches on an exception (PF5): out of memory is Memory, a stop latched at
    // the interrupt keeps its own reason, and any other uncatchable error is Internal.
    {
        // An exception a script's evaluation ends with (runScript).
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        env.runtime().setGlobal("throwUncatchable", JS_NewCFunction(env.ctx(), throwUncatchable, "throwUncatchable", 0));
        CHECK(aborts(env.runtime(), "try { throwUncatchable() } catch (e) { globalThis.caught = true }"));
        CHECK(env.runtime().stopReason() == wr::StopReason::Internal);
        CHECK(JS_IsUndefined(global(env.ctx(), "caught").get()));
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
    {
        // A call's result (callFunction, leaveScript).
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        JSContext* ctx = env.ctx();
        env.runtime().setGlobal("throwUncatchable", JS_NewCFunction(ctx, throwUncatchable, "throwUncatchable", 0));
        wr::Value f = evalValue(ctx, "(() => throwUncatchable())");
        bool aborted = false;
        try {
            wr::callFunction(ctx, f.get(), JS_UNDEFINED, 0, nullptr);
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        CHECK(aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Internal);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
    {
        // The default report's ToString (logUncaughtException): the thrown object's toString hits it.
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        env.runtime().setGlobal("throwUncatchable", JS_NewCFunction(env.ctx(), throwUncatchable, "throwUncatchable", 0));
        CHECK(aborts(env.runtime(), "throw { toString() { throwUncatchable() } }"));
        CHECK(env.runtime().stopReason() == wr::StopReason::Internal);
        CHECK(host.logs.empty());
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
}

WR_TEST(testAStopThatAPromiseSwallowedStillAborts) {
    // A Promise executor that the CPU slice stops: the stop propagates (quickjs-ng change 8), so nothing after the
    // constructor runs. stackTraceLimit 0: otherwise the backtrace's allocation re-arms the poll and stops it by
    // accident.
    const char* executor = "Error.stackTraceLimit = 0; new Promise(() => { for (;;) {} }); globalThis.after = true";
    // Promise.try still turns the stop into a rejection (VENDOR.md entry 8 leaves it), and a module's evaluation
    // always does: the runtime's check of its latch after the call is what stops those.
    const char* tried = "Error.stackTraceLimit = 0; Promise.try(() => { for (;;) {} })";
    {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        limitWork(env);
        CHECK(run(env.runtime(), executor) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
        CHECK(JS_IsUndefined(global(env.ctx(), "after").get()));
    }
    {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        limitWork(env);
        CHECK(run(env.runtime(), tried) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
    {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        limitWork(env);
        CHECK(run(env.runtime(), "for (;;) {}", true) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    }
    {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        JSContext* ctx = env.ctx();
        wr::Value viaExecutor = evalValue(ctx, (std::string("(() => { ") + executor + " })").c_str());
        limitWork(env);
        CHECK(call(ctx, viaExecutor.get()) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
        CHECK(JS_IsUndefined(global(ctx, "after").get()));
    }
    {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        JSContext* ctx = env.ctx();
        wr::Value viaTry = evalValue(ctx, (std::string("(() => { ") + tried + " })").c_str());
        limitWork(env);
        CHECK(call(ctx, viaTry.get()) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
    {
        // evaluateToString too: a call that latched throws Aborted (HostEnv::eval answers "ABORTED").
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        limitWork(env);
        CHECK(evaluate(env.runtime(), tried) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
}

WR_TEST(testAStoppedRuntimeEvaluatesNothing) {
    // evaluateToString on a latched runtime does not evaluate: it answers what a stop inside a script reads back as.
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    env.runtime().stop(wr::StopReason::Internal);
    bool threw = false;
    CHECK(env.runtime().evaluateToString("globalThis.ran = true", "<test>", &threw) == "InternalError: interrupted");
    CHECK(threw);
    CHECK(JS_IsUndefined(global(env.ctx(), "ran").get()));
}

WR_TEST(testAHostFailureAtTheScriptBoundaryStops) {
    // A C++ failure on the host's side of a call into JS (the report, the cleanup hook) stops the widget as one inside a
    // binding does, and leaves as Aborted: bad_alloc is Memory, anything else Internal. A Thrown is classified by its
    // pending exception (PF5): QuickJS's out of memory is Memory, a catchable one Internal.
    struct Case {
        Failure failure;
        bool inReport;
        wr::StopReason expected;
    };
    const Case cases[] = {
        {Failure::BadAlloc, true, wr::StopReason::Memory},
        {Failure::Other, true, wr::StopReason::Internal},
        {Failure::ThrownTypeError, true, wr::StopReason::Internal},
        {Failure::ThrownOutOfMemory, true, wr::StopReason::Memory},
        {Failure::BadAlloc, false, wr::StopReason::Memory},
        {Failure::Other, false, wr::StopReason::Internal},
    };
    for (const Case& c : cases) {
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        auto extension = std::make_unique<RecordingExtension>();
        (c.inReport ? extension->failInReport : extension->failInCleanup) = c.failure;
        env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
        CHECK(run(env.runtime(), c.inReport ? "throw 1" : "1") == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == c.expected);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
    {
        // The cleanup hook after a call (leaveScript).
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        wr::Value f = evalValue(env.ctx(), "(() => 1)");
        auto extension = std::make_unique<RecordingExtension>();
        extension->failInCleanup = Failure::BadAlloc;
        env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
        CHECK(call(env.ctx(), f.get()) == Outcome::Aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
        CHECK_EQ(env.runtime().scriptDepth(), 0);
    }
}

WR_TEST(testAStoppedRuntimeCallsNothing) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    JSContext* ctx = env.ctx();
    wr::Value f = evalValue(ctx, "(() => { globalThis.called = true })");
    env.runtime().stop(wr::StopReason::Internal);
    env.runtime().stop(wr::StopReason::Cpu);
    CHECK(env.runtime().stopReason() == wr::StopReason::Internal);
    bool aborted = false;
    try {
        wr::callFunction(ctx, f.get(), JS_UNDEFINED, 0, nullptr);
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK(JS_IsUndefined(global(ctx, "called").get()));
}

namespace {

/// Whether wr::throwIfFatal(ctx, exception) threw Aborted.
bool fatal(JSContext* ctx, JSValueConst exception) {
    try {
        wr::throwIfFatal(ctx, exception);
    } catch (const wr::Aborted&) {
        return true;
    }
    return false;
}

} // namespace

WR_TEST(testThrowIfFatalLatchesOnlyWhatCannotBeCaught) {
    {
        // A catchable exception is the caller's to report: nothing latches.
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        wr::Value error = evalValue(env.ctx(), "new TypeError('t')");
        CHECK(!fatal(env.ctx(), error.get()));
        CHECK(env.runtime().stopReason() == wr::StopReason::None);
    }
    {
        // QuickJS's out-of-memory error.
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        JS_ThrowOutOfMemory(env.ctx());
        wr::Value oom = wr::Value::adopt(env.ctx(), JS_GetException(env.ctx()));
        CHECK(fatal(env.ctx(), oom.get()));
        CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
    }
    {
        // An uncatchable error with work left is an internal failure.
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        JS_ThrowInternalError(env.ctx(), "x");
        wr::Value error = wr::Value::adopt(env.ctx(), JS_GetException(env.ctx()));
        JS_SetUncatchableError(env.ctx(), error.get());
        CHECK(fatal(env.ctx(), error.get()));
        CHECK(env.runtime().stopReason() == wr::StopReason::Internal);
    }
    {
        // Once stopped, every exception is fatal, and the first reason stays. (The error is made first: evalValue calls
        // JS_Eval directly, which a stopped runtime's interrupt refuses at its first poll.)
        wr_test::TestHost host;
        wr_test::DOMEnv env(host);
        wr::Value error = evalValue(env.ctx(), "new TypeError('t')");
        env.runtime().stop(wr::StopReason::Cpu);
        CHECK(fatal(env.ctx(), error.get()));
        CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    }
}

WR_TEST(testEvaluateToStringPassesAStopInTheCleanupOn) {
    wr_test::TestHost host;
    wr_test::DOMEnv env(host);
    auto extension = std::make_unique<RecordingExtension>();
    RecordingExtension* recorder = extension.get();
    env.runtime().setExtension(wr::ExtensionSlot::Host, std::move(extension));
    bool threw = false;
    // A script's own exception is still a string.
    CHECK(env.runtime().evaluateToString("throw new Error('e')", "<test>", &threw) == "Error: e" && threw);
    recorder->abortInCleanup = true;
    bool aborted = false;
    try {
        env.runtime().evaluateToString("1", "<test>", &threw);
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK_EQ(env.runtime().scriptDepth(), 0);
}

WR_TEST(testDateAndRandomComeFromTheHost) {
    wr_test::TestHost host;
    host.now = 250;
    wr_test::DOMEnv env(host);
    CHECK_JS_EQ(env, "Date.now()", "1767225600250");
    CHECK_JS_EQ(env, "new Date().getTime()", "1767225600250");
    std::string first = env.eval("[Math.random(), Math.random(), Math.random()].join()");

    wr_test::TestHost sameHost;
    wr_test::DOMEnv same(sameHost);
    CHECK(same.eval("[Math.random(), Math.random(), Math.random()].join()") == first);

    wr::Runtime::Options options;
    options.interfaces = &wr::idl::kTable;
    options.host = &host;
    options.randomSeed = 2;
    std::unique_ptr<wr::Runtime> other = wr::Runtime::create(options);
    bool threw = false;
    CHECK(other->evaluateToString("[Math.random(), Math.random(), Math.random()].join()", "<test>", &threw) != first);
}
