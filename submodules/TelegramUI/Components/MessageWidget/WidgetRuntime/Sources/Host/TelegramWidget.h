// The bridge to the chat (M1d plan, Task 4): window.TelegramWidget, and Navigator's clipboard, which today's sandbox
// routes through the same bridge. A call is posted to the host (Host::bridgeCall) as its method name and its arguments
// as a JSON array of strings. The host sends the chat's theme (HostState::themeChanged) and visibility
// (HostState::setVisible) back in, each run as a task.
#pragma once

#include <optional>
#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/Host/Profile.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

/// SDK v1 §2.11 (sdk-policy.ts MAX_HANDLERS_PER_EVENT): onEvent keeps this many handlers per type; further ones are
/// ignored.
inline constexpr size_t kMaxHandlersPerEvent = 16;

/// SDK v1 §2.6 (sdk-policy.ts HAPTIC_BURST, HAPTIC_PER_SECOND, HAPTIC_REPORT_MS): a bucket of 5 haptics refilled at 10
/// per second; haptic-limit is reported at most once per second.
inline constexpr double kHapticBurst = 5;
inline constexpr double kHapticPerSecond = 10;
inline constexpr double kHapticReportMs = 1000;

/// SDK v1 §2.6 (V2a plan, Task 6): an unknown style or type is a TypeError; a call is posted as `haptic`
/// (["impact", style], ["notification", type], ["selection"]) when HostState::admitHaptic lets it through.
class HapticFeedback : public PlatformObject {
public:
    HapticFeedback() = default;
    HapticFeedback* impactOccurred(JSContext* ctx, std::optional<Value> style);
    HapticFeedback* notificationOccurred(JSContext* ctx, std::optional<Value> type);
    HapticFeedback* selectionChanged(JSContext* ctx);
};

/// SDK v1 §2.1 (V2a plan, Task 3).
class TelegramWidget : public PlatformObject {
public:
    explicit TelegramWidget(JSContext* ctx);

    int32_t profile(JSContext*) const { return profile::kVersion; }
    /// False for anything but a number.
    bool isProfileAtLeast(JSContext* ctx, std::optional<Value> n);
    String colorScheme(JSContext* ctx);
    /// SDK v1 §2.3: every key as lowercase #rrggbb (HostState::themeParams), frozen; the same object until a change.
    Value themeParams(JSContext* ctx);
    /// Deprecated alias of colorScheme.
    String theme(JSContext* ctx) { return this->colorScheme(ctx); }
    /// !document.hidden.
    bool isActive(JSContext* ctx);
    /// themeChanged, activated, deactivated; anything else, a non-function, a handler already added or one past the
    /// 16th is ignored.
    void onEvent(JSContext* ctx, std::optional<Value> type, std::optional<Value> handler);
    /// Removes the first handler of `type` that is `handler`.
    void offEvent(JSContext* ctx, std::optional<Value> type, std::optional<Value> handler);
    void openLink(JSContext* ctx, std::optional<Value> url);
    void openTelegramLink(JSContext* ctx, std::optional<Value> url);
    /// SDK v1 §2.12, §5.6 (widget-sandbox v0.1.3): which edge of the bubble stays put when the widget's height changes,
    /// kept for the host (HostState::resizeAnchor); exactly 'top' or 'bottom' (the SDK policy's checkResizeAnchor), else
    /// a TypeError. No tap needed, and nothing reaches the bridge: it is no action.
    void setResizeAnchor(JSContext* ctx, std::optional<Value> edge);
    wr::HapticFeedback* HapticFeedback(JSContext* ctx);
    void ready(JSContext* ctx);
    /// Deprecated alias of onEvent('themeChanged') whose callback gets the colour scheme, at once and on every change.
    /// Its callbacks are a list of their own (16, past which one is neither kept nor called), run after themeChanged's.
    void onTheme(JSContext* ctx, Callback callback);

    // Native, inside the tasks HostState queues.
    enum class Event { ThemeChanged, Activated, Deactivated };
    /// Runs the handlers of `event` in the order added, `this` the TelegramWidget and no arguments, then for
    /// ThemeChanged onTheme's callbacks with the colour scheme; each is reported on its own.
    void runEvent(JSContext* ctx, Event event);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Vector<HeldCallback>& handlersOf(Event event);
    Vector<HeldCallback> m_themeChanged;
    Vector<HeldCallback> m_activated;
    Vector<HeldCallback> m_deactivated;
    Vector<HeldCallback> m_onTheme;
    Held m_hapticFeedback;
    /// themeParams' object, made for HostState::themeGeneration m_themeParamsGeneration.
    Held m_themeParams;
    uint64_t m_themeParamsGeneration = 0;
};

class Clipboard : public PlatformObject {
public:
    Clipboard() = default;
    Value writeText(JSContext* ctx, std::vector<Value> arguments);
    Value readText(JSContext* ctx);
    Value write(JSContext* ctx, std::vector<Value> arguments);
    Value read(JSContext* ctx);
};

class Navigator : public PlatformObject {
public:
    Navigator() = default;
    Clipboard* clipboard(JSContext* ctx);
    String language(JSContext* ctx);
    Value languages(JSContext* ctx);
    /// SDK v1 §2.10: sendBeacon throws NetworkDisabledError; vibrate is false; share rejects with NotAllowedError and
    /// canShare is false.
    bool sendBeacon(JSContext* ctx, std::vector<Value> arguments);
    bool vibrate(JSContext*, std::vector<Value>) { return false; }
    Value share(JSContext* ctx, std::vector<Value> arguments);
    bool canShare(JSContext*, std::vector<Value>) { return false; }
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    Held m_clipboard;
};

/// Posts a bridge call: `method` with the strings in `args` as a JSON array (JSON.stringify's escaping).
void postBridgeCall(JSContext* ctx, std::string_view method, std::initializer_list<const String*> args);

} // namespace wr
