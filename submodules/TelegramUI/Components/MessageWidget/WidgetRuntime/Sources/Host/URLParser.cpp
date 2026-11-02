#include "Sources/Host/URLParser.h"

#include <algorithm>
#include <array>
#include <climits>
#include <cstdint>
#include <cstdio>

#include "Sources/Host/ICU.h"

namespace wr::url {

namespace {

constexpr char32_t kEOF = 0xFFFFFFFF;
constexpr char kUpperHex[] = "0123456789ABCDEF";

bool isAlpha(char32_t c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

bool isDigit(char32_t c) {
    return c >= '0' && c <= '9';
}

bool isAlnum(char32_t c) {
    return isAlpha(c) || isDigit(c);
}

int hexValue(char32_t c) {
    if (isDigit(c)) {
        return int(c - '0');
    }
    if (c >= 'A' && c <= 'F') {
        return int(c - 'A' + 10);
    }
    if (c >= 'a' && c <= 'f') {
        return int(c - 'a' + 10);
    }
    return -1;
}

char32_t lower(char32_t c) {
    return c >= 'A' && c <= 'Z' ? c + 32 : c;
}

bool inSet(char32_t c, EncodeSet set) {
    if (c < 0x20 || c > 0x7E) {
        return true;
    }
    auto query = [&] { return c == ' ' || c == '"' || c == '#' || c == '<' || c == '>'; };
    auto path = [&] { return query() || c == '?' || c == '^' || c == '`' || c == '{' || c == '}'; };
    switch (set) {
    case EncodeSet::C0Control:
        return false;
    case EncodeSet::Fragment:
        return c == ' ' || c == '"' || c == '<' || c == '>' || c == '`';
    case EncodeSet::Query:
        return query();
    case EncodeSet::SpecialQuery:
        return query() || c == '\'';
    case EncodeSet::Path:
        return path();
    case EncodeSet::Userinfo:
        return path() || c == '/' || c == ':' || c == ';' || c == '=' || c == '@' || c == '[' || c == '\\' || c == ']' || c == '|';
    }
    return true;
}

void appendUTF8(char32_t c, std::string& out) {
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

bool isForbiddenHost(char32_t c) {
    switch (c) {
    case 0x00: case 0x09: case 0x0A: case 0x0D: case ' ': case '#': case '/': case ':': case '<': case '>': case '?':
    case '@': case '[': case '\\': case ']': case '^': case '|':
        return true;
    default:
        return false;
    }
}

bool isForbiddenDomain(char32_t c) {
    return isForbiddenHost(c) || c <= 0x1F || c == '%' || c == 0x7F;
}

// ---- IPv4

std::optional<uint64_t> parseIPv4Number(std::string_view s) {
    if (s.empty()) {
        return std::nullopt;
    }
    int radix = 10;
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        radix = 16;
        s.remove_prefix(2);
    } else if (s.size() >= 2 && s[0] == '0') {
        radix = 8;
        s.remove_prefix(1);
    }
    if (s.empty()) {
        return 0;
    }
    uint64_t value = 0;
    for (char c : s) {
        const int digit = hexValue(char32_t(c));
        if (digit < 0 || digit >= radix) {
            return std::nullopt;
        }
        // Saturate: anything past 2^40 fails every range check that follows.
        value = value > (uint64_t(1) << 40) ? value : value * uint64_t(radix) + uint64_t(digit);
    }
    return value;
}

std::vector<std::string_view> splitDots(std::string_view s) {
    std::vector<std::string_view> parts;
    size_t start = 0;
    for (;;) {
        const size_t dot = s.find('.', start);
        parts.push_back(s.substr(start, dot == std::string_view::npos ? std::string_view::npos : dot - start));
        if (dot == std::string_view::npos) {
            return parts;
        }
        start = dot + 1;
    }
}

bool endsInANumber(std::string_view s) {
    std::vector<std::string_view> parts = splitDots(s);
    if (parts.back().empty()) {
        if (parts.size() == 1) {
            return false;
        }
        parts.pop_back();
    }
    const std::string_view last = parts.back();
    bool digits = !last.empty();
    for (char c : last) {
        digits = digits && isDigit(char32_t(c));
    }
    return digits || parseIPv4Number(last).has_value();
}

std::optional<std::string> parseIPv4(std::string_view s) {
    std::vector<std::string_view> parts = splitDots(s);
    if (parts.back().empty() && parts.size() > 1) {
        parts.pop_back();
    }
    if (parts.size() > 4) {
        return std::nullopt;
    }
    std::vector<uint64_t> numbers;
    for (std::string_view part : parts) {
        std::optional<uint64_t> n = parseIPv4Number(part);
        if (!n) {
            return std::nullopt;
        }
        numbers.push_back(*n);
    }
    for (size_t i = 0; i + 1 < numbers.size(); i++) {
        if (numbers[i] > 255) {
            return std::nullopt;
        }
    }
    const uint64_t limit = uint64_t(1) << (8 * (5 - numbers.size()));
    if (numbers.back() >= limit) {
        return std::nullopt;
    }
    uint64_t address = numbers.back();
    for (size_t i = 0; i + 1 < numbers.size(); i++) {
        address += numbers[i] << (8 * (3 - i));
    }
    char text[16];
    std::snprintf(text, sizeof(text), "%u.%u.%u.%u", unsigned(address >> 24) & 255, unsigned(address >> 16) & 255,
                  unsigned(address >> 8) & 255, unsigned(address) & 255);
    return std::string(text);
}

// ---- IPv6

std::optional<std::array<uint16_t, 8>> parseIPv6(const std::u32string& in) {
    std::array<uint16_t, 8> address{};
    int pieceIndex = 0;
    int compress = -1;
    size_t p = 0;
    auto at = [&](size_t i) { return i < in.size() ? in[i] : kEOF; };
    if (at(p) == ':') {
        if (at(p + 1) != ':') {
            return std::nullopt;
        }
        p += 2;
        pieceIndex++;
        compress = pieceIndex;
    }
    while (at(p) != kEOF) {
        if (pieceIndex == 8) {
            return std::nullopt;
        }
        if (at(p) == ':') {
            if (compress != -1) {
                return std::nullopt;
            }
            p++;
            pieceIndex++;
            compress = pieceIndex;
            continue;
        }
        uint32_t value = 0;
        int length = 0;
        while (length < 4 && hexValue(at(p)) >= 0) {
            value = value * 16 + uint32_t(hexValue(at(p)));
            p++;
            length++;
        }
        if (at(p) == '.') {
            if (length == 0) {
                return std::nullopt;
            }
            p -= size_t(length);
            if (pieceIndex > 6) {
                return std::nullopt;
            }
            int numbersSeen = 0;
            while (at(p) != kEOF) {
                int ipv4Piece = -1;
                if (numbersSeen > 0) {
                    if (at(p) == '.' && numbersSeen < 4) {
                        p++;
                    } else {
                        return std::nullopt;
                    }
                }
                if (!isDigit(at(p))) {
                    return std::nullopt;
                }
                while (isDigit(at(p))) {
                    const int number = int(at(p) - '0');
                    if (ipv4Piece == -1) {
                        ipv4Piece = number;
                    } else if (ipv4Piece == 0) {
                        return std::nullopt;
                    } else {
                        ipv4Piece = ipv4Piece * 10 + number;
                    }
                    if (ipv4Piece > 255) {
                        return std::nullopt;
                    }
                    p++;
                }
                address[size_t(pieceIndex)] = uint16_t(address[size_t(pieceIndex)] * 0x100 + ipv4Piece);
                numbersSeen++;
                if (numbersSeen == 2 || numbersSeen == 4) {
                    pieceIndex++;
                }
            }
            if (numbersSeen != 4) {
                return std::nullopt;
            }
            break;
        }
        if (at(p) == ':') {
            p++;
            if (at(p) == kEOF) {
                return std::nullopt;
            }
        } else if (at(p) != kEOF) {
            return std::nullopt;
        }
        address[size_t(pieceIndex)] = uint16_t(value);
        pieceIndex++;
    }
    if (compress != -1) {
        int swaps = pieceIndex - compress;
        pieceIndex = 7;
        while (pieceIndex != 0 && swaps > 0) {
            std::swap(address[size_t(pieceIndex)], address[size_t(compress + swaps - 1)]);
            pieceIndex--;
            swaps--;
        }
    } else if (pieceIndex != 8) {
        return std::nullopt;
    }
    return address;
}

std::string serializeIPv6(const std::array<uint16_t, 8>& address) {
    // The first longest run of two or more zero pieces is compressed.
    int compress = -1, bestLength = 1;
    for (int i = 0; i < 8;) {
        if (address[size_t(i)] != 0) {
            i++;
            continue;
        }
        int j = i;
        while (j < 8 && address[size_t(j)] == 0) {
            j++;
        }
        if (j - i > bestLength) {
            bestLength = j - i;
            compress = i;
        }
        i = j;
    }
    std::string out;
    bool ignore0 = false;
    for (int i = 0; i < 8; i++) {
        if (ignore0 && address[size_t(i)] == 0) {
            continue;
        }
        ignore0 = false;
        if (compress == i) {
            out += i == 0 ? "::" : ":";
            ignore0 = true;
            continue;
        }
        char piece[8];
        std::snprintf(piece, sizeof(piece), "%x", unsigned(address[size_t(i)]));
        out += piece;
        if (i != 7) {
            out += ':';
        }
    }
    return out;
}

// ---- Hosts

std::optional<std::string> parseHost(const std::u32string& input, bool notSpecial) {
    if (!input.empty() && input[0] == '[') {
        if (input.back() != ']') {
            return std::nullopt;
        }
        std::optional<std::array<uint16_t, 8>> address = parseIPv6(input.substr(1, input.size() - 2));
        if (!address) {
            return std::nullopt;
        }
        return "[" + serializeIPv6(*address) + "]";
    }
    if (notSpecial) {
        // The opaque-host parser.
        std::string out;
        for (char32_t c : input) {
            if (c != '%' && isForbiddenHost(c)) {
                return std::nullopt;
            }
            percentEncode(c, EncodeSet::C0Control, out);
        }
        return out;
    }
    // A domain: percent-decoded, then "domain to ASCII", then the forbidden code points and IPv4.
    std::string utf8;
    for (char32_t c : input) {
        appendUTF8(c, utf8);
    }
    std::string domain;
    for (size_t i = 0; i < utf8.size(); i++) {
        if (utf8[i] == '%' && i + 2 < utf8.size() && hexValue(char32_t(uint8_t(utf8[i + 1]))) >= 0 &&
            hexValue(char32_t(uint8_t(utf8[i + 2]))) >= 0) {
            domain += char(hexValue(char32_t(uint8_t(utf8[i + 1]))) * 16 + hexValue(char32_t(uint8_t(utf8[i + 2]))));
            i += 2;
        } else {
            domain += utf8[i];
        }
    }
    std::optional<std::string> ascii = domainToASCII(domain);
    if (!ascii) {
        return std::nullopt;
    }
    for (char c : *ascii) {
        if (isForbiddenDomain(char32_t(uint8_t(c)))) {
            return std::nullopt;
        }
    }
    if (endsInANumber(*ascii)) {
        return parseIPv4(*ascii);
    }
    return ascii;
}


bool isWindowsDriveLetter(const std::u32string& s, size_t at, bool normalized) {
    return at + 1 < s.size() && isAlpha(s[at]) && (s[at + 1] == ':' || (!normalized && s[at + 1] == '|'));
}

bool isWindowsDriveLetterString(const std::string& s, bool normalized) {
    return s.size() == 2 && isAlpha(char32_t(s[0])) && (s[1] == ':' || (!normalized && s[1] == '|'));
}

/// "Starts with a Windows drive letter" over the code points from `at`.
bool startsWithWindowsDriveLetter(const std::u32string& s, size_t at) {
    if (at + 2 > s.size() || !isWindowsDriveLetter(s, at, false)) {
        return false;
    }
    if (at + 2 == s.size()) {
        return true;
    }
    const char32_t c = s[at + 2];
    return c == '/' || c == '\\' || c == '?' || c == '#';
}

void shortenPath(Record& url) {
    if (url.scheme == "file" && url.path.size() == 1 && isWindowsDriveLetterString(url.path[0], true)) {
        return;
    }
    if (!url.path.empty()) {
        url.path.pop_back();
    }
}

bool isSingleDot(const std::string& s) {
    return s == "." || s == "%2e" || s == "%2E";
}

bool isDoubleDot(const std::string& s) {
    if (s.size() < 2 || s.size() > 6) {
        return false;
    }
    std::string l;
    for (char c : s) {
        l += char(lower(char32_t(c)));
    }
    return l == ".." || l == ".%2e" || l == "%2e." || l == "%2e%2e";
}

enum class State {
    SchemeStart, Scheme, NoScheme, SpecialRelativeOrAuthority, PathOrAuthority, Relative, RelativeSlash,
    SpecialAuthoritySlashes, SpecialAuthorityIgnoreSlashes, Authority, Host, Port, File, FileSlash, FileHost, PathStart,
    Path, OpaquePath, Query, Fragment,
};

} // namespace

std::optional<std::string> domainToASCII(const std::string& domain) {
    // An ASCII domain is only lowercased: the standard's shortcut, which WPT's data at the vendored pin extends to
    // labels starting with "xn--" (invalid Punycode included: "xn--a" stays "xn--a").
    const bool ascii = std::all_of(domain.begin(), domain.end(), [](char c) { return uint8_t(c) < 0x80; });
    if (ascii) {
        if (domain.empty()) {
            return std::nullopt;
        }
        std::string out = domain;
        for (char& c : out) {
            c = char(lower(char32_t(uint8_t(c))));
        }
        return out;
    }
    static const UIDNA* const idna = [] {
        UErrorCode status = U_ZERO_ERROR;
        UIDNA* made = uidna_openUTS46(UIDNA_CHECK_BIDI | UIDNA_CHECK_CONTEXTJ | UIDNA_NONTRANSITIONAL_TO_ASCII |
                                          UIDNA_NONTRANSITIONAL_TO_UNICODE,
                                      &status);
        return U_SUCCESS(status) ? made : nullptr;
    }();
    if (!idna || domain.size() > size_t(INT32_MAX / 4)) {
        return std::nullopt;
    }
    std::string out(domain.size() * 4 + 16, '\0');
    UIDNAInfo info = UIDNA_INFO_INITIALIZER;
    UErrorCode status = U_ZERO_ERROR;
    const int32_t length = uidna_nameToASCII_UTF8(idna, domain.data(), int32_t(domain.size()), out.data(),
                                                  int32_t(out.size()), &info, &status);
    // beStrict false: VerifyDnsLength and CheckHyphens are off, so their errors do not fail the domain.
    const uint32_t ignored = UIDNA_ERROR_EMPTY_LABEL | UIDNA_ERROR_LABEL_TOO_LONG | UIDNA_ERROR_DOMAIN_NAME_TOO_LONG |
                             UIDNA_ERROR_LEADING_HYPHEN | UIDNA_ERROR_TRAILING_HYPHEN | UIDNA_ERROR_HYPHEN_3_4;
    if (U_FAILURE(status) || (info.errors & ~ignored) != 0 || length <= 0 || size_t(length) > out.size()) {
        return std::nullopt;
    }
    out.resize(size_t(length));
    return out;
}

bool isSpecialScheme(std::string_view scheme) {
    return scheme == "ftp" || scheme == "file" || scheme == "http" || scheme == "https" || scheme == "ws" || scheme == "wss";
}

std::optional<uint16_t> defaultPort(std::string_view scheme) {
    if (scheme == "ftp") {
        return 21;
    }
    if (scheme == "http" || scheme == "ws") {
        return 80;
    }
    if (scheme == "https" || scheme == "wss") {
        return 443;
    }
    return std::nullopt;
}

void percentEncode(char32_t codePoint, EncodeSet set, std::string& out) {
    if (!inSet(codePoint, set)) {
        out += char(codePoint);
        return;
    }
    std::string bytes;
    appendUTF8(codePoint, bytes);
    for (char b : bytes) {
        out += '%';
        out += kUpperHex[uint8_t(b) >> 4];
        out += kUpperHex[uint8_t(b) & 15];
    }
}

std::u32string codePoints(const std::u16string& input) {
    std::u32string out;
    out.reserve(input.size());
    for (size_t i = 0; i < input.size(); i++) {
        const char16_t c = input[i];
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < input.size() && input[i + 1] >= 0xDC00 && input[i + 1] <= 0xDFFF) {
            out += char32_t(0x10000 + ((char32_t(c) - 0xD800) << 10) + (char32_t(input[i + 1]) - 0xDC00));
            i++;
        } else if (c >= 0xD800 && c <= 0xDFFF) {
            out += char32_t(0xFFFD);
        } else {
            out += char32_t(c);
        }
    }
    return out;
}

bool Record::special() const {
    return isSpecialScheme(this->scheme);
}

std::string Record::pathname() const {
    if (this->opaquePath) {
        return this->opaque;
    }
    std::string out;
    for (const std::string& segment : this->path) {
        out += '/';
        out += segment;
    }
    return out;
}

std::string Record::serialize(bool excludeFragment) const {
    std::string out = this->scheme + ":";
    if (this->host) {
        out += "//";
        if (!this->username.empty() || !this->password.empty()) {
            out += this->username;
            if (!this->password.empty()) {
                out += ':';
                out += this->password;
            }
            out += '@';
        }
        out += *this->host;
        if (this->port) {
            out += ':';
            out += std::to_string(*this->port);
        }
    } else if (!this->opaquePath && this->path.size() > 1 && this->path[0].empty()) {
        out += "/.";
    }
    out += this->pathname();
    if (this->query) {
        out += '?';
        out += *this->query;
    }
    if (!excludeFragment && this->fragment) {
        out += '#';
        out += *this->fragment;
    }
    return out;
}

std::string Record::origin() const {
    if (this->scheme == "http" || this->scheme == "https" || this->scheme == "ws" || this->scheme == "wss" || this->scheme == "ftp") {
        std::string out = this->scheme + "://" + this->host.value_or("");
        if (this->port) {
            out += ':';
            out += std::to_string(*this->port);
        }
        return out;
    }
    return "null";
}

std::optional<Record> parse(const std::u16string& raw, const Record* base) {
    if (raw.size() > kMaxURLLength) {
        return std::nullopt;
    }
    // Leading and trailing C0 controls and spaces go, then every ASCII tab or newline.
    std::u32string all = codePoints(raw);
    size_t begin = 0, end = all.size();
    while (begin < end && all[begin] <= 0x20) {
        begin++;
    }
    while (end > begin && all[end - 1] <= 0x20) {
        end--;
    }
    std::u32string in;
    in.reserve(end - begin);
    for (size_t i = begin; i < end; i++) {
        if (all[i] != 0x09 && all[i] != 0x0A && all[i] != 0x0D) {
            in += all[i];
        }
    }

    Record url;
    State state = State::SchemeStart;
    std::u32string buffer;
    bool atSignSeen = false, insideBrackets = false, passwordTokenSeen = false;
    auto at = [&](size_t i) -> char32_t { return i < in.size() ? in[i] : kEOF; };
    auto remainingStartsWith = [&](size_t p, char32_t c) { return at(p + 1) == c; };
    auto toASCII = [](const std::u32string& s) {
        std::string out;
        for (char32_t c : s) {
            out += char(c);
        }
        return out;
    };

    for (size_t pointer = 0;; pointer++) {
        const char32_t c = at(pointer);
        switch (state) {
        case State::SchemeStart:
            if (isAlpha(c)) {
                buffer += lower(c);
                state = State::Scheme;
            } else {
                state = State::NoScheme;
                pointer--;
            }
            break;
        case State::Scheme:
            if (isAlnum(c) || c == '+' || c == '-' || c == '.') {
                buffer += lower(c);
            } else if (c == ':') {
                url.scheme = toASCII(buffer);
                buffer.clear();
                if (url.scheme == "file") {
                    state = State::File;
                } else if (url.special() && base && base->scheme == url.scheme) {
                    state = State::SpecialRelativeOrAuthority;
                } else if (url.special()) {
                    state = State::SpecialAuthoritySlashes;
                } else if (remainingStartsWith(pointer, '/')) {
                    state = State::PathOrAuthority;
                    pointer++;
                } else {
                    url.opaquePath = true;
                    state = State::OpaquePath;
                }
            } else {
                buffer.clear();
                state = State::NoScheme;
                pointer = size_t(-1);
            }
            break;
        case State::NoScheme:
            if (!base || (base->opaquePath && c != '#')) {
                return std::nullopt;
            }
            if (base->opaquePath && c == '#') {
                url.scheme = base->scheme;
                url.opaquePath = true;
                url.opaque = base->opaque;
                url.query = base->query;
                url.fragment = std::string();
                state = State::Fragment;
            } else if (base->scheme != "file") {
                state = State::Relative;
                pointer--;
            } else {
                state = State::File;
                pointer--;
            }
            break;
        case State::SpecialRelativeOrAuthority:
            if (c == '/' && remainingStartsWith(pointer, '/')) {
                state = State::SpecialAuthorityIgnoreSlashes;
                pointer++;
            } else {
                state = State::Relative;
                pointer--;
            }
            break;
        case State::PathOrAuthority:
            if (c == '/') {
                state = State::Authority;
            } else {
                state = State::Path;
                pointer--;
            }
            break;
        case State::Relative:
            url.scheme = base->scheme;
            if (c == '/') {
                state = State::RelativeSlash;
            } else if (url.special() && c == '\\') {
                state = State::RelativeSlash;
            } else {
                url.username = base->username;
                url.password = base->password;
                url.host = base->host;
                url.port = base->port;
                url.path = base->path;
                url.query = base->query;
                if (c == '?') {
                    url.query = std::string();
                    state = State::Query;
                } else if (c == '#') {
                    url.fragment = std::string();
                    state = State::Fragment;
                } else if (c != kEOF) {
                    url.query.reset();
                    shortenPath(url);
                    state = State::Path;
                    pointer--;
                }
            }
            break;
        case State::RelativeSlash:
            if (url.special() && (c == '/' || c == '\\')) {
                state = State::SpecialAuthorityIgnoreSlashes;
            } else if (c == '/') {
                state = State::Authority;
            } else {
                url.username = base->username;
                url.password = base->password;
                url.host = base->host;
                url.port = base->port;
                state = State::Path;
                pointer--;
            }
            break;
        case State::SpecialAuthoritySlashes:
            if (c == '/' && remainingStartsWith(pointer, '/')) {
                state = State::SpecialAuthorityIgnoreSlashes;
                pointer++;
            } else {
                state = State::SpecialAuthorityIgnoreSlashes;
                pointer--;
            }
            break;
        case State::SpecialAuthorityIgnoreSlashes:
            if (c != '/' && c != '\\') {
                state = State::Authority;
                pointer--;
            }
            break;
        case State::Authority:
            if (c == '@') {
                if (atSignSeen) {
                    buffer.insert(0, U"%40");
                }
                atSignSeen = true;
                for (char32_t b : buffer) {
                    if (b == ':' && !passwordTokenSeen) {
                        passwordTokenSeen = true;
                        continue;
                    }
                    percentEncode(b, EncodeSet::Userinfo, passwordTokenSeen ? url.password : url.username);
                }
                buffer.clear();
            } else if (c == kEOF || c == '/' || c == '?' || c == '#' || (url.special() && c == '\\')) {
                if (atSignSeen && buffer.empty()) {
                    return std::nullopt;
                }
                pointer -= buffer.size() + 1;
                buffer.clear();
                state = State::Host;
            } else {
                buffer += c;
            }
            break;
        case State::Host:
            if (c == ':' && !insideBrackets) {
                if (buffer.empty()) {
                    return std::nullopt;
                }
                std::optional<std::string> host = parseHost(buffer, !url.special());
                if (!host) {
                    return std::nullopt;
                }
                url.host = std::move(host);
                buffer.clear();
                state = State::Port;
            } else if (c == kEOF || c == '/' || c == '?' || c == '#' || (url.special() && c == '\\')) {
                pointer--;
                if (url.special() && buffer.empty()) {
                    return std::nullopt;
                }
                std::optional<std::string> host = parseHost(buffer, !url.special());
                if (!host) {
                    return std::nullopt;
                }
                url.host = std::move(host);
                buffer.clear();
                state = State::PathStart;
            } else {
                if (c == '[') {
                    insideBrackets = true;
                }
                if (c == ']') {
                    insideBrackets = false;
                }
                buffer += c;
            }
            break;
        case State::Port:
            if (isDigit(c)) {
                buffer += c;
            } else if (c == kEOF || c == '/' || c == '?' || c == '#' || (url.special() && c == '\\')) {
                if (!buffer.empty()) {
                    uint32_t port = 0;
                    for (char32_t d : buffer) {
                        port = port * 10 + uint32_t(d - '0');
                        if (port > 65535) {
                            return std::nullopt;
                        }
                    }
                    url.port = defaultPort(url.scheme) == uint16_t(port) ? std::nullopt : std::optional<uint16_t>(uint16_t(port));
                    buffer.clear();
                }
                state = State::PathStart;
                pointer--;
            } else {
                return std::nullopt;
            }
            break;
        case State::File:
            url.scheme = "file";
            url.host = std::string();
            if (c == '/' || c == '\\') {
                state = State::FileSlash;
            } else if (base && base->scheme == "file") {
                url.host = base->host;
                url.path = base->path;
                url.query = base->query;
                if (c == '?') {
                    url.query = std::string();
                    state = State::Query;
                } else if (c == '#') {
                    url.fragment = std::string();
                    state = State::Fragment;
                } else if (c != kEOF) {
                    url.query.reset();
                    if (!startsWithWindowsDriveLetter(in, pointer)) {
                        shortenPath(url);
                    } else {
                        url.path.clear();
                    }
                    state = State::Path;
                    pointer--;
                }
            } else {
                state = State::Path;
                pointer--;
            }
            break;
        case State::FileSlash:
            if (c == '/' || c == '\\') {
                state = State::FileHost;
            } else {
                if (base && base->scheme == "file") {
                    url.host = base->host;
                    if (!startsWithWindowsDriveLetter(in, pointer) && !base->path.empty() &&
                        isWindowsDriveLetterString(base->path[0], true)) {
                        url.path.push_back(base->path[0]);
                    }
                }
                state = State::Path;
                pointer--;
            }
            break;
        case State::FileHost:
            if (c == kEOF || c == '/' || c == '\\' || c == '?' || c == '#') {
                pointer--;
                if (buffer.size() == 2 && isWindowsDriveLetter(buffer, 0, false)) {
                    state = State::Path;
                } else if (buffer.empty()) {
                    url.host = std::string();
                    state = State::PathStart;
                } else {
                    std::optional<std::string> host = parseHost(buffer, !url.special());
                    if (!host) {
                        return std::nullopt;
                    }
                    url.host = *host == "localhost" ? std::string() : *host;
                    buffer.clear();
                    state = State::PathStart;
                }
            } else {
                buffer += c;
            }
            break;
        case State::PathStart:
            if (url.special()) {
                state = State::Path;
                if (c != '/' && c != '\\') {
                    pointer--;
                }
            } else if (c == '?') {
                url.query = std::string();
                state = State::Query;
            } else if (c == '#') {
                url.fragment = std::string();
                state = State::Fragment;
            } else if (c != kEOF) {
                state = State::Path;
                if (c != '/') {
                    pointer--;
                }
            }
            break;
        case State::Path:
            if (c == kEOF || c == '/' || (url.special() && c == '\\') || c == '?' || c == '#') {
                const std::string segment = toASCII(buffer);
                const bool slash = c == '/' || (url.special() && c == '\\');
                if (isDoubleDot(segment)) {
                    shortenPath(url);
                    if (!slash) {
                        url.path.emplace_back();
                    }
                } else if (isSingleDot(segment) && !slash) {
                    url.path.emplace_back();
                } else if (!isSingleDot(segment)) {
                    std::string s = segment;
                    if (url.scheme == "file" && url.path.empty() && isWindowsDriveLetterString(s, false)) {
                        s[1] = ':';
                    }
                    url.path.push_back(std::move(s));
                }
                buffer.clear();
                if (c == '?') {
                    url.query = std::string();
                    state = State::Query;
                } else if (c == '#') {
                    url.fragment = std::string();
                    state = State::Fragment;
                }
            } else {
                std::string encoded;
                percentEncode(c, EncodeSet::Path, encoded);
                for (char e : encoded) {
                    buffer += char32_t(uint8_t(e));
                }
            }
            break;
        case State::OpaquePath:
            if (c == '?') {
                url.query = std::string();
                state = State::Query;
            } else if (c == '#') {
                url.fragment = std::string();
                state = State::Fragment;
            } else if (c != kEOF) {
                percentEncode(c, EncodeSet::C0Control, url.opaque);
            }
            break;
        case State::Query:
            if (c == '#' || c == kEOF) {
                const EncodeSet set = url.special() ? EncodeSet::SpecialQuery : EncodeSet::Query;
                for (char32_t b : buffer) {
                    percentEncode(b, set, *url.query);
                }
                buffer.clear();
                if (c == '#') {
                    url.fragment = std::string();
                    state = State::Fragment;
                }
            } else {
                buffer += c;
            }
            break;
        case State::Fragment:
            if (c != kEOF) {
                percentEncode(c, EncodeSet::Fragment, *url.fragment);
            }
            break;
        }
        // The standard's loop: done when, after the state ran, the pointer is at the EOF code point (a state that
        // stepped back from it runs the next state on it again).
        if (pointer == in.size()) {
            break;
        }
    }
    return url;
}

} // namespace wr::url
