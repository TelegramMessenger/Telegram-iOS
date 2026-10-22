// The host layer's per-runtime state (ExtensionSlot::Host): the Window, its time origins and the event loop, whose
// microtask checkpoint is the runtime's cleanup hook and whose report is the runtime's report.
#pragma once

#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

#include "Sources/Events/Taps.h"
#include "Sources/Events/UserActions.h"
#include "Sources/Render/RenderHost.h"
#include "Sources/Events/ListenedTypes.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/EventHandlerAttributes.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/ThemeParams.h"
#include "Sources/Runtime/Runtime.h"

namespace wr {

class RenderTree;
class ScriptElements;
class Window;
namespace intl {
struct IntlState;
}
namespace canvas {
class CanvasState;
}
namespace animation {
class AnimationState;
}

class HostState : public RuntimeExtension {
public:
    /// Made by installHost, after createGlobal<Window>: the window is the global's payload, and the time origins are
    /// the host's clocks now.
    explicit HostState(JSContext* ctx);
    ~HostState() override;

    static HostState& of(JSContext* ctx) { return *static_cast<HostState*>(Runtime::from(ctx).extension(ExtensionSlot::Host)); }
    /// The host state, or nullptr before installHost (or when a test put another extension in the slot).
    static HostState* find(JSContext* ctx) { return dynamic_cast<HostState*>(Runtime::from(ctx).extension(ExtensionSlot::Host)); }

    Window& window() const { return *m_window; }
    /// The registry dispatch records into: the DOM state's.
    ListenedTypes& listenedTypes();
    /// HR-Time's time origin, on the host's monotonic clock: performance.now() and Event.timeStamp subtract it.
    double timeOrigin() const { return m_timeOrigin; }
    /// The same instant in milliseconds since the epoch: performance.timeOrigin.
    double wallTimeOrigin() const { return m_wallTimeOrigin; }
    EventLoop& loop() { return m_loop; }
    /// The event handler content attributes' change steps on the main document, and the handler names as atoms.
    EventHandlerAttributes& eventHandlerAttributes() { return m_eventHandlerAttributes; }
    /// HTML's script processing model for the main document's scripts (Sources/Host/Scripts.h).
    ScriptElements& scripts() { return *m_scripts; }
    /// The host's page visibility: queues a task that runs HTML's "update the visibility state" (no change: nothing;
    /// else visibilitychange at the document, bubbling). The host's, as the loop's steps are: it never throws, and a
    /// stopped widget queues nothing. A task it cannot queue (the work limit, the memory limit) stops the widget.
    void setVisible(JSContext* ctx, bool visible);
    /// The host's pointer (M1d plan, Task 2): one phase of a tap at (x, y) in CSS px, hit-tested on the published layout
    /// and dispatched as a task (Sources/Events/Taps.h). The host's, as setVisible is: it never throws, and a stopped
    /// widget queues nothing.
    void pointer(JSContext* ctx, PointerPhase phase, double x, double y, int32_t pointerId, bool primary) {
        m_taps.pointer(ctx, phase, x, y, pointerId, primary);
    }
    /// SDK v1 §2.5, user activation (widget-sandbox v0.1.0 packages/core/src/host/user-activation.ts): each trusted
    /// pointer press (Taps, from its pointerdown to its click) is numbered, and its number is active while one of its
    /// pointer and mouse events dispatches (PressScope), and so in the microtask checkpoint after each of their
    /// listeners (the reference's settle drains the jobs inside the press's task, with its gesture); never in a timer, a
    /// frame, a touch event, or a job of a later task. consumeActivation answers true once per press, while it is active and the widget visible.
    uint64_t beginPress() { return ++m_lastPress; }
    struct PressScope {
        PressScope(HostState& state, uint64_t press) : state(state), saved(state.m_activePress) { state.m_activePress = press; }
        ~PressScope() { state.m_activePress = saved; }
        PressScope(const PressScope&) = delete;
        PressScope& operator=(const PressScope&) = delete;
        HostState& state;
        uint64_t saved;
    };
    bool consumeActivation(JSContext* ctx);
    /// SDK v1 §2.6, sdk-policy.ts HapticGate: true while the widget is visible and the bucket has a token (taken);
    /// otherwise the haptic is dropped, and haptic-limit reported unless it was in the last second. On the step's clock
    /// (EventLoop::currentTime).
    bool admitHaptic(JSContext* ctx);
    /// SDK v1 §2.9: the client's UI language, navigator.language. sdk-policy.ts checkLocale: a tag of at most 35
    /// characters shaped /^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$/; anything else (an empty one too) is en-US.
    void setLocale(std::string_view locale);
    const std::string& locale() const { return m_locale; }
    /// Intl's per-runtime state (Sources/Host/Intl.h).
    intl::IntlState& intl() { return *m_intl; }
    /// activation-blocked and navigation-blocked (Links.h), each posted to the host at most kMaxLinkDiagnostics times.
    void reportLinkDiagnostic(JSContext* ctx, std::string_view kind, const std::string& detail);
    /// The bridge (M1d plan, Task 4), from script: Host::bridgeCall, whose throw (a host bug) is dropped.
    void bridgeCall(JSContext* ctx, std::string_view method, std::string_view argsJson);
    /// The host's: the chat's colour scheme, with the palette last set (setThemeParams). SDK v1 §2.3: when the scheme or
    /// any completed colour changed, colorScheme, themeParams and the root's variables change at once (the render tree
    /// rebuilds at the next flush, RenderTree::setTheme) and a task fires themeChanged and the onTheme callbacks;
    /// otherwise nothing happens. Never throws.
    void themeChanged(JSContext* ctx, Theme theme);
    /// The host's: the chat's palette (ThemePalette, checked as checkThemeParams does) and its button tokens
    /// (checkButtonTokens; §2.4), with the scheme and the text tokens last set; the change rule as themeChanged's, a
    /// token counting as a colour. Never throws.
    void setThemeParams(JSContext* ctx, const ThemePalette& palette, const ThemeButtonTokens& tokens = {});
    /// The scheme, the palette, the button and the text tokens (checkTextTokens) at once (the iOS host's theme change):
    /// one change, one themeChanged, by the same rule, a text token counting as a colour (a text-size change alone is a
    /// theme change, §2.4). Never throws.
    void setTheme(JSContext* ctx, Theme theme, const ThemePalette& palette, const ThemeButtonTokens& tokens,
                  const ThemeTextTokens& text = {});
    /// The layout width (RenderTree::setWidth), and a task whose end runs the rendering update's steps (media changes,
    /// resize and intersection observations): a width change is told to an idle widget (the V3b review's I4). The
    /// host's, as themeChanged is: it never throws.
    void setWidth(JSContext* ctx, double width);
    /// The chat's theme as the host last reported it (installRender's options first).
    Theme theme() const { return m_theme; }
    /// TelegramWidget.themeParams' values: the palette completed for the scheme.
    const ThemeParams& themeParams() const { return m_themeParams; }
    /// The button tokens as checked, for the root's --tg-button-* variables.
    const ThemeButtonTokens& buttonTokens() const { return m_buttonTokens; }
    /// The text tokens as checked, for the root's --tg-text-* variables.
    const ThemeTextTokens& textTokens() const { return m_textTokens; }
    /// Counts the changes of themeParams, so TelegramWidget keeps one object between them.
    uint64_t themeGeneration() const { return m_themeGeneration; }
    /// The main document's focus, hover and active state (Sources/Events/UserActions.h), installed as its ElementState.
    UserActions& userActions() { return m_userActions; }
    void setInitialTheme(Theme theme) {
        m_theme = theme;
        m_themeParams = completeThemeParams(m_palette, theme);
    }
    /// The same, with the host's first palette, button and text tokens (before installRender, so the first build has
    /// them).
    void setInitialTheme(Theme theme, ThemePalette palette, const ThemeButtonTokens& tokens, const ThemeTextTokens& text = {}) {
        m_palette = std::move(palette);
        m_buttonTokens = checkButtonTokens(tokens);
        m_textTokens = checkTextTokens(text);
        this->setInitialTheme(theme);
    }
    /// The canvases' state (V5d plan, Task 3), made by CanvasState::of on first use.
    std::unique_ptr<canvas::CanvasState>& canvasSlot() { return m_canvas; }
    /// The Web Animations state (V5e plan), made by AnimationState::of on first use.
    std::unique_ptr<animation::AnimationState>& animationSlot() { return m_animations; }
    /// The main document's render tree (M1c, Task 6), or nullptr when none was installed (installRender).
    RenderTree* render() const { return m_render.get(); }
    /// Owns `render` from now on, destroying any tree before it. installRender's.
    void setRender(std::unique_ptr<RenderTree> render);
    /// The host's flush (Ruling 13), for a host-initiated call that may have changed the DOM outside a step (M1d):
    /// RenderTree::flush. A step boundary: it never throws, and a stop inside it is latched (Runtime::stopReason()).
    /// Nothing without a tree, when it is clean, or once the widget has stopped.
    void flushRender(JSContext* ctx);

    /// HTML "clean up after running script": the microtask checkpoint, when the outermost callback returned.
    void afterOutermostScript(JSContext* ctx) override { m_loop.performMicrotaskCheckpoint(ctx); }
    /// Runtime::runScript and callFunction's callers report through here: an ErrorEvent at the window.
    void reportException(JSContext* ctx, JSValue exception) override { reportTheException(ctx, exception); }
    /// Ruling 6: the outermost native frame was left normally; the scripts mutations inserted, filled or gave a src are
    /// prepared now.
    void afterOutermostNative(JSContext* ctx) override;

private:
    /// themeChanged and setThemeParams.
    void applyTheme(JSContext* ctx, Theme theme, ThemePalette palette, ThemeButtonTokens tokens, ThemeTextTokens text);

    JSContext* m_ctx;
    /// Not counted: the window is the global object, alive for the context's life.
    Window* m_window;
    double m_timeOrigin;
    double m_wallTimeOrigin;
    /// The tap under way. Before the loop, so destroyed after it: a queued phase's task points at it.
    TapState m_taps;
    Theme m_theme = Theme::Light;
    ThemePalette m_palette;
    ThemeButtonTokens m_buttonTokens;
    ThemeTextTokens m_textTokens;
    ThemeParams m_themeParams = completeThemeParams({}, Theme::Light);
    uint64_t m_themeGeneration = 0;
    uint64_t m_lastPress = 0;
    uint64_t m_activePress = 0;
    uint64_t m_consumedPress = 0;
    uint32_t m_activationBlockedReports = 0;
    uint32_t m_navigationBlockedReports = 0;
    std::string m_locale = "en-US";
    std::unique_ptr<intl::IntlState> m_intl;
    double m_hapticTokens = 5;
    std::optional<double> m_hapticLast;
    std::optional<double> m_hapticReported;
    UserActions m_userActions;
    /// Its construction needs only the context, and a queued task's destruction needs none of the members above.
    /// Destroyed with the host state, before the context, so what a task captured is released while it is alive.
    EventLoop m_loop;
    /// After the loop: it unregisters from the DOM state before the loop's tasks are destroyed (neither depends on the
    /// other). It registers with the DOM state, which installDOM made.
    EventHandlerAttributes m_eventHandlerAttributes;
    /// After the loop, so destroyed before it: it unregisters from the main document, which it holds, and a script it
    /// still holds may be in a task m_loop owns. Made at the end of the constructor, when the main document is known.
    std::unique_ptr<ScriptElements> m_scripts;
    /// After the loop and the DOM state's other listeners: it unregisters from the DOM state when it goes; the bitmaps
    /// it allocated are self-contained and may outlive it.
    std::unique_ptr<canvas::CanvasState> m_canvas;
    /// After the loop, so destroyed before it; before the render tree, so destroyed after it (the tree reads the
    /// animated styles it hands out while it goes).
    std::unique_ptr<animation::AnimationState> m_animations;
    /// Last, so destroyed first (Global Constraints, "Payload rules"): it unregisters from the main document and
    /// releases the nodes it maps and journals while the document and the context are alive (Runtime::~Runtime resets
    /// this extension before the DOM's). Set by installRender, before the boot.
    std::unique_ptr<RenderTree> m_render;
};

/// Makes the global object the Window: its payload (createGlobal), Window.prototype and Window's members on the global
/// (installGlobalMembers, where QuickJS's own performance and queueMicrotask give way), `console`, and the host state
/// with its event loop.
/// Call after installDOM, and before parsing into the document, so parsed `on*` attributes find the host state.
HostState& installHost(JSContext* ctx);

} // namespace wr
