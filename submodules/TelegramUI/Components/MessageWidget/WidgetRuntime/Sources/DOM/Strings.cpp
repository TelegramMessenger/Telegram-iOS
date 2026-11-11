#include "Sources/DOM/Strings.h"

#include <algorithm>
#include <cstddef>

#include "Sources/Support/Allocator.h"

namespace wr {

static String mapASCII(JSContext* ctx, const String& s, char16_t from, char16_t to, int delta) {
    JSStringView v = s.view();
    bool needs = false;
    for (uint32_t i = 0; i < v.length && !needs; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        needs = c >= from && c <= to;
    }
    if (!needs) {
        return s;
    }
    Vector<char16_t> out(v.length, u'\0', JSAllocator<char16_t>(JS_GetRuntime(ctx)));
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        out[i] = c >= from && c <= to ? char16_t(c + delta) : c;
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

String asciiLowercase(JSContext* ctx, const String& s) {
    return mapASCII(ctx, s, 'A', 'Z', 32);
}

String asciiUppercase(JSContext* ctx, const String& s) {
    return mapASCII(ctx, s, 'a', 'z', -32);
}

std::vector<String> splitOnASCIIWhitespace(JSContext* ctx, const String& s) {
    std::vector<String> out;
    JSStringView v = s.view();
    auto at = [&](uint32_t i) -> char16_t { return v.latin1 ? v.latin1[i] : v.utf16[i]; };
    uint32_t i = 0;
    while (i < v.length) {
        while (i < v.length && isASCIIWhitespace(at(i))) {
            i++;
        }
        uint32_t start = i;
        while (i < v.length && !isASCIIWhitespace(at(i))) {
            i++;
        }
        if (i > start) {
            out.push_back(s.substring(ctx, start, i));
        }
    }
    return out;
}

static char16_t unitAt(const JSStringView& v, uint32_t i) {
    return v.latin1 ? char16_t(v.latin1[i]) : char16_t(v.utf16[i]);
}

/// Orders two tokens of `v` by code unit, then by length. Reads at most the shorter token's units plus one.
static int compareTokens(const JSStringView& v, const TokenRange& a, const TokenRange& b) {
    uint32_t la = a.end - a.start;
    uint32_t lb = b.end - b.start;
    uint32_t n = la < lb ? la : lb;
    for (uint32_t i = 0; i < n; i++) {
        char16_t x = unitAt(v, a.start + i);
        char16_t y = unitAt(v, b.start + i);
        if (x != y) {
            return x < y ? -1 : 1;
        }
    }
    return la < lb ? -1 : la > lb ? 1 : 0;
}

Vector<TokenRange> orderedSetTokens(JSContext* ctx, const String& s) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    JSStringView v = s.view();
    Vector<TokenRange> tokens{JSAllocator<TokenRange>(rt)};
    for (uint32_t i = 0; i < v.length;) {
        while (i < v.length && isASCIIWhitespace(unitAt(v, i))) {
            i++;
        }
        uint32_t start = i;
        while (i < v.length && !isASCIIWhitespace(unitAt(v, i))) {
            i++;
        }
        if (i > start) {
            tokens.push_back(TokenRange{start, i});
        }
    }
    const size_t n = tokens.size();
    if (n < 2) {
        return tokens;
    }
    Vector<uint32_t> order(n, 0, JSAllocator<uint32_t>(rt));
    for (size_t k = 0; k < n; k++) {
        order[k] = uint32_t(k);
    }
    Vector<uint32_t> merged(n, 0, JSAllocator<uint32_t>(rt));
    for (size_t width = 1; width < n; width *= 2) {
        for (size_t lo = 0; lo < n; lo += 2 * width) {
            size_t mid = std::min(lo + width, n);
            size_t hi = std::min(lo + 2 * width, n);
            size_t a = lo, b = mid, out = lo;
            while (a < mid && b < hi) {
                // Stable: on a tie the left run's token, the earlier occurrence, goes first.
                merged[out++] = compareTokens(v, tokens[order[b]], tokens[order[a]]) < 0 ? order[b++] : order[a++];
            }
            while (a < mid) {
                merged[out++] = order[a++];
            }
            while (b < hi) {
                merged[out++] = order[b++];
            }
        }
        order.swap(merged);
    }
    // Equal tokens are adjacent, earliest occurrence first (the sort is stable): drop every later one, then compact in
    // the original order.
    Vector<uint8_t> drop(n, 0, JSAllocator<uint8_t>(rt));
    for (size_t k = 1; k < n; k++) {
        if (compareTokens(v, tokens[order[k - 1]], tokens[order[k]]) == 0) {
            drop[order[k]] = 1;
        }
    }
    size_t kept = 0;
    for (size_t k = 0; k < n; k++) {
        if (!drop[k]) {
            tokens[kept++] = tokens[k];
        }
    }
    tokens.erase(tokens.begin() + ptrdiff_t(kept), tokens.end());
    return tokens;
}

String stripAndCollapseASCIIWhitespace(JSContext* ctx, const String& s) {
    JSStringView v = s.view();
    Vector<char16_t> out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    out.reserve(v.length);
    bool pendingSpace = false;
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        if (isASCIIWhitespace(c)) {
            pendingSpace = !out.empty();
            continue;
        }
        if (pendingSpace) {
            out.push_back(u' ');
            pendingSpace = false;
        }
        out.push_back(c);
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

/// Non-empty, without ASCII whitespace, NUL, '/', '>', and '=' when `noEquals`.
static bool isValidName(JSContext* ctx, const String& s, bool noEquals) {
    JSStringView v = s.view();
    if (v.length == 0) {
        return false;
    }
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        if (isASCIIWhitespace(c) || c == 0 || c == '/' || c == '>' || (noEquals && c == '=')) {
            return false;
        }
    }
    return true;
}

bool isValidAttributeLocalName(JSContext* ctx, const String& s) {
    return isValidName(ctx, s, true);
}

bool isValidNamespacePrefix(JSContext* ctx, const String& s) {
    return isValidName(ctx, s, false);
}

bool qualifiedNameIs(JSContext* ctx, JSAtom prefix, JSAtom localName, const String& name) {
    String p = String::fromAtom(ctx, prefix);
    String l = String::fromAtom(ctx, localName);
    JSStringView pv = p.view(), lv = l.view(), nv = name.view();
    if (uint64_t(nv.length) != uint64_t(pv.length) + 1 + lv.length) {
        return false;
    }
    auto unit = [](const JSStringView& v, uint32_t i) -> char16_t { return v.latin1 ? v.latin1[i] : v.utf16[i]; };
    for (uint32_t i = 0; i < pv.length; i++) {
        if (unit(nv, i) != unit(pv, i)) {
            return false;
        }
    }
    if (unit(nv, pv.length) != ':') {
        return false;
    }
    for (uint32_t i = 0; i < lv.length; i++) {
        if (unit(nv, pv.length + 1 + i) != unit(lv, i)) {
            return false;
        }
    }
    return true;
}

std::string quotedForMessage(const String& s) {
    constexpr size_t kMaxQuotedNameBytes = 160;
    bool cut = false;
    std::string quoted = s.utf8Prefix(kMaxQuotedNameBytes, &cut);
    if (cut) {
        quoted += "\xE2\x80\xA6"; // …
    }
    return quoted;
}

} // namespace wr
