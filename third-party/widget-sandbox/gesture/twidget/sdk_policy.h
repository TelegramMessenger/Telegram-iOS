// SDK v1 checks (docs/sdk-v1.md §2.5, §2.6, §2.8, §2.9, §2.12, §3): the C++ twin of
// the checked part of packages/core/src/shared/sdk-policy.ts, next to
// SdkPolicy.swift and SdkPolicy.kt. Pure and side-effect free; checked against
// tests/fixtures/sdk-policy.json (copied from packages/core/tests/fixtures by
// `pnpm build:desktop`), so a rule change goes to the four copies and the
// fixture together. The theme defaults and the renderer's CSS variables are
// TS only: the renderer core builds them from the host's `theme` message.
//
// Strings. Everything here is UTF-8 bytes. A JS string may hold a lone
// surrogate; QuickJS hands it to C++ in its 3-byte WTF-8 form (ED A0..BF xx),
// and the engine parses bridge calls and storage commits with
// `Json::parse(…, Json::Surrogates::Keep)` so that the JSON route gives the
// same bytes. `utf8Length` is the byte length, which is what the TS
// `utf8Length` counts (a lone surrogate is 3 bytes in both); `checkLink`
// rejects invalid UTF-8 and every surrogate code point, as the TS version
// rejects lone surrogates.
#pragma once

#include "twidget/json.h"

#include <array>
#include <map>
#include <optional>
#include <string>
#include <string_view>

namespace twidget {

/// One Web Storage area: keys and values as the widget set them (see "Strings" above).
using StorageArea = std::map<std::string, std::string>;

/// Web Storage of one message as the client keeps it (docs/sdk-v1.md §2.8, §5.4): the preload at start.
struct WidgetStorage {
    StorageArea local;
    StorageArea session;
};

/// What a widget asks the client to do, after the glue's checks (docs/sdk-v1.md §3.2, §4.3).
struct WidgetAction {
    enum Kind { Ready, OpenLink, OpenTelegramLink, Haptic } kind = Ready;
    /// OpenLink, OpenTelegramLink: the URL to open (scheme and host lowercase, non-ASCII percent-encoded).
    std::string url;
    /// Haptic: "impact", "notification" or "selection".
    std::string hapticKind;
    /// Haptic: the impact style or the notification type; empty for "selection".
    std::string hapticValue;

    bool operator==(const WidgetAction& o) const { return kind == o.kind && url == o.url && hapticKind == o.hapticKind && hapticValue == o.hapticValue; }
    /// The TS `WidgetAction` shape: {kind:'ready'} | {kind:'openLink', url} | {kind:'haptic', haptic, value?}.
    Json toJson() const;
};

namespace sdk {

inline constexpr int MAX_LINK_LENGTH = 256;
/// Bytes of keys and values (UTF-8) per storage area and message.
inline constexpr int STORAGE_QUOTA_BYTES = 16384;
inline constexpr int MAX_LOCALE_LENGTH = 35;
inline constexpr std::string_view DEFAULT_LOCALE = "en-US";
inline constexpr int HAPTIC_BURST = 5;
inline constexpr int HAPTIC_PER_SECOND = 10;
/// `haptic-limit` is reported at most this often.
inline constexpr double HAPTIC_REPORT_MS = 1000;
/// Handlers per `onEvent` type in the shim (here for completeness; the glue never sees them).
inline constexpr int MAX_HANDLERS_PER_EVENT = 16;
/// The widget profile this glue enforces (`PROFILE_VERSION` in profile-tables.ts; docs/profile-v1.md).
inline constexpr int PROFILE_VERSION = 1;
/// Two full areas of the quota at 12 JSON bytes per byte (`\uXXXX` escapes plus the quotes, colon and
/// comma of tiny pairs): a longer `storage` host call cannot be within the quota (worker.ts
/// MAX_STORAGE_COMMIT_CHARS; JSON bytes ≥ JSON characters, and the bound holds for bytes too).
inline constexpr size_t MAX_STORAGE_COMMIT_BYTES = 2 * 12 * STORAGE_QUOTA_BYTES + 64;
/// The diagnostics `bridge-rejected`, `activation-blocked` and `storage-rejected` are reported at most this often per widget.
inline constexpr int MAX_REJECTION_REPORTS = 20;

inline constexpr std::array<std::string_view, 15> THEME_KEYS = {
    "bg_color", "text_color", "hint_color", "link_color", "button_color", "button_text_color",
    "secondary_bg_color", "accent_text_color", "subtitle_text_color", "destructive_text_color",
    "section_bg_color", "section_header_text_color", "section_separator_color", "header_bg_color", "bottom_bar_bg_color",
};
inline constexpr std::array<std::string_view, 5> HAPTIC_IMPACT_STYLES = {"light", "medium", "heavy", "rigid", "soft"};
inline constexpr std::array<std::string_view, 3> HAPTIC_NOTIFICATION_TYPES = {"error", "success", "warning"};
inline constexpr std::array<std::string_view, 3> TELEGRAM_HOSTS = {"t.me", "telegram.me", "telegram.dog"};
/// Methods that need the task's user gesture (docs/protocol.md, "User activation").
inline constexpr std::array<std::string_view, 2> PRIVILEGED_METHODS = {"openLink", "openTelegramLink"};
/// The edges of the bubble that can stay put on screen when the widget's height changes (`setResizeAnchor`,
/// docs/sdk-v1.md §2.12): "top" (the bubble grows and shrinks downward, the content below moves) or "bottom" (it
/// grows upward, its bottom stays, the content above moves).
inline constexpr std::array<std::string_view, 2> RESIZE_ANCHORS = {"top", "bottom"};
/// Until the widget calls `setResizeAnchor`: the bubble grows and shrinks downward.
inline constexpr std::string_view DEFAULT_RESIZE_ANCHOR = "top";

bool isPrivilegedMethod(std::string_view method);

/// UTF-8 length of a string: its byte length (a lone surrogate in WTF-8 is 3 bytes, as the TS version counts it).
inline size_t utf8Length(std::string_view s) { return s.size(); }

/**
 * The URL a link call opens, or nullopt when it breaks the rules: an absolute
 * `https:` URL, no user name or password, an ASCII host of LDH labels (an IDN in
 * its `xn--` form), an optional port, at most 256 bytes as given and at most
 * 256 characters once non-ASCII characters after the host are percent-encoded
 * as UTF-8. `openTelegramLink` takes only t.me, telegram.me and telegram.dog
 * (and their subdomains), any path; any other `method` is `openLink`, which
 * takes every other host. Scheme and host come out lowercase (A–Z only), the
 * rest as given. Invalid UTF-8 and surrogate code points are refused.
 */
std::optional<std::string> checkLink(std::string_view method, std::string_view url);
/// The same for a JSON value: anything but a string is nullopt.
std::optional<std::string> checkLinkValue(std::string_view method, const Json& url);

struct HapticCall {
    std::string haptic;                // "impact" | "notification" | "selection"
    std::optional<std::string> value;  // the style or type; none for "selection"
    bool operator==(const HapticCall& o) const { return haptic == o.haptic && value == o.value; }
};

/// The haptic of a `haptic` bridge call's args, or nullopt: `['impact', style]`, `['notification', type]`, `['selection']`.
std::optional<HapticCall> checkHaptic(const Json& args);

/// The resize anchor of a `setResizeAnchor` call's argument, or nullopt: exactly "top" or "bottom" (case-sensitive, no trimming).
std::optional<std::string> checkResizeAnchor(std::string_view edge);
/// The same for a JSON value: anything but a string is nullopt.
std::optional<std::string> checkResizeAnchorValue(const Json& edge);

/**
 * A bridge call that passed its checks (the TS `BridgeCall`): an action for the client (`onAction`), or, for
 * `setResizeAnchor`, the edge, which no action carries: the host keeps the latest one next to the height it reports
 * (`WidgetDiagnostics::resizeAnchor`). Exactly one of the two is set. Since v0.1.3; `WidgetAction` is unchanged.
 */
struct BridgeCall {
    std::optional<WidgetAction> action;
    /// `setResizeAnchor`: "top" or "bottom".
    std::optional<std::string> resizeAnchor;

    bool operator==(const BridgeCall& o) const { return action == o.action && resizeAnchor == o.resizeAnchor; }
    /// The TS `BridgeCall` shape: the action's (`WidgetAction::toJson`), or {kind:'setResizeAnchor', edge}.
    Json toJson() const;
};

/// The checked call, or nullopt when the method is unknown or its arguments are wrong (`bridge-rejected`).
/// Before v0.1.3 this returned `std::optional<WidgetAction>`; the action is now `->action`.
std::optional<BridgeCall> checkBridgeCall(const Json& method, const Json& args);

/**
 * Haptics need no gesture but a visible widget and room in the bucket (5 calls,
 * refilled at 10 per second). `Play` delivers; `Drop` drops silently; `Report`
 * drops and reports `haptic-limit` (at most once per second). Same arithmetic,
 * in the same order, as the TS class (the fixture steps through the floats).
 */
class HapticGate {
public:
    enum class Decision { Play, Drop, Report };
    Decision decide(double nowMs, bool visible);
    static std::string_view name(Decision d) { return d == Decision::Play ? "play" : d == Decision::Drop ? "drop" : "report"; }

private:
    double tokens_ = HAPTIC_BURST;
    std::optional<double> last_;
    std::optional<double> reported_;
};

/// The theme keys of `params` whose values are `#rrggbb` (lowercased); everything else is dropped.
std::map<std::string, std::string> checkThemeParams(const Json& params);
std::map<std::string, std::string> checkThemeParams(const std::map<std::string, std::string>& params);
Json themeParamsJson(const std::map<std::string, std::string>& checked);

/// A BCP 47 tag of at most 35 characters (`ru`, `en-US`, `pt-BR`, `zh-Hant-TW`), or nullopt.
std::optional<std::string> checkLocale(std::string_view locale);
std::optional<std::string> checkLocaleValue(const Json& locale);

/// UTF-8 bytes of an area's keys and values.
size_t storageBytes(const StorageArea& area);

/// An object of strings within the quota, or nullopt. A key given twice counts once, with its last value (JSON.parse).
std::optional<StorageArea> checkStorageArea(const Json& area);
/// The same for an area the client passed (only the quota can be wrong).
bool storageAreaFits(const StorageArea& area);

struct StorageCommit {
    std::optional<StorageArea> local;
    std::optional<StorageArea> session;
    Json toJson() const;
};

/// A commit (or a preload) of `local` and/or `session`, each checked whole; nullopt when anything is wrong (`storage-rejected`).
std::optional<StorageCommit> checkStorageCommit(const Json& commit);

/// `{"local": {…}, "session": {…}}` of a client preload, or `{}` (and false) when either area is over the quota.
Json storagePreloadJson(const WidgetStorage& storage, bool* accepted = nullptr);

} // namespace sdk
} // namespace twidget
