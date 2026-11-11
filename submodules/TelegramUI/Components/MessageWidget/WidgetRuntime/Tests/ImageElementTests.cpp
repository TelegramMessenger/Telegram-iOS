// HTMLImageElement as a canvas source (V5d plan, Task 5): a data: image decodes through the container (the layout's own
// decision). Since widget-sandbox v0.2.3 its state is a browser's: pending (not complete, no natural size, not drawn)
// from a src change until its load or error fires from a task, the parsed images' before the window's load; drawImage
// and createPattern take an image.
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
    // No source: nothing to draw. A broken image (a profile type that does not decode), once its error fired:
    // InvalidStateError (HTML's "check the usability of the image").
    env.env().eval("var none = document.createElement('img'); var bad = document.createElement('img');"
                   " bad.src = 'data:image/png;base64,AAAA'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[err(() => x.drawImage(none, 0, 0)), err(() => x.drawImage(bad, 0, 0)),"
                            " err(() => x.createPattern(bad, 'repeat')), x.createPattern(i, 'repeat') instanceof CanvasPattern].join()"),
             std::string("ok,InvalidStateError,InvalidStateError,true"));
    CHECK(!FakeCanvas::live().empty() && FakeCanvas::live().back()->log.size() == 3);
}

/// V5d final review, I3: an image keeps its decision while its src stays, so a detached sprite drawn every frame (each
/// paint a rebuild, which drops the decisions the build did not use) decodes once.
WR_TEST(testADetachedImageDecodesOnce) {
    RenderEnv env(page("<canvas id=c width=50 height=50></canvas>"));
    const size_t before = env.host().decodedMimeTypes.size();
    env.env().eval(std::string("var x = c.getContext('2d'); var s = document.createElement('img'); s.src = '") + kPNG + "'; 1");
    env.env().drain();
    for (int frame = 0; frame < 5; frame++) {
        env.env().eval("x.clearRect(0, 0, 50, 50); x.drawImage(s, 0, 0); 1");
        env.flush();
    }
    CHECK_EQ(env.host().decodedMimeTypes.size() - before, size_t(1));
    // A new src is a new decision.
    env.env().eval(std::string("s.src = 'data:image/png;x=1;base64,") + (kPNG + std::strlen("data:image/png;base64,")) + "'; 1");
    env.env().drain();
    env.env().eval("x.drawImage(s, 0, 0); 1");
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
    env.env().eval("for (let i = 0; i < 100; i++) { const im = new Image(); im.src = big; keep.push(im); } 1");
    env.env().drain();
    // The footprint can shrink meanwhile (the system reclaims memory under pressure): that is no growth, not an
    // unsigned wrap to 2^64 minus the shrink.
    const uint64_t after = footprint();
    const uint64_t grown = after > before ? after - before : 0;
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
        env.env().eval(std::string("var im = new Image(); im.src = '") + kPNG + "'; keep.push(im); 1");
        env.env().drain();
        env.env().eval("x.drawImage(im, 0, 0); 1");
        env.flush();
    }
    CHECK_EQ(env.host().decodedMimeTypes.size() - decodes, size_t(1));
    CHECK(FakeRenderHost::liveImages() <= images + 3);
}

/// V5d fix-wave 2 review, I-1: the shared decodes' sweep of expired entries is amortized, so a live image with a src of
/// its own costs the same however many came before it: the last thousand of 10,000 take about the CPU time the first
/// did (a sweep of every entry per decision would take about nine times as long).
WR_TEST(testTheImageSweepIsAmortized) {
    RenderEnv env(page(""));
    env.env().eval(std::string("var png = '") + kPNG + "'; var keep = [];"
                   " var add = (n) => { for (let i = 0; i < n; i++) { const im = new Image(); im.src = png + '#' + keep.length;"
                   " im.naturalWidth; keep.push(im); } }; 1");
    // The decisions (each a shared decode's lookup and sweep) are made when the images' events fire.
    auto cost = [&](int n) {
        const double before = wr_test::threadCpuMs();
        env.env().eval("add(" + std::to_string(n) + "); 1");
        env.env().drain();
        return wr_test::threadCpuMs() - before;
    };
    const double first = cost(1000);
    env.env().eval("add(8000); 1");
    env.env().drain();
    const double last = cost(1000);
    CHECK_EQ(env.env().eval("[keep.length, keep[9999].naturalWidth].join()"), std::string("10000,40"));
    if (last >= 3 * first + 1) {
        std::printf("  first 1000: %.3f CPU ms, last 1000: %.3f\n", first, last);
    }
    CHECK(last < 3 * first + 1);
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

namespace {

/// The image lines every live canvas logged.
std::string imageDraws() {
    std::string log;
    for (const FakeCanvas* canvas : FakeCanvas::live()) {
        for (const std::string& line : canvas->log) {
            if (line.rfind("image ", 0) == 0) {
                log += (log.empty() ? "" : " | ") + line;
            }
        }
    }
    return log;
}

} // namespace

/// widget-sandbox v0.2.3 (its image-state.test.ts): an image's state is a browser's. A new src is pending until its
/// load or error fires: not complete, no natural size, a width of 0 (or its attribute's); a broken one is complete with
/// no natural size; a new src is pending again.
WR_TEST(testAnImageIsPendingUntilItsEventFires) {
    RenderEnv env(page(""));
    env.env().eval(std::string("var s = new Image(); var seen = ''; s.onload = () => { seen = [s.complete, s.naturalWidth].join() };"
                               " s.src = '") + kPNG + "'; 1");
    CHECK_EQ(env.env().eval("[s.complete, s.naturalWidth, s.naturalHeight, s.width, s.currentSrc].join()"), std::string("false,0,0,0,"));
    env.env().drain();
    CHECK_EQ(env.env().eval("[seen, s.complete, s.naturalWidth, s.width, s.height].join('|')"), std::string("true,40|true|40|40|20"));
    CHECK_EQ(env.env().eval("[(s.src = s.src + '#2', s.complete), (s.width = 7, s.width), s.getAttribute('width')].join()"),
             std::string("false,7,7"));
    env.env().eval("s.src = 'data:image/png;base64,AAAA'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[s.complete, s.naturalWidth].join()"), std::string("true,0"));
}

/// widget-sandbox v0.2.3: a src set again before the first load fired loads once, for the new src (a browser's new
/// request replaces the pending one).
WR_TEST(testANewSourceReplacesThePendingImageEvent) {
    RenderEnv env(page(""));
    env.env().eval(std::string("var r = new Image(); var log = []; r.onload = () => log.push('load'); r.onerror = () => log.push('error');"
                               " r.src = 'data:image/png;base64,AAAA'; r.src = '") + kPNG + "'; 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.join(), r.naturalWidth].join('|')"), std::string("load|40"));
}

/// widget-sandbox v0.2.3 (auto/02-attributes-images-b's i-css): img.width and height are the rendered size when the
/// image is rendered, else the attribute, else the natural size.
WR_TEST(testAnImagesWidthIsItsRenderedWidth) {
    RenderEnv env(page(std::string("<img id=c width=30 style=\"width:12px\" src=\"") + kPNG + "\">"));
    CHECK_EQ(env.env().eval("[c.width, c.getAttribute('width')].join()"), std::string("12,30"));
    env.env().eval("c.style.display = 'none'; 1");
    CHECK_EQ(env.env().eval("c.width"), std::string("30"));
    env.env().eval("var d = c.cloneNode(); d.removeAttribute('width'); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("d.width"), std::string("40"));
}

/// widget-sandbox v0.2.3: a pending image is not yet usable on a canvas: drawImage draws nothing, without an error;
/// once loaded it draws.
WR_TEST(testAPendingImageDrawsNothing) {
    RenderEnv env(page("<canvas id=c width=60 height=40></canvas>"));
    env.env().eval(std::string("var x = c.getContext('2d'); var p = new Image(); p.src = '") + kPNG + "';"
                   " var thrown = err(() => x.drawImage(p, 0, 0)); 1");
    CHECK_EQ(env.env().eval("thrown"), std::string("ok"));
    CHECK_EQ(imageDraws(), std::string(""));
    env.env().drain();
    env.env().eval("x.drawImage(p, 1, 2); 1");
    CHECK_EQ(imageDraws(), std::string("image 40x20 -> 1,2 40x20"));
}

/// v0.2.3 review, I1: a parsed image a script takes out of the document before the window's load still loads (a
/// browser's fetch goes on), from a task, once: taken out alone or with its parent.
WR_TEST(testADetachedParsedImageStillLoads) {
    RenderEnv env("<!doctype html><html><head></head><body><img id=a src=\"" + std::string(kPNG) + "\"><div id=d><img id=b src=\"" +
                  std::string(kPNG) +
                  "\"></div><script>window.log = []; window.a = document.getElementById('a'); window.b = document.getElementById('b');"
                  " for (const e of [a, b]) e.onload = () => log.push(e.id); a.remove(); document.getElementById('d').remove();"
                  "</script></body></html>");
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.sort().join(), a.complete, a.naturalWidth, b.complete, b.naturalWidth].join('|')"),
             std::string("a,b|true|40|true|40"));
}

/// v0.2.3 review, I1: an image of a template's contents is pending until it is moved into the document (HTML: its
/// adopting steps are a relevant mutation), then loads from a task.
WR_TEST(testATemplateImageLoadsInTheDocument) {
    RenderEnv env(page(std::string("<template id=t><img src=\"") + kPNG + "\"></template>"));
    env.env().drain();
    env.env().eval("var m = t.content.firstChild; var log = []; m.onload = () => log.push('load'); 1");
    CHECK_EQ(env.env().eval("[m.complete, log.length].join()"), std::string("false,0"));
    env.env().eval("document.body.appendChild(m); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.join(), m.complete, m.naturalWidth].join('|')"), std::string("load|true|40"));
}

/// HTML's "check the usability of the image argument" (v0.2.3 review, M2): an image that is not fully decodable (its
/// load has not fired, or it has no src) makes createPattern return null; a canvas without a context still gives a
/// pattern.
WR_TEST(testCreatePatternOfAPendingImageIsNull) {
    RenderEnv env(page("<canvas id=c width=60 height=40></canvas><canvas id=e width=8 height=8></canvas>"));
    env.env().eval(std::string("var x = c.getContext('2d'); var p = new Image(); p.src = '") + kPNG + "'; 1");
    CHECK_EQ(env.env().eval("[x.createPattern(p, 'repeat'), x.createPattern(new Image(), 'repeat')].map(String).join()"),
             std::string("null,null"));
    CHECK_EQ(env.env().eval("x.createPattern(e, 'repeat') instanceof CanvasPattern"), std::string("true"));
    env.env().drain();
    CHECK_EQ(env.env().eval("x.createPattern(p, 'repeat') instanceof CanvasPattern"), std::string("true"));
}

/// v0.2.3 review, M3: a pending image has no natural size, so while it is rendered a dimension the CSS leaves auto is 0
/// (a browser lays it out at 0 until it decodes); a dimension the CSS sets is the rendered one. After its load, both
/// follow the image.
WR_TEST(testAPendingRenderedImageHasNoNaturalSizeInLayout) {
    RenderEnv env(page(""));
    env.env().eval(std::string("var a = new Image(); a.src = '") + kPNG + "'; var b = new Image(); b.style.width = '12px';"
                   " b.src = '" + kPNG + "'; document.body.append(a, b); 1");
    CHECK_EQ(env.env().eval("[a.width, a.height, b.width, b.height].join()"), std::string("0,0,12,0"));
    env.env().drain();
    CHECK_EQ(env.env().eval("[a.width, a.height, b.width, b.height].join()"), std::string("40,20,12,6"));
}

/// v0.2.3 review, M5: an image under a display: none ancestor is not being rendered, so its width is the attribute's.
WR_TEST(testAnImageUnderADisplayNoneAncestorUsesItsAttribute) {
    RenderEnv env(page(std::string("<div id=d style=\"display:none\"><img id=i width=30 style=\"width:12px\" src=\"") + kPNG +
                       "\"></div>"));
    CHECK_EQ(env.env().eval("i.width"), std::string("30"));
    env.env().eval("d.style.display = 'block'; 1");
    CHECK_EQ(env.env().eval("i.width"), std::string("12"));
}

/// v0.2.3 review, M5: the rendered width is rounded to the nearest pixel (pins `lround`).
WR_TEST(testAnImagesRenderedWidthRounds) {
    RenderEnv env(page(std::string("<img id=r style=\"width:12.6px\" src=\"") + kPNG + "\">"));
    CHECK_EQ(env.env().eval("r.width"), std::string("13"));
}

/// v0.2.3 fix-wave review, minor 5: a parsed image's load handler that gives another parsed image a new src during the
/// window's load gets one load for that image, for its new src (a browser's new request replaces the pending one).
WR_TEST(testALoadHandlerChangingAnotherParsedImageFiresOnce) {
    RenderEnv env("<!doctype html><html><head></head><body><img id=a src=\"" + std::string(kPNG) + "\"><img id=b src=\"" +
                  std::string(kPNG) +
                  "\"><script>window.log = []; const a = document.getElementById('a'), b = document.getElementById('b');"
                  " a.onload = () => { log.push('a'); b.src = '" + std::string(kSVG10x8) + "' };"
                  " b.onload = () => log.push('b:' + b.naturalWidth);</script></body></html>");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("a,b:48"));
}

/// v0.2.3 fix-wave review, test gaps: when a parsed image's load fires, against the window's, once.
WR_TEST(testADetachedParsedImageLoadsBeforeTheWindow) {
    RenderEnv env("<!doctype html><html><head></head><body><img id=a src=\"" + std::string(kPNG) +
                  "\"><script>window.log = []; const a = document.getElementById('a'); a.onload = () => log.push('a');"
                  " window.onload = () => log.push('window'); a.remove();</script></body></html>");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("a,window"));
}

WR_TEST(testAParsedImageRemovedAndReinsertedLoadsOnce) {
    RenderEnv env("<!doctype html><html><head></head><body><img id=a src=\"" + std::string(kPNG) +
                  "\"><script>window.log = []; const a = document.getElementById('a'); a.onload = () => log.push('a');"
                  " a.remove(); document.body.append(a);</script></body></html>");
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("a"));
}

WR_TEST(testAParsedImageIntoATemplateAndBackLoadsOnce) {
    RenderEnv env("<!doctype html><html><head></head><body><template id=t></template><img id=a src=\"" + std::string(kPNG) +
                  "\"><script>window.log = []; const a = document.getElementById('a'); a.onload = () => log.push('a');"
                  " document.getElementById('t').content.append(a); document.body.append(a);</script></body></html>");
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.join(), document.getElementById('a').complete].join('|')"), std::string("a|true"));
}

/// HTML: adoption is a relevant mutation, so an image that already loaded and is moved out of the document and back in
/// loads again.
WR_TEST(testReadoptingALoadedImageLoadsAgain) {
    RenderEnv env(page(std::string("<template id=t></template><img id=i src=\"") + kPNG + "\">"));
    env.env().eval("var log = []; i.onload = () => log.push('load'); t.content.append(i); document.body.append(i); 1");
    env.env().drain();
    CHECK_EQ(env.env().eval("[log.join(), i.complete, i.naturalWidth].join('|')"), std::string("load|true|40"));
}

