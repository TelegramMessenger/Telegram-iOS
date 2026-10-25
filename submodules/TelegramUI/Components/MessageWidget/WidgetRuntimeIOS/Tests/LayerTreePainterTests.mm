// The layer-tree painter (M1d plan, Task 6): a tree the runtime recorded, painted through LHContainer's code, against
// LHDocument drawing the same HTML; tiles that compose; a tree that outlives its runtime.
#import <XCTest/XCTest.h>
#import <ImageIO/ImageIO.h>
#import "LHDocument.h"

#include <cstdlib>
#include <memory>
#include <string>
#include <vector>

#include "../Sources/CoreTextRenderHost.h"
#include "../Sources/LayerTreePainter.h"
#include "third-party/twidget/LiteHTML/LHHostSupport.h"
#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/Boot.h"
#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/Builder.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Runtime/Runtime.h"

namespace {

class QuietHost final : public wr::Host {
public:
    double monotonicNow() override { return 0; }
    double wallClockNow() override { return 1767225600000.0; }
    void log(wr::LogLevel, std::string_view) override {}
    void diagnostic(std::string_view, std::string_view) override {}
};

// A runtime booted from `html` over CoreTextRenderHost, recording at `snap`, its loop drained.
struct Booted {
    QuietHost host;
    wr::ios::CoreTextRenderHost render;
    std::unique_ptr<wr::Runtime> runtime;

    Booted(const std::string& html, double snap) {
        wr::Runtime::Options options;
        options.interfaces = &wr::idl::kTable;
        options.host = &host;
        runtime = wr::Runtime::create(options);
        JSContext* ctx = runtime->context();
        wr::installDOM(ctx, wr::Document::createHTML(ctx));
        wr::installHost(ctx);
        wr::RenderOptions renderOptions;
        renderOptions.pixelSnapScale = snap;
        wr::installRender(ctx, render, renderOptions);
        wr::boot(ctx, wr::BootOptions{html});
        while (wr::EventLoop::of(ctx).runNextTask(0) == wr::StepResult::Ran) {
        }
    }
    std::shared_ptr<const wr::LayerTree> tree() { return wr::HostState::of(runtime->context()).render()->layerTree(); }
};

std::vector<uint8_t> rgba(CGImageRef image, size_t width, size_t height) {
    std::vector<uint8_t> pixels(width * height * 4, 0);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4, space,
                                             kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, CGFloat(width), CGFloat(height)), image);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return pixels;
}

// The share of pixels any channel of which differs by more than 2, and the largest difference.
std::pair<double, int> difference(CGImageRef a, CGImageRef b) {
    const size_t w = CGImageGetWidth(a);
    const size_t h = CGImageGetHeight(a);
    if (w != CGImageGetWidth(b) || h != CGImageGetHeight(b)) {
        return {1.0, 255};
    }
    std::vector<uint8_t> pa = rgba(a, w, h);
    std::vector<uint8_t> pb = rgba(b, w, h);
    size_t differing = 0;
    int largest = 0;
    for (size_t p = 0; p < w * h; p++) {
        int worst = 0;
        for (size_t c = 0; c < 4; c++) {
            worst = std::max(worst, std::abs(int(pa[p * 4 + c]) - int(pb[p * 4 + c])));
        }
        largest = std::max(largest, worst);
        differing += worst > 2 ? 1 : 0;
    }
    return {double(differing) / double(w * h), largest};
}

std::string pngDataURL() {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(nullptr, 8, 8, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(ctx, 0, 0.5, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, 8, 4));
    CGContextSetRGBFillColor(ctx, 1, 0.5, 0, 1);
    CGContextFillRect(ctx, CGRectMake(0, 4, 8, 4));
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CFMutableDataRef data = CFDataCreateMutable(nullptr, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(data, CFSTR("public.png"), 1, nullptr);
    CGImageDestinationAddImage(destination, image, nullptr);
    CGImageDestinationFinalize(destination);
    NSString* base64 = [(__bridge NSData*)data base64EncodedStringWithOptions:0];
    CFRelease(destination);
    CFRelease(data);
    CGImageRelease(image);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    return std::string("data:image/png;base64,") + base64.UTF8String;
}

const char* const kHostCSS = "html { display: flow-root; position: relative; min-height: 0 } head { display: none } "
                              "body { display: block; margin: 8px }";

// How many pixels anything was painted into (alpha above 0): a parity of two blank images proves nothing.
size_t paintedPixels(CGImageRef image) {
    const size_t w = CGImageGetWidth(image);
    const size_t h = CGImageGetHeight(image);
    std::vector<uint8_t> pixels = rgba(image, w, h);
    size_t painted = 0;
    for (size_t p = 0; p < w * h; p++) {
        painted += pixels[p * 4 + 3] > 0 ? 1 : 0;
    }
    return painted;
}

} // namespace

@interface LayerTreePainterTests : XCTestCase
@end

@implementation LayerTreePainterTests

- (void)testPaintsLikeLHDocument {
    const std::string png = pngDataURL();
    const std::pair<const char*, std::string> fixtures[] = {
        // In-profile CSS only (V4 plan, Task 3b): LHDocument applies no profile, and profile 1 drops text-shadow.
        {"text", "<p style=\"font:17px -apple-system;text-decoration:underline\">Hello world, quickly</p>"},
        {"image", "<img src=\"" + png + "\" width=40 height=40>"},
        {"list marker", "<ul><li>one</li><li>two</li></ul><ol><li>a</li></ol>"},
        {"solid fill", "<div style=\"width:100px;height:40px;background:#3a7\"></div>"},
        {"linear gradient", "<div style=\"width:120px;height:40px;background:linear-gradient(90deg,#f00,#00f)\"></div>"},
        {"radial gradient", "<div style=\"width:120px;height:60px;background:radial-gradient(circle,#ff0,#080)\"></div>"},
        {"conic gradient", "<div style=\"width:80px;height:80px;background:conic-gradient(#f00,#0f0,#00f,#f00)\"></div>"},
        {"borders", "<div style=\"width:100px;height:40px;border:3px solid #333;border-radius:10px\"></div>"},
        {"box shadow", "<div style=\"margin:10px;width:80px;height:40px;background:#fff;box-shadow:4px 4px 8px "
                       "rgba(0,0,0,.5)\"></div>"},
        {"svg path", "<svg width=\"50\" height=\"50\"><circle cx=\"25\" cy=\"25\" r=\"20\" fill=\"red\"/></svg>"},
        {"nested clips", "<div style=\"width:100px;height:60px;overflow:hidden;border-radius:20px\"><div "
                         "style=\"width:200px;height:200px;background:#c33\"><div style=\"width:50px;height:50px;"
                         "overflow:hidden;border-radius:10px\"><div style=\"width:90px;height:90px;background:#33c\">"
                         "</div></div></div></div>"},
        {"transform", "<div style=\"margin:20px;width:60px;height:30px;background:#36c;transform:rotate(10deg)\"></div>"},
        {"opacity", "<div style=\"width:80px;height:40px;background:#c63;opacity:.5\"></div>"},
        {"filter", "<div style=\"width:80px;height:40px;background:#c63;filter:blur(2px)\"></div>"},
        {"backdrop", "<div style=\"position:relative;width:120px;height:80px;background:linear-gradient(#f00,#00f)\"><div "
                     "style=\"position:absolute;left:20px;top:20px;width:60px;height:40px;"
                     "backdrop-filter:blur(4px)\"></div></div>"},
        {"isolated", "<div style=\"isolation:isolate;position:relative;z-index:1;width:80px;height:40px;"
                     "background:#6c3\"><span>stacked</span></div>"},
    };
    for (const auto& [name, body] : fixtures) {
        const std::string html = "<!doctype html><html><head></head><body>" + body + "</body></html>";
        Booted booted(html, 2);
        std::shared_ptr<const wr::LayerTree> tree = booted.tree();
        XCTAssertTrue(tree != nullptr, @"%s", name);
        if (!tree) {
            continue;
        }
        // LHDocument with the runtime's master (the UA layer, an origin above the master's other rules) and the theme's
        // root declarations, which the layer's values read.
        const std::string master = wr::masterWithHostCSS(wr::RenderOptions().hostCSS) + "\nhtml{" +
                                   wr::HostState::of(booted.runtime->context()).render()->options().rootDeclarations + "}";
        LHDocument* document = [[LHDocument alloc] initWithHTML:@(html.c_str()) css:@(master.c_str())];
        CGSize size = [document layoutWithMaxWidth:300 preferredWidth:300];
        const CGFloat height = std::min<CGFloat>(std::ceil(size.height), tree->height());
        const CGRect rect = CGRectMake(0, 0, 300, height);
        CGImageRef ours = wr::ios::LayerTreePainter::copyImage(*tree, rect, 2);
        CGImageRef theirs = [document copyImageWithMaxWidth:300 rect:rect scale:2];
        XCTAssertTrue(ours != nullptr && theirs != nullptr, @"%s", name);
        if (ours && theirs) {
            auto [share, largest] = difference(ours, theirs);
            const size_t painted = paintedPixels(ours);
            NSLog(@"painter parity %s: %.4f%% of pixels differ, largest %d, %zu painted", name, share * 100, largest, painted);
            // CoreImage has no Metal device in an ios_unit_test process, so a CSS filter paints nothing on either
            // side here; its parity still holds, and the simulator run (Task 10) checks that it draws.
            if (std::string(name) != "filter") {
                XCTAssertGreaterThan(painted, size_t(50), @"%s painted nothing", name);
            }
            XCTAssertLessThanOrEqual(share, 0.005, @"%s: %.4f%% differ (largest %d)", name, share * 100, largest);
        }
        CGImageRelease(ours);
        CGImageRelease(theirs);
    }
}

- (void)testTilesCompose {
    Booted booted("<!doctype html><html><head></head><body><div style=\"width:240px;height:240px;background:"
                  "linear-gradient(45deg,#f00,#00f);border-radius:30px\">tiles</div></body></html>",
                  2);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    CGImageRef whole = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(0, 0, 256, 256), 2);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef composed = CGBitmapContextCreate(nullptr, 512, 512, 8, 0, space,
                                                  kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    for (int ty = 0; ty < 2; ty++) {
        for (int tx = 0; tx < 2; tx++) {
            CGImageRef tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(tx * 128, ty * 128, 128, 128), 2);
            // Bitmap y is up: tile row 0 is the top half.
            CGContextDrawImage(composed, CGRectMake(tx * 256, (1 - ty) * 256, 256, 256), tile);
            CGImageRelease(tile);
        }
    }
    CGImageRef joined = CGBitmapContextCreateImage(composed);
    auto [share, largest] = difference(whole, joined);
    XCTAssertLessThanOrEqual(share, 0.001, @"%.4f%% differ (largest %d)", share * 100, largest);
    CGImageRelease(joined);
    CGContextRelease(composed);
    CGColorSpaceRelease(space);
    CGImageRelease(whole);
}

// V5d plan, Task 4: a canvas's bitmap is drawn in its box, through the twcanvas: image.
- (void)testACanvasPixelIsPainted {
    Booted booted("<!doctype html><html><head></head><body><canvas id=c width=20 height=20 style=\"display:block\"></canvas>"
                  "<script>var x = document.getElementById('c').getContext('2d'); x.fillStyle = 'red'; x.fillRect(0, 0, 20, 20);"
                  " x.fillStyle = 'blue'; x.fillRect(10, 10, 10, 10);</script></body></html>",
                  1);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    CGImageRef image = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(0, 0, 40, 40), 1);
    XCTAssertTrue(image != nullptr);
    std::vector<uint8_t> px = rgba(image, 40, 40);
    CGImageRelease(image);
    auto at = [&](int x, int y) { return &px[(size_t(y) * 40 + size_t(x)) * 4]; };
    // The canvas sits at (8, 8): red at its top-left quarter, blue at its bottom-right, nothing outside it.
    XCTAssertTrue(at(12, 12)[0] > 200 && at(12, 12)[2] < 60, @"%d %d", at(12, 12)[0], at(12, 12)[2]);
    XCTAssertTrue(at(24, 24)[2] > 200 && at(24, 24)[0] < 60, @"%d %d", at(24, 24)[0], at(24, 24)[2]);
    XCTAssertEqual(at(32, 32)[3], 0);
}

/// A rounded border whose sides differ (a CSS spinner: one side coloured) fills its whole ring: the parts of the ring
/// inside the inner rect's corners belong to a side too. They were left unpainted, a square hole in a round ring.
// Fidelity plan, Task 8 (twidget edit 36): Blink's dash metrics. A 6px dashed side 100px long: dashes 2w = 12 and a gap
// fitted near w so the side starts and ends with a dash, 6 dashes and gaps of 5.6 ([0, 12], [17.6, 29.6], …, [88, 100]).
// Dotted: round dots w across, 9 of them with gaps of 5.75, centred at 3, 14.75, 26.5, …, 97.
- (void)testDashesAndDotsFollowBlinksMetrics {
    Booted booted("<!doctype html><html><head></head><body style=\"margin:0\">"
                  "<div style=\"width:88px;height:28px;border:6px dashed rgb(0,0,0)\"></div>"
                  "<div style=\"width:88px;height:28px;border:6px dotted rgb(0,0,0)\"></div></body></html>",
                  1);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    CGImageRef image = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(0, 0, 100, 80), 1);
    XCTAssertTrue(image != nullptr);
    std::vector<uint8_t> px = rgba(image, 100, 80);
    CGImageRelease(image);
    auto alpha = [&](int x, int y) { return int(px[(size_t(y) * 100 + size_t(x)) * 4 + 3]); };
    // Dashed, top side (y 3): ink at 5, 20 and 95; the gap at 14.
    XCTAssertEqual(alpha(5, 3), 255);
    XCTAssertEqual(alpha(14, 3), 0);
    XCTAssertEqual(alpha(20, 3), 255);
    XCTAssertEqual(alpha(95, 3), 255);
    // Dotted, top side (y 40 + 3): the dot centred at 85.25 covers 83; 89 is in the gap before the last, at 97.
    XCTAssertGreaterThan(alpha(83, 43), 200);
    XCTAssertEqual(alpha(89, 43), 0);
}

- (void)testARoundedBorderWithOneSideColouredFillsItsRing {
    Booted booted("<!doctype html><html><head></head><body style=\"margin:8px\"><div style=\"width:46px;height:46px;border-radius:50%;"
                  "border:6px solid rgb(221,221,221);border-top-color:rgb(51,102,204);box-sizing:border-box\"></div>"
                  "</body></html>",
                  1);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    CGImageRef image = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(0, 0, 70, 70), 1);
    XCTAssertTrue(image != nullptr);
    std::vector<uint8_t> px = rgba(image, 70, 70);
    CGImageRelease(image);
    auto at = [&](int x, int y) { return &px[(size_t(y) * 70 + size_t(x)) * 4]; };
    // The ring is centred at (31, 31), radii 17 to 23; its inner rect is [14, 48]. (20, 15) is on the ring inside the
    // inner rect's top-left corner, above the corner's miter: the top side's blue. (17, 45), inside the bottom-left
    // corner: grey. The middle is unpainted.
    XCTAssertTrue(at(20, 15)[3] == 255 && at(20, 15)[2] > 150 && at(20, 15)[0] < 100, @"%d %d %d %d", at(20, 15)[0],
                  at(20, 15)[1], at(20, 15)[2], at(20, 15)[3]);
    XCTAssertTrue(at(17, 45)[3] == 255 && at(17, 45)[0] > 200 && at(17, 45)[2] > 200, @"%d %d %d %d", at(17, 45)[0],
                  at(17, 45)[1], at(17, 45)[2], at(17, 45)[3]);
    XCTAssertEqual(at(31, 31)[3], 0);
}

- (void)testTreeOutlivesItsRuntime {
    std::shared_ptr<const wr::LayerTree> tree;
    {
        Booted booted("<!doctype html><html><head></head><body><p style=\"background:#ccc\">kept</p></body></html>", 2);
        tree = booted.tree();
    }
    XCTAssertTrue(tree != nullptr);
    CGImageRef image = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(0, 0, 300, tree->height()), 2);
    XCTAssertTrue(image != nullptr);
    CGImageRelease(image);
}

// Twidget edit 64: the tiles of one draw share an LHEffectStore, so a filter or a backdrop is made once however many
// tiles show it, and not for a tile it misses. Here the blurred box covers 20…220 and 24 px of blur around it, the
// backdrop 100…160: both show in each of the four tiles of 0…256.
static const char* const kEffectsPage = "<!doctype html><html><head></head><body style=\"margin:0\">"
    "<div style=\"position:absolute;left:20px;top:20px;width:200px;height:200px;background:#f00;filter:blur(8px)\"></div>"
    "<div style=\"position:absolute;left:100px;top:100px;width:60px;height:60px;backdrop-filter:blur(4px)\"></div>"
    "</body></html>";

- (void)testADrawMakesEachEffectOnce {
    Booted booted(kEffectsPage, 3);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    LHEffectStore effects;
    for (int ty = 0; ty < 2; ty++) {
        for (int tx = 0; tx < 2; tx++) {
            CGImageRef tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(tx * 128, ty * 128, 128, 128), 3, &effects);
            XCTAssertTrue(tile != nullptr);
            CGImageRelease(tile);
        }
    }
    XCTAssertEqual(effects.made(), 2u);
}

- (void)testATileAnEffectMissesDoesNotMakeIt {
    Booted booted(kEffectsPage, 3);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    LHEffectStore effects;
    CGImageRef tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(256, 256, 128, 128), 3, &effects);
    CGImageRelease(tile);
    XCTAssertEqual(effects.made(), 0u);
    // Inside the blur's reach, past the backdrop: the filter alone.
    tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(170, 170, 60, 60), 3, &effects);
    CGImageRelease(tile);
    XCTAssertEqual(effects.made(), 1u);
}

// Tiles drawn at once wait for the one making an effect they share, a backdrop inside a filter and a backdrop over one
// included: the green box and its inner backdrop show in the top two tiles, the blue box and the backdrop over it in the
// bottom two. Four effects, each made once, and no tile waits forever.
- (void)testTilesDrawnTogetherShareTheirEffects {
    Booted booted("<!doctype html><html><head></head><body style=\"margin:0\">"
                  "<div style=\"position:absolute;left:16px;top:16px;width:224px;height:100px;background:#0a0;filter:blur(2px)\">"
                  "<div style=\"position:absolute;left:40px;top:20px;width:150px;height:40px;backdrop-filter:blur(3px)\"></div></div>"
                  "<div style=\"position:absolute;left:16px;top:140px;width:224px;height:100px;background:#00a;filter:blur(2px)\"></div>"
                  "<div style=\"position:absolute;left:60px;top:160px;width:120px;height:60px;backdrop-filter:blur(3px)\"></div>"
                  "</body></html>",
                  3);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    LHEffectStore effects;
    // A block copies what it captures: the store goes in by its address.
    LHEffectStore* store = &effects;
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        dispatch_apply(4, DISPATCH_APPLY_AUTO, ^(size_t i) {
            CGImageRef tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(CGFloat(i % 2) * 128, CGFloat(i / 2) * 128, 128, 128), 3, store);
            CGImageRelease(tile);
        });
    });
    XCTAssertEqual(dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)), 0);
    XCTAssertEqual(effects.made(), 4u);
}

// A paint allows its first 8 backdrops in tree order (LHContainer's kMaxBackdrops), whichever it shows: a tile the green
// box misses still counts the two backdrops inside it, so it allows b3…b8 and not b9 and b10, as every other tile does.
- (void)testEveryTileAllowsTheSameBackdrops {
    std::string html = "<!doctype html><html><head></head><body style=\"margin:0\">"
                       "<div style=\"position:absolute;left:8px;top:8px;width:100px;height:100px;background:#0a0;filter:blur(1px)\">"
                       "<div style=\"position:absolute;left:10px;top:10px;width:20px;height:20px;backdrop-filter:blur(2px)\"></div>"
                       "<div style=\"position:absolute;left:50px;top:10px;width:20px;height:20px;backdrop-filter:blur(2px)\"></div></div>";
    for (int i = 0; i < 8; i++) {
        html += "<div style=\"position:absolute;left:140px;top:" + std::to_string(8 + i * 12) +
                "px;width:100px;height:10px;backdrop-filter:blur(2px)\"></div>";
    }
    html += "</body></html>";
    Booted booted(html, 3);
    std::shared_ptr<const wr::LayerTree> tree = booted.tree();
    XCTAssertTrue(tree != nullptr);
    if (!tree) {
        return;
    }
    LHEffectStore right;
    CGImageRef tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(128, 0, 128, 128), 3, &right);
    CGImageRelease(tile);
    XCTAssertEqual(right.made(), 6u);
    // The box and the two backdrops inside it.
    LHEffectStore left;
    tile = wr::ios::LayerTreePainter::copyImage(*tree, CGRectMake(0, 0, 128, 128), 3, &left);
    CGImageRelease(tile);
    XCTAssertEqual(left.made(), 3u);
}

@end
