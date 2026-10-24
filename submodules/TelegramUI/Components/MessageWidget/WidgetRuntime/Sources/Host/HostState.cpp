#include "Sources/Host/HostState.h"
#include "Sources/Support/Work.h"
#include "Sources/Host/TelegramWidget.h"

#include <algorithm>
#include <new>
#include <stdexcept>

#include "Generated/Bindings.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Canvas/CanvasState.h"
#include "Sources/Canvas/ImageElement.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Events/Dispatch.h"
#include "Sources/Host/CSSNamespace.h"
#include "Sources/Host/Console.h"
#include "Sources/Host/Intl.h"
#include "Sources/Host/Links.h"
#include "Sources/Host/Scripts.h"
#include "Sources/Host/Task.h"
#include "Sources/Host/Window.h"
#include "Sources/Render/RenderTree.h"

namespace wr {

namespace {

Window& globalWindow(JSContext* ctx) {
    Value global = Value::adopt(ctx, JS_GetGlobalObject(ctx));
    PlatformObject* payload = payloadImplementing(ctx, global.get(), idl::kWindow);
    if (!payload) {
        throw std::logic_error("HostState: the global object has no Window payload (createGlobal<Window> first)");
    }
    return *static_cast<Window*>(payload);
}

} // namespace

HostState::HostState(JSContext* ctx)
    : m_ctx(ctx), m_window(&globalWindow(ctx)), m_timeOrigin(Runtime::from(ctx).host().monotonicNow()),
      m_wallTimeOrigin(Runtime::from(ctx).host().wallClockNow()), m_loop(ctx), m_eventHandlerAttributes(ctx) {
    m_intl = std::make_unique<intl::IntlState>(JS_GetRuntime(ctx));
    // HTML: a document's visibility state starts "hidden"; the main document is the one the host shows.
    DOMState::of(ctx).document().setHidden(false);
    m_scripts = std::make_unique<ScriptElements>(ctx, DOMState::of(ctx).document());
    DOMState::of(ctx).setElementState(&m_userActions);
}

HostState::~HostState() {
    // The DOM state outlives the host state (Runtime::~Runtime): it must not keep answering through this one.
    if (DOMState* state = DOMState::find(m_ctx)) {
        state->setElementState(nullptr);
    }
    m_userActions.clear();
}

// Ruling 6: the outermost native frame was left, so no native algorithm is running; the scripts mutations inserted,
// filled or gave a src are prepared now.
void HostState::afterOutermostNative(JSContext* ctx) {
    m_scripts->preparePending(ctx);
}

void HostState::setVisible(JSContext* ctx, bool visible) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    try {
        // HTML "Page visibility": a global task on the user interaction task source.
        m_loop.queueTask(TaskSource::UserInteraction, makeTask(ctx, [visible](JSContext* ctx) {
            // HTML "update the visibility state". What escapes is the task runner's to handle (runNextTask's guard).
            Document& document = DOMState::of(ctx).document();
            if (document.isHidden() == !visible) {
                return;
            }
            document.setHidden(!visible);
            Atom type = Atom::fromUTF8(ctx, "visibilitychange");
            fireEvent(ctx, document, type.get(), true, false);
            // SDK v1 §2.7: isActive and activated / deactivated follow, after visibilitychange.
            HostState::of(ctx).window().TelegramWidget(ctx)->runEvent(
                ctx, visible ? TelegramWidget::Event::Activated : TelegramWidget::Event::Deactivated);
        }));
    } catch (...) {
        // Not to the host: the failure latches the stop (a charge the budget refused: Budget; out of memory: Memory).
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::bridgeCall(JSContext* ctx, std::string_view method, std::string_view argsJson) {
    try {
        Runtime::from(ctx).host().bridgeCall(method, argsJson);
    } catch (...) {
    }
}

bool HostState::consumeActivation(JSContext* ctx) {
    if (m_activePress == 0 || DOMState::of(ctx).document().isHidden() ||
        std::find(m_consumedPresses.begin(), m_consumedPresses.end(), m_activePress) != m_consumedPresses.end()) {
        return false;
    }
    m_consumedPresses.push_back(m_activePress);
    return true;
}

void HostState::endPress(uint64_t press) {
    m_consumedPresses.erase(std::remove(m_consumedPresses.begin(), m_consumedPresses.end(), press), m_consumedPresses.end());
}

namespace {

/// MAX_LOCALE_LENGTH.
constexpr size_t kMaxLocaleLength = 35;

bool isASCIIAlpha(char c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

/// checkLocale's shape: a 2–8 letter language, then subtags of 1–8 letters or digits.
bool isLocaleTag(std::string_view tag) {
    if (tag.empty() || tag.size() > kMaxLocaleLength) {
        return false;
    }
    size_t start = 0;
    for (bool first = true;; first = false) {
        const size_t dash = tag.find('-', start);
        const std::string_view part = tag.substr(start, dash == std::string_view::npos ? std::string_view::npos : dash - start);
        if (part.size() < (first ? 2 : 1) || part.size() > 8) {
            return false;
        }
        for (char c : part) {
            if (!isASCIIAlpha(c) && (first || c < '0' || c > '9')) {
                return false;
            }
        }
        if (dash == std::string_view::npos) {
            return true;
        }
        start = dash + 1;
    }
}

} // namespace

void HostState::setLocale(std::string_view locale) {
    m_locale = isLocaleTag(locale) ? std::string(locale) : std::string("en-US");
}

bool HostState::admitHaptic(JSContext* ctx) {
    // The step's time: a burst inside one task sees no refill however long it runs.
    const double now = m_loop.currentTime();
    if (m_hapticLast) {
        m_hapticTokens = std::min(kHapticBurst, m_hapticTokens + std::max(0.0, now - *m_hapticLast) * kHapticPerSecond / 1000);
    }
    m_hapticLast = now;
    const bool visible = !DOMState::of(ctx).document().isHidden();
    if (visible && m_hapticTokens >= 1) {
        m_hapticTokens -= 1;
        return true;
    }
    if (m_hapticReported && now - *m_hapticReported < kHapticReportMs) {
        return false;
    }
    m_hapticReported = now;
    Runtime::from(ctx).host().diagnostic("haptic-limit", visible ? "haptics over 5 per burst or 10 per second are dropped"
                                            : "haptics of a hidden widget are dropped");
    return false;
}

void HostState::reportLinkDiagnostic(JSContext* ctx, std::string_view kind, const std::string& detail) {
    uint32_t& reports = kind == "activation-blocked" ? m_activationBlockedReports : m_navigationBlockedReports;
    if (reports >= kMaxLinkDiagnostics) {
        return;
    }
    reports++;
    Runtime::from(ctx).host().diagnostic(kind, detail);
}

void HostState::themeChanged(JSContext* ctx, Theme theme) {
    this->applyTheme(ctx, theme, m_palette, m_buttonTokens, m_textTokens);
}

void HostState::setThemeParams(JSContext* ctx, const ThemePalette& palette, const ThemeButtonTokens& tokens) {
    this->applyTheme(ctx, m_theme, palette, checkButtonTokens(tokens), m_textTokens);
}

void HostState::setTheme(JSContext* ctx, Theme theme, const ThemePalette& palette, const ThemeButtonTokens& tokens,
                         const ThemeTextTokens& text) {
    this->applyTheme(ctx, theme, palette, checkButtonTokens(tokens), checkTextTokens(text));
}

void HostState::applyTheme(JSContext* ctx, Theme theme, ThemePalette palette, ThemeButtonTokens tokens, ThemeTextTokens text) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    ThemeParams params = completeThemeParams(palette, theme);
    m_palette = std::move(palette);
    if (theme == m_theme && params == m_themeParams && tokens == m_buttonTokens && text == m_textTokens) {
        return;
    }
    m_theme = theme;
    m_themeParams = std::move(params);
    m_buttonTokens = std::move(tokens);
    m_textTokens = std::move(text);
    m_themeGeneration++;
    try {
        if (m_render) {
            m_render->setTheme(ctx, theme, themeRootDeclarations(m_themeParams, theme, m_buttonTokens, m_textTokens));
        }
        m_loop.queueTask(TaskSource::UserInteraction, makeTask(ctx, [](JSContext* ctx) {
            HostState::of(ctx).window().TelegramWidget(ctx)->runEvent(ctx, TelegramWidget::Event::ThemeChanged);
        }));
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::setReducedMotion(JSContext* ctx, bool reduced) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    try {
        if (m_render) {
            m_render->setReducedMotion(ctx, reduced);
        }
        m_loop.queueTask(TaskSource::Rendering, makeTask(ctx, [](JSContext*) {}));
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::setWidth(JSContext* ctx, double width) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    try {
        if (m_render) {
            m_render->setWidth(ctx, width);
        }
        m_loop.queueTask(TaskSource::Rendering, makeTask(ctx, [](JSContext*) {}));
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::setRender(std::unique_ptr<RenderTree> render) {
    m_render = std::move(render);
}

void HostState::flushRender(JSContext* ctx) {
    if (!m_render || Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    // A host entry, as a step is: it may run on another thread than the one that made the runtime.
    JS_UpdateStackTop(JS_GetRuntime(ctx));
    try {
        m_render->flush(ctx);
    } catch (...) {
        // Latched already (the flush's build routes every failure through abortForCaughtException): not to the host.
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

ListenedTypes& HostState::listenedTypes() {
    return DOMState::of(m_ctx).listenedTypes();
}

HostState& installHost(JSContext* ctx) {
    Runtime& runtime = Runtime::from(ctx);
    // The payload goes on the existing global object (Task 4); it throws logic_error when the table has no [Global]
    // interface. installGlobalMembers then sets Window.prototype and defines Window's members, deleting QuickJS's own
    // performance and queueMicrotask by name.
    Window& window = createGlobal<Window>(ctx);
    runtime.installGlobalMembers(idl::kWindow);
    installConsole(ctx);
    runtime.setExtension(ExtensionSlot::Host, std::make_unique<HostState>(ctx));
    DOMState::of(ctx).setWindowTarget(&window);
    intl::installIntl(ctx);
    installCSSNamespace(ctx);
    installImageConstructor(ctx);
    return HostState::of(ctx);
}

} // namespace wr
