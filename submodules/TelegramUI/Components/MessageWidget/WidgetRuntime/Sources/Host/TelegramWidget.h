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
#include "Sources/Support/Promises.h"
#include "twidget/sdk_policy.h"

namespace wr {

/// SDK v1 §2.11 (sdk-policy.ts MAX_HANDLERS_PER_EVENT): onEvent keeps this many handlers per type; further ones are
/// ignored.
inline constexpr size_t kMaxHandlersPerEvent = 16;

/// SDK v1 §2.6 (V2a plan, Task 6): an unknown style or type is a TypeError; a call is posted as `haptic`
/// (["impact", style], ["notification", type], ["selection"]) when HostState::admitHaptic lets it through (the vendored
/// SDK policy's HapticGate: the rate limit, and a touch since widget-sandbox v0.2.2).
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
    /// themeChanged, activated, deactivated, chatDataChanged, publicDataChanged, contentSafeAreaChanged; anything else, a
    /// non-function, a handler already added or one past the 16th is ignored.
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
    /// SDK v1 §2.13 (widget-sandbox v0.2): the bot's chat state and shared state (HostState::chatData, publicData), null
    /// for none.
    std::optional<String> chatData(JSContext* ctx);
    std::optional<String> publicData(JSContext* ctx);
    /// The message is a forwarded copy (never in a preview).
    bool isForward(JSContext* ctx);
    /// 'private', 'group', 'supergroup' or 'channel'; null in a copy, a preview and when the host passed none.
    std::optional<String> chatType(JSContext* ctx);
    /// Mini Apps' WebAppUser for the account looking at the widget (the SDK policy's viewerJson), frozen and the same
    /// object for the runtime's life; null where the widget may not send requests and in a preview.
    Value viewer(JSContext* ctx);
    /// SDK v1 §2.17: what the client draws over the widget (HostState::sdkContentSafeArea), frozen and the same object
    /// until a change.
    Value contentSafeAreaInset(JSContext* ctx);
    /// An inline result shown before it is sent (sdk-v1 §2.16).
    bool isPreview(JSContext* ctx);
    /// SDK v1 §2.14: a request to the bot. `data` is 1–64 bytes of well-formed UTF-8 (the SDK policy's
    /// checkRequestData), else a TypeError at once. The promise settles in a task of its own: with `{result}` (frozen)
    /// when the client answers (HostState::completeRequest), else a WidgetRequestError with its code: a refusal of the
    /// request gate, a preview's NOT_ALLOWED, the client's failure, INVALID_ANSWER. `options` (v0.5.0, §2.18): an object
    /// with at most `wallet`, a boolean (checkRequestOptions), else a TypeError; `{ wallet: true }` asks the bot with the
    /// user's wallet card, on a press only, where the client has the wallet.
    Value request(JSContext* ctx, std::optional<Value> data, std::optional<Value> options);
    /// SDK v1 §2.18 (widget-sandbox v0.5.0): Gram Wallet, a frozen `{ sendTransaction, signData }`, the same object for
    /// the runtime's life; null where the client has no wallet for this user, the widget may not ask the bot, or in a
    /// preview (WidgetContextState::wallet).
    Value wallet(JSContext* ctx);
    /// The wallet object's two methods: `argument` (TON Connect's transaction, or its signData payload when `signData`)
    /// checked as the shim checks it (walletArgumentJson, then checkWalletTransaction or checkSignDataPayload) and `data`
    /// as a request's, else a TypeError. Then the gate (decideWallet): a refusal rejects in a task of its own; a call that
    /// passes goes to the client as the bridge call `wallet` with the checked argument. Its promise settles as a
    /// request's, with the wallet's own codes (REJECTED, BAD_REQUEST).
    Value walletCall(JSContext* ctx, bool signData, std::optional<Value> argument, std::optional<Value> data);
    /// The widget appeared and the request gate let the held background request go (RequestGate::show): its bridge call,
    /// as that appearance's request.
    void sendHeldRequest(JSContext* ctx);
    /// SDK v1 §2.15: `text` (1–256 UTF-16 code units, well-formed, else a TypeError) to the host, on a tap only: one
    /// privileged call per tap, shared with the links and request; outside one it is dropped with activation-blocked.
    void copyText(JSContext* ctx, std::optional<Value> text);
    /// SDK v1 §2.13: the widget follows its shared state live, or stops; the host is told changes only (`watchPublicData`
    /// with "true" or "false"). No tap needed.
    void watchPublicData(JSContext* ctx);
    void unwatchPublicData(JSContext* ctx);

    // Native, inside the tasks HostState queues.
    enum class Event { ThemeChanged, Activated, Deactivated, ChatDataChanged, PublicDataChanged, ContentSafeAreaChanged };
    /// The client's outcome for request `id`, sent to it: frees the request gate and settles the promise; nothing for
    /// an id that is not an outgoing request still pending.
    void settleRequest(JSContext* ctx, int64_t id, const twidget::WidgetRequestOutcome& outcome);
    /// Rejects request `id`, refused before it went out, with `code`, its message worded for the glue's `reason`.
    void refuseRequest(JSContext* ctx, int64_t id, const std::string& code, const std::string& reason);
    /// Runs the handlers of `event` in the order added, `this` the TelegramWidget and no arguments, then for
    /// ThemeChanged onTheme's callbacks with the colour scheme; each is reported on its own.
    void runEvent(JSContext* ctx, Event event);

    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

private:
    /// A request whose promise has not settled: sent to the client (`outgoing`), or refused, its rejection queued.
    struct PendingRequest {
        int64_t id = 0;
        bool outgoing = false;
        /// What the error messages name (upstream's label): `request`, or a wallet call (v0.5.0)
        /// `wallet.sendTransaction` or `wallet.signData`, whose failures keep the wallet's codes.
        std::string_view label = "request";
        bool isWallet() const { return label != "request"; }
        PromiseSlot slot;
        /// A background request made off screen (widget-sandbox v0.3.0): held, with its data, until the widget appears.
        bool held = false;
        std::string data;
    };
    Vector<HeldCallback>& handlersOf(Event event);
    void setWatching(JSContext* ctx, bool on);
    /// The pending request `id`, or nullptr.
    PendingRequest* pendingRequest(int64_t id);
    void removeRequest(JSRuntime* rt, int64_t id);
    Vector<PendingRequest> m_requests;
    Vector<HeldCallback> m_themeChanged;
    Vector<HeldCallback> m_activated;
    Vector<HeldCallback> m_deactivated;
    Vector<HeldCallback> m_chatDataChanged;
    Vector<HeldCallback> m_publicDataChanged;
    Vector<HeldCallback> m_contentSafeAreaChanged;
    Vector<HeldCallback> m_onTheme;
    Held m_hapticFeedback;
    /// themeParams' object, made for HostState::themeGeneration m_themeParamsGeneration.
    Held m_themeParams;
    uint64_t m_themeParamsGeneration = 0;
    /// viewer's object, made for HostState::contextGeneration m_viewerGeneration.
    Held m_viewer;
    uint64_t m_viewerGeneration = 0;
    /// contentSafeAreaInset's object, made for HostState::contentSafeAreaGeneration m_contentSafeAreaGeneration.
    Held m_contentSafeAreaInset;
    uint64_t m_contentSafeAreaGeneration = 0;
    /// wallet's object, made at the first read where the widget has the wallet.
    Held m_wallet;
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

/// Posts a bridge call: `method` with the strings in `args` as a JSON array (JSON.stringify's escaping). A preview posts
/// only what the SDK policy's allowedInPreview lets it (callers report the refusal first: refusedInPreview).
void postBridgeCall(JSContext* ctx, std::string_view method, std::initializer_list<const String*> args);
/// The same for arguments the runtime built itself as JSON (v0.5.0: a request's options, a wallet call's checked
/// argument), `args` an array.
void postBridgeCallJson(JSContext* ctx, std::string_view method, const twidget::Json& args);

/// SDK v1 §2.16: true, with preview-blocked (at most MAX_REJECTION_REPORTS times), when the widget is a preview and
/// `method` is not one a preview may call (the SDK policy's allowedInPreview: ready and setResizeAnchor).
bool refusedInPreview(JSContext* ctx, std::string_view method);

} // namespace wr
