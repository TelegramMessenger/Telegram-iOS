// A host for tests: a virtual clock the test moves, a fixed wall clock, and the log and diagnostics it records
// (M1b plan, the header's harness contract), and HostEnv, a runtime with the DOM and the Window installed.
#pragma once

#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "Sources/Host/Boot.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Runtime/Host.h"
#include "Sources/Runtime/Runtime.h"
// The checks (WR_TEST, CHECK_JS, …) a HostEnv test is written with.
#include "Tests/JSHarness.h"

namespace wr_test {

class TestHost : public wr::Host {
public:
    /// Virtual monotonic milliseconds; tests move it.
    double now = 0;
    /// 2026-01-01T00:00:00Z, fixed.
    double wall = 1767225600000.0;
    std::vector<std::pair<wr::LogLevel, std::string>> logs;
    std::vector<std::pair<std::string, std::string>> diagnostics;
    wr::ScriptLoader* loader = nullptr;

    double monotonicNow() override { return now; }
    double wallClockNow() override { return wall + now; }
    void log(wr::LogLevel level, std::string_view text) override;
    void diagnostic(std::string_view kind, std::string_view detail) override;
    wr::ScriptLoader* scriptLoader() override { return loader; }
    /// Every bridge call (M1d plan, Task 4), as (method, argsJson), in order.
    std::vector<std::pair<std::string, std::string>> bridgeCalls;
    /// SDK v1 §2.8: what storageArea answers, per area; and every commit, in order.
    std::map<std::string, std::vector<std::pair<std::string, std::string>>> storedAreas;
    std::vector<std::pair<std::string, std::vector<std::pair<std::string, std::string>>>> storageCommits;
    std::vector<std::pair<std::string, std::string>> storageArea(std::string_view area) override {
        auto it = storedAreas.find(std::string(area));
        return it == storedAreas.end() ? std::vector<std::pair<std::string, std::string>>{} : it->second;
    }
    void storageCommit(std::string_view area, const std::vector<std::pair<std::string, std::string>>& entries) override {
        storageCommits.emplace_back(std::string(area), entries);
    }
    void bridgeCall(std::string_view method, std::string_view argsJson) override {
        bridgeCalls.emplace_back(std::string(method), std::string(argsJson));
    }
    /// widget-sandbox's `intl` capability: every request, in order, answered by `intlAnswer` ("" without one: no locale
    /// data, as the default host).
    std::vector<std::string> intlRequests;
    std::function<std::string(std::string_view)> intlAnswer;
    std::string intl(std::string_view requestJson) override {
        intlRequests.emplace_back(requestJson);
        return intlAnswer ? intlAnswer(requestJson) : std::string();
    }

    /// Whether a line at `level` was logged containing `text`.
    bool hasLog(wr::LogLevel level, std::string_view text) const;
};

/// An `intl` answer for tests (TestHost::intlAnswer) that shows the request to the widget: a format answers the request
/// itself; formatToParts one literal part holding it; resolvedOptions `{"request": …}` (a key resolvedOptions drops: it
/// shows ours alone).
std::string echoIntl(std::string_view request);

/// A ScriptLoader over a map: a URL it has serves its text (as that URL), any other is refused. Records every request.
class MapScriptLoader : public wr::ScriptLoader {
public:
    std::map<std::string, std::string> sources;
    std::vector<std::string> requests;
    std::optional<wr::ScriptSource> load(std::string_view url) override {
        requests.emplace_back(url);
        auto it = sources.find(std::string(url));
        if (it == sources.end()) {
            return std::nullopt;
        }
        return wr::ScriptSource{it->second, std::string(url)};
    }
};

/// Selects HostEnv's booting constructor.
struct BootTag {};


/// A runtime with the DOM, the Window and (Task 9) the loop installed, over a TestHost it owns.
class HostEnv {
public:
    explicit HostEnv(std::string_view html = "<!doctype html><html><head></head><body></body></html>", uint64_t randomSeed = 1);
    /// A runtime with the DOM, the Window and the loop installed over an empty main document, booted from `html`
    /// (wr::boot): the parse's scripts and "the end" are queued, not run; drain() runs them.
    HostEnv(BootTag, std::string_view html, std::string url = "about:srcdoc", uint64_t randomSeed = 1, wr::ParseLimits limits = {});
    /// A HostEnv whose main document is empty until wr::boot parses options.html into it. `beforeBoot` runs after the
    /// DOM, the Window and the loop are installed and before the parse: it installs natives, sets host().loader. The
    /// scripts and "the end" are queued, and no step has run. (Tasks 17 and 18 boot through this.)
    static std::unique_ptr<HostEnv> booted(const wr::BootOptions& options, uint64_t randomSeed = 1,
                                           const std::function<void(HostEnv&)>& beforeBoot = {});
    const wr::ParseOutcome& bootOutcome() const { return m_bootOutcome; }
    ~HostEnv();
    TestHost& host() { return m_host; }
    wr::Runtime& runtime() { return *m_runtime; }
    JSContext* ctx() { return m_runtime->context(); }
    /// Evaluates `code` as a global script at host.now, and the microtask checkpoint after it (the cleanup hook). The
    /// completion value as a string, or "THROW <Name>: <message>" for its own exception (evaluated directly, so not
    /// reported); "ABORTED" when the script or the checkpoint stopped the widget, and "STOPPED", running nothing, once
    /// it is stopped.
    std::string eval(std::string_view code);
    /// loop.runNextTask(host.now).
    wr::StepResult step();
    /// Runs the tasks runnable at host.now until the loop is idle or stopped, at most `maxSteps`; the number run.
    int drain(int maxSteps = 100000);
    /// Moves host.now forward `ms` in deadline order, draining at each deadline (and at the start and the end). Stops
    /// early when the runtime stops.
    void advance(double ms);
    /// advance(ms), then one animation frame at host.now, then drain.
    void frame(double ms = 16.0);

private:
    /// The runtime over m_host, installDOM with an empty main document, installHost, and `gc()`. The host state exists
    /// before anything is parsed, so parsed `on*` attributes (Task 12) and scripts (Task 13) see it.
    void install(uint64_t randomSeed);
    struct InstallOnly {};
    /// install() alone; booted() parses after its hook.
    HostEnv(InstallOnly, uint64_t randomSeed);

    TestHost m_host;  // declared first: it outlives the runtime
    std::unique_ptr<wr::Runtime> m_runtime;
    wr::ParseOutcome m_bootOutcome;
};

/// The fake clock's natives (testClock()): `burn(ms)`, the widget's JS running `ms`; `render(ms)`, our renderer
/// working `ms` in a render scope, as a flush does; `query(ms)`, a layout query's flush taking `ms`; `elapse(ms)`, the
/// host's clock (TestHost::now) moving `ms` within the task.
void installClockNatives(HostEnv& env);

} // namespace wr_test
