#include "Sources/DOM/CSSComponents.h"

#include <algorithm>


namespace wr::css {

namespace {

void putUTF8(std::string& out, uint32_t c) {
    if (c < 0x80) {
        out += char(c);
    } else if (c < 0x800) {
        out += char(0xC0 | (c >> 6));
        out += char(0x80 | (c & 0x3F));
    } else if (c < 0x10000) {
        out += char(0xE0 | (c >> 12));
        out += char(0x80 | ((c >> 6) & 0x3F));
        out += char(0x80 | (c & 0x3F));
    } else {
        out += char(0xF0 | (c >> 18));
        out += char(0x80 | ((c >> 12) & 0x3F));
        out += char(0x80 | ((c >> 6) & 0x3F));
        out += char(0x80 | (c & 0x3F));
    }
}

} // namespace

std::string cssInput(const String& text, uint32_t limit) {
    JSStringView v = text.view();
    auto unit = [&v](uint32_t i) -> uint32_t { return v.latin1 ? v.latin1[i] : v.utf16[i]; };
    const uint32_t length = std::min(v.length, limit);
    std::string out;
    out.reserve(length);
    for (uint32_t i = 0; i < length; i++) {
        uint32_t c = unit(i);
        if (c == '\r') {
            if (i + 1 < length && unit(i + 1) == '\n') {
                i++;
            }
            c = '\n';
        } else if (c == '\f') {
            c = '\n';
        } else if (c == 0) {
            c = 0xFFFD;
        } else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length && unit(i + 1) >= 0xDC00 && unit(i + 1) <= 0xDFFF) {
            c = 0x10000 + ((c - 0xD800) << 10) + (unit(i + 1) - 0xDC00);
            i++;
        } else if (c >= 0xD800 && c <= 0xDFFF) {
            c = 0xFFFD;
        }
        putUTF8(out, c);
    }
    return out;
}

BlockShape blockShape(const litehtml::css_token_vector& tokens) {
    BlockShape shape;
    std::array<int, kMaxBracketDepth> closers{};
    int depth = 0;
    for (const litehtml::css_token& t : tokens) {
        int closer = 0;
        if (t.type == litehtml::LEFT_PAREN || t.type == litehtml::FUNCTION) {
            closer = litehtml::RIGHT_PAREN;
        } else if (t.type == litehtml::LEFT_BRACKET) {
            closer = litehtml::RIGHT_BRACKET;
        } else if (t.type == litehtml::LEFT_BRACE) {
            closer = litehtml::RIGHT_BRACE;
        }
        if (closer) {
            if (depth == kMaxBracketDepth) {
                shape.tooDeep = true;
                return shape;
            }
            closers[size_t(depth++)] = closer;
        } else if (depth > 0 && t.ch == closers[size_t(depth - 1)]) {
            depth--;
        }
    }
    return shape;
}

std::optional<litehtml::css_token_vector> componentValues(JSContext* ctx, const String& text) {
    if (text.length() > kMaxSelectorUnits) {
        return std::nullopt;
    }
    std::string source = cssInput(text);
    litehtml::css_token_vector flat = litehtml::tokenize(source);
    const BlockShape shape = blockShape(flat);
    if (shape.tooDeep) {
        return std::nullopt;
    }
    return litehtml::normalize(std::move(flat), litehtml::f_componentize);
}

} // namespace wr::css
