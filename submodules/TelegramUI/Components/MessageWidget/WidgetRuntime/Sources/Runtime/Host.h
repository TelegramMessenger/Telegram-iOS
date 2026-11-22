// What the embedder gives a widget's runtime: its clocks, its log and diagnostics, and the only way a script source
// can arrive (M1b plan, Global Constraints "Time" and "No network"). The runtime never reads a clock of its own.
#pragma once

#include <vector>

#include <utility>

#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <optional>
#include <string>
#include <string_view>

namespace wr {

enum class LogLevel : uint8_t { Debug, Log, Info, Warn, Error };

/// The most UTF-8 bytes of a script-made text the runtime gives the host (M1b plan, Ruling 14): an uncaught
/// exception's string (after its "Uncaught "), a console line. It is cut at a character boundary, with no marker,
/// and only that much of it is converted.
inline constexpr size_t kMaxDiagnosticBytes = 4000;

/// A script's source, as the loader resolved it.
struct ScriptSource {
    std::string text;
    std::string url;
};

/// Resolves an external script's `src`. The library has no implementation: the app's (M1d) resolves only bundled
/// libraries, and the WPT runner's reads the vendored tree. nullopt refuses the script.
class ScriptLoader {
public:
    virtual ~ScriptLoader() = default;
    virtual std::optional<ScriptSource> load(std::string_view url) = 0;
};

class Host {
public:
    virtual ~Host() = default;
    /// Monotonic milliseconds: performance.now() and Event.timeStamp are this minus the window's time origin. Only
    /// reported to script; no decision of the runtime reads it. Read by native code (currentHighResTime, the host
    /// state's time origin), never from inside QuickJS: it must not throw, and a throw inside a binding call reaches
    /// rethrowAsJS (or a step's guard) and stops the widget with StopReason::Internal.
    virtual double monotonicNow() = 0;
    /// Milliseconds since the epoch: Date.now() and new Date() (quickjs-ng change 7). Read from inside QuickJS (Date,
    /// through a noexcept callback): it must not throw, and a throw terminates the process rather than unwinding
    /// through the engine.
    virtual double wallClockNow() = 0;
    virtual void log(LogLevel level, std::string_view text) = 0;
    virtual void diagnostic(std::string_view kind, std::string_view detail) = 0;
    virtual ScriptLoader* scriptLoader() { return nullptr; }
    /// A bridge call (M1d plan, Task 4): TelegramWidget's methods and the window members routed through it, as the method
    /// name and its arguments as a JSON array of strings. Synchronous, on the widget's queue, inside a step. Since V2a
    /// the runtime has applied SDK v1's policy (the URL rules, one link per press, the haptic bucket) before a call gets
    /// here; the host opens or plays what arrives, a link only after the user confirms. It must not throw. The default
    /// drops everything.
    virtual void bridgeCall(std::string_view method, std::string_view argsJson) {}
    /// SDK v1 §2.8 (V2a plan, Task 2): the stored area ("local" or "session") the widget starts with, read once,
    /// synchronously, the first time the widget touches it. Empty by default.
    virtual std::vector<std::pair<std::string, std::string>> storageArea(std::string_view area) { return {}; }
    /// SDK v1 §2.8: the whole area, in insertion order, after a task in which it changed. The client keeps it.
    virtual void storageCommit(std::string_view area, const std::vector<std::pair<std::string, std::string>>& entries) {}
    /// Web Crypto (V5a plan, Task 1): `count` cryptographically random bytes into `out`. The default is the system's
    /// (arc4random_buf). It must not throw.
    virtual void randomBytes(uint8_t* out, size_t count) { arc4random_buf(out, count); }
    /// widget-sandbox's `intl` capability: a request as its shim sends one (`{"kind":…,"locale":…,"opts":{…},…}`,
    /// Sources/Host/Intl.h) and the answer as its glue gives it: the formatted text, or JSON for the parts and options
    /// kinds. All of Intl's locale data comes from here; the app's is widget-sandbox's iOS glue, Foundation's
    /// formatters. Synchronous, on the widget's queue, inside a step. It must not throw. The default has no locale data
    /// and answers "".
    virtual std::string intl(std::string_view requestJson) { return {}; }
};

} // namespace wr
