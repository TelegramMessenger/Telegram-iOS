#include "Tests/HostHarness.h"

#include <algorithm>
#include <optional>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/Globals.h"

namespace wr_test {

void TestHost::log(wr::LogLevel level, std::string_view text) {
    logs.emplace_back(level, std::string(text));
}

void TestHost::diagnostic(std::string_view kind, std::string_view detail) {
    diagnostics.emplace_back(std::string(kind), std::string(detail));
}

bool TestHost::hasLog(wr::LogLevel level, std::string_view text) const {
    for (const auto& [l, line] : logs) {
        if (l == level && line.find(text) != std::string::npos) {
            return true;
        }
    }
    return false;
}

namespace {

JSValue runGC(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    JS_RunGC(JS_GetRuntime(ctx));
    return JS_UNDEFINED;
}

} // namespace

void HostEnv::install(uint64_t randomSeed) {
    wr::Runtime::Options options;
    options.limits = testLimits();
    options.cpu = testCpuLimits();
    options.clock = testClock().clock();
    options.interfaces = &wr::idl::kTable;
    options.host = &m_host;
    options.randomSeed = randomSeed;
    m_runtime = wr::Runtime::create(options);
    JSContext* ctx = m_runtime->context();
    // installDOM first: the element factory reads the DOM state's interned names, and installHost reads the document.
    wr::installDOM(ctx, wr::Document::createHTML(ctx));
    wr::installHost(ctx);
    m_runtime->setGlobal("gc", JS_NewCFunction(ctx, runGC, "gc", 0));
}

HostEnv::HostEnv(std::string_view html, uint64_t randomSeed) {
    this->install(randomSeed);
    wr::parseDocumentInto(this->ctx(), wr::globalDocument(this->ctx()), html);
}

HostEnv::HostEnv(BootTag, std::string_view html, std::string url, uint64_t randomSeed, wr::ParseLimits limits) {
    this->install(randomSeed);
    m_bootOutcome = wr::boot(this->ctx(), wr::BootOptions{html, std::move(url), limits});
}

HostEnv::HostEnv(InstallOnly, uint64_t randomSeed) {
    this->install(randomSeed);
}

std::unique_ptr<HostEnv> HostEnv::booted(const wr::BootOptions& options, uint64_t randomSeed,
                                         const std::function<void(HostEnv&)>& beforeBoot) {
    // The constructor is private, so not std::make_unique.
    std::unique_ptr<HostEnv> env(new HostEnv(InstallOnly{}, randomSeed));
    if (beforeBoot) {
        beforeBoot(*env);
    }
    env->m_bootOutcome = wr::boot(env->ctx(), options);
    return env;
}

HostEnv::~HostEnv() = default;

std::string HostEnv::eval(std::string_view code) {
    if (m_runtime->stopReason() != wr::StopReason::None) {
        return "STOPPED";
    }
    wr::EventLoop::of(this->ctx()).advanceTime(m_host.now);
    // A script of its own, as a task is: it starts an operations batch (limit.batch) and runs in a slice.
    m_runtime->startBatch();
    EvalSlice slice(*m_runtime);
    bool threw = false;
    std::string out;
    try {
        out = m_runtime->evaluateToString(code, "<test>", &threw);
    } catch (const wr::Aborted&) {
        // A stop inside the script, or in the checkpoint after it, comes back from evaluateToString as Aborted.
        return "ABORTED";
    }
    // evaluateToString throws Aborted for every stop it sees; a latch it did not see would still not read as success.
    if (m_runtime->stopReason() != wr::StopReason::None) {
        return "ABORTED";
    }
    return threw ? "THROW " + out : out;
}

wr::StepResult HostEnv::step() {
    return wr::EventLoop::of(this->ctx()).runNextTask(m_host.now);
}

int HostEnv::drain(int maxSteps) {
    int ran = 0;
    while (ran < maxSteps && this->step() == wr::StepResult::Ran) {
        ran++;
    }
    return ran;
}

void HostEnv::advance(double ms) {
    double target = m_host.now + ms;
    this->drain();
    wr::EventLoop& loop = wr::EventLoop::of(this->ctx());
    for (;;) {
        if (m_runtime->stopReason() != wr::StopReason::None) {
            return;
        }
        std::optional<double> next = loop.nextTimerDeadline();
        if (!next || *next > target) {
            break;
        }
        m_host.now = std::max(m_host.now, *next);
        this->drain();
    }
    m_host.now = target;
    this->drain();
}

void HostEnv::frame(double ms) {
    this->advance(ms);
    wr::EventLoop::of(this->ctx()).runAnimationFrame(m_host.now);
    this->drain();
}

namespace {

JSValue burnNative(JSContext* ctx, JSValueConst, int, JSValueConst* argv) {
    double ms = 0;
    JS_ToFloat64(ctx, &ms, argv[0]);
    testClock().advance(ms);
    return JS_UNDEFINED;
}

JSValue renderNative(JSContext* ctx, JSValueConst, int, JSValueConst* argv) {
    double ms = 0;
    JS_ToFloat64(ctx, &ms, argv[0]);
    wr::Runtime::RenderScope scope(wr::Runtime::from(ctx), false);
    testClock().advance(ms);
    return JS_UNDEFINED;
}

JSValue queryNative(JSContext* ctx, JSValueConst, int, JSValueConst* argv) {
    double ms = 0;
    JS_ToFloat64(ctx, &ms, argv[0]);
    wr::Runtime::RenderScope scope(wr::Runtime::from(ctx), true);
    testClock().advance(ms);
    return JS_UNDEFINED;
}

/// elapse(ms): the host's clock moves `ms` (a task that took that long on the wall), the CPU clock not.
JSValue elapseNative(JSContext* ctx, JSValueConst, int, JSValueConst* argv) {
    double ms = 0;
    JS_ToFloat64(ctx, &ms, argv[0]);
    static_cast<TestHost&>(wr::Runtime::from(ctx).host()).now += ms;
    return JS_UNDEFINED;
}

/// renderAround(ms, fn, script): a render scope of `ms` before and after a call of `fn` inside it, made in a ScriptScope
/// when `script`, as our renderer calls script.
JSValue renderAroundNative(JSContext* ctx, JSValueConst, int, JSValueConst* argv) {
    double ms = 0;
    JS_ToFloat64(ctx, &ms, argv[0]);
    const bool script = JS_ToBool(ctx, argv[2]);
    wr::Runtime::RenderScope scope(wr::Runtime::from(ctx), false);
    testClock().advance(ms);
    JSValue result;
    {
        std::optional<wr::Runtime::ScriptScope> scriptScope;
        if (script) {
            scriptScope.emplace(wr::Runtime::from(ctx));
        }
        result = JS_Call(ctx, argv[1], JS_UNDEFINED, 0, nullptr);
    }
    if (JS_IsException(result)) {
        return result;
    }
    JS_FreeValue(ctx, result);
    testClock().advance(ms);
    return JS_UNDEFINED;
}

} // namespace

void installClockNatives(HostEnv& env) {
    env.runtime().setGlobal("burn", JS_NewCFunction(env.ctx(), burnNative, "burn", 1));
    env.runtime().setGlobal("render", JS_NewCFunction(env.ctx(), renderNative, "render", 1));
    env.runtime().setGlobal("query", JS_NewCFunction(env.ctx(), queryNative, "query", 1));
    env.runtime().setGlobal("renderAround", JS_NewCFunction(env.ctx(), renderAroundNative, "renderAround", 3));
    env.runtime().setGlobal("elapse", JS_NewCFunction(env.ctx(), elapseNative, "elapse", 1));
}

std::string echoIntl(std::string_view request) {
    const std::string kind = std::string(request.substr(9, request.find('"', 9) - 9));  // {"kind":"…"
    const std::string text(request);
    if (kind.size() > 5 && kind.compare(kind.size() - 5, 5, "Parts") == 0) {
        std::string quoted;
        for (char c : text) {
            quoted += (c == '"' || c == '\\') ? std::string("\\") + c : std::string(1, c);
        }
        return "[{\"type\":\"literal\",\"value\":\"" + quoted + "\"}]";
    }
    if (kind.size() > 7 && kind.compare(kind.size() - 7, 7, "Options") == 0) {
        return "{\"request\":" + text + "}";
    }
    return text;
}

} // namespace wr_test
