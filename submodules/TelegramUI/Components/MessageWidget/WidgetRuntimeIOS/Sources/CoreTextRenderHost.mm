#include "CoreTextRenderHost.h"

#include <atomic>
#include <string>

#include "CanvasBitmap.h"
#include "third-party/twidget/LiteHTML/LHHostSupport.h"

namespace wr::ios {

IOSHostFont::~IOSHostFont() {
    LHHostContainer::deleteFont(handle);
}

CTFontRef IOSHostFont::font() const {
    return LHHostContainer::nativeFont(handle);
}

IOSHostImage::IOSHostImage(CGImageRef adopted, std::shared_ptr<std::atomic<uint64_t>> total, uint64_t bytes)
    : image(adopted), serial([] {
          static std::atomic<uint64_t> next{1};
          return next.fetch_add(1, std::memory_order_relaxed);
      }()),
      m_total(std::move(total)), m_bytes(bytes) {}

IOSHostImage::~IOSHostImage() {
    CGImageRelease(image);
    m_total->fetch_sub(m_bytes);
}

CoreTextRenderHost::CoreTextRenderHost() : m_container(std::make_unique<LHHostContainer>()) {}

CoreTextRenderHost::~CoreTextRenderHost() = default;

std::shared_ptr<const HostFont> CoreTextRenderHost::createFont(const litehtml::font_description& description,
                                                               litehtml::font_metrics& metrics) {
    litehtml::uint_ptr handle = m_container->createFont(description, &metrics);
    if (!handle) {
        return nullptr;
    }
    return std::make_shared<IOSHostFont>(handle, double(description.letter_spacing));
}

double CoreTextRenderHost::textWidth(const HostFont& font, std::string_view utf8) {
    const std::string text(utf8);
    return m_container->textWidth(text.c_str(), static_cast<const IOSHostFont&>(font).handle);
}

std::shared_ptr<litehtml::text_breaker> CoreTextRenderHost::createTextBreaker(const HostFont& font,
                                                                              const std::string& utf8) {
    return m_container->createTextBreaker(utf8, static_cast<const IOSHostFont&>(font).handle);
}

ShapedText CoreTextRenderHost::shape(const HostFont& hostFont, std::string_view utf8) {
    ShapedText shaped;
    const auto& font = static_cast<const IOSHostFont&>(hostFont);
    CTFontRef ctFont = font.font();
    if (!ctFont || utf8.empty()) {
        return shaped;
    }
    CFStringRef string = CFStringCreateWithBytes(nullptr, reinterpret_cast<const UInt8*>(utf8.data()), CFIndex(utf8.size()),
                                                 kCFStringEncodingUTF8, false);
    if (!string) {
        return shaped;
    }
    // The attributes LHContainer measures with: the font, and the kern its letter spacing gives.
    CGFloat kern = font.kern;
    CFNumberRef kernNumber = CFNumberCreate(nullptr, kCFNumberCGFloatType, &kern);
    const void* keys[] = {kCTFontAttributeName, kCTKernAttributeName};
    const void* values[] = {ctFont, kernNumber};
    CFDictionaryRef attributes = CFDictionaryCreate(nullptr, keys, values, kern != 0 ? 2 : 1,
                                                    &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAttributedStringRef attributed = CFAttributedStringCreate(nullptr, string, attributes);
    CTLineRef line = CTLineCreateWithAttributedString(attributed);
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    const CFIndex runCount = CFArrayGetCount(runs);
    for (CFIndex r = 0; r < runCount; r++) {
        CTRunRef run = static_cast<CTRunRef>(CFArrayGetValueAtIndex(runs, r));
        const CFIndex count = CTRunGetGlyphCount(run);
        std::vector<CGGlyph> glyphs(static_cast<size_t>(count));
        std::vector<CGSize> advances(static_cast<size_t>(count));
        CTRunGetGlyphs(run, CFRangeMake(0, 0), glyphs.data());
        CTRunGetAdvances(run, CFRangeMake(0, 0), advances.data());
        for (CFIndex i = 0; i < count; i++) {
            shaped.glyphs.push_back(glyphs[size_t(i)]);
            shaped.advances.push_back(float(advances[size_t(i)].width));
        }
    }
    CFRelease(line);
    CFRelease(attributed);
    CFRelease(attributes);
    CFRelease(kernNumber);
    CFRelease(string);
    return shaped;
}

std::vector<float> CoreTextRenderHost::caretOffsets(const HostFont& font, std::string_view utf8) {
    const std::string text(utf8);
    return m_container->caretOffsets(text.c_str(), static_cast<const IOSHostFont&>(font).handle);
}

void CoreTextRenderHost::transformText(std::string& utf8, litehtml::text_transform transform) {
    m_container->transformText(utf8, transform);
}

double CoreTextRenderHost::defaultFontSize() const {
    return m_container->defaultFontSize();
}

std::string CoreTextRenderHost::defaultFontName() const {
    return m_container->defaultFontName();
}

std::optional<DecodedImage> CoreTextRenderHost::decodeImage(std::string_view mimeType, std::span<const uint8_t> bytes) {
    const uint64_t before = m_decodedBytes->load();
    if (before >= kMaxDecodedImageBytes) {
        return std::nullopt;
    }
    const bool svg = mimeType.find("svg") != std::string_view::npos;
    CGSize size = CGSizeZero;
    // What is left of the total: an image whose raster would pass it is refused before it is drawn.
    CGImageRef image = LHHostContainer::createImage(bytes.data(), bytes.size(), svg, &size,
                                                    size_t(kMaxDecodedImageBytes - before));
    if (!image) {
        return std::nullopt;
    }
    // Counted as ImageStore counts: an SVG at its raster, any other image at the size it decodes to (ImageIO keeps
    // the decoded pixels as long as the image). The check above was made against an earlier total and without row
    // padding, so the total is checked again here.
    const uint64_t pixelBytes = uint64_t(CGImageGetBytesPerRow(image)) * CGImageGetHeight(image);
    uint64_t held = m_decodedBytes->load();
    do {
        if (pixelBytes > kMaxDecodedImageBytes || held > kMaxDecodedImageBytes - pixelBytes) {
            CGImageRelease(image);
            return std::nullopt;
        }
    } while (!m_decodedBytes->compare_exchange_weak(held, held + pixelBytes));
    DecodedImage decoded;
    decoded.image = std::make_shared<IOSHostImage>(image, m_decodedBytes, pixelBytes);
    decoded.width = size.width;
    decoded.height = size.height;
    return decoded;
}

bool CoreTextRenderHost::pathContains(const litehtml::vector_path& path, double x, double y) {
    return m_container->pathContains(path, float(x), float(y));
}

std::unique_ptr<HostCanvas> CoreTextRenderHost::createCanvas(int width, int height) {
    return IOSCanvasBitmap::create(width, height);
}

} // namespace wr::ios
