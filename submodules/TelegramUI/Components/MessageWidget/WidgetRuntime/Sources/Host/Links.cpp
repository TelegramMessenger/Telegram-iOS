#include "Sources/Host/Links.h"

#include <algorithm>
#include <string_view>

#include "Sources/Host/HostState.h"
#include "Sources/Host/TelegramWidget.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

constexpr std::string_view kTelegramHosts[] = {"t.me", "telegram.me", "telegram.dog"};
/// ASCII that may stand unescaped after the authority: RFC 3986 unreserved, reserved and `%`.
constexpr std::string_view kUrlAscii = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;=%";
constexpr char kHex[] = "0123456789ABCDEF";

char16_t asciiLower(char16_t c) {
    return c >= 'A' && c <= 'Z' ? char16_t(c + 32) : c;
}

bool isHex(char16_t c) {
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

bool isTelegramHost(std::string_view host) {
    for (std::string_view t : kTelegramHosts) {
        if (host == t || (host.size() > t.size() && host.ends_with(t) && host[host.size() - t.size() - 1] == '.')) {
            return true;
        }
    }
    return false;
}

/// utf8Length(url) > MAX_LINK_LENGTH, reading at most MAX_LINK_LENGTH + 1 units (each is at least one byte).
bool overLength(const String& url) {
    const uint32_t n = url.length();
    size_t bytes = 0;
    for (uint32_t i = 0; i < n; i++) {
        const char16_t c = url.at(i);
        if (c < 0x80) {
            bytes += 1;
        } else if (c < 0x800) {
            bytes += 2;
        } else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n && (url.at(i + 1) & 0xFC00) == 0xDC00) {
            bytes += 4;
            i++;
        } else {
            bytes += 3;
        }
        if (bytes > kMaxLinkLength) {
            return true;
        }
    }
    return false;
}

void appendEscaped(std::string& out, uint8_t byte) {
    out += '%';
    out += kHex[byte >> 4];
    out += kHex[byte & 15];
}

bool isASCIIWhitespace(char16_t c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

String trimmed(JSContext* ctx, const String& s) {
    uint32_t begin = 0;
    uint32_t end = s.length();
    while (begin < end && isASCIIWhitespace(s.at(begin))) {
        begin++;
    }
    while (end > begin && isASCIIWhitespace(s.at(end - 1))) {
        end--;
    }
    return begin == 0 && end == s.length() ? s : s.substring(ctx, begin, end);
}

void postLink(JSContext* ctx, LinkMethod method, const std::string& url) {
    const char* name = method == LinkMethod::OpenLink ? "openLink" : "openTelegramLink";
    // The glue's order: the URL's check, then a preview's refusal, then the press.
    if (refusedInPreview(ctx, name)) {
        return;
    }
    HostState& state = HostState::of(ctx);
    if (!state.consumeActivation(ctx)) {
        state.reportLinkDiagnostic(ctx, "activation-blocked",
                                   std::string(name) + " ignored: it needs a tap on the visible widget and runs in that tap's "
                                                       "handler, one call per tap");
        return;
    }
    const String text = String::fromUTF8(ctx, url);
    postBridgeCall(ctx, name, {&text});
}

} // namespace

std::optional<std::string> checkLink(LinkMethod method, const String& url) {
    if (overLength(url)) {
        return std::nullopt;
    }
    const uint32_t n = url.length();
    constexpr std::u16string_view kScheme = u"https://";
    if (n < kScheme.size()) {
        return std::nullopt;
    }
    for (uint32_t i = 0; i < kScheme.size(); i++) {
        if (asciiLower(url.at(i)) != kScheme[i]) {
            return std::nullopt;
        }
    }
    uint32_t end = uint32_t(kScheme.size());
    while (end < n && url.at(end) != '/' && url.at(end) != '?' && url.at(end) != '#') {
        end++;
    }
    // The authority: a host of LDH labels, lowercased (A–Z only, so no non-ASCII character turns ASCII), and a port.
    std::string host;
    std::optional<std::string> port;
    for (uint32_t i = uint32_t(kScheme.size()); i < end; i++) {
        const char16_t c = url.at(i);
        if (c == '@') {
            return std::nullopt;
        }
        if (port) {
            if (c < '0' || c > '9' || port->size() == 5) {
                return std::nullopt;
            }
            *port += char(c);
        } else if (c == ':') {
            port.emplace();
        } else {
            const char16_t lower = asciiLower(c);
            if (!((lower >= 'a' && lower <= 'z') || (lower >= '0' && lower <= '9') || lower == '-' || lower == '.')) {
                return std::nullopt;
            }
            host += char(lower);
        }
    }
    if (port && (port->empty() || std::stoi(*port) > 65535)) {
        return std::nullopt;
    }
    if (host.empty() || host.size() > 253) {
        return std::nullopt;
    }
    size_t labelStart = 0;
    while (true) {
        const size_t dot = host.find('.', labelStart);
        const std::string_view label = std::string_view(host).substr(labelStart, dot == std::string::npos ? std::string::npos : dot - labelStart);
        if (label.empty() || label.size() > 63 || label.front() == '-' || label.back() == '-') {
            return std::nullopt;
        }
        if (dot == std::string::npos) {
            break;
        }
        labelStart = dot + 1;
    }
    if (isTelegramHost(host) != (method == LinkMethod::OpenTelegramLink)) {
        return std::nullopt;
    }
    std::string out = "https://" + host;
    if (port) {
        out += ':';
        out += *port;
    }
    for (uint32_t i = end; i < n; i++) {
        const char16_t c = url.at(i);
        if (c < 0x80) {
            if (kUrlAscii.find(char(c)) == std::string_view::npos) {
                return std::nullopt;
            }
            if (c == '%' && !(i + 2 < n && isHex(url.at(i + 1)) && isHex(url.at(i + 2)))) {
                return std::nullopt;
            }
            out += char(c);
            continue;
        }
        uint32_t cp = c;
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < n && (url.at(i + 1) & 0xFC00) == 0xDC00) {
            cp = 0x10000 + ((uint32_t(c) - 0xD800) << 10) + (uint32_t(url.at(++i)) - 0xDC00);
        } else if (c >= 0xD800 && c <= 0xDFFF) {
            return std::nullopt;
        }
        if (cp < 0x800) {
            appendEscaped(out, uint8_t(0xC0 | (cp >> 6)));
            appendEscaped(out, uint8_t(0x80 | (cp & 63)));
        } else if (cp < 0x10000) {
            appendEscaped(out, uint8_t(0xE0 | (cp >> 12)));
            appendEscaped(out, uint8_t(0x80 | ((cp >> 6) & 63)));
            appendEscaped(out, uint8_t(0x80 | (cp & 63)));
        } else {
            appendEscaped(out, uint8_t(0xF0 | (cp >> 18)));
            appendEscaped(out, uint8_t(0x80 | ((cp >> 12) & 63)));
            appendEscaped(out, uint8_t(0x80 | ((cp >> 6) & 63)));
            appendEscaped(out, uint8_t(0x80 | (cp & 63)));
        }
    }
    if (out.size() > kMaxLinkLength) {
        return std::nullopt;
    }
    return out;
}

void openLinkFromWidget(JSContext* ctx, LinkMethod method, const std::optional<Value>& url) {
    std::optional<std::string> checked;
    if (url && JS_IsString(url->get())) {
        const String text = String::adopt(ctx, JS_DupValue(ctx, url->get()));
        checked = checkLink(method, text);
    }
    if (!checked) {
        throw TypeError{method == LinkMethod::OpenLink
                            ? "openLink: expected an absolute https: URL of at most 256 characters, without a user name, "
                              "not on t.me (use openTelegramLink)"
                            : "openTelegramLink: expected https://t.me/… (or telegram.me, telegram.dog) of at most 256 "
                              "characters"};
    }
    postLink(ctx, method, *checked);
}

void followLink(JSContext* ctx, const String& url) {
    // The trim scans the whitespace (the final review's I3); checkLink reads at most kMaxLinkLength + 1 units after it.
    const String link = trimmed(ctx, url);
    HostState& state = HostState::of(ctx);
    if (link.length() >= 11 && link.substring(ctx, 0, 11).equalsIgnoringASCIICase("javascript:")) {
        state.reportLinkDiagnostic(ctx, "navigation-blocked", "javascript: link ignored");
        return;
    }
    for (LinkMethod method : {LinkMethod::OpenTelegramLink, LinkMethod::OpenLink}) {
        if (std::optional<std::string> checked = checkLink(method, link)) {
            postLink(ctx, method, *checked);
            return;
        }
    }
    bool cut = false;
    state.reportLinkDiagnostic(ctx, "navigation-blocked",
                               "link ignored (openLink takes https: URLs of at most 256 characters): " +
                                   link.utf8Prefix(200, &cut, true));
}

void followAnchor(JSContext* ctx, const String& href) {
    const String link = trimmed(ctx, href);
    if (link.empty() || link.at(0) == '#') {
        return;
    }
    followLink(ctx, link);
}

} // namespace wr
