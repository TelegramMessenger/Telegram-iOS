#include "Sources/Host/HostState.h"
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
            if (visible) {
                // SDK v1 §2.14: the widget appeared on screen, so its next background request may go out at once; one
                // made while it was hidden is that request (widget-sandbox v0.3.0).
                HostState& host = HostState::of(ctx);
                if (host.m_requestGate.show(host.m_loop.currentTime())) {
                    host.window().TelegramWidget(ctx)->sendHeldRequest(ctx);
                }
            }
            Atom type = Atom::fromUTF8(ctx, "visibilitychange");
            fireEvent(ctx, document, type.get(), true, false);
            // SDK v1 §2.7: isActive and activated / deactivated follow, after visibilitychange.
            HostState::of(ctx).window().TelegramWidget(ctx)->runEvent(
                ctx, visible ? TelegramWidget::Event::Activated : TelegramWidget::Event::Deactivated);
        }), TaskKind::Visibility);
    } catch (...) {
        // Not to the host: the failure latches the stop (out of memory: Memory).
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

bool HostState::activationAvailable(JSContext* ctx) const {
    return m_activePress != 0 && !DOMState::of(ctx).document().isHidden() &&
           std::find(m_consumedPresses.begin(), m_consumedPresses.end(), m_activePress) == m_consumedPresses.end();
}

twidget::sdk::RequestVerdict HostState::decideRequest(JSContext* ctx, bool withWallet) {
    twidget::sdk::RequestGate::Conditions conditions;
    conditions.gesture = this->activationAvailable(ctx);
    conditions.visible = !DOMState::of(ctx).document().isHidden();
    conditions.canQuery = m_widgetContext.canQuery;
    conditions.backgroundQuery = m_widgetContext.backgroundQuery;
    conditions.withWallet = withWallet;
    conditions.wallet = m_widgetContext.wallet;
    return m_requestGate.decide(m_loop.currentTime(), conditions);
}

twidget::sdk::RequestVerdict HostState::decideWallet(JSContext* ctx) {
    twidget::sdk::RequestGate::WalletConditions conditions;
    conditions.gesture = this->activationAvailable(ctx);
    conditions.visible = !DOMState::of(ctx).document().isHidden();
    conditions.canQuery = m_widgetContext.canQuery;
    conditions.wallet = m_widgetContext.wallet;
    return m_requestGate.decideWallet(m_loop.currentTime(), conditions);
}

int64_t HostState::nextRequestId() {
    m_lastRequestId = m_lastRequestId >= twidget::sdk::MAX_REQUEST_ID ? 1 : m_lastRequestId + 1;
    return m_lastRequestId;
}

void HostState::completeRequest(JSContext* ctx, int64_t id, const twidget::WidgetRequestOutcome& outcome) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    try {
        m_loop.queueTask(TaskSource::UserInteraction, makeTask(ctx, [id, outcome](JSContext* ctx) {
            HostState::of(ctx).window().TelegramWidget(ctx)->settleRequest(ctx, id, outcome);
        }), TaskKind::Bridge);
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::queueRequestRefusal(JSContext* ctx, int64_t id, const std::string& code, const std::string& reason) {
    // From inside a binding: a failure to queue is the binding's (a memory stop), thrown through.
    m_loop.queueTask(TaskSource::UserInteraction, makeTask(ctx, [id, code, reason](JSContext* ctx) {
        HostState::of(ctx).window().TelegramWidget(ctx)->refuseRequest(ctx, id, code, reason);
    }), TaskKind::Bridge);
}

void HostState::reportCapped(JSContext* ctx, std::string_view kind, const std::string& detail) {
    uint32_t& reports = kind == "preview-blocked" ? m_previewBlockedReports : m_requestBlockedReports;
    if (reports >= uint32_t(twidget::sdk::MAX_REJECTION_REPORTS)) {
        return;
    }
    reports++;
    Runtime::from(ctx).host().diagnostic(kind, detail);
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

void HostState::setContext(JSContext* ctx, const twidget::WidgetContext& context) {
    // WidgetContext.effective: a preview's flags are ignored. Whatever the widget knows can reach the bot in a request:
    // no copy tells where it was forwarded, and the widget knows its viewer only where it may send requests.
    WidgetContextState state;
    state.preview = context.preview;
    state.isForward = !context.preview && context.isCopy;
    state.canQuery = !context.preview && context.canQuery;
    state.backgroundQuery = !context.preview && context.backgroundQuery;
    state.wallet = state.canQuery && context.wallet;
    if (!state.preview && !state.isForward) {
        state.chatType = twidget::sdk::checkChatType(context.chatType);
    }
    if (state.canQuery) {
        twidget::sdk::CheckedViewer checked = twidget::sdk::checkViewer(context.viewer);
        for (const std::string& field : checked.rejected) {
            Runtime::from(ctx).host().diagnostic("data-rejected", "viewer." + field + ": " + std::string(twidget::sdk::viewerFieldRule(field)) +
                                                                      "; the widget does not see it");
        }
        state.viewer = std::move(checked.viewer);
    }
    m_widgetContext = std::move(state);
    m_contextGeneration++;
}

twidget::sdk::CheckedWidgetData HostState::checkedData(JSContext* ctx, const twidget::WidgetData& data) {
    twidget::sdk::CheckedWidgetData checked = twidget::sdk::checkWidgetData(data, m_widgetContext.isForward);
    if (!checked.rejected.empty()) {
        std::string fields;
        for (const std::string& field : checked.rejected) {
            fields += (fields.empty() ? "" : " and ") + field;
        }
        Runtime::from(ctx).host().diagnostic("data-rejected", fields + ": not text of at most " + std::to_string(twidget::sdk::MAX_WIDGET_DATA_BYTES) +
                                                                  " bytes (UTF-8, no NUL); the widget sees null");
    }
    return checked;
}

void HostState::setInitialData(JSContext* ctx, const twidget::WidgetData& data) {
    twidget::sdk::CheckedWidgetData checked = this->checkedData(ctx, data);
    m_chatData = std::move(checked.chatData);
    m_publicData = std::move(checked.publicData);
}

void HostState::setData(JSContext* ctx, const twidget::WidgetData& data) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    twidget::sdk::CheckedWidgetData checked = this->checkedData(ctx, data);
    try {
        if (m_holdingInputs) {
            m_heldInputs.emplace_back(std::move(checked));
            return;
        }
        this->queueData(ctx, std::move(checked));
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::setInitialContentSafeArea(JSContext* ctx, const ContentSafeArea& area) {
    m_contentSafeArea = checkContentSafeArea(area);
    m_sdkContentSafeArea = m_contentSafeArea;
    m_contentSafeAreaGeneration++;
    if (m_render) {
        m_render->setContentSafeArea(ctx, contentSafeAreaRootDeclarations(m_contentSafeArea));
    }
}

void HostState::setContentSafeArea(JSContext* ctx, const ContentSafeArea& area) {
    const ContentSafeArea checked = checkContentSafeArea(area);
    if (Runtime::from(ctx).stopReason() != StopReason::None || checked == m_contentSafeArea) {
        return;
    }
    try {
        m_contentSafeArea = checked;
        if (m_render) {
            m_render->setContentSafeArea(ctx, contentSafeAreaRootDeclarations(m_contentSafeArea));
        }
        // The band changes the layout now (the bubble's size follows at once), as a width change does.
        m_loop.flushForHostChange(TaskKind::SafeArea);
        if (m_holdingInputs) {
            m_heldInputs.emplace_back(checked);
            return;
        }
        this->queueContentSafeArea(ctx, checked);
    } catch (...) {
        try {
            abortForCaughtException(ctx);
        } catch (const Aborted&) {
        }
    }
}

void HostState::queueContentSafeArea(JSContext* ctx, const ContentSafeArea& area) {
    // The shim's safeArea dispatch (sdk-v1 §3): a fresh object for script, then the event, in one task; nothing when
    // script already has these numbers (a change and its reversal queued together).
    m_loop.queueTask(TaskSource::Rendering, makeTask(ctx, [area](JSContext* ctx) {
        HostState& host = HostState::of(ctx);
        if (area == host.m_sdkContentSafeArea) {
            return;
        }
        host.m_sdkContentSafeArea = area;
        host.m_contentSafeAreaGeneration++;
        host.window().TelegramWidget(ctx)->runEvent(ctx, TelegramWidget::Event::ContentSafeAreaChanged);
    }), TaskKind::SafeArea);
}

void HostState::queueData(JSContext* ctx, twidget::sdk::CheckedWidgetData checked) {
    // The bridge task of upstream's shim (sdk-v1 §3.3): the values change, then the events fire, in one task.
    m_loop.queueTask(TaskSource::UserInteraction, makeTask(ctx, [chatData = std::move(checked.chatData), publicData = std::move(checked.publicData)](JSContext* ctx) {
        HostState& host = HostState::of(ctx);
        const bool chatChanged = chatData != host.m_chatData;
        const bool publicChanged = publicData != host.m_publicData;
        host.m_chatData = chatData;
        host.m_publicData = publicData;
        TelegramWidget* widget = host.window().TelegramWidget(ctx);
        if (chatChanged) {
            widget->runEvent(ctx, TelegramWidget::Event::ChatDataChanged);
        }
        if (publicChanged) {
            widget->runEvent(ctx, TelegramWidget::Event::PublicDataChanged);
        }
    }), TaskKind::Bridge);
}

void HostState::releaseHeldInputs(JSContext* ctx) {
    m_holdingInputs = false;
    std::vector<std::variant<twidget::sdk::CheckedWidgetData, ContentSafeArea>> held = std::move(m_heldInputs);
    m_heldInputs.clear();
    for (auto& input : held) {
        if (auto* data = std::get_if<twidget::sdk::CheckedWidgetData>(&input)) {
            this->queueData(ctx, std::move(*data));
        } else {
            this->queueContentSafeArea(ctx, std::get<ContentSafeArea>(input));
        }
    }
}

bool HostState::admitHaptic(JSContext* ctx) {
    // The step's time: a burst inside one task sees no refill however long it runs.
    const bool visible = !DOMState::of(ctx).document().isHidden();
    switch (m_hapticGate.decide(m_loop.currentTime(), visible)) {
    case twidget::sdk::HapticGate::Decision::Play:
        return true;
    case twidget::sdk::HapticGate::Decision::Drop:
        return false;
    case twidget::sdk::HapticGate::Decision::Report:
        break;
    }
    Runtime::from(ctx).host().diagnostic("haptic-limit", visible ? "haptics over 5 per burst or 10 per second, or outside a touch after a 1 s series, are dropped"
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
        // The new theme lays out now; only the widget's own step (themeChanged, media changes) waits for the windows.
        m_loop.flushForHostChange(TaskKind::Theme);
        m_loop.queueTask(TaskSource::UserInteraction, makeTask(ctx, [](JSContext* ctx) {
            HostState::of(ctx).window().TelegramWidget(ctx)->runEvent(ctx, TelegramWidget::Event::ThemeChanged);
        }), TaskKind::Theme);
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
        m_loop.flushForHostChange(TaskKind::Viewport);
        m_loop.queueTask(TaskSource::Rendering, makeTask(ctx, [](JSContext*) {}), TaskKind::Viewport);
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
        // The new width lays out now (the bubble's size follows at once); only the widget's own step (its media
        // changes, ResizeObserver delivery) waits for the windows.
        m_loop.flushForHostChange(TaskKind::Resize);
        m_loop.queueTask(TaskSource::Rendering, makeTask(ctx, [](JSContext*) {}), TaskKind::Viewport);
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
