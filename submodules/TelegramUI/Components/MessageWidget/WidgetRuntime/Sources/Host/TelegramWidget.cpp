#include "Sources/Host/TelegramWidget.h"

#include "Sources/Host/Inert.h"
#include "Sources/Host/Links.h"

#include <string>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/ErrorReporting.h"
#include "Sources/Host/HostState.h"
#include "Sources/Host/WalletArguments.h"
#include "Sources/Host/Window.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "twidget/sdk_policy.h"

namespace wr {

void postBridgeCall(JSContext* ctx, std::string_view method, std::initializer_list<const String*> args) {
    // Every caller reports a preview's refusal itself (refusedInPreview); this is the floor under them.
    if (HostState::of(ctx).isPreview() && !twidget::sdk::allowedInPreview(method)) {
        return;
    }
    Value array = Value::adopt(ctx, JS_NewArray(ctx));
    if (JS_IsException(array.get())) {
        throw Thrown{};
    }
    uint32_t index = 0;
    for (const String* arg : args) {
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

void postBridgeCallJson(JSContext* ctx, std::string_view method, const twidget::Json& args) {
    if (HostState::of(ctx).isPreview() && !twidget::sdk::allowedInPreview(method)) {
        return;
    }
    HostState::of(ctx).bridgeCall(ctx, method, args.dump());
}

bool refusedInPreview(JSContext* ctx, std::string_view method) {
    HostState& host = HostState::of(ctx);
    if (!host.isPreview() || twidget::sdk::allowedInPreview(method)) {
        return false;
    }
    host.reportCapped(ctx, "preview-blocked", std::string(method) + " ignored: a preview (an inline result not sent yet) takes no actions");
    return true;
}

// TelegramWidget

TelegramWidget::TelegramWidget(JSContext* ctx)
    : m_requests(JSAllocator<PendingRequest>(JS_GetRuntime(ctx))), m_themeChanged(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_activated(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_deactivated(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_chatDataChanged(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_publicDataChanged(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))),
      m_contentSafeAreaChanged(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))), m_onTheme(JSAllocator<HeldCallback>(JS_GetRuntime(ctx))) {}

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
    if (name.equalsASCII("chatDataChanged")) {
        return TelegramWidget::Event::ChatDataChanged;
    }
    if (name.equalsASCII("publicDataChanged")) {
        return TelegramWidget::Event::PublicDataChanged;
    }
    if (name.equalsASCII("contentSafeAreaChanged")) {
        return TelegramWidget::Event::ContentSafeAreaChanged;
    }
    return std::nullopt;
}

std::optional<String> optionalString(JSContext* ctx, const std::optional<std::string>& text) {
    if (!text) {
        return std::nullopt;
    }
    return String::fromUTF8(ctx, *text);
}

} // namespace

bool TelegramWidget::isProfileAtLeast(JSContext*, std::optional<Value> n) {
    if (!n || !JS_IsNumber(n->get())) {
        return false;
    }
    double value = 0;
    JS_ToFloat64(nullptr, &value, n->get());
    return double(profile::kVersion) >= value;
}

String TelegramWidget::colorScheme(JSContext* ctx) {
    return String::fromUTF8(ctx, HostState::of(ctx).theme() == Theme::Dark ? "dark" : "light");
}

Value TelegramWidget::themeParams(JSContext* ctx) {
    const HostState& state = HostState::of(ctx);
    if (m_themeParams.isUndefined() || m_themeParamsGeneration != state.themeGeneration()) {
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

std::optional<String> TelegramWidget::chatData(JSContext* ctx) {
    return optionalString(ctx, HostState::of(ctx).chatData());
}

std::optional<String> TelegramWidget::publicData(JSContext* ctx) {
    return optionalString(ctx, HostState::of(ctx).publicData());
}

bool TelegramWidget::isForward(JSContext* ctx) {
    return HostState::of(ctx).widgetContext().isForward;
}

std::optional<String> TelegramWidget::chatType(JSContext* ctx) {
    return optionalString(ctx, HostState::of(ctx).widgetContext().chatType);
}

bool TelegramWidget::isPreview(JSContext* ctx) {
    return HostState::of(ctx).isPreview();
}

Value TelegramWidget::viewer(JSContext* ctx) {
    const HostState& state = HostState::of(ctx);
    const std::optional<twidget::WidgetViewer>& viewer = state.widgetContext().viewer;
    if (!viewer) {
        return Value::adopt(ctx, JS_NULL);
    }
    if (m_viewer.isUndefined() || m_viewerGeneration != state.contextGeneration()) {
        // The SDK policy's viewerJson in the widget's field names: id, then the names and username present, is_premium
        // only when true.
        Value object = Value::adopt(ctx, JS_NewObject(ctx));
        if (JS_IsException(object.get()) || JS_SetPropertyStr(ctx, object.get(), "id", JS_NewFloat64(ctx, double(viewer->id))) < 0) {
            throw Thrown{};
        }
        const std::pair<const char*, const std::optional<std::string>*> fields[] = {
            {"first_name", &viewer->firstName}, {"last_name", &viewer->lastName}, {"username", &viewer->username}};
        for (const auto& [key, value] : fields) {
            if (!*value) {
                continue;
            }
            JSValue text = String::fromUTF8(ctx, **value).toJS(ctx);
            if (JS_IsException(text) || JS_SetPropertyStr(ctx, object.get(), key, text) < 0) {
                throw Thrown{};
            }
        }
        if (viewer->isPremium && JS_SetPropertyStr(ctx, object.get(), "is_premium", JS_TRUE) < 0) {
            throw Thrown{};
        }
        if (JS_FreezeObject(ctx, object.get()) < 0) {
            throw Thrown{};
        }
        m_viewer.set(JS_GetRuntime(ctx), JS_DupValue(ctx, object.get()));
        m_viewerGeneration = state.contextGeneration();
    }
    return Value::dup(ctx, m_viewer.value);
}

namespace {

/// argv: the reject function, the code and the message. sdk-v1 §2.14: an Error whose name is WidgetRequestError and
/// whose `code` says why; made in the job, as queueRejectWithDOMException makes its exception, since making it can run
/// the widget's Error.prepareStackTrace. The shim's `new Error(message)`, then `name` and `code` set: the message is
/// the error's own, not enumerable, the other two are.
JSValue rejectWithRequestErrorJob(JSContext* ctx, int, JSValueConst* argv) {
    JSValue error = JS_NewError(ctx);
    if (JS_IsException(error)) {
        return JS_EXCEPTION;
    }
    if (JS_DefinePropertyValueStr(ctx, error, "message", JS_DupValue(ctx, argv[2]), JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE) < 0 ||
        JS_SetPropertyStr(ctx, error, "name", JS_NewString(ctx, "WidgetRequestError")) < 0 ||
        JS_SetPropertyStr(ctx, error, "code", JS_DupValue(ctx, argv[1])) < 0) {
        JS_FreeValue(ctx, error);
        return JS_EXCEPTION;
    }
    JSValue result = JS_Call(ctx, argv[0], JS_UNDEFINED, 1, &error);
    JS_FreeValue(ctx, error);
    return result;
}

void queueRejectWithRequestError(JSContext* ctx, PromiseSlot& slot, std::string_view code, const std::string& message) {
    if (slot.settled) {
        return;
    }
    Value codeValue = Value::adopt(ctx, JS_NewStringLen(ctx, code.data(), code.size()));
    Value messageValue = Value::adopt(ctx, JS_NewStringLen(ctx, message.data(), message.size()));
    if (JS_IsException(codeValue.get()) || JS_IsException(messageValue.get())) {
        throw Thrown{};
    }
    JSValueConst argv[3] = {slot.reject.value, codeValue.get(), messageValue.get()};
    if (JS_EnqueueJob(ctx, rejectWithRequestErrorJob, 3, argv) < 0) {
        throw Thrown{};
    }
    slot.settled = true;
}

/// Upstream's shim's words for a request's error (globals.ts, REQUEST_MESSAGES), by the refusal's reason or the code.
std::optional<std::string_view> requestErrorText(std::string_view key) {
    if (key == "preview") {
        return "a preview (an inline result not sent yet) cannot ask the bot";
    }
    if (key == "no-wallet") {
        return "the client has no wallet for this user (TelegramWidget.wallet is null)";
    }
    if (key == "disabled") {
        return "requests are off for this message (the bot did not allow them here)";
    }
    if (key == "no-activation") {
        return "it needs a tap on the widget and runs in that tap's handler, one call per tap; background requests only where the client allows them "
               "(the private chat with the bot)";
    }
    if (key == "unsupported") {
        return "this client does not deliver requests";
    }
    if (key == "BUSY") {
        return "a request is already in flight; wait for its answer";
    }
    if (key == "RATE_LIMITED") {
        return "too many requests (background requests at most once per 5 s); try again later";
    }
    if (key == "TIMEOUT") {
        return "the bot did not answer in time";
    }
    if (key == "FAILED") {
        return "the client could not deliver the request";
    }
    if (key == "INVALID_ANSWER") {
        return "the bot's answer broke the limits (a result over 1024 bytes, or not text)";
    }
    return std::nullopt;
}

/// Where a wallet call's words differ (globals.ts, WALLET_MESSAGES).
std::optional<std::string_view> walletErrorText(std::string_view key) {
    if (key == "no-activation") {
        return "it needs a tap on the widget and runs in that tap's handler (one call per tap), or follows within 10 s the answer to a call made by a tap";
    }
    if (key == "REJECTED") {
        return "the user declined in the wallet window";
    }
    if (key == "BAD_REQUEST") {
        return "the wallet refused it (the network, the sender, the expiry or the cells)";
    }
    if (key == "FAILED") {
        return "the client could not complete the call";
    }
    return std::nullopt;
}

/// The error's message as upstream's shim words it (globals.ts, requestError): the call's label, then the words for the
/// glue's reason when the code is NOT_ALLOWED and there is one, else for the code; a wallet call's own words first; the
/// request's `no-activation` words for anything else.
std::string requestErrorMessage(std::string_view label, std::string_view code, std::string_view reason) {
    const std::string_view key = code == "NOT_ALLOWED" && !reason.empty() ? reason : code;
    std::optional<std::string_view> text = label != "request" ? walletErrorText(key) : std::nullopt;
    if (!text) {
        text = requestErrorText(key);
    }
    return std::string(label) + ": " + std::string(text ? *text : *requestErrorText("no-activation"));
}

/// What the glue says for a refused request (upstream's SandboxEngine.requestRefused).
std::string refusalDetail(twidget::sdk::RequestVerdict verdict) {
    using twidget::sdk::RequestVerdict;
    switch (verdict) {
    case RequestVerdict::Disabled:
        return "the server allows no requests for this message (no can_query: a widget sent without allow_queries, or a forwarded copy of one sent without fwd_allow_queries)";
    case RequestVerdict::Busy:
        return "a request is already in flight";
    case RequestVerdict::NoActivation:
        return "it needs a tap on the visible widget, one request per tap; this message allows no background requests (no background_query)";
    case RequestVerdict::Held:
        return "a background request from a widget off screen";
    case RequestVerdict::RateLimited:
        return "background requests at most once per 5 s";
    case RequestVerdict::NoWallet:
        return "the client has no wallet for this user (no WidgetContext.wallet)";
    case RequestVerdict::Foreground:
    case RequestVerdict::Background:
    case RequestVerdict::Granted:
        break;
    }
    return std::string(twidget::sdk::requestVerdictName(verdict));
}

/// Where the glue's words for a refused wallet call differ from a request's (upstream's WALLET_REFUSED).
std::string walletRefusalDetail(twidget::sdk::RequestVerdict verdict) {
    using twidget::sdk::RequestVerdict;
    switch (verdict) {
    case RequestVerdict::NoActivation:
        return "it needs a tap on the visible widget, or the answer to a call made by a tap within 10 s; one call each";
    case RequestVerdict::Busy:
        return "a request or a wallet call is already in flight";
    default:
        return refusalDetail(verdict);
    }
}

/// The wallet object's methods (magic 0: sendTransaction, 1: signData).
JSValue walletMethod(JSContext* ctx, JSValueConst, int argc, JSValueConst* argv, int magic) {
    return glue(ctx, [&]() -> JSValue {
        const char* name = magic == 1 ? "signData" : "sendTransaction";
        auto argument = [&](int i) {
            return argc > i && !JS_IsUndefined(argv[i]) ? std::optional<Value>(convert<Value>(ctx, argv[i], ArgInfo{"TelegramWidget.wallet", name, i}))
                                                         : std::optional<Value>();
        };
        return toJS(ctx, HostState::of(ctx).window().TelegramWidget(ctx)->walletCall(ctx, magic == 1, argument(0), argument(1)));
    });
}

/// A string argument converted only up to `maxBytes + 1` UTF-8 bytes (a lone surrogate as WTF-8, which the SDK policy
/// refuses); nullopt for a non-string or anything longer.
std::optional<std::string> boundedUTF8(JSContext* ctx, const std::optional<Value>& value, size_t maxBytes) {
    if (!value || !JS_IsString(value->get())) {
        return std::nullopt;
    }
    bool cut = false;
    std::string text = String::adopt(ctx, JS_DupValue(ctx, value->get())).utf8Prefix(maxBytes + 1, &cut);
    if (cut || text.size() > maxBytes) {
        return std::nullopt;
    }
    return text;
}

} // namespace

TelegramWidget::PendingRequest* TelegramWidget::pendingRequest(int64_t id) {
    for (PendingRequest& request : m_requests) {
        if (request.id == id) {
            return &request;
        }
    }
    return nullptr;
}

void TelegramWidget::removeRequest(JSRuntime* rt, int64_t id) {
    for (size_t i = 0; i < m_requests.size(); i++) {
        if (m_requests[i].id == id) {
            m_requests[i].slot.clear(rt);
            m_requests.erase(m_requests.begin() + ptrdiff_t(i));
            return;
        }
    }
}

Value TelegramWidget::request(JSContext* ctx, std::optional<Value> data, std::optional<Value> options) {
    std::optional<std::string> checked = boundedUTF8(ctx, data, size_t(twidget::sdk::MAX_REQUEST_DATA_BYTES));
    if (checked) {
        checked = twidget::sdk::checkRequestData(*checked);
    }
    if (!checked) {
        throw TypeError{"TelegramWidget.request: data must be a string of 1–64 bytes (UTF-8)"};
    }
    // v0.5.0 (§2.18): the options, after the data, as the shim checks them.
    bool withWallet = false;
    if (options) {
        const std::optional<twidget::Json> json = walletArgumentJson(ctx, options->get());
        const std::optional<bool> wallet = json ? twidget::sdk::checkRequestOptions(*json) : std::nullopt;
        if (!wallet) {
            throw TypeError{"TelegramWidget.request: options must be an object with at most `wallet` (a boolean)"};
        }
        withWallet = *wallet;
    }
    HostState& host = HostState::of(ctx);
    PendingRequest pending;
    pending.id = host.nextRequestId();
    makePending(ctx, pending.slot, false);
    Value promise = Value::dup(ctx, pending.slot.promise.value);
    const int64_t id = pending.id;
    m_requests.push_back(std::move(pending));
    // The glue's order: a preview, then the request gate, then the press it consumes.
    if (refusedInPreview(ctx, "request")) {
        host.queueRequestRefusal(ctx, id, "NOT_ALLOWED", "preview");
        return promise;
    }
    const twidget::sdk::RequestVerdict verdict = host.decideRequest(ctx, withWallet);
    if (verdict == twidget::sdk::RequestVerdict::Held) {
        // widget-sandbox v0.3.0: a background request off screen waits for the widget to appear, holding the gate's
        // one-in-flight slot; its promise stays pending meanwhile (sendHeldRequest).
        PendingRequest* held = this->pendingRequest(id);
        held->held = true;
        held->data = *checked;
        return promise;
    }
    if (const std::optional<std::string_view> refusal = twidget::sdk::requestRefusal(verdict)) {
        const std::string detail = withWallet && verdict == twidget::sdk::RequestVerdict::NoActivation
                                       ? "a request for the wallet needs a tap on the visible widget, one request per tap"
                                       : refusalDetail(verdict);
        host.reportCapped(ctx, "request-blocked", "request refused (" + std::string(twidget::sdk::requestVerdictName(verdict)) + "): " + detail);
        host.queueRequestRefusal(ctx, id, std::string(*refusal), std::string(twidget::sdk::requestVerdictName(verdict)));
        return promise;
    }
    if (verdict == twidget::sdk::RequestVerdict::Foreground) {
        host.consumeActivation(ctx);
    }
    this->pendingRequest(id)->outgoing = true;
    if (withWallet) {
        twidget::Json options = twidget::Json::object();
        options.set("wallet", true);
        twidget::Json args = twidget::Json::array();
        args.push(std::to_string(id)).push(*checked).push(std::move(options));
        postBridgeCallJson(ctx, "request", args);
        return promise;
    }
    const String idText = String::fromUTF8(ctx, std::to_string(id));
    const String dataText = String::fromUTF8(ctx, *checked);
    postBridgeCall(ctx, "request", {&idText, &dataText});
    return promise;
}

Value TelegramWidget::wallet(JSContext* ctx) {
    if (!HostState::of(ctx).widgetContext().wallet) {
        return Value::adopt(ctx, JS_NULL);
    }
    if (m_wallet.isUndefined()) {
        // The shim's Object.freeze({ sendTransaction, signData }): two own enumerable methods, frozen.
        Value object = Value::adopt(ctx, checked(ctx, JS_NewObject(ctx)));
        const char* names[] = {"sendTransaction", "signData"};
        for (int i = 0; i < 2; i++) {
            JSValue method = checked(ctx, JS_NewCFunctionMagic(ctx, walletMethod, names[i], 2, JS_CFUNC_generic_magic, i));
            check(ctx, JS_DefinePropertyValueStr(ctx, object.get(), names[i], method, JS_PROP_C_W_E));
        }
        check(ctx, JS_FreezeObject(ctx, object.get()));
        m_wallet.set(JS_GetRuntime(ctx), JS_DupValue(ctx, object.get()));
    }
    return Value::dup(ctx, m_wallet.value);
}

Value TelegramWidget::walletCall(JSContext* ctx, bool signData, std::optional<Value> argument, std::optional<Value> data) {
    const std::string method = signData ? "signData" : "sendTransaction";
    const std::optional<twidget::Json> json = argument ? walletArgumentJson(ctx, argument->get()) : std::nullopt;
    twidget::Json checkedArgument;
    if (signData) {
        const std::optional<twidget::SignDataPayload> payload = json ? twidget::sdk::checkSignDataPayload(*json) : std::nullopt;
        if (!payload) {
            throw TypeError{"TelegramWidget.wallet.signData: expected TON Connect's payload: { type: 'text', text } (at most 4096 bytes), "
                            "{ type: 'binary', bytes } or { type: 'cell', schema, cell } (base64 of at most 4096 characters); no domain"};
        }
        checkedArgument = payload->toJson();
    } else {
        const std::optional<twidget::WalletTransaction> transaction = json ? twidget::sdk::checkWalletTransaction(*json) : std::nullopt;
        if (!transaction) {
            throw TypeError{"TelegramWidget.wallet.sendTransaction: expected TON Connect's transaction: { valid_until?, network?, from?, messages: "
                            "[{ address, amount, payload?, stateInit? }] }, 1 to 255 messages, user-friendly addresses, amounts as decimal strings of "
                            "nanotons, payloads in base64 (at most 8192 characters each, 65536 together)"};
        }
        checkedArgument = transaction->toJson();
    }
    std::optional<std::string> label = boundedUTF8(ctx, data, size_t(twidget::sdk::MAX_REQUEST_DATA_BYTES));
    if (label) {
        label = twidget::sdk::checkRequestData(*label);
    }
    if (!label) {
        throw TypeError{"TelegramWidget.wallet." + method + ": data must be a string of 1–64 bytes (UTF-8)"};
    }
    HostState& host = HostState::of(ctx);
    PendingRequest pending;
    pending.id = host.nextRequestId();
    pending.label = signData ? "wallet.signData" : "wallet.sendTransaction";
    makePending(ctx, pending.slot, false);
    Value promise = Value::dup(ctx, pending.slot.promise.value);
    const int64_t id = pending.id;
    m_requests.push_back(std::move(pending));
    // The shim's: no wallet, NOT_ALLOWED (the object is null then, but a reference may outlive a context set again).
    if (!host.widgetContext().wallet) {
        host.queueRequestRefusal(ctx, id, "NOT_ALLOWED", "no-wallet");
        return promise;
    }
    // The glue's order: a preview, then the gate (a press or the grant, never the background), then the press it consumes.
    if (refusedInPreview(ctx, "wallet")) {
        host.queueRequestRefusal(ctx, id, "NOT_ALLOWED", "preview");
        return promise;
    }
    const twidget::sdk::RequestVerdict verdict = host.decideWallet(ctx);
    if (const std::optional<std::string_view> refusal = twidget::sdk::requestRefusal(verdict)) {
        host.reportCapped(ctx, "request-blocked", "wallet." + method + " refused (" + std::string(twidget::sdk::requestVerdictName(verdict)) + "): " + walletRefusalDetail(verdict));
        host.queueRequestRefusal(ctx, id, std::string(*refusal), std::string(twidget::sdk::requestVerdictName(verdict)));
        return promise;
    }
    if (verdict == twidget::sdk::RequestVerdict::Foreground) {
        host.consumeActivation(ctx);
    }
    this->pendingRequest(id)->outgoing = true;
    twidget::Json args = twidget::Json::array();
    args.push(std::to_string(id)).push(method).push(std::move(checkedArgument)).push(*label);
    postBridgeCallJson(ctx, "wallet", args);
    return promise;
}

void TelegramWidget::sendHeldRequest(JSContext* ctx) {
    for (PendingRequest& request : m_requests) {
        if (!request.held) {
            continue;
        }
        request.held = false;
        request.outgoing = true;
        const String idText = String::fromUTF8(ctx, std::to_string(request.id));
        const String dataText = String::fromUTF8(ctx, request.data);
        postBridgeCall(ctx, "request", {&idText, &dataText});
        return;
    }
}

void TelegramWidget::settleRequest(JSContext* ctx, int64_t id, const twidget::WidgetRequestOutcome& outcome) {
    PendingRequest* request = this->pendingRequest(id);
    if (!request || !request->outgoing || request->slot.settled) {
        return;
    }
    HostState& host = HostState::of(ctx);
    // The gate is free before the widget hears the outcome, so its handler may ask again at once.
    if (outcome.failure != twidget::WidgetRequestFailure::None) {
        host.finishRequest(false);
        // A wallet call keeps the wallet's codes (REJECTED, BAD_REQUEST); a request's are FAILED.
        const std::string_view code = request->isWallet() ? twidget::sdk::walletFailureCode(outcome.failure) : twidget::sdk::requestFailureCode(outcome.failure);
        queueRejectWithRequestError(ctx, request->slot, code, requestErrorMessage(request->label, code, {}));
        this->removeRequest(JS_GetRuntime(ctx), id);
        return;
    }
    const std::optional<twidget::sdk::CheckedAnswer> answer = twidget::sdk::checkRequestAnswer(outcome.answer);
    // v0.5.0 (§2.18): an answer with no error grants one wallet call when the call had a press or the grant.
    host.finishRequest(answer.has_value());
    if (!answer) {
        Runtime::from(ctx).host().diagnostic("answer-rejected", "the answer's result is not text of at most " + std::to_string(twidget::sdk::MAX_REQUEST_RESULT_BYTES) +
                                                                    " bytes (UTF-8, no NUL); the widget gets INVALID_ANSWER");
        queueRejectWithRequestError(ctx, request->slot, "INVALID_ANSWER", requestErrorMessage(request->label, "INVALID_ANSWER", {}));
        this->removeRequest(JS_GetRuntime(ctx), id);
        return;
    }
    Value object = Value::adopt(ctx, JS_NewObject(ctx));
    if (JS_IsException(object.get())) {
        throw Thrown{};
    }
    JSValue result = answer->result ? String::fromUTF8(ctx, *answer->result).toJS(ctx) : JS_NULL;
    if (JS_IsException(result) || JS_SetPropertyStr(ctx, object.get(), "result", result) < 0 || JS_FreezeObject(ctx, object.get()) < 0) {
        throw Thrown{};
    }
    // Resolving reads the value's `then` (script): the slot leaves the list first.
    PromiseSlot slot = std::move(request->slot);
    request->slot = PromiseSlot{};
    this->removeRequest(JS_GetRuntime(ctx), id);
    resolveNow(ctx, slot, object.get());
    slot.clear(JS_GetRuntime(ctx));
}

void TelegramWidget::refuseRequest(JSContext* ctx, int64_t id, const std::string& code, const std::string& reason) {
    PendingRequest* request = this->pendingRequest(id);
    if (!request || request->outgoing) {
        return;
    }
    queueRejectWithRequestError(ctx, request->slot, code, requestErrorMessage(request->label, code, reason));
    this->removeRequest(JS_GetRuntime(ctx), id);
}

void TelegramWidget::copyText(JSContext* ctx, std::optional<Value> text) {
    std::optional<std::string> checked = boundedUTF8(ctx, text, size_t(twidget::sdk::MAX_COPY_TEXT_LENGTH) * 3);
    if (checked) {
        checked = twidget::sdk::checkCopyText(*checked);
    }
    if (!checked) {
        throw TypeError{"TelegramWidget.copyText: text must be a string of 1–256 characters"};
    }
    if (refusedInPreview(ctx, "copyText")) {
        return;
    }
    HostState& host = HostState::of(ctx);
    if (!host.consumeActivation(ctx)) {
        host.reportLinkDiagnostic(ctx, "activation-blocked",
                                  "copyText ignored: it needs a tap on the visible widget and runs in that tap's handler, one call per tap");
        return;
    }
    const String value = String::fromUTF8(ctx, *checked);
    postBridgeCall(ctx, "copyText", {&value});
}

void TelegramWidget::setWatching(JSContext* ctx, bool on) {
    if (refusedInPreview(ctx, "watchPublicData")) {
        return;
    }
    HostState& host = HostState::of(ctx);
    if (host.watchesPublicData() == on) {
        return;
    }
    host.setWatchesPublicData(on);
    const String flag = String::fromUTF8(ctx, on ? "true" : "false");
    postBridgeCall(ctx, "watchPublicData", {&flag});
}

Value TelegramWidget::contentSafeAreaInset(JSContext* ctx) {
    const HostState& state = HostState::of(ctx);
    if (m_contentSafeAreaInset.isUndefined() || m_contentSafeAreaGeneration != state.contentSafeAreaGeneration()) {
        // Upstream's ContentSafeArea, its fields in its order.
        const ContentSafeArea& area = state.sdkContentSafeArea();
        const std::pair<const char*, double> fields[] = {{"top", area.top},       {"right", area.right},
                                                         {"bottom", area.bottom}, {"left", area.left},
                                                         {"cornerLeft", area.cornerLeft}, {"cornerRight", area.cornerRight}};
        Value object = Value::adopt(ctx, JS_NewObject(ctx));
        if (JS_IsException(object.get())) {
            throw Thrown{};
        }
        for (const auto& [key, value] : fields) {
            if (JS_SetPropertyStr(ctx, object.get(), key, JS_NewFloat64(ctx, value)) < 0) {
                throw Thrown{};
            }
        }
        if (JS_FreezeObject(ctx, object.get()) < 0) {
            throw Thrown{};
        }
        m_contentSafeAreaInset.set(JS_GetRuntime(ctx), JS_DupValue(ctx, object.get()));
        m_contentSafeAreaGeneration = state.contentSafeAreaGeneration();
    }
    return Value::dup(ctx, m_contentSafeAreaInset.value);
}

void TelegramWidget::watchPublicData(JSContext* ctx) {
    this->setWatching(ctx, true);
}

void TelegramWidget::unwatchPublicData(JSContext* ctx) {
    this->setWatching(ctx, false);
}

Vector<HeldCallback>& TelegramWidget::handlersOf(Event event) {
    switch (event) {
    case Event::ThemeChanged:
        return m_themeChanged;
    case Event::Activated:
        return m_activated;
    case Event::Deactivated:
        return m_deactivated;
    case Event::ChatDataChanged:
        return m_chatDataChanged;
    case Event::PublicDataChanged:
        return m_publicDataChanged;
    case Event::ContentSafeAreaChanged:
        return m_contentSafeAreaChanged;
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

void TelegramWidget::setResizeAnchor(JSContext* ctx, std::optional<Value> edge) {
    std::optional<std::string> checked;
    if (edge && JS_IsString(edge->get())) {
        // Longer than either edge is neither: only a short prefix is converted.
        bool cut = false;
        const std::string text = String::adopt(ctx, JS_DupValue(ctx, edge->get())).utf8Prefix(16, &cut);
        if (!cut) {
            checked = twidget::sdk::checkResizeAnchor(text);
        }
    }
    if (!checked) {
        throw TypeError{"TelegramWidget.setResizeAnchor: edge must be 'top' or 'bottom'"};
    }
    HostState::of(ctx).setResizeAnchor(*checked == "bottom" ? ResizeAnchor::Bottom : ResizeAnchor::Top);
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
    // A handler may add or remove others: call through copies, made first.
    const Vector<HeldCallback>& handlers = this->handlersOf(event);
    const bool withTheme = event == Event::ThemeChanged;
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
    // The glue's order: a preview's refusal comes before the haptic gate.
    if (refusedInPreview(ctx, "haptic") || !HostState::of(ctx).admitHaptic(ctx)) {
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
    for (const Vector<HeldCallback>* handlers : {&m_themeChanged, &m_activated, &m_deactivated, &m_chatDataChanged, &m_publicDataChanged, &m_contentSafeAreaChanged, &m_onTheme}) {
        for (const HeldCallback& held : *handlers) {
            held.mark(rt, mark);
        }
    }
    m_themeParams.mark(rt, mark);
    m_viewer.mark(rt, mark);
    m_contentSafeAreaInset.mark(rt, mark);
    m_wallet.mark(rt, mark);
    m_hapticFeedback.mark(rt, mark);
    for (const PendingRequest& request : m_requests) {
        request.slot.mark(rt, mark);
    }
}

void TelegramWidget::dispose(JSRuntime* rt) {
    for (Vector<HeldCallback>* handlers : {&m_themeChanged, &m_activated, &m_deactivated, &m_chatDataChanged, &m_publicDataChanged, &m_contentSafeAreaChanged, &m_onTheme}) {
        for (HeldCallback& held : *handlers) {
            held.clear(rt);
        }
        handlers->clear();
    }
    m_themeParams.clear(rt);
    m_viewer.clear(rt);
    m_contentSafeAreaInset.clear(rt);
    m_wallet.clear(rt);
    m_hapticFeedback.clear(rt);
    for (PendingRequest& request : m_requests) {
        request.slot.clear(rt);
    }
    m_requests.clear();
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
