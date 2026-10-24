#include "twidget/sdk_policy.h"

#include <algorithm>

namespace twidget {

Json WidgetAction::toJson() const {
    Json o = Json::object();
    switch (kind) {
    case Ready: o.set("kind", "ready"); break;
    case OpenLink: o.set("kind", "openLink").set("url", url); break;
    case OpenTelegramLink: o.set("kind", "openTelegramLink").set("url", url); break;
    case Haptic:
        o.set("kind", "haptic").set("haptic", hapticKind);
        if (!hapticValue.empty()) o.set("value", hapticValue);
        break;
    }
    return o;
}

namespace sdk {

namespace {

template <size_t N>
bool contains(const std::array<std::string_view, N>& list, std::string_view s) {
    return std::find(list.begin(), list.end(), s) != list.end();
}

bool isHex(unsigned char c) { return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f'); }
bool isAlpha(unsigned char c) { return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'); }
bool isDigit(unsigned char c) { return c >= '0' && c <= '9'; }

/// Lowercases A–Z only: a Unicode mapping (U+212A KELVIN SIGN → `k`) must not turn a non-ASCII host into an ASCII one.
std::string asciiLower(std::string_view s) {
    std::string out(s);
    for (char& c : out) if (c >= 'A' && c <= 'Z') c = char(c + 32);
    return out;
}

bool endsWith(std::string_view s, std::string_view suffix) { return s.size() >= suffix.size() && s.substr(s.size() - suffix.size()) == suffix; }

bool isTelegramHost(std::string_view host) {
    for (std::string_view t : TELEGRAM_HOSTS)
        if (host == t || (host.size() > t.size() && endsWith(host, t) && host[host.size() - t.size() - 1] == '.')) return true;
    return false;
}

/// ASCII that may stand unescaped after the authority: RFC 3986 unreserved, reserved and `%`.
bool isUrlAscii(unsigned char c) {
    if (isAlpha(c) || isDigit(c)) return true;
    static constexpr std::string_view other = "-._~:/?#[]@!$&'()*+,;=%";
    return other.find(char(c)) != std::string_view::npos;
}

/// Length of the well-formed UTF-8 sequence of a scalar value at `s[i]` (a non-ASCII lead byte), 0 when it is
/// not one: a bad lead or continuation byte, an overlong form, a surrogate (WTF-8 ED A0..BF), above U+10FFFF, truncated.
size_t utf8Sequence(std::string_view s, size_t i) {
    auto at = [&](size_t k) -> unsigned { return i + k < s.size() ? (unsigned char)s[i + k] : 0x100; };
    auto cont = [&](size_t k, unsigned lo = 0x80, unsigned hi = 0xBF) { unsigned b = at(k); return b >= lo && b <= hi; };
    unsigned c = at(0);
    if (c >= 0xC2 && c <= 0xDF) return cont(1) ? 2 : 0;
    if (c == 0xE0) return cont(1, 0xA0) && cont(2) ? 3 : 0;
    if ((c >= 0xE1 && c <= 0xEC) || c == 0xEE || c == 0xEF) return cont(1) && cont(2) ? 3 : 0;
    if (c == 0xED) return cont(1, 0x80, 0x9F) && cont(2) ? 3 : 0; // ED A0..BF would be U+D800..DFFF
    if (c == 0xF0) return cont(1, 0x90) && cont(2) && cont(3) ? 4 : 0;
    if (c >= 0xF1 && c <= 0xF3) return cont(1) && cont(2) && cont(3) ? 4 : 0;
    if (c == 0xF4) return cont(1, 0x80, 0x8F) && cont(2) && cont(3) ? 4 : 0;
    return 0;
}

/// The member a JS object built by JSON.parse would have: with a key given twice, the last value.
const Json* member(const Json& object, std::string_view key) {
    const Json* found = nullptr;
    for (const auto& [k, v] : object.obj()) if (k == key) found = &v;
    return found;
}

bool isThemeColor(const std::string& v) {
    if (v.size() != 7 || v[0] != '#') return false;
    for (size_t i = 1; i < 7; i++) if (!isHex((unsigned char)v[i])) return false;
    return true;
}

} // namespace

bool isPrivilegedMethod(std::string_view method) { return contains(PRIVILEGED_METHODS, method); }

std::optional<std::string> checkLink(std::string_view method, std::string_view url) {
    if (utf8Length(url) > size_t(MAX_LINK_LENGTH)) return std::nullopt;
    if (url.size() < 8 || asciiLower(url.substr(0, 8)) != "https://") return std::nullopt;
    size_t end = 8;
    while (end < url.size() && url[end] != '/' && url[end] != '?' && url[end] != '#') end++;
    std::string_view authority = url.substr(8, end - 8);
    if (authority.find('@') != std::string_view::npos) return std::nullopt;
    size_t colon = authority.find(':');
    std::string host = asciiLower(colon == std::string_view::npos ? authority : authority.substr(0, colon));
    std::optional<std::string_view> port;
    if (colon != std::string_view::npos) port = authority.substr(colon + 1);
    if (port) {
        if (port->empty() || port->size() > 5) return std::nullopt;
        long value = 0;
        for (char c : *port) {
            if (!isDigit((unsigned char)c)) return std::nullopt;
            value = value * 10 + (c - '0');
        }
        if (value > 65535) return std::nullopt;
    }
    if (host.empty() || host.size() > 253) return std::nullopt;
    for (size_t start = 0;;) {
        size_t dot = host.find('.', start);
        std::string_view label = std::string_view(host).substr(start, dot == std::string::npos ? std::string::npos : dot - start);
        if (label.empty() || label.size() > 63 || label.front() == '-' || label.back() == '-') return std::nullopt;
        for (char c : label) if (!(isDigit((unsigned char)c) || (c >= 'a' && c <= 'z') || c == '-')) return std::nullopt;
        if (dot == std::string::npos) break;
        start = dot + 1;
    }
    if (isTelegramHost(host) != (method == "openTelegramLink")) return std::nullopt;
    static constexpr char HEX[] = "0123456789ABCDEF";
    std::string rest;
    for (size_t i = end; i < url.size();) {
        unsigned char c = (unsigned char)url[i];
        if (c < 0x80) {
            if (!isUrlAscii(c)) return std::nullopt;
            if (c == '%' && !(i + 2 < url.size() && isHex((unsigned char)url[i + 1]) && isHex((unsigned char)url[i + 2]))) return std::nullopt;
            rest.push_back(char(c));
            i++;
            continue;
        }
        size_t n = utf8Sequence(url, i);
        if (n == 0) return std::nullopt;
        for (size_t k = 0; k < n; k++) {
            unsigned char b = (unsigned char)url[i + k];
            rest.push_back('%');
            rest.push_back(HEX[b >> 4]);
            rest.push_back(HEX[b & 15]);
        }
        i += n;
    }
    std::string out = "https://" + host + (port ? ":" + std::string(*port) : std::string()) + rest;
    if (out.size() > size_t(MAX_LINK_LENGTH)) return std::nullopt;
    return out;
}

std::optional<std::string> checkLinkValue(std::string_view method, const Json& url) {
    if (!url.isString()) return std::nullopt;
    return checkLink(method, url.asString());
}

std::optional<HapticCall> checkHaptic(const Json& args) {
    if (!args.isArray()) return std::nullopt;
    const Json& kind = args[0];
    const Json& value = args[1];
    if (kind.isString() && kind.asString() == "impact" && args.size() == 2 && value.isString() && contains(HAPTIC_IMPACT_STYLES, value.asString()))
        return HapticCall{"impact", value.asString()};
    if (kind.isString() && kind.asString() == "notification" && args.size() == 2 && value.isString() && contains(HAPTIC_NOTIFICATION_TYPES, value.asString()))
        return HapticCall{"notification", value.asString()};
    if (kind.isString() && kind.asString() == "selection" && args.size() == 1) return HapticCall{"selection", std::nullopt};
    return std::nullopt;
}

std::optional<std::string> checkResizeAnchor(std::string_view edge) {
    if (!contains(RESIZE_ANCHORS, edge)) return std::nullopt;
    return std::string(edge);
}

std::optional<std::string> checkResizeAnchorValue(const Json& edge) {
    return edge.isString() ? checkResizeAnchor(edge.asString()) : std::nullopt;
}

Json BridgeCall::toJson() const {
    if (action) return action->toJson();
    Json o = Json::object();
    if (resizeAnchor) o.set("kind", "setResizeAnchor").set("edge", *resizeAnchor);
    return o;
}

std::optional<BridgeCall> checkBridgeCall(const Json& method, const Json& args) {
    if (!args.isArray() || !method.isString()) return std::nullopt;
    const std::string& m = method.asString();
    WidgetAction action;
    if (m == "ready") {
        if (args.size() != 0) return std::nullopt;
        action.kind = WidgetAction::Ready;
        return BridgeCall{action, std::nullopt};
    }
    if (m == "openLink" || m == "openTelegramLink") {
        std::optional<std::string> url = args.size() == 1 ? checkLinkValue(m, args[0]) : std::nullopt;
        if (!url) return std::nullopt;
        action.kind = m == "openLink" ? WidgetAction::OpenLink : WidgetAction::OpenTelegramLink;
        action.url = std::move(*url);
        return BridgeCall{action, std::nullopt};
    }
    if (m == "haptic") {
        std::optional<HapticCall> h = checkHaptic(args);
        if (!h) return std::nullopt;
        action.kind = WidgetAction::Haptic;
        action.hapticKind = h->haptic;
        action.hapticValue = h->value.value_or("");
        return BridgeCall{action, std::nullopt};
    }
    if (m == "setResizeAnchor") {
        std::optional<std::string> edge = args.size() == 1 ? checkResizeAnchorValue(args[0]) : std::nullopt;
        if (!edge) return std::nullopt;
        return BridgeCall{std::nullopt, std::move(edge)};
    }
    return std::nullopt;
}

HapticGate::Decision HapticGate::decide(double now, bool visible) {
    if (last_) tokens_ = std::min(double(HAPTIC_BURST), tokens_ + (std::max(0.0, now - *last_) * HAPTIC_PER_SECOND) / 1000);
    last_ = now;
    if (visible && tokens_ >= 1) {
        tokens_ -= 1;
        return Decision::Play;
    }
    if (reported_ && now - *reported_ < HAPTIC_REPORT_MS) return Decision::Drop;
    reported_ = now;
    return Decision::Report;
}

std::map<std::string, std::string> checkThemeParams(const Json& params) {
    std::map<std::string, std::string> out;
    if (!params.isObject()) return out;
    for (std::string_view key : THEME_KEYS) {
        const Json* v = member(params, key);
        if (v && v->isString() && isThemeColor(v->asString())) out.emplace(std::string(key), asciiLower(v->asString()));
    }
    return out;
}

std::map<std::string, std::string> checkThemeParams(const std::map<std::string, std::string>& params) {
    std::map<std::string, std::string> out;
    for (std::string_view key : THEME_KEYS) {
        auto it = params.find(std::string(key));
        if (it != params.end() && isThemeColor(it->second)) out.emplace(std::string(key), asciiLower(it->second));
    }
    return out;
}

Json themeParamsJson(const std::map<std::string, std::string>& checked) {
    Json o = Json::object();
    for (std::string_view key : THEME_KEYS) {
        auto it = checked.find(std::string(key));
        if (it != checked.end()) o.set(it->first, it->second);
    }
    return o;
}

std::optional<std::string> checkLocale(std::string_view locale) {
    if (locale.empty() || locale.size() > size_t(MAX_LOCALE_LENGTH)) return std::nullopt;
    // ^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$
    size_t i = 0;
    while (i < locale.size() && isAlpha((unsigned char)locale[i])) i++;
    if (i < 2 || i > 8) return std::nullopt;
    while (i < locale.size()) {
        if (locale[i] != '-') return std::nullopt;
        size_t start = ++i;
        while (i < locale.size() && (isAlpha((unsigned char)locale[i]) || isDigit((unsigned char)locale[i]))) i++;
        if (i - start < 1 || i - start > 8) return std::nullopt;
    }
    return std::string(locale);
}

std::optional<std::string> checkLocaleValue(const Json& locale) {
    if (!locale.isString()) return std::nullopt;
    return checkLocale(locale.asString());
}

size_t storageBytes(const StorageArea& area) {
    size_t n = 0;
    for (const auto& [k, v] : area) n += utf8Length(k) + utf8Length(v);
    return n;
}

std::optional<StorageArea> checkStorageArea(const Json& area) {
    if (!area.isObject()) return std::nullopt;
    std::map<std::string, const Json*> members;
    for (const auto& [k, v] : area.obj()) members[k] = &v; // the last value of a repeated key, as JSON.parse keeps it
    StorageArea out;
    for (const auto& [k, v] : members) {
        if (!v->isString()) return std::nullopt;
        out.emplace(k, v->asString());
    }
    if (storageBytes(out) > size_t(STORAGE_QUOTA_BYTES)) return std::nullopt;
    return out;
}

bool storageAreaFits(const StorageArea& area) { return storageBytes(area) <= size_t(STORAGE_QUOTA_BYTES); }

Json StorageCommit::toJson() const {
    Json o = Json::object();
    auto area = [](const StorageArea& a) {
        Json j = Json::object();
        for (const auto& [k, v] : a) j.set(k, v);
        return j;
    };
    if (local) o.set("local", area(*local));
    if (session) o.set("session", area(*session));
    return o;
}

std::optional<StorageCommit> checkStorageCommit(const Json& commit) {
    if (!commit.isObject()) return std::nullopt;
    StorageCommit out;
    std::map<std::string, const Json*> members;
    for (const auto& [k, v] : commit.obj()) members[k] = &v;
    for (const auto& [k, v] : members) {
        if (k != "local" && k != "session") return std::nullopt;
        std::optional<StorageArea> area = checkStorageArea(*v);
        if (!area) return std::nullopt;
        (k == "local" ? out.local : out.session) = std::move(area);
    }
    return out;
}

Json storagePreloadJson(const WidgetStorage& storage, bool* accepted) {
    bool ok = storageAreaFits(storage.local) && storageAreaFits(storage.session);
    if (accepted) *accepted = ok;
    if (!ok) return Json::object();
    return StorageCommit{storage.local, storage.session}.toJson();
}

} // namespace sdk
} // namespace twidget
