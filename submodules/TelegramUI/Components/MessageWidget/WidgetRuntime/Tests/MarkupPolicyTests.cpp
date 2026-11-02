// Profile 1's markup rules (V4 plan, Tasks 4 and 5): what the renderer's copy of an element is (kept, rendered as a span
// or a div with data-tg-tag, or dropped with its subtree), as the reference validator decides it (widget-sandbox v0.1.0
// validator.ts, opEl). The widget's DOM keeps the element as it is.
#include <string>

#include "Sources/Host/MarkupPolicy.h"
#include "Tests/wr_test.h"

using wr::markup::ElementNamespace;

namespace {

std::string shown(const wr::markup::RenderTag& tag) {
    if (tag.stylesheet) {
        return "stylesheet";
    }
    return std::string(tag.rendered ? "1" : "0") + "|" + tag.tag + "|" + tag.dataTgTag;
}

struct Row {
    ElementNamespace ns;
    std::string name;
    bool adopted;
    const char* expected;
};

} // namespace

WR_TEST(testRenderTagFor) {
    const Row rows[] = {
        {ElementNamespace::HTML, "font", false, "1|span|font"},
        {ElementNamespace::HTML, "CENTER", false, "1|div|center"},
        {ElementNamespace::HTML, "input", false, "0||"},
        {ElementNamespace::HTML, "progress", false, "0||"},
        {ElementNamespace::HTML, "my-widget", false, "1|span|my-widget"},
        {ElementNamespace::HTML, "svg", false, "1|span|svg"},
        {ElementNamespace::HTML, "rect", false, "1|span|rect"},
        {ElementNamespace::HTML, "dialog", false, "1|div|dialog"},
        {ElementNamespace::HTML, "my-\xC3\xA9l\xC3\xA9ment", false, "0||"},
        {ElementNamespace::HTML, "a:b", false, "0||"},
        {ElementNamespace::HTML, std::string(65, 'a'), false, "0||"},
        {ElementNamespace::HTML, std::string(64, 'a'), false, ""},  // its expectation is built below
        {ElementNamespace::HTML, "title", false, "0||"},
        {ElementNamespace::HTML, "body", true, "1|body|"},
        {ElementNamespace::HTML, "body", false, "1|div|body"},
        {ElementNamespace::HTML, "html", false, "1|div|html"},
        {ElementNamespace::HTML, "style", false, "stylesheet"},
        {ElementNamespace::HTML, "div", false, "1|div|"},
        {ElementNamespace::SVG, "lineargradient", false, "1|linearGradient|"},
        {ElementNamespace::SVG, "clipPath", false, "0||"},
        {ElementNamespace::SVG, "div", false, "0||"},
        {ElementNamespace::SVG, "title", false, "1|title|"},
        {ElementNamespace::SVG, "a", false, "1|a|"},
        {ElementNamespace::SVG, "style", false, "stylesheet"},
        {ElementNamespace::SVG, "foreignObject", false, "0||"},
        {ElementNamespace::Other, "div", false, "0||"},
        {ElementNamespace::HTML, "video", false, "0||"},
    };
    std::string wrong;
    for (const Row& row : rows) {
        const std::string got = shown(wr::markup::renderTagFor(row.ns, row.name, row.adopted));
        // A 64-unit name is the longest kept: an unknown element.
        const std::string want = row.name == std::string(64, 'a') ? "1|span|" + std::string(64, 'a') : row.expected;
        if (got != want) {
            wrong += " [" + row.name + (row.adopted ? " adopted" : "") + " → " + got + ", want " + want + "]";
        }
    }
    CHECK_EQ(wrong, std::string(""));
}

namespace {

struct AttributeRow {
    ElementNamespace ns;
    const char* tag;
    const char* name;
    const char* value;
    const char* expected;
};

std::string shownAttribute(const wr::markup::RenderAttributeDecision& d) {
    if (!d.kept) {
        return "0";
    }
    return "1|" + d.name + "|" + d.value + "|" + (d.addsLink ? "1" : "0");
}

} // namespace

// RB §2.1–§2.4 (V4 plan, Task 5): the attribute gate in the reference's order.
WR_TEST(testTheAttributeRules) {
    using N = ElementNamespace;
    const AttributeRow rows[] = {
        {N::HTML, "div", "onclick", "x", "0"},
        {N::HTML, "div", "ONE", "x", "0"},
        {N::HTML, "div", "data-tg-tag", "x", "0"},
        {N::HTML, "div", "DATA-Foo", "v", "1|data-foo|v|0"},
        {N::HTML, "div", "aria-label", "v", "1|aria-label|v|0"},
        {N::HTML, "span", "contenteditable", "true", "0"},
        {N::HTML, "span", "tabindex", "0", "0"},
        {N::HTML, "span", "draggable", "true", "0"},
        {N::HTML, "div", "align", "center", "0"},
        {N::HTML, "td", "bgcolor", "red", "0"},
        {N::HTML, "span", "color", "red", "0"},
        {N::HTML, "div", "style", "color:red", "1|style|color:red|0"},
        {N::HTML, "style", "media", "print", "0"},
        {N::HTML, "div", "popover", "", "0"},
        {N::HTML, "div", ":class", "x", "0"},
        {N::HTML, "div", "@click", "x", "0"},
        {N::HTML, "div", "1x", "x", "0"},
        {N::HTML, "span", "disabled", "", "1|disabled||0"},
        {N::HTML, "div", "width", "10", "1|width|10|0"},
        {N::HTML, "a", "href", "https://x", "1|href|#|1"},
        {N::HTML, "a", "href", "#top", "1|href|#top|0"},
        {N::HTML, "a", "href", "#a b", "1|href|#|0"},
        {N::HTML, "a", "href", "", "1|href|#|1"},
        {N::HTML, "a", "href", "javascript:alert(1)", "1|href|#|1"},
        {N::SVG, "a", "xlink:href", "https://x", "1|href|#|1"},
        {N::SVG, "use", "href", "#i", "1|href|#i|0"},
        {N::SVG, "use", "href", "other.svg#i", "0"},
        {N::SVG, "rect", "href", "#x", "0"},
        {N::HTML, "div", "href", "#x", "0"},
        {N::HTML, "q", "cite", "x", "0"},
        {N::HTML, "button", "formaction", "x", "0"},
        {N::SVG, "svg", "viewbox", "0 0 1 1", "1|viewBox|0 0 1 1|0"},
        {N::SVG, "rect", "fill", "url(#g)", "1|fill|url(#g)|0"},
        {N::SVG, "rect", "fill", "url(https://x#g)", "0"},
        {N::SVG, "rect", "fill", "oklch(1 0 0)", "0"},
        {N::SVG, "rect", "clip-path", "url(#c)", "0"},
        // widget-sandbox v0.4.0 (sdk-v1 §2.17): env() rewritten as in a stylesheet.
        {N::SVG, "rect", "fill", "env(safe-area-inset-bottom, red)", "1|fill|var(--tg-content-safe-area-inset-bottom, red)|0"},
        {N::SVG, "rect", "stroke", "env(keyboard-inset-height, red)", "1|stroke|red|0"},
        {N::SVG, "rect", "stroke", "env(keyboard-inset-height)", "0"},
        {N::SVG, "rect", "fill", "url(env(safe-area-inset-bottom))", "0"},
        {N::SVG, "rect", "stroke-width", "env(safe-area-inset-bottom, 2px)", "1|stroke-width|env(safe-area-inset-bottom, 2px)|0"},
        {N::SVG, "text", "font-family", "Inter, monospace", "1|font-family|monospace|0"},
        {N::SVG, "svg", "overflow", "scroll", "1|overflow|scroll|0"},
        {N::HTML, "img", "src", "https://x", "1|src|https://x|0"},
        {N::HTML, "div", "src", "x", "0"},
        {N::HTML, "img", "srcset", "x", "0"},
        {N::HTML, "td", "background", "x", "0"},
        {N::HTML, "div", "xml:lang", "en", "0"},
        {N::SVG, "text", "xml:lang", "en", "1|xml:lang|en|0"},
    };
    std::string wrong;
    for (const AttributeRow& row : rows) {
        const std::string got = shownAttribute(wr::markup::renderAttribute(row.ns, row.tag, row.name, row.value));
        if (got != row.expected) {
            wrong += std::string(" [") + row.tag + " " + row.name + "=" + row.value + " → " + got + ", want " + row.expected + "]";
        }
    }
    CHECK_EQ(wrong, std::string(""));
}
