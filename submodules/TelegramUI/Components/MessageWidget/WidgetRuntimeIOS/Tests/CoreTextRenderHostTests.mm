// The iOS RenderHost (M1d plan, Task 5): LHContainer's fonts, measuring, breaking and transforms, glyph runs shaped by
// CoreText, today's image policy, and CGPath containment.
#import <XCTest/XCTest.h>
#import <ImageIO/ImageIO.h>
#import <mach/mach.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <numeric>
#include <string>
#include <vector>

#include "../Sources/CoreTextRenderHost.h"
#include "Sources/Render/WidgetContainer.h"
#include "third-party/twidget/LiteHTML/LHHostSupport.h"

namespace {

litehtml::font_description describe(const char* family, float size, int weight = 400) {
    litehtml::font_description descr;
    descr.family = family;
    descr.size = litehtml::pixel_t(size);
    descr.weight = weight;
    return descr;
}

// A width × height image of one colour, encoded as `type` (a UTType identifier).
std::vector<uint8_t> encoded(CFStringRef type, size_t width, size_t height) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nullptr, width, height, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGImageRef image = CGBitmapContextCreateImage(context);
    CFMutableDataRef data = CFDataCreateMutable(nullptr, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(data, type, 1, nullptr);
    CGImageDestinationAddImage(destination, image, nullptr);
    CGImageDestinationFinalize(destination);
    std::vector<uint8_t> bytes(CFDataGetBytePtr(data), CFDataGetBytePtr(data) + CFDataGetLength(data));
    CFRelease(destination);
    CFRelease(data);
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return bytes;
}

std::span<const uint8_t> span(const std::string& s) {
    return std::span<const uint8_t>(reinterpret_cast<const uint8_t*>(s.data()), s.size());
}

uint64_t residentBytes() {
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    task_info(mach_task_self(), TASK_VM_INFO, reinterpret_cast<task_info_t>(&info), &count);
    return info.phys_footprint;
}

} // namespace

@interface CoreTextRenderHostTests : XCTestCase
@end

@implementation CoreTextRenderHostTests

- (void)testFontMetricsMatchLHContainer {
    wr::ios::CoreTextRenderHost host;
    LHHostContainer reference;
    const std::pair<const char*, float> cases[] = {
        {"Helvetica", 13}, {"Helvetica", 17}, {"Helvetica", 21}, {"-apple-system", 17}, {"serif", 17}};
    for (const auto& [family, size] : cases) {
        litehtml::font_metrics ours;
        litehtml::font_metrics theirs;
        std::shared_ptr<const wr::HostFont> font = host.createFont(describe(family, size), ours);
        litehtml::uint_ptr handle = reference.createFont(describe(family, size), &theirs);
        XCTAssertTrue(font != nullptr);
        XCTAssertEqual(ours.height, theirs.height, @"%s %g", family, size);
        XCTAssertEqual(ours.ascent, theirs.ascent, @"%s %g", family, size);
        XCTAssertEqual(ours.descent, theirs.descent, @"%s %g", family, size);
        XCTAssertEqual(ours.x_height, theirs.x_height, @"%s %g", family, size);
        XCTAssertEqual(ours.ch_width, theirs.ch_width, @"%s %g", family, size);
        LHHostContainer::deleteFont(handle);
    }
    XCTAssertEqual(host.defaultFontSize(), 16);
}

- (void)testShapeSumsToTextWidth {
    wr::ios::CoreTextRenderHost host;
    litehtml::font_metrics metrics;
    std::shared_ptr<const wr::HostFont> font = host.createFont(describe("-apple-system", 17), metrics);
    std::string paragraph;
    while (paragraph.size() < 300) {
        paragraph += "The quick brown fox jumps over the lazy dog. ";
    }
    for (const std::string& text : {std::string("Hello"), std::string("Привет, мир"), std::string("مرحبا"),
                                    std::string("👩‍👩‍👧"), paragraph}) {
        wr::ShapedText shaped = host.shape(*font, text);
        XCTAssertFalse(shaped.glyphs.empty(), @"%s", text.c_str());
        XCTAssertEqual(shaped.glyphs.size(), shaped.advances.size());
        const double sum = std::accumulate(shaped.advances.begin(), shaped.advances.end(), 0.0);
        XCTAssertEqualWithAccuracy(sum, host.textWidth(*font, text), 0.01, @"%s", text.c_str());
    }
}

- (void)testBreakerBreaksAtClusterBoundaries {
    wr::ios::CoreTextRenderHost host;
    litehtml::font_metrics metrics;
    std::shared_ptr<const wr::HostFont> font = host.createFont(describe("-apple-system", 17), metrics);
    const std::string text = "a👩‍👩‍👧b";
    std::shared_ptr<litehtml::text_breaker> breaker = host.createTextBreaker(*font, text);
    XCTAssertTrue(breaker != nullptr);
    // Whatever the width, a break falls at a cluster boundary: never inside the family emoji.
    const size_t boundaries[] = {0, 1, text.size() - 1, text.size()};
    for (float width : {1.0f, 5.0f, 10.0f, 15.0f, 20.0f, 30.0f, 40.0f, 1000.0f}) {
        const size_t end = breaker->fit(0, litehtml::pixel_t(width));
        XCTAssertTrue(std::find(std::begin(boundaries), std::end(boundaries), end) != std::end(boundaries),
                      @"width %g broke at %zu", width, end);
    }
}

- (void)testTransformTextUnicode {
    wr::ios::CoreTextRenderHost host;
    std::string upper = "straße";
    host.transformText(upper, litehtml::text_transform_uppercase);
    XCTAssertEqual(upper, std::string("STRASSE"));
    std::string lower = "İSTANBUL";
    host.transformText(lower, litehtml::text_transform_lowercase);
    XCTAssertEqual(lower, std::string("i̇stanbul"));
}

- (void)testDecodesPngJpegGifAndSvg {
    wr::ios::CoreTextRenderHost host;
    for (CFStringRef type : {CFSTR("public.png"), CFSTR("public.jpeg"), CFSTR("com.compuserve.gif")}) {
        std::vector<uint8_t> bytes = encoded(type, 6, 4);
        std::optional<wr::DecodedImage> image = host.decodeImage("image/png", bytes);
        XCTAssertTrue(image.has_value());
        XCTAssertEqual(image->width, 6);
        XCTAssertEqual(image->height, 4);
        XCTAssertTrue(dynamic_cast<const wr::ios::IOSHostImage*>(image->image.get()) != nullptr);
    }
    const std::string svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"8\"><rect width=\"10\" "
                            "height=\"8\" fill=\"red\"/></svg>";
    std::optional<wr::DecodedImage> image = host.decodeImage("image/svg+xml", span(svg));
    XCTAssertTrue(image.has_value());
    XCTAssertEqual(image->width, 10);
    XCTAssertEqual(image->height, 8);
}

// V4 plan, Task 6: the 48 px placeholder a refused <img src> renders (RB §3.5) is the one SVG the host is handed.
- (void)testThePlaceholderDecodesAt48 {
    wr::ios::CoreTextRenderHost host;
    const std::string_view svg = wr::WidgetContainer::placeholderSVG();
    std::optional<wr::DecodedImage> image =
        host.decodeImage("image/svg+xml", std::span<const uint8_t>(reinterpret_cast<const uint8_t*>(svg.data()), svg.size()));
    XCTAssertTrue(image.has_value());
    XCTAssertEqual(image->width, 48);
    XCTAssertEqual(image->height, 48);
}

- (void)testHostileImagesAreRefused {
    wr::ios::CoreTextRenderHost host;
    const uint64_t before = residentBytes();
    // A PNG whose header claims 40,000 × 40,000: refused before anything is decoded.
    std::vector<uint8_t> png = encoded(CFSTR("public.png"), 2, 2);
    auto putBE = [&](size_t at, uint32_t v) {
        png[at] = uint8_t(v >> 24);
        png[at + 1] = uint8_t(v >> 16);
        png[at + 2] = uint8_t(v >> 8);
        png[at + 3] = uint8_t(v);
    };
    putBE(16, 40000);
    putBE(20, 40000);
    XCTAssertFalse(host.decodeImage("image/png", png).has_value());
    // A body over 24 MiB.
    std::vector<uint8_t> huge(30u << 20, 0);
    XCTAssertFalse(host.decodeImage("image/png", huge).has_value());
    // A TIFF, whatever the type says.
    std::vector<uint8_t> tiff = encoded(CFSTR("public.tiff"), 4, 4);
    XCTAssertFalse(host.decodeImage("image/png", tiff).has_value());
    // An SVG naming an http image decodes; nothing is loaded (its painter refuses every non-data: URL).
    const std::string svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\"><image "
                            "href=\"http://example.com/x.png\" width=\"10\" height=\"10\"/></svg>";
    XCTAssertTrue(host.decodeImage("image/svg+xml", span(svg)).has_value());
    XCTAssertLessThan(residentBytes() - std::min(before, residentBytes()), uint64_t(64) << 20);
}

/// Today's ImageStore limit (LHContainer.mm's kMaxDataImageBytes) on the decoded images one host holds at a time:
/// past it a decode is refused, and an image freed gives its bytes back (final review C1: each image was checked on its
/// own, so a message of many distinct images decoded gigabytes).
- (void)testDecodedImagesAreLimitedInTotal {
    wr::ios::CoreTextRenderHost host;
    const uint64_t limit = uint64_t(24) << 20;
    auto pixelBytes = [](const wr::DecodedImage& decoded) {
        CGImageRef image = static_cast<const wr::ios::IOSHostImage&>(*decoded.image).image;
        return uint64_t(CGImageGetBytesPerRow(image)) * CGImageGetHeight(image);
    };
    // Each is rasterized at 2x: 600 x 3200 pixels, about 7.3 MiB, so three fit.
    auto tall = [](int i) {
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"300\" height=\"1600\"><g id=\"g" + std::to_string(i) +
               "\"/></svg>";
    };
    std::vector<wr::DecodedImage> held;
    int refused = 0;
    for (int i = 0; i < 10; i++) {
        std::optional<wr::DecodedImage> decoded = host.decodeImage("image/svg+xml", span(tall(i)));
        if (decoded) {
            held.push_back(std::move(*decoded));
        } else {
            refused++;
        }
    }
    uint64_t total = 0;
    for (const auto& decoded : held) {
        total += pixelBytes(decoded);
    }
    XCTAssertGreaterThanOrEqual(held.size(), 2u);
    XCTAssertLessThanOrEqual(total, limit);
    XCTAssertEqual(refused, int(10 - held.size()));
    XCTAssertEqual(held.size(), 3u);
    // What is left still takes an image that fits.
    XCTAssertTrue(host.decodeImage("image/png", encoded(CFSTR("public.png"), 6, 4)).has_value());
    held.clear();
    XCTAssertTrue(host.decodeImage("image/svg+xml", span(tall(99))).has_value());
}

/// An image whose raster would pass what is left of the total is refused before it is drawn: an SVG once it is laid out,
/// any other image from its header (fix-pass review B: a 2048 x 2048 SVG rasterizes to 64 MiB, more than the whole
/// total, and each of thousands was drawn in full before its refusal). 20 such decodes cost no more than 4x 20 small ones.
- (void)testAnImageOverTheTotalIsRefusedBeforeItIsDrawn {
    wr::ios::CoreTextRenderHost host;
    auto svg = [](int side, int i) {
        const std::string s = std::to_string(side);
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + s + "\" height=\"" + s + "\"><rect id=\"r" +
               std::to_string(i) + "\" width=\"" + s + "\" height=\"" + s + "\" fill=\"red\"/></svg>";
    };
    auto seconds = [&](int side, bool decoded) {
        double best = 1e9;
        for (int run = 0; run < 3; run++) {
            auto start = std::chrono::steady_clock::now();
            for (int i = 0; i < 20; i++) {
                XCTAssertEqual(host.decodeImage("image/svg+xml", span(svg(side, run * 100 + i))).has_value(), decoded);
            }
            best = std::min(best, std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count());
        }
        return best;
    };
    const double small = seconds(20, true);
    const double large = seconds(2048, false);
    XCTAssertLessThanOrEqual(large, 4 * small + 0.02);
}

- (void)testPathContains {
    wr::ios::CoreTextRenderHost host;
    litehtml::vector_path path;
    auto rect = [&](float x, float y, float w, float h) {
        path.ops.push_back(litehtml::vector_path::move);
        path.points.insert(path.points.end(), {x, y});
        path.ops.push_back(litehtml::vector_path::line);
        path.points.insert(path.points.end(), {x + w, y});
        path.ops.push_back(litehtml::vector_path::line);
        path.points.insert(path.points.end(), {x + w, y + h});
        path.ops.push_back(litehtml::vector_path::line);
        path.points.insert(path.points.end(), {x, y + h});
        path.ops.push_back(litehtml::vector_path::close);
    };
    rect(0, 0, 100, 100);
    rect(25, 25, 50, 50);
    path.evenodd = false;
    XCTAssertTrue(host.pathContains(path, 50, 50));
    XCTAssertTrue(host.pathContains(path, 10, 10));
    XCTAssertFalse(host.pathContains(path, 150, 50));
    path.evenodd = true;
    XCTAssertFalse(host.pathContains(path, 50, 50));
    XCTAssertTrue(host.pathContains(path, 10, 10));
}

@end
