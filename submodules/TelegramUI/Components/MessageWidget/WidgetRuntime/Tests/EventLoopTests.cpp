// The event loop (M1b plan, Task 9): tasks and scheduled tasks, the microtask checkpoint, reporting exceptions,
// promise rejections, and the stop latch.
#include <algorithm>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Sources/Events/Events.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

namespace {

/// A global's value as a number, read without running script (a data property read does not poll).
double globalNumber(JSContext* ctx, const char* name) {
    JSValue global = JS_GetGlobalObject(ctx);
    JSValue v = JS_GetPropertyStr(ctx, global, name);
    double d = -1;
    JS_ToFloat64(ctx, &d, v);
    JS_FreeValue(ctx, v);
    JS_FreeValue(ctx, global);
    return d;
}

/// Whether a global is undefined, read without running script.
bool globalIsUndefined(JSContext* ctx, const char* name) {
    JSValue global = JS_GetGlobalObject(ctx);
    JSValue v = JS_GetPropertyStr(ctx, global, name);
    bool undefined = JS_IsUndefined(v);
    JS_FreeValue(ctx, v);
    JS_FreeValue(ctx, global);
    return undefined;
}

wr::Task scriptTask(JSContext* ctx, std::string code) {
    return wr::makeTask(ctx, [code = std::move(code)](JSContext* ctx) { wr::Runtime::from(ctx).runScript(code, "task.js", false); });
}

size_t diagnosticsOfKind(wr_test::HostEnv& env, const char* kind) {
    size_t n = 0;
    for (const auto& [k, detail] : env.host().diagnostics) {
        n += k == kind ? 1 : 0;
    }
    return n;
}

/// Objects of a class registered for one test, whose finalizer counts: what a task or a rejection list captured is
/// released exactly when its finalizer has run.
JSClassID g_countedClass = 0;
int g_countedFinalized = 0;

void finalizeCounted(JSRuntime*, JSValueConst) {
    g_countedFinalized++;
}

JSValue newCounted(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    return JS_NewObjectClass(ctx, g_countedClass);
}

/// globalThis.latch(): latches the runtime and returns normally, as the rejection tracker does when an allocation
/// fails. Called as a microtask itself, it ends a job normally on a stopped runtime with no JS frame left to poll.
JSValue latch(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    wr::Runtime::from(ctx).stop(wr::StopReason::Memory);
    return JS_UNDEFINED;
}

} // namespace

WR_TEST(testTasksRunInOrderWithACheckpointAfterEach) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var log = []");
    wr::EventLoop& loop = wr::EventLoop::of(ctx);
    loop.queueTask(wr::TaskSource::DOMManipulation, scriptTask(ctx, "log.push('t1'); Promise.resolve().then(() => log.push('m1'));"));
    loop.queueTask(wr::TaskSource::DOMManipulation, scriptTask(ctx, "log.push('t2')"));
    CHECK(loop.hasRunnableTask(0));
    CHECK(env.step() == wr::StepResult::Ran);
    CHECK_JS_EQ(env, "log.join()", "t1,m1");
    CHECK(env.step() == wr::StepResult::Ran);
    CHECK_JS_EQ(env, "log.join()", "t1,m1,t2");
    CHECK(env.step() == wr::StepResult::Idle);
    CHECK(!loop.hasRunnableTask(0));
}

WR_TEST(testCheckpointRunsAfterEachOutermostCallback) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var log = []; var d = document.body;"
             "d.addEventListener('x', () => { log.push('L1'); queueMicrotask(() => log.push('M1')); });"
             "d.addEventListener('x', () => { log.push('L2'); queueMicrotask(() => log.push('M2')); });");
    // A task with an empty script stack dispatches: HTML cleans up after each listener.
    wr::EventLoop::of(ctx).queueTask(wr::TaskSource::UserInteraction, wr::makeTask(ctx, [](JSContext* ctx) {
        wr::Atom x = wr::Atom::fromUTF8(ctx, "x");
        // Held across the listeners' calls.
        wr::Ref<wr::HTMLElement> body = wr::Ref<wr::HTMLElement>::retain(ctx, wr::DOMState::of(ctx).document().body(ctx));
        wr::fireEvent(ctx, *body, x.get());
    }));
    CHECK(env.step() == wr::StepResult::Ran);
    CHECK_JS_EQ(env, "log.join()", "L1,M1,L2,M2");
    // A script dispatches: the stack is not empty between the listeners, so the microtasks wait for the script.
    env.eval("log = []; d.dispatchEvent(new Event('x')); log.push('after');");
    CHECK_JS_EQ(env, "log.join()", "L1,L2,after,M1,M2");
}

WR_TEST(testScheduledTasksRunInDeadlineThenSequenceOrder) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var log = []");
    wr::EventLoop& loop = wr::EventLoop::of(ctx);
    loop.queueTaskAt(30, wr::TaskSource::Timer, scriptTask(ctx, "log.push('a')"));
    uint64_t b = loop.queueTaskAt(10, wr::TaskSource::Timer, scriptTask(ctx, "log.push('b')"));
    loop.queueTaskAt(10, wr::TaskSource::Timer, scriptTask(ctx, "log.push('c')"));
    uint64_t d = loop.queueTaskAt(20, wr::TaskSource::Timer, scriptTask(ctx, "log.push('d')"));
    CHECK(b > 0 && d > b);
    CHECK(loop.nextTimerDeadline() == 10.0);
    CHECK(loop.cancelScheduled(d));
    CHECK(!loop.cancelScheduled(d));
    CHECK(!loop.hasRunnableTask(9.5));
    CHECK(loop.runNextTask(9.5) == wr::StepResult::Idle);
    CHECK(loop.hasRunnableTask(10));
    CHECK(loop.runNextTask(10) == wr::StepResult::Ran);
    CHECK_JS_EQ(env, "log.join()", "b");
    CHECK(loop.runNextTask(10) == wr::StepResult::Ran);
    CHECK_JS_EQ(env, "log.join()", "b,c");
    CHECK(loop.runNextTask(10) == wr::StepResult::Idle);
    CHECK(loop.nextTimerDeadline() == 30.0);
    CHECK(loop.runNextTask(100) == wr::StepResult::Ran);
    CHECK_JS_EQ(env, "log.join()", "b,c,a");
    CHECK(!loop.nextTimerDeadline());
    CHECK(!loop.cancelScheduled(b));
    // Time never moves back.
    CHECK_EQ(loop.currentTime(), 100.0);
    loop.runNextTask(50);
    CHECK_EQ(loop.currentTime(), 100.0);
}

WR_TEST(testQueueMicrotaskIsBound) {
    wr_test::HostEnv env;
    CHECK_JS(env, "typeof Object.getOwnPropertyDescriptor(globalThis, 'queueMicrotask').value === 'function'");
    // The IDL member, not QuickJS's own, which installGlobalMembers deletes (C4): a WebIDL operation is enumerable, and
    // the argument's conversion error is the binding's.
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(globalThis, 'queueMicrotask').enumerable");
    CHECK_JS(env, "(() => { try { queueMicrotask(1); } catch (e) { return e.message === \"Failed to execute 'queueMicrotask' on 'Window': parameter 1 is not a function.\"; } })()");
    // HTML invokes the callback with this undefined (QuickJS's own passes the global object).
    env.eval("var seen = 'unset'; queueMicrotask(function () { 'use strict'; seen = this; });");
    CHECK_JS_EQ(env, "String(seen)", "undefined");
    CHECK_THROWS(env, "queueMicrotask(5)", "TypeError");
    // A microtask that throws is reported, and the next one still runs.
    env.eval("var order = []; addEventListener('error', e => order.push('error:' + e.error.message));"
             "queueMicrotask(() => { throw new Error('one'); }); queueMicrotask(() => order.push('two'));");
    CHECK_JS_EQ(env, "order.join()", "error:one,two");
}

WR_TEST(testReportTheExceptionFiresAnErrorEvent) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var got = null; addEventListener('error', e => { got = e; });");
    CHECK(!wr::Runtime::from(ctx).runScript("var x = 1;\nvar y = 2;\nthrow new Error('boom');", "page.js", false));
    CHECK_JS(env, "got instanceof ErrorEvent");
    CHECK_JS_EQ(env, "got.type", "error");
    CHECK_JS_EQ(env, "got.message", "Uncaught Error: boom");
    CHECK_JS_EQ(env, "got.filename", "page.js");
    CHECK_JS_EQ(env, "got.lineno", "3");
    CHECK_JS(env, "got.colno > 0");
    CHECK_JS(env, "got.error instanceof Error && got.error.message === 'boom'");
    CHECK_JS(env, "got.cancelable && got.isTrusted && !got.bubbles");
    CHECK_EQ(env.host().diagnostics.size(), size_t(1));
    CHECK_EQ(env.host().diagnostics[0].first, std::string("uncaught-exception"));
    CHECK(env.host().diagnostics[0].second.find("Uncaught Error: boom") != std::string::npos);
    // A canceled ErrorEvent is handled: nothing reaches the host.
    env.eval("addEventListener('error', e => e.preventDefault());");
    CHECK(!wr::Runtime::from(ctx).runScript("throw new Error('quiet');", "page.js", false));
    CHECK_EQ(env.host().diagnostics.size(), size_t(1));
}

WR_TEST(testReportErrorReports) {
    wr_test::HostEnv env;
    env.eval("var got = []; addEventListener('error', e => got.push(e.message + '|' + (e.error === err) + '|' + e.lineno));");
    env.eval("var err = new TypeError('t'); reportError(err); reportError('s');");
    CHECK_JS_EQ(env, "got.length", "2");
    CHECK_JS(env, "got[0].startsWith('Uncaught TypeError: t|true|')");
    CHECK_JS_EQ(env, "got[1]", "Uncaught s|false|0");
}

// Review Focus 3: an error listener that throws is reported to the host only; it is not dispatched again.
WR_TEST(testThrowingErrorHandlerDoesNotRecurse) {
    wr_test::HostEnv env;
    env.eval("var calls = 0; addEventListener('error', () => { calls++; throw new Error('again'); });");
    env.eval("reportError(new Error('first'))");
    CHECK_JS_EQ(env, "calls", "1");
    CHECK_EQ(env.host().diagnostics.size(), size_t(2));
    CHECK(env.host().diagnostics[0].second.find("again") != std::string::npos);
    CHECK(env.host().diagnostics[1].second.find("first") != std::string::npos);
    // The guard resets: the next report dispatches again.
    env.eval("reportError(new Error('second'))");
    CHECK_JS_EQ(env, "calls", "2");
}

// Fix round 1, M3: a thrown object whose toString reports itself recurses report -> ToString -> reportError -> report,
// which HTML's order (extract the error information, then the reporting-mode guard) allows. QuickJS's stack check ends
// it: the innermost ToString throws a catchable RangeError, which the report drops for the fixed text. Every level
// reports, innermost first, and nothing stops the widget.
WR_TEST(testAToStringThatReportsItselfTerminates) {
    wr_test::HostEnv env;
    CHECK(!env.runtime().runScript("throw { toString() { reportError(this); return 'x'; } }", "page.js", false));
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
    CHECK(diagnosticsOfKind(env, "uncaught-exception") > 1);
    CHECK_EQ(diagnosticsOfKind(env, "uncaught-exception"), env.host().diagnostics.size());
    CHECK_EQ(env.host().diagnostics.front().second, std::string("Uncaught exception"));
    CHECK_EQ(env.host().diagnostics.back().second, std::string("Uncaught x"));
    CHECK_JS_EQ(env, "1 + 1", "2");
}

// Fix round 1, M4 (R5): what reading the exception throws is dropped, not reported. A throwing toString and a Symbol give
// the fixed text; a throwing `stack` getter gives no location.
WR_TEST(testAThrowingExtractionFallsBack) {
    wr_test::HostEnv env;
    wr::Runtime& runtime = env.runtime();
    env.eval("var got = []; addEventListener('error', e => got.push([e.message, e.filename, e.lineno, e.colno].join('|')));");
    CHECK(!runtime.runScript("throw { toString() { throw new Error('no'); } }", "a.js", false));
    CHECK(!runtime.runScript("throw Symbol('s')", "b.js", false));
    CHECK(!runtime.runScript("var e = new Error('m'); Object.defineProperty(e, 'stack', { get() { throw new Error('g'); } }); throw e;", "c.js", false));
    CHECK_JS_EQ(env, "got.join(';')", "Uncaught exception||0|0;Uncaught exception||0|0;Uncaught Error: m||0|0");
    // One report each, and no location: nothing the extraction threw was reported in turn.
    CHECK_EQ(env.host().diagnostics.size(), size_t(3));
    CHECK_EQ(env.host().diagnostics[0].second, std::string("Uncaught exception"));
    CHECK_EQ(env.host().diagnostics[1].second, std::string("Uncaught exception"));
    CHECK_EQ(env.host().diagnostics[2].second, std::string("Uncaught Error: m"));
    CHECK(runtime.stopReason() == wr::StopReason::None);
}

// Final review I3: the reads a report makes of the exception run author code (its toString, a `stack` getter, an
// unhandled rejection's reason described for the host), and they count as script: a callback that code makes is not
// the outermost call, so the microtask checkpoint never runs inside the conversion, and the task's own checkpoint after
// it drains what the conversion queued. probe() queues M, dispatches an event whose listener logs L, then logs A: called
// directly in a timer it logs LAM (the control), and so must it inside each conversion (it logged LMA before the fix).
WR_TEST(testAReportsConversionsRunNoCheckpoint) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    env.eval("var logs = {}, current = null;"
             "document.body.addEventListener('x', () => current.push('L'));"
             "function probe(name) {"
             "  const log = current = logs[name] = [];"
             "  Promise.resolve().then(() => log.push('M'));"
             "  document.body.dispatchEvent(new Event('x'));"
             "  log.push('A');"
             "}"
             // Conversions that throw first (a toString, a `stack` getter): each gives back the depth it counted, which
             // the depth check below and the error listeners' order after it would see.
             "setTimeout(() => { throw { toString() { throw new Error('no'); } }; });"
             "setTimeout(() => {"
             "  const e = new Error('g');"
             "  Object.defineProperty(e, 'stack', { get() { throw new Error('no'); } });"
             "  throw e;"
             "});"
             "setTimeout(() => probe('control'));"
             "setTimeout(() => { throw { toString() { probe('toString'); return 'probe'; } }; });"
             "setTimeout(() => {"
             "  const e = new Error('s');"
             "  Object.defineProperty(e, 'stack', { get() { probe('stack'); return 'x'; } });"
             "  throw e;"
             "});"
             "Promise.reject({ toString() { probe('rejection'); return 'r'; } });");
    env.advance(10);
    CHECK_JS_EQ(env, "logs.control.join('')", "LAM");
    CHECK_JS_EQ(env, "logs.toString.join('')", "LAM");
    CHECK_JS_EQ(env, "logs.stack.join('')", "LAM");
    CHECK_JS_EQ(env, "logs.rejection.join('')", "LAM");
    CHECK_EQ(env.runtime().scriptDepth(), 0);
    // Each was still reported: the conversions' results reach the host.
    CHECK_EQ(diagnosticsOfKind(env, "uncaught-exception"), size_t(4));
    CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection"), size_t(1));
    std::vector<std::string> details;
    for (const auto& [kind, detail] : env.host().diagnostics) {
        details.push_back(detail);
    }
    CHECK(std::find(details.begin(), details.end(), "Uncaught (in promise) r") != details.end());
    CHECK(std::find(details.begin(), details.end(), "Uncaught probe") != details.end());
    // The ErrorEvent's listeners are not conversions: each is an outermost call, with a checkpoint after it (M before S).
    env.eval("var order = [];"
             "addEventListener('error', () => { Promise.resolve().then(() => order.push('M')); });"
             "addEventListener('error', () => order.push('S'));"
             "setTimeout(() => { throw new Error('e'); });");
    env.advance(10);
    CHECK_JS_EQ(env, "order.join('')", "MS");
    // A stop inside a conversion gives the depth back too.
    env.eval("setTimeout(() => { throw { toString() { for (;;) {} } }; });");
    wr_test::stopAfter(env.runtime());
    env.advance(10);
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(env.runtime().scriptDepth(), 0);
}

WR_TEST(testUnhandledRejectionIsReported) {
    wr_test::HostEnv env;
    env.eval("var got = []; addEventListener('unhandledrejection', e => got.push([e instanceof PromiseRejectionEvent, e.promise === p, e.reason.message, e.cancelable].join()));"
             "var p = Promise.reject(new Error('r'));");
    // The checkpoint after the script queued the notification task.
    CHECK_JS_EQ(env, "got.length", "0");
    env.drain();
    CHECK_JS_EQ(env, "got.join(';')", "true,true,r,true");
    CHECK_EQ(env.host().diagnostics.size(), size_t(1));
    CHECK_EQ(env.host().diagnostics[0].first, std::string("unhandled-rejection"));
    // Handling it later fires rejectionhandled.
    env.eval("var handled = []; addEventListener('rejectionhandled', e => handled.push(e.promise === p)); p.catch(() => {});");
    env.drain();
    CHECK_JS_EQ(env, "handled.join()", "true");
    // Handled in the same script: nothing is reported.
    env.eval("got = []; var q = Promise.reject(1); q.catch(() => {});");
    env.drain();
    CHECK_JS_EQ(env, "got.length", "0");
    // Handled after the checkpoint queued the notification, before it ran: skipped, and it was never outstanding, so no
    // rejectionhandled either.
    env.eval("var r = Promise.reject(2);");
    env.eval("r.catch(() => {});");
    env.drain();
    CHECK_JS_EQ(env, "got.length", "0");
    CHECK_JS_EQ(env, "handled.join()", "true");
    // A canceled unhandledrejection is not reported to the host.
    env.eval("addEventListener('unhandledrejection', e => e.preventDefault()); Promise.reject(3);");
    env.drain();
    CHECK_EQ(env.host().diagnostics.size(), size_t(1));
}

// Ruling 13 and R4: the rejection lists are capped. A rejection dropped from either list of 1,024 posts the one
// unhandled-rejection-dropped diagnostic; the outstanding set keeps the newest 256.
WR_TEST(testRejectionListsAreCapped) {
    {
        // The about-to-be-notified list: the 1,025th rejection of one script is dropped.
        wr_test::HostEnv env;
        env.eval("for (let i = 0; i < 1025; i++) Promise.reject(i);");
        CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection-dropped"), size_t(1));
        env.drain();
        CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection"), size_t(1024));
    }
    {
        // The list being notified: a later checkpoint's rejections find it full and are dropped (R4), with one
        // diagnostic for both.
        wr_test::HostEnv env;
        env.eval("for (let i = 0; i < 1024; i++) Promise.reject(i);");
        CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection-dropped"), size_t(0));
        env.eval("Promise.reject('late'); Promise.reject('later');");
        CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection-dropped"), size_t(1));
        env.drain();
        CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection"), size_t(1024));
        CHECK_EQ(diagnosticsOfKind(env, "unhandled-rejection-dropped"), size_t(1));
    }
    {
        // The outstanding set evicts the oldest, which then never gets rejectionhandled.
        wr_test::HostEnv env;
        env.eval("var ps = []; for (let i = 0; i < 257; i++) ps.push(Promise.reject(i));");
        env.drain();
        env.eval("var handled = []; addEventListener('rejectionhandled', e => handled.push(e.reason)); ps.forEach(p => p.catch(() => {}));");
        env.drain();
        CHECK_JS_EQ(env, "handled.length", "256");
        CHECK_JS_EQ(env, "handled[0] + ',' + handled[255]", "1,256");
    }
}

// Review Focus 2: a microtask that queues itself runs until its task's CPU slice ends, then the widget is stopped for
// good.
WR_TEST(testSelfRequeueingMicrotasksStopAtTheLimit) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    wr_test::stopAfter(env.runtime());
    CHECK_EQ(env.eval("var count = 0; (function f() { count++; queueMicrotask(f); })()"), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK(globalNumber(env.ctx(), "count") > 100);
    CHECK(env.step() == wr::StepResult::Stopped);
    CHECK_EQ(env.eval("1"), std::string("STOPPED"));
}

// The CPU stop's interrupt is uncatchable: a promise reaction's own catch does not turn it into a rejection.
WR_TEST(testUncatchableStopSurvivesAPromiseCatch) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    wr_test::stopAfter(env.runtime());
    CHECK_EQ(env.eval("var caught = 0, after = 0;"
                      "Promise.resolve().then(() => { for (;;) {} }).catch(() => { caught++; }).finally(() => { after++; });"),
             std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    CHECK_EQ(globalNumber(env.ctx(), "caught"), 0.0);
    CHECK_EQ(globalNumber(env.ctx(), "after"), 0.0);
}

// Carry C1 (Task 5): a checkpoint whose work stops the widget never returns normally, so the outermost script's caller
// sees the stop, not success, and no JS runs afterwards. Every way a microtask can stop it: the job ends with the
// uncatchable error; the job returns normally on a stopped runtime after JS ran (Promise.try turns the stop into a
// rejection, VENDOR.md entry 8); and a job returns normally on a runtime a native latched, with no JS frame that would
// poll, before a job that must not run.
WR_TEST(testAStopInTheCheckpointReachesTheScriptsCaller) {
    wr_test::ScopedProductSlices slices;
    struct Case {
        const char* microtasks;
        wr::StopReason expected;
    };
    const Case cases[] = {
        {"queueMicrotask(() => { for (;;) {} }); queueMicrotask(() => { globalThis.after = true; });", wr::StopReason::Cpu},
        {"Error.stackTraceLimit = 0; queueMicrotask(() => Promise.try(() => { for (;;) {} }));"
         "queueMicrotask(() => { globalThis.after = true; });",
         wr::StopReason::Cpu},
        // The later job is stopped only by the checkpoint's own latch check after the first (fix round 1, M1).
        {"queueMicrotask(latch); queueMicrotask(() => { globalThis.after = true; });", wr::StopReason::Memory},
    };
    for (const Case& c : cases) {
        wr_test::HostEnv env;
        JSContext* ctx = env.ctx();
        wr::Runtime& runtime = env.runtime();
        runtime.setGlobal("latch", JS_NewCFunction(ctx, latch, "latch", 0));
        wr_test::stopAfter(runtime);
        std::string code = std::string(c.microtasks) + " globalThis.ran = true;";
        bool aborted = false;
        try {
            runtime.runScript(code, "page.js", false);
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        CHECK(aborted);
        CHECK(runtime.stopReason() == c.expected);
        CHECK_EQ(globalNumber(ctx, "ran"), 1.0);
        CHECK(globalIsUndefined(ctx, "after"));
        // Stopped for good: another script aborts without running, and so do the loop and the harness.
        bool again = false;
        try {
            runtime.runScript("globalThis.later = true", "later.js", false);
        } catch (const wr::Aborted&) {
            again = true;
        }
        CHECK(again);
        CHECK(globalIsUndefined(ctx, "later"));
        CHECK(env.step() == wr::StepResult::Stopped);
        CHECK_EQ(env.eval("globalThis.later = true"), std::string("STOPPED"));
        CHECK(globalIsUndefined(ctx, "later"));
    }
    {
        // The same after an outermost call into JS (callFunction, leaveScript): the caller gets Aborted, not a value.
        wr_test::HostEnv env;
        JSContext* ctx = env.ctx();
        env.runtime().setGlobal("latch", JS_NewCFunction(ctx, latch, "latch", 0));
        const char* source = "(() => queueMicrotask(latch))";
        wr::Value f = wr::Value::adopt(ctx, JS_Eval(ctx, source, std::strlen(source), "<value>", JS_EVAL_TYPE_GLOBAL));
        CHECK(JS_IsFunction(ctx, f.get()));
        bool aborted = false;
        try {
            wr::callFunction(ctx, f.get(), JS_UNDEFINED, 0, nullptr);
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        CHECK(aborted);
        CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
    }
}

WR_TEST(testStoppedLoopRunsNothing) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    bool ran = false;
    wr::EventLoop& loop = wr::EventLoop::of(ctx);
    loop.queueTask(wr::TaskSource::DOMManipulation, wr::makeTask(ctx, [&ran](JSContext*) { ran = true; }));
    loop.queueTaskAt(5, wr::TaskSource::Timer, wr::makeTask(ctx, [&ran](JSContext*) { ran = true; }));
    wr_test::stopAfter(env.runtime());
    CHECK_EQ(env.eval("for (;;) {}"), std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
    wr_test::stopAfter(env.runtime(), 1e9);
    CHECK(!loop.hasRunnableTask(100));
    CHECK(!loop.nextTimerDeadline());
    CHECK(loop.runNextTask(100) == wr::StepResult::Stopped);
    CHECK(!ran);
}

WR_TEST(testTaskThatExceedsTheLimitStops) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    wr::EventLoop::of(ctx).queueTask(wr::TaskSource::DOMManipulation, scriptTask(ctx, "for (;;) {}"));
    wr_test::stopAfter(env.runtime());
    CHECK(env.step() == wr::StepResult::Stopped);
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
}

// R3: what a task captured is released when the task has run, and what is still queued, scheduled or awaiting its
// rejection notification is released with the runtime; each counted object's finalizer runs exactly then.
WR_TEST(testTasksReleaseWhatTheyCaptureWithTheRuntime) {
    g_countedFinalized = 0;
    auto env = std::make_unique<wr_test::HostEnv>();
    JSContext* ctx = env->ctx();
    JSRuntime* rt = env->runtime().jsRuntime();
    g_countedClass = 0;
    JS_NewClassID(rt, &g_countedClass);
    JSClassDef def{};
    def.class_name = "Counted";
    def.finalizer = &finalizeCounted;
    CHECK_EQ(JS_NewClass(rt, g_countedClass, &def), 0);
    env->runtime().setGlobal("counted", JS_NewCFunction(ctx, newCounted, "counted", 0));
    auto counted = [ctx] { return wr::Value::adopt(ctx, JS_NewObjectClass(ctx, g_countedClass)); };
    wr::EventLoop& loop = wr::EventLoop::of(ctx);

    loop.queueTask(wr::TaskSource::DOMManipulation, wr::makeTask(ctx, [v = counted()](JSContext*) {}));
    CHECK(env->step() == wr::StepResult::Ran);
    JS_RunGC(rt);
    CHECK_EQ(g_countedFinalized, 1);

    loop.queueTask(wr::TaskSource::DOMManipulation, wr::makeTask(ctx, [v = counted()](JSContext*) {}));
    loop.queueTaskAt(1e9, wr::TaskSource::Timer, wr::makeTask(ctx, [v = counted()](JSContext*) {}));
    // The checkpoint after the script moves the rejection to the list being notified and queues its task, which does
    // not run: the list holds the promise, and the promise its reason.
    env->eval("Promise.reject(counted())");
    JS_RunGC(rt);
    CHECK_EQ(g_countedFinalized, 1);
    env.reset();
    CHECK_EQ(g_countedFinalized, 4);
}
