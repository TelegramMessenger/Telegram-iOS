// widget-sandbox v0.3.0, limit.image-pixels (url-policy.ts dataImageSize and checkUrl, and its tests in
// url-policy-images.test.ts): a data: image's size is read from its bytes as a decoder would, by its signature whatever
// type it declares; past 1024² pixels it is refused (the 48 px placeholder, as a refused URL), and bytes of none of the
// profile's formats are broken (no decoder takes them: `error`). The body is read as fetch decodes it.
#include <string>
#include <vector>

#include "Sources/Host/CSSPolicy.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;
namespace policy = wr::css::policy;

namespace {

std::string base64(const std::vector<uint8_t>& bytes) {
    static const char* const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out;
    for (size_t i = 0; i < bytes.size(); i += 3) {
        const uint32_t a = bytes[i], b = i + 1 < bytes.size() ? bytes[i + 1] : 0, c = i + 2 < bytes.size() ? bytes[i + 2] : 0;
        out += alphabet[a >> 2];
        out += alphabet[((a & 3) << 4) | (b >> 4)];
        out += i + 1 < bytes.size() ? alphabet[((b & 15) << 2) | (c >> 6)] : '=';
        out += i + 2 < bytes.size() ? alphabet[c & 63] : '=';
    }
    return out;
}

void append(std::vector<uint8_t>& to, std::initializer_list<int> bytes) {
    for (int b : bytes) {
        to.push_back(uint8_t(b));
    }
}

/// The signature and IHDR of a PNG claiming `width` × `height`: all a decoder reads before it allocates.
std::string pngHeader(uint32_t width, uint32_t height) {
    std::vector<uint8_t> b;
    append(b, {0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52});
    for (uint32_t n : {width, height}) {
        append(b, {int(n >> 24), int((n >> 16) & 255), int((n >> 8) & 255), int(n & 255)});
    }
    append(b, {8, 6, 0, 0, 0});
    return "data:image/png;base64," + base64(b);
}

/// A GIF89a of a `screen` logical screen whose first frame is `frame` ({left, top, width, height}), after an extension.
std::string gif(uint16_t sw, uint16_t sh, std::vector<uint16_t> frame) {
    std::vector<uint8_t> b = {'G', 'I', 'F', '8', '9', 'a'};
    append(b, {sw & 255, sw >> 8, sh & 255, sh >> 8, 0, 0, 0, 0x21, 0xf9, 4, 0, 0, 0, 0, 0});
    if (!frame.empty()) {
        b.push_back(0x2c);
        for (uint16_t v : frame) {
            append(b, {v & 255, v >> 8});
        }
        append(b, {0, 2, 2, 0x4c, 0x01, 0});
    }
    b.push_back(0x3b);
    return "data:image/gif;base64," + base64(b);
}

/// A JPEG whose frame header (16 × 16) comes after APP1 segments of these lengths.
std::vector<uint8_t> jpegWithSegments(std::initializer_list<int> lengths) {
    std::vector<uint8_t> b = {0xff, 0xd8};
    for (int length : lengths) {
        append(b, {0xff, 0xe1, (length + 2) >> 8, (length + 2) & 255});
        b.insert(b.end(), size_t(length), 0x41);
    }
    append(b, {0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03});
    return b;
}

std::string sizeOf(const std::string& url) {
    const auto size = policy::dataImageSize(url);
    return size ? std::to_string(size->first) + "x" + std::to_string(size->second) : std::string("none");
}

const char* name(policy::ImageSource source) {
    switch (source) {
    case policy::ImageSource::Kept: return "kept";
    case policy::ImageSource::Refused: return "refused";
    case policy::ImageSource::Broken: return "broken";
    }
    return "?";
}

std::string decided(const std::string& url) {
    return name(policy::imageSource(url));
}

} // namespace

/// Past 1024² pixels an image is refused, whatever the format says it is: PNG's IHDR, GIF's logical screen.
WR_TEST(testAnImageClaimingTooManyPixelsIsRefused) {
    CHECK_EQ(sizeOf(pngHeader(4096, 4096)), std::string("4096x4096"));
    CHECK_EQ(decided(pngHeader(1024, 1024)), std::string("kept"));
    CHECK_EQ(decided(pngHeader(4096, 256)), std::string("kept"));
    CHECK_EQ(decided(pngHeader(1025, 1024)), std::string("refused"));
    CHECK_EQ(decided(pngHeader(4096, 4096)), std::string("refused"));
    CHECK_EQ(decided(pngHeader(65535, 65535)), std::string("refused"));
    CHECK_EQ(decided(gif(65535, 65535, {0, 0, 1, 1})), std::string("refused"));
}

/// A GIF is bounded by its first frame too, where that frame reaches past the logical screen; one with no frame, or with
/// thousands of tiny extensions before it, is broken.
WR_TEST(testAGifIsBoundedByItsFirstFrame) {
    CHECK_EQ(sizeOf(gif(100, 100, {10, 10, 5, 5})), std::string("100x100"));
    CHECK_EQ(sizeOf(gif(100, 100, {90, 0, 20, 10})), std::string("110x100"));
    CHECK_EQ(sizeOf(gif(1, 1, {0, 0, 8192, 8192})), std::string("8192x8192"));
    CHECK_EQ(decided(gif(1, 1, {0, 0, 8192, 8192})), std::string("refused"));
    CHECK_EQ(decided(gif(1, 1, {})), std::string("broken"));
    std::vector<uint8_t> crowded = {'G', 'I', 'F', '8', '9', 'a', 1, 0, 1, 0, 0, 0, 0};
    for (int i = 0; i < 20000; i++) {
        append(crowded, {0x21, 0xfe, 0});
    }
    append(crowded, {0x2c, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 2, 0x4c, 0x01, 0, 0x3b});
    CHECK_EQ(decided("data:image/gif;base64," + base64(crowded)), std::string("broken"));
}

/// A whole lossless WebP of 28 bytes (1 × 1), shorter than the other chunks need.
WR_TEST(testAShortLosslessWebP) {
    const std::string webp = "data:image/webp;base64,UklGRhQAAABXRUJQVlA4TAgAAAAvAAAAAIiICA==";
    CHECK_EQ(sizeOf(webp), std::string("1x1"));
    CHECK_EQ(decided(webp), std::string("kept"));
}

/// The body as fetch decodes it: the URL's fragment left out, percent-decoding, base64 with spaces.
WR_TEST(testTheBodyIsReadAsFetchDecodesIt) {
    const std::string png = pngHeader(2, 3);
    const std::string body = png.substr(png.find(',') + 1);
    std::string spaced;
    for (size_t i = 0; i < body.size(); i++) {
        spaced += body[i];
        if (i % 4 == 3) {
            spaced += ' ';
        }
    }
    CHECK_EQ(sizeOf("data:image/png;base64," + spaced + "#part"), std::string("2x3"));
    std::string escaped;
    for (char c : body) {
        escaped += c == '+' ? "%2B" : c == '/' ? "%2F" : std::string(1, c);
    }
    CHECK_EQ(sizeOf("data:image/png;base64," + escaped), std::string("2x3"));
    std::string percent;
    static const char* const hex = "0123456789abcdef";
    const std::vector<uint8_t> raw = {0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52,
                                      0, 0, 0, 2, 0, 0, 0, 3, 8, 6, 0, 0, 0};
    for (uint8_t b : raw) {
        percent += std::string("%") + hex[b >> 4] + hex[b & 15];
    }
    CHECK_EQ(sizeOf("data:image/png," + percent), std::string("2x3"));
}

/// The bytes pick the decoder, not the declared type: BMP bytes, or none, behind image/png are broken.
WR_TEST(testBytesOfAnotherFormatAreBroken) {
    std::vector<uint8_t> bmp = {0x42, 0x4d};
    bmp.insert(bmp.end(), 52, 0);
    CHECK_EQ(decided("data:image/png;base64," + base64(bmp)), std::string("broken"));
    CHECK_EQ(decided("data:image/png;base64,AAAA"), std::string("broken"));
    CHECK_EQ(decided("data:image/png;base64,!!"), std::string("broken"));
    CHECK_EQ(decided("data:image/png;base64,"), std::string("broken"));
    // A JPEG's bytes behind image/png are a JPEG.
    CHECK_EQ(sizeOf("data:image/png;base64," + base64(jpegWithSegments({10}))), std::string("16x16"));
    // Not a data: image of the profile's types at all: refused, as before.
    CHECK_EQ(decided("https://example.org/p.png"), std::string("refused"));
    CHECK_EQ(decided("data:image/bmp;base64," + base64(bmp)), std::string("refused"));
}

/// A JPEG's frame header past the segments before it, and no further than 64 KB.
WR_TEST(testAJpegsSizeIsFoundWithin64KB) {
    CHECK_EQ(sizeOf("data:image/jpeg;base64," + base64(jpegWithSegments({30000, 32000}))), std::string("16x16"));
    CHECK_EQ(decided("data:image/jpeg;base64," + base64(jpegWithSegments({65533}))), std::string("broken"));
    std::vector<uint8_t> fill = {0xff, 0xd8};
    fill.insert(fill.end(), 2000, 0xff);
    append(fill, {0xc0, 0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03});
    CHECK_EQ(decided("data:image/jpeg;base64," + base64(fill)), std::string("broken"));
}

/// The DOM and the layout agree: an image claiming 4096² loads as the 48 px placeholder, and bytes of no format error.
WR_TEST(testTheDomFollowsTheDecision) {
    RenderEnv env("<!doctype html><html><head></head><body></body></html>");
    const std::pair<std::string, std::string> rows[] = {
        {pngHeader(4096, 4096), "load,48"},
        {"data:image/png;base64,AAAA", "error,0"},
    };
    std::string wrong;
    for (const auto& [src, want] : rows) {
        env.env().eval("var r = document.createElement('img'); var got = [];"
                       " r.onload = () => got.push('load'); r.onerror = () => got.push('error'); r.src = '" + src + "'; 1");
        env.env().drain();
        const std::string got = env.env().eval("[got.join('+'), r.naturalWidth].join()");
        if (got != want) {
            wrong += " [" + src.substr(0, 40) + " → " + got + ", want " + want + "]";
        }
    }
    CHECK_EQ(wrong, std::string(""));
}
