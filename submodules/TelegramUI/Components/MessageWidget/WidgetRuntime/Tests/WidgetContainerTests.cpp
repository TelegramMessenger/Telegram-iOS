// WidgetContainer (M1c plan, Task 3): the runtime's own litehtml container. Layout goes to the RenderHost, loads are
// data: images or refused (Review Focus 3), fonts and images are cached across builds, and the media features are
// fixed (Ruling 16).
#include "third-party/twidget/tests/test_container.h"
// test_container.h ends with twidget's own CHECK; this file uses wr_test.h's.
#undef CHECK

#include <cstdint>
#include <cstdio>
#include <memory>
#include <string>
#include <vector>

#include "Sources/Render/DataUrl.h"
#include "Sources/Render/RenderDump.h"
#include "Sources/Render/RenderHost.h"
#include "Sources/Render/WidgetContainer.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/wr_test.h"

using wr_test::FakeRenderHost;

namespace {

wr::RenderOptions options(double width, double viewportHeight, wr::Theme theme = wr::Theme::Light) {
    wr::RenderOptions result;
    result.width = width;
    result.viewportHeight = viewportHeight;
    result.theme = theme;
    return result;
}

litehtml::document::ptr layOut(litehtml::document_container& container, const std::string& html, float width = 300) {
    litehtml::document::ptr document = litehtml::document::createFromString(litehtml::estring(html), &container);
    document->render(litehtml::pixel_t(width));
    return document;
}

// A 3×2 RGBA PNG (signature, IHDR, IDAT, IEND).
const char* const kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

// The first line of `dump` that starts with `prefix`, without its newline; "" when there is none.
std::string lineStartingWith(const std::string& dump, const std::string& prefix) {
    size_t start = 0;
    while (start < dump.size()) {
        size_t end = dump.find('\n', start);
        if (end == std::string::npos) {
            end = dump.size();
        }
        if (dump.compare(start, prefix.size(), prefix) == 0) {
            return dump.substr(start, end - start);
        }
        start = end + 1;
    }
    return {};
}

bool isZero(const litehtml::size& size) {
    return float(size.width) == 0 && float(size.height) == 0;
}

} // namespace

WR_TEST(testDumpLayoutFormat) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options(300, 600));
    litehtml::document::ptr document = layOut(container, "<div style='width:100.5px;height:50px'>text <b>bold</b></div>");
    std::string dump = wr::dumpLayout(*document);
    // One line per element in tree order, indented two spaces per level, numbers by %g; no text or space pieces.
    CHECK(dump.rfind("html 0 0 300 ", 0) == 0);
    CHECK(dump.find("\n  body 8 8 284 50\n") != std::string::npos);
    CHECK(dump.find("\n    div 8 8 100.5 50\n") != std::string::npos);
    CHECK(dump.find("\n      b ") != std::string::npos);
    CHECK(dump.find("text") == std::string::npos);
    CHECK(dump.back() == '\n');
}

WR_TEST(testLayoutMatchesTheTestContainer) {
    struct Fixture {
        const char* html;
        const char* tag;   // a line the dump must have, so two empty dumps cannot pass
    };
    const Fixture fixtures[] = {
        {"<p>Some text runs: <b>bold</b>, <i>italic</i>, <span style='font-size:20px'>larger</span> and <small>small"
         "</small>, long enough to wrap twice at this width, with <sub>sub</sub> and <sup>super</sup>.</p>",
         "    p "},
        {"<table border=1 cellpadding=2><tr><th>head</th><th>wider head</th></tr><tr><td>a</td><td>bb</td></tr>"
         "<tr><td colspan=2>a cell across both columns with some text</td></tr></table>",
         "td "},
        {"<pre>line one\n  line two, indented\n\tthree after a tab\n\n</pre><p>after</p>", "    pre "},
        {"<ul><li>one<ol><li>a</li><li>b<ul><li>deep</li></ul></li></ol></li><li>two</li></ul>", "li "},
        {"<style>.box { padding: 4px; margin: 2px; border: 1px solid red } .wide { width: 120px } .row { display: flex; "
         "gap: 6px } .row > * { flex: 1 }</style><div class='box wide'>x</div><div class=box>y z</div>"
         "<div class=row><span>left</span><span class=box>right</span></div>",
         "    div "},
        {"<form><input type=text value=hi><input type=checkbox checked><input type=radio><input type=range>"
         "<select><option>one</option><option selected>two</option></select><button>Go</button>"
         "<textarea>t</textarea><input placeholder='a placeholder'></form>",
         "input "},
    };
    for (const Fixture& fixture : fixtures) {
        FakeRenderHost host;
        wr::WidgetContainer container(host, options(300, 600));
        litehtml_test::TestContainer reference;
        litehtml::document::ptr ours = layOut(container, fixture.html);
        litehtml::document::ptr theirs = litehtml_test::layout(reference, fixture.html, 300);
        std::string ourDump = wr::dumpLayout(*ours);
        std::string theirDump = wr::dumpLayout(*theirs);
        CHECK_EQ(ourDump, theirDump);
        CHECK(ourDump.find(fixture.tag) != std::string::npos);
        if (ourDump != theirDump) {
            std::printf("  WidgetContainer:\n%s  TestContainer:\n%s", ourDump.c_str(), theirDump.c_str());
        }
    }
}

WR_TEST(testLoadsAreRefused) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options(300, 0));
    container.beginBuild();
    const char* const urls[] = {
        "http://127.0.0.1:9999/x",
        "//127.0.0.1:9999/x",
        " http://x",
        "relative.png",
        "blob:http://x/y",
        "javascript:alert(1)",
        "icon:send",
        "sf:star",
        "data:text/html,<b>",
        "data:image/png",
    };
    uint64_t refused = 0;
    for (const char* url : urls) {
        container.load_image(url, nullptr, true);
        CHECK_EQ(container.refusedLoads(), ++refused);
        litehtml::size size(7, 7);
        container.get_image_size(url, nullptr, size);
        CHECK_EQ(container.refusedLoads(), ++refused);
        CHECK(isZero(size));
    }
    // A base URL changes nothing: the URL is decided alone, and a relative one is never resolved.
    litehtml::size size(7, 7);
    container.get_image_size("relative.png", kPng3x2, size);
    CHECK_EQ(container.refusedLoads(), ++refused);
    CHECK(isZero(size));

    std::string css = "p { color: red }";
    std::string baseUrl;
    container.import_css(css, "http://x/a.css", baseUrl);
    CHECK(css.empty());
    CHECK_EQ(container.refusedLoads(), ++refused);
    litehtml::document::ptr document = layOut(container, "<p>x</p>");
    container.link(document, document->root());
    CHECK_EQ(container.refusedLoads(), ++refused);

    // Through a document: an <img>, a background, a stylesheet <link> (import_css, then link) and @import. The profile
    // drops the @import rule and the remote background before any load is asked for (V4 plan, Task 3b).
    litehtml::document::ptr loads = layOut(container,
        "<style>@import url(http://x/i.css);</style><link rel=stylesheet href=//x/l.css><img src=http://x/i.png>"
        "<div id=bg style='width:10px;height:10px;background-image:url(http://x/b.png)'></div>");
    CHECK(container.refusedLoads() >= refused + 4);
    litehtml::element::ptr bg = loads->root()->select_one("#bg");
    CHECK(bg && bg->css().get_bg().m_image.size() == 1 && bg->css().get_bg().m_image[0].is_empty());
    // An empty source asks for nothing: it is not counted (LHContainer's refuse_request does not count it either).
    uint64_t beforeEmpty = container.refusedLoads();
    container.load_image("", nullptr, true);
    container.get_image_size(nullptr, nullptr, size);
    CHECK_EQ(container.refusedLoads(), beforeEmpty);
    CHECK(isZero(size));
    container.prune(*loads);

    CHECK(host.decodedMimeTypes.empty());
    CHECK_EQ(FakeRenderHost::liveImages(), size_t(0));
}

WR_TEST(testDataImagesDecodeOnce) {
    FakeRenderHost host;
    size_t imagesBefore = FakeRenderHost::liveImages();
    {
        wr::WidgetContainer container(host, options(300, 0));
        container.beginBuild();
        container.load_image(kPng3x2, nullptr, true);
        litehtml::size size;
        container.get_image_size(kPng3x2, nullptr, size);
        CHECK(float(size.width) == 3 && float(size.height) == 2);
        const std::string html = std::string("<img src='") + kPng3x2 + "'>";
        litehtml::document::ptr first = layOut(container, html);
        litehtml::document::ptr second = layOut(container, html);
        container.prune(*second);
        CHECK(host.decodedMimeTypes == std::vector<std::string>{"image/png"});
        CHECK_EQ(container.refusedLoads(), uint64_t(0));
        const std::string img = lineStartingWith(wr::dumpLayout(*second), "    img ");
        CHECK(img.size() > 4 && img.compare(img.size() - 4, 4, " 3 2") == 0);
        CHECK_EQ(FakeRenderHost::liveImages(), imagesBefore + 1);

        // A document that names it keeps it at a prune; one that does not drops it.
        litehtml::document::ptr third = layOut(container, html);
        container.prune(*third);
        CHECK_EQ(host.decodedMimeTypes.size(), size_t(1));
        CHECK_EQ(FakeRenderHost::liveImages(), imagesBefore + 1);
        litehtml::document::ptr fourth = layOut(container, "<p>no image</p>");
        container.prune(*fourth);
        CHECK_EQ(FakeRenderHost::liveImages(), imagesBefore);

        // An image/* data: URL of bytes no decoder takes (widget-sandbox v0.3.0) never reaches the host, reports no
        // size and is not a refusal.
        container.load_image("data:image/png;base64,AAEC", nullptr, true);
        container.get_image_size("data:image/png;base64,AAEC", nullptr, size);
        CHECK(isZero(size));
        CHECK(host.decodedMimeTypes == (std::vector<std::string>{"image/png"}));
        CHECK_EQ(container.refusedLoads(), uint64_t(0));

        // A GIF: the host is handed the type's essence.
        container.get_image_size("data:image/gif;base64,R0lGODlhBQAHAAAAACwAAAAABQAHAAACAkwBADs=", nullptr, size);
        CHECK(float(size.width) == 5 && float(size.height) == 7);
        CHECK(host.decodedMimeTypes == (std::vector<std::string>{"image/png", "image/gif"}));
    }
    CHECK_EQ(FakeRenderHost::liveImages(), imagesBefore);
}

/// V4 plan, Task 6: only profile 1's image types decode (RB §3.2); the 48 px placeholder is the one SVG the host is
/// ever handed, and a widget's own internal URL is refused like any other.
WR_TEST(testOnlyProfileImagesDecode) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options(300, 0));
    container.beginBuild();
    uint64_t refused = 0;
    for (const char* url : {"data:image/svg+xml,<svg/>", "data:image/bmp;base64,Qk0=", "data:image/x-icon;base64,AAAB",
                            "#frag"}) {
        litehtml::size size(7, 7);
        container.get_image_size(url, nullptr, size);
        CHECK_EQ(container.refusedLoads(), ++refused);
        CHECK(isZero(size));
    }
    CHECK(host.decodedMimeTypes.empty());
    litehtml::size size;
    container.get_image_size(kPng3x2, nullptr, size);
    CHECK(float(size.width) == 3 && float(size.height) == 2);
    container.get_image_size(std::string(wr::WidgetContainer::kPlaceholderURL).c_str(), nullptr, size);
    CHECK(float(size.width) == 48 && float(size.height) == 48);
    CHECK(!host.decodedMimeTypes.empty() && host.decodedMimeTypes.back() == "image/svg+xml");
    CHECK_EQ(container.refusedLoads(), refused);
    // The DOM's decode follows the same predicate.
    CHECK(!container.decodeImageUncached("data:image/svg+xml,<svg/>").has_value());
    std::optional<wr::DecodedImage> placeholder = container.decodeImageUncached(wr::WidgetContainer::kPlaceholderURL);
    CHECK(placeholder && placeholder->width == 48 && placeholder->height == 48);
    // Byte for byte the reference's (widget-sandbox v0.1.0 url-policy.ts; RB §3.5).
    std::optional<wr::DataUrl> reference = wr::parseDataUrl(
        "data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2248%22%20height%3D%2248%22"
        "%20viewBox%3D%220%200%2048%2048%22%3E%3Crect%20width%3D%2248%22%20height%3D%2248%22%20fill%3D%22%238882%22%2F%3E%3Cpath"
        "%20d%3D%22M8%2036l10-12%208%209%206-7%208%2010z%22%20fill%3D%22%238886%22%2F%3E%3Ccircle%20cx%3D%2233%22%20cy%3D%2215%22"
        "%20r%3D%224%22%20fill%3D%22%238886%22%2F%3E%3C%2Fsvg%3E");
    CHECK(reference && std::string(reference->bytes.begin(), reference->bytes.end()) == wr::WidgetContainer::placeholderSVG());
}

WR_TEST(testFontsAreCachedAcrossBuilds) {
    const std::string both = "<p>sans</p><p style='font-family: serif'>serif</p>";
    const std::string sansOnly = "<p>sans</p>";
    size_t fontsForSansOnly = 0;
    {
        FakeRenderHost host;
        wr::WidgetContainer container(host, options(300, 0));
        litehtml::document::ptr document = layOut(container, sansOnly);
        fontsForSansOnly = host.fontsCreated;
    }
    const size_t liveBefore = FakeRenderHost::liveFonts();
    {
        FakeRenderHost host;
        wr::WidgetContainer container(host, options(300, 0));
        litehtml::document::ptr first = layOut(container, both);
        container.prune(*first);
        const size_t created = host.fontsCreated;
        CHECK(created > fontsForSansOnly);
        const size_t liveAfterFirst = FakeRenderHost::liveFonts();
        CHECK_EQ(liveAfterFirst, liveBefore + created);

        litehtml::document::ptr second = layOut(container, both);
        container.prune(*second);
        CHECK_EQ(host.fontsCreated, created);
        // litehtml deletes the first document's handles; the cache and the second document keep the fonts.
        first.reset();
        CHECK_EQ(FakeRenderHost::liveFonts(), liveAfterFirst);

        // A prune for the third document drops the serif font from the cache, but the second document still holds a
        // handle to it: the font stays alive, and the handle stays usable, until litehtml deletes it.
        litehtml::document::ptr third = layOut(container, sansOnly);
        container.prune(*third);
        CHECK_EQ(host.fontsCreated, created);
        CHECK_EQ(FakeRenderHost::liveFonts(), liveAfterFirst);
        second->render(litehtml::pixel_t(200.0f));
        CHECK(wr::dumpLayout(*second).find("\n    p ") != std::string::npos);
        second.reset();
        CHECK_EQ(FakeRenderHost::liveFonts(), liveAfterFirst - (created - fontsForSansOnly));
        third.reset();
        CHECK_EQ(FakeRenderHost::liveFonts(), liveBefore + fontsForSansOnly);
    }
    CHECK_EQ(FakeRenderHost::liveFonts(), liveBefore);
}

WR_TEST(testMediaFeatures) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options(320, 480, wr::Theme::Dark));
    CHECK(container.options().width == 320 && container.options().viewportHeight == 480);
    CHECK(container.options().theme == wr::Theme::Dark);
    litehtml::media_features media;
    container.get_media_features(media);
    CHECK(media.type == litehtml::media_type_screen);
    CHECK(float(media.width) == 320 && float(media.height) == 480);
    CHECK(float(media.device_width) == 1440 && float(media.device_height) == 900);
    CHECK_EQ(media.color, 8);
    CHECK_EQ(media.color_index, 256);
    CHECK_EQ(media.monochrome, 0);
    CHECK(float(media.resolution) == 96);
    CHECK_EQ(media.color_scheme, 1);
    litehtml::position viewport(1, 2, 3, 4);
    container.get_viewport(viewport);
    CHECK(float(viewport.x) == 0 && float(viewport.y) == 0);
    CHECK(float(viewport.width) == 320 && float(viewport.height) == 480);

    container.setOptions(options(300, 0));
    container.get_media_features(media);
    CHECK_EQ(media.color_scheme, 0);
    CHECK(float(media.width) == 300 && float(media.height) == 0);
    container.get_viewport(viewport);
    CHECK(float(viewport.width) == 300 && float(viewport.height) == 0);
    // The default viewport height is 0, as today.
    CHECK(wr::RenderOptions().viewportHeight == 0 && wr::RenderOptions().theme == wr::Theme::Light);

    CHECK(float(container.pt_to_px(12)) == 16);
    CHECK(float(container.get_default_font_size()) == 16);
    CHECK(std::string(container.get_default_font_name()) == "sans-serif");
    std::string language = "x";
    std::string culture = "y";
    container.get_language(language, culture);
    CHECK(language == "en" && culture.empty());
    CHECK(container.create_element("div", {}, nullptr) == nullptr);

    // The scheme reaches litehtml's prefers-color-scheme (twidget edit 13).
    const std::string html = "<style>div { height: 10px } @media (prefers-color-scheme: dark) { div { height: 20px } }"
                             "</style><div></div>";
    {
        litehtml::document::ptr light = layOut(container, html);
        CHECK(wr::dumpLayout(*light).find("\n    div 8 8 284 10\n") != std::string::npos);
    }
    container.setOptions(options(300, 0, wr::Theme::Dark));
    litehtml::document::ptr dark = layOut(container, html);
    CHECK(wr::dumpLayout(*dark).find("\n    div 8 8 284 20\n") != std::string::npos);
}

// Text goes to the host with the font that measures it; handles are never 0 and are freed by delete_font.
WR_TEST(testTextGoesToTheHost) {
    FakeRenderHost host;
    size_t liveBefore = FakeRenderHost::liveFonts();
    wr::WidgetContainer container(host, options(300, 0));
    litehtml::font_description description;
    description.family = "sans-serif";
    description.size = 13;
    description.weight = 400;
    litehtml::font_metrics metrics;
    litehtml::uint_ptr font = container.create_font(description, nullptr, &metrics);
    CHECK(font != 0);
    CHECK(float(metrics.font_size) == 13 && float(metrics.ascent) == 12 && float(metrics.descent) == 4);
    CHECK(float(metrics.height) == 16 && float(metrics.x_height) == 6 && float(metrics.ch_width) == 8);
    CHECK(float(metrics.sub_shift) == 2 && float(metrics.super_shift) == 4 && !metrics.draw_spaces);
    CHECK(float(container.text_width("abc", font)) == 24);
    CHECK(float(container.text_width("\xc3\xa9", font)) == 16);
    // The host's breaker, forwarded: the fake fits a byte per 8 px.
    std::shared_ptr<litehtml::text_breaker> breaker = container.create_text_breaker("abc def", font);
    CHECK(breaker && breaker->fit(0, 24) == 3 && breaker->fit(5, 100) == 7);
    // The same description is the same font; a different one is not.
    litehtml::uint_ptr again = container.create_font(description, nullptr, &metrics);
    CHECK(again != 0 && again != font);
    CHECK_EQ(host.fontsCreated, size_t(1));
    description.weight = 700;
    litehtml::uint_ptr bold = container.create_font(description, nullptr, nullptr);
    CHECK_EQ(host.fontsCreated, size_t(2));
    container.delete_font(font);
    container.delete_font(again);
    container.delete_font(bold);
    CHECK_EQ(FakeRenderHost::liveFonts(), liveBefore + 2);

    std::string text = "make it big";
    container.transform_text(text, litehtml::text_transform_uppercase);
    CHECK(text == "MAKE IT BIG");
    container.transform_text(text, litehtml::text_transform_lowercase);
    CHECK(text == "make it big");
    container.transform_text(text, litehtml::text_transform_capitalize);
    CHECK(text == "Make It Big");
}

// point_in_clip_path is the host's (Ruling P1); sanitizer_limit records each kind once per build; the inert callbacks
// change nothing.
WR_TEST(testHostQuestionsAndInertCallbacks) {
    FakeRenderHost host;
    wr::WidgetContainer container(host, options(300, 0));
    litehtml::vector_path triangle;
    triangle.ops = {litehtml::vector_path::move, litehtml::vector_path::line, litehtml::vector_path::line,
                    litehtml::vector_path::close};
    triangle.points = {10, 10, 30, 10, 30, 20};
    CHECK(container.point_in_clip_path(triangle, litehtml::pixel_t(15.0f), litehtml::pixel_t(15.0f)));
    CHECK(container.point_in_clip_path(triangle, litehtml::pixel_t(30.0f), litehtml::pixel_t(20.0f)));
    CHECK(!container.point_in_clip_path(triangle, litehtml::pixel_t(31.0f), litehtml::pixel_t(15.0f)));
    CHECK(!container.point_in_clip_path(triangle, litehtml::pixel_t(15.0f), litehtml::pixel_t(9.0f)));

    container.beginBuild();
    container.sanitizer_limit("elements");
    container.sanitizer_limit("depth");
    container.sanitizer_limit("elements");
    container.sanitizer_limit(nullptr);
    CHECK(container.limitsHit() == (std::vector<std::string>{"elements", "depth"}));
    CHECK_EQ(container.limitsHit().size(), size_t(2));
    container.beginBuild();
    CHECK(container.limitsHit().empty());
    container.sanitizer_limit("text");
    CHECK(container.limitsHit() == std::vector<std::string>{"text"});

    litehtml::document::ptr document = layOut(container, "<a href='http://x'>link</a>");
    container.on_anchor_click("http://x", document->root());
    CHECK(!container.on_element_click(document->root()));
    container.on_mouse_event(document->root(), litehtml::mouse_event_enter);
    container.set_cursor("pointer");
    container.set_caption("caption");
    container.set_base_url("http://x/");
    CHECK_EQ(container.refusedLoads(), uint64_t(0));
    CHECK(host.decodedMimeTypes.empty());
}
