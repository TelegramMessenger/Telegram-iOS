#include "Sources/Host/Base64.h"

#include "Sources/Support/Allocator.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

constexpr char kAlphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

/// The alphabet's value of `c`, or -1.
int sextet(char16_t c) {
    if (c >= 'A' && c <= 'Z') {
        return c - 'A';
    }
    if (c >= 'a' && c <= 'z') {
        return c - 'a' + 26;
    }
    if (c >= '0' && c <= '9') {
        return c - '0' + 52;
    }
    if (c == '+') {
        return 62;
    }
    if (c == '/') {
        return 63;
    }
    return -1;
}

bool isASCIIWhitespace(char16_t c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

[[noreturn]] void invalidCharacter(const char* message) {
    throw DOMError{"InvalidCharacterError", message};
}

} // namespace

String base64Encode(JSContext* ctx, const String& data) {
    const uint32_t n = data.length();
    Vector<char> out{JSAllocator<char>(JS_GetRuntime(ctx))};
    out.reserve(size_t(n + 2) / 3 * 4);
    uint32_t group = 0;
    int bits = 0;
    for (uint32_t i = 0; i < n; i++) {
        const char16_t c = data.at(i);
        if (c > 0xFF) {
            invalidCharacter("btoa: the string has a character outside Latin-1.");
        }
        group = (group << 8) | c;
        bits += 8;
        if (bits == 24) {
            out.push_back(kAlphabet[(group >> 18) & 63]);
            out.push_back(kAlphabet[(group >> 12) & 63]);
            out.push_back(kAlphabet[(group >> 6) & 63]);
            out.push_back(kAlphabet[group & 63]);
            group = 0;
            bits = 0;
        }
    }
    if (bits == 8) {
        out.push_back(kAlphabet[(group >> 2) & 63]);
        out.push_back(kAlphabet[(group << 4) & 63]);
        out.push_back('=');
        out.push_back('=');
    } else if (bits == 16) {
        out.push_back(kAlphabet[(group >> 10) & 63]);
        out.push_back(kAlphabet[(group >> 4) & 63]);
        out.push_back(kAlphabet[(group << 2) & 63]);
        out.push_back('=');
    }
    return String::fromUTF8(ctx, std::string_view(out.data(), out.size()));
}

String forgivingBase64Decode(JSContext* ctx, const String& data) {
    const uint32_t n = data.length();
    // Step 1: the code units without ASCII whitespace.
    Vector<char16_t> units{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    units.reserve(n);
    for (uint32_t i = 0; i < n; i++) {
        const char16_t c = data.at(i);
        if (!isASCIIWhitespace(c)) {
            units.push_back(c);
        }
    }
    // Step 2: a length that is a multiple of four loses one or two trailing "=".
    size_t length = units.size();
    if (length % 4 == 0) {
        for (int k = 0; k < 2 && length > 0 && units[length - 1] == '='; k++) {
            length--;
        }
    }
    // Step 3: a remainder of one cannot be.
    if (length % 4 == 1) {
        invalidCharacter("atob: the string is not correctly encoded.");
    }
    Vector<char16_t> out{JSAllocator<char16_t>(JS_GetRuntime(ctx))};
    out.reserve(length / 4 * 3 + 2);
    uint32_t buffer = 0;
    int bits = 0;
    for (size_t i = 0; i < length; i++) {
        const int value = sextet(units[i]);
        if (value < 0) {
            invalidCharacter("atob: the string is not correctly encoded.");
        }
        buffer = (buffer << 6) | uint32_t(value);
        bits += 6;
        if (bits == 24) {
            out.push_back(char16_t((buffer >> 16) & 0xFF));
            out.push_back(char16_t((buffer >> 8) & 0xFF));
            out.push_back(char16_t(buffer & 0xFF));
            buffer = 0;
            bits = 0;
        }
    }
    // Steps 8.2: 12 bits left give one byte, 18 give two (the rest is discarded).
    if (bits == 12) {
        out.push_back(char16_t((buffer >> 4) & 0xFF));
    } else if (bits == 18) {
        out.push_back(char16_t((buffer >> 10) & 0xFF));
        out.push_back(char16_t((buffer >> 2) & 0xFF));
    }
    return String::fromUTF16(ctx, out.data(), out.size());
}

} // namespace wr
