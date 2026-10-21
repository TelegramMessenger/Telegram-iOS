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

} // namespace wr_test
