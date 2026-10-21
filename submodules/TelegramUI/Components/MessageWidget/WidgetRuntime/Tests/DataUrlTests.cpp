// data: URLs (M1c plan, Task 3): WHATWG Fetch's data: URL processor, which decides what WidgetContainer can load.
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "Sources/Render/DataUrl.h"
#include "Tests/wr_test.h"

namespace {

std::vector<uint8_t> bytes(std::string_view text) {
    return std::vector<uint8_t>(text.begin(), text.end());
}

bool parsesTo(std::string_view url, std::string_view mimeType, const std::vector<uint8_t>& body) {
    std::optional<wr::DataUrl> parsed = wr::parseDataUrl(url);
    return parsed && parsed->mimeType == mimeType && parsed->bytes == body;
}

} // namespace

WR_TEST(testDataUrlVectors) {
    const std::vector<uint8_t> zeroOneTwo = {0x00, 0x01, 0x02};
    CHECK(parsesTo("data:image/png;base64,AAEC", "image/png", zeroOneTwo));
    CHECK(parsesTo("DATA:IMAGE/PNG;BASE64,AAEC", "image/png", zeroOneTwo));
    CHECK(parsesTo("data:image/svg+xml,%3Csvg%2F%3E", "image/svg+xml", bytes("<svg/>")));
    CHECK(parsesTo("data:image/svg+xml;charset=utf-8,<svg/>", "image/svg+xml", bytes("<svg/>")));
    CHECK(parsesTo(" data:image/png;base64,AAEC ", "image/png", zeroOneTwo));
    CHECK(parsesTo("da\tta:image/png;base64,AAEC", "image/png", zeroOneTwo));
    CHECK(parsesTo("data:image/png;base64, AA EC", "image/png", zeroOneTwo));
    CHECK(parsesTo("data:,hello", "text/plain", bytes("hello")));
    CHECK(!wr::parseDataUrl("data:image/png;base64,!!!"));
    CHECK(!wr::parseDataUrl("data:image/png"));
    CHECK(!wr::parseDataUrl("http://x/"));
}

// The rest of the processor: what the URL parser removes first, the fragment, the base64 suffix and padding, and the
// MIME type's essence.
WR_TEST(testDataUrlProcessorDetails) {
    const std::vector<uint8_t> zeroOneTwo = {0x00, 0x01, 0x02};
    // Leading and trailing C0 controls go, and newlines anywhere.
    CHECK(parsesTo(std::string("\x01\x1f data:image/png;base64,AA\nEC\r") + '\0', "image/png", zeroOneTwo));
    // The fragment is not part of the body.
    CHECK(parsesTo("data:text/plain,a#b", "text/plain", bytes("a")));
    CHECK(parsesTo("data:image/png;base64,AAEC#x", "image/png", zeroOneTwo));
    // Spaces before "base64", and its case; ASCII whitespace around the type.
    CHECK(parsesTo("data:image/png;  BaSe64,AAEC", "image/png", zeroOneTwo));
    CHECK(parsesTo("data: image/PNG ;base64,AAEC", "image/png", zeroOneTwo));
    // Parameters do not reach the essence; "base64" that is not the final parameter is one of them.
    CHECK(parsesTo("data:image/png;base64;x=y,AAEC", "image/png", bytes("AAEC")));
    CHECK(parsesTo("data:image/gif;name=a.gif;base64,AAEC", "image/gif", zeroOneTwo));
    // Forgiving-base64: padding, whitespace, a percent-decoded body, and the lengths that fail.
    CHECK(parsesTo("data:;base64,AAE=", "text/plain", std::vector<uint8_t>{0x00, 0x01}));
    CHECK(parsesTo("data:;base64,AA==", "text/plain", std::vector<uint8_t>{0x00}));
    CHECK(parsesTo("data:;base64,AA", "text/plain", std::vector<uint8_t>{0x00}));
    CHECK(parsesTo("data:;base64,A%41EC", "text/plain", zeroOneTwo));
    CHECK(parsesTo("data:;base64,", "text/plain", {}));
    CHECK(!wr::parseDataUrl("data:;base64,AAECA"));
    CHECK(!wr::parseDataUrl("data:;base64,AA=E"));
    CHECK(!wr::parseDataUrl("data:;base64,AAE=="));
    // An unparsable type is text/plain; the body is kept.
    CHECK(parsesTo("data:image,x", "text/plain", bytes("x")));
    CHECK(parsesTo("data:image/,x", "text/plain", bytes("x")));
    CHECK(parsesTo("data:/png,x", "text/plain", bytes("x")));
    CHECK(parsesTo("data:im(age/png,x", "text/plain", bytes("x")));
    CHECK(parsesTo("data:;charset=utf-8,x", "text/plain", bytes("x")));
    // Percent-decoding keeps a '%' that does not start an escape.
    CHECK(parsesTo("data:,%zz%4", "text/plain", bytes("%zz%4")));
    // Only the "data" scheme, matched whole.
    CHECK(!wr::parseDataUrl("dat:image/png,x"));
    CHECK(!wr::parseDataUrl("xdata:image/png,x"));
    CHECK(!wr::parseDataUrl(""));
    CHECK(!wr::parseDataUrl("data"));
    CHECK(parsesTo("data:,", "text/plain", {}));
}
