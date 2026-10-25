// Host test of twidget edit 12 (VENDOR.md): building a litehtml document from an external DOM (create_element,
// append_text, insert_child, external_element_allowed, finalize_from_external_root) and the master CSS in C++.
#include "test_container.h"

#include <litehtml/telegram_master_css.h>

#include <litehtml/render_inline_context.h>
#include <litehtml/render_item.h>

#include <malloc/malloc.h>

#include <algorithm>
#include <cstdio>
#include <functional>
#include <map>
#include <set>
#include <sstream>

static int failures = 0;

using litehtml::element;

// Records every vector path with what decides its pixels, so an SVG's drawing can be compared.
struct PathContainer : litehtml_test::TestContainer {
    std::vector<std::string> paths;
    void draw_path(litehtml::uint_ptr, const litehtml::vector_path& path) override {
        std::ostringstream out;
        out << "path ops=" << path.ops.size() << " pts=" << path.points.size() << " fill=" << path.fill
            << " color=" << int(path.fill_color.red) << ',' << int(path.fill_color.green) << ',' << int(path.fill_color.blue)
            << " gradient.type=" << path.fill_gradient.type << " stops=" << path.fill_gradient.stops.size();
        for (const auto& stop : path.fill_gradient.stops)
            out << " [" << stop.first << ' ' << int(stop.second.red) << ',' << int(stop.second.green) << ',' << int(stop.second.blue) << ']';
        paths.push_back(out.str());
    }
};

// A container that counts sanitizer_limit reports by kind.
struct LimitContainer : litehtml_test::TestContainer {
    std::vector<std::string> limits;
    void sanitizer_limit(const char* what) override { limits.push_back(what); }
};

static element::ptr make(const litehtml::document::ptr& doc, const char* tag, const litehtml::string_map& attrs = {}) {
    return doc->create_element(tag, attrs);
}

static void add(const litehtml::document::ptr& doc, const element::ptr& parent, const element::ptr& child) {
    doc->insert_child(parent, parent->children().size(), child);
}

static void text(const litehtml::document::ptr& doc, const element::ptr& parent, const char* t) {
    std::vector<element::ptr> pieces;
    doc->append_text(parent, t, pieces);
}

// One line per element below `el`, in tree order: tag, x, y, width, height. A <style>'s text is one piece when
// built externally and split when parsed, so its pieces are not dumped.
static void dump(const element::ptr& el, int depth, std::ostringstream& out) {
    auto pos = el->get_placement();
    out << std::string(depth, ' ') << el->get_tagName() << ' ' << float(pos.x) << ' ' << float(pos.y) << ' '
        << float(pos.width) << ' ' << float(pos.height) << '\n';
    if (el->tag() == litehtml::_style_) return;
    for (const auto& child : el->children()) dump(child, depth + 1, out);
}

static std::string dump_of(const litehtml::document::ptr& doc) {
    std::ostringstream out;
    dump(doc->root(), 0, out);
    return out.str();
}

static int count_elements(const element::ptr& el) {
    int n = 1;
    for (const auto& child : el->children()) n += count_elements(child);
    return n;
}

static std::string draws(const litehtml_test::TestContainer& c) {
    std::string s;
    for (const auto& call : c.calls) s += call.kind + ",";
    return s;
}

static void testExternalBuildMatchesParse() {
    const char* html =
        "<html><head><style>p{color:red} .a b{font-weight:bold}</style></head><body><p class=a>Hello <b>big</b>  world</p>"
        "<ul><li>x</li><li>y</li></ul></body></html>";
    litehtml_test::TestContainer external;
    auto doc = std::make_shared<litehtml::document>(&external);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = make(doc, "html");
    auto head = make(doc, "head");
    auto style = make(doc, "style");
    text(doc, style, "p{color:red} .a b{font-weight:bold}");
    add(doc, head, style);
    add(doc, root, head);
    auto body = make(doc, "body");
    auto p = make(doc, "p", {{"class", "a"}});
    text(doc, p, "Hello ");
    auto b = make(doc, "b");
    text(doc, b, "big");
    add(doc, p, b);
    text(doc, p, "  world");
    add(doc, body, p);
    auto ul = make(doc, "ul");
    for (const char* t : {"x", "y"}) {
        auto li = make(doc, "li");
        text(doc, li, t);
        add(doc, ul, li);
    }
    add(doc, body, ul);
    add(doc, root, body);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(300.0f));

    litehtml_test::TestContainer parsed;
    auto reference = litehtml::document::createFromString(litehtml::estring(html), &parsed, litehtml::telegram_master_css());
    reference->render(litehtml::pixel_t(300.0f));

    CHECK(dump_of(doc) == dump_of(reference));
    CHECK(dump_of(doc).find("p ") != std::string::npos);
    CHECK(float(doc->height()) > 0.0f && float(doc->height()) == float(reference->height()));
}

static void testExternalSvgMatchesParse() {
    // No doctype: the parse of this markup is in quirks mode, so the builder sets the same.
    const char* html =
        "<svg viewBox=\"0 0 20 20\" width=20 height=20><defs><linearGradient id=g><stop offset=0 stop-color=red /></linearGradient></defs>"
        "<rect width=10 height=10 fill=\"url(#g)\"/></svg>";
    PathContainer external;
    auto doc = std::make_shared<litehtml::document>(&external);
    doc->set_document_mode(litehtml::quirks_mode);
    auto root = make(doc, "html");
    auto head = make(doc, "head");
    add(doc, root, head);
    auto body = make(doc, "body");
    auto svg = make(doc, "svg", {{"viewBox", "0 0 20 20"}, {"width", "20"}, {"height", "20"}});
    auto defs = make(doc, "defs");
    auto grad = make(doc, "linearGradient", {{"id", "g"}});
    add(doc, grad, make(doc, "stop", {{"offset", "0"}, {"stop-color", "red"}}));
    add(doc, defs, grad);
    add(doc, svg, defs);
    add(doc, svg, make(doc, "rect", {{"width", "10"}, {"height", "10"}, {"fill", "url(#g)"}}));
    add(doc, body, svg);
    add(doc, root, body);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(300.0f));
    litehtml::position clip(0, 0, 300, 300);
    doc->draw(1, 0, 0, &clip);

    PathContainer parsed;
    auto reference = litehtml::document::createFromString(litehtml::estring(std::string("<html><head></head><body>") + html + "</body></html>"),
                                                          &parsed, litehtml::telegram_master_css());
    reference->render(litehtml::pixel_t(300.0f));
    reference->draw(1, 0, 0, &clip);

    CHECK(dump_of(doc) == dump_of(reference));
    CHECK(!external.paths.empty());
    CHECK(external.paths == parsed.paths);
    CHECK(!external.paths.empty() && external.paths[0].find("stops=1") != std::string::npos);
    CHECK(draws(external) == draws(parsed));
}

static void testInsertChildAtEveryIndex() {
    litehtml_test::TestContainer c;
    auto doc = std::make_shared<litehtml::document>(&c);
    auto parent = make(doc, "div");
    auto a = make(doc, "a"), b = make(doc, "b"), i = make(doc, "i"), u = make(doc, "u");
    doc->insert_child(parent, 0, a);   // [a]
    doc->insert_child(parent, 1, b);   // [a b]
    doc->insert_child(parent, 1, i);   // [a i b]
    doc->insert_child(parent, 0, u);   // [u a i b]
    auto s = make(doc, "s");
    doc->insert_child(parent, 4, s);   // [u a i b s]
    const std::vector<element::ptr> expected = {u, a, i, b, s};
    CHECK(parent->children().size() == expected.size());
    size_t k = 0;
    for (const auto& child : parent->children()) {
        CHECK(k < expected.size() && child == expected[k]);
        CHECK(child->parent() == parent);
        k++;
    }
}

static void testRemoveChildRepointsHover() {
    litehtml_test::TestContainer c;
    auto doc = litehtml::document::createFromString(
        litehtml::estring("<body style='margin:0'><div id=d style='width:100px;height:50px'><p id=p style='margin:0;width:100px;height:50px'>hi</p></div></body>"),
        &c, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(300.0f));
    auto d = doc->root()->select_one("#d");
    auto p = doc->root()->select_one("#p");
    CHECK(d && p);
    doc->on_mouse_over(litehtml::pixel_t(5.0f), litehtml::pixel_t(5.0f), litehtml::pixel_t(5.0f), litehtml::pixel_t(5.0f), [](const litehtml::position&) {});
    CHECK(doc->get_over_element() == p);
    doc->remove_child(p);
    CHECK(doc->get_over_element() == d);
    CHECK(p->parent() == nullptr);
    CHECK(d->children().empty());
}

static void testTextPiecesFollowTheCap() {
    LimitContainer c;
    auto doc = std::make_shared<litehtml::document>(&c);
    auto parent = make(doc, "p");
    std::vector<element::ptr> pieces;
    bool all = true;
    for (int n = 0; n < 10000; n++) all = doc->append_text(parent, "w", pieces) && all;
    CHECK(all);
    CHECK(pieces.size() == 10000);
    CHECK(c.limits.empty());
    CHECK(!doc->append_text(parent, "w", pieces));
    CHECK(pieces.size() == 10000);
    CHECK(c.limits.size() == 1 && c.limits[0] == "text");
}

// Telegram (VENDOR.md edit 16): text patched in place. A document html > body > [p "before", <tag> text, p "after"],
// built externally; `target` gets the <tag>.
static litehtml::document::ptr textDocument(litehtml_test::TestContainer& c, const char* tag, const char* t,
                                             element::ptr& target) {
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = make(doc, "html");
    auto body = make(doc, "body");
    auto before = make(doc, "p");
    text(doc, before, "before");
    add(doc, body, before);
    target = make(doc, tag);
    if (*t) text(doc, target, t);
    add(doc, body, target);
    auto after = make(doc, "p");
    text(doc, after, "after text here");
    add(doc, body, after);
    add(doc, root, body);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(120.0f));
    return doc;
}

static std::string drawn(litehtml_test::TestContainer& c, const litehtml::document::ptr& doc) {
    c.calls.clear();
    litehtml::position clip(0, 0, 1000, 1000);
    doc->draw(0, 0, 0, &clip);
    return draws(c);
}

static void patchedMatchesFresh(const char* tag, const char* before, const char* after) {
    litehtml_test::TestContainer c, fresh;
    element::ptr target, expected;
    auto doc = textDocument(c, tag, before, target);
    auto reference = textDocument(fresh, tag, after, expected);
    std::vector<element::ptr> pieces;
    const size_t count = target->children().size();
    CHECK(doc->replace_text(target, 0, count, after, pieces));
    CHECK(pieces.size() == expected->children().size());
    for (const auto& piece : pieces) CHECK(piece->parent() == target);
    CHECK(target->children().size() == pieces.size());
    doc->commit_patch();
    doc->render(litehtml::pixel_t(120.0f));
    CHECK(dump_of(doc) == dump_of(reference));
    CHECK(float(doc->height()) == float(reference->height()));
    CHECK(drawn(c, doc) == drawn(fresh, reference));
}

static void testReplaceTextMatchesFresh() {
    patchedMatchesFresh("p", "hello world", "other thing");            // the same piece count
    patchedMatchesFresh("p", "hello world", "one two three four five six seven eight nine ten");   // more words, wraps
    patchedMatchesFresh("p", "one two three four five six seven eight nine ten", "hi");          // fewer words
    patchedMatchesFresh("p", "hello world", "   ");                    // whitespace only
    patchedMatchesFresh("p", "   ", "now words again");
    patchedMatchesFresh("pre", "a  b\n  c", "line one\n    line two\nthree");  // inside pre
    patchedMatchesFresh("li", "item", "a longer item text for the list");
    patchedMatchesFresh("div", "x", "y");
    // Several replacements in one session, then one commit.
    litehtml_test::TestContainer c, fresh;
    element::ptr target, expected;
    auto doc = textDocument(c, "p", "alpha beta", target);
    auto reference = textDocument(fresh, "p", "gamma delta epsilon", expected);
    std::vector<element::ptr> first, second;
    CHECK(doc->replace_text(target, 0, target->children().size(), "alpha beta gamma", first));
    CHECK(doc->replace_text(target, 0, first.size(), "gamma delta epsilon", second));
    doc->commit_patch();
    doc->render(litehtml::pixel_t(120.0f));
    CHECK(dump_of(doc) == dump_of(reference));
    // Nothing collected: commit_patch changes nothing.
    const std::string before = dump_of(doc);
    doc->commit_patch();
    doc->render(litehtml::pixel_t(120.0f));
    CHECK(dump_of(doc) == before);
}

// A <p> of text, a <b> and more text: the first run is not all of its parent's content, so the render tree is rebuilt.
static litehtml::document::ptr mixedDocument(litehtml_test::TestContainer& c, const char* first, element::ptr& target) {
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = make(doc, "html");
    auto body = make(doc, "body");
    target = make(doc, "p");
    text(doc, target, first);
    auto b = make(doc, "b");
    text(doc, b, "bold");
    add(doc, target, b);
    text(doc, target, " tail words here");
    add(doc, body, target);
    auto after = make(doc, "p");
    text(doc, after, "after");
    add(doc, body, after);
    add(doc, root, body);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(120.0f));
    return doc;
}

static void testReplaceTextBesideElements() {
    for (const char* after : {"one two three four five six seven", "x", "  "}) {
        litehtml_test::TestContainer c, fresh;
        element::ptr target, expected;
        auto doc = mixedDocument(c, "lead words", target);
        auto reference = mixedDocument(fresh, after, expected);
        // The leading run: "lead words" is three pieces.
        std::vector<element::ptr> pieces;
        CHECK(doc->replace_text(target, 0, 3, after, pieces));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(120.0f));
        CHECK(dump_of(doc) == dump_of(reference));
        CHECK(drawn(c, doc) == drawn(fresh, reference));
    }
}

static void testReplaceTextRefusals() {
    {
        // A <style>'s text is a sheet, not content.
        litehtml_test::TestContainer c;
        auto doc = std::make_shared<litehtml::document>(&c);
        doc->set_document_mode(litehtml::no_quirks_mode);
        auto root = make(doc, "html");
        auto head = make(doc, "head");
        auto style = make(doc, "style");
        text(doc, style, "p{color:red}");
        add(doc, head, style);
        add(doc, root, head);
        auto body = make(doc, "body");
        auto p = make(doc, "p");
        text(doc, p, "x");
        add(doc, body, p);
        add(doc, root, body);
        doc->finalize_from_external_root(root, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(120.0f));
        const std::string before = dump_of(doc);
        std::vector<element::ptr> pieces;
        CHECK(!doc->replace_text(style, 0, 1, "p{color:blue}", pieces));
        CHECK(pieces.empty());
        CHECK(!doc->can_replace_text(style, 0, 1, "p{color:blue}"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(120.0f));
        CHECK(dump_of(doc) == before);
        // Not a run of text pieces, and out of range.
        CHECK(!doc->replace_text(body, 0, 1, "y", pieces));
        CHECK(!doc->replace_text(p, 0, 2, "y", pieces));
        CHECK(!doc->replace_text(p, 2, 0, "y", pieces));
        CHECK(!doc->replace_text(nullptr, 0, 0, "y", pieces));
        CHECK(doc->replace_text(p, 0, 1, "z", pieces));
        doc->commit_patch();
    }
    {
        // Generated content and drawing that read their text: a select's label, an svg's text.
        litehtml_test::TestContainer c;
        auto doc = std::make_shared<litehtml::document>(&c);
        doc->set_document_mode(litehtml::no_quirks_mode);
        auto root = make(doc, "html");
        auto body = make(doc, "body");
        auto select = make(doc, "select");
        auto option = make(doc, "option");
        text(doc, option, "one");
        add(doc, select, option);
        add(doc, body, select);
        auto button = make(doc, "button");
        text(doc, button, "go");
        add(doc, body, button);
        add(doc, root, body);
        doc->finalize_from_external_root(root, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(120.0f));
        std::vector<element::ptr> pieces;
        CHECK(!doc->can_replace_text(option, 0, 1, "two"));
        CHECK(!doc->replace_text(option, 0, 1, "two", pieces));
        CHECK(!doc->replace_text(button, 0, 1, "stop", pieces));
        CHECK(pieces.empty());
    }
    {
        // The text cap: a replacement that would pass it changes nothing; one that fits does not.
        LimitContainer c;
        auto doc = std::make_shared<litehtml::document>(&c);
        doc->set_document_mode(litehtml::no_quirks_mode);
        auto root = make(doc, "html");
        auto body = make(doc, "body");
        auto p = make(doc, "p");
        std::vector<element::ptr> built;
        for (int n = 0; n < 9999; n++) doc->append_text(p, "w", built);
        add(doc, body, p);
        auto q = make(doc, "p");
        text(doc, q, "a");
        add(doc, body, q);
        add(doc, root, body);
        doc->finalize_from_external_root(root, litehtml::telegram_master_css());
        std::vector<element::ptr> pieces;
        CHECK(doc->text_elements() == 10000);
        CHECK(!doc->can_replace_text(q, 0, 1, "a b"));       // 3 pieces for 1: 10002
        CHECK(!doc->replace_text(q, 0, 1, "a b", pieces));
        CHECK(pieces.empty() && q->children().size() == 1);
        int growth = 0;
        CHECK(doc->can_replace_text(q, 0, 1, "b", 0, &growth) && growth == 0);
        CHECK(doc->can_replace_text(q, 0, 1, "", 0, &growth) && growth == -1);
        // pending_growth counts replacements planned and not made.
        CHECK(!doc->can_replace_text(q, 0, 1, "b", 1));
        CHECK(doc->replace_text(q, 0, 1, "b", pieces));
        // The session counts what it made, not what it replaced: the old piece is still alive.
        CHECK(doc->replace_text(q, 0, 1, "c", pieces));
        CHECK(!doc->replace_text(q, 0, 1, "c d", pieces));
        doc->commit_patch();
        CHECK(doc->text_elements() == 10000);
    }
}

static void testReplaceTextRepointsHover() {
    litehtml_test::TestContainer c;
    auto doc = litehtml::document::createFromString(
        litehtml::estring("<body style='margin:0'><div id=d style='width:100px;height:50px'>hello</div></body>"), &c,
        litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(300.0f));
    auto d = doc->root()->select_one("#d");
    CHECK(d && !d->children().empty());
    doc->on_mouse_over(litehtml::pixel_t(2.0f), litehtml::pixel_t(2.0f), litehtml::pixel_t(2.0f), litehtml::pixel_t(2.0f), [](const litehtml::position&) {});
    auto over = doc->get_over_element();
    CHECK(over);
    std::vector<element::ptr> pieces;
    CHECK(doc->replace_text(d, 0, d->children().size(), "bye now", pieces));
    doc->commit_patch();
    CHECK(doc->get_over_element() == over || doc->get_over_element() == d);
    for (const auto& piece : pieces) CHECK(doc->get_over_element() != piece);
}

// Telegram (VENDOR.md edit 17): attributes patched in place. A container that records what is painted with its
// colors and boxes, and gives two data URLs two sizes.
struct PaintContainer : litehtml_test::TestContainer {
    std::vector<std::string> log;
    std::vector<std::string> limits;
    void sanitizer_limit(const char* what) override { limits.push_back(what); }
    void get_image_size(const char* url, const char*, litehtml::size& sz) override {
        const std::string u = url ? url : "";
        sz.width = u == "data:b" ? 30 : (u == "data:a" ? 10 : 0);
        sz.height = u == "data:b" ? 20 : (u == "data:a" ? 10 : 0);
    }
    static std::string box(const litehtml::position& p) {
        std::ostringstream out;
        out << float(p.x) << ',' << float(p.y) << ',' << float(p.width) << ',' << float(p.height);
        return out.str();
    }
    static std::string color(const litehtml::web_color& c) {
        std::ostringstream out;
        out << int(c.red) << '.' << int(c.green) << '.' << int(c.blue) << '.' << int(c.alpha);
        return out.str();
    }
    void draw_solid_fill(litehtml::uint_ptr, const litehtml::background_layer& l, const litehtml::web_color& c) override {
        log.push_back("fill " + box(l.border_box) + ' ' + color(c));
    }
    void draw_text(litehtml::uint_ptr, const char* t, litehtml::uint_ptr, litehtml::web_color c, const litehtml::position& p) override {
        log.push_back(std::string("text ") + t + ' ' + box(p) + ' ' + color(c));
    }
    void draw_image(litehtml::uint_ptr, const litehtml::background_layer& l, const std::string& url, const std::string&) override {
        log.push_back("image " + url + ' ' + box(l.border_box));
    }
    void draw_borders(litehtml::uint_ptr, const litehtml::borders&, const litehtml::position& p, bool) override {
        log.push_back("borders " + box(p));
    }
    void draw_path(litehtml::uint_ptr, const litehtml::vector_path& path) override {
        log.push_back("path fill=" + std::to_string(path.fill) + ' ' + color(path.fill_color) + " pts=" + std::to_string(path.points.size()));
    }
};

static const char* beforeText = "before";   // the paragraph before the target
static int fillerWords = 0;   // a paragraph of this many words before the target, to put the text pieces near their cap

// html > [head > style(sheet)] body > p "before", <tag attrs> (an svg > <tag> for "circle"), p "after text here".
static litehtml::document::ptr attrDocument(PaintContainer& c, const char* sheet, const char* tag,
                                            const litehtml::string_map& attrs, element::ptr& target) {
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = make(doc, "html");
    if (*sheet) {
        auto head = make(doc, "head");
        auto style = make(doc, "style");
        text(doc, style, sheet);
        add(doc, head, style);
        add(doc, root, head);
    }
    const std::string name = tag;
    auto body = make(doc, "body", name == "body" ? attrs : litehtml::string_map());
    auto before = make(doc, "p");
    text(doc, before, beforeText);
    add(doc, body, before);
    if (fillerWords > 0) {
        auto filler = make(doc, "p");
        std::string words;
        for (int n = 0; n < fillerWords; n++) words += n ? " w" : "w";
        text(doc, filler, words.c_str());
        add(doc, body, filler);
    }
    target = name == "body" ? body : make(doc, name == "a+span" ? "a" : tag, attrs);
    if (name == "body") {
        text(doc, body, "box text");
    } else if (name == "a+span") {
        auto span = make(doc, "span");
        text(doc, span, "inner text");
        add(doc, target, span);
        add(doc, body, target);
    } else if (name == "svg") {
        auto circle = make(doc, "circle", {{"cx", "20"}, {"cy", "20"}, {"r", "10"}, {"fill", "red"}});
        add(doc, target, circle);
        add(doc, body, target);
    } else if (name == "circle") {
        auto svg = make(doc, "svg", {{"width", "40"}, {"height", "40"}, {"viewBox", "0 0 40 40"}});
        add(doc, svg, target);
        add(doc, body, svg);
    } else {
        if (name != "input" && name != "img") text(doc, target, name == "a" ? "link text" : "box text");
        add(doc, body, target);
    }
    auto after = make(doc, "p");
    text(doc, after, "after text here");
    add(doc, body, after);
    add(doc, root, body);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(160.0f));
    return doc;
}

static std::string painted(PaintContainer& c, const litehtml::document::ptr& doc) {
    c.log.clear();
    litehtml::position clip(0, 0, 1000, 1000);
    doc->draw(0, 0, 0, &clip);
    std::string s;
    for (const auto& line : c.log) s += line + '\n';
    return s;
}

// The patched document equals one built with the final attributes: positions, height and everything painted.
static void attributePatchedMatchesFresh(const char* sheet, const char* tag, litehtml::string_map before, const char* name,
                                         const char* value) {
    PaintContainer c, fresh;
    element::ptr target, expected;
    auto doc = attrDocument(c, sheet, tag, before, target);
    auto after = before;
    if (value) after[name] = value; else after.erase(name);
    auto reference = attrDocument(fresh, sheet, tag, after, expected);
    CHECK(doc->can_set_element_attribute(target, name, value));
    CHECK(doc->set_element_attribute(target, name, value));
    doc->commit_patch();
    doc->render(litehtml::pixel_t(160.0f));
    const bool same = dump_of(doc) == dump_of(reference) && float(doc->height()) == float(reference->height()) &&
                      painted(c, doc) == painted(fresh, reference);
    if (!same) std::printf("  differs: <%s> %s=%s\n", tag, name, value ? value : "(removed)");
    CHECK(dump_of(doc) == dump_of(reference));
    CHECK(float(doc->height()) == float(reference->height()));
    CHECK(painted(c, doc) == painted(fresh, reference));
}

static void testSetAttributeMatchesFresh() {
    const char* sheet = ".a{color:#c00;background:#00f;padding:2px} .b{color:#0a0;font-weight:bold} .c{background:#fc0}"
                        "#x{background:#ccc;padding:4px} #y{background:#fc0;padding:12px;margin:3px}"
                        "[hidden]{display:none} a:link{color:#909} input:checked{outline:1px solid #f00}";
    // A class toggle (added, swapped, removed) and an id change.
    attributePatchedMatchesFresh(sheet, "p", {}, "class", "a");
    attributePatchedMatchesFresh(sheet, "div", {{"class", "a"}}, "class", "b");
    attributePatchedMatchesFresh(sheet, "div", {{"class", "a"}}, "class", "a c");
    attributePatchedMatchesFresh(sheet, "div", {{"class", "b"}}, "class", nullptr);
    attributePatchedMatchesFresh(sheet, "div", {{"id", "x"}}, "id", "y");
    attributePatchedMatchesFresh(sheet, "div", {}, "id", "x");
    // Inline style: a local change and a background-only one.
    attributePatchedMatchesFresh(sheet, "div", {{"style", "color:#c00"}}, "style", "color:#00c;padding:6px");
    attributePatchedMatchesFresh(sheet, "div", {{"style", "background:#f00"}}, "style", "background:#0f0");
    attributePatchedMatchesFresh(sheet, "div", {}, "style", "background:#0f0;width:50px");
    attributePatchedMatchesFresh(sheet, "div", {{"style", "color:#c00"}}, "style", nullptr);
    // hidden.
    attributePatchedMatchesFresh(sheet, "div", {}, "hidden", "");
    attributePatchedMatchesFresh(sheet, "div", {{"hidden", ""}}, "hidden", nullptr);
    // A checkbox's checked and a text input's value.
    attributePatchedMatchesFresh(sheet, "input", {{"type", "checkbox"}}, "checked", "");
    attributePatchedMatchesFresh(sheet, "input", {{"type", "checkbox"}, {"checked", ""}}, "checked", nullptr);
    attributePatchedMatchesFresh(sheet, "input", {{"type", "text"}, {"value", "ab"}}, "value", "abcdef");
    attributePatchedMatchesFresh(sheet, "input", {{"type", "text"}, {"value", "ab"}}, "value", nullptr);
    attributePatchedMatchesFresh(sheet, "input", {{"type", "text"}, {"value", "ab"}}, "placeholder", "hint");
    attributePatchedMatchesFresh(sheet, "input", {{"type", "text"}, {"value", "ab"}}, "type", "number");
    // img src between two data URLs; an anchor's href; an svg shape's fill.
    attributePatchedMatchesFresh(sheet, "img", {{"src", "data:a"}}, "src", "data:b");
    attributePatchedMatchesFresh(sheet, "a", {{"href", "x"}}, "href", "y");
    attributePatchedMatchesFresh(sheet, "a", {{"href", "x"}}, "href", nullptr);
    attributePatchedMatchesFresh(sheet, "a", {}, "href", "x");
    attributePatchedMatchesFresh(sheet, "circle", {{"cx", "20"}, {"cy", "20"}, {"r", "10"}, {"fill", "red"}}, "fill", "blue");
    attributePatchedMatchesFresh(sheet, "circle", {{"cx", "20"}, {"cy", "20"}, {"r", "10"}}, "r", "15");
    // Several changes in one session, then one commit; the same attribute twice.
    {
        PaintContainer c, fresh;
        element::ptr target, expected;
        auto doc = attrDocument(c, sheet, "div", {{"class", "a"}}, target);
        auto reference = attrDocument(fresh, sheet, "div", {{"class", "b"}, {"id", "y"}, {"style", "width:60px"}}, expected);
        CHECK(doc->set_element_attribute(target, "id", "x"));
        CHECK(doc->set_element_attribute(target, "class", "b"));
        CHECK(doc->set_element_attribute(target, "id", "y"));
        CHECK(doc->set_element_attribute(target, "style", "width:60px"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(160.0f));
        CHECK(dump_of(doc) == dump_of(reference));
        CHECK(painted(c, doc) == painted(fresh, reference));
    }
    // Setting what is already there changes nothing.
    {
        PaintContainer c;
        element::ptr target;
        auto doc = attrDocument(c, sheet, "div", {{"class", "a"}}, target);
        const std::string before = dump_of(doc);
        CHECK(doc->set_element_attribute(target, "class", "a"));
        CHECK(doc->set_element_attribute(target, "id", nullptr));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(160.0f));
        CHECK(dump_of(doc) == before);
    }
}

static void attributeRefused(const char* sheet, const char* tag, litehtml::string_map attrs, const char* name, const char* value) {
    PaintContainer c;
    element::ptr target;
    auto doc = attrDocument(c, sheet, tag, attrs, target);
    const std::string before = dump_of(doc);
    const std::string paint = painted(c, doc);
    if (doc->can_set_element_attribute(target, name, value)) std::printf("  accepted: <%s> %s\n", tag, name);
    CHECK(!doc->can_set_element_attribute(target, name, value));
    CHECK(!doc->set_element_attribute(target, name, value));
    doc->commit_patch();
    doc->render(litehtml::pixel_t(160.0f));
    CHECK(dump_of(doc) == before);
    CHECK(painted(c, doc) == paint);
}

// Telegram (VENDOR.md edit 17), fix round 1.
static void testSetAttributeFixRound() {
    // I1: :link in an ancestor position names href, so an href change reaches the span and is refused either way.
    attributeRefused("a:link span{color:#c00} span{color:#00c}", "a+span", {}, "href", "x");
    attributeRefused("a:link span{color:#c00} span{color:#00c}", "a+span", {{"href", "x"}}, "href", nullptr);
    attributeRefused("a:link span{color:#c00} span{color:#00c}", "a+span", {{"href", "x"}}, "href", "y");
    // ... while a class on the anchor, which no selector names, still patches, and the span follows the anchor.
    attributePatchedMatchesFresh("a:link span{color:#c00} span{color:#00c} .k{font-weight:bold}", "a+span", {{"href", "x"}}, "class", "k");

    // I4: href x -> y -> x -> y, one commit each: :link must survive the memo (match epoch).
    {
        PaintContainer c, fresh;
        element::ptr target, expected;
        const char* sheet = "a:link{color:#909} a{color:#090}";
        auto doc = attrDocument(c, sheet, "a", {{"href", "x"}}, target);
        auto reference = attrDocument(fresh, sheet, "a", {{"href", "y"}}, expected);
        for (const char* href : {"y", "x", "y"}) {
            CHECK(doc->set_element_attribute(target, "href", href));
            doc->commit_patch();
            doc->render(litehtml::pixel_t(160.0f));
        }
        CHECK(doc->root()->select_one("a:link") != nullptr);
        CHECK(dump_of(doc) == dump_of(reference));
        CHECK(painted(c, doc) == painted(fresh, reference));
    }

    // I3: one re-match for a whole attribute map.
    {
        PaintContainer c, fresh;
        element::ptr target, expected;
        const char* sheet = ".a{color:#c00} .b{color:#0a0;padding:3px} #y{background:#fc0}";
        auto doc = attrDocument(c, sheet, "div", {{"class", "a"}}, target);
        auto reference = attrDocument(fresh, sheet, "div", {{"class", "b"}, {"id", "y"}, {"style", "width:60px"}, {"data-x", "1"}}, expected);
        CHECK(doc->attribute_rematches() == 0);
        CHECK(doc->set_element_attributes(target, {{"class", "b"}, {"id", "y"}, {"style", "width:60px"}, {"data-x", "1"}}));
        CHECK(doc->attribute_rematches() == 1);
        doc->commit_patch();
        doc->render(litehtml::pixel_t(160.0f));
        CHECK(dump_of(doc) == dump_of(reference));
        CHECK(painted(c, doc) == painted(fresh, reference));
        // The same map again: nothing to do.
        CHECK(doc->set_element_attributes(target, {{"class", "b"}, {"id", "y"}, {"style", "width:60px"}, {"data-x", "1"}}));
        CHECK(doc->attribute_rematches() == 1);
        // The single-attribute form is one re-match each.
        CHECK(doc->set_element_attribute(target, "class", "a"));
        CHECK(doc->set_element_attribute(target, "data-x", "2"));
        CHECK(doc->attribute_rematches() == 3);
        doc->commit_patch();
    }

    // The svg element itself, body's style, a mixed-case and a prefixed attribute.
    attributePatchedMatchesFresh("", "svg", {{"width", "40"}, {"height", "40"}, {"viewBox", "0 0 40 40"}}, "width", "60");
    attributePatchedMatchesFresh("", "svg", {{"width", "40"}, {"height", "40"}, {"viewBox", "0 0 40 40"}}, "viewBox", "0 0 20 20");
    attributePatchedMatchesFresh("", "svg", {{"width", "40"}, {"height", "40"}, {"viewBox", "0 0 40 40"}}, "viewBox", nullptr);
    attributePatchedMatchesFresh("", "body", {{"style", "margin:0"}}, "style", "margin:10px;background:#eee");
    attributePatchedMatchesFresh("", "body", {}, "style", "margin:0;color:#c00");
    attributePatchedMatchesFresh("", "circle", {{"cx", "20"}, {"cy", "20"}, {"r", "10"}}, "xlink:title", "t");
    attributePatchedMatchesFresh("", "circle", {{"cx", "20"}, {"cy", "20"}, {"r", "10"}, {"Fill", "red"}}, "Fill", "blue");

    // I2: while a ::before or ::after rule with content could match, no patch is made: near the text-piece cap a patch and
    // a rebuild cut at different words. The shapes that got past a byte bound: function name case and spacing, and a
    // second element's rule whose content overlaps in a fresh build.
    {
        const char* sheets[] = {
            ".x::before{content:\"a b c d\"} .x{color:#c00}",
            ".x::before{content:ATTR(title)} .z::before{content:\"q\"}",
            ".x::before{content:attr (title)} .z::before{content:\"q\"}",
            "[title]::before{content:attr(title)} .k::before{content:attr(title)} .x::before{content:\"a b c d\"}",
            ".x:after{content:\"a b c d\"}",
        };
        for (const char* sheet : sheets) {
            for (int words : {0, 4000, 4990, 5004}) {
                fillerWords = words;
                PaintContainer c;
                element::ptr target;
                auto doc = attrDocument(c, sheet, "div", {{"title", "t t t t t t t t t t"}}, target);
                CHECK(doc->pseudo_content_possible());
                if (doc->can_set_element_attribute(target, "class", "x")) std::printf("  accepted with pseudo content: %s\n", sheet);
                CHECK(!doc->can_set_element_attribute(target, "class", "x"));
                CHECK(!doc->set_element_attribute(target, "class", "x"));
                // The same for a text patch (edit 16).
                std::vector<element::ptr> pieces;
                CHECK(!doc->can_replace_text(target, 0, target->children().size(), "other words"));
                CHECK(!doc->replace_text(target, 0, target->children().size(), "other words", pieces));
            }
        }
        fillerWords = 0;
        // What is not content does not count: a pseudo-element rule without `content`, with `content:none`, and content
        // on a real element; and then patches work near the cap and equal a fresh build, limits included.
        for (const char* sheet : {".x::before{color:#c00}", ".x::before{content:none}", ".x{color:#c00;content:\"abc\"}",
                                  ".x::first-line{color:#c00}"}) {
            int accepted = 0;
            for (int words = 4950; words <= 5010; words += 7) {
                fillerWords = words;
                PaintContainer c, fresh;
                element::ptr target, expected;
                auto doc = attrDocument(c, sheet, "div", {}, target);
                auto reference = attrDocument(fresh, sheet, "div", {{"class", "x"}}, expected);
                CHECK(!doc->pseudo_content_possible());
                if (!doc->set_element_attribute(target, "class", "x")) continue;
                accepted++;
                doc->commit_patch();
                doc->render(litehtml::pixel_t(160.0f));
                CHECK(dump_of(doc) == dump_of(reference));
                CHECK(painted(c, doc) == painted(fresh, reference));
                CHECK(c.limits == fresh.limits);
                CHECK(doc->text_elements() == reference->text_elements());
            }
            CHECK(accepted > 0);
        }
        fillerWords = 0;
        // The master sheet's own rules: summary::before declares content, so a document with a <summary> is refused and
        // one without is not.
        {
            PaintContainer c;
            element::ptr target;
            auto without = attrDocument(c, "", "div", {}, target);
            CHECK(!without->pseudo_content_possible());
            CHECK(without->can_set_element_attribute(target, "class", "x"));
            auto doc = std::make_shared<litehtml::document>(&c);
            doc->set_document_mode(litehtml::no_quirks_mode);
            auto root = make(doc, "html");
            auto body = make(doc, "body");
            auto details = make(doc, "details");
            auto summary = make(doc, "summary");
            text(doc, summary, "sum");
            add(doc, details, summary);
            auto p = make(doc, "p");
            text(doc, p, "text");
            add(doc, details, p);
            add(doc, body, details);
            add(doc, root, body);
            doc->finalize_from_external_root(root, litehtml::telegram_master_css());
            doc->render(litehtml::pixel_t(160.0f));
            CHECK(doc->pseudo_content_possible());
            CHECK(!doc->can_set_element_attribute(p, "class", "x"));
            CHECK(!doc->can_replace_text(p, 0, 1, "other"));
        }
    }

    // A control makes its lh-* parts when it is matched again: a rule for one counts wherever a control could make it, and the
    // flag is read afresh after each commit. type text -> range in one patch, then a text patch near the cap: whatever
    // is accepted equals a fresh build with the same text.
    {
        const char* sheet = "lh-range-thumb::before{content:\"B1 B2 B3 B4 B5 B6 B7 B8 B9 B10 B11 B12 B13 B14 B15 B16 B17 B18 B19 B20\"}"
                            " input lh-range-thumb::before{content:\"q\"}";
        const char* newText = "n1 n2 n3 n4 n5 n6 n7 n8 n9 n10 n11 n12 n13 n14 n15 n16 n17 n18 n19 n20";
        int typed = 0, texted = 0;
        for (int words = 4900; words <= 5010; words += 3) {
            fillerWords = words;
            PaintContainer c, fresh;
            element::ptr target, expected;
            auto doc = attrDocument(c, sheet, "input", {{"type", "text"}}, target);
            beforeText = newText;
            auto reference = attrDocument(fresh, sheet, "input", {{"type", "range"}}, expected);
            beforeText = "before";
            if (doc->set_element_attribute(target, "type", "range")) {
                typed++;
                doc->commit_patch();
            }
            auto p = doc->root()->select_one("p");
            if (p && doc->can_replace_text(p, 0, p->children().size(), newText)) {
                texted++;
                std::vector<element::ptr> pieces;
                CHECK(doc->replace_text(p, 0, p->children().size(), newText, pieces));
                doc->commit_patch();
                doc->render(litehtml::pixel_t(160.0f));
                const bool same = dump_of(doc) == dump_of(reference) && painted(c, doc) == painted(fresh, reference) &&
                                  doc->text_elements() == reference->text_elements() && c.limits == fresh.limits;
                if (!same) std::printf("  range then text differs at %d filler words\n", words);
                CHECK(same);
            }
        }
        fillerWords = 0;
        std::printf("  range shape: %d type patches, %d text patches accepted\n", typed, texted);
        CHECK(typed == 0 && texted == 0);   // the flag is set from the start: the document has a control
    }

    // The table-cell cap: a span change that would take the cells past 200,000 is refused; below it, equal to fresh.
    {
        auto build = [](PaintContainer& c, const char* bspan, element::ptr& b) {
            auto doc = std::make_shared<litehtml::document>(&c);
            doc->set_document_mode(litehtml::no_quirks_mode);
            auto root = make(doc, "html");
            auto body = make(doc, "body");
            auto table = make(doc, "table");
            auto tr = make(doc, "tr");
            auto a = make(doc, "td", {{"colspan", "1000"}, {"rowspan", "199"}});
            text(doc, a, "a");
            b = make(doc, "td", {{"colspan", bspan}});
            text(doc, b, "b");
            auto tbody = make(doc, "tbody");
            add(doc, tr, a);
            add(doc, tr, b);
            add(doc, tbody, tr);
            add(doc, table, tbody);
            add(doc, body, table);
            add(doc, root, body);
            doc->finalize_from_external_root(root, litehtml::telegram_master_css());
            doc->render(litehtml::pixel_t(160.0f));
            return doc;
        };
        PaintContainer c;
        element::ptr b;
        auto doc = build(c, "1", b);
        CHECK(doc->table_cells() == 199001);
        CHECK(doc->can_set_element_attribute(b, "colspan", "2"));         // 199,001 + 1
        CHECK(doc->can_set_element_attribute(b, "colspan", "1000"));      // 200,000 exactly
        CHECK(doc->can_set_element_attribute(b, "rowspan", "2"));         // 199,002
        litehtml::string_map big = {{"colspan", "1000"}, {"rowspan", "2"}};
        CHECK(!doc->can_set_element_attributes(b, big));                  // 2,000 cells
        CHECK(!doc->set_element_attributes(b, big));
        // Pending cells count too.
        litehtml::document::attribute_growth pending;
        CHECK(doc->can_set_element_attributes(b, {{"colspan", "500"}}, &pending) && pending.cells == 499);
        CHECK(!doc->can_set_element_attributes(b, {{"colspan", "1000"}}, &pending));   // 499 + 999 + 199,001 > cap
        // An accepted change equals a fresh build.
        PaintContainer fresh;
        element::ptr expected;
        auto reference = build(fresh, "3", expected);
        CHECK(doc->set_element_attribute(b, "colspan", "3"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(160.0f));
        CHECK(dump_of(doc) == dump_of(reference));
        CHECK(painted(c, doc) == painted(fresh, reference));
        CHECK(c.limits == fresh.limits);
    }
}

// Telegram (VENDOR.md edit 18): litehtml's get_font answered no font for size 0 and left the metrics as they were, so an
// element restyled to font-size 0 kept its old line height where a fresh one has none.
static void testFontSizeZeroMatchesFresh() {
    attributePatchedMatchesFresh("", "div", {}, "style", "font-size:0");
    attributePatchedMatchesFresh("", "div", {}, "style", "font-size:0;line-height:0");
    attributePatchedMatchesFresh("", "div", {{"style", "font-size:0"}}, "style", "font-size:4px");
    attributePatchedMatchesFresh(".z{font-size:0}", "div", {}, "class", "z");
}

static void testSetAttributeRefusals() {
    // A class in a selector's ancestor position.
    attributeRefused(".on p{color:#c00}", "div", {}, "class", "on");
    attributeRefused(".on p{color:#c00}", "div", {{"class", "on"}}, "class", nullptr);
    // An id and an attribute name in an ancestor position.
    attributeRefused("#x p{color:#c00}", "div", {}, "id", "x");
    attributeRefused("[hidden] p{color:#c00}", "div", {}, "hidden", "");
    // Sibling combinators anywhere in the sheets. (A positional pseudo-class reads an element's place, which no
    // attribute changes: VENDOR.md edit 42.)
    attributePatchedMatchesFresh("p:nth-child(2){color:#c00}", "div", {}, "class", "z");
    attributePatchedMatchesFresh("p:first-child{color:#c00}", "div", {}, "id", "z");
    attributeRefused("div + p{color:#c00}", "div", {}, "class", "z");
    // Counters.
    attributeRefused("p{counter-increment:n}", "div", {}, "class", "z");
    // An option inside a select (and the select itself, which is not restylable in place).
    {
        PaintContainer c;
        auto doc = std::make_shared<litehtml::document>(&c);
        doc->set_document_mode(litehtml::no_quirks_mode);
        auto root = make(doc, "html");
        auto body = make(doc, "body");
        auto select = make(doc, "select");
        auto one = make(doc, "option");
        text(doc, one, "one");
        auto two = make(doc, "option");
        text(doc, two, "two");
        add(doc, select, one);
        add(doc, select, two);
        add(doc, body, select);
        add(doc, root, body);
        doc->finalize_from_external_root(root, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(160.0f));
        const std::string before = dump_of(doc);
        CHECK(!doc->can_set_element_attribute(two, "selected", ""));
        CHECK(!doc->set_element_attribute(two, "selected", ""));
        CHECK(!doc->set_element_attribute(select, "class", "x"));
        CHECK(!doc->set_element_attribute(select, "disabled", ""));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(160.0f));
        CHECK(dump_of(doc) == before);
    }
    // An inline style touching a custom property, var() or a counter, going in or out.
    attributeRefused("", "div", {}, "style", "--x:1");
    attributeRefused("", "div", {}, "style", "color:var(--x)");
    attributeRefused("", "div", {}, "style", "counter-reset:n");
    attributeRefused("", "div", {{"style", "--x:1"}}, "style", "color:red");
    attributeRefused("", "div", {{"style", "--x:1"}}, "style", nullptr);
    // An element no one patches in place: a table, a textarea, a button; and one that is not in the document.
    attributeRefused("", "table", {}, "class", "z");
    attributeRefused("", "textarea", {}, "placeholder", "hint");
    attributeRefused("", "button", {}, "class", "z");
    {
        PaintContainer c;
        element::ptr target;
        auto doc = attrDocument(c, "", "div", {}, target);
        auto loose = make(doc, "div");
        CHECK(!doc->can_set_element_attribute(loose, "class", "a"));
        CHECK(!doc->set_element_attribute(loose, "class", "a"));
        CHECK(!doc->set_element_attribute(nullptr, "class", "a"));
        CHECK(!doc->set_element_attribute(target, nullptr, "a"));
        CHECK(!doc->set_element_attribute(target, "", "a"));
    }
}

static void testBuildCapsMatchCreateNode() {
    {
        LimitContainer c;
        auto doc = std::make_shared<litehtml::document>(&c);
        CHECK(doc->external_element_allowed(255));
        CHECK(!c.limits.empty() == false);
        CHECK(!doc->external_element_allowed(256));
        CHECK(c.limits.size() == 1 && c.limits[0] == "depth");
    }
    {
        LimitContainer c;
        auto doc = std::make_shared<litehtml::document>(&c);
        bool all = true;
        for (int n = 0; n < 20000; n++) all = doc->external_element_allowed(1) && all;
        CHECK(all);
        CHECK(c.limits.empty());
        CHECK(!doc->external_element_allowed(1));
        CHECK(c.limits.size() == 1 && c.limits[0] == "elements");
    }
    // Hostile shapes: the same element counts as the parse.
    auto build = [](LimitContainer& c, const std::function<void(const litehtml::document::ptr&, const element::ptr&, int&)>& fill) {
        auto doc = std::make_shared<litehtml::document>(&c);
        doc->set_document_mode(litehtml::no_quirks_mode);
        int n = 0;
        auto root = make(doc, "html");
        doc->external_element_allowed(0);
        auto head = make(doc, "head");
        doc->external_element_allowed(1);
        add(doc, root, head);
        auto body = make(doc, "body");
        doc->external_element_allowed(1);
        add(doc, root, body);
        fill(doc, body, n);
        doc->finalize_from_external_root(root, litehtml::telegram_master_css());
        return doc;
    };
    {
        LimitContainer ext, par;
        auto doc = build(ext, [](const litehtml::document::ptr& d, const element::ptr& body, int&) {
            element::ptr parent = body;
            for (int depth = 2; depth < 302; depth++) {
                if (!d->external_element_allowed(depth)) break;
                auto el = make(d, "div");
                add(d, parent, el);
                parent = el;
            }
        });
        std::string markup = "<html><head></head><body>";
        for (int n = 0; n < 300; n++) markup += "<div>";
        auto reference = litehtml::document::createFromString(litehtml::estring(markup), &par, litehtml::telegram_master_css());
        CHECK(count_elements(doc->root()) == count_elements(reference->root()));
        CHECK(!ext.limits.empty() && ext.limits[0] == "depth");
        CHECK(!par.limits.empty() && par.limits[0] == "depth");
    }
    {
        LimitContainer ext, par;
        auto doc = build(ext, [](const litehtml::document::ptr& d, const element::ptr& body, int&) {
            for (int n = 0; n < 20001; n++) {
                if (!d->external_element_allowed(2)) continue;
                add(d, body, make(d, "span"));
            }
        });
        std::string markup = "<html><head></head><body>";
        for (int n = 0; n < 20001; n++) markup += "<span></span>";
        auto reference = litehtml::document::createFromString(litehtml::estring(markup), &par, litehtml::telegram_master_css());
        CHECK(count_elements(doc->root()) == count_elements(reference->root()));
        CHECK(count_elements(doc->root()) == 20000);
        CHECK(!ext.limits.empty() && ext.limits[0] == "elements");
        CHECK(!par.limits.empty() && par.limits[0] == "elements");
    }
}

static void testMasterCssIsTwidgets() {
    const std::string& css = litehtml::telegram_master_css();
    CHECK(css.find("a:link { cursor: pointer; }") != std::string::npos);
    CHECK(css.find("[hidden], template, datalist { display: none; }") != std::string::npos);
    const std::string base = litehtml::master_css;
    const size_t link = base.find("a:link");
    CHECK(link != std::string::npos);
    CHECK(css.compare(0, link, base, 0, link) == 0);
}

// Telegram (VENDOR.md edit 18): structure patched in place. A document is described by specs, so the patched one can be
// compared with one built afresh from the final description.
struct Spec {
    std::string tag;               // empty: a text
    litehtml::string_map attrs;
    std::string text;              // a text's data, or an element's single text child when not empty
    std::vector<Spec> kids;
};

static Spec el(const char* tag, const char* t = "", litehtml::string_map attrs = {}, std::vector<Spec> kids = {}) {
    return Spec{tag, std::move(attrs), t, std::move(kids)};
}

static Spec txt(const char* t) {
    return Spec{"", {}, t, {}};
}

// A detached element subtree for `spec` (an element spec), built as WidgetRuntime builds one: its text through
// make_text_pieces, which asks the cap nothing (can_insert_subtree counts the pieces).
static void pieces(const litehtml::document::ptr& doc, const element::ptr& parent, const std::string& t) {
    std::vector<element::ptr> made;
    doc->make_text_pieces(parent, t.c_str(), made);
    for (const auto& piece : made) add(doc, parent, piece);
}

static element::ptr build(const litehtml::document::ptr& doc, const Spec& spec) {
    auto e = make(doc, spec.tag.c_str(), spec.attrs);
    if (!spec.text.empty()) pieces(doc, e, spec.text);
    for (const Spec& kid : spec.kids) {
        if (kid.tag.empty()) pieces(doc, e, kid.text);
        else add(doc, e, build(doc, kid));
    }
    return e;
}

// html > [head > style(sheet)] body(style=margin:0, kids). `body` gets the body.
static litehtml::document::ptr structureDocument(PaintContainer& c, const char* sheet, const std::vector<Spec>& kids,
                                                 element::ptr& body, bool render = true) {
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = make(doc, "html");
    auto head = make(doc, "head");
    if (*sheet) {
        auto style = make(doc, "style");
        text(doc, style, sheet);
        add(doc, head, style);
    }
    add(doc, root, head);
    body = make(doc, "body", {{"style", "margin:0"}});
    for (const Spec& kid : kids) {
        if (kid.tag.empty()) text(doc, body, kid.text.c_str());
        else add(doc, body, build(doc, kid));
    }
    add(doc, root, body);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    if (render) doc->render(litehtml::pixel_t(200.0f));
    return doc;
}

// Commits and lays out `doc`, then compares it with a document built afresh from `kids`: placements, height, everything
// painted, the text-piece count and the limits reported.
static void structureMatchesFresh(PaintContainer& c, const litehtml::document::ptr& doc, const char* sheet,
                                  const std::vector<Spec>& kids, const char* what) {
    doc->commit_patch();
    doc->render(litehtml::pixel_t(200.0f));
    PaintContainer fresh;
    element::ptr body;
    auto reference = structureDocument(fresh, sheet, kids, body);
    const bool same = dump_of(doc) == dump_of(reference) && float(doc->height()) == float(reference->height()) &&
                      painted(c, doc) == painted(fresh, reference) && doc->text_elements() == reference->text_elements() &&
                      c.limits == fresh.limits;
    if (!same) std::printf("  structure differs after: %s\n%s---\n%s", what, dump_of(doc).c_str(), dump_of(reference).c_str());
    CHECK(dump_of(doc) == dump_of(reference));
    CHECK(float(doc->height()) == float(reference->height()));
    CHECK(painted(c, doc) == painted(fresh, reference));
    CHECK(doc->text_elements() == reference->text_elements());
    CHECK(c.limits == fresh.limits);
}

static element::ptr childAt(const element::ptr& parent, size_t index) {
    auto it = parent->children().begin();
    std::advance(it, index);
    return *it;
}

// VENDOR.md edit 42: a rule positional in its subject alone lets an insertion or a removal through, and the commit
// matches the parent's other element children again, so the result is a fresh document's; a parent the rule cannot reach
// (its children's tags) is left alone.
static void testSubjectPositionsMatchSiblingsAgain() {
    const char* sheet = "p:first-child{color:#00c} p:last-child{color:#0c0} p:nth-child(2n){background:#eee}"
                        " body>:first-child{margin-top:7px} li:first-child{color:#c00}";
    std::vector<Spec> kids = {el("p", "one"), el("p", "two"), el("div", "", {}, {el("span", "s")}), el("p", "three")};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    CHECK(doc->insert_subtree(body, 0, build(doc, el("p", "new first"))));
    kids.insert(kids.begin(), el("p", "new first"));
    structureMatchesFresh(c, doc, sheet, kids, "insert at 0 under positions");
    CHECK(doc->insert_subtree(body, body->children().size(), build(doc, el("p", "new last"))));
    kids.push_back(el("p", "new last"));
    structureMatchesFresh(c, doc, sheet, kids, "append under positions");
    CHECK(doc->remove_subtree(childAt(body, 0)));
    kids.erase(kids.begin());
    structureMatchesFresh(c, doc, sheet, kids, "remove the first under positions");
    // Into the div: no rule's subject is a span, and the div is no body.
    auto div = childAt(body, 2);
    CHECK(!doc->positions_reach(div));
    CHECK(doc->insert_subtree(div, 0, build(doc, el("span", "t"))));
    kids[2].kids.insert(kids[2].kids.begin(), el("span", "t"));
    structureMatchesFresh(c, doc, sheet, kids, "insert where no position reaches");
    CHECK(doc->positions_reach(body));
}

static void testInsertRemoveMatchesFresh() {
    const char* sheet = ".a{color:#c00;background:#00f} p{margin:2px} li{color:#0a0} td{padding:3px;border:1px solid #000}"
                        " .n{font-weight:bold;background:#fc0} b{color:#090} .box p{color:#00c}";
    std::vector<Spec> kids = {
        el("p", "one", {{"class", "a"}}),
        el("div", "", {}, {txt("two "), el("b", "bold")}),
        el("p", "three"),
        el("ul", "", {}, {el("li", "x"), el("li", "y")}),
        el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "c1")})})}),
        el("div", "", {{"class", "box"}}),
    };
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    // Append.
    CHECK(doc->insert_subtree(body, body->children().size(), build(doc, el("p", "appended", {{"class", "n"}}))));
    kids.push_back(el("p", "appended", {{"class", "n"}}));
    structureMatchesFresh(c, doc, sheet, kids, "append");
    // insertBefore at 0.
    CHECK(doc->insert_subtree(body, 0, build(doc, el("div", "first", {{"class", "a"}}))));
    kids.insert(kids.begin(), el("div", "first", {{"class", "a"}}));
    structureMatchesFresh(c, doc, sheet, kids, "insert at 0");
    // Remove the middle child (p "three", now at index 3).
    CHECK(doc->remove_subtree(childAt(body, 3)));
    kids.erase(kids.begin() + 3);
    structureMatchesFresh(c, doc, sheet, kids, "remove the middle child");
    // A move: the <b> out of the div into the .box, where `.box p` does not reach it, and a p into the .box, where it
    // does; one session.
    auto div = childAt(body, 2);
    CHECK(doc->remove_subtree(childAt(div, 2)));   // div: [two, space, b]... the b is after "two" and its space
    kids[2].kids.pop_back();
    auto box = childAt(body, 5);
    CHECK(doc->insert_subtree(box, 0, build(doc, el("b", "bold"))));
    CHECK(doc->remove_subtree(childAt(body, 0)));
    CHECK(doc->insert_subtree(box, 1, build(doc, el("div", "first", {{"class", "a"}}))));
    CHECK(doc->insert_subtree(box, 2, build(doc, el("p", "in box"))));
    kids[5].kids = {el("b", "bold"), el("div", "first", {{"class", "a"}}), el("p", "in box")};
    kids.erase(kids.begin());
    structureMatchesFresh(c, doc, sheet, kids, "move between parents");
    // A table row, and a list item (whose list_index layout writes again).
    auto tbody = childAt(childAt(body, 3), 0);
    CHECK(doc->insert_subtree(tbody, tbody->children().size(), build(doc, el("tr", "", {}, {el("td", "c2"), el("td", "c3")}))));
    kids[3].kids[0].kids.push_back(el("tr", "", {}, {el("td", "c2"), el("td", "c3")}));
    auto ul = childAt(body, 2);
    CHECK(doc->insert_subtree(ul, 0, build(doc, el("li", "w"))));
    kids[2].kids.insert(kids[2].kids.begin(), el("li", "w"));
    structureMatchesFresh(c, doc, sheet, kids, "table row and list item");
    // A text inserted directly, as pieces, and a text removed.
    std::vector<element::ptr> pieces;
    auto first = childAt(body, 1);   // the div holding "two "
    doc->make_text_pieces(first, " more words", pieces);
    CHECK(pieces.size() == 4);
    for (size_t i = 0; i < pieces.size(); i++) CHECK(pieces[i]->parent() == nullptr && doc->insert_subtree(first, first->children().size(), pieces[i]));
    kids[1].kids.push_back(txt(" more words"));
    structureMatchesFresh(c, doc, sheet, kids, "text pieces inserted");
    CHECK(doc->remove_subtree(childAt(first, 0)));   // "two"
    CHECK(doc->remove_subtree(childAt(first, 0)));   // " "
    kids[1].kids.erase(kids[1].kids.begin());
    structureMatchesFresh(c, doc, sheet, kids, "text pieces removed");
}

// Every refusal answers false, changes nothing (the dump and the piece count) and reports no limit.
static void structureRefused(const char* what, const litehtml::document::ptr& doc, PaintContainer& c, const std::function<bool()>& ask,
                             const std::function<bool()>& apply) {
    const std::string before = dump_of(doc);
    const int pieces = doc->text_elements();
    const bool asked = ask(), applied = apply();
    if (asked || applied) std::printf("  accepted: %s\n", what);
    CHECK(!asked);
    CHECK(!applied);
    CHECK(dump_of(doc) == before);
    CHECK(doc->text_elements() == pieces);
    CHECK(c.limits.empty());
}

static void testStructureRefusals() {
    const std::vector<Spec> kids = {el("p", "one"), el("select", "", {}, {el("option", "o")}), el("div", "two"),
                                    el("svg", "", {{"width", "20"}, {"height", "20"}}), el("button", "b")};
    const std::vector<Spec> plain = {el("p", "one"), el("div", "two")};
    // `path` picks the parent from the body down (empty: the body).
    auto refuseInsert = [&](const char* what, const char* sheet, std::vector<size_t> path, const Spec& spec,
                            const std::vector<Spec>* children = nullptr) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, children ? *children : kids, body);
        auto parent = body;
        for (size_t index : path) parent = childAt(parent, index);
        auto sub = build(doc, spec);
        const int before = doc->text_elements();   // the subtree's pieces are alive
        structureRefused(what, doc, c, [&] { return doc->can_insert_subtree(parent, 0, sub); },
                         [&] { return doc->insert_subtree(parent, 0, sub); });
        CHECK(sub->parent() == nullptr);
        CHECK(doc->text_elements() == before);
    };
    auto refuseRemove = [&](const char* what, const char* sheet, size_t index, const std::vector<Spec>* children = nullptr) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, children ? *children : kids, body);
        auto victim = childAt(body, index);
        structureRefused(what, doc, c, [&] { return doc->can_remove_subtree(victim); }, [&] { return doc->remove_subtree(victim); });
        CHECK(victim->parent() == body);
    };
    // Document-level elements, inserted or removed.
    refuseInsert("a <style>", "", {}, el("style", "p{color:red}"));
    refuseInsert("a div holding a <style>", "", {}, el("div", "", {}, {el("style", "p{color:red}")}));
    refuseInsert("a div holding a <select>", "", {}, el("div", "", {}, {el("select")}));
    refuseInsert("a <body>", "", {}, el("body", "x"));
    refuseRemove("the <select>", "", 1);
    // Inside <select>, a form control, an svg.
    refuseInsert("an <option> into the <select>", "", {1}, el("option", "p"));
    refuseInsert("a span into the <option>", "", {1, 0}, el("span", "p"));
    refuseInsert("a circle into the svg", "", {3}, el("circle", "", {{"r", "5"}}));
    refuseInsert("a span into the <button>", "", {4}, el("span", "s"));
    // What the parent's own appendChild refuses: a <table> takes tbody, thead, tfoot and caption only.
    const std::vector<Spec> table = {el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "c")})})})};
    refuseInsert("a tr into the table", "", {0}, el("tr", "", {}, {el("td", "d")}), &table);
    // Counters; sibling combinators and positional pseudo-classes outside a rule's subject (replace_children is the
    // change for those; one in the subject alone matches the siblings again: testSubjectPositionsMatchSiblingsAgain).
    refuseInsert("with counter-increment", "p{counter-increment:x}", {}, el("p", "x"));
    refuseRemove("with counter-increment", "div{counter-increment:x}", 2);
    refuseInsert("with :nth-child outside the subject", "p:nth-child(2n) b{color:red}", {}, el("p", "x"));
    refuseInsert("with +", "p + div{color:red}", {}, el("p", "x"));
    refuseRemove("with ~", "p ~ div{color:red}", 2);
    // Pseudo-element content: already possible, or brought by the subtree (a tag a rule names; a control with lh-* rules).
    refuseInsert("with p::before content", "p::before{content:'x'}", {}, el("div", "x"), &plain);
    refuseRemove("with p::before content", "p::before{content:'x'}", 1, &plain);
    refuseInsert("a <q> with q::before content", "q::before{content:'x'}", {}, el("div", "", {}, {el("q", "x")}), &plain);
    refuseInsert("an input with an lh-* part rule", "lh-range-thumb::after{content:'x'}", {}, el("input", "", {{"type", "range"}}),
                 &plain);
    // The same sheets let what they do not reach through.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", table, body);
        CHECK(doc->can_insert_subtree(childAt(body, 0), 1, build(doc, el("tbody", "", {}, {el("tr", "", {}, {el("td", "d")})}))));
        CHECK(doc->can_insert_subtree(childAt(body, 0), 0, build(doc, el("caption", "c"))));
    }
    for (const char* sheet : {"q::before{content:'x'}", "lh-range-thumb::after{content:'x'}", "p::before{color:red}"}) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, plain, body);
        auto sub = build(doc, el("div", "", {}, {el("p", "x"), el("span", "y")}));
        CHECK(doc->can_insert_subtree(body, 1, sub));
        CHECK(doc->can_remove_subtree(childAt(body, 1)));
    }
    // The parent, the subtree and the index.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", kids, body);
        auto attached = childAt(body, 0);
        structureRefused("an attached subtree", doc, c, [&] { return doc->can_insert_subtree(body, 0, attached); },
                         [&] { return doc->insert_subtree(body, 0, attached); });
        auto detached = build(doc, el("div"));
        auto sub = build(doc, el("p", "x"));
        structureRefused("a detached parent", doc, c, [&] { return doc->can_insert_subtree(detached, 0, sub); },
                         [&] { return doc->insert_subtree(detached, 0, sub); });
        structureRefused("an index past the end", doc, c, [&] { return doc->can_insert_subtree(body, 99, sub); },
                         [&] { return doc->insert_subtree(body, 99, sub); });
        PaintContainer cs;
        element::ptr bodys;
        auto styled = structureDocument(cs, "p{color:#000}", kids, bodys);
        auto style = childAt(childAt(styled->root(), 0), 0);
        CHECK(style->tag() == litehtml::_style_);
        std::vector<element::ptr> sheetText;
        styled->make_text_pieces(style, "div{color:red}", sheetText);
        CHECK(sheetText.size() == 1);
        structureRefused("a <style>'s text", styled, cs, [&] { return styled->can_insert_subtree(style, 1, sheetText[0]); },
                         [&] { return styled->insert_subtree(style, 1, sheetText[0]); });
        structureRefused("the root", doc, c, [&] { return doc->can_remove_subtree(doc->root()); },
                         [&] { return doc->remove_subtree(doc->root()); });
        structureRefused("a detached element", doc, c, [&] { return doc->can_remove_subtree(sub); },
                         [&] { return doc->remove_subtree(sub); });
        // A form control's generated part.
        PaintContainer ci;
        element::ptr bodyi;
        auto withInput = structureDocument(ci, "", {el("input", "", {{"type", "range"}})}, bodyi);
        auto input = childAt(bodyi, 0);
        CHECK(!input->children().empty());
        structureRefused("an lh-* part", withInput, ci, [&] { return withInput->can_remove_subtree(childAt(input, 0)); },
                         [&] { return withInput->remove_subtree(childAt(input, 0)); });
    }
}

// The caps: depth, elements, text pieces and table cells. What is accepted equals a fresh build, limits included.
static void testStructureCaps() {
    // Depth: body > 250 nested divs; an element at depth 256 is refused.
    {
        PaintContainer c;
        element::ptr body;
        Spec chain = el("div", "deep");
        for (int n = 0; n < 249; n++) chain = el("div", "", {}, {chain});
        std::vector<Spec> kids = {chain};
        auto doc = structureDocument(c, "", kids, body);
        element::ptr deepest = body;   // depth 1
        while (!deepest->children().empty() && deepest->children().front()->tag() == litehtml::_div_) deepest = deepest->children().front();
        int depth = 0;
        for (auto p = deepest->parent(); p; p = p->parent()) depth++;
        CHECK(depth == 251);
        // Children of `deepest` are at depth 252: a subtree four levels deep reaches 255, five reaches 256.
        Spec four = el("i", "", {}, {el("i", "", {}, {el("i", "", {}, {el("i", "x")})})});
        Spec five = el("i", "", {}, {four});
        auto sub = build(doc, five);
        structureRefused("depth 256", doc, c, [&] { return doc->can_insert_subtree(deepest, 0, sub); },
                         [&] { return doc->insert_subtree(deepest, 0, sub); });
        CHECK(doc->insert_subtree(deepest, 0, build(doc, four)));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(c.limits.empty());
    }
    // Elements: 19,995 counted by external_element_allowed, then insertions of 6 and 5 elements.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", {}, body, false);
        for (int n = 0; n < 19995; n++) CHECK(doc->external_element_allowed(2));
        auto six = build(doc, el("div", "", {}, {el("i"), el("i"), el("i"), el("i"), el("i")}));
        structureRefused("past max_build_elements", doc, c, [&] { return doc->can_insert_subtree(body, 0, six); },
                         [&] { return doc->insert_subtree(body, 0, six); });
        litehtml::document::structure_growth growth;
        CHECK(doc->can_remove_subtree(childAt(doc->root(), 0), nullptr) == false);   // head: a document-level element
        auto five = build(doc, el("div", "", {}, {el("i"), el("i"), el("i"), el("i")}));
        CHECK(doc->can_insert_subtree(body, 0, five, &growth));
        CHECK(growth.elements == 5);
        CHECK(!doc->can_insert_subtree(body, 0, five, &growth));   // twice is past the cap
        CHECK(doc->insert_subtree(body, 0, five));
        CHECK(!doc->can_insert_subtree(body, 0, build(doc, el("i"))));
        CHECK(doc->remove_subtree(five));
        CHECK(doc->can_insert_subtree(body, 0, build(doc, el("i"))));
        doc->commit_patch();
    }
    // Text pieces: 9,990 in a paragraph, a 4-piece one beside it; then 13 pieces more.
    {
        std::string words;
        for (int n = 0; n < 4995; n++) words += n ? " w" : "w";   // 9,989 pieces
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = {el("p", words.c_str()), el("p", "a b")};
        auto doc = structureDocument(c, "", kids, body);
        const int base = doc->text_elements();
        CHECK(base == 9989 + 3);
        auto big = build(doc, el("p", "1 2 3 4 5 6 7"));   // 13 pieces: 10,005 alive
        structureRefused("past the text cap", doc, c, [&] { return doc->can_insert_subtree(body, 2, big); },
                         [&] { return doc->insert_subtree(body, 2, big); });
        litehtml::document::structure_growth growth;
        CHECK(doc->can_remove_subtree(childAt(body, 1), &growth));
        CHECK(growth.released == 3);
        CHECK(!doc->can_insert_subtree(body, 2, big, nullptr));
        CHECK(!doc->can_insert_subtree(body, 2, big, &growth));   // 10,005 alive, 3 to be released: 10,002 > 10,000
        CHECK(growth.released == 3);
        big.reset();
        auto fits = build(doc, el("p", "1 2 3 4 5"));   // 9 pieces: 9,992 + 9 - 3 = 9,998
        CHECK(doc->remove_subtree(childAt(body, 1)));
        CHECK(doc->insert_subtree(body, 1, fits));
        kids[1] = el("p", "1 2 3 4 5");
        structureMatchesFresh(c, doc, "", kids, "near the text cap");
    }
    // Table cells: one td of 1000 x 199 cells is 199,000; 1000 x 200 passes the cap with the table's own cell.
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = {el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "c")})})})};
        auto doc = structureDocument(c, "", kids, body);
        CHECK(doc->table_cells() == 1);
        auto tr = childAt(childAt(childAt(body, 0), 0), 0);
        auto wide = build(doc, el("td", "w", {{"colspan", "1000"}, {"rowspan", "200"}}));
        structureRefused("past max_table_cells", doc, c, [&] { return doc->can_insert_subtree(tr, 1, wide); },
                         [&] { return doc->insert_subtree(tr, 1, wide); });
        wide.reset();   // the piece count compares what the documents hold
        CHECK(doc->insert_subtree(tr, 1, build(doc, el("td", "w", {{"colspan", "1000"}, {"rowspan", "199"}}))));
        kids[0].kids[0].kids[0].kids.push_back(el("td", "w", {{"colspan", "1000"}, {"rowspan", "199"}}));
        structureMatchesFresh(c, doc, "", kids, "near the cell cap");
        CHECK(doc->table_cells() == 199001);
    }
}

// Under sibling combinators and positional pseudo-classes, insert_subtree and remove_subtree refuse and replace_children
// matches every child afresh; it keeps the generated content where it is.
static void testReplaceChildrenUnderPositionalSelectors() {
    const char* sheet = "li:nth-child(2n){color:#f00;background:#eee} li + li{margin-top:3px} .x ~ li{font-weight:bold}"
                        " li:last-child{background:#0f0} li:first-child span{color:#00f}";
    std::vector<Spec> kids = {el("ul", "", {}, {el("li", "", {}, {el("span", "a")}), el("li", "b", {{"class", "x"}}), el("li", "c")})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    CHECK(doc->structure_reaches_siblings());
    auto ul = childAt(body, 0);
    CHECK(!doc->can_insert_subtree(ul, 0, build(doc, el("li", "n"))));
    CHECK(!doc->can_remove_subtree(childAt(ul, 0)));
    std::vector<Spec> next = {el("li", "n"), el("li", "", {}, {el("span", "a")}), el("li", "b", {{"class", "x"}}), el("li", "c"),
                              el("li", "", {}, {el("span", "d")})};
    std::vector<element::ptr> built;
    for (const Spec& spec : next) built.push_back(build(doc, spec));
    litehtml::document::structure_growth growth;
    CHECK(doc->can_replace_children(ul, built, &growth));
    CHECK(growth.elements == 7 - 4);
    CHECK(doc->replace_children(ul, built));
    built.clear();   // the piece count compares what the documents hold
    kids[0].kids = next;
    structureMatchesFresh(c, doc, sheet, kids, "replace_children under positional selectors");
    // Down to one item, then none.
    CHECK(doc->replace_children(ul, {build(doc, el("li", "only"))}));
    kids[0].kids = {el("li", "only")};
    structureMatchesFresh(c, doc, sheet, kids, "one item left");
    CHECK(doc->replace_children(ul, {}));
    kids[0].kids = {};
    structureMatchesFresh(c, doc, sheet, kids, "no item left");
    // Counters still refuse it.
    PaintContainer cc;
    element::ptr body2;
    auto counted = structureDocument(cc, "li{counter-increment:n}", {el("ul", "", {}, {el("li", "a")})}, body2);
    structureRefused("replace_children with counters", counted, cc,
                     [&] { return counted->can_replace_children(childAt(body2, 0), {build(counted, el("li", "b"))}); },
                     [&] { return counted->replace_children(childAt(body2, 0), {build(counted, el("li", "b"))}); });
}

// Telegram (VENDOR.md edit 18): one selector-step budget per session. A document of `divs` divs under a sheet of `rules`
// `div` rules, the last of which colours them, built inside a session; `used` gets the steps the build took.
static litehtml::document::ptr stepDocument(PaintContainer& c, int rules, int divs, element::ptr& body, int64_t& used,
                                            int64_t limit = litehtml::document::default_selector_steps) {
    std::string sheet;
    for (int i = 0; i < rules - 1; i++) sheet += "div{margin-left:0}";
    sheet += "div{color:#ff0000}";
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = make(doc, "html");
    auto head = make(doc, "head");
    auto style = make(doc, "style");
    text(doc, style, sheet.c_str());
    add(doc, head, style);
    add(doc, root, head);
    body = make(doc, "body");
    for (int i = 0; i < divs; i++) add(doc, body, build(doc, el("div", "x")));
    add(doc, root, body);
    doc->begin_selector_steps(limit);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    used = doc->end_selector_steps();
    doc->render(litehtml::pixel_t(300.0f));
    return doc;
}

static int coloured(const element::ptr& parent) {
    int n = 0;
    for (const auto& child : parent->children()) n += child->css().get_color().red == 255;
    return n;
}

static void testSelectorStepsAreOneBudgetPerSession() {
    // One div's steps, measured in a session of its own.
    int64_t perDiv = 0;
    {
        PaintContainer c;
        element::ptr body;
        int64_t used = 0;
        auto doc = stepDocument(c, 1000, 0, body, used);
        auto div = build(doc, el("div", "x"));
        doc->begin_selector_steps();
        CHECK(doc->insert_subtree(body, 0, div));
        doc->commit_patch();
        perDiv = doc->end_selector_steps();
        CHECK(perDiv >= 1000);
        CHECK(div->css().get_color().red == 255);
        // The bound holds it.
        litehtml::document::selector_step_plan plan;
        plan.inserted.push_back({body, build(doc, el("div", "x"))});
        CHECK(doc->selector_step_bound(plan) >= perDiv);
    }
    // Two roots and three sheets share one session: a limit of a div and a half colours the first and not the second.
    // (Without the edit each outermost pass had 4,000,000 steps of its own, and both were coloured.)
    {
        PaintContainer c;
        element::ptr body;
        int64_t used = 0;
        auto doc = stepDocument(c, 1000, 0, body, used);
        auto first = build(doc, el("div", "x")), second = build(doc, el("div", "y"));
        doc->begin_selector_steps(perDiv + perDiv / 2);
        CHECK(doc->insert_subtree(body, 0, first));
        CHECK(doc->insert_subtree(body, 1, second));
        doc->commit_patch();
        const int64_t shared = doc->end_selector_steps();
        CHECK(shared > perDiv + perDiv / 2);   // cut
        CHECK(first->css().get_color().red == 255);
        CHECK(second->css().get_color().red != 255);
    }
    // The reviewer's parity probe: 1,000 rules, 4,099 divs. A fresh build in a session passes 4,000,000 steps and leaves
    // the last divs uncoloured; a patch that matched in a session of its own would colour an appended div. With the
    // build's steps recorded, the bound of the append says it does not fit (a caller rebuilds), and a session limited to
    // what is left colours nothing, as the fresh build of the final document does not colour its last div.
    {
        PaintContainer c;
        element::ptr body;
        int64_t used = 0;
        auto doc = stepDocument(c, 1000, 4099, body, used);
        CHECK(used > litehtml::document::default_selector_steps);
        const int built = coloured(body);
        CHECK(built < 4099 && built > 3900);
        auto div = build(doc, el("div", "last"));
        litehtml::document::selector_step_plan plan;
        plan.inserted.push_back({body, div});
        CHECK(used + doc->selector_step_bound(plan) >= litehtml::document::default_selector_steps);
        doc->begin_selector_steps(std::max<int64_t>(0, litehtml::document::default_selector_steps - used));
        CHECK(doc->insert_subtree(body, body->children().size(), div));
        doc->commit_patch();
        doc->end_selector_steps();
        PaintContainer cf;
        element::ptr bodyf;
        int64_t usedf = 0;
        stepDocument(cf, 1000, 4100, bodyf, usedf);
        CHECK(coloured(bodyf) == built);
        CHECK(bodyf->children().back()->css().get_color().red != 255);
        CHECK(div->css().get_color().red != 255);
        // A patch session the caller opened no budget for opens its own (4,000,000): the appended div is coloured. That a
        // patch agrees with a build near the cap is the caller's: the bound above says it does not fit, and it rebuilds.
        auto again = build(doc, el("div", "own session"));
        CHECK(doc->insert_subtree(body, body->children().size(), again));
        doc->commit_patch();
        CHECK(again->css().get_color().red == 255);
    }
    // The reviewer's work probe: 300 roots in one patch session under a 16,000-selector rule share its 4,000,000 steps
    // (250 roots' worth), where each outermost pass had 4,000,000 of its own before the edit (and all 300 were coloured,
    // at 300 times the work).
    {
        std::string sheet;
        for (int i = 0; i < 15999; i++) sheet += "div,";
        sheet += "div{color:#ff0000}";
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet.c_str(), {}, body);
        std::vector<element::ptr> roots;
        for (int i = 0; i < 300; i++) {
            roots.push_back(build(doc, el("div", "x")));
            CHECK(doc->insert_subtree(body, body->children().size(), roots.back()));
        }
        doc->commit_patch();
        const int red = coloured(body);
        if (red > 251) std::printf("  %d of 300 roots coloured in one patch session\n", red);
        CHECK(red >= 249 && red <= 251);
        CHECK(doc->selector_steps_used() == 0);   // the session closed with the commit
    }
    // A session counts only its own document's matching: another document parsed on the thread while it is open (it
    // opens none of its own) counts into it nothing, and still matches with litehtml's own budget.
    {
        PaintContainer ca;
        element::ptr bodyA;
        int64_t used = 0;
        auto a = stepDocument(ca, 10, 0, bodyA, used);
        a->begin_selector_steps(1000000);
        litehtml_test::TestContainer legacy;
        auto parsed = litehtml::document::createFromString(litehtml::estring("<style>p{color:red}</style><p>a</p><p>b</p>"), &legacy,
                                                           litehtml::telegram_master_css());
        CHECK(parsed->root()->select_one("p")->css().get_color().red == 255);
        CHECK(a->selector_steps_used() == 0);
        CHECK(a->end_selector_steps() == 0);
    }
}

// The bound is an upper bound: for selector shapes that walk ancestors, siblings and selector lists, the steps a patch
// uses (inserting subtrees, re-matching an element) never pass it.
static void testSelectorStepBoundHolds() {
    const char* sheets[] = {
        "div p span{color:red} div span{color:blue} p > span{margin:1px}",
        "li + li{color:red} li ~ li{margin:1px} .x ~ li span{color:blue}",
        ":is(div, p) :not(.x) span{color:red} li:nth-child(2n of .x){color:blue} :where(ul li) b{margin:1px}",
        "a b c d e{color:red} a > b c > d e{color:blue} * *{margin:0} .x .y .z{padding:1px}",
        "input{color:red} lh-input-text{color:blue} *{margin:0}",
    };
    int checked = 0;
    for (const char* sheet : sheets) {
        PaintContainer c;
        element::ptr body;
        Spec deep = el("div", "", {{"class", "x"}}, {el("p", "", {}, {el("span", "s")})});
        for (int n = 0; n < 40; n++) deep = el(n % 2 ? "div" : "p", "", {{"class", n % 3 ? "y" : "x"}}, {deep});
        std::vector<Spec> kids = {deep, el("ul", "", {}, {el("li", "a", {{"class", "x"}}), el("li", "b"), el("li", "c", {{"class", "x"}})}),
                                  el("a", "", {}, {el("b", "", {}, {el("c", "", {}, {el("d", "", {}, {el("e", "e")})})})})};
        auto doc = structureDocument(c, sheet, kids, body);
        element::ptr deepest = body;
        while (!deepest->children().empty() && std::dynamic_pointer_cast<litehtml::html_tag>(deepest->children().front()))
            deepest = deepest->children().front();
        const std::vector<Spec> inserts = {
            el("span", "", {{"class", "z"}}, {el("span", "t")}),
            el("li", "", {{"class", "x"}}, {el("span", "u"), el("b", "v")}),
            el("div", "", {{"class", "x y"}}, {el("p", "", {}, {el("span", "w")}), el("input", "", {{"type", "range"}})}),
            el("e", "", {}, {el("e", "e")}),
        };
        for (const element::ptr& parent : {body, deepest, childAt(body, 1), childAt(childAt(childAt(childAt(body, 2), 0), 0), 0)}) {
            for (const Spec& spec : inserts) {
                auto sub = build(doc, spec);
                litehtml::document::selector_step_plan plan;
                plan.inserted.push_back({parent, sub});
                const int64_t bound = doc->selector_step_bound(plan);
                if (!doc->can_insert_subtree(parent, 0, sub)) continue;
                doc->begin_selector_steps(int64_t(1) << 60);
                CHECK(doc->insert_subtree(parent, 0, sub));
                doc->commit_patch();
                const int64_t used = doc->end_selector_steps();
                if (used > bound) std::printf("  bound %lld < used %lld: %s\n", (long long)bound, (long long)used, sheet);
                CHECK(used <= bound);
                checked++;
            }
        }
        // A re-match (set_element_attributes) of the list's first item, with a class going away and one coming.
        // (The shapes above keep their ancestors' sibling lists short; the many-sibling case follows the loop.)
        auto li = childAt(childAt(body, 1), 0);
        litehtml::string_map attrs = {{"class", "y"}};
        litehtml::document::selector_step_plan plan;
        plan.rematched.push_back({li, &attrs});
        const int64_t bound = doc->selector_step_bound(plan);
        if (doc->can_set_element_attributes(li, attrs)) {
            doc->begin_selector_steps(int64_t(1) << 60);
            CHECK(doc->set_element_attributes(li, attrs));
            doc->commit_patch();
            const int64_t used = doc->end_selector_steps();
            CHECK(used <= bound);
            checked++;
        }
    }
    // The reviewer's shape (fix round 2): a compound left of a combinator, tested at an ancestor, walks that ancestor's
    // siblings: `.a ~ p span` for spans under the last of 900 <p>s walks the body's children for each. The bound sees every
    // ancestor's parent's children, not only the insertion parent's.
    for (const char* sheet : {".a ~ p span{color:red}", "p:nth-child(2n of .a) span{color:red}", ".a ~ p > span b{color:red}"}) {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids;
        // No sibling matches `.a`, so each walk goes through all of them.
        for (int n = 0; n < 900; n++) kids.push_back(el("p", "x"));
        kids.push_back(el("p"));
        auto doc = structureDocument(c, sheet, kids, body);
        auto last = childAt(body, body->children().size() - 1);
        std::vector<element::ptr> spans;
        litehtml::document::selector_step_plan plan;
        for (int n = 0; n < 20; n++) {
            spans.push_back(build(doc, el("span", "", {}, {el("b", "s")})));
            plan.inserted.push_back({last, spans.back()});
        }
        const int64_t bound = doc->selector_step_bound(plan);
        doc->begin_selector_steps(int64_t(1) << 60);
        CHECK(doc->replace_children(last, spans));
        doc->commit_patch();
        const int64_t used = doc->end_selector_steps();
        if (used > bound) std::printf("  bound %lld < used %lld: %s\n", (long long)bound, (long long)used, sheet);
        CHECK(used <= bound);
        CHECK(used >= 20 * 900);
        checked++;
    }
    CHECK(checked >= 43);
}

// Telegram (VENDOR.md edit 18): a table's rows are placed once per layout. render_item_table shifted each row down by
// its top captions with +=, and nothing else places a row, so every layout of a kept render tree (a text or attribute
// patch's) moved the cells' placements down again.
static void testTableRowsArePlacedOncePerLayout() {
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", {el("table", "", {}, {el("caption", "cap"), el("tbody", "", {}, {el("tr", "", {}, {el("td", "a")})})}),
                                         el("p", "p")}, body);
    const std::string once = dump_of(doc);
    for (int n = 0; n < 3; n++) {
        doc->invalidate_layout_cache();
        doc->render(litehtml::pixel_t(200.0f));
    }
    if (dump_of(doc) != once) std::printf("  table rows moved:\n%s---\n%s", once.c_str(), dump_of(doc).c_str());
    CHECK(dump_of(doc) == once);
}

// Telegram (VENDOR.md edit 18), Ruling E22: the filter loop's bound. A ::before/::after rule creates pseudo-elements for
// the tag it names, or for every tag (`*` with more than the pseudo-element), unless its content is none, and they are
// matched against every rule too; a form control's lh-* parts count with it (with their pseudo-elements when a rule can
// make those); and generated elements are their owner's weight, so a matched tree has the bound it had before matching.
static void testMatchingBoundCountsPseudoElementsAndParts() {
    struct Case {
        const char* sheet;
        size_t div, p, input;
    };
    const Case cases[] = {
        {"", 1, 1, 4},
        {"div::before{color:red}", 3, 1, 4},
        {"div::before{content:none} p::after{content:none}", 1, 1, 4},
        {"*::before{color:red}", 1, 1, 4},
        {".x::after{color:red}", 3, 3, 12},
        {"lh-input-text::before{color:red}", 1, 1, 10},
    };
    for (const Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        const std::vector<Spec> kids = {el("div", "d", {{"class", "x"}}), el("p", "p"), el("input", "", {{"value", "v"}}),
                                        el("input", "", {{"type", "number"}})};
        auto doc = structureDocument(c, k.sheet, kids, body);
        const auto creators = doc->pseudo_element_creators();
        CHECK(litehtml::document::matching_weight(*childAt(body, 0), creators) == k.div);
        CHECK(litehtml::document::matching_weight(*childAt(body, 1), creators) == k.p);
        CHECK(litehtml::document::matching_weight(*childAt(body, 2), creators) == k.input);
        // The matched inputs hold their parts (a number input two), and the matched div its ::after where `.x` made one.
        CHECK(!childAt(body, 2)->children().empty());
        CHECK(childAt(body, 3)->children().size() == 2);
        // Matched or not, the same bound.
        for (size_t i = 0; i < kids.size(); i++) {
            const size_t fresh = litehtml::document::matching_bound(build(doc, kids[i]), creators);
            const size_t matched = litehtml::document::matching_bound(childAt(body, i), creators);
            if (fresh != matched) std::printf("  bound %zu fresh, %zu matched: %s, child %zu\n", fresh, matched, k.sheet, i);
            CHECK(fresh == matched);
        }
    }
    // The master sheet's summary::before creates for a summary only.
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", {el("summary", "s"), el("div", "d")}, body);
    const auto creators = doc->pseudo_element_creators();
    CHECK(creators.creatable(childAt(body, 0)->tag()));
    CHECK(!creators.creatable(childAt(body, 1)->tag()));
    CHECK(!creators.every && !creators.parts);
}

// Telegram (VENDOR.md edit 20): the paint walk. Logs every container call drawing makes, and, during a walk, which visit's
// paint made it (-1: the traversal's own call).
struct WalkContainer : litehtml_test::TestContainer {
    struct Call {
        std::string what;
        int visit = -1;
    };
    std::vector<Call> log;
    int current = -1;
    void note(const char* what) { log.push_back({what, current}); }
    void draw_text(litehtml::uint_ptr, const char*, litehtml::uint_ptr, litehtml::web_color, const litehtml::position&) override { note("text"); }
    void draw_list_marker(litehtml::uint_ptr, const litehtml::list_marker&) override { note("marker"); }
    void draw_image(litehtml::uint_ptr, const litehtml::background_layer&, const std::string&, const std::string&) override { note("image"); }
    void draw_solid_fill(litehtml::uint_ptr, const litehtml::background_layer&, const litehtml::web_color&) override { note("fill"); }
    void draw_linear_gradient(litehtml::uint_ptr, const litehtml::background_layer&, const litehtml::background_layer::linear_gradient&) override { note("linear"); }
    void draw_radial_gradient(litehtml::uint_ptr, const litehtml::background_layer&, const litehtml::background_layer::radial_gradient&) override { note("radial"); }
    void draw_conic_gradient(litehtml::uint_ptr, const litehtml::background_layer&, const litehtml::background_layer::conic_gradient&) override { note("conic"); }
    void draw_borders(litehtml::uint_ptr, const litehtml::borders&, const litehtml::position&, bool) override { note("borders"); }
    void draw_box_shadow(litehtml::uint_ptr, const litehtml::position&, const litehtml::border_radiuses&, const litehtml::shadow_paint&) override { note("shadow"); }
    void draw_path(litehtml::uint_ptr, const litehtml::vector_path&) override { note("path"); }
    void draw_backdrop(litehtml::uint_ptr, const litehtml::filter_paint&) override { note("backdrop"); }
    void set_clip(const litehtml::position&, const litehtml::border_radiuses&) override { note("set-clip"); }
    void del_clip() override { note("del-clip"); }
    void suspend_clips() override { note("suspend"); }
    void resume_clips() override { note("resume"); }
    void set_clip_path(const litehtml::vector_path&) override { note("clip-path"); }
    void begin_group(litehtml::uint_ptr, const litehtml::paint_group&) override { note("group"); }
    void end_group(litehtml::uint_ptr) override { note("end-group"); }
    void draw_filtered(litehtml::uint_ptr hdc, const litehtml::filter_paint&, const std::function<void(litehtml::uint_ptr)>& paint) override {
        note("filter(");
        paint(hdc);
        note(")filter");
    }
    void draw_isolated(litehtml::uint_ptr hdc, const litehtml::position&, const std::function<void(litehtml::uint_ptr)>& paint) override {
        note("isolated(");
        paint(hdc);
        note(")isolated");
    }
    bool draw_cached(litehtml::uint_ptr, const litehtml::position&, uint64_t, const std::function<void(litehtml::uint_ptr)>&) override { return false; }
};

// Visits in order; runs each visit's paint when `paint` is set, attributing what it draws to the visit.
struct LogVisitor : litehtml::paint_visitor {
    WalkContainer& container;
    bool paint;
    std::vector<const litehtml::render_item*> visited;
    int contexts = 0, open = 0, passes = 0;
    LogVisitor(WalkContainer& c, bool p) : container(c), paint(p) {}
    void open_context(const std::shared_ptr<litehtml::render_item>&, litehtml::paint_context) override { contexts++; open++; }
    void close_context() noexcept override { open--; }
    void open_pass(const std::shared_ptr<litehtml::render_item>&, litehtml::draw_flag, int) override { passes++; }
    void close_pass() noexcept override {}
    void paint_element(const std::shared_ptr<litehtml::render_item>& item, litehtml::draw_flag, litehtml::pixel_t, litehtml::pixel_t,
                       const std::function<void()>& draw) override {
        visited.push_back(item.get());
        if (!paint) return;
        const int saved = container.current;
        container.current = int(visited.size()) - 1;
        draw();
        container.current = saved;
    }
};

// Task 4's fixture (WidgetRuntime's LayerTreeTests): one of every paint call and layer kind.
static const char* const kEveryKind =
    "<div style='border:1px solid red'>text</div>"
    "<div style='background-color:#00ff00;height:10px'></div>"
    "<div style='background-image:linear-gradient(red,blue);height:10px'></div>"
    "<div style='background-image:radial-gradient(red,blue);height:10px'></div>"
    "<div style='background-image:conic-gradient(red,blue);height:10px'></div>"
    "<div style='box-shadow:2px 3px 4px 1px black;height:10px'></div>"
    "<div style='opacity:.5'>half</div>"
    "<div style='transform:rotate(10deg)'>turned</div>"
    "<div style='overflow:hidden;border-radius:4px;height:20px'>clipped</div>"
    "<div style='filter:blur(2px)'>blurred</div>"
    "<div style='backdrop-filter:blur(3px);height:10px'></div>"
    "<div style='clip-path:circle(5px);height:10px'>c</div>"
    "<div style='position:fixed;left:0;top:0'>fixed</div>"
    "<svg width=20 height=20><rect width=10 height=10 fill=red /></svg>"
    "<ul><li>item</li></ul>"
    "<p style='text-shadow:3px 4px 2px red'>shadowed</p>"
    "<svg width=20 height=20><line x1=0 y1=5 x2=10 y2=5 stroke=blue stroke-width=2 /></svg>"
    "<svg width=20 height=20><path d='M0 10 C0 0 10 0 10 10' fill='#00ff00' /></svg>"
    "<img src='data:image/png;base64,AAAA'>";

static bool isPaintCall(const std::string& what) {
    return what != "set-clip" && what != "del-clip" && what != "suspend" && what != "resume" && what != "clip-path" &&
           what != "group" && what != "end-group" && what != "filter(" && what != ")filter" && what != "backdrop";
}

// walk_paint_order is draw(): with every visit painted it makes draw()'s calls in draw()'s order; without, only the
// traversal's own calls, which paint nothing. Each render item is visited once, and every paint call comes from a visit.
static void testWalkVisitsWhatDrawPaints() {
    for (const std::string html : {std::string(kEveryKind), std::string("<p>a <span style='background:red'>b</span> <b>c</b></p>"
                                                                       "<div style='float:left;overflow:hidden'>f <i>g</i></div>"
                                                                       "<div style='position:relative;z-index:-1'>n</div>"
                                                                       "<div style='position:absolute;z-index:2'>z</div>"
                                                                       "<p>x <span style='display:inline-block;background:#00f'>ib</span> y</p>"
                                                                       "<table><tr><td style='background:#ff0'>cell</td></tr></table>")}) {
        WalkContainer drawn;
        auto doc = litehtml_test::layout(drawn, html, 300);
        doc->draw(0, 0, 0, nullptr);
        const auto expected = drawn.log;

        WalkContainer painted;
        auto doc2 = litehtml_test::layout(painted, html, 300);
        LogVisitor visitor(painted, true);
        litehtml::walk_paint_order(*doc2, visitor, 0, 0, 0);
        CHECK(visitor.open == 0 && visitor.contexts > 1 && visitor.passes > 3);
        CHECK(painted.log.size() == expected.size());
        bool same = painted.log.size() == expected.size();
        for (size_t i = 0; same && i < expected.size(); i++) same = painted.log[i].what == expected[i].what;
        CHECK(same);
        if (!same) {
            std::printf("  walk differs from draw:\n");
            for (size_t i = 0; i < std::max(expected.size(), painted.log.size()); i++)
                std::printf("    %s | %s\n", i < expected.size() ? expected[i].what.c_str() : "-", i < painted.log.size() ? painted.log[i].what.c_str() : "-");
        }
        // Every paint call is a visit's, in visit order; the traversal's own calls are not.
        int last = -1;
        bool attributed = true, ordered = true;
        for (const auto& call : painted.log) {
            if (isPaintCall(call.what) && call.visit < 0) attributed = false;
            if (call.what == "backdrop" && call.visit >= 0) attributed = false;
            if (call.visit >= 0) {
                if (call.visit < last) ordered = false;
                last = call.visit;
            }
        }
        CHECK(attributed);
        CHECK(ordered);
        // Each render item's own paint happens once.
        CHECK(std::set<const litehtml::render_item*>(visitor.visited.begin(), visitor.visited.end()).size() == visitor.visited.size());
        CHECK(!visitor.visited.empty() && visitor.visited.front() == doc2->root_render().get());

        // Without painting, the traversal's own calls alone, in the same order, and the same visits.
        WalkContainer bare;
        auto doc3 = litehtml_test::layout(bare, html, 300);
        LogVisitor quiet(bare, false);
        litehtml::walk_paint_order(*doc3, quiet, 0, 0, 0);
        std::vector<std::string> own;
        for (const auto& call : painted.log)
            if (call.visit < 0) own.push_back(call.what);
        std::vector<std::string> walked;
        for (const auto& call : bare.log) walked.push_back(call.what);
        CHECK(walked == own);
        CHECK(quiet.visited.size() == visitor.visited.size());
        // A walk changes nothing draw() then does.
        WalkContainer again;
        auto doc4 = litehtml_test::layout(again, html, 300);
        LogVisitor walk(again, false);
        litehtml::walk_paint_order(*doc4, walk, 0, 0, 0);
        again.log.clear();
        doc4->draw(0, 0, 0, nullptr);
        bool unchanged = again.log.size() == expected.size();
        for (size_t i = 0; unchanged && i < expected.size(); i++) unchanged = again.log[i].what == expected[i].what;
        CHECK(unchanged);
    }
}

// Every render item of `doc`, kept alive so no address is reused while a test compares them.
static std::vector<std::shared_ptr<litehtml::render_item>> renderItems(const litehtml::document::ptr& doc) {
    std::vector<std::shared_ptr<litehtml::render_item>> out;
    std::vector<std::shared_ptr<litehtml::render_item>> stack{doc->root_render()};
    while (!stack.empty()) {
        auto item = stack.back();
        stack.pop_back();
        if (!item) continue;
        out.push_back(item);
        for (const auto& child : item->children()) stack.push_back(child);
    }
    return out;
}

struct RecordingObserver : litehtml::render_observer {
    std::set<const litehtml::render_item*> added, removed, texts;
    std::map<const litehtml::render_item*, unsigned> geometry;
    std::vector<std::pair<const litehtml::element*, bool>> restyled;
    int rebuilt = 0;
    void item_added(const std::shared_ptr<litehtml::render_item>& item) override { added.insert(item.get()); }
    void item_removed(const litehtml::render_item* item) override { removed.insert(item); }
    void item_geometry_changed(const litehtml::render_item* item, unsigned what) override { geometry[item] |= what; }
    void element_restyled(const litehtml::element* el, bool paint_order) override { restyled.push_back({el, paint_order}); }
    void text_replaced(const litehtml::render_item* inline_context) override { texts.insert(inline_context); }
    void tree_rebuilt() override { rebuilt++; }
    void clear() {
        added.clear(), removed.clear(), texts.clear(), geometry.clear(), restyled.clear();
        rebuilt = 0;
    }
};

struct Geometry {
    litehtml::position pos;
    litehtml::margins padding, borders;
    std::vector<litehtml::position> boxes;
};

static std::map<const litehtml::render_item*, Geometry> geometryOf(const std::vector<std::shared_ptr<litehtml::render_item>>& items) {
    std::map<const litehtml::render_item*, Geometry> out;
    for (const auto& item : items) {
        Geometry g;
        g.pos = item->pos();
        g.padding = item->get_paddings();
        g.borders = item->get_borders();
        item->for_inline_boxes([&](const litehtml::position& box, bool, bool) {
            g.boxes.push_back(box);
            return true;
        });
        out[item.get()] = g;
    }
    return out;
}

static bool samePos(const litehtml::position& a, const litehtml::position& b) {
    return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}

static bool sameMargins(const litehtml::margins& a, const litehtml::margins& b) {
    return a.left == b.left && a.right == b.right && a.top == b.top && a.bottom == b.bottom;
}

// The inline context an inline-level item is laid out in, or null.
static const litehtml::render_item* inlineContextOf(const litehtml::render_item* item) {
    for (auto p = item->parent(); p; p = p->parent()) {
        if (dynamic_cast<const litehtml::render_item_inline_context*>(p.get())) return p.get();
        if (!p->src_el()->is_inline() || p->src_el()->is_inline_box()) return nullptr;
    }
    return nullptr;
}

// What the observer was told matches what changed: the render items added and removed are exactly the difference of
// the trees, every box that layout moved or resized is reported (an inline item's through its inline context's reflow),
// and every report is a real change. The test compares; the fork never does outside the write site.
static void checkReports(const litehtml::document::ptr& doc, RecordingObserver& observer,
                         const std::vector<std::shared_ptr<litehtml::render_item>>& before,
                         const std::map<const litehtml::render_item*, Geometry>& was, const char* what) {
    const auto after = renderItems(doc);
    std::set<const litehtml::render_item*> a, b;
    for (const auto& item : before) a.insert(item.get());
    for (const auto& item : after) b.insert(item.get());
    std::set<const litehtml::render_item*> gone, came;
    for (const auto* item : a)
        if (!b.count(item)) gone.insert(item);
    for (const auto* item : b)
        if (!a.count(item)) came.insert(item);
    const bool exact = gone == observer.removed && came == observer.added;
    if (!exact) std::printf("  %s: %zu gone / %zu reported removed, %zu came / %zu reported added\n", what, gone.size(),
                            observer.removed.size(), came.size(), observer.added.size());
    CHECK(exact);
    const auto now = geometryOf(after);
    for (const auto& [item, g] : now) {
        auto old = was.find(item);
        if (old == was.end()) continue;
        const bool moved = !(old->second.pos.x == g.pos.x && old->second.pos.y == g.pos.y);
        const bool resized = !(old->second.pos.width == g.pos.width && old->second.pos.height == g.pos.height) ||
                             !sameMargins(old->second.padding, g.padding) || !sameMargins(old->second.borders, g.borders);
        const bool boxes = old->second.boxes.size() != g.boxes.size() ||
                           !std::equal(g.boxes.begin(), g.boxes.end(), old->second.boxes.begin(), samePos);
        auto reported = observer.geometry.find(item);
        const unsigned bits = reported == observer.geometry.end() ? 0 : reported->second;
        const litehtml::render_item* context = inlineContextOf(item);
        const unsigned contextBits = context && observer.geometry.count(context) ? observer.geometry.at(context) : 0;
        const bool covered = (moved || resized || boxes) == false ||
                             ((!moved || (bits & litehtml::render_observer::moved)) && (!resized || (bits & litehtml::render_observer::resized))) ||
                             (contextBits & litehtml::render_observer::reflowed);
        if (!covered) std::printf("  %s: an unreported change (moved %d resized %d boxes %d)\n", what, moved, resized, boxes);
        CHECK(covered);
        // Nothing unchanged is reported moved or resized.
        CHECK(!(bits & litehtml::render_observer::moved) || moved);
        CHECK(!(bits & litehtml::render_observer::resized) || resized);
    }
}

static void testObserverReportsEveryRenderTreeChange() {
    const char* sheet = ".a{color:#c00} .b{color:#00c;background-color:#eee} .o{opacity:.5} p{margin:0}";
    // A text patch the render tree survives: the paragraph's pieces are replaced, it re-flows onto two lines, and the
    // paragraph after it moves.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("p", "short"), el("p", "after"), el("div", "x", {{"class", "a"}})}, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        const auto before = renderItems(doc);
        const auto was = geometryOf(before);
        auto p = childAt(body, 0);
        std::vector<element::ptr> made;
        CHECK(doc->replace_text(p, 0, p->children().size(), "a much longer text that has to wrap here", made));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.rebuilt == 0);
        CHECK(observer.texts.size() == 1 && observer.texts.count(p->get_render_item().get()));
        CHECK(!observer.added.empty() && !observer.removed.empty());
        checkReports(doc, observer, before, was, "text patch");
        auto after = childAt(body, 1)->get_render_item().get();
        CHECK(observer.geometry.count(after) && (observer.geometry.at(after) & litehtml::render_observer::moved));
        CHECK(observer.geometry.count(p->get_render_item().get()));
        // The paragraph before nothing changed above is not reported.
        doc->set_render_observer(nullptr);
    }
    // A neutral class change: the tree is kept, nothing is added or removed, the element is reported restyled, with
    // paint order when the change is opacity.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("p", "one"), el("div", "x", {{"class", "a"}}), el("p", "two")}, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        const auto before = renderItems(doc);
        const auto was = geometryOf(before);
        auto div = childAt(body, 1);
        CHECK(doc->set_element_attribute(div, "class", "b"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.rebuilt == 0);
        CHECK(observer.restyled.size() == 1 && observer.restyled[0].first == div.get() && !observer.restyled[0].second);
        checkReports(doc, observer, before, was, "class patch");
        CHECK(observer.added.empty() && observer.removed.empty());
        observer.clear();
        const auto before2 = renderItems(doc);
        const auto was2 = geometryOf(before2);
        CHECK(doc->set_element_attribute(div, "class", "b o"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.rebuilt == 0);
        CHECK(observer.restyled.size() == 1 && observer.restyled[0].first == div.get() && observer.restyled[0].second);
        checkReports(doc, observer, before2, was2, "opacity class patch");
        doc->set_render_observer(nullptr);
    }
    // A structural patch and a style patch rebuild the render tree: tree_rebuilt, and no per-item reports.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("p", "one"), el("div", "x")}, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->insert_subtree(body, body->children().size(), build(doc, el("p", "appended"))));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.rebuilt == 1);
        CHECK(observer.added.empty() && observer.removed.empty());
        observer.clear();
        CHECK(doc->set_element_attribute(childAt(body, 1), "style", "padding:4px"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.rebuilt == 1);
        doc->set_render_observer(nullptr);
    }
}


// Telegram (VENDOR.md edit 21): the style-byte budget.
static size_t heap_in_use() {
    malloc_statistics_t stats{};
    malloc_zone_statistics(nullptr, &stats);
    return stats.size_in_use;
}

static std::string many_elements(int n) {
    std::string out = "<body style='margin:0'>";
    for (int i = 0; i < n; i++) out += "<b></b>";
    return out + "</body>";
}

static void testStyleBytesAreBudgeted() {
    const int kElements = 9000;
    const std::string body = many_elements(kElements);
    size_t baseline = 0;
    {
        LimitContainer c;
        const size_t before = heap_in_use();
        auto doc = litehtml::document::createFromString(litehtml::estring("<style></style>" + body), &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        baseline = heap_in_use() - before;
        CHECK(c.limits.empty());
        CHECK(doc->style_bytes_charged() == 0);
    }
    {
        LimitContainer c;
        const size_t before = heap_in_use();
        auto doc = litehtml::document::createFromString(
            litehtml::estring("<style>* { --x: " + std::string(16 * 1024, 'x') + " }</style>" + body), &c,
            litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        const size_t grown = heap_in_use() - before;
        const double over = double(grown) - double(baseline);
        std::printf("style budget: 16 KiB --x on * over %d elements: +%.1f MB over the baseline, %zu bytes charged\n", kElements,
                    over / 1048576, doc->style_bytes_charged());
        CHECK(std::count(c.limits.begin(), c.limits.end(), std::string("style-bytes")) == 1);
        CHECK(over < 2.0 * double(litehtml::document::max_style_bytes));
        CHECK(doc->style_bytes_charged() <= litehtml::document::max_style_bytes);
        CHECK(count_elements(doc->root()) > kElements);
        CHECK(!dump_of(doc).empty());
    }
    // A plainly styled document of the same size is not cut.
    {
        LimitContainer c;
        auto doc = litehtml::document::createFromString(litehtml::estring("<style>b { color: red; font-family: A, B, C }</style>" + body), &c,
                                                        litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        CHECK(c.limits.empty());
    }
}

static void testStyleBudgetIsDeterministic() {
    const std::string html = "<style>* { --x: " + std::string(16 * 1024, 'x') + " } b { width: 3px; height: 3px; display: block }</style>" +
                             many_elements(3000);
    std::string dumps[2];
    size_t charged[2];
    for (int i = 0; i < 2; i++) {
        LimitContainer c;
        auto doc = litehtml::document::createFromString(litehtml::estring(html), &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        CHECK(std::count(c.limits.begin(), c.limits.end(), std::string("style-bytes")) == 1);
        dumps[i]   = dump_of(doc);
        charged[i] = doc->style_bytes_charged();
    }
    CHECK(dumps[0] == dumps[1]);
    CHECK(charged[0] == charged[1]);
}

// Telegram (VENDOR.md edit 21, Ruling E47): a var() splice copies the property's value onto the element, and is charged.
static std::string repeated(const std::string& unit, size_t bytes) {
    std::string out;
    while (out.size() < bytes) out += unit;
    return out;
}

static void testVarSplicesAreBudgeted() {
    const int kElements = 9000;
    const std::string ff = repeated("aa,", 16 * 1024);
    const std::string ct = repeated("\"a\" ", 16 * 1024);
    const std::string tr = repeated("color 1s,", 16 * 1024);
    std::string chain = ":root{--a0:" + ff + "}";
    for (int i = 1; i <= 10; i++)
        chain += ":root{--a" + std::to_string(i) + ":var(--a" + std::to_string(i - 1) + ") var(--a" + std::to_string(i - 1) + ")}";
    struct Case { const char* name; std::string css; std::string element; std::string baselineCss = ""; };
    const Case cases[] = {
        {"--y:var(--x)", ":root{--x:" + ff + "} *{--y:var(--x)}", "<b></b>"},
        {"transition:var(--x)", ":root{--x:" + tr + "} *{transition:var(--x)}", "<b></b>"},
        {"font-family:var(--x)", ":root{--x:" + ff + "} *{font-family:var(--x)}", "<b></b>"},
        {"::before content:var(--x)", ":root{--x:" + ct + "} b::before{content:var(--x)}", "<b></b>", "b::before{content:\"a\"}"},
        {"inline style --y:var(--x)", ":root{--x:" + ff + "}", "<b style='--y:var(--x)'></b>"},
        {"10-level doubling chain", chain + "*{--z:var(--a10)}", "<b></b>"},
    };
    for (const Case& k : cases) {
        std::string body = "<body style='margin:0'>";
        for (int i = 0; i < kElements; i++) body += k.element;
        body += "</body>";
        size_t baseline = 0;
        {
            LimitContainer c;
            const size_t before = heap_in_use();
            auto doc = litehtml::document::createFromString(litehtml::estring("<style>" + k.baselineCss + "</style>" + body), &c, litehtml::telegram_master_css());
            doc->render(litehtml::pixel_t(300.0f));
            baseline = heap_in_use() - before;
        }
        LimitContainer c;
        const size_t before = heap_in_use();
        auto doc = litehtml::document::createFromString(litehtml::estring("<style>" + k.css + "</style>" + body), &c,
                                                        litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        const double over = double(heap_in_use() - before) - double(baseline);
        std::printf("var budget: %-28s +%.1f MB over the baseline, %zu charged\n", k.name, over / 1048576, doc->style_bytes_charged());
        const auto posts = std::count(c.limits.begin(), c.limits.end(), std::string("style-bytes"));
        if (posts != 1) std::printf("  %s: style-bytes posted %ld times\n", k.name, long(posts));
        CHECK(posts == 1);
        CHECK(over < 2.0 * double(litehtml::document::max_style_bytes));
        CHECK(!dump_of(doc).empty());
    }
}

// Ruling E48: a document past the budget keeps its fixed-size declarations, and a refresh (a width change) after the limit
// equals a rebuild at the new width.
static void testRefreshAfterTheLimitEqualsARebuild() {
    const std::string big(16 * 1024, 'x');
    std::string body = "<body style='margin:0'>";
    for (int i = 0; i < 3000; i++) body += "<b></b>";
    body += "</body>";
    const std::string css = "<style>*{--x:" + big + "} b{display:block;width:30px;height:3px} @media (max-width:250px){ b{width:7px} }</style>";
    LimitContainer c;
    c.width = 300;
    auto doc = litehtml::document::createFromString(litehtml::estring(css + body), &c, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(300.0f));
    CHECK(doc->style_bytes_limited());
    // Past the budget the fixed-size declarations still apply: every b is 30 wide.
    const std::string at300 = dump_of(doc);
    size_t p = 0, thirties = 0;
    while ((p = at300.find(" 30 3\n", p)) != std::string::npos) { thirties++; p++; }
    CHECK(thirties == 3000);
    c.width = 200;
    CHECK(doc->viewport_changed());
    doc->render(litehtml::pixel_t(200.0f));
    const std::string refreshed = dump_of(doc);
    LimitContainer c2;
    c2.width = 200;
    auto fresh = litehtml::document::createFromString(litehtml::estring(css + body), &c2, litehtml::telegram_master_css());
    fresh->render(litehtml::pixel_t(200.0f));
    CHECK(refreshed == dump_of(fresh));
    CHECK(doc->style_bytes_charged() == fresh->style_bytes_charged());
    size_t sevens = 0;
    p = 0;
    while ((p = refreshed.find(" 7 3\n", p)) != std::string::npos) { sevens++; p++; }
    std::printf("refresh after the limit: %zu of 3000 b are 7 wide after the width change\n", sevens);
    CHECK(sevens == 3000);
}

// Ruling E50: an inherited string is copied into every descendant's computed style, so a long one is cut (a URL dropped).
static void testInheritedStringsAreBounded() {
    const int kElements = 9000;
    const std::string a(16 * 1024, 'a');
    // `bullet`: the list's image URL, kept and charged instead (edit 60, testInheritedUrlsAreSharedAndCharged).
    struct Case { const char* name; std::string css; bool bullet = false; };
    const Case cases[] = {
        {"cursor", "html{cursor:" + a + "}"},
        {"cursor url", "html{cursor:url(" + a + "),auto}"},
        {"text-emphasis-style", "html{text-emphasis-style:\"" + a + "\"}"},
        {"text-emphasis shorthand", "html{text-emphasis:\"" + a + "\" red}"},
        {"font-variant-numeric", "html{font-variant-numeric:" + a + "}"},
        {"list-style-image", "html{list-style-image:url(" + a + ")}", true},
        {"list-style shorthand", "html{list-style:url(" + a + ")}", true},
        {"font-family", "html{font-family:" + a + "}"},
        {"font shorthand", "html{font:12px " + a + "}"},
        // An unresolved var() leaves a token list, not a string: the element declares no string, so it inherits (cut).
        {"cursor var(--nope)", "html{cursor:" + a + "} *{cursor:var(--nope)}"},
        {"text-emphasis-style var(--nope)", "html{text-emphasis-style:\"" + a + "\"} *{text-emphasis-style:var(--nope)}"},
        {"font-variant-numeric var(--nope)", "html{font-variant-numeric:" + a + "} *{font-variant-numeric:var(--nope)}"},
        {"list-style-image var(--nope)", "html{list-style-image:url(" + a + ")} *{list-style-image:var(--nope)}", true},
    };
    const std::string body = many_elements(kElements);
    size_t baseline = 0;
    {
        LimitContainer c;
        const size_t before = heap_in_use();
        auto doc = litehtml::document::createFromString(litehtml::estring("<style></style>" + body), &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        baseline = heap_in_use() - before;
    }
    for (const Case& k : cases) {
        LimitContainer c;
        const size_t before = heap_in_use();
        auto doc = litehtml::document::createFromString(litehtml::estring("<style>" + k.css + "</style>" + body), &c,
                                                        litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        const double over = double(heap_in_use() - before) - double(baseline);
        std::printf("inherited string: %-26s +%.1f MB over the baseline\n", k.name, over / 1048576);
        CHECK(over < 2.0 * double(litehtml::document::max_style_bytes));
        auto b = doc->root()->select_one("b");
        CHECK(b != nullptr);
        if (b) {
            CHECK(b->css().get_cursor().size() <= 1024);
            if (!k.bullet)
                CHECK(b->css().get_list_style_image().size() <= 1024);
            CHECK(b->css().get_text_emphasis_style().size() <= 1024);
            CHECK(b->css().font_family().size() <= 1024);
        }
    }
    // A short value is unchanged, and a URL under the cap still loads as written.
    {
        LimitContainer c;
        auto doc = litehtml::document::createFromString(
            litehtml::estring("<style>html{cursor:pointer;list-style-image:url(a.png);text-emphasis-style:filled;font-family:Foo,Bar}</style>" + many_elements(3)),
            &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        auto b = doc->root()->select_one("b");
        CHECK(b != nullptr);
        if (b) {
            CHECK(b->css().get_cursor() == "pointer");
            CHECK(b->css().get_list_style_image() == "a.png");
            CHECK(b->css().get_text_emphasis_style() == "filled");
            CHECK(b->css().font_family() == "Foo,Bar" || b->css().font_family() == "Foo, Bar");
        }
    }
}

// Edit 60: an inherited URL over 1 KiB (an image bullet set on a list) is kept: the elements holding it share one
// string, and each list item among them (only a marker reads the URL) is charged its length to the style budget, given
// back when it is computed again. Past half the budget an item falls back to no image, and the budget does not latch.
static void testInheritedUrlsAreSharedAndCharged() {
    const std::string url = "data:image/png;base64," + std::string(16 * 1024, 'A');
    const std::string css = "<style>html{list-style:url(" + url + ")} b{display:list-item}</style>";
    {
        LimitContainer c;
        auto doc = litehtml::document::createFromString(litehtml::estring(css + many_elements(100)), &c,
                                                        litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        const litehtml::elements_list bs = doc->root()->select_all("b");
        CHECK(bs.size() == 100);
        if (bs.size() == 100) {
            CHECK(bs.front()->css().get_list_style_image() == url);
            CHECK(&bs.front()->css().get_list_style_image() == &bs.back()->css().get_list_style_image());
        }
        CHECK(c.limits.empty());
        const size_t charged = doc->style_bytes_charged();
        // html's own declaration and the 100 <b>s, which are list items; head and body hold the string uncharged.
        if (charged < 101 * url.size() || charged >= 102 * url.size()) std::printf("inherited url: %zu bytes charged\n", charged);
        CHECK(charged >= 101 * url.size() && charged < 102 * url.size());
        CHECK(doc->root()->select_one("body")->css().get_list_style_image() == url);
        doc->root()->compute_styles();
        CHECK(doc->style_bytes_charged() == charged);
        doc->refresh_all_styles();
        doc->root()->compute_styles();
        CHECK(doc->style_bytes_charged() == charged);
    }
    {
        const std::string body = many_elements(9000);
        size_t baseline = 0;
        {
            LimitContainer c;
            const size_t before = heap_in_use();
            auto doc = litehtml::document::createFromString(litehtml::estring("<style>b{display:list-item}</style>" + body), &c,
                                                            litehtml::telegram_master_css());
            doc->render(litehtml::pixel_t(300.0f));
            baseline = heap_in_use() - before;
        }
        LimitContainer c;
        const size_t before = heap_in_use();
        auto doc = litehtml::document::createFromString(litehtml::estring(css + body), &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        const double over = double(heap_in_use() - before) - double(baseline);
        std::printf("inherited url over 9000 elements: +%.1f MB over the baseline, %zu bytes charged\n", over / 1048576,
                    doc->style_bytes_charged());
        // One shared string: the copies cost a pointer each.
        CHECK(over < 2.0 * 1048576);
        CHECK(c.limits.empty() && !doc->style_bytes_limited());
        CHECK(doc->style_bytes_charged() <= litehtml::document::max_style_bytes / 2);
        const litehtml::elements_list bs = doc->root()->select_all("b");
        CHECK(!bs.empty() && bs.front()->css().get_list_style_image() == url);
        CHECK(!bs.empty() && bs.back()->css().get_list_style_image().empty());
    }
    // A template document's class changes, back and forth: each turn charges the items' bullet and gives it back alike.
    {
        LimitContainer c;
        const auto page = [&](const char* cls) {
            return "<style>.on{list-style:url(" + url + ")}</style><body><ul class=\"" + std::string(cls) +
                   "\"><li></li><li></li></ul></body>";
        };
        auto doc = litehtml::document::createUpdatableFromString(page("off"), &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        const size_t off = doc->style_bytes_charged();
        size_t on = 0;
        for (int i = 0; i < 3; i++) {
            bool changed = false;
            doc->update_from_string(page("on"), &changed);
            doc->render(litehtml::pixel_t(300.0f));
            if (i == 0)
                on = doc->style_bytes_charged();
            if (doc->style_bytes_charged() != on) std::printf("class change %d on: %zu charged, first %zu\n", i, doc->style_bytes_charged(), on);
            CHECK(doc->style_bytes_charged() == on);
            doc->update_from_string(page("off"), &changed);
            doc->render(litehtml::pixel_t(300.0f));
            if (doc->style_bytes_charged() != off) std::printf("class change %d off: %zu charged, first %zu\n", i, doc->style_bytes_charged(), off);
            CHECK(doc->style_bytes_charged() == off);
        }
        CHECK(on >= off + 2 * url.size());
    }
}

int main() {
    testExternalBuildMatchesParse();
    testExternalSvgMatchesParse();
    testInsertChildAtEveryIndex();
    testRemoveChildRepointsHover();
    testTextPiecesFollowTheCap();
    testReplaceTextMatchesFresh();
    testReplaceTextBesideElements();
    testReplaceTextRefusals();
    testReplaceTextRepointsHover();
    testSetAttributeMatchesFresh();
    testSetAttributeRefusals();
    testSetAttributeFixRound();
    testBuildCapsMatchCreateNode();
    testMasterCssIsTwidgets();
    testInsertRemoveMatchesFresh();
    testSubjectPositionsMatchSiblingsAgain();
    testStructureRefusals();
    testStructureCaps();
    testReplaceChildrenUnderPositionalSelectors();
    testSelectorStepsAreOneBudgetPerSession();
    testSelectorStepBoundHolds();
    testTableRowsArePlacedOncePerLayout();
    testMatchingBoundCountsPseudoElementsAndParts();
    testFontSizeZeroMatchesFresh();
    testWalkVisitsWhatDrawPaints();
    testObserverReportsEveryRenderTreeChange();
    testStyleBytesAreBudgeted();
    testStyleBudgetIsDeterministic();
    testVarSplicesAreBudgeted();
    testInheritedStringsAreBounded();
    testInheritedUrlsAreSharedAndCharged();
    testRefreshAfterTheLimitEqualsARebuild();
    if (failures) {
        std::printf("%d failure(s)\n", failures);
        return 1;
    }
    std::printf("ok\n");
    return 0;
}
