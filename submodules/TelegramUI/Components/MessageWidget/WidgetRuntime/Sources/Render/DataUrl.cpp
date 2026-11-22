#include "Sources/Render/DataUrl.h"

#include <cstring>
#include <utility>

namespace wr {

namespace {

bool isC0ControlOrSpace(unsigned char c) {
    return c <= 0x20;
}

bool isAsciiTabOrNewline(unsigned char c) {
    return c == '\t' || c == '\n' || c == '\r';
}

bool isAsciiWhitespace(unsigned char c) {
    return c == '\t' || c == '\n' || c == '\f' || c == '\r' || c == ' ';
}

bool isHttpWhitespace(unsigned char c) {
    return c == '\t' || c == '\n' || c == '\r' || c == ' ';
}

bool isAsciiAlphanumeric(unsigned char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

// MIME Sniffing's HTTP token code points.
bool isHttpTokenCodePoint(unsigned char c) {
    return isAsciiAlphanumeric(c) || (c != 0 && std::strchr("!#$%&'*+-.^_`|~", c) != nullptr);
}

char asciiLower(char c) {
    return c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c;
}

bool equalsIgnoringAsciiCase(std::string_view a, std::string_view b) {
    if (a.size() != b.size()) {
        return false;
    }
    for (size_t i = 0; i < a.size(); i++) {
        if (asciiLower(a[i]) != asciiLower(b[i])) {
            return false;
        }
    }
    return true;
}

int hexValue(unsigned char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

void appendPercentEncoded(std::string& out, unsigned char c) {
    static const char kHex[] = "0123456789ABCDEF";
    out += '%';
    out += kHex[c >> 4];
    out += kHex[c & 0xf];
}

// The text before the body's comma as the URL serializer writes it: the parser's opaque-path state percent-encodes
// C0 controls and bytes above U+007E, and its query state (after a '?') also space, '"', '<' and '>'. The type is
// read from that text, so a space in the query is not one the base64 suffix may skip, and a non-ASCII byte in the
// type is "%XX", which the MIME type parser accepts as token code points, as Fetch does.
std::string serializedHead(std::string_view head) {
    std::string out;
    out.reserve(head.size());
    bool inQuery = false;
    for (char ch : head) {
        unsigned char c = static_cast<unsigned char>(ch);
        bool encode = c < 0x20 || c > 0x7e;
        if (inQuery) {
            encode = encode || c == ' ' || c == '"' || c == '<' || c == '>';
        } else if (c == '?') {
            inQuery = true;
        }
        if (encode) {
            appendPercentEncoded(out, c);
        } else {
            out += ch;
        }
    }
    return out;
}

// URL's "percent-decode".
std::vector<uint8_t> percentDecode(std::string_view input) {
    std::vector<uint8_t> out;
    out.reserve(input.size());
    for (size_t i = 0; i < input.size(); i++) {
        unsigned char c = static_cast<unsigned char>(input[i]);
        if (c == '%' && i + 2 < input.size() && hexValue(input[i + 1]) >= 0 && hexValue(input[i + 2]) >= 0) {
            out.push_back(static_cast<uint8_t>(hexValue(input[i + 1]) * 16 + hexValue(input[i + 2])));
            i += 2;
        } else {
            out.push_back(c);
        }
    }
    return out;
}

int base64Value(uint8_t c) {
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

// Infra's "forgiving-base64 decode", over the isomorphic decode of `data` (each byte one code point).
std::optional<std::vector<uint8_t>> forgivingBase64Decode(const std::vector<uint8_t>& data) {
    std::vector<uint8_t> text;
    text.reserve(data.size());
    for (uint8_t c : data) {
        if (!isAsciiWhitespace(c)) {
            text.push_back(c);
        }
    }
    if (text.size() % 4 == 0) {
        if (text.size() >= 2 && text[text.size() - 1] == '=' && text[text.size() - 2] == '=') {
            text.resize(text.size() - 2);
        } else if (!text.empty() && text.back() == '=') {
            text.pop_back();
        }
    }
    if (text.size() % 4 == 1) {
        return std::nullopt;
    }
    std::vector<uint8_t> out;
    out.reserve(text.size() / 4 * 3 + 2);
    uint32_t buffer = 0;
    int bits = 0;
    for (uint8_t c : text) {
        int value = base64Value(c);
        if (value < 0) {
            return std::nullopt;
        }
        buffer = (buffer << 6) | uint32_t(value);
        bits += 6;
        if (bits == 24) {
            out.push_back(uint8_t(buffer >> 16));
            out.push_back(uint8_t(buffer >> 8));
            out.push_back(uint8_t(buffer));
            buffer = 0;
            bits = 0;
        }
    }
    if (bits == 12) {
        out.push_back(uint8_t(buffer >> 4));
    } else if (bits == 18) {
        out.push_back(uint8_t(buffer >> 10));
        out.push_back(uint8_t(buffer >> 2));
    }
    return out;
}

// Whether `mimeType` ends with ';', zero or more spaces, and "base64" (ASCII case-insensitive): Fetch's step 11.
bool endsWithBase64Suffix(std::string_view mimeType) {
    if (mimeType.size() < 7 || !equalsIgnoringAsciiCase(mimeType.substr(mimeType.size() - 6), "base64")) {
        return false;
    }
    size_t i = mimeType.size() - 6;
    while (i > 0 && mimeType[i - 1] == ' ') {
        i--;
    }
    return i > 0 && mimeType[i - 1] == ';';
}

bool allTokenCodePoints(std::string_view text) {
    for (char c : text) {
        if (!isHttpTokenCodePoint(static_cast<unsigned char>(c))) {
            return false;
        }
    }
    return true;
}

// The essence of MIME Sniffing's "parse a MIME type" (https://mimesniff.spec.whatwg.org/#parse-a-mime-type), or
// nullopt for failure. Parameters never fail the parse, so they are not read.
std::optional<std::string> mimeTypeEssence(std::string_view input) {
    while (!input.empty() && isHttpWhitespace(static_cast<unsigned char>(input.front()))) {
        input.remove_prefix(1);
    }
    while (!input.empty() && isHttpWhitespace(static_cast<unsigned char>(input.back()))) {
        input.remove_suffix(1);
    }
    size_t slash = input.find('/');
    if (slash == std::string_view::npos) {
        return std::nullopt;
    }
    std::string_view type = input.substr(0, slash);
    std::string_view subtype = input.substr(slash + 1);
    subtype = subtype.substr(0, subtype.find(';'));
    while (!subtype.empty() && isHttpWhitespace(static_cast<unsigned char>(subtype.back()))) {
        subtype.remove_suffix(1);
    }
    if (type.empty() || subtype.empty() || !allTokenCodePoints(type) || !allTokenCodePoints(subtype)) {
        return std::nullopt;
    }
    std::string essence;
    essence.reserve(type.size() + 1 + subtype.size());
    for (char c : type) {
        essence += asciiLower(c);
    }
    essence += '/';
    for (char c : subtype) {
        essence += asciiLower(c);
    }
    return essence;
}

} // namespace

std::optional<DataUrl> parseDataUrl(std::string_view url) {
    // The URL parser's first steps.
    size_t begin = 0;
    size_t end = url.size();
    while (begin < end && isC0ControlOrSpace(static_cast<unsigned char>(url[begin]))) {
        begin++;
    }
    while (end > begin && isC0ControlOrSpace(static_cast<unsigned char>(url[end - 1]))) {
        end--;
    }
    std::string input;
    input.reserve(end - begin);
    for (size_t i = begin; i < end; i++) {
        if (!isAsciiTabOrNewline(static_cast<unsigned char>(url[i]))) {
            input += url[i];
        }
    }
    std::string_view rest(input);
    if (rest.size() < 5 || !equalsIgnoringAsciiCase(rest.substr(0, 5), "data:")) {
        return std::nullopt;
    }
    rest.remove_prefix(5);
    // Fetch serializes the URL with "exclude fragment" set.
    rest = rest.substr(0, rest.find('#'));

    size_t comma = rest.find(',');
    if (comma == std::string_view::npos) {
        return std::nullopt;
    }
    std::string mimeType = serializedHead(rest.substr(0, comma));
    size_t first = 0;
    while (first < mimeType.size() && isAsciiWhitespace(static_cast<unsigned char>(mimeType[first]))) {
        first++;
    }
    size_t last = mimeType.size();
    while (last > first && isAsciiWhitespace(static_cast<unsigned char>(mimeType[last - 1]))) {
        last--;
    }
    mimeType = mimeType.substr(first, last - first);

    std::vector<uint8_t> body = percentDecode(rest.substr(comma + 1));
    if (endsWithBase64Suffix(mimeType)) {
        std::optional<std::vector<uint8_t>> decoded = forgivingBase64Decode(body);
        if (!decoded) {
            return std::nullopt;
        }
        body = std::move(*decoded);
        mimeType.resize(mimeType.size() - 6);
        while (!mimeType.empty() && mimeType.back() == ' ') {
            mimeType.pop_back();
        }
        mimeType.pop_back();   // the ';'
    }
    if (!mimeType.empty() && mimeType.front() == ';') {
        mimeType.insert(0, "text/plain");
    }
    std::optional<std::string> essence = mimeTypeEssence(mimeType);
    return DataUrl{essence ? std::move(*essence) : std::string("text/plain"), std::move(body)};
}

} // namespace wr
