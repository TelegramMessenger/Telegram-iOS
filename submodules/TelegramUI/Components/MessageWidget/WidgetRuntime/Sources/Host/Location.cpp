#include "Sources/Host/Location.h"

#include "Sources/DOM/DOM.h"

namespace wr {

namespace {

std::string lowercase(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
    return out;
}

const char* defaultPort(const std::string& scheme) {
    if (scheme == "http" || scheme == "ws") {
        return "80";
    }
    if (scheme == "https" || scheme == "wss") {
        return "443";
    }
    return nullptr;
}

} // namespace

URLParts splitURL(std::string_view url) {
    URLParts p;
    size_t colon = url.find(':');
    if (colon == std::string_view::npos) {
        p.pathname = std::string(url);
        p.origin = "null";
        return p;
    }
    std::string scheme = lowercase(url.substr(0, colon));
    p.protocol = scheme + ":";
    std::string_view rest = url.substr(colon + 1);
    if (size_t at = rest.find('#'); at != std::string_view::npos) {
        if (at + 1 < rest.size()) {
            p.hash = std::string(rest.substr(at));
        }
        rest = rest.substr(0, at);
    }
    if (size_t at = rest.find('?'); at != std::string_view::npos) {
        if (at + 1 < rest.size()) {
            p.search = std::string(rest.substr(at));
        }
        rest = rest.substr(0, at);
    }
    bool special = defaultPort(scheme) != nullptr;
    if (rest.substr(0, 2) == "//") {
        rest = rest.substr(2);
        size_t slash = rest.find('/');
        std::string_view authority = rest.substr(0, slash);
        rest = slash == std::string_view::npos ? std::string_view() : rest.substr(slash);
        if (size_t at = authority.rfind('@'); at != std::string_view::npos) {
            authority = authority.substr(at + 1);
        }
        size_t portAt = authority.rfind(':');
        if (portAt != std::string_view::npos && authority.find(']', portAt) == std::string_view::npos) {
            p.hostname = lowercase(authority.substr(0, portAt));
            p.port = std::string(authority.substr(portAt + 1));
        } else {
            p.hostname = lowercase(authority);
        }
        if (const char* port = defaultPort(scheme); port && p.port == port) {
            p.port.clear();
        }
        p.host = p.port.empty() ? p.hostname : p.hostname + ":" + p.port;
        p.pathname = rest.empty() ? "/" : std::string(rest);
        p.origin = special ? p.protocol + "//" + p.host : "null";
    } else {
        p.pathname = std::string(rest);
        p.origin = "null";
    }
    return p;
}

URLParts Location::parts(JSContext* ctx) {
    // The document holds its URL as a flat string, so reading it copies nothing.
    USVString url = DOMState::of(ctx).document().URL(ctx);
    return splitURL(url.utf8());
}

String Location::href(JSContext* ctx) {
    return DOMState::of(ctx).document().URL(ctx);
}

String Location::origin(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).origin); }
String Location::protocol(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).protocol); }
String Location::host(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).host); }
String Location::hostname(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).hostname); }
String Location::port(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).port); }
String Location::pathname(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).pathname); }
String Location::search(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).search); }
String Location::hash(JSContext* ctx) { return String::fromUTF8(ctx, this->parts(ctx).hash); }

} // namespace wr
