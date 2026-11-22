// widget-sandbox v0.3.0's dataImageSize (url-policy.ts): the size a decoder would give a data: image, by its signature,
// the body read as fetch decodes it. A pure function of its text (CSSPolicy.h's rule), and every scan is bounded
// (64 KB, 1024 JPEG steps, 256 GIF extensions and 4096 sub-blocks).
#include <algorithm>
#include <string>
#include <vector>

#include "Sources/Host/CSSPolicy.h"

namespace wr::css::policy {

namespace {

/// How far into an image what gives its size is looked for (upstream's HEADER_SCAN_BYTES).
constexpr size_t kHeaderScanBytes = 64 * 1024;

bool isFetchSpace(char c) {
    return c == '\t' || c == '\n' || c == '\f' || c == '\r' || c == ' ';
}

int hexValue(char c) {
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

int base64Value(char c) {
    if (c >= 'A' && c <= 'Z') {
        return c - 'A';
    }
    if (c >= 'a' && c <= 'z') {
        return c - 'a' + 26;
    }
    if (c >= '0' && c <= '9') {
        return c - '0' + 52;
    }
    return c == '+' ? 62 : c == '/' ? 63 : -1;
}

/// A data: URL's body as fetch decodes it (percent-decoding, then forgiving base64 when `;base64`), decoded from its
/// start as far as the reads go, never past what a scan may read. The URL's fragment is not the body's.
class DataBody {
public:
    explicit DataBody(std::string_view url) {
        const size_t hash = url.find('#');
        const std::string_view data = hash == std::string_view::npos ? url : url.substr(0, hash);
        const size_t comma = data.find(',');
        if (comma == std::string_view::npos) {
            m_failed = true;
            return;
        }
        // `;[\t\n\f\r ]*base64$` over the part before the comma, its trailing white space trimmed.
        std::string_view head = data.substr(0, comma);
        while (!head.empty() && isFetchSpace(head.back())) {
            head.remove_suffix(1);
        }
        if (head.size() >= 6) {
            std::string tail(head.substr(head.size() - 6));
            for (char& c : tail) {
                c = c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c;
            }
            if (tail == "base64") {
                std::string_view before = head.substr(0, head.size() - 6);
                while (!before.empty() && isFetchSpace(before.back())) {
                    before.remove_suffix(1);
                }
                m_base64 = !before.empty() && before.back() == ';';
            }
        }
        m_body = data.substr(comma + 1);
    }

    /// Whether bytes from…to can be read.
    bool has(size_t to) {
        while (m_bytes.size() < to && !m_failed && !m_ended) {
            this->decodeMore();
        }
        return to <= m_bytes.size();
    }
    uint32_t at(size_t i) const { return m_bytes[i]; }

private:
    /// The next byte of the percent-decoded body, or -1 at its end.
    int nextByte() {
        if (m_read >= m_body.size()) {
            return -1;
        }
        const char c = m_body[m_read];
        if (c == '%' && m_read + 2 < m_body.size()) {
            const int high = hexValue(m_body[m_read + 1]);
            const int low = hexValue(m_body[m_read + 2]);
            if (high >= 0 && low >= 0) {
                m_read += 3;
                return high * 16 + low;
            }
        }
        m_read++;
        return uint8_t(c);
    }

    void decodeMore() {
        // Enough for any scan: the furthest read is a header past 64 KB of segments.
        if (m_bytes.size() >= kHeaderScanBytes + 16) {
            m_ended = true;
            return;
        }
        if (!m_base64) {
            const int b = this->nextByte();
            if (b < 0) {
                m_ended = true;
            } else {
                m_bytes.push_back(uint8_t(b));
            }
            return;
        }
        // Forgiving base64 a group of four at a time: white space skipped, padding only at the end, a short last group
        // of two or three taken as fetch takes it, one character alone or anything else a failure.
        int group[4];
        int count = 0;
        int padding = 0;
        while (count + padding < 4) {
            const int b = this->nextByte();
            if (b < 0) {
                break;
            }
            if (isFetchSpace(char(b))) {
                continue;
            }
            if (b == '=') {
                padding++;
                continue;
            }
            const int v = padding ? -1 : base64Value(char(b));
            if (v < 0) {
                m_failed = true;
                return;
            }
            group[count++] = v;
        }
        if (padding && this->restHasData()) {
            m_failed = true;
            return;
        }
        if (count == 1 || (count + padding < 4 && padding)) {
            m_failed = count != 0 || padding != 0;
            m_ended = true;
            return;
        }
        if (count >= 2) {
            m_bytes.push_back(uint8_t((group[0] << 2) | (group[1] >> 4)));
        }
        if (count >= 3) {
            m_bytes.push_back(uint8_t(((group[1] & 15) << 4) | (group[2] >> 2)));
        }
        if (count == 4) {
            m_bytes.push_back(uint8_t(((group[2] & 3) << 6) | group[3]));
        }
        if (count < 4) {
            m_ended = true;
        }
    }

    /// Anything but white space left in the body (after a padding, which ends it).
    bool restHasData() {
        for (;;) {
            const int b = this->nextByte();
            if (b < 0) {
                return false;
            }
            if (!isFetchSpace(char(b))) {
                return true;
            }
        }
    }

    std::string_view m_body;
    size_t m_read = 0;
    bool m_base64 = false;
    bool m_failed = false;
    bool m_ended = false;
    std::vector<uint8_t> m_bytes;
};

} // namespace

std::optional<std::pair<uint32_t, uint32_t>> dataImageSize(std::string_view url) {
    DataBody body(url);
    const auto u16be = [&](size_t i) { return (body.at(i) << 8) | body.at(i + 1); };
    const auto le16 = [&](size_t i) { return body.at(i) | (body.at(i + 1) << 8); };
    const auto u24le = [&](size_t i) { return body.at(i) | (body.at(i + 1) << 8) | (body.at(i + 2) << 16); };
    const auto is = [&](size_t i, std::string_view magic) {
        if (!body.has(i + magic.size())) {
            return false;
        }
        for (size_t k = 0; k < magic.size(); k++) {
            if (body.at(i + k) != uint8_t(magic[k])) {
                return false;
            }
        }
        return true;
    };
    using Size = std::pair<uint32_t, uint32_t>;
    // PNG: the signature, then IHDR's width and height.
    if (is(0, std::string_view("\x89PNG\r\n\x1a\n", 8)) && is(12, "IHDR") && body.has(24)) {
        return Size{uint32_t(u16be(16)) * 65536 + uint32_t(u16be(18)), uint32_t(u16be(20)) * 65536 + uint32_t(u16be(22))};
    }
    // GIF: the logical screen, grown to the first frame where that frame reaches past it.
    if ((is(0, "GIF87a") || is(0, "GIF89a")) && body.has(13)) {
        const uint32_t screenWidth = le16(6), screenHeight = le16(8);
        size_t blocks = 0;
        size_t i = 13 + ((body.at(10) & 0x80) ? size_t(3) << ((body.at(10) & 7) + 1) : 0);
        for (int extensions = 0; i < kHeaderScanBytes && extensions < 256; extensions++) {
            if (!body.has(i + 2)) {
                return std::nullopt;
            }
            if (body.at(i) == 0x2c) {
                if (!body.has(i + 9)) {
                    return std::nullopt;
                }
                return Size{std::max(screenWidth, uint32_t(le16(i + 1) + le16(i + 5))), std::max(screenHeight, uint32_t(le16(i + 3) + le16(i + 7)))};
            }
            // An extension (introducer, label, its sub-blocks up to the empty one); anything else, the trailer included:
            // no frame.
            if (body.at(i) != 0x21) {
                return std::nullopt;
            }
            for (i += 2;;) {
                if (i >= kHeaderScanBytes || ++blocks > 4096 || !body.has(i + 1)) {
                    return std::nullopt;
                }
                const uint32_t n = body.at(i);
                i += 1 + n;
                if (n == 0) {
                    break;
                }
            }
        }
        return std::nullopt;
    }
    // WebP: its first chunk, the canvas of an extended one.
    if (is(0, "RIFF") && is(8, "WEBP")) {
        if (is(12, "VP8X") && body.has(30)) {
            return Size{1 + u24le(24), 1 + u24le(27)};
        }
        if (is(12, "VP8L") && body.has(25) && body.at(20) == 0x2f) {
            return Size{1 + (body.at(21) | ((body.at(22) & 0x3f) << 8)), 1 + ((body.at(22) >> 6) | (body.at(23) << 2) | ((body.at(24) & 0x0f) << 10))};
        }
        if (is(12, "VP8 ") && body.has(30)) {
            return Size{(body.at(26) | (body.at(27) << 8)) & 0x3fff, (body.at(28) | (body.at(29) << 8)) & 0x3fff};
        }
        return std::nullopt;
    }
    // JPEG: the first frame header (SOFn) past the segments before it, in at most 1024 steps.
    if (is(0, "\xff\xd8") && body.has(4)) {
        size_t i = 2;
        for (int steps = 0; i + 9 <= kHeaderScanBytes && steps < 1024; steps++) {
            if (!body.has(i + 4) || body.at(i) != 0xff) {
                return std::nullopt;
            }
            const uint32_t marker = body.at(i + 1);
            if (marker == 0xff) {
                i++;
                continue;
            }
            if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd8)) {
                i += 2;
                continue;
            }
            if (marker >= 0xc0 && marker <= 0xcf && marker != 0xc4 && marker != 0xc8 && marker != 0xcc) {
                if (!body.has(i + 9)) {
                    return std::nullopt;
                }
                return Size{uint32_t(u16be(i + 7)), uint32_t(u16be(i + 5))};
            }
            if (marker == 0xd9 || marker == 0xda) {
                return std::nullopt;
            }
            i += 2 + size_t(u16be(i + 2));
        }
    }
    return std::nullopt;
}

} // namespace wr::css::policy
