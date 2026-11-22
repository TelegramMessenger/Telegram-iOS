#include "Tests/FakeRenderHost.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <vector>

#include "Sources/Canvas/CanvasOps.h"
#include "Sources/Render/WidgetContainer.h"

namespace wr_test {

namespace {

size_t& liveFontCount() {
    static size_t count = 0;
    return count;
}

size_t& liveImageCount() {
    static size_t count = 0;
    return count;
}

class FakeFont final : public wr::HostFont {
public:
    explicit FakeFont(double size) : m_size(size) { liveFontCount()++; }
    ~FakeFont() override { liveFontCount()--; }
    FakeFont(const FakeFont&) = delete;
    FakeFont& operator=(const FakeFont&) = delete;
    double size() const { return m_size; }

private:
    double m_size;
};

class FakeImage final : public wr::HostImage {
public:
    FakeImage() { liveImageCount()++; }
    ~FakeImage() override { liveImageCount()--; }
    FakeImage(const FakeImage&) = delete;
    FakeImage& operator=(const FakeImage&) = delete;
};

uint32_t bigEndian32(std::span<const uint8_t> bytes, size_t offset) {
    return (uint32_t(bytes[offset]) << 24) | (uint32_t(bytes[offset + 1]) << 16) | (uint32_t(bytes[offset + 2]) << 8) |
           uint32_t(bytes[offset + 3]);
}

uint32_t littleEndian16(std::span<const uint8_t> bytes, size_t offset) {
    return uint32_t(bytes[offset]) | (uint32_t(bytes[offset + 1]) << 8);
}

bool startsWith(std::span<const uint8_t> bytes, const char* prefix, size_t length) {
    return bytes.size() >= length && std::memcmp(bytes.data(), prefix, length) == 0;
}

char asciiUpper(char c) {
    return c >= 'a' && c <= 'z' ? char(c - 'a' + 'A') : c;
}

char asciiLower(char c) {
    return c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c;
}

bool isAsciiWhitespace(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

} // namespace

size_t FakeRenderHost::liveFonts() {
    return liveFontCount();
}

size_t FakeRenderHost::liveImages() {
    return liveImageCount();
}

std::shared_ptr<const wr::HostFont> FakeRenderHost::createFont(const litehtml::font_description& description,
                                                               litehtml::font_metrics& metrics) {
    fontsCreated++;
    metrics.font_size = description.size;
    metrics.ascent = 12;
    metrics.descent = 4;
    metrics.height = 16;
    metrics.x_height = 6;
    metrics.ch_width = 8;
    metrics.draw_spaces = false;
    metrics.sub_shift = 2;
    metrics.super_shift = 4;
    auto font = std::make_shared<FakeFont>(double(description.size.value()));
    createdFonts.push_back({description, font});
    return font;
}

double FakeRenderHost::textWidth(const wr::HostFont&, std::string_view utf8) {
    textWidthCalls++;
    if (onTextWidth) {
        onTextWidth();
    }
    return 8.0 * double(utf8.size());
}

namespace {

/// Breaks between code points, never inside one (CoreTextRenderHost's breaker breaks between composed character
/// sequences, coarser still); each byte 8 px wide as textWidth measures it (fidelity plan, Task 5: word-break and
/// overflow-wrap: anywhere reach the breaker). At least one code point per line, so a fit always advances.
class FakeTextBreaker final : public litehtml::text_breaker {
public:
    explicit FakeTextBreaker(const std::string& text) {
        for (size_t at = 0; at < text.size();) {
            const uint8_t lead = uint8_t(text[at]);
            const size_t bytes = std::min(text.size() - at, size_t(lead < 0xC0 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4));
            m_widest = std::max(m_widest, bytes);
            at += bytes;
            m_ends.push_back(at);
        }
    }
    size_t fit(size_t start, litehtml::pixel_t width) override {
        const size_t room = size_t(std::max(0.0f, float(width)) / 8.0f);
        const auto first = std::upper_bound(m_ends.begin(), m_ends.end(), start);
        if (first == m_ends.end()) {
            return start;
        }
        const auto past = std::upper_bound(first, m_ends.end(), start + room);
        return past == first ? *first : *(past - 1);
    }
    litehtml::pixel_t minimum_width() override { return litehtml::pixel_t(8.0f * float(m_widest)); }

private:
    /// Where each code point ends, in bytes.
    std::vector<size_t> m_ends;
    size_t m_widest = 0;
};

} // namespace

std::shared_ptr<litehtml::text_breaker> FakeRenderHost::createTextBreaker(const wr::HostFont&, const std::string& text) {
    return std::make_shared<FakeTextBreaker>(text);
}

wr::ShapedText FakeRenderHost::shape(const wr::HostFont&, std::string_view utf8) {
    shapeCalls++;
    wr::ShapedText shaped;
    shaped.glyphs.reserve(utf8.size());
    shaped.advances.reserve(utf8.size());
    for (char c : utf8) {
        shaped.glyphs.push_back(uint32_t(uint8_t(c)));
        shaped.advances.push_back(8.0f);
    }
    return shaped;
}

std::vector<float> FakeRenderHost::caretOffsets(const wr::HostFont&, std::string_view utf8) {
    std::vector<float> offsets{0.0f};
    size_t i = 0;
    while (i < utf8.size()) {
        const uint8_t lead = uint8_t(utf8[i]);
        const size_t bytes = lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
        const float start = offsets.back();
        i = std::min(utf8.size(), i + bytes);
        if (bytes == 4) {
            offsets.push_back(start); // inside the surrogate pair
        }
        offsets.push_back(8.0f * float(i));
    }
    return offsets;
}

void FakeRenderHost::transformText(std::string& utf8, litehtml::text_transform transform) {
    switch (transform) {
    case litehtml::text_transform_uppercase:
        std::transform(utf8.begin(), utf8.end(), utf8.begin(), asciiUpper);
        break;
    case litehtml::text_transform_lowercase:
        std::transform(utf8.begin(), utf8.end(), utf8.begin(), asciiLower);
        break;
    case litehtml::text_transform_capitalize: {
        bool wordStart = true;
        for (char& c : utf8) {
            if (wordStart) {
                c = asciiUpper(c);
            }
            wordStart = isAsciiWhitespace(c);
        }
        break;
    }
    case litehtml::text_transform_none:
        break;
    }
}

std::optional<wr::DecodedImage> FakeRenderHost::decodeImage(std::string_view mimeType, std::span<const uint8_t> bytes) {
    decodedMimeTypes.emplace_back(mimeType);
    double width = 0;
    double height = 0;
    // PNG: the signature, then the IHDR chunk (length, type, width, height; big-endian).
    if (startsWith(bytes, "\x89PNG\r\n\x1a\n", 8) && bytes.size() >= 24 && std::memcmp(bytes.data() + 12, "IHDR", 4) == 0) {
        width = bigEndian32(bytes, 16);
        height = bigEndian32(bytes, 20);
    } else if ((startsWith(bytes, "GIF87a", 6) || startsWith(bytes, "GIF89a", 6)) && bytes.size() >= 10) {
        // GIF: the logical screen descriptor's width and height (little-endian) after the 6-byte header.
        width = littleEndian16(bytes, 6);
        height = littleEndian16(bytes, 8);
    } else if (mimeType == "image/svg+xml") {
        // SVG: the root's width and height attributes, as whole numbers.
        const std::string_view text(reinterpret_cast<const char*>(bytes.data()), bytes.size());
        if (text != wr::WidgetContainer::placeholderSVG()) {
            foreignSVGs++;
        }
        const size_t root = text.find("<svg");
        const std::string_view tag = root == std::string_view::npos ? std::string_view() : text.substr(root, text.find('>', root) - root);
        const auto attribute = [&](std::string_view name) {
            const size_t at = tag.find(std::string(" ") + std::string(name) + "=\"");
            double value = 0;
            for (size_t i = at == std::string_view::npos ? tag.size() : at + name.size() + 3; i < tag.size() && tag[i] >= '0' && tag[i] <= '9'; i++) {
                value = value * 10 + (tag[i] - '0');
            }
            return value;
        };
        width = attribute("width");
        height = attribute("height");
        if (width <= 0 || height <= 0) {
            return std::nullopt;
        }
    } else {
        return std::nullopt;
    }
    return wr::DecodedImage{std::make_shared<FakeImage>(), width, height};
}

bool FakeRenderHost::pathContains(const litehtml::vector_path& path, double x, double y) {
    if (path.points.size() < 2) {
        return false;
    }
    double minX = path.points[0], maxX = path.points[0];
    double minY = path.points[1], maxY = path.points[1];
    for (size_t i = 0; i + 1 < path.points.size(); i += 2) {
        minX = std::min(minX, double(path.points[i]));
        maxX = std::max(maxX, double(path.points[i]));
        minY = std::min(minY, double(path.points[i + 1]));
        maxY = std::max(maxY, double(path.points[i + 1]));
    }
    return x >= minX && x <= maxX && y >= minY && y <= maxY;
}

// The fake canvas.

namespace {

std::vector<FakeCanvas*>& liveCanvasList() {
    static std::vector<FakeCanvas*> list;
    return list;
}

std::string number(double v) {
    char buffer[32];
    std::snprintf(buffer, sizeof buffer, "%g", std::round(v * 100) / 100);
    return buffer;
}

std::string boundsOf(std::span<const float> points) {
    if (points.size() < 2) {
        return "0,0 0x0";
    }
    double minX = points[0], maxX = points[0], minY = points[1], maxY = points[1];
    for (size_t i = 0; i + 1 < points.size(); i += 2) {
        minX = std::min(minX, double(points[i]));
        maxX = std::max(maxX, double(points[i]));
        minY = std::min(minY, double(points[i + 1]));
        maxY = std::max(maxY, double(points[i + 1]));
    }
    return number(std::round(minX)) + "," + number(std::round(minY)) + " " + number(std::round(maxX - minX)) + "x" +
           number(std::round(maxY - minY));
}

std::string paintOf(const wr::canvas::Paint& paint) {
    if (paint.kind == wr::canvas::Paint::Kind::Linear) {
        return "linear";
    }
    if (paint.kind == wr::canvas::Paint::Kind::Radial) {
        return "radial";
    }
    char buffer[16];
    std::snprintf(buffer, sizeof buffer, "#%02x%02x%02x%02x", paint.color.r, paint.color.g, paint.color.b, paint.color.a);
    return buffer;
}

} // namespace

FakeCanvas::FakeCanvas(int width, int height) : width(width), height(height) { liveCanvasList().push_back(this); }

FakeCanvas::~FakeCanvas() {
    auto& list = liveCanvasList();
    list.erase(std::find(list.begin(), list.end(), this));
}

const std::vector<FakeCanvas*>& FakeCanvas::live() {
    return liveCanvasList();
}

void FakeCanvas::run(std::span<const wr::canvas::CanvasOp> ops) {
    using Kind = wr::canvas::CanvasOp::Kind;
    if (ops.empty()) {
        return;
    }
    runs++;
    m_snapshot = nullptr;
    for (const wr::canvas::CanvasOp& op : ops) {
        std::string line;
        switch (op.kind) {
        case Kind::Reset:
            line = "reset";
            break;
        case Kind::Fill:
            line = "fill " + boundsOf(op.path.points) + " " + paintOf(op.paint);
            break;
        case Kind::Stroke:
            line = "stroke " + boundsOf(op.path.points) + " " + paintOf(op.paint) + " w=" + number(op.lineWidth);
            if (!op.dashes.empty()) {
                line += " dash=" + std::to_string(op.dashes.size());
            }
            break;
        case Kind::Clear:
            line = "clear " + boundsOf(op.path.points);
            break;
        case Kind::Text:
            line = "text \"" + op.text + "\" " + number(op.x) + "," + number(op.y);
            break;
        case Kind::Image:
            line = "image " + number(op.sourceWidth) + "x" + number(op.sourceHeight) + " -> " + number(op.dx) + "," +
                   number(op.dy) + " " + number(op.dw) + "x" + number(op.dh);
            if (op.sw != op.sourceWidth || op.sh != op.sourceHeight) {
                line += " from " + number(op.sx) + "," + number(op.sy) + " " + number(op.sw) + "x" + number(op.sh);
            }
            break;
        }
        if (op.kind != Kind::Reset && op.alpha != 1) {
            line += " alpha=" + number(op.alpha);
        }
        if (op.clip) {
            line += " clips=" + std::to_string(op.clip->depth);
        }
        log.push_back(std::move(line));
    }
}

std::shared_ptr<const wr::HostImage> FakeCanvas::snapshot() {
    if (!m_snapshot) {
        m_snapshot = std::make_shared<FakeImage>();
    }
    return m_snapshot;
}

std::unique_ptr<wr::HostCanvas> FakeRenderHost::createCanvas(int width, int height) {
    if (refuseCanvases || width <= 0 || height <= 0) {
        return nullptr;
    }
    return std::make_unique<FakeCanvas>(width, height);
}

} // namespace wr_test
