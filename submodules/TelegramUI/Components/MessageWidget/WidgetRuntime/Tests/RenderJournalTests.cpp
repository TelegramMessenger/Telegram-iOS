// The mutation journal and the flush (M1c plan, Task 6; Ruling 13): the parsed markup built in boot, a flush after
// every task and animation frame, what the journal records and when it collapses, theme and width changes, a stop that
// keeps the last flush (Review Focus 2) and a published tree that outlives the runtime (Review Focus 5).
#include <cstdint>
#include <cstdio>
#include <map>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>

#include <litehtml.h>

#include "Sources/Host/EventLoop.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/RenderHarness.h"

using wr_test::FakeRenderHost;
using wr_test::findText;
using wr_test::HostEnv;
using wr_test::RenderEnv;

namespace {

const char* const kEmpty = "<!doctype html><html><head></head><body></body></html>";
// The body's height is fixed, so text appended to it leaves the tree's size, and changedRects a vector.
const char* const kFixed = "<!doctype html><body style='height:100px'><p>x</p></body>";

// A 3×2 RGBA PNG (signature, IHDR, IDAT, IEND).
const std::string kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

// A data: PNG of `width` × 1 px: the signature and IHDR alone, which FakeRenderHost decodes by its size.
std::string pngOfWidth(uint32_t width) {
    const uint8_t bytes[] = {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n', 0, 0, 0, 13, 'I', 'H', 'D', 'R',
                             uint8_t(width >> 24), uint8_t(width >> 16), uint8_t(width >> 8), uint8_t(width), 0, 0, 0, 1,
                             8, 6, 0, 0, 0, 0, 0, 0, 0};
    static const char* const kDigits = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out = "data:image/png;base64,";
    const size_t n = sizeof bytes;
    for (size_t i = 0; i < n; i += 3) {
        const uint32_t v = uint32_t(bytes[i]) << 16 | (i + 1 < n ? uint32_t(bytes[i + 1]) << 8 : 0) | (i + 2 < n ? bytes[i + 2] : 0);
        out += kDigits[(v >> 18) & 63];
        out += kDigits[(v >> 12) & 63];
        out += i + 1 < n ? kDigits[(v >> 6) & 63] : '=';
        out += i + 2 < n ? kDigits[v & 63] : '=';
    }
    return out;
}

bool hasText(wr::RenderTree& render, const std::string& text) {
    std::shared_ptr<const wr::LayerTree> tree = render.layerTree();
    return tree && findText(*tree, text) != nullptr;
}

size_t countOf(const std::string& haystack, const std::string& needle) {
    size_t found = 0;
    for (size_t at = haystack.find(needle); at != std::string::npos; at = haystack.find(needle, at + needle.size())) {
        found++;
    }
    return found;
}

// A RenderHost that calls the tree's flush (and flushForQuery) back from textWidth: it breaks the host contract on
// purpose (RenderHost.h: host calls never call back into the runtime), to show a re-entered flush returns at once.
// Everything else is the FakeRenderHost's.
class ReentrantHost final : public wr::RenderHost {
public:
    FakeRenderHost fake;
    JSContext* ctx = nullptr;
    wr::RenderTree* tree = nullptr;
    int reentries = 0;
    bool innerChangedNothing = true;

    std::shared_ptr<const wr::HostFont> createFont(const litehtml::font_description& description,
                                                   litehtml::font_metrics& metrics) override {
        return fake.createFont(description, metrics);
    }
    double textWidth(const wr::HostFont& font, std::string_view utf8) override {
        if (tree) {
            reentries++;
            const uint64_t builds = tree->buildCount();
            std::shared_ptr<const wr::LayerTree> published = tree->layerTree();
            tree->flush(ctx);
            tree->flushForQuery(ctx);
            if (tree->buildCount() != builds || tree->layerTree() != published) {
                innerChangedNothing = false;
            }
        }
        return fake.textWidth(font, utf8);
    }
    std::shared_ptr<litehtml::text_breaker> createTextBreaker(const wr::HostFont& font, const std::string& utf8) override {
        return fake.createTextBreaker(font, utf8);
    }
    wr::ShapedText shape(const wr::HostFont& font, std::string_view utf8) override { return fake.shape(font, utf8); }
    void transformText(std::string& utf8, litehtml::text_transform transform) override {
        fake.transformText(utf8, transform);
    }
    double defaultFontSize() const override { return fake.defaultFontSize(); }
    std::string defaultFontName() const override { return fake.defaultFontName(); }
    std::optional<wr::DecodedImage> decodeImage(std::string_view mimeType, std::span<const uint8_t> bytes) override {
        return fake.decodeImage(mimeType, bytes);
    }
    bool pathContains(const litehtml::vector_path& path, double x, double y) override {
        return fake.pathContains(path, x, y);
    }
};

} // namespace

WR_TEST(testBootBuildsTheParsedMarkup) {
    RenderEnv env("<p>x</p>", {}, false);
    // Right after the boot, before any step: the parse's markup is built, laid out and recorded.
    CHECK(env.render().layerTree() != nullptr);
    CHECK_EQ(env.render().buildCount(), uint64_t(1));
    CHECK(!env.render().changedRects().has_value());
    CHECK(hasText(env.render(), "x"));
    CHECK(env.render().layoutDump().find("p ") != std::string::npos);
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    // The boot's tasks are still queued.
    CHECK(wr::EventLoop::of(env.ctx()).hasRunnableTask(env.env().host().now));
    // They change nothing rendered (readiness and events are not mutations): no other build.
    CHECK(env.env().drain() > 0);
    CHECK_EQ(env.render().buildCount(), uint64_t(1));
    CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
}

// Spec §5: a first script that never ends still leaves the parsed markup laid out.
WR_TEST(testHangingFirstScriptLeavesTheParsedMarkup) {
    wr_test::ScopedProductSlices slices;
    RenderEnv env("<p>parsed</p><script>for(;;){}</script>", {}, false, [](HostEnv& host) {
        wr_test::stopAfter(host.runtime());
    });
    env.env().drain();
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    CHECK(env.render().renderInput().find("<p>parsed</p>") != std::string::npos);
    CHECK(hasText(env.render(), "parsed"));
    CHECK_EQ(env.render().buildCount(), uint64_t(1));
}

WR_TEST(testTaskMutationsReachTheTree) {
    RenderEnv env("<!doctype html><body style='height:100px'><p>x</p><img src='" + kPng3x2 + "'></body>");
    std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
    const uint64_t builds = env.render().buildCount();
    const size_t fonts = env.host().fontsCreated;
    const size_t images = env.host().decodedMimeTypes.size();
    CHECK_EQ(env.env().eval("setTimeout(() => document.body.append('y')); 'ok'"), std::string("ok"));
    // A script the host evaluates is not a task: nothing is flushed.
    CHECK(env.render().layerTree() == before);
    env.env().advance(1);
    std::shared_ptr<const wr::LayerTree> after = env.render().layerTree();
    CHECK(after != before);
    CHECK(after && findText(*after, "y") != nullptr);
    CHECK(before && findText(*before, "y") == nullptr);
    // A structural flush, patched in place (Task 9).
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    CHECK(env.render().changedRects().has_value() && !env.render().changedRects()->empty());
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    // The flush reused the fonts and the image (Ruling 19): nothing was asked for anew, and the same font object
    // draws `x`.
    CHECK_EQ(env.host().fontsCreated, fonts);
    CHECK_EQ(env.host().decodedMimeTypes.size(), images);
    CHECK_EQ(images, size_t(1));
    const wr::TextItem* x0 = before ? findText(*before, "x") : nullptr;
    const wr::TextItem* x1 = after ? findText(*after, "x") : nullptr;
    CHECK(x0 && x1 && x0->font == x1->font);
    // An idle step flushes nothing.
    CHECK(env.env().step() == wr::StepResult::Idle);
    CHECK_EQ(env.render().buildCount() + env.render().patchCount(), builds + 1);
    if (before && after && before->width() != after->width()) {
        std::printf("  sizes: %gx%g -> %gx%g\n", before->width(), before->height(), after->width(), after->height());
    }
}

WR_TEST(testMicrotaskMutationsAreFlushed) {
    RenderEnv env(kFixed);
    const uint64_t builds = env.render().buildCount();
    // Queued from inside the task, so it runs at that task's checkpoint, before its flush.
    CHECK_EQ(env.env().eval("setTimeout(() => Promise.resolve().then(() => document.body.append('m'))); 'ok'"),
             std::string("ok"));
    env.env().host().now += 1;
    CHECK(env.env().step() == wr::StepResult::Ran);
    CHECK(hasText(env.render(), "m"));
    CHECK_EQ(env.render().buildCount() + env.render().patchCount(), builds + 1);
}

WR_TEST(testFrameMutationsAreFlushed) {
    RenderEnv env(kFixed);
    const uint64_t builds = env.render().buildCount();
    wr::EventLoop& loop = wr::EventLoop::of(env.ctx());
    CHECK_EQ(env.env().eval("requestAnimationFrame(() => document.body.append('f')); 'ok'"), std::string("ok"));
    CHECK(loop.wantsAnimationFrame());
    env.env().host().now += 16;
    CHECK(loop.runAnimationFrame(env.env().host().now) == wr::StepResult::Ran);
    CHECK(hasText(env.render(), "f"));
    CHECK_EQ(env.render().buildCount() + env.render().patchCount(), builds + 1);
    // And a microtask a frame callback queues.
    CHECK_EQ(env.env().eval("requestAnimationFrame(() => Promise.resolve().then(() => document.body.append('g'))); 'ok'"),
             std::string("ok"));
    env.env().host().now += 16;
    CHECK(loop.runAnimationFrame(env.env().host().now) == wr::StepResult::Ran);
    CHECK(hasText(env.render(), "g"));
    CHECK_EQ(env.render().buildCount() + env.render().patchCount(), builds + 2);
}

WR_TEST(testDetachedBuildsAreNotJournaled) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kEmpty);
    const uint64_t builds = env.render().buildCount();
    // A div built by script and never attached: spans appended into it, attributes set before and after, text, a
    // clone, a fragment and innerHTML. None of it is in the rendered tree, so none of it is journaled.
    CHECK_EQ(env.env().eval("const d = document.createElement('div');"
                            "for (let i = 0; i < 1000; i++) { const s = document.createElement('span');"
                            " s.setAttribute('data-a', i); d.appendChild(s); s.setAttribute('data-b', i); s.className = 'c';"
                            " s.textContent = 't'; s.firstChild.data = 'u'; }"
                            "d.setAttribute('x', '1'); d.cloneNode(true).setAttribute('y', '2');"
                            "const f = document.createDocumentFragment(); f.append(d.cloneNode(true));"
                            "const g = document.createElement('div'); g.innerHTML = '<b class=k>z</b>'; g.append(f);"
                            "d.childElementCount"),
             std::string("1000"));
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    // Attached, the div is one insertion under the body: the div and the body's children.
    CHECK_EQ(env.env().eval("document.body.appendChild(d); 'ok'"), std::string("ok"));
    CHECK_EQ(env.render().journalNodes(), size_t(2));
    env.flush();
    // Patched in place (Task 9): the div built whole, as it is now.
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    CHECK_EQ(countOf(env.render().renderInput(), "<span data-a=\"999\" data-b=\"999\" class=\"c\">u</span>"), size_t(1));
}

WR_TEST(testTheJournalKeepsEveryNode) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(kEmpty);
    const uint64_t builds = env.render().buildCount();
    // Distinct nodes: one div inserted and given attributes is one node, and the body's children another.
    CHECK_EQ(env.env().eval("const e = document.body.appendChild(document.createElement('div'));"
                            "e.setAttribute('a', '1'); e.className = 'b'; e.append('t'); 'ok'"),
             std::string("ok"));
    CHECK_EQ(env.render().journalNodes(), size_t(2));
    // 5,000 distinct nodes in one go: each keeps its entry (each allocated under the memory limit), beside
    // the body's and the first div's.
    CHECK_EQ(env.env().eval("for (let i = 0; i < 5000; i++) document.body.appendChild(document.createElement('div'));"
                            "'ok'"),
             std::string("ok"));
    CHECK_EQ(env.render().journalNodes(), size_t(5002));
    // The flush patches them all.
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    CHECK_EQ(countOf(env.render().renderInput(), "<div></div>"), size_t(5000));
    // And records again.
    CHECK_EQ(env.env().eval("document.body.setAttribute('data-x', '1'); 'ok'"), std::string("ok"));
    CHECK_EQ(env.render().journalNodes(), size_t(1));
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
}

// The Document is not mapped, but its children render: a root inserted into it is journaled, and the document element
// replaced in place (twidget edit 82).
WR_TEST(testChangesUnderTheDocumentAreJournaled) {
    RenderEnv env("<!doctype html><p>old</p>");
    CHECK_EQ(env.env().eval("setTimeout(() => document.documentElement.remove()); 'ok'"), std::string("ok"));
    env.env().advance(1);
    CHECK_EQ(env.render().renderInput(), std::string("<!doctype html><html></html>"));
    const uint64_t builds = env.render().buildCount();
    CHECK_EQ(env.env().eval("setTimeout(() => { const h = document.createElement('html');"
                            " h.appendChild(document.createElement('body')).textContent = 'new'; document.appendChild(h); });"
                            " 'ok'"),
             std::string("ok"));
    env.env().advance(1);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(hasText(env.render(), "new"));
}

// A `<style>`'s Text children are not mapped (its sheet is one piece of the style): their parent is, and the change is
// its sheet's, patched in place (twidget edit 81).
WR_TEST(testStyleTextChangesAreJournaled) {
    RenderEnv env("<!doctype html><style id=s>p{color:#000001}</style><p>t</p>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    CHECK_EQ(env.env().eval("setTimeout(() => { document.getElementById('s').firstChild.data = 'p{color:#000002}'; });"
                            " 'ok'"),
             std::string("ok"));
    env.env().advance(1);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    const wr::TextItem* item = env.render().layerTree() ? findText(*env.render().layerTree(), "t") : nullptr;
    CHECK(item && item->color.blue == 2);
    CHECK_EQ(env.env().eval("setTimeout(() => { document.getElementById('s').append(' p{color:#000003}'); }); 'ok'"),
             std::string("ok"));
    env.env().advance(1);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 2);
    item = env.render().layerTree() ? findText(*env.render().layerTree(), "t") : nullptr;
    CHECK(item && item->color.blue == 3);
}

// The node the byte budget cut is not mapped (Ruling 7: neither it nor anything after it renders), but its parent is:
// a change that makes it fit is journaled, and it renders again.
WR_TEST(testACutNodeComesBack) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><p id=a>first</p><p id=b>second</p>");
    CHECK_EQ(env.env().eval("setTimeout(() => document.getElementById('b').title = 'x'.repeat(1100000)); 'ok'"),
             std::string("ok"));
    env.env().advance(1);
    CHECK(hasText(env.render(), "first"));
    CHECK(!hasText(env.render(), "second"));
    CHECK_EQ(env.env().eval("setTimeout(() => document.getElementById('b').title = 'short'); 'ok'"), std::string("ok"));
    env.env().advance(1);
    CHECK(hasText(env.render(), "second"));
    // So does a cut Text node, the cut's other shape: its paragraph renders, empty.
    CHECK_EQ(env.env().eval("setTimeout(() => document.getElementById('b').firstChild.data = 'y'.repeat(1100000)); 'ok'"),
             std::string("ok"));
    env.env().advance(1);
    CHECK(env.render().renderInput().find("<p id=\"b\" title=\"short\"></p>") != std::string::npos);
    CHECK(env.render().renderInput().find("yyyy") == std::string::npos);
    CHECK_EQ(env.env().eval("setTimeout(() => document.getElementById('b').firstChild.data = 'back'); 'ok'"),
             std::string("ok"));
    env.env().advance(1);
    CHECK(hasText(env.render(), "back"));
}

// Review Focus 2: a stop leaves the last flush published, and a stopped widget builds nothing again.
namespace {

/// The root declarations HostState passes RenderTree::setTheme for `theme` and no palette.
std::string themeDeclarations(wr::Theme theme) {
    return wr::themeRootDeclarations(wr::completeThemeParams({}, theme), theme);
}

} // namespace

WR_TEST(testAStoppedWidgetKeepsItsLastFlush) {
    wr_test::ScopedProductSlices slices;
    RenderEnv env("<!doctype html><p id=t>before</p>");
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const std::string input = env.render().renderInput();
    const std::string dump = env.render().layoutDump();
    const uint64_t builds = env.render().buildCount();
    CHECK_EQ(env.env().eval("setTimeout(() => { document.getElementById('t').textContent = 'after';"
                            " document.body.append('more'); for (;;) {} }); 'ok'"),
             std::string("ok"));
    env.env().host().now += 1;
    CHECK(env.env().step() == wr::StepResult::Stopped);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Cpu);
    // The task mutated: the journal has it, and nothing was built from it.
    CHECK(env.render().journalNodes() > 0);
    CHECK(env.render().layerTree() == tree);
    CHECK_EQ(env.render().renderInput(), input);
    CHECK_EQ(env.render().layoutDump(), dump);
    CHECK_EQ(env.render().buildCount(), builds);
    // A further step, a frame, and the host's own flush build nothing.
    CHECK(env.env().step() == wr::StepResult::Stopped);
    CHECK(wr::EventLoop::of(env.ctx()).runAnimationFrame(env.env().host().now) == wr::StepResult::Stopped);
    wr::HostState::of(env.ctx()).flushRender(env.ctx());
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    // Nor does a width or theme change, at once or at a flush.
    env.render().setWidth(env.ctx(), 600);
    env.render().setTheme(env.ctx(), wr::Theme::Dark, themeDeclarations(wr::Theme::Dark));
    env.flush();
    wr::HostState::of(env.ctx()).flushRender(env.ctx());
    bool aborted = false;
    try {
        env.render().flushForQuery(env.ctx());
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK(env.render().layerTree() == tree);
    CHECK_EQ(env.render().renderInput(), input);
    CHECK_EQ(env.render().layoutDump(), dump);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(tree && tree->width() == 300);
}

// Twidget edit 80: a theme change is a patch: the scheme and the root's theme declarations applied in place, as a
// rebuild under the new theme makes them.
WR_TEST(testThemeChangePatches) {
    RenderEnv env("<!doctype html><div style=\"color:light-dark(#000001,#000002)\">t</div>");
    std::shared_ptr<const wr::LayerTree> light = env.render().layerTree();
    const wr::TextItem* item = light ? findText(*light, "t") : nullptr;
    CHECK(item && item->color.red == 0 && item->color.green == 0 && item->color.blue == 1);
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    env.render().setTheme(env.ctx(), wr::Theme::Dark, themeDeclarations(wr::Theme::Dark));
    // The next flush performs it.
    CHECK(env.render().layerTree() == light);
    wr::HostState::of(env.ctx()).flushRender(env.ctx());
    std::shared_ptr<const wr::LayerTree> dark = env.render().layerTree();
    item = dark ? findText(*dark, "t") : nullptr;
    CHECK(item && item->color.red == 0 && item->color.green == 0 && item->color.blue == 2);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    // The same theme again changes nothing.
    env.render().setTheme(env.ctx(), wr::Theme::Dark, themeDeclarations(wr::Theme::Dark));
    env.flush();
    CHECK_EQ(env.render().patchCount(), patches + 1);
    // And back.
    env.render().setTheme(env.ctx(), wr::Theme::Light, themeDeclarations(wr::Theme::Light));
    env.flush();
    item = env.render().layerTree() ? findText(*env.render().layerTree(), "t") : nullptr;
    CHECK(item && item->color.blue == 1);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 2);
}

// The container's caches follow the document at every flush, patch or build: a font or image no element names is
// dropped, and an image under an element hidden for one flush keeps its entry, so showing it again decodes nothing.
WR_TEST(testCachesFollowTheDocument) {
    RenderEnv env("<!doctype html><body style='margin:0'><img id=i src='" + pngOfWidth(1) +
                  "'><p id=p style='font-size:10px'>t</p><div id=d><img src='" + kPng3x2 + "'></div></body>");
    const uint64_t builds = env.render().buildCount();
    for (int n = 2; n <= 41; n++) {
        CHECK_EQ(env.env().eval("document.getElementById('i').src = '" + pngOfWidth(uint32_t(n)) +
                                "'; document.getElementById('p').style.fontSize = '" + std::to_string(10 + n) + "px'; 'ok'"),
                 std::string("ok"));
        env.flush();
    }
    CHECK_EQ(env.render().buildCount(), builds);
    if (env.render().cachedImages() > 2 || env.render().cachedFonts() > 3) {
        std::printf("  %zu images and %zu fonts cached\n", env.render().cachedImages(), env.render().cachedFonts());
    }
    CHECK(env.render().cachedImages() <= 2);
    CHECK(env.render().cachedFonts() <= 3);
    const size_t decodes = env.host().decodedMimeTypes.size();
    CHECK_EQ(env.env().eval("document.getElementById('d').style.display = 'none'; 'ok'"), std::string("ok"));
    env.flush();
    CHECK_EQ(env.env().eval("document.getElementById('d').style.display = ''; 'ok'"), std::string("ok"));
    env.flush();
    CHECK_EQ(env.host().decodedMimeTypes.size(), decodes);
}

// Twidget edit 79: a width change is a patch: the document relaid out at the new width, its media rules and viewport
// units applied again, as a rebuild at that width.
WR_TEST(testWidthChangePatches) {
    RenderEnv env("<!doctype html><style>@media (min-width:400px){p.a{display:none}} div{width:50vw}</style>"
                  "<p>some words to lay out</p><p class=a>gone when wide</p><div>half</div>");
    const std::string narrow = env.render().layoutDump();
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    CHECK(narrow.rfind("html 0 0 300 ", 0) == 0);
    env.render().setWidth(env.ctx(), 600);
    CHECK_EQ(env.render().layoutDump(), narrow);
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
    const std::string wide = env.render().layoutDump();
    CHECK(wide.rfind("html 0 0 600 ", 0) == 0);
    CHECK(env.render().layerTree() && env.render().layerTree()->width() == 600);
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    if (wide != layout) std::printf("  patched:\n%s---\n  rebuilt:\n%s", wide.c_str(), layout.c_str());
    CHECK_EQ(wide, layout);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
    // The same width again changes nothing.
    env.render().setWidth(env.ctx(), 600);
    env.flush();
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 1);
}

// Twidget edit 79: reduced motion is a patch, its media rules applied again.
WR_TEST(testReducedMotionPatches) {
    RenderEnv env("<!doctype html><style>@media (prefers-reduced-motion:reduce){p{color:#c00;padding:3px}}</style>"
                  "<p>moving words</p>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patches = env.render().patchCount();
    for (const bool reduced : {true, false}) {
        env.render().setReducedMotion(env.ctx(), reduced);
        env.flush();
        auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
        CHECK_EQ(env.render().layoutDump(), layout);
        CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
    }
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().patchCount(), patches + 2);
}

WR_TEST(testFlushIsNotReentrant) {
    ReentrantHost host;
    std::unique_ptr<HostEnv> env =
        HostEnv::booted(wr::BootOptions{"<!doctype html><p>words to measure</p>"}, 1, [&](HostEnv& booting) {
            host.ctx = booting.ctx();
            host.tree = &wr::installRender(booting.ctx(), host, wr::RenderOptions{});
        });
    // The boot's flush measured text, and each flush the host made from inside it returned at once.
    CHECK(host.reentries > 0);
    CHECK(host.innerChangedNothing);
    CHECK_EQ(host.tree->buildCount(), uint64_t(1));
    CHECK(env->runtime().stopReason() == wr::StopReason::None);
    // A task's flush too.
    const int reentries = host.reentries;
    CHECK_EQ(env->eval("setTimeout(() => document.body.append(' more words')); 'ok'"), std::string("ok"));
    env->advance(1);
    CHECK(host.reentries > reentries);
    CHECK(host.innerChangedNothing);
    // Patched in place (Task 9), with the same guard.
    CHECK_EQ(host.tree->buildCount(), uint64_t(1));
    CHECK_EQ(host.tree->patchCount(), uint64_t(1));
    CHECK(env->runtime().stopReason() == wr::StopReason::None);
    // The tree goes with the runtime, before the host.
    host.tree = nullptr;
}

WR_TEST(testRenderTreeReleasesNodes) {
    RenderEnv env(kEmpty);
    env.env().eval("gc()");
    const size_t before = env.env().runtime().liveObjects();
    // 1,000 (journaled one by one) and 5,000 (past the collapse): appended in one task, removed in the next.
    for (int count : {1000, 5000}) {
        const std::string n = std::to_string(count);
        CHECK_EQ(env.env().eval("setTimeout(() => { for (let i = 0; i < " + n +
                                "; i++) document.body.appendChild(document.createElement('div')); }); 'ok'"),
                 std::string("ok"));
        env.env().advance(1);
        CHECK_EQ(countOf(env.render().renderInput(), "<div></div>"), size_t(count));
        CHECK_EQ(env.env().eval("setTimeout(() => { while (document.body.lastChild) document.body.lastChild.remove(); });"
                                " 'ok'"),
                 std::string("ok"));
        env.env().advance(1);
        CHECK_EQ(countOf(env.render().renderInput(), "<div></div>"), size_t(0));
        env.env().eval("gc()");
        const size_t after = env.env().runtime().liveObjects();
        CHECK(after <= before + 10 && after + 10 >= before);
        if (after > before + 10) {
            std::printf("  %d: live objects %zu, before %zu\n", count, after, before);
        }
    }
}

// Review Focus 5: the published tree is plain data. The runtime and its RenderTree go in the middle of a journal (the
// HostState destroys its tree first, while the document and the context are alive), and the tree still reads; it holds
// the last fonts and images, which go with it.
WR_TEST(testTreeOutlivesTheRuntime) {
    CHECK_EQ(FakeRenderHost::liveFonts(), size_t(0));
    CHECK_EQ(FakeRenderHost::liveImages(), size_t(0));
    FakeRenderHost host;
    std::shared_ptr<const wr::LayerTree> tree;
    std::string dump;
    {
        std::unique_ptr<HostEnv> env = HostEnv::booted(
            wr::BootOptions{"<!doctype html><p id=t>text <b>bold</b></p><img src='" + kPng3x2 +
                            "'><div style=\"background-image:url('" + kPng3x2 + "')\">bg</div>"},
            1, [&](HostEnv& booting) { wr::installRender(booting.ctx(), host, wr::RenderOptions{}); });
        env->drain();
        wr::RenderTree& render = *wr::HostState::of(env->ctx()).render();
        tree = render.layerTree();
        CHECK(tree != nullptr);
        dump = tree ? tree->dump() : std::string();
        // Changes no flush has seen: a removed paragraph (held by the journal and the published maps alone) and new
        // nodes.
        CHECK_EQ(env->eval("document.getElementById('t').remove();"
                           "for (let i = 0; i < 100; i++) document.body.appendChild(document.createElement('i')).append('x');"
                           " 'ok'"),
                 std::string("ok"));
        CHECK(render.journalNodes() > 0);
    }
    CHECK(FakeRenderHost::liveFonts() > 0);
    CHECK(FakeRenderHost::liveImages() > 0);
    CHECK(tree && tree->dump() == dump);
    CHECK(tree && findText(*tree, "bold") != nullptr);
    CHECK(dump.find("image") != std::string::npos);
    tree.reset();
    CHECK_EQ(FakeRenderHost::liveFonts(), size_t(0));
    CHECK_EQ(FakeRenderHost::liveImages(), size_t(0));
}
