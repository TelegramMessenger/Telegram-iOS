#include "Sources/Host/TelegramWidget.h"

#include "Sources/Host/Inert.h"
#include "Sources/Host/Links.h"

#include <string>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Work.h"

namespace wr {

void postBridgeCall(JSContext* ctx, std::string_view method, std::initializer_list<const String*> args) {
    Value array = Value::adopt(ctx, JS_NewArray(ctx));
    if (JS_IsException(array.get())) {
        throw Thrown{};
    }
    uint32_t index = 0;
    for (const String* arg : args) {
        chargeScan(ctx, arg->length());
        if (JS_SetPropertyUint32(ctx, array.get(), index++, JS_DupValue(ctx, arg->value())) < 0) {
            throw Thrown{};
        }
    }
    Value json = Value::adopt(ctx, JS_JSONStringify(ctx, array.get(), JS_UNDEFINED, JS_UNDEFINED));
    if (JS_IsException(json.get())) {
        throw Thrown{};
    }
    String text = String::adopt(ctx, JS_DupValue(ctx, json.get()));
    HostState::of(ctx).bridgeCall(ctx, method, text.utf8());
}

// TelegramWidget

TelegramWidget::TelegramWidget(JSContext* ctx)
    : m_themeChanged(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_activated(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_deactivated(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))), m_onTheme(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))) {}

namespace {

std::optional<TelegramWidget::Event> eventNamed(JSContext* ctx, const std::optional<Value>& type) {
    if (!type || !JS_IsString(type->get())) {
        return std::nullopt;
    }
    const String name = String::adopt(ctx, JS_DupValue(ctx, type->get()));
    if (name.equalsASCII("themeChanged")) {
        return TelegramWidget::Event::ThemeChanged;
    }
    if (name.equalsASCII("activated")) {
        return TelegramWidget::Event::Activated;
    }
    if (name.equalsASCII("deactivated")) {
        return TelegramWidget::Event::Deactivated;
    }
    return std::nullopt;
}

} // namespace

bool TelegramWidget::isProfileAtLeast(JSContext*, std::optional<Value> n) {
    if (!n || !JS_IsNumber(n->get())) {
        return false;
    }
    double value = 0;
    JS_ToFloat64(nullptr, &value, n->get());
    return double(kWidgetProfile) >= value;
}

String TelegramWidget::colorScheme(JSContext* ctx) {
    return String::fromUTF8(ctx, HostState::of(ctx).theme() == Theme::Dark ? "dark" : "light");
}

Value TelegramWidget::themeParams(JSContext* ctx) {
    const HostState& state = HostState::of(ctx);
    if (m_themeParams.isUndefined() || m_themeParamsGeneration != state.themeGeneration()) {
        charge(ctx, work::kNodeVisit * kThemeKeyCount);
        Value object = Value::adopt(ctx, JS_NewObject(ctx));
        if (JS_IsException(object.get())) {
            throw Thrown{};
        }
        const ThemeParams& params = state.themeParams();
        for (size_t i = 0; i < kThemeKeyCount; i++) {
            const std::string key(kThemeKeys[i]);
            JSValue value = JS_NewStringLen(ctx, params[i].data(), params[i].size());
            if (JS_IsException(value) || JS_SetPropertyStr(ctx, object.get(), key.c_str(), value) < 0) {
                throw Thrown{};
            }
        }
        if (JS_FreezeObject(ctx, object.get()) < 0) {
            throw Thrown{};
        }
        m_themeParams.set(JS_GetRuntime(ctx), JS_DupValue(ctx, object.get()));
        m_themeParamsGeneration = state.themeGeneration();
    }
    return Value::dup(ctx, m_themeParams.value);
}

bool TelegramWidget::isActive(JSContext* ctx) {
    return !DOMState::of(ctx).document().isHidden();
}

Vector<HeldCallback>& TelegramWidget::handlersOf(Event event) {
    switch (event) {
    case Event::ThemeChanged:
        return m_themeChanged;
    case Event::Activated:
        return m_activated;
    case Event::Deactivated:
        return m_deactivated;
    }
    return m_themeChanged;
}

namespace {

void append(JSContext* ctx, Vector<HeldCallback>& list, JSValueConst callback) {
    HeldCallback held;
    held.set(JS_GetRuntime(ctx), JS_DupValue(ctx, callback));
    list.push_back(std::move(held));
}

} // namespace

void TelegramWidget::onEvent(JSContext* ctx, std::optional<Value> type, std::optional<Value> handler) {
    const std::optional<Event> event = eventNamed(ctx, type);
    if (!event || !handler || !JS_IsFunction(ctx, handler->get())) {
        return;
    }
    Vector<HeldCallback>& handlers = this->handlersOf(*event);
    charge(ctx, work::kNodeVisit * uint64_t(handlers.size() + 1));
    if (handlers.size() >= kMaxHandlersPerEvent) {
        return;
    }
    for (const HeldCallback& held : handlers) {
        if (JS_IsStrictEqual(ctx, held.get(), handler->get())) {
            return;
        }
    }
    append(ctx, handlers, handler->get());
}

void TelegramWidget::offEvent(JSContext* ctx, std::optional<Value> type, std::optional<Value> handler) {
    const std::optional<Event> event = eventNamed(ctx, type);
    if (!event || !handler) {
        return;
    }
    Vector<HeldCallback>& handlers = this->handlersOf(*event);
    charge(ctx, work::kNodeVisit * uint64_t(handlers.size() + 1));
    for (size_t i = 0; i < handlers.size(); i++) {
        if (JS_IsStrictEqual(ctx, handlers[i].get(), handler->get())) {
            handlers[i].clear(JS_GetRuntime(ctx));
            handlers.erase(handlers.begin() + ptrdiff_t(i));
            return;
        }
    }
}

void TelegramWidget::openLink(JSContext* ctx, std::optional<Value> url) {
    openLinkFromWidget(ctx, LinkMethod::OpenLink, url);
}

void TelegramWidget::openTelegramLink(JSContext* ctx, std::optional<Value> url) {
    openLinkFromWidget(ctx, LinkMethod::OpenTelegramLink, url);
}

void TelegramWidget::ready(JSContext* ctx) {
    postBridgeCall(ctx, "ready", {});
}

void TelegramWidget::onTheme(JSContext* ctx, Callback callback) {
    if (m_onTheme.size() >= kMaxHandlersPerEvent) {
        return;
    }
    append(ctx, m_onTheme, callback.get());
    // At once (SDK v1 §2.1), with the current colour scheme.
    Value scheme = Value::adopt(ctx, this->colorScheme(ctx).toJS(ctx));
    JSValueConst argv[] = {scheme.get()};
    invokeWithReport(ctx, callback.get(), JS_UNDEFINED, 1, argv);
}

void TelegramWidget::runEvent(JSContext* ctx, Event event) {
    // A handler may add or remove others: call through copies, made (and charged) first.
    const Vector<HeldCallback>& handlers = this->handlersOf(event);
    const bool withTheme = event == Event::ThemeChanged;
    charge(ctx, work::kNodeVisit * uint64_t(handlers.size() + (withTheme ? m_onTheme.size() : 0)));
    Vector<Value> calls{JSAllocator<Value>(JS_GetRuntime(ctx))};
    for (const HeldCallback& held : handlers) {
        calls.push_back(Value::dup(ctx, held.get()));
    }
    Vector<Value> themeCalls{JSAllocator<Value>(JS_GetRuntime(ctx))};
    if (withTheme) {
        for (const HeldCallback& held : m_onTheme) {
            themeCalls.push_back(Value::dup(ctx, held.get()));
        }
    }
    for (const Value& fn : calls) {
        invokeWithReport(ctx, fn.get(), this->object(), 0, nullptr);
    }
    Value scheme = Value::adopt(ctx, this->colorScheme(ctx).toJS(ctx));
    for (const Value& fn : themeCalls) {
        JSValueConst argv[] = {scheme.get()};
        invokeWithReport(ctx, fn.get(), JS_UNDEFINED, 1, argv);
    }
}

wr::HapticFeedback* TelegramWidget::HapticFeedback(JSContext* ctx) {
    if (m_hapticFeedback.isUndefined()) {
        m_hapticFeedback.set(JS_GetRuntime(ctx), create<wr::HapticFeedback>(ctx, idl::kHapticFeedback).release());
    }
    return static_cast<wr::HapticFeedback*>(payloadOfKnown(m_hapticFeedback.value));
}

namespace {

constexpr std::string_view kImpactStyles[] = {"light", "medium", "heavy", "rigid", "soft"};
constexpr std::string_view kNotificationTypes[] = {"error", "success", "warning"};

/// `value` when it is a string of `list` (HAPTIC_IMPACT_STYLES, HAPTIC_NOTIFICATION_TYPES), else nullopt.
template <size_t N>
std::optional<String> listed(JSContext* ctx, const std::optional<Value>& value, const std::string_view (&list)[N]) {
    if (!value || !JS_IsString(value->get())) {
        return std::nullopt;
    }
    String text = String::adopt(ctx, JS_DupValue(ctx, value->get()));
    for (std::string_view name : list) {
        if (text.equalsASCII(name)) {
            return text;
        }
    }
    return std::nullopt;
}

void postHaptic(JSContext* ctx, std::string_view kind, const String* value) {
    if (!HostState::of(ctx).admitHaptic(ctx)) {
        return;
    }
    const String name = String::fromUTF8(ctx, kind);
    if (value) {
        postBridgeCall(ctx, "haptic", {&name, value});
    } else {
        postBridgeCall(ctx, "haptic", {&name});
    }
}

} // namespace

HapticFeedback* HapticFeedback::impactOccurred(JSContext* ctx, std::optional<Value> style) {
    const std::optional<String> checked = listed(ctx, style, kImpactStyles);
    if (!checked) {
        throw TypeError{"HapticFeedback.impactOccurred: style must be one of light, medium, heavy, rigid, soft"};
    }
    postHaptic(ctx, "impact", &*checked);
    return this;
}

HapticFeedback* HapticFeedback::notificationOccurred(JSContext* ctx, std::optional<Value> type) {
    const std::optional<String> checked = listed(ctx, type, kNotificationTypes);
    if (!checked) {
        throw TypeError{"HapticFeedback.notificationOccurred: type must be one of error, success, warning"};
    }
    postHaptic(ctx, "notification", &*checked);
    return this;
}

HapticFeedback* HapticFeedback::selectionChanged(JSContext* ctx) {
    postHaptic(ctx, "selection", nullptr);
    return this;
}

void TelegramWidget::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    for (const Vector<HeldCallback>* handlers : {&m_themeChanged, &m_activated, &m_deactivated, &m_onTheme}) {
        for (const HeldCallback& held : *handlers) {
            held.mark(rt, mark);
        }
    }
    m_themeParams.mark(rt, mark);
    m_hapticFeedback.mark(rt, mark);
}

void TelegramWidget::dispose(JSRuntime* rt) {
    for (Vector<HeldCallback>* handlers : {&m_themeChanged, &m_activated, &m_deactivated, &m_onTheme}) {
        for (HeldCallback& held : *handlers) {
            held.clear(rt);
        }
        handlers->clear();
    }
    m_themeParams.clear(rt);
    m_hapticFeedback.clear(rt);
}

Value Clipboard::writeText(JSContext* ctx, std::vector<Value>) {
    return rejectedWithDOMException(ctx, "NotAllowedError", "Widgets have no clipboard.");
}

Value Clipboard::readText(JSContext* ctx) {
    return rejectedWithDOMException(ctx, "NotAllowedError", "Widgets have no clipboard.");
}

Value Clipboard::write(JSContext* ctx, std::vector<Value>) {
    return rejectedWithDOMException(ctx, "NotAllowedError", "Widgets have no clipboard.");
}

Value Clipboard::read(JSContext* ctx) {
    return rejectedWithDOMException(ctx, "NotAllowedError", "Widgets have no clipboard.");
}

String Navigator::language(JSContext* ctx) {
    return String::fromUTF8(ctx, HostState::of(ctx).locale());
}

Value Navigator::languages(JSContext* ctx) {
    // A fresh frozen [language] on every read, as the reference's (its FrozenArray is not cached either).
    Value array = Value::adopt(ctx, JS_NewArray(ctx));
    if (JS_IsException(array.get()) || JS_SetPropertyUint32(ctx, array.get(), 0, this->language(ctx).toJS(ctx)) < 0 ||
        JS_FreezeObject(ctx, array.get()) < 0) {
        throw Thrown{};
    }
    return array;
}

bool Navigator::sendBeacon(JSContext*, std::vector<Value>) {
    throwNetworkDisabled();
}

Value Navigator::share(JSContext* ctx, std::vector<Value>) {
    return rejectedWithDOMException(ctx, "NotAllowedError", "Widgets cannot share.");
}

Clipboard* Navigator::clipboard(JSContext* ctx) {
    if (m_clipboard.isUndefined()) {
        m_clipboard.set(JS_GetRuntime(ctx), create<Clipboard>(ctx, idl::kClipboard).release());
    }
    return static_cast<Clipboard*>(payloadOfKnown(m_clipboard.value));
}

void Navigator::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_clipboard.mark(rt, mark);
}

void Navigator::dispose(JSRuntime* rt) {
    m_clipboard.clear(rt);
}

} // namespace wr
