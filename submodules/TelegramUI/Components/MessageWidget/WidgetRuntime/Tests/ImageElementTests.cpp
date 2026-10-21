// HTMLImageElement as a canvas source (V5d plan, Task 5): a data: image decodes through the container (the layout's own
// decision), so `complete` and the natural size are known at once; load and error fire from a task when the source
// changes, and for the parsed images before the window's load; drawImage and createPattern take an image.
#include <cstdio>
#include <cstring>
#include <string>

#include <mach/mach.h>

#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::FakeCanvas;
using wr_test::FakeRenderHost;
using wr_test::RenderEnv;

namespace {

/// auto/12-canvas-b's 40 × 20 PNG.
const char* const kPNG =
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAPElEQVR4AcXBQQEAIBCAMKTShTKTnQxlBz9s687wa8/hl0QkIhGJ"
    "SEQiEpGIRCQiEYlIRCISkYhEJCKRBx5KAo1ZaufhAAAAAElFTkSuQmCC";

std::string page(const std::string& body) {
    return "<!doctype html><html><head></head><body>" + body +
           "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
           "window.err = f => { try { f(); return 'ok' } catch (e) { return e.name } };</script></body></html>";
}

} // namespace

WR_TEST(testADataImageIsCompleteWithItsSize) {
    RenderEnv env(page(std::string("<img id=i width=20 height=10 src=\"") + kPNG + "\"><img id=n src=\"" + kPNG + "\">"));
    CHECK_EQ(env.env().eval("[i instanceof HTMLImageElement, i.complete, i.naturalWidth, i.naturalHeight, i.width, i.height,"
                            " n.width, n.height, i.alt].join()"),
             std::string("true,true,40,20,20,10,40,20,"));
    CHECK_EQ(env.env().eval("var e = document.createElement('img'); [e.complete, e.naturalWidth, e.width, e.currentSrc].join()"),
             std::string("true,0,0,"));
    CHECK_EQ(env.env().eval("e.width = 7; [e.width, e.getAttribute('width')].join()"), std::string("7,7"));
}

WR_TEST(testLoadAndErrorEvents) {
    RenderEnv env(page(std::string("<img id=p src=\"") + kPNG + "\" onload=\"window.parsed = (window.parsed || 0) + 1\">"));
    // A parsed image's load fires once, before the window's.
    CHECK_EQ(env.env().eval("window.parsed"), std::string("1"));
    env.env().eval("var log = []; var img = document.createElement('img'); img.onload = () => log.push('load');"
                   " img.onerror = () => log.push('error'); img.src = '" + std::string(kPNG) + "'; 1");
    CHECK_EQ(env.env().eval("log.join()"), std::string(""));
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.join(), img.complete, img.naturalWidth].join('|')"), std::string("load|true|40"));
    // A source the profile allows that does not decode: error.
    env.env().eval("img.src = 'data:image/png;base64,AAAA'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.join(), img.complete, img.naturalWidth].join('|')"), std::string("load,error|true|0"));
    // Removing the source fires nothing.
    env.env().eval("img.removeAttribute('src'); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("load,error"));
}

WR_TEST(testDrawImageFromAnImage) {
    RenderEnv env(page(std::string("<canvas id=c width=160 height=120></canvas><img id=i src=\"") + kPNG + "\">"));
    env.env().eval("var x = c.getContext('2d'); x.imageSmoothingEnabled = false; x.drawImage(i, 6, 6, 32, 16);"
                   " x.drawImage(i, 0, 0, 20, 20, 6, 30, 16, 16); x.drawImage(i, 1, 2); 1");
    std::string log = FakeCanvas::live().empty() ? "(no canvas)" : "";
    for (const FakeCanvas* canvas : FakeCanvas::live()) {
        for (const std::string& line : canvas->log) {
            log += (log.empty() ? "" : " | ") + line;
        }
    }
    CHECK_EQ(log, std::string("image 40x20 -> 6,6 32x16 | image 40x20 -> 6,30 16x16 from 0,0 20x20 | image 40x20 -> 1,2 40x20"));
    // No source: nothing to draw. A broken image (a profile type that does not decode): InvalidStateError (HTML's "check
    // the usability of the image").
    CHECK_EQ(env.env().eval("var none = document.createElement('img'); var bad = document.createElement('img');"
                            " bad.src = 'data:image/png;base64,AAAA';"
                            " [err(() => x.drawImage(none, 0, 0)), err(() => x.drawImage(bad, 0, 0)),"
                            " err(() => x.createPattern(bad, 'repeat')), x.createPattern(i, 'repeat') instanceof CanvasPattern].join()"),
             std::string("ok,InvalidStateError,InvalidStateError,true"));
    CHECK(!FakeCanvas::live().empty() && FakeCanvas::live().back()->log.size() == 3);
}

/// V5d final review, I3: an image keeps its decision while its src stays, so a detached sprite drawn every frame (each
/// paint a rebuild, which drops the decisions the build did not use) decodes once.
WR_TEST(testADetachedImageDecodesOnce) {
    RenderEnv env(page("<canvas id=c width=50 height=50></canvas>"));
    env.env().eval(std::string("var x = c.getContext('2d'); var s = document.createElement('img'); s.src = '") + kPNG + "'; 1");
    const size_t before = env.host().decodedMimeTypes.size();
    for (int frame = 0; frame < 5; frame++) {
        env.env().eval("x.clearRect(0, 0, 50, 50); x.drawImage(s, 0, 0); 1");
        env.flush();
    }
    CHECK_EQ(env.host().decodedMimeTypes.size() - before, size_t(1));
    // A new src is a new decision.
    env.env().eval(std::string("s.src = 'data:image/png;x=1;base64,") + (kPNG + std::strlen("data:image/png;base64,")) + "'; x.drawImage(s, 0, 0); 1");
    CHECK_EQ(env.host().decodedMimeTypes.size() - before, size_t(2));
}

/// V5d final review, I4: HTML's legacy factory function Image(width, height), as the reference defines it.
WR_TEST(testTheImageConstructor) {
    RenderEnv env(page(""));
    CHECK_EQ(env.env().eval("var i = new Image(4, 3); [i instanceof HTMLImageElement, i.tagName, i.width, i.height, i.getAttribute('width'),"
                            " Image.prototype === HTMLImageElement.prototype, Image.name, Image.length, err(() => Image()),"
                            " new Image().hasAttribute('width'), i.ownerDocument === document].join()"),
             std::string("true,IMG,4,3,4,true,Image,0,TypeError,false,true"));
    env.env().eval(std::string("var loaded = false; var j = new Image(); j.onload = () => { loaded = true }; j.src = '") + kPNG + "'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[loaded, j.naturalWidth].join()"), std::string("true,40"));
}

namespace {

/// The process's physical footprint, in bytes.
uint64_t footprint() {
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, reinterpret_cast<task_info_t>(&info), &count) != KERN_SUCCESS) {
        return 0;
    }
    return info.phys_footprint;
}

} // namespace

/// V5d fix-wave review, C-A: an image keeps no copy of its src (the attribute is a JS string, counted once however many
/// elements share it).
WR_TEST(testAnImageKeepsNoCopyOfItsSource) {
    RenderEnv env(page(""));
    env.env().eval("var big = 'data:image/png;base64,' + 'A'.repeat(1000000) + '#'; var keep = []; 1");
    const uint64_t before = footprint();
    env.env().eval("for (let i = 0; i < 100; i++) { const im = new Image(); im.src = big; im.naturalWidth; keep.push(im); } 1");
    const uint64_t grown = footprint() - before;
    CHECK(grown < (uint64_t(30) << 20));
    if (grown >= (uint64_t(30) << 20)) {
        std::printf("  grew %llu bytes\n", (unsigned long long)grown);
    }
}

/// V5d fix-wave review, I-A: images with one src share one decode while any of them holds it, so new images made
/// across builds do not each pin a decode of their own.
WR_TEST(testImagesShareADecode) {
    RenderEnv env(page("<canvas id=c width=50 height=50></canvas>"));
    env.env().eval("var x = c.getContext('2d'); var keep = []; 1");
    const size_t decodes = env.host().decodedMimeTypes.size();
    const size_t images = FakeRenderHost::liveImages();
    for (int frame = 0; frame < 20; frame++) {
        env.env().eval(std::string("var im = new Image(); im.src = '") + kPNG + "'; keep.push(im); x.drawImage(im, 0, 0); 1");
        env.flush();
    }
    CHECK_EQ(env.host().decodedMimeTypes.size() - decodes, size_t(1));
    CHECK(FakeRenderHost::liveImages() <= images + 3);
}

/// V5d fix-wave 2 review, I-1: the shared decodes' sweep of expired entries is amortized, so a live image with a src of
/// its own costs the same however many came before it: the last thousand of 10,000 cost about what the first did.
WR_TEST(testTheImageSweepIsAmortized) {
    RenderEnv env(page(""));
    env.env().eval(std::string("var png = '") + kPNG + "'; var keep = [];"
                   " var add = (n) => { for (let i = 0; i < n; i++) { const im = new Image(); im.src = png + '#' + keep.length;"
                   " im.naturalWidth; keep.push(im); } }; 1");
    JSRuntime* rt = env.env().runtime().jsRuntime();
    auto cost = [&](int n) {
        const uint64_t before = JS_GetWorkUnits(rt);
        env.env().eval("add(" + std::to_string(n) + "); 1");
        return JS_GetWorkUnits(rt) - before;
    };
    const uint64_t first = cost(1000);
    env.env().eval("add(8000); 1");
    const uint64_t last = cost(1000);
    CHECK_EQ(env.env().eval("[keep.length, keep[9999].naturalWidth].join()"), std::string("10000,40"));
    CHECK(last < first * 3 / 2);
    if (last >= first * 3 / 2) {
        std::printf("  first 1000: %llu units, last 1000: %llu\n", (unsigned long long)first, (unsigned long long)last);
    }
}

namespace {

// widget-sandbox v0.1.0 conformance/auto/02-attributes-images-b.html's i-svg, i-bmp and i-ico.
const char* const kSVG10x8 =
    "data:image/svg+xml;utf8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2210%22%20height%3D%228%22%2F%3E";
const char* const kBMP2x2 =
    "data:image/bmp;base64,Qk1GAAAAAAAAADYAAAAoAAAAAgAAAAIAAAABABgAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAIjMAIjMAAAAiMwAiMwAAA==";
const char* const kICO2x2 =
    "data:image/x-icon;base64,AAABAAEAAgIAAAEAGABAAAAAFgAAACgAAAACAAAABAAAAAEAGAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAADMAIjMAIgAAMwAiMwAiAAAAAAAAAAAAAA=";

} // namespace

/// V4 plan, Task 6 (RB §8.5, §9 html.el.img-svg, img-other-formats, img-remote): a present src the profile refuses, the
/// empty one included, is the 48 px placeholder: load, 48 × 48, complete. An allowed one decodes, or errors.
WR_TEST(testARefusedSourceIsThePlaceholder) {
    RenderEnv env(page(""));
    const std::pair<std::string, std::string> rows[] = {
        {"https://example.org/p.png", "load,48,48,true"},
        {kSVG10x8, "load,48,48,true"},
        {kBMP2x2, "load,48,48,true"},
        {kICO2x2, "load,48,48,true"},
        {"#x", "load,48,48,true"},
        {"", "load,48,48,true"},
        {kPNG, "load,40,20,true"},
        {"data:image/png;base64,AAAA", "error,0,0,true"},
    };
    std::string wrong;
    for (const auto& [src, want] : rows) {
        env.env().eval("var r = document.createElement('img'); var got = [];"
                       " r.onload = () => got.push('load'); r.onerror = () => got.push('error');"
                       " r.src = '" + src + "'; 1");
        env.env().drain();
        const std::string got = env.env().eval("[got.join('+'), r.naturalWidth, r.naturalHeight, r.complete].join()");
        if (got != want) {
            wrong += " [" + src.substr(0, 40) + " → " + got + ", want " + want + "]";
        }
    }
    CHECK_EQ(wrong, std::string(""));
    // No src: no event, no size.
    env.env().eval("var n = document.createElement('img'); var none = []; n.onload = () => none.push('load');"
                   " n.onerror = () => none.push('error'); n.alt = 'x'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[none.length, n.naturalWidth, n.complete].join()"), std::string("0,0,true"));
}

/// V4 plan, Task 6 (FH §8.2): a parsed image's load or error fires at the window's load, after the page's scripts added
/// their listeners, once; an image a script makes fires from its own task.
WR_TEST(testAParsedImageFiresLoadToAScriptsListener) {
    RenderEnv env("<!doctype html><html><head></head><body><img id=i src=\"https://x/p.png\"><img id=j src=\"" +
                  std::string(kPNG) +
                  "\"><script>window.log = []; for (const e of document.querySelectorAll('img')) { e.onload = () => log.push(e.id + ':' +"
                  " e.naturalWidth); e.onerror = () => log.push(e.id + ':error'); }</script></body></html>");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("i:48,j:40"));
    env.env().eval("const m = new Image(); m.onload = () => log.push('m'); m.src = '" + std::string(kPNG) + "'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("i:48,j:40,m"));
}
