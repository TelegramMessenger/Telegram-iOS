// Host test of twidget edit 12 (VENDOR.md): building a litehtml document from an external DOM (create_element,
// append_text, insert_child, external_element_allowed, finalize_from_external_root) and the master CSS in C++.
#include "test_container.h"

#include <litehtml/telegram_master_css.h>

#include <litehtml/render_inline_context.h>
#include <litehtml/render_item.h>

#include <malloc/malloc.h>

#include <algorithm>
#include <cstdio>
#include <cstring>
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

// Twidget edit 83: accepts_child and accepts_text answer exactly what appendChild links, so a caller can ask before it
// makes (and counts) anything.
static void testAcceptsChildMatchesAppendChild() {
    litehtml_test::TestContainer c;
    auto doc = std::make_shared<litehtml::document>(&c);
    for (const char* parentTag : {"div", "table", "style", "script", "p"}) {
        for (const char* childTag : {"tbody", "thead", "tfoot", "caption", "tr", "td", "div"}) {
            auto parent = make(doc, parentTag);
            auto child = make(doc, childTag);
            const bool asked = parent->accepts_child(child->tag());
            const bool linked = parent->appendChild(child);
            if (asked != linked) std::printf("  %s under %s: asked %d, linked %d\n", childTag, parentTag, asked, linked);
            CHECK(asked == linked);
        }
        auto parent = make(doc, parentTag);
        std::vector<element::ptr> pieces;
        doc->make_text_pieces(parent, "x", pieces);
        CHECK(pieces.size() == 1);
        const bool asked = parent->accepts_text();
        const bool linked = !pieces.empty() && parent->appendChild(pieces.front());
        if (asked != linked) std::printf("  text under %s: asked %d, linked %d\n", parentTag, asked, linked);
        CHECK(asked == linked);
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

// VENDOR.md edit 16: a <button> never reads its children's text (el_button draws its bezel around them), so text inside one
// is replaced in place as anywhere else.
static void testButtonTextIsReplacedInPlace() {
    patchedMatchesFresh("button", "go", "a much longer label");
    patchedMatchesFresh("button", "one two three", "x");
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
        CHECK(std::string(doc->refusal()) == "a parent whose children an element reads"); // edit 76
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
        add(doc, root, body);
        doc->finalize_from_external_root(root, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(120.0f));
        std::vector<element::ptr> pieces;
        CHECK(!doc->can_replace_text(option, 0, 1, "two"));
        CHECK(std::string(doc->refusal()) == "a parent whose children an element reads"); // edit 76
        CHECK(!doc->replace_text(option, 0, 1, "two", pieces));
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
        CHECK(std::string(doc->refusal()) == "the text-piece cap"); // edit 76: WidgetRuntime walks the cut there
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
    std::string rootDeclarations;  // the root declarations structureDocument sets (edit 26)
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
    void draw_box_shadow(litehtml::uint_ptr, const litehtml::position& p, const litehtml::border_radiuses&,
                         const litehtml::shadow_paint& shadow) override {
        log.push_back("shadow " + box(p) + ' ' + color(shadow.color));
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
    if (doc->style_bytes_charged() != reference->style_bytes_charged())
        std::printf("  style bytes %zu, a fresh document's %zu: <%s> %s=%s\n", doc->style_bytes_charged(),
                    reference->style_bytes_charged(), tag, name, value ? value : "(removed)");
    CHECK(doc->style_bytes_charged() == reference->style_bytes_charged());
}

static void testSetAttributeMatchesFresh() {
    const char* sheet = ".a{color:#c00;background:#00f;padding:2px} .b{color:#0a0;font-weight:bold} .c{background:#fc0}"
                        "#x{background:#ccc;padding:4px} #y{background:#fc0;padding:12px;margin:3px}"
                        "[hidden]{display:none} a:link{color:#909} input:checked{outline:1px solid #f00}";
    // A class toggle (added, swapped, removed) and an id change.
    attributePatchedMatchesFresh(sheet, "p", {}, "class", "a");
    // A <br>'s attributes (el_break): what a rule reads of it, a block one included, and its inline style.
    {
        const char* brSheet = ".v{display:block;height:4px;background:#00f} #k{border:1px solid #000}";
        attributePatchedMatchesFresh(brSheet, "br", {}, "class", "v");
        attributePatchedMatchesFresh(brSheet, "br", {{"class", "v"}}, "class", nullptr);
        attributePatchedMatchesFresh(brSheet, "br", {}, "id", "k");
        attributePatchedMatchesFresh(brSheet, "br", {}, "style", "display:block;height:3px");
    }
    // Edit 31.5: matched again in place, an element with text is still not :empty.
    attributePatchedMatchesFresh("span:empty{padding:9px} p:not(:empty){margin:7px} .k{color:#c00}", "span", {}, "class", "k");
    attributePatchedMatchesFresh("span:empty{padding:9px} p:not(:empty){margin:7px} .k{color:#c00}", "p", {}, "class", "k");
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
    // A <button>'s class and disabled (it reads disabled again when restyled).
    attributePatchedMatchesFresh(".on{background:#cfc}", "button", {}, "class", "on");
    attributePatchedMatchesFresh("", "button", {}, "disabled", "");
    attributePatchedMatchesFresh("", "button", {{"disabled", ""}}, "disabled", nullptr);
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
    // I1: :link in an ancestor position names href, so an href change reaches the span (edit 77), either way.
    attributePatchedMatchesFresh("a:link span{color:#c00} span{color:#00c}", "a+span", {}, "href", "x");
    attributePatchedMatchesFresh("a:link span{color:#c00} span{color:#00c}", "a+span", {{"href", "x"}}, "href", nullptr);
    attributePatchedMatchesFresh("a:link span{color:#c00} span{color:#00c}", "a+span", {{"href", "x"}}, "href", "y");
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

    // I2, under edit 84: with a ::before or ::after rule with content, a patch is made at the caps too: near one the commit
    // replays the style pass in a build's order, so the patched document equals a fresh build, which makes pseudo-element
    // content after all text, in document order. The shapes that got past a byte bound: function name case and spacing,
    // and a second element's rule whose content overlaps in a fresh build.
    {
        const char* sheets[] = {
            ".x::before{content:\"a b c d\"} .x{color:#c00}",
            ".x::before{content:ATTR(title)} .z::before{content:\"q\"}",
            ".x::before{content:attr (title)} .z::before{content:\"q\"}",
            "[title]::before{content:attr(title)} .k::before{content:attr(title)} .x::before{content:\"a b c d\"}",
            ".x:after{content:\"a b c d\"}",
        };
        const litehtml::string_map title = {{"title", "t t t t t t t t t t"}};
        int compared = 0, capped = 0;
        for (const char* sheet : sheets) {
            for (int words : {0, 4000, 4990, 5004}) {
                fillerWords = words;
                PaintContainer c, fresh, textFresh;
                element::ptr target, expected, textExpected;
                auto doc = attrDocument(c, sheet, "div", title, target);
                litehtml::string_map classed = title;
                classed["class"] = "x";
                auto reference = attrDocument(fresh, sheet, "div", classed, expected);
                beforeText = "other words";
                auto textReference = attrDocument(textFresh, sheet, "div", classed, textExpected);
                beforeText = "before";
                CHECK(doc->pseudo_content_possible());
                auto p = doc->root()->select_one("p");
                CHECK(doc->set_element_attribute(target, "class", "x"));
                doc->commit_patch();
                doc->render(litehtml::pixel_t(160.0f));
                CHECK(dump_of(doc) == dump_of(reference));
                CHECK(painted(c, doc) == painted(fresh, reference));
                CHECK(doc->text_elements() == reference->text_elements());
                CHECK(doc->text_limited() == reference->text_limited() && doc->pseudo_limited() == reference->pseudo_limited());
                // Then a text patch (edit 16), unless the document's own text is at the cap: a fresh build cuts the filler
                // after it, which is the caller's walk to find (WidgetRuntime's RenderCut), not the fork's.
                std::vector<element::ptr> pieces;
                if (doc->document_text_pieces() + 2 > litehtml::document::max_text_elements) {
                    CHECK(!doc->can_replace_text(p, 0, p->children().size(), "other words"));
                    continue;
                }
                CHECK(doc->can_replace_text(p, 0, p->children().size(), "other words"));
                CHECK(doc->replace_text(p, 0, p->children().size(), "other words", pieces));
                doc->commit_patch();
                doc->render(litehtml::pixel_t(160.0f));
                CHECK(dump_of(doc) == dump_of(textReference));
                CHECK(painted(c, doc) == painted(textFresh, textReference));
                CHECK(doc->text_elements() == textReference->text_elements());
                capped += textReference->text_limited() ? 1 : 0;
                compared++;
            }
        }
        CHECK(compared > 0);
        CHECK(capped > 0);
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
            CHECK(doc->can_set_element_attribute(p, "class", "x"));
            CHECK(doc->can_replace_text(p, 0, 1, "other"));
        }
    }

    // A control makes its lh-* parts when it is matched again, and a build makes them between the master and author passes
    // (edit 84: the commit's replay makes them there too). type text -> range in one patch, then a text patch near the
    // cap: each equals a fresh build with the same text.
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
                                  doc->text_elements() == reference->text_elements() &&
                                  doc->text_limited() == reference->text_limited();
                if (!same) {
                    std::printf("  range then text differs at %d filler words: pieces %d/%d limited %d/%d replays %llu\n", words,
                                doc->text_elements(), reference->text_elements(), doc->text_limited(), reference->text_limited(),
                                (unsigned long long)doc->generated_replays());
                    std::istringstream a(dump_of(doc)), b(dump_of(reference));
                    std::string la, lb;
                    int line = 0, shown = 0;
                    while (std::getline(a, la) && std::getline(b, lb) && shown < 6) {
                        line++;
                        if (la != lb) { std::printf("    line %d: [%s] vs [%s]\n", line, la.c_str(), lb.c_str()); shown++; }
                    }
                }                CHECK(same);
            }
        }
        fillerWords = 0;
        std::printf("  range shape: %d type patches, %d text patches accepted\n", typed, texted);
        // Every type change patches; a text past the document's own cap is refused here (the caller's walk cuts the filler
        // after it, as a build does), and every other one patches.
        CHECK(typed == 37 && texted > 20);
    }

    // The table-cell cap: a span change past 200,000 cells is made (edit 84: the commit recounts the cells from the root,
    // cutting them as a build does); each equals a fresh build.
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
        CHECK(doc->can_set_element_attributes(b, big));                   // 2,000 cells: past the cap
        // Pending cells are threaded through.
        litehtml::document::attribute_growth pending;
        CHECK(doc->can_set_element_attributes(b, {{"colspan", "500"}}, &pending) && pending.cells == 499);
        CHECK(doc->can_set_element_attributes(b, {{"colspan", "1000"}}, &pending) && pending.cells == 499 + 999);
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
        // Past the cap, equal to a fresh build that cuts there.
        PaintContainer freshPast;
        auto built = [&] {
            auto d = std::make_shared<litehtml::document>(&freshPast);
            d->set_document_mode(litehtml::no_quirks_mode);
            auto root = make(d, "html");
            auto body = make(d, "body");
            auto table = make(d, "table");
            auto tr = make(d, "tr");
            auto a = make(d, "td", {{"colspan", "1000"}, {"rowspan", "199"}});
            text(d, a, "a");
            auto bb = make(d, "td", {{"colspan", "1000"}, {"rowspan", "2"}});
            text(d, bb, "b");
            auto tbody = make(d, "tbody");
            add(d, tr, a);
            add(d, tr, bb);
            add(d, tbody, tr);
            add(d, table, tbody);
            add(d, body, table);
            add(d, root, body);
            d->finalize_from_external_root(root, litehtml::telegram_master_css());
            d->render(litehtml::pixel_t(160.0f));
            return d;
        }();
        CHECK(doc->set_element_attributes(b, big));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(160.0f));
        CHECK(dump_of(doc) == dump_of(built));
        CHECK(painted(c, doc) == painted(freshPast, built));
        CHECK(doc->table_cells() == built->table_cells());
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
    // A class, an id and an attribute name in a selector's ancestor position reach what they name (edit 77).
    attributePatchedMatchesFresh(".on p{color:#c00}", "div", {}, "class", "on");
    attributePatchedMatchesFresh(".on p{color:#c00}", "div", {{"class", "on"}}, "class", nullptr);
    attributePatchedMatchesFresh("#x p{color:#c00}", "div", {}, "id", "x");
    attributePatchedMatchesFresh("[hidden] p{color:#c00}", "div", {}, "hidden", "");
    // Sibling combinators anywhere in the sheets. (A positional pseudo-class reads an element's place, which no
    // attribute changes: VENDOR.md edit 42.)
    attributePatchedMatchesFresh("p:nth-child(2){color:#c00}", "div", {}, "class", "z");
    attributePatchedMatchesFresh("p:first-child{color:#c00}", "div", {}, "id", "z");
    attributePatchedMatchesFresh("div + p{color:#c00}", "div", {}, "class", "z");
    // Counters (edit 78: they run again in a build's order).
    attributePatchedMatchesFresh("p{counter-increment:n}", "div", {}, "class", "z");
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
    // An inline style touching a counter, going in or out; a custom property or var().
    attributePatchedMatchesFresh("", "div", {}, "style", "counter-reset:n");
    attributePatchedMatchesFresh("", "div", {{"style", "counter-reset:n"}}, "style", "color:red");
    attributePatchedMatchesFresh("", "div", {{"style", "counter-reset:n"}}, "style", nullptr);
    attributePatchedMatchesFresh("", "div", {}, "style", "--x:1");
    attributePatchedMatchesFresh("", "div", {}, "style", "color:var(--x, #c00)");
    attributePatchedMatchesFresh("", "div", {{"style", "--x:1"}}, "style", "color:red");
    attributePatchedMatchesFresh("", "div", {{"style", "--x:1"}}, "style", nullptr);
    // An element no one patches in place: a textarea; and one that is not in the document.
    attributeRefused("", "textarea", {}, "placeholder", "hint");
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
    bool hover = false;            // :hover set before the document is finalized, as WidgetRuntime's build sets it
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
    if (spec.hover) e->set_pseudo_class(litehtml::_hover_, true);
    if (!spec.text.empty()) pieces(doc, e, spec.text);
    for (const Spec& kid : spec.kids) {
        if (kid.tag.empty()) pieces(doc, e, kid.text);
        else add(doc, e, build(doc, kid));
    }
    return e;
}

// html > [head > style(sheet)...] body(style=margin:0, kids): a <style> for each of `sheets`, an empty one holding no
// text. `body` gets the body.
static element::ptr structureRoot(const litehtml::document::ptr& doc, const std::vector<std::string>& sheets,
                                  const std::vector<Spec>& kids, element::ptr& body) {
    auto root = make(doc, "html");
    auto head = make(doc, "head");
    for (const std::string& sheet : sheets) {
        auto style = make(doc, "style");
        if (!sheet.empty()) text(doc, style, sheet.c_str());
        add(doc, head, style);
    }
    add(doc, root, head);
    body = make(doc, "body", {{"style", "margin:0"}});
    for (const Spec& kid : kids) {
        if (kid.tag.empty()) text(doc, body, kid.text.c_str());
        else add(doc, body, build(doc, kid));
    }
    add(doc, root, body);
    return root;
}

static litehtml::document::ptr structureDocument(PaintContainer& c, const std::vector<std::string>& sheets,
                                                 const std::vector<Spec>& kids, element::ptr& body, bool render = true) {
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    auto root = structureRoot(doc, sheets, kids, body);
    if (!c.rootDeclarations.empty()) doc->set_root_declarations(c.rootDeclarations);
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    if (render) doc->render(litehtml::pixel_t(200.0f));
    return doc;
}

// html > [head > style(sheet)] body(style=margin:0, kids), the <style> only when `sheet` is not empty.
static litehtml::document::ptr structureDocument(PaintContainer& c, const char* sheet, const std::vector<Spec>& kids,
                                                 element::ptr& body, bool render = true) {
    return structureDocument(c, *sheet ? std::vector<std::string>{sheet} : std::vector<std::string>{}, kids, body, render);
}

// The caps the document's content has reached (edit 84: what a fresh build of it reports; a patched document's container
// has heard every cap its history reached, a replay's again).
static std::string capsReached(const litehtml::document::ptr& doc) {
    return std::string(doc->text_limited() ? "text " : "") + (doc->pseudo_limited() ? "elements " : "") +
           (doc->style_bytes_limited() ? "style-bytes " : "") + (doc->table_limited() ? "table" : "");
}

// Commits and lays out `doc`, then compares it with a document built afresh from `kids`: placements, height, everything
// painted, the text-piece count and the limits reported.
static void structureMatchesFresh(PaintContainer& c, const litehtml::document::ptr& doc,
                                  const std::vector<std::string>& sheets, const std::vector<Spec>& kids, const char* what,
                                  int width = 300, int reduced = 0, int scheme = 0) {
    doc->commit_patch();
    doc->render(litehtml::pixel_t(200.0f));
    PaintContainer fresh;
    fresh.width = width;
    fresh.reduced = reduced;
    fresh.scheme = scheme;
    fresh.rootDeclarations = c.rootDeclarations;
    element::ptr body;
    auto reference = structureDocument(fresh, sheets, kids, body);
    const bool same = dump_of(doc) == dump_of(reference) && float(doc->height()) == float(reference->height()) &&
                      painted(c, doc) == painted(fresh, reference) && doc->text_elements() == reference->text_elements() &&
                      capsReached(doc) == capsReached(reference);
    if (!same) std::printf("  structure differs after: %s\n%s---\n%s", what, dump_of(doc).c_str(), dump_of(reference).c_str());
    CHECK(dump_of(doc) == dump_of(reference));
    CHECK(float(doc->height()) == float(reference->height()));
    CHECK(painted(c, doc) == painted(fresh, reference));
    CHECK(doc->text_elements() == reference->text_elements());
    CHECK(capsReached(doc) == capsReached(reference));
    if (doc->style_bytes_charged() != reference->style_bytes_charged())
        std::printf("  style bytes %zu, a fresh document's %zu after: %s\n", doc->style_bytes_charged(),
                    reference->style_bytes_charged(), what);
    CHECK(doc->style_bytes_charged() == reference->style_bytes_charged());
}

static void structureMatchesFresh(PaintContainer& c, const litehtml::document::ptr& doc, const char* sheet,
                                  const std::vector<Spec>& kids, const char* what, int width = 300, int reduced = 0,
                                  int scheme = 0) {
    structureMatchesFresh(c, doc, *sheet ? std::vector<std::string>{sheet} : std::vector<std::string>{}, kids, what, width,
                          reduced, scheme);
}

// structureMatchesFresh against a document built with :hover set on the elements whose ids are `ids`.
static void pseudoMatchesFresh(PaintContainer& c, const litehtml::document::ptr& doc, const char* sheet,
                               std::vector<Spec> kids, const std::vector<std::string>& ids, const char* what) {
    std::vector<Spec*> stack;
    for (Spec& kid : kids) stack.push_back(&kid);
    while (!stack.empty()) {
        Spec* spec = stack.back();
        stack.pop_back();
        auto found = spec->attrs.find("id");
        if (found != spec->attrs.end() && std::find(ids.begin(), ids.end(), found->second) != ids.end()) spec->hover = true;
        for (Spec& kid : spec->kids) stack.push_back(&kid);
    }
    structureMatchesFresh(c, doc, sheet, kids, what);
}

// A parent's children but its ::before and ::after removed and `subtrees` inserted between them, as removals and
// insertions (what WidgetRuntime makes of new children); true when each was taken.
static bool replaceKids(const litehtml::document::ptr& doc, const element::ptr& parent, const std::vector<element::ptr>& subtrees) {
    bool taken = true;
    {
        const litehtml::elements_list children = parent->children();
        for (const auto& child : children) {
            if (child->tag() != litehtml::__tag_before_ && child->tag() != litehtml::__tag_after_) taken = doc->remove_subtree(child) && taken;
        }
    }
    size_t index = 0;
    for (const auto& child : parent->children()) {
        if (child->tag() != litehtml::__tag_before_) break;
        index++;
    }
    for (const auto& subtree : subtrees) taken = doc->insert_subtree(parent, index++, subtree) && taken;
    return taken;
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

// VENDOR.md edits 16 and 18: a <button> reads nothing of its children, so structure inside one is patched in place.
static void testStructureInsideAButton() {
    const char* sheet = "";
    std::vector<Spec> kids = {el("button", "go", {{"id", "b"}}), el("p", "after")};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    auto button = doc->root()->select_one("#b");
    CHECK(button != nullptr);
    if (!button) return;
    auto span = build(doc, el("span", "s"));
    CHECK(doc->can_insert_subtree(button, button->children().size(), span));
    CHECK(doc->insert_subtree(button, button->children().size(), span));
    kids[0].kids.push_back(el("span", "s"));
    structureMatchesFresh(c, doc, sheet, kids, "a span into a button");
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
    refuseInsert("a div holding a <select>", "", {}, el("div", "", {}, {el("select")}));
    refuseInsert("a <body>", "", {}, el("body", "x"));
    refuseRemove("the <select>", "", 1);
    // Inside <select> and a form control (an svg replaces itself: testStructureInsideAnSvg).
    refuseInsert("an <option> into the <select>", "", {1}, el("option", "p"));
    refuseInsert("a span into the <option>", "", {1, 0}, el("span", "p"));
    // What the parent's own appendChild refuses: a <table> takes tbody, thead, tfoot and caption only.
    const std::vector<Spec> table = {el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "c")})})})};
    refuseInsert("a tr into the table", "", {0}, el("tr", "", {}, {el("td", "d")}), &table);
    // A form control's parts' content, brought by the subtree, is no refusal (edit 84: the commit's replay makes it where a
    // build does).
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "lh-range-thumb::after{content:'x'}", plain, body);
        CHECK(doc->insert_subtree(body, 0, build(doc, el("input", "", {{"type", "range"}}))));
        std::vector<Spec> next = plain;
        next.insert(next.begin(), el("input", "", {{"type", "range"}}));
        structureMatchesFresh(c, doc, "lh-range-thumb::after{content:'x'}", next, "an input with an lh-* part rule");
    }
    // The same sheets let what they do not reach through.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", table, body);
        CHECK(doc->can_insert_subtree(childAt(body, 0), 1, build(doc, el("tbody", "", {}, {el("tr", "", {}, {el("td", "d")})}))));
        CHECK(doc->can_insert_subtree(childAt(body, 0), 0, build(doc, el("caption", "c"))));
    }
    for (const char* sheet : {"q::before{content:'x'}", "p::before{content:'x'}", "lh-range-thumb::after{content:'x'}",
                              "p::before{color:red}", "p{counter-increment:x}", "div{counter-increment:x}"}) {
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

// 5,000 words: 9,999 text pieces, a document's text cap less one.
static std::string capWords() {
    std::string words;
    for (int n = 0; n < 5000; n++) words += n ? " w" : "w";
    return words;
}

// VENDOR.md edits 18 and 19: structure beside ::before/::after content is patched; the content of what a patch inserts
// is made by the commit's match, in the inserted element's place, as a fresh build makes it.
static void testStructureBesidePseudoContent() {
    const char* sheet = "p::before{content:'x'} p{margin:1px}";
    const std::vector<Spec> base = {el("p", "one"), el("div", "two"), el("p", "three")};
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = base;
        auto doc = structureDocument(c, sheet, kids, body);
        auto sub = build(doc, el("p", "new"));
        CHECK(doc->can_insert_subtree(body, 1, sub));
        CHECK(doc->insert_subtree(body, 1, sub));
        kids.insert(kids.begin() + 1, el("p", "new"));
        structureMatchesFresh(c, doc, sheet, kids, "a <p> inserted beside ::before content");
    }
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = base;
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->can_remove_subtree(childAt(body, 0)));
        CHECK(doc->remove_subtree(childAt(body, 0)));
        kids.erase(kids.begin());
        structureMatchesFresh(c, doc, sheet, kids, "a <p> removed beside ::before content");
    }
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, base, body);
        const std::vector<Spec> kids = {el("div", "a"), el("p", "b"), el("p", "c")};
        std::vector<element::ptr> built;
        for (const Spec& kid : kids) built.push_back(build(doc, kid));
        CHECK(replaceKids(doc, body, built));
        structureMatchesFresh(c, doc, sheet, kids, "the body's children replaced beside ::before content");
    }
    {
        // The master sheet's summary::before, brought by the subtree into a document with no <summary>.
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = base;
        auto doc = structureDocument(c, sheet, kids, body);
        const Spec details = el("details", "", {}, {el("summary", "s"), el("p", "d")});
        auto sub = build(doc, details);
        CHECK(doc->can_insert_subtree(body, 2, sub));
        CHECK(doc->insert_subtree(body, 2, sub));
        kids.insert(kids.begin() + 2, details);
        structureMatchesFresh(c, doc, sheet, kids, "a <summary> inserted (the master sheet's ::before)");
    }
    {
        const char* words = "p::before{content:'a b c'}";
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = base;
        auto doc = structureDocument(c, words, kids, body);
        auto sub = build(doc, el("p", "new"));
        CHECK(doc->can_insert_subtree(body, 3, sub));
        CHECK(doc->insert_subtree(body, 3, sub));
        kids.push_back(el("p", "new"));
        structureMatchesFresh(c, doc, words, kids, "a <p> inserted under several-piece ::before content");
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
        // Past the cap: inserted, and the replacement cuts the cells as a build does (edit 84).
        auto wide = build(doc, el("td", "w", {{"colspan", "1000"}, {"rowspan", "200"}}));
        CHECK(doc->can_insert_subtree(tr, 1, wide));
        CHECK(doc->insert_subtree(tr, 1, wide));
        kids[0].kids[0].kids[0].kids.push_back(el("td", "w", {{"colspan", "1000"}, {"rowspan", "200"}}));
        structureMatchesFresh(c, doc, "", kids, "past the cell cap");
        CHECK(doc->remove_subtree(wide));
        wide.reset();   // the piece count compares what the documents hold
        kids[0].kids[0].kids[0].kids.pop_back();
        CHECK(doc->insert_subtree(tr, 1, build(doc, el("td", "w", {{"colspan", "1000"}, {"rowspan", "199"}}))));
        kids[0].kids[0].kids[0].kids.push_back(el("td", "w", {{"colspan", "1000"}, {"rowspan", "199"}}));
        structureMatchesFresh(c, doc, "", kids, "near the cell cap");
        CHECK(doc->table_cells() == 199001);
    }
}

// Under sibling combinators and positional pseudo-classes, insert_subtree and remove_subtree are taken, the siblings a rule
// can reach matched again in place (edit 90): an item whose box does not change keeps its render item, one whose box the
// match changes is a seed. New children keep the generated content where it is.
static void testStructureUnderPositionalSelectorsMatchesFresh() {
    const char* sheet = "li:nth-child(2n){color:#f00;background:#eee} li + li{margin-top:3px} .x ~ li{font-weight:bold}"
                        " li:last-child{background:#0f0} li:first-child span{color:#00f}";
    std::vector<Spec> kids = {el("ul", "", {}, {el("li", "", {}, {el("span", "a")}), el("li", "b", {{"class", "x"}}), el("li", "c")})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    CHECK(doc->structure_reaches_siblings());
    auto ul = childAt(body, 0);
    CHECK(doc->can_insert_subtree(ul, 0, build(doc, el("li", "n"))));
    CHECK(doc->can_remove_subtree(childAt(ul, 0)));
    std::vector<Spec> next = {el("li", "n"), el("li", "", {}, {el("span", "a")}), el("li", "b", {{"class", "x"}}), el("li", "c"),
                              el("li", "", {}, {el("span", "d")})};
    std::vector<element::ptr> built;
    for (const Spec& spec : next) built.push_back(build(doc, spec));
    CHECK(replaceKids(doc, ul, built));
    built.clear();   // the piece count compares what the documents hold
    kids[0].kids = next;
    structureMatchesFresh(c, doc, sheet, kids, "new children under positional selectors");
    // Down to one item, then none.
    CHECK(replaceKids(doc, ul, {build(doc, el("li", "only"))}));
    kids[0].kids = {el("li", "only")};
    structureMatchesFresh(c, doc, sheet, kids, "one item left");
    CHECK(replaceKids(doc, ul, {}));
    kids[0].kids = {};
    structureMatchesFresh(c, doc, sheet, kids, "no item left");
    // And under counters (edit 78).
    const char* countedSheet = "ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n) '. '}";
    std::vector<Spec> countedKids = {el("ol", "", {}, {el("li", "a"), el("li", "b"), el("li", "c")})};
    PaintContainer cc;
    element::ptr body2;
    auto counted = structureDocument(cc, countedSheet, countedKids, body2);
    CHECK(replaceKids(counted, childAt(body2, 0), {build(counted, el("li", "x")), build(counted, el("li", "y"))}));
    countedKids[0].kids = {el("li", "x"), el("li", "y")};
    structureMatchesFresh(cc, counted, countedSheet, countedKids, "an ordered list's items replaced");
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
    // the last divs uncoloured; a patch that matched in a session of its own would colour an appended div. A session
    // limited to what the build left colours nothing, as the fresh build of the final document does not colour its last
    // div.
    {
        PaintContainer c;
        element::ptr body;
        int64_t used = 0;
        auto doc = stepDocument(c, 1000, 4099, body, used);
        CHECK(used > litehtml::document::default_selector_steps);
        const int built = coloured(body);
        CHECK(built < 4099 && built > 3900);
        auto div = build(doc, el("div", "last"));
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
        // A patch session the caller opened no budget for opens its own (4,000,000): the appended div is coloured. A cut
        // boot's first commit replays the style pass uncut (note_match_cut, testACutBootReplaysAtItsFirstCommit).
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

// Telegram (VENDOR.md edit 84): a boot whose matching litehtml's budget cut (note_match_cut) replays the style pass at
// its first commit, whatever the session changed, within the replay's limit: the patched document is matched as an uncut
// build's. The mark goes with that replay: the next commit replays nothing.
static void testACutBootReplaysAtItsFirstCommit() {
    PaintContainer c;
    element::ptr body;
    int64_t used = 0;
    auto doc = stepDocument(c, 1000, 4099, body, used);
    CHECK(used > litehtml::document::default_selector_steps);
    CHECK(coloured(body) < 4099);
    doc->note_match_cut();
    const uint64_t replays = doc->generated_replays();
    // A text replaced by the same text: it matches nothing.
    element::ptr first = body->children().front();
    std::vector<element::ptr> pieces;
    doc->begin_selector_steps(int64_t(1) << 60);
    CHECK(doc->replace_text(first, 0, first->children().size(), "x", pieces));
    doc->commit_patch();
    doc->end_selector_steps();
    doc->render(litehtml::pixel_t(300.0f));
    CHECK(doc->generated_replays() == replays + 1);
    CHECK(coloured(body) == 4099);
    PaintContainer cf;
    element::ptr bodyf;
    int64_t usedf = 0;
    auto fresh = stepDocument(cf, 1000, 4099, bodyf, usedf, int64_t(1) << 60);
    CHECK(dump_of(doc) == dump_of(fresh));
    CHECK(painted(c, doc) == painted(cf, fresh));
    doc->begin_selector_steps(int64_t(1) << 60);
    CHECK(doc->replace_text(first, 0, first->children().size(), "x", pieces));
    doc->commit_patch();
    doc->end_selector_steps();
    CHECK(doc->generated_replays() == replays + 1);
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
    // subtree_replaced's (old, new).
    std::vector<std::pair<const litehtml::render_item*, const litehtml::render_item*>> replaced;
    // subtree_linked's and subtree_unlinked's items (edit 89).
    std::vector<const litehtml::render_item*> linked, unlinked;
    void item_added(const std::shared_ptr<litehtml::render_item>& item) override { added.insert(item.get()); }
    void item_removed(const litehtml::render_item* item) override { removed.insert(item); }
    void item_geometry_changed(const litehtml::render_item* item, unsigned what) override { geometry[item] |= what; }
    void element_restyled(const litehtml::element* el, bool paint_order) override { restyled.push_back({el, paint_order}); }
    void text_replaced(const litehtml::render_item* inline_context) override { texts.insert(inline_context); }
    void subtree_replaced(const litehtml::render_item* old_item, const std::shared_ptr<litehtml::render_item>& new_item) override {
        replaced.push_back({old_item, new_item.get()});
    }
    void subtree_linked(const std::shared_ptr<litehtml::render_item>& item) override { linked.push_back(item.get()); }
    void subtree_unlinked(const litehtml::render_item* item) override { unlinked.push_back(item); }
    void clear() {
        added.clear(), removed.clear(), texts.clear(), geometry.clear(), restyled.clear(), replaced.clear();
        linked.clear(), unlinked.clear();
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
        CHECK(observer.restyled.size() == 1 && observer.restyled[0].first == div.get() && !observer.restyled[0].second);
        checkReports(doc, observer, before, was, "class patch");
        CHECK(observer.added.empty() && observer.removed.empty());
        observer.clear();
        const auto before2 = renderItems(doc);
        const auto was2 = geometryOf(before2);
        CHECK(doc->set_element_attribute(div, "class", "b o"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.restyled.size() == 1 && observer.restyled[0].first == div.get() && observer.restyled[0].second);
        checkReports(doc, observer, before2, was2, "opacity class patch");
        doc->set_render_observer(nullptr);
    }
    // A block appended to the body is linked (edit 89: subtree_linked), and a style patch that changes a box replaces a
    // render subtree (edit 74: subtree_replaced); neither gives per-item reports.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("p", "one"), el("div", "x")}, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->insert_subtree(body, body->children().size(), build(doc, el("p", "appended"))));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.replaced.empty() && observer.linked.size() == 1);
        CHECK(observer.added.empty() && observer.removed.empty());
        observer.clear();
        CHECK(doc->set_element_attribute(childAt(body, 1), "style", "float:left"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(observer.replaced.size() == 1);
        doc->set_render_observer(nullptr);
    }
    // Edit 63: a style patch of a box's geometry alone keeps the render tree, and the layout reports every box it moved
    // or resized, the ones after it included.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("p", "one"), el("div", "x"), el("p", "two")}, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        const auto before = renderItems(doc);
        const auto was = geometryOf(before);
        CHECK(doc->set_element_attribute(childAt(body, 1), "style", "padding:4px"));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        checkReports(doc, observer, before, was, "padding style patch");
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
        LimitContainer c;
        auto doc = litehtml::document::createFromString(litehtml::estring(css + body), &c, litehtml::telegram_master_css());
        doc->render(litehtml::pixel_t(300.0f));
        CHECK(c.limits.empty() && !doc->style_bytes_limited());
        CHECK(doc->style_bytes_charged() <= litehtml::document::max_style_bytes / 2);
        const litehtml::elements_list bs = doc->root()->select_all("b");
        // One shared string: the copies cost a pointer each. (A heap reading moves by megabytes with what earlier tests
        // allocated, so the sharing itself is checked.)
        const char* shared = nullptr;
        size_t holders = 0;
        bool one = true;
        for (const auto& b : bs) {
            const std::string& image = b->css().get_list_style_image();
            if (image.empty()) continue;
            holders++;
            shared = shared ? shared : image.data();
            one = one && image.data() == shared;
        }
        std::printf("inherited url over 9000 elements: %zu list items hold it, %zu bytes charged\n", holders,
                    doc->style_bytes_charged());
        CHECK(holders > 1 && one);
        CHECK(!bs.empty() && bs.front()->css().get_list_style_image() == url);
        CHECK(!bs.empty() && bs.back()->css().get_list_style_image().empty());
    }
}

// Edits 74, 89: after the boot the render tree is never re-created: a block inserted into the body is linked in place
// (subtree_linked) and a viewport change replaces a render subtree in place (subtree_replaced).
static void testAfterTheBootSubtreesAreReplaced() {
    const char* sheet = "@media (max-width:260px){p{display:none}}";
    std::vector<Spec> kids = {el("p", "one"), el("div", "two")};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    CHECK(doc->insert_subtree(body, 0, build(doc, el("p", "new"))));
    kids.insert(kids.begin(), el("p", "new"));
    structureMatchesFresh(c, doc, sheet, kids, "an insert");
    CHECK(observer.replaced.empty() && observer.linked.size() == 1);
    observer.clear();
    c.width = 250;
    CHECK(doc->viewport_changed());
    structureMatchesFresh(c, doc, sheet, kids, "a media query flipped", 250);
    CHECK(observer.replaced.size() == 1);
    CHECK(!observer.replaced.empty() && observer.replaced[0].second == doc->root_render().get());
    // The replaced items leave their elements: an element answers its new item, not the old one, nor null once the old
    // one is gone.
    CHECK(doc->root()->get_render_item() == doc->root_render());
    doc->set_render_observer(nullptr);
}

// Edit 74: a patch replaces the render subtree of its nearest boundary, and keeps every render item outside it; edit 89:
// a block inserted into a block links alone, so its parent keeps its item too.
static element::ptr byId(const element::ptr& root, const char* id) {
    const char* own = root->get_attr("id");
    if (own && std::strcmp(own, id) == 0) return root;
    for (const auto& child : root->children()) {
        if (auto found = byId(child, id)) return found;
    }
    return nullptr;
}

static bool inTree(const litehtml::document::ptr& doc, const std::shared_ptr<litehtml::render_item>& item) {
    auto top = item;
    while (top && top->parent()) top = top->parent();
    return top && top == doc->root_render();
}

static void reasonIs(const litehtml::document::ptr& doc, const std::string& expected, const char* what);

// What the boundary is: the element whose new item subtree_replaced reported, "root", or "" for no replacement.
static std::string replacedAt(const litehtml::document::ptr& doc, const RecordingObserver& observer) {
    if (observer.replaced.empty()) return "";
    const litehtml::render_item* item = observer.replaced.back().second;
    if (item == doc->root_render().get()) return "root";
    const char* id = item->src_el()->get_attr("id");
    return id ? id : "?";
}

static void testStructurePatchKeepsTheTreeOutsideItsBoundary() {
    std::vector<Spec> kids = {el("div", "", {{"id", "a"}}, {el("p", "a")}), el("div", "", {{"id", "b"}}, {el("p", "b")})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    auto a = byId(body, "a"), b = byId(body, "b");
    // Held, so that an item made again cannot take a kept one's address.
    const std::shared_ptr<litehtml::render_item> root = doc->root_render();
    const std::shared_ptr<litehtml::render_item> aItem = doc->live_item(*a), bItem = doc->live_item(*b);
    CHECK(aItem != nullptr && bItem != nullptr);
    CHECK(doc->insert_subtree(b, 1, build(doc, el("p", "new"))));
    kids[1].kids.push_back(el("p", "new"));
    structureMatchesFresh(c, doc, "", kids, "an insert into #b");
    CHECK(doc->root_render() == root);
    CHECK(doc->live_item(*a) == aItem);
    CHECK(doc->live_item(*b) == bItem);
    CHECK(observer.replaced.empty() && observer.linked.size() == 1);
    doc->set_render_observer(nullptr);
}

// WidgetRuntime's structure flush replaces a kept Text's pieces in the session of its insertions and removals, after
// them (RenderTree::flushStructure). In another parent the run is replaced in place and its inline context kept; in its
// own parent, whose children the session changed, the parent is a seed (edit 74). Each equals a fresh build.
static void testReplaceTextBesideStructure() {
    {
        std::vector<Spec> kids = {el("div", "", {{"id", "a"}}, {el("p", "one two", {{"id", "t"}})}),
                                  el("div", "", {{"id", "b"}}, {el("p", "x")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", kids, body);
        auto t = byId(body, "t"), b = byId(body, "b");
        // Held, so that an item made again cannot take the kept one's address.
        const std::shared_ptr<litehtml::render_item> tItem = doc->live_item(*t);
        CHECK(tItem != nullptr);
        CHECK(doc->remove_subtree(b->children().front()));
        CHECK(doc->insert_subtree(b, 0, build(doc, el("p", "y"))));
        std::vector<element::ptr> made;
        CHECK(doc->replace_text(t, 0, t->children().size(), "three four five", made));
        kids[1].kids = {el("p", "y")};
        kids[0].kids[0].text = "three four five";
        structureMatchesFresh(c, doc, "", kids, "a text beside structure in another parent");
        CHECK(doc->live_item(*t) == tItem);
    }
    {
        // An insertion before the run, at its first piece's place.
        std::vector<Spec> kids = {el("p", "", {{"id", "t"}}, {txt("one "), el("b", "x")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", kids, body);
        auto t = byId(body, "t");
        CHECK(doc->insert_subtree(t, 0, build(doc, el("span", "s"))));
        std::vector<element::ptr> made;
        CHECK(doc->replace_text(t, 1, 2, "uno dos", made));
        kids[0].kids = {el("span", "s"), txt("uno dos"), el("b", "x")};
        structureMatchesFresh(c, doc, "", kids, "a text after an insertion before it");
    }
    {
        // Its sibling removed.
        std::vector<Spec> kids = {el("p", "", {{"id", "t"}}, {txt("one "), el("b", "x", {{"id", "x"}})})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", kids, body);
        auto t = byId(body, "t");
        CHECK(doc->remove_subtree(byId(body, "x")));
        std::vector<element::ptr> made;
        CHECK(doc->replace_text(t, 0, 2, "uno dos", made));
        kids[0].kids = {txt("uno dos")};
        structureMatchesFresh(c, doc, "", kids, "a text beside its removed sibling");
    }
}

static void testReplacementBoundaries() {
    struct Case {
        const char* name;
        const char* sheet;
        std::vector<Spec> kids;
        // Patches the document and the specs alike; true when the patch was taken.
        std::function<bool(const litehtml::document::ptr&, const element::ptr&, std::vector<Spec>&, PaintContainer&)> patch;
        const char* boundary;
        int width;
    };
    std::vector<Case> cases = {
        {"a <b> inside a <span> inside #p", "",
         {el("p", "", {{"id", "p"}}, {txt("t "), el("span", "", {{"id", "s"}}, {el("b", "x")})})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[1].kids.push_back(el("b", "y"));
             return doc->insert_subtree(byId(body, "s"), 1, build(doc, el("b", "y")));
         },
         "p", 300},
        {"a <div> made inline inside #s", "",
         {el("section", "", {{"id", "s"}}, {el("div", "d", {{"id", "d"}}), el("p", "after")})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].attrs["style"] = "display:inline";
             return doc->set_element_attribute(byId(body, "d"), "style", "display:inline");
         },
         "s", 300},
        {"a row appended to a <tbody> in #t", "",
         {el("table", "", {{"id", "t"}}, {el("tbody", "", {{"id", "b"}}, {el("tr", "", {}, {el("td", "c1")})})})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].kids.push_back(el("tr", "", {}, {el("td", "c2")}));
             return doc->insert_subtree(byId(body, "b"), 1, build(doc, el("tr", "", {}, {el("td", "c2")})));
         },
         "t", 300},
        {"a circle's cx in #g", "",
         {el("svg", "", {{"id", "g"}, {"width", "40"}, {"height", "40"}},
             {el("circle", "", {{"id", "c"}, {"cx", "20"}, {"cy", "20"}, {"r", "10"}})})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].attrs["cx"] = "25";
             return doc->set_element_attribute(byId(body, "c"), "cx", "25");
         },
         "g", 300},
        {"a <p> appended under display:none", "",
         {el("div", "", {{"id", "h"}, {"style", "display:none"}}, {el("p", "x")}), el("p", "shown")},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids.push_back(el("p", "y"));
             return doc->insert_subtree(byId(body, "h"), 1, build(doc, el("p", "y")));
         },
         "", 300},
        // An SVG element under an element that renders nothing is not dropped: a <use> or url(#…) anywhere can draw it.
        {"a circle in a hidden svg", "",
         {el("div", "", {{"id", "w"}}, {el("svg", "", {{"style", "display:none"}}, {el("circle", "", {{"id", "c"}, {"r", "4"}})})}),
          el("p", "after")},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].kids[0].attrs["r"] = "9";
             return doc->set_element_attribute(byId(body, "c"), "r", "9");
         },
         "w", 300},
        // A replaced element displayed as a table part is held by the table's grid: the table is the boundary.
        {"an img displayed as a table cell", "",
         {el("div", "", {{"id", "t"}, {"style", "display:table"}},
             {el("div", "", {{"style", "display:table-row"}},
                 {el("img", "", {{"id", "i"}, {"style", "display:table-cell"}, {"src", "data:a"}})})})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].kids[0].attrs["src"] = "data:b";
             return doc->set_element_attribute(byId(body, "i"), "src", "data:b");
         },
         "t", 300},
        // A flex item that is not a block box (compute_flex blockifies the others, not inline-grid) sits in an anonymous
        // block made from it, which inherits its style and is not in its subtree: the flex container is the boundary.
        {"an inline-grid flex item's font size", ".big{font-size:28px}",
         {el("div", "", {{"id", "f"}, {"style", "display:flex;flex-direction:column"}},
             {el("span", "k", {{"id", "k"}, {"style", "display:inline-grid;height:20px"}})})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].attrs["class"] = "big";
             return doc->set_element_attribute(byId(body, "k"), "class", "big");
         },
         "f", 300},
        // A document with an <svg> drops no seed under an element that renders nothing: a <use> or url(#…) can draw an
        // SVG element that the session moved into, out of, or under it.
        {"a <p> under display:none beside an svg", "",
         {el("div", "", {{"id", "w"}}, {el("div", "", {{"id", "h"}, {"style", "display:none"}}, {el("p", "x")})}),
          el("svg", "", {{"width", "10"}, {"height", "10"}})},
         [](auto doc, auto body, auto& kids, auto&) {
             kids[0].kids[0].kids.push_back(el("p", "y"));
             return doc->insert_subtree(byId(body, "h"), 1, build(doc, el("p", "y")));
         },
         "w", 300},
        {"a media query flipped", "@media (max-width:260px){p{display:none}}", {el("p", "one"), el("div", "two")},
         [](auto doc, auto, auto&, PaintContainer& c) {
             c.width = 250;
             return doc->viewport_changed();
         },
         "root", 250},
    };
    for (Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, k.kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(k.patch(doc, body, k.kids, c));
        structureMatchesFresh(c, doc, k.sheet, k.kids, k.name, k.width);
        const std::string at = replacedAt(doc, observer);
        if (at != k.boundary) std::printf("  %s: replaced at \"%s\", want \"%s\"\n", k.name, at.c_str(), k.boundary);
        CHECK(at == k.boundary);
        CHECK(*k.boundary || doc->rebuild_reason().empty());
        doc->set_render_observer(nullptr);
    }
}

static void testReplacedItemsLeaveTheirElements() {
    std::vector<Spec> kids = {el("div", "", {{"id", "a"}}, {el("p", "a")}),
                              el("div", "", {{"id", "b"}}, {el("p", "b one"), el("p", "", {}, {txt("b "), el("i", "two")})})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    auto b = byId(body, "b");
    CHECK(doc->insert_subtree(b, 0, build(doc, el("p", "new"))));
    doc->commit_patch();
    const auto everyElement = [&](const char* when) {
        std::vector<element::ptr> pending{b};
        while (!pending.empty()) {
            auto e = pending.back();
            pending.pop_back();
            auto item = e->get_render_item();
            if (!item || !inTree(doc, item)) std::printf("  %s: an element of #b answers %s\n", when, item ? "an old item" : "no item");
            CHECK(item && inTree(doc, item));
            for (const auto& child : e->children()) pending.push_back(child);
        }
    };
    everyElement("before the layout");
    doc->render(litehtml::pixel_t(200.0f));
    everyElement("after the layout");
    CHECK(b->get_render_item() == doc->live_item(*b));
}

static void testReplacementGivesBackTableCells() {
    std::vector<Spec> rows;
    for (int r = 0; r < 3; r++) rows.push_back(el("tr", "", {}, {el("td", "1"), el("td", "2"), el("td", "3"), el("td", "4")}));
    std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("table", "", {{"id", "t"}}, {el("tbody", "", {}, rows)})}),
                              el("p", "after")};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    const int before = doc->table_cells();
    CHECK(doc->remove_subtree(byId(body, "t")));
    kids[0].kids.clear();
    structureMatchesFresh(c, doc, "", kids, "a table removed");
    CHECK(doc->table_cells() == before - 12);
    CHECK(replacedAt(doc, observer) == "w");
    doc->set_render_observer(nullptr);
}

// A table in an inline-grid flex item is made twice (the flex wrapper inits the item again) and takes its cells twice,
// as a fresh build does: a replacement gives all of them back, so the count does not drift.
static void testReplacementGivesBackTableCellsUnderFlex() {
    std::vector<Spec> rows;
    for (int r = 0; r < 3; r++) rows.push_back(el("tr", "", {}, {el("td", "1"), el("td", "2"), el("td", "3"), el("td", "4")}));
    std::vector<Spec> kids = {el("div", "", {{"id", "row"}, {"style", "display:flex"}},
                                 {el("div", "", {{"style", "display:inline-grid"}}, {el("table", "", {}, {el("tbody", "", {}, rows)})})}),
                              el("p", "after")};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    const int before = doc->table_cells();
    for (int round = 0; round < 3; round++) {
        auto row = byId(body, "row");
        CHECK(doc->insert_subtree(row, row->children().size(), build(doc, el("p", "in"))));
        kids[0].kids.push_back(el("p", "in"));
        structureMatchesFresh(c, doc, "", kids, "a paragraph into the flex row");
        CHECK(doc->remove_subtree(childAt(row, row->children().size() - 1)));
        kids[0].kids.pop_back();
        structureMatchesFresh(c, doc, "", kids, "the paragraph out of the flex row");
    }
    if (doc->table_cells() != before) std::printf("  table cells %d, %d at the boot\n", doc->table_cells(), before);
    CHECK(doc->table_cells() == before);
}

// The boundary walk and the splice are linear in what they touch (review C1): a session that seeds a thousand siblings
// under a 200-deep chain walks each ancestor once, not once per pair of boundaries.
static void testReplacementWalksAreLinear() {
    std::vector<Spec> leaves;
    for (int n = 0; n < 1000; n++) leaves.push_back(el("div", "l"));
    Spec chain = el("div", "", {{"id", "deep"}}, leaves);
    for (int d = 0; d < 200; d++) chain = el("div", "", {}, {chain});
    std::vector<Spec> kids = {chain};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    auto deep = byId(body, "deep");
    const uint64_t walked = doc->replacement_steps();
    for (const auto& leaf : deep->children()) CHECK(doc->set_element_attribute(leaf, "data-x", "1"));
    doc->commit_patch();
    const uint64_t steps = doc->replacement_steps() - walked;
    std::printf("  replacement steps for 1000 seeds under 200 ancestors: %llu\n", (unsigned long long)steps);
    CHECK(steps <= 20000);
}

// A replacement that moves the table-cell cap's cut makes the root's replacement too: the observer hears the root's
// alone, as edit 74's event order says (Step 2's review, M1). An element with large spans becomes a cell by its class:
// the spans did not change, so can_set_element_attributes lets it through, and its cell passes the cap.
static void testACapCrossingReplacementReportsTheRootAlone() {
    const char* sheet = ".cell{display:table-cell}";
    std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("div", "x", {{"id", "c"}, {"colspan", "1000"}, {"rowspan", "1000"}})})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    CHECK(doc->set_element_attribute(byId(body, "c"), "class", "cell"));
    kids[0].kids[0].attrs["class"] = "cell";
    structureMatchesFresh(c, doc, sheet, kids, "a cell past the cap by its class");
    if (observer.replaced.size() != 1) std::printf("  %zu replacements reported\n", observer.replaced.size());
    CHECK(observer.replaced.size() == 1 && observer.replaced[0].second == doc->root_render().get());
    CHECK(std::count(c.limits.begin(), c.limits.end(), std::string("table")) == 1);
    doc->set_render_observer(nullptr);
}

// A document a build cut at the table-cell cap: any replacement is the root's, which counts the cells in tree order as
// a build does.
static void testReplacementAtTheTableCellCap() {
    std::vector<Spec> kids = {
        el("div", "", {{"id", "w"}}, {el("p", "w")}),
        el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "a", {{"colspan", "1000"}, {"rowspan", "199"}})})})}),
        el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "b", {{"colspan", "1000"}, {"rowspan", "2"}})})})}),
    };
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    CHECK(std::count(c.limits.begin(), c.limits.end(), std::string("table")) == 1);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    CHECK(doc->insert_subtree(byId(body, "w"), 1, build(doc, el("p", "new"))));
    kids[0].kids.push_back(el("p", "new"));
    structureMatchesFresh(c, doc, "", kids, "an insert beside tables cut at the cap");
    CHECK(replacedAt(doc, observer) == "root");
    reasonIs(doc, "structure: insert: at the table-cell cap", "an insert beside tables cut at the cap");
    doc->set_render_observer(nullptr);
}

// Review Focus 1: an inline-block in a line of text is its own boundary; its line points at the old item until the next
// layout, which places the new one.
static void testAnInlineBoxInALineIsReplacedInPlace() {
    const char* sheet = ".big{font-size:30px}";
    std::vector<Spec> kids = {el("p", "", {{"id", "p"}},
                                 {txt("text "), el("span", "k", {{"id", "k"}, {"style", "display:inline-block"}}), txt(" more text")})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    CHECK(doc->set_element_attribute(byId(body, "k"), "class", "big"));
    kids[0].kids[1].attrs["class"] = "big";
    structureMatchesFresh(c, doc, sheet, kids, "an inline-block's font size");
    CHECK(replacedAt(doc, observer) == "k");
    doc->set_render_observer(nullptr);
}

// Review Focus 2: a positioned descendant beside a linked block (edit 89), whose containing block is outside its parent.
static void testAPositionedDescendantFollowsItsContainingBlock() {
    std::vector<Spec> kids = {el("div", "", {{"style", "position:relative;padding:10px"}},
                                 {el("div", "", {{"id", "b"}},
                                     {el("span", "abs", {{"id", "a"}, {"style", "position:absolute;left:5px;top:7px"}})})})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    CHECK(doc->insert_subtree(byId(body, "b"), 1, build(doc, el("p", "new"))));
    kids[0].kids[0].kids.push_back(el("p", "new"));
    structureMatchesFresh(c, doc, "", kids, "a block appended beside a positioned span");
    CHECK(observer.replaced.empty() && observer.linked.size() == 1);
    auto span = byId(body, "a");
    const litehtml::position box = span->get_render_item()->get_placement();
    const litehtml::pixel_t x = box.x + 1, y = box.y + 1;
    auto hit = doc->root_render()->get_element_by_point(x, y, x, y, nullptr);
    bool onSpan = false;
    for (auto e = hit; e; e = e->parent()) onSpan = onSpan || e == span;
    CHECK(onSpan);
    doc->set_render_observer(nullptr);
}

// Review Focus 3: an item inserted into or removed from an ordered list numbers the items after it again.
static void testListItemsAreNumberedAgain() {
    std::vector<Spec> kids = {el("ol", "", {{"id", "o"}, {"start", "3"}},
                                 {el("li", "one"), el("li", "two"), el("li", "three"), el("li", "four")})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    auto list = byId(body, "o");
    CHECK(doc->insert_subtree(list, 1, build(doc, el("li", "inserted"))));
    kids[0].kids.insert(kids[0].kids.begin() + 1, el("li", "inserted"));
    structureMatchesFresh(c, doc, "", kids, "an item inserted");
    CHECK(observer.replaced.empty() && observer.linked.size() == 1);
    observer.clear();
    CHECK(doc->remove_subtree(childAt(list, 2)));
    kids[0].kids.erase(kids[0].kids.begin() + 2);
    structureMatchesFresh(c, doc, "", kids, "an item removed");
    CHECK(observer.replaced.empty() && observer.unlinked.size() == 1);
    doc->set_render_observer(nullptr);
}

// Review Focus 4: seeds in one session. Text replaced in place beside a block linked into its parent (edit 89); two
// seeds whose boundaries nest (inline content inserted beside blocks, which is not linked) give one replacement, the
// outer one.
static void testSeedsInOneSession() {
    {
        std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("p", "old text", {{"id", "t"}})})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        auto t = byId(body, "t");
        std::vector<element::ptr> made;
        CHECK(doc->replace_text(t, 0, t->children().size(), "new words here", made));
        CHECK(doc->insert_subtree(byId(body, "w"), 1, build(doc, el("p", "appended"))));
        kids[0].kids[0].text = "new words here";
        kids[0].kids.push_back(el("p", "appended"));
        structureMatchesFresh(c, doc, "", kids, "text then structure in one session");
        CHECK(observer.replaced.empty() && observer.linked.size() == 1);
        doc->set_render_observer(nullptr);
    }
    {
        std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("div", "", {{"id", "x"}}, {el("p", "x")}), el("p", "w")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->insert_subtree(byId(body, "x"), 1, build(doc, el("span", "into x"))));
        CHECK(doc->insert_subtree(byId(body, "w"), 0, build(doc, el("span", "into w"))));
        kids[0].kids[0].kids.push_back(el("span", "into x"));
        kids[0].kids.insert(kids[0].kids.begin(), el("span", "into w"));
        structureMatchesFresh(c, doc, "", kids, "nested seeds");
        CHECK(observer.replaced.size() == 1 && replacedAt(doc, observer) == "w");
        doc->set_render_observer(nullptr);
    }
}

// Edit 73: why a commit_patch, media_changed or viewport_changed re-created the render tree; "" when it kept it.
static void reasonIs(const litehtml::document::ptr& doc, const std::string& expected, const char* what) {
    if (doc->rebuild_reason() != expected)
        std::printf("  %s: rebuild reason \"%s\", want \"%s\"\n", what, doc->rebuild_reason().c_str(), expected.c_str());
    CHECK(doc->rebuild_reason() == expected);
}

static void testRebuildReasonsNameTheChange() {
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", {el("p", "one"), el("p", "two")}, body);
        // Edit 89: a block linked or unlinked replaces nothing; inline content beside blocks is refused, by name.
        CHECK(doc->insert_subtree(body, 0, build(doc, el("p", "new"))));
        doc->commit_patch();
        reasonIs(doc, "", "a block inserted");
        CHECK(doc->remove_subtree(childAt(body, 0)));
        doc->commit_patch();
        reasonIs(doc, "", "a block removed");
        CHECK(doc->insert_subtree(body, 1, build(doc, el("span", "s"))));
        doc->commit_patch();
        reasonIs(doc, "structure: insert: inline content", "a span inserted between blocks");
        CHECK(doc->remove_subtree(childAt(body, 1)));
        doc->commit_patch();
        reasonIs(doc, "structure: remove: inline content", "a span removed from between blocks");
    }
    const auto attribute = [](const char* sheet, const char* tag, litehtml::string_map attrs, const char* name, const char* value,
                              const char* expected, const char* what) {
        PaintContainer c;
        element::ptr target;
        auto doc = attrDocument(c, sheet, tag, attrs, target);
        CHECK(doc->set_element_attribute(target, name, value));
        doc->commit_patch();
        reasonIs(doc, expected, what);
    };
    attribute("", "circle", {{"cx", "20"}, {"cy", "20"}, {"r", "10"}}, "cx", "25", "attribute: cx", "a circle's cx");
    attribute("", "div", {}, "style", "display:none", "property: display", "an inline display");
    attribute(".abs{position:absolute}", "div", {}, "class", "abs", "rule: position", "a class whose rule positions");
    attribute("div::before{content:'x'} .k{color:#c00}", "div", {}, "class", "k", "pseudo-element children", "beside ::before");
    attribute("", "div", {}, "style", "color:#c00", "", "a paint-only inline style");
    // Two rules start matching, three properties neither paint-only nor geometry-only: the smallest name, whatever
    // order the rules come in (their selectors' addresses).
    attribute(".a{position:absolute} .b{z-index:2;float:left}", "div", {}, "class", "a b", "rule: float", "two rules");
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "@media (max-width:260px){p{display:none}}", {el("p", "one")}, body);
        c.width = 250;
        doc->viewport_changed();
        reasonIs(doc, "media", "a media query flipped");
    }
}

// The index of `parent`'s first child whose tag is `tag`.
static size_t indexOfTag(const element::ptr& parent, const char* tag) {
    size_t index = 0;
    for (const auto& child : parent->children()) {
        if (child->get_tagName() && std::strcmp(child->get_tagName(), tag) == 0) return index;
        index++;
    }
    return index;
}

// Edit 89: a block-level child inserted into or removed from a block formatting context is linked or unlinked alone:
// nothing is replaced, the parent and every other child keep their render items, an unlinked item is the removed
// element's own, and the patch equals a fresh build.
static void testBlockChildrenLinkAndUnlink() {
    struct Case {
        const char* name;
        std::vector<Spec> kids;
        const char* parent; // its id; "" for the body
        // Patches the document and the specs alike; true when the patch was taken. `removed` gets each element it
        // removes, before it removes it.
        std::function<bool(const litehtml::document::ptr&, const element::ptr&, std::vector<Spec>&, std::vector<element::ptr>&)> patch;
        size_t linked, unlinked;
    };
    std::vector<Case> cases = {
        {"a <p> between two <div>s of the body", {el("div", "a"), el("div", "b")}, "",
         [](auto doc, auto parent, auto& kids, auto&) {
             kids.insert(kids.begin() + 1, el("p", "new"));
             return doc->insert_subtree(parent, 1, build(doc, el("p", "new")));
         },
         1, 0},
        {"an <li> appended to a <ul> whose items newlines separate",
         {el("ul", "", {{"id", "u"}}, {txt("\n"), el("li", "a"), txt("\n"), el("li", "b"), txt("\n")})}, "u",
         [](auto doc, auto parent, auto& kids, auto&) {
             kids[0].kids.push_back(el("li", "c"));
             return doc->insert_subtree(parent, parent->children().size(), build(doc, el("li", "c")));
         },
         1, 0},
        {"a <p> after an inline run's end, before a block",
         {el("div", "", {{"id", "d"}}, {txt("one "), el("i", "two"), el("p", "x")})}, "d",
         [](auto doc, auto parent, auto& kids, auto&) {
             kids[0].kids.insert(kids[0].kids.begin() + 2, el("p", "new"));
             return doc->insert_subtree(parent, indexOfTag(parent, "p"), build(doc, el("p", "new")));
         },
         1, 0},
        {"the middle <div> of three removed", {el("div", "a"), el("div", "m", {{"id", "m"}}), el("div", "c")}, "",
         [](auto doc, auto parent, auto& kids, auto& removed) {
             kids.erase(kids.begin() + 1);
             removed.push_back(byId(parent, "m"));
             return doc->remove_subtree(removed.back());
         },
         0, 1},
        {"a <ul>'s items replaced", {el("ul", "", {{"id", "u"}}, {el("li", "a"), el("li", "b")})}, "u",
         [](auto doc, auto parent, auto& kids, auto& removed) {
             kids[0].kids = {el("li", "x"), el("li", "y"), el("li", "z")};
             for (const auto& child : parent->children()) removed.push_back(child);
             return replaceKids(doc, parent, {build(doc, el("li", "x")), build(doc, el("li", "y")), build(doc, el("li", "z"))});
         },
         3, 2},
        {"a <p> appended beside a float",
         {el("div", "", {{"id", "d"}}, {el("div", "f", {{"style", "float:left;width:20px"}}), el("p", "a")})}, "d",
         [](auto doc, auto parent, auto& kids, auto&) {
             kids[0].kids.push_back(el("p", "b"));
             return doc->insert_subtree(parent, parent->children().size(), build(doc, el("p", "b")));
         },
         1, 0},
    };
    for (Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", k.kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        auto parent = *k.parent ? byId(body, k.parent) : body;
        CHECK(parent != nullptr);
        if (!parent) continue;
        // Held, so that an item made again cannot take a kept one's address.
        const std::shared_ptr<litehtml::render_item> parentItem = doc->live_item(*parent);
        std::map<const element*, std::shared_ptr<litehtml::render_item>> before;
        for (const auto& child : parent->children()) before[child.get()] = doc->live_item(*child);
        std::vector<element::ptr> removed;
        CHECK(k.patch(doc, parent, k.kids, removed));
        // The removed elements let go (their pieces count while alive), their former items kept by address only.
        std::set<const litehtml::render_item*> formerItems;
        for (const auto& gone : removed) {
            auto was = before.find(gone.get());
            if (was == before.end()) continue;
            if (was->second) formerItems.insert(was->second.get());
            before.erase(was);
        }
        removed.clear();
        structureMatchesFresh(c, doc, "", k.kids, k.name);
        if (!observer.replaced.empty() || observer.linked.size() != k.linked || observer.unlinked.size() != k.unlinked)
            std::printf("  %s: %zu replaced, %zu linked, %zu unlinked (%s)\n", k.name, observer.replaced.size(),
                        observer.linked.size(), observer.unlinked.size(), doc->rebuild_reason().c_str());
        CHECK(observer.replaced.empty());
        CHECK(observer.linked.size() == k.linked);
        CHECK(observer.unlinked.size() == k.unlinked);
        CHECK(doc->rebuild_reason().empty());
        CHECK(doc->live_item(*parent) == parentItem);
        for (const auto& child : parent->children()) {
            auto kept = before.find(child.get());
            if (kept != before.end()) CHECK(doc->live_item(*child) == kept->second);
        }
        const std::set<const litehtml::render_item*> unlinked(observer.unlinked.begin(), observer.unlinked.end());
        CHECK(unlinked == formerItems);
        doc->set_render_observer(nullptr);
    }
}

// Edit 89: what is not linked yet is replaced as before (edit 74), under a reason naming the case.
static void testStructureRefusalsNameTheirCase() {
    struct Case {
        const char* name;
        std::vector<Spec> kids;
        std::function<bool(const litehtml::document::ptr&, const element::ptr&, std::vector<Spec>&)> patch;
        const char* reason;
        const char* boundary;
    };
    std::vector<Case> cases = {
        {"a <b> into a <p>", {el("p", "one", {{"id", "p"}})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("b", "x"));
             auto p = byId(body, "p");
             return doc->insert_subtree(p, p->children().size(), build(doc, el("b", "x")));
         },
         "structure: insert: in an inline context", "p"},
        {"a <span> between two <div>s", {el("div", "", {{"id", "d"}}, {el("div", "a"), el("div", "b")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.insert(kids[0].kids.begin() + 1, el("span", "s"));
             return doc->insert_subtree(byId(body, "d"), 1, build(doc, el("span", "s")));
         },
         "structure: insert: inline content", "d"},
        {"a <p> between the halves of a run", {el("div", "", {{"id", "d"}}, {txt("one "), el("i", "two"), el("p", "end")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.insert(kids[0].kids.begin() + 1, el("p", "x"));
             auto d = byId(body, "d");
             return doc->insert_subtree(d, indexOfTag(d, "i"), build(doc, el("p", "x")));
         },
         "structure: insert: inline content", "d"},
        {"the block between two runs removed",
         {el("div", "", {{"id", "d"}}, {txt("one"), el("p", "x", {{"id", "x"}}), txt("two"), el("p", "end")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.erase(kids[0].kids.begin() + 1);
             return doc->remove_subtree(byId(body, "x"));
         },
         "structure: remove: inline content", "d"},
        {"a removal that joins a space to a run",
         {el("div", "", {{"id", "d"}}, {txt("one"), el("p", "x", {{"id", "x"}}), txt(" "), el("p", "y")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.erase(kids[0].kids.begin() + 1);
             return doc->remove_subtree(byId(body, "x"));
         },
         "structure: remove: inline content", "d"},
        {"the last block removed beside text", {el("div", "", {{"id", "d"}}, {txt("one"), el("p", "x", {{"id", "x"}})})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.erase(kids[0].kids.begin() + 1);
             return doc->remove_subtree(byId(body, "x"));
         },
         "structure: remove: the formatting context flips", "d"},
        {"a <div> into a flex container", {el("div", "", {{"id", "f"}, {"style", "display:flex"}}, {el("div", "a")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("div", "b"));
             return doc->insert_subtree(byId(body, "f"), 1, build(doc, el("div", "b")));
         },
         "structure: insert: in a flex container", "f"},
        {"a <div> into a grid", {el("div", "", {{"id", "g"}, {"style", "display:grid"}}, {el("div", "a")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("div", "b"));
             return doc->insert_subtree(byId(body, "g"), 1, build(doc, el("div", "b")));
         },
         "structure: insert: in a grid", "g"},
        {"a floated <div>", {el("div", "", {{"id", "d"}}, {el("p", "a")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("div", "f", {{"style", "float:left;width:20px"}}));
             return doc->insert_subtree(byId(body, "d"), 1, build(doc, el("div", "f", {{"style", "float:left;width:20px"}})));
         },
         "structure: insert: a float or an out-of-flow box", "d"},
        {"an absolutely positioned <div>", {el("div", "", {{"id", "d"}, {"style", "position:relative"}}, {el("p", "a")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("div", "abs", {{"style", "position:absolute;top:0"}}));
             return doc->insert_subtree(byId(body, "d"), 1, build(doc, el("div", "abs", {{"style", "position:absolute;top:0"}})));
         },
         "structure: insert: a float or an out-of-flow box", "d"},
        {"a <p> into a closed <details>", {el("details", "", {{"id", "s"}}, {el("summary", "s"), el("p", "a")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("p", "b"));
             return doc->insert_subtree(byId(body, "s"), byId(body, "s")->children().size(), build(doc, el("p", "b")));
         },
         "structure: insert: in a closed details", "s"},
        {"a <p> under display:none beside an svg",
         {el("div", "", {{"id", "w"}}, {el("div", "", {{"id", "h"}, {"style", "display:none"}}, {el("p", "x")})}),
          el("svg", "", {{"width", "10"}, {"height", "10"}})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids[0].kids.push_back(el("p", "y"));
             return doc->insert_subtree(byId(body, "h"), 1, build(doc, el("p", "y")));
         },
         "structure: insert: renders nothing", "w"},
        {"a <p> into an inline holding a block",
         {el("div", "", {{"id", "d"}}, {el("span", "", {{"id", "s"}}, {el("div", "x")}), el("p", "y")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids[0].kids.push_back(el("p", "z"));
             auto span = byId(body, "s");
             return doc->insert_subtree(span, span->children().size(), build(doc, el("p", "z")));
         },
         "structure: insert: several render items", "d"},
        {"a <tr> into a block", {el("div", "", {{"id", "d"}}, {el("p", "a")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("tr", "", {}, {el("td", "c")}));
             return doc->insert_subtree(byId(body, "d"), 1, build(doc, el("tr", "", {}, {el("td", "c")})));
         },
         "structure: insert: a table part outside a table", "d"},
        {"a <p> beside a <tr> in a block", {el("div", "", {{"id", "d"}}, {el("p", "a"), el("tr", "", {}, {el("td", "c")})})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.insert(kids[0].kids.begin(), el("p", "z"));
             return doc->insert_subtree(byId(body, "d"), 0, build(doc, el("p", "z")));
         },
         "structure: insert: a table part outside a table", "d"},
        {"a <p> beside an inline holding a block",
         {el("div", "", {{"id", "d"}}, {el("span", "", {}, {el("div", "x")}), el("p", "y")})},
         [](auto doc, auto body, auto& kids) {
             kids[0].kids.push_back(el("p", "z"));
             auto d = byId(body, "d");
             return doc->insert_subtree(d, d->children().size(), build(doc, el("p", "z")));
         },
         "structure: insert: an inline holding blocks", "d"},
    };
    for (Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", k.kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(k.patch(doc, body, k.kids));
        structureMatchesFresh(c, doc, "", k.kids, k.name);
        reasonIs(doc, k.reason, k.name);
        const std::string at = replacedAt(doc, observer);
        if (at != k.boundary) std::printf("  %s: replaced at \"%s\", want \"%s\"\n", k.name, at.c_str(), k.boundary);
        CHECK(at == k.boundary);
        CHECK(observer.linked.empty() && observer.unlinked.empty());
        doc->set_render_observer(nullptr);
    }
}

// Edits 89, 42: a positional rule the insertion moves matches the parent's other children again with the check a kept
// parent needs. A sibling whose box it changes replaces the parent, the link with it; one whose geometry it changes
// keeps its item and is restyled beside the link.
static void testAPositionalChangeBesideALink() {
    {
        const char* sheet = ".x:first-child{float:left;width:20px}";
        std::vector<Spec> kids = {el("div", "", {{"id", "d"}}, {el("p", "a", {{"class", "x"}}), el("p", "b")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->insert_subtree(byId(body, "d"), 0, build(doc, el("p", "new"))));
        kids[0].kids.insert(kids[0].kids.begin(), el("p", "new"));
        structureMatchesFresh(c, doc, sheet, kids, "a float that is no longer first");
        CHECK(replacedAt(doc, observer) == "d");
        CHECK(observer.linked.empty());
        doc->set_render_observer(nullptr);
    }
    {
        const char* sheet = "p:first-child{margin-top:30px}";
        std::vector<Spec> kids = {el("div", "", {{"id", "d"}}, {el("p", "a", {{"id", "a"}}), el("p", "b")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        auto a = byId(body, "a");
        const std::shared_ptr<litehtml::render_item> aItem = doc->live_item(*a);
        CHECK(doc->insert_subtree(byId(body, "d"), 0, build(doc, el("p", "new"))));
        kids[0].kids.insert(kids[0].kids.begin(), el("p", "new"));
        structureMatchesFresh(c, doc, sheet, kids, "a margin that is no longer first");
        CHECK(observer.replaced.empty() && observer.linked.size() == 1);
        CHECK(doc->live_item(*a) == aItem);
        CHECK(std::any_of(observer.restyled.begin(), observer.restyled.end(), [&](const auto& r) { return r.first == a.get(); }));
        doc->set_render_observer(nullptr);
    }
}

// Edit 89: a linked table takes its cells and an unlinked one gives them back, as a replaced one does.
static void testALinkedTableTakesAndGivesBackItsCells() {
    std::vector<Spec> rows;
    for (int r = 0; r < 3; r++) rows.push_back(el("tr", "", {}, {el("td", "1"), el("td", "2"), el("td", "3"), el("td", "4")}));
    const Spec table = el("table", "", {{"id", "t"}}, {el("tbody", "", {}, rows)});
    std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("p", "a")})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, "", kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    const int before = doc->table_cells();
    CHECK(doc->insert_subtree(byId(body, "w"), 1, build(doc, table)));
    kids[0].kids.push_back(table);
    structureMatchesFresh(c, doc, "", kids, "a table linked");
    CHECK(observer.replaced.empty() && observer.linked.size() == 1);
    CHECK(doc->table_cells() == before + 12);
    observer.clear();
    CHECK(doc->remove_subtree(byId(body, "t")));
    kids[0].kids.pop_back();
    structureMatchesFresh(c, doc, "", kids, "a table unlinked");
    CHECK(observer.replaced.empty() && observer.unlinked.size() == 1);
    CHECK(doc->table_cells() == before);
    doc->set_render_observer(nullptr);
}

// Edit 89 beside edit 74 in one session: a sibling's own replacement and a link into its parent both happen; a seed
// inside the linked subtree makes the parent the boundary, and the link goes with it.
static void testALinkBesideAReplacement() {
    const char* sheet = ".big{font-size:30px}";
    {
        std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("div", "", {{"id", "a"}}, {el("p", "a")}), el("p", "w")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->set_element_attribute(byId(body, "a"), "class", "big"));
        CHECK(doc->insert_subtree(byId(body, "w"), 2, build(doc, el("p", "new"))));
        kids[0].kids[0].attrs["class"] = "big";
        kids[0].kids.push_back(el("p", "new"));
        structureMatchesFresh(c, doc, sheet, kids, "a sibling replaced beside a link");
        CHECK(observer.replaced.size() == 1 && replacedAt(doc, observer) == "a");
        CHECK(observer.linked.size() == 1);
        doc->set_render_observer(nullptr);
    }
    {
        std::vector<Spec> kids = {el("div", "", {{"id", "w"}}, {el("div", "", {{"id", "a"}}, {el("p", "a")}), el("p", "w")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->insert_subtree(byId(body, "w"), 2, build(doc, el("p", "new", {{"id", "n"}}))));
        CHECK(doc->set_element_attribute(byId(body, "n"), "class", "big"));
        kids[0].kids.push_back(el("p", "new", {{"id", "n"}, {"class", "big"}}));
        structureMatchesFresh(c, doc, sheet, kids, "a seed inside a linked subtree");
        CHECK(replacedAt(doc, observer) == "w");
        CHECK(observer.linked.empty());
        doc->set_render_observer(nullptr);
    }
}

// VENDOR.md edit 75: a pseudo-class change restyles what it reaches (the element; its descendants when a rule names the
// class in a compound that is not its subject; its later siblings' subtrees when the sheets have sibling combinators),
// keeping the render tree where every rule that started or stopped matching is neutral and replacing it where one is
// not, as a document built with the class set lays out and paints.
static void testPseudoClassStateRematchesItsReach() {
    struct Case {
        const char* sheet;
        std::vector<Spec> kids;
        bool neutral;
        const char* what;
    };
    const Case cases[] = {
        {"p:hover{color:#c00}", {el("p", "one", {{"id", "t"}}), el("p", "two")}, true, "a paint-only rule on the element"},
        {".card:hover .x{display:none}",
         {el("div", "", {{"id", "t"}, {"class", "card"}}, {el("span", "x", {{"class", "x"}}), txt(" y")}), el("p", "after")},
         false, "a rule on a descendant"},
        {"a:hover + .tip{display:block} .tip{display:none}",
         {el("a", "link", {{"id", "t"}}), el("div", "tip", {{"class", "tip"}}), el("p", "after")}, false,
         "a rule on the next sibling"},
        {"#t:hover::before{content:'>'}", {el("p", "one", {{"id", "t"}}), el("p", "two")}, false, "pseudo-element content"},
        {"#t:hover{background-color:#eee}", {el("table", "", {{"id", "t"}}, {el("tr", "", {}, {el("td", "c")})}), el("p", "after")},
         true, "a table, which has no attribute patch"},
        {"p:nth-last-child(1 of :not(:hover)){color:#c00}", {el("p", "one"), el("p", "two", {{"id", "t"}})}, true,
         "an earlier sibling, by an nth-last-child of a list naming the class"},
    };
    const std::vector<std::pair<litehtml::string_id, bool>> hover{{litehtml::_hover_, true}};
    for (const Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, k.kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        auto t = doc->root()->select_one("#t");
        CHECK(t != nullptr);
        if (!t) continue;
        CHECK(doc->can_set_pseudo_classes({{t, hover}}));
        CHECK(doc->set_pseudo_classes({{t, hover}}));
        pseudoMatchesFresh(c, doc, k.sheet, k.kids, {"t"}, k.what);
        CHECK(t->has_pseudo_class(litehtml::_hover_));
        if (observer.replaced.empty() != k.neutral) std::printf("  replacements %zu after: %s (%s)\n", observer.replaced.size(), k.what, doc->rebuild_reason().c_str());
        CHECK(observer.replaced.empty() == k.neutral);
        doc->set_render_observer(nullptr);
    }
    // Only what the flip can change is matched again: :hover set on an element no rule's match depends on (as a tap's
    // chain sets it on <body>) leaves it alone, its ::before content and its render tree untouched, nothing restyled.
    {
        const char* sheet = "p:hover{color:#c00} body::before{content:'b'}";
        std::vector<Spec> kids = {el("p", "one", {{"id", "t"}}), el("p", "two")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->set_pseudo_classes({{body, hover}}));
        doc->commit_patch();
        doc->render(litehtml::pixel_t(200.0f));
        CHECK(body->has_pseudo_class(litehtml::_hover_));
        CHECK(observer.replaced.empty());
        CHECK(observer.restyled.empty());
        doc->set_render_observer(nullptr);
    }
    // A tap's chain in one call: nested flips that each reach their subtree visit each element once, and the result is
    // a document built with every class set.
    {
        const char* sheet = ".c:hover .x{display:none} .c:hover{color:#c00}";
        std::vector<Spec> kids = {
            el("div", "", {{"id", "o"}, {"class", "c"}},
               {el("div", "", {{"id", "i"}, {"class", "c"}}, {el("span", "x", {{"class", "x"}}), txt(" y")}),
                el("span", "z", {{"class", "x"}})}),
            el("p", "after")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto o = doc->root()->select_one("#o");
        auto i = doc->root()->select_one("#i");
        CHECK(o && i);
        if (o && i) {
            const std::vector<litehtml::document::pseudo_flip> chain{{i, hover}, {o, hover}};
            uint64_t nodes = 0;
            std::vector<element::ptr> stack{o};
            while (!stack.empty()) {
                element::ptr next = stack.back();
                stack.pop_back();
                nodes++;
                for (const auto& child : next->children()) stack.push_back(child);
            }
            const uint64_t steps = doc->predicate_steps();
            const auto reach = doc->pseudo_reach(chain);
            // #o's subtree's nodes once each, and #i once more, where the walk from #o meets it.
            CHECK(reach.size() == 4);
            if (doc->predicate_steps() - steps != nodes + 1) std::printf("  steps %llu, nodes %llu\n", (unsigned long long)(doc->predicate_steps() - steps), (unsigned long long)nodes);
            CHECK(doc->predicate_steps() - steps == nodes + 1);
            CHECK(doc->set_pseudo_classes(chain));
            pseudoMatchesFresh(c, doc, sheet, kids, {"o", "i"}, "a chain of two");
        }
    }
    // A link's :link stays one entry per sheet, as a fresh document's (el_anchor::apply_stylesheet adds it at each match).
    {
        const char* sheet = "a:hover{color:#c00}";
        std::vector<Spec> kids = {el("a", "link", {{"id", "t"}, {"href", "#"}}), el("p", "after")};
        auto links = [](const element::ptr& e) {
            int count = 0;
            while (e->set_pseudo_class(litehtml::_link_, false)) count++;
            return count;
        };
        PaintContainer fresh;
        element::ptr freshBody;
        auto reference = structureDocument(fresh, sheet, kids, freshBody);
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto t = doc->root()->select_one("#t");
        CHECK(t != nullptr);
        if (t) {
            for (int round = 0; round < 3; round++) {
                CHECK(doc->set_pseudo_classes({{t, hover}}));
                CHECK(doc->set_pseudo_classes({{t, {{litehtml::_hover_, false}}}}));
            }
            const int expected = links(reference->root()->select_one("#t"));
            const int got = links(t);
            if (got != expected) std::printf("  :link entries %d, a fresh document's %d\n", got, expected);
            CHECK(expected > 0);
            CHECK(got == expected);
        }
    }
    // Counters reach the elements after it (edit 78: they run again in a build's order).
    {
        const char* sheet = "#t:hover{counter-increment:n} p::after{content:counter(n)}";
        const std::vector<Spec> kids = {el("p", "one", {{"id", "t"}}), el("p", "two")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto t = doc->root()->select_one("#t");
        CHECK(t && doc->can_set_pseudo_classes({{t, hover}}));
        CHECK(t && doc->set_pseudo_classes({{t, hover}}));
        pseudoMatchesFresh(c, doc, sheet, kids, {"t"}, "a hover incrementing a counter the next element reads");
    }
}

// VENDOR.md edit 78: counters are made in a build's order, so a change that touches a counted element (one declaring
// counter-reset or counter-increment, holding counter values, or with ::before/::after content reading a counter) runs
// every counted element's match again in a build's pass order, as a document built with the change counts.
static void testCountersRunAgainInBuildOrder() {
    const char* sheet = "ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n) '. '} li:hover{color:#c00}"
                        " li.skip{counter-increment:none}";
    const auto list = [] {
        return std::vector<Spec>{el("ol", "", {}, {el("li", "a", {{"id", "l1"}}), el("li", "b", {{"id", "l2"}}),
                                                   el("li", "c", {{"id", "l3"}}), el("li", "d", {{"id", "l4"}})})};
    };
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, list(), body);
        CHECK(doc->set_pseudo_classes({{doc->root()->select_one("#l2"), {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, sheet, list(), {"l2"}, "a hover on a numbered item");
    }
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = list();
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->set_element_attribute(doc->root()->select_one("#l2"), "class", "skip"));
        kids[0].kids[1].attrs["class"] = "skip";
        structureMatchesFresh(c, doc, sheet, kids, "an item that stops counting");
    }
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = list();
        auto doc = structureDocument(c, sheet, kids, body);
        auto ol = childAt(body, 0);
        CHECK(doc->insert_subtree(ol, 0, build(doc, el("li", "z"))));
        kids[0].kids.insert(kids[0].kids.begin(), el("li", "z"));
        structureMatchesFresh(c, doc, sheet, kids, "an item inserted first");
    }
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = list();
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->remove_subtree(doc->root()->select_one("#l3")));
        kids[0].kids.erase(kids[0].kids.begin() + 2);
        structureMatchesFresh(c, doc, sheet, kids, "the third item removed");
    }
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = list();
        auto doc = structureDocument(c, sheet, kids, body);
        auto ol = childAt(body, 0);
        CHECK(doc->remove_subtree(doc->root()->select_one("#l1")));
        CHECK(doc->insert_subtree(ol, ol->children().size(), build(doc, el("li", "a", {{"id", "l1"}}))));
        std::rotate(kids[0].kids.begin(), kids[0].kids.begin() + 1, kids[0].kids.end());
        structureMatchesFresh(c, doc, sheet, kids, "the first item moved last");
    }
    // The rules a build applies to the ::before/::after themselves (`*`, `li > *`), each in a build's place: an ::after
    // after its owner's descendants.
    struct Case {
        const char* sheet;
        std::vector<Spec> kids;
        const char* what;
    };
    const std::vector<Spec> nested = {el("ol", "", {}, {el("li", "a", {{"id", "l1"}}),
                                                         el("li", "", {{"id", "l2"}}, {txt("b"), el("ol", "", {}, {el("li", "c"), el("li", "d")})}),
                                                         el("li", "e")})};
    const Case cases[] = {
        {"ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n) '. '} li > *{color:#c00}"
         " li:hover{background:#eee}",
         list(), "a rule on li > * reaching the ::before"},
        {"*{padding:0} ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n) '. ';padding:0 9px}"
         " li:hover{color:#c00}",
         list(), "a * reset over the ::before's padding"},
        {"ol{counter-reset:n} li{counter-increment:n} li::after{counter-increment:n;content:counter(n)} *{margin:0}"
         " li:hover{color:#c00}",
         nested, "an ::after that counts, reached by * after its owner's descendants"},
        // A pseudo-element that counts and reads nothing (its owner is counted).
        {"body{counter-reset:n} div::before{counter-increment:n;content:'-'} p::after{content:counter(n)}"
         " p:hover{color:#c00}",
         {el("div", "d"), el("p", "p", {{"id", "l2"}}), el("div", "d"), el("p", "q")}, "a ::before that counts"},
    };
    for (const Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, k.kids, body);
        CHECK(doc->set_pseudo_classes({{doc->root()->select_one("#l2"), {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, k.sheet, k.kids, {"l2"}, k.what);
    }
    {
        // Inserting an element whose ::before counts.
        const char* sheet = "body{counter-reset:n} div::before{counter-increment:n;content:'-'} p::after{content:counter(n)}";
        std::vector<Spec> kids = {el("div", "d"), el("p", "p"), el("p", "q")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->insert_subtree(body, 2, build(doc, el("div", "e"))));
        kids.insert(kids.begin() + 2, el("div", "e"));
        structureMatchesFresh(c, doc, sheet, kids, "an element whose ::before counts inserted");
    }
}

// VENDOR.md edit 79: the same sheets parse to the same sorted rules at any viewport, so an environment change pairs them
// by position; a rule whose parse folded a viewport unit is marked.
static void testEnvironmentParsesPairUp() {
    const char* sheet = "div{width:50vw} p{color:#c00} @media (min-width:250px){p{margin:1px}} li{font-size:2vmin}"
                        " .a b{padding:1vh}";
    PaintContainer narrow, wide;
    narrow.width = 200;
    wide.width = 400;
    element::ptr b1, b2;
    auto d1 = structureDocument(narrow, sheet, {el("p", "p")}, b1);
    auto d2 = structureDocument(wide, sheet, {el("p", "p")}, b2);
    const std::pair<const litehtml::css*, const litehtml::css*> sheets[] = {{&d1->master_css(), &d2->master_css()},
                                                                         {&d1->author_css(), &d2->author_css()}};
    for (const auto& [a, b] : sheets) {
        CHECK(a->selectors().size() == b->selectors().size());
        for (size_t i = 0; i < a->selectors().size() && i < b->selectors().size(); i++) {
            const auto& x = a->selectors()[i];
            const auto& y = b->selectors()[i];
            CHECK(x->m_specificity == y->m_specificity);
            CHECK(x->m_right.m_tag == y->m_right.m_tag);
            CHECK(x->m_style->environment() == y->m_style->environment());
        }
    }
    int marked = 0;
    for (const auto& sel : d1->author_css().selectors()) marked += (sel->m_style->environment() & litehtml::environment_viewport) ? 1 : 0;
    CHECK(marked == 3);
}

// VENDOR.md edit 79: a width or reduced-motion change patches the document in place: the users of rules whose media
// lists flip are matched again and the elements whose style resolved a viewport unit restyled, as a build at the new
// values makes them.
static void testEnvironmentChangesMatchFresh() {
    struct Case {
        const char* sheet;
        std::vector<Spec> kids;
        int fromWidth, toWidth, fromReduced, toReduced;
        bool paintOnly;
        const char* what;
    };
    const std::vector<Spec> list = {el("p", "p"),
                                    el("ol", "", {}, {el("li", "a", {{"class", "a"}}), el("li", "b"), el("li", "c")})};
    const char* breakpoint = "@media (max-width:250px){li.a{display:none}} @media (min-width:250px){p::before{content:'*'}}"
                             " ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n)}";
    const Case cases[] = {
        {breakpoint, list, 200, 300, 0, 0, false, "a breakpoint over ::before content and counters, widening"},
        {breakpoint, list, 300, 200, 0, 0, false, "a breakpoint over ::before content and counters, narrowing"},
        {"div{width:50vw;font-size:4vw}", {el("div", "d"), el("p", "p")}, 200, 300, 0, 0, false, "viewport units"},
        {"@media (min-width:250px){li{counter-increment:n}} ol{counter-reset:n} li::before{content:counter(n)}", list, 200,
         300, 0, 0, false, "counters under a media rule"},
        {"@media (prefers-reduced-motion:reduce){p{color:#c00;padding:2px}}", list, 300, 300, 0, 1, false,
         "reduced motion"},
        {"@media (prefers-reduced-motion:reduce){p{color:#c00}}", list, 300, 300, 0, 1, true, "reduced motion, paint only"},
    };
    for (const Case& k : cases) {
        PaintContainer c;
        c.width = k.fromWidth;
        c.reduced = k.fromReduced;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, k.kids, body);
        c.width = k.toWidth;
        c.reduced = k.toReduced;
        CHECK(doc->environment_changed());
        doc->commit_patch();
        if (k.paintOnly && !doc->rebuild_reason().empty()) std::printf("  %s: replaced (%s)\n", k.what, doc->rebuild_reason().c_str());
        CHECK(!k.paintOnly || doc->rebuild_reason().empty());
        structureMatchesFresh(c, doc, k.sheet, k.kids, k.what, k.toWidth, k.toReduced);
    }
}

// VENDOR.md edit 80: the same sheets parse to the same sorted rules under either scheme, so a scheme change pairs them by
// position; a rule whose parse resolved light-dark() or a color-scheme naming both is marked.
static void testSchemeParsesPairUp() {
    const char* sheet = "p{color:light-dark(#000001,#000002)} div{color-scheme:light dark} span{color-scheme:dark}"
                        " @media (prefers-color-scheme:dark){p{margin:1px}} li{color:#c00} .a b{background:light-dark(red,blue)}";
    PaintContainer light, dark;
    dark.scheme = 1;
    element::ptr b1, b2;
    auto d1 = structureDocument(light, sheet, {el("p", "p")}, b1);
    auto d2 = structureDocument(dark, sheet, {el("p", "p")}, b2);
    const std::pair<const litehtml::css*, const litehtml::css*> sheets[] = {{&d1->master_css(), &d2->master_css()},
                                                                         {&d1->author_css(), &d2->author_css()}};
    for (const auto& [a, b] : sheets) {
        CHECK(a->selectors().size() == b->selectors().size());
        for (size_t i = 0; i < a->selectors().size() && i < b->selectors().size(); i++) {
            const auto& x = a->selectors()[i];
            const auto& y = b->selectors()[i];
            CHECK(x->m_specificity == y->m_specificity);
            CHECK(x->m_right.m_tag == y->m_right.m_tag);
            CHECK(x->m_style->environment() == y->m_style->environment());
        }
    }
    int marked = 0;
    for (const auto& sel : d1->author_css().selectors()) marked += (sel->m_style->environment() & litehtml::environment_scheme) ? 1 : 0;
    CHECK(marked == 3);
}

// VENDOR.md edit 80: a scheme change, with new root declarations or not, patches the document in place as a build under
// the new scheme makes it.
static void testSchemeChangeMatchesFresh() {
    struct Case {
        const char* sheet;
        std::vector<Spec> kids;
        const char* fromDeclarations;
        const char* toDeclarations;
        bool paintOnly;
        const char* what;
    };
    const std::vector<Spec> para = {el("p", "p"), el("div", "", {}, {el("p", "inner")})};
    const Case cases[] = {
        {"p{color:light-dark(#000001,#000002)}", para, "", "", true, "light-dark() in a sheet"},
        {"", {el("p", "p", {{"style", "color:light-dark(#000001,#000002)"}})}, "", "", true, "an inline light-dark()"},
        {"div{color:light-dark(#000001,#000002)}", para, "", "", true, "light-dark() inherited"},
        {"@media (prefers-color-scheme:dark){p{display:none}}", para, "", "", false, "a prefers-color-scheme rule"},
        {"div{color-scheme:light dark}", {el("div", "", {}, {el("input", "", {{"value", "v"}})})}, "", "", false,
         "a color-scheme naming both over an <input>"},
        {":root{--k:light-dark(#000001,#000002)} p{color:var(--k)}", para, "", "", true, "light-dark() through var()"},
        {"p{color:var(--tg-theme-text-color)}", para, "--tg-theme-text-color:#000001", "--tg-theme-text-color:#000002",
         true, "root declarations read through var()"},
        {"p{margin:1px}", para, "color:light-dark(#000001,#000002)", "color:light-dark(#000001,#000002)", true,
         "a light-dark() in unchanged root declarations"},
        // Final review I2: a property kept as tokens resolves light-dark() at compute or at draw.
        {"p{box-shadow:0 2px 3px light-dark(#000001,#000002)}", para, "", "", true, "light-dark() in a box-shadow"},
    };
    for (const Case& k : cases) {
        PaintContainer c;
        c.rootDeclarations = k.fromDeclarations;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, k.kids, body);
        const std::string before = painted(c, doc);
        c.scheme = 1;
        c.rootDeclarations = k.toDeclarations;
        CHECK(doc->change_root_declarations(k.toDeclarations) == (std::string(k.fromDeclarations) != k.toDeclarations));
        CHECK(doc->environment_changed());
        doc->commit_patch();
        if (k.paintOnly && !doc->rebuild_reason().empty()) std::printf("  %s: replaced (%s)\n", k.what, doc->rebuild_reason().c_str());
        CHECK(!k.paintOnly || doc->rebuild_reason().empty());
        structureMatchesFresh(c, doc, k.sheet, k.kids, k.what, 300, 0, 1);
        // The case reads the scheme: a dark build differs from the light one.
        PaintContainer fresh;
        fresh.scheme = 1;
        fresh.rootDeclarations = k.toDeclarations;
        element::ptr b;
        auto reference = structureDocument(fresh, k.sheet, k.kids, b);
        if (painted(fresh, reference) == before) std::printf("  %s: the scheme changes nothing painted\n", k.what);
        CHECK(painted(fresh, reference) != before);
    }
}

// VENDOR.md edit 80 (final review I2): an SVG paint resolves light-dark() at draw, from a rule's tokens or a presentation
// attribute, so a scheme change restyles the shape (the render observer hears it, and repaints it): a fresh draw is right
// either way, what was painted before is not.
static void testSchemeChangeRestylesSvgPaint() {
    const char* sheet = "rect{fill:light-dark(#000003,#000004)}";
    const std::vector<Spec> kids = {el("svg", "", {{"width", "40"}, {"height", "20"}},
                                       {el("circle", "", {{"cx", "10"}, {"cy", "10"}, {"r", "5"}, {"fill", "light-dark(#000001,#000002)"}}),
                                        el("rect", "", {{"x", "20"}, {"y", "5"}, {"width", "10"}, {"height", "10"}})})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    c.scheme = 1;
    CHECK(doc->environment_changed());
    doc->commit_patch();
    doc->render(litehtml::pixel_t(200.0f));
    auto svg = childAt(body, 0);
    auto restyled = [&](const element::ptr& el) {
        for (const auto& [e, order] : observer.restyled)
            for (const litehtml::element* p = el.get(); p; p = p->parent().get())
                if (e == p) return true;
        return false;
    };
    if (!restyled(childAt(svg, 0))) std::printf("  the circle (a fill attribute) was not restyled\n");
    if (!restyled(childAt(svg, 1))) std::printf("  the rect (a fill rule) was not restyled\n");
    CHECK(restyled(childAt(svg, 0)));
    CHECK(restyled(childAt(svg, 1)));
    doc->set_render_observer(nullptr);
    structureMatchesFresh(c, doc, sheet, kids, "light-dark() in SVG paint", 300, 0, 1);
}

// VENDOR.md edits 79, 80: a rule an environment change replaced (a copy holding the new parse's style) is replaced again
// by the next one, and nothing holds the first copy then but what matched it: a match again keeps it alive while it
// compares, and the indexes derived from the sheets are made again, so nothing reads it after (AddressSanitizer).
static void testEnvironmentChangesTwiceKeepNoFreedRule() {
    const char* sheet = "p{color:light-dark(#000001,#000002)} p:hover{background:light-dark(#000003,#000004)}";
    const std::vector<Spec> kids = {el("p", "p", {{"id", "p"}}), el("div", "d")};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, kids, body);
    auto p = doc->root()->select_one("#p");
    CHECK(p != nullptr);
    if (!p) return;
    const litehtml::string_id hover = litehtml::_hover_;
    for (int round = 0; round < 4; round++) {
        c.scheme = 1 - c.scheme;
        CHECK(doc->environment_changed());
        doc->commit_patch();
        // A hover flip reads the sheets' indexes (selector_scope), made from the rules as they are now.
        CHECK(doc->set_pseudo_classes({{p, {{hover, round % 2 == 0}}}}));
        doc->commit_patch();
    }
    CHECK(doc->set_pseudo_classes({{p, {{hover, false}}}}));
    structureMatchesFresh(c, doc, sheet, kids, "four scheme changes with hover flips between", 300, 0, c.scheme);
}

// VENDOR.md edit 81 (final review I1): a sheet change that leaves the applied texts as they were (a <style> set to its own
// text, an empty one emptied) parses nothing: a sheet with @media skips the parse cache, so a parse would be the whole
// author sheets' again, which the runtime charges only when the applied texts change.
static void testUnchangedSheetsParseNothing() {
    struct Counting : PaintContainer {
        int lists = 0;
        void sanitize_selector_list(std::vector<litehtml::css_token_vector>&) override { lists++; }
    };
    const std::string sheet = "@media (min-width:1px){p{color:#c00}} b{color:#00c}";
    const std::vector<Spec> kids = {el("p", "p"), el("b", "b")};
    Counting c;
    element::ptr body;
    auto doc = structureDocument(c, std::vector<std::string>{sheet, ""}, kids, body);
    const int parsed = c.lists;
    std::vector<element::ptr> made;
    CHECK(doc->replace_style_text(childAt(childAt(doc->root(), 0), 0), sheet, made));
    CHECK(doc->replace_style_text(childAt(childAt(doc->root(), 0), 1), "", made));
    doc->commit_patch();
    if (c.lists != parsed) std::printf("  %d selector lists parsed again\n", c.lists - parsed);
    CHECK(c.lists == parsed);
    structureMatchesFresh(c, doc, std::vector<std::string>{sheet, ""}, kids, "unchanged sheets");
}

// VENDOR.md edits 77, 81: a class change beside a sheet change in one session: the commit applies the sheets (which
// makes the sheet-derived indexes again) and then matches the class change's reach by the rules naming the class, as a
// build with both makes the document.
static void testAClassChangeBesideASheetChangeMatchesFresh() {
    std::vector<Spec> kids = {el("div", "", {{"id", "d"}}, {el("p", "p"), el("p", "q")}), el("b", "b")};
    const std::vector<std::string> before = {".k p{color:#c00}", "b{color:#00c}"};
    const std::vector<std::string> after = {".k p{color:#c00}", "b{color:#0c0}"};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, before, kids, body);
    std::vector<element::ptr> made;
    CHECK(doc->replace_style_text(childAt(childAt(doc->root(), 0), 1), after[1], made));
    CHECK(doc->set_element_attribute(childAt(body, 0), "class", "k"));
    kids[0].attrs["class"] = "k";
    structureMatchesFresh(c, doc, after, kids, "a class change beside a sheet change");
}

// VENDOR.md edit 81 (final review C1): a new rule's tests against the elements count every step select takes into the
// session, and stop at its limit, as a build's matching does: a sibling chain that never matches recurses over every
// earlier sibling, so counting one step per test let one sheet edit run unbounded in the commit.
static void testSheetTestsCountIntoTheSession() {
    std::vector<Spec> kids;
    for (int n = 0; n < 60; n++) kids.push_back(el("i", "i", {{"class", "a"}}));
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, std::vector<std::string>{"i{color:#c00}"}, kids, body);
    constexpr int64_t limit = 20000;
    doc->begin_selector_steps(limit);
    // A sheet of its own: the first keeps its rules, so only the new rule's tests run (nothing holds a lost rule).
    CHECK(doc->insert_subtree(childAt(doc->root(), 0), 1, build(doc, el("style", ".z~.a~.a~.a~.a{color:#00c}"))));
    doc->commit_patch();
    const int64_t used = doc->end_selector_steps();
    if (used <= limit) std::printf("  %lld steps counted under a %lld limit\n", (long long)used, (long long)limit);
    CHECK(used > limit);
    {
        // A class change beside a sheet change: the commit's attribute reach tests the rules naming the class against the
        // reach (here a kept sheet's chain), in a counted pass too.
        PaintContainer c2;
        element::ptr body2;
        const std::vector<Spec> held = {el("div", "", {{"id", "d"}}, kids)};
        auto doc2 = structureDocument(c2, std::vector<std::string>{".k .z~.a~.a~.a~.a{color:#00c}", "b{color:#c00}"}, held, body2);
        doc2->begin_selector_steps(limit);
        std::vector<element::ptr> made2;
        CHECK(doc2->replace_style_text(childAt(childAt(doc2->root(), 0), 1), "b{color:#0c0}", made2));
        CHECK(doc2->set_element_attribute(childAt(body2, 0), "class", "k"));
        doc2->commit_patch();
        const int64_t used2 = doc2->end_selector_steps();
        if (used2 <= limit) std::printf("  %lld steps counted under a %lld limit beside a class change\n", (long long)used2, (long long)limit);
        CHECK(used2 > limit);
    }
    {
        // A state flip with no sheet change (edit 75): the rules naming the state tested over its reach, counted too.
        PaintContainer c3;
        element::ptr body3;
        auto doc3 = structureDocument(c3, std::vector<std::string>{".z~.a:hover~.a~.a~.a{color:#00c}"}, kids, body3);
        doc3->begin_selector_steps(limit);
        CHECK(doc3->set_pseudo_classes({{childAt(body3, 0), {{litehtml::_hover_, true}}}}));
        doc3->commit_patch();
        const int64_t used3 = doc3->end_selector_steps();
        if (used3 <= limit) std::printf("  %lld steps counted under a %lld limit for a state flip\n", (long long)used3, (long long)limit);
        CHECK(used3 > limit);
    }
}

// VENDOR.md edit 81: a <style>'s text changed, a <style> inserted or removed: the sheets change in place, as a build with
// the new sheets makes the document.
static void testSheetChangesMatchFresh() {
    const std::vector<Spec> kids = {el("p", "p", {{"class", "a b"}}), el("ol", "", {}, {el("li", "a"), el("li", "b")})};
    const char* counters = "li{counter-increment:n} li::before{content:counter(n)}";
    struct TextCase {
        std::string from, to;
        bool paintOnly;
        const char* what;
    };
    const TextCase texts[] = {
        {"p{color:#c00}", "p{color:#c00} .a{display:none}", false, "a rule added"},
        {"p{color:#c00} .a{display:none}", "p{color:#c00}", false, "a rule removed"},
        {".a{color:#c00} .b{color:#00c}", ".b{color:#00c} .a{color:#c00}", true, "two equal rules swapped"},
        {"p{color:#c00}", "p{color:#00c}", true, "a colour changed"},
        {"p{color:#c00}", "@media (min-width:100px){p{display:none}} p{color:#c00}", false, "an @media block added"},
        {"p{color:#c00}", std::string("p{color:#c00} ") + counters, false, "counters added"},
        {std::string("p{color:#c00} ") + counters, "p{color:#c00}", false, "counters removed"},
        {"p{color:#c00}", "", false, "a sheet emptied"},
        {"", "p::before{content:'x'}", false, "an empty sheet filled"},
    };
    for (const TextCase& k : texts) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, std::vector<std::string>{k.from}, kids, body);
        auto style = childAt(childAt(doc->root(), 0), 0);
        std::vector<element::ptr> made;
        CHECK(doc->replace_style_text(style, k.to, made));
        doc->commit_patch();
        if (k.paintOnly && !doc->rebuild_reason().empty()) std::printf("  %s: replaced (%s)\n", k.what, doc->rebuild_reason().c_str());
        CHECK(!k.paintOnly || doc->rebuild_reason().empty());
        structureMatchesFresh(c, doc, std::vector<std::string>{k.to}, kids, k.what);
    }
    {
        // A second <style> inserted before the first and after it, then removed; and a sheet in the body changed.
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> withBody = kids;
        withBody.insert(withBody.begin(), el("style", "li{color:#00c}"));
        auto doc = structureDocument(c, std::vector<std::string>{"p{color:#c00}"}, withBody, body);
        auto head = childAt(doc->root(), 0);
        CHECK(doc->insert_subtree(head, 0, build(doc, el("style", "p{color:#00c;padding:1px}"))));
        structureMatchesFresh(c, doc, std::vector<std::string>{"p{color:#00c;padding:1px}", "p{color:#c00}"}, withBody,
                              "a <style> inserted before the first");
        CHECK(doc->insert_subtree(head, 2, build(doc, el("style", "p{color:#0c0}"))));
        structureMatchesFresh(c, doc,
                              std::vector<std::string>{"p{color:#00c;padding:1px}", "p{color:#c00}", "p{color:#0c0}"},
                              withBody, "a <style> inserted after it");
        CHECK(doc->remove_subtree(childAt(head, 0)));
        CHECK(doc->remove_subtree(childAt(head, 1)));
        structureMatchesFresh(c, doc, std::vector<std::string>{"p{color:#c00}"}, withBody, "both removed");
        std::vector<element::ptr> made;
        CHECK(doc->replace_style_text(childAt(body, 0), "li{color:#0c0;margin:2px}", made));
        CHECK(made.size() == 1);
        withBody[0] = el("style", "li{color:#0c0;margin:2px}");
        structureMatchesFresh(c, doc, std::vector<std::string>{"p{color:#c00}"}, withBody, "a sheet in the body changed");
        CHECK(doc->insert_subtree(body, 1, build(doc, el("div", "", {}, {el("style", counters), el("i", "i")}))));
        withBody.insert(withBody.begin() + 1, el("div", "", {}, {el("style", counters), el("i", "i")}));
        structureMatchesFresh(c, doc, std::vector<std::string>{"p{color:#c00}"}, withBody, "a subtree holding a <style>");
        CHECK(doc->remove_subtree(childAt(body, 1)));
        withBody.erase(withBody.begin() + 1);
        structureMatchesFresh(c, doc, std::vector<std::string>{"p{color:#c00}"}, withBody, "the subtree removed");
    }
}

// VENDOR.md edit 82: the document element replaced in place: the old tree goes as a removal does, the new one is styled
// fresh with its sheets and the root declarations, as a build of the new tree makes the document.
static void testRootReplacementMatchesFresh() {
    const std::vector<Spec> kids = {el("p", "p", {{"class", "a"}}), el("ol", "", {}, {el("li", "a"), el("li", "b")})};
    const std::vector<std::string> sheets = {
        ":root{--k:#c00} p{color:var(--k)} li{counter-increment:n} li::before{content:counter(n)}"};
    const std::vector<Spec> next = {el("p", "new", {{"class", "a"}}),
                                    el("ul", "", {}, {el("li", "x"), el("li", "y"), el("li", "z")}), el("div", "d")};
    PaintContainer c;
    c.rootDeclarations = "--tg:#00c;color:var(--tg)";
    element::ptr body;
    auto doc = structureDocument(c, std::vector<std::string>{"p{color:#0c0}"}, kids, body);
    element::ptr nextBody;
    auto root = structureRoot(doc, sheets, next, nextBody);
    CHECK(doc->can_replace_root(root));
    CHECK(doc->replace_root(root));
    doc->commit_patch();
    CHECK(doc->root() == root);
    // The old tree's pieces count while anything holds them.
    body.reset();
    structureMatchesFresh(c, doc, sheets, next, "the document element replaced");
    // And by a tree with no sheet: the old tree's goes with it.
    auto bare = structureRoot(doc, {}, kids, body);
    CHECK(doc->replace_root(bare));
    doc->commit_patch();
    root.reset();
    nextBody.reset();
    structureMatchesFresh(c, doc, std::vector<std::string>{}, kids, "replaced by a tree with no sheet");
    // A root already in the document, or one with a parent, is refused.
    CHECK(!doc->can_replace_root(bare));
    CHECK(!doc->can_replace_root(childAt(bare, 1)));
}

// VENDOR.md edit 76: a predicate that refuses names why (document::refusal()).
static void testRefusalsSayWhy() {
    auto said = [](const litehtml::document::ptr& doc, const char* want, const char* what) {
        const std::string got = doc->refusal();
        if (got != want) std::printf("  %s: refused for \"%s\", want \"%s\"\n", what, got.c_str(), want);
        CHECK(got == want);
    };
    {
        // Counters refuse nothing (edit 78).
        const char* sheet = "li{counter-increment:n} li::before{content:counter(n)}";
        std::vector<Spec> kids = {el("div", "d", {{"id", "d"}}), el("ul", "", {}, {el("li", "a")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto d = doc->root()->select_one("#d");
        CHECK(d && doc->set_element_attribute(d, "class", "x"));
        kids[0].attrs["class"] = "x";
        structureMatchesFresh(c, doc, sheet, kids, "a class beside counters");
    }
    {
        PaintContainer c;
        element::ptr body;
        // Edit 84: an insertion beside ::before content at the text cap is made, and the commit's replay cuts as a build.
        // The document's own text is under the cap (cutting it is the caller's walk): 9,997 pieces, the sheet's and "p".
        std::string words;
        for (int n = 0; n < 4999; n++) words += n ? " w" : "w";
        std::vector<Spec> kids = {el("p", words.c_str()), el("p", "p")};
        auto doc = structureDocument(c, "p::before{content:'x'}", kids, body);
        CHECK(doc->text_limited());
        CHECK(doc->insert_subtree(body, 0, build(doc, el("p", "new"))));
        kids.insert(kids.begin(), el("p", "new"));
        structureMatchesFresh(c, doc, "p::before{content:'x'}", kids, "an insertion beside ::before content at the text cap");
    }
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "p{color:#c00}", {el("p", "p")}, body);
        CHECK(!doc->can_insert_subtree(body, 0, build(doc, el("body", "b"))));
        said(doc, "a document-level element", "a <body> inserted");
        CHECK(!doc->can_remove_subtree(doc->root()));
        said(doc, "an invalid subtree", "the root removed");
    }
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "td{padding:1px}",
                                     {el("table", "", {}, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "c", {{"id", "td"}})})})})},
                                     body);
        auto td = doc->root()->select_one("#td");
        CHECK(td != nullptr);
        if (td) {
            litehtml::string_map attrs = std::static_pointer_cast<litehtml::html_tag>(td)->attributes();
            attrs["colspan"] = "1000";
            attrs["rowspan"] = "1000";
            CHECK(doc->can_set_element_attributes(td, attrs)); // edit 84: the commit's recount cuts the cells
        }
    }
    {
        const char* sheet = "#t:hover{counter-increment:n} p::before{content:counter(n)}";
        const std::vector<Spec> kids = {el("p", "one", {{"id", "t"}}), el("p", "two")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto t = doc->root()->select_one("#t");
        CHECK(t && doc->set_pseudo_classes({{t, {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, sheet, kids, {"t"}, "a hover beside counters");
    }
    // The caps are no refusal (edit 84): elements counted up to 19,995 (the external build counts its own nowhere) beside
    // the 4 pseudo-elements, one short of the cap, which the hover's reach (a <p>, two pseudo-elements) would pass.
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "p::before{content:'x'} p::after{content:'y'} p:hover{color:#c00}",
                                     {el("p", "one", {{"id", "t"}}), el("p", "two")}, body);
        for (int n = 0; n < 19995; n++) CHECK(doc->external_element_allowed(2));
        auto t = doc->root()->select_one("#t");
        CHECK(t && doc->can_set_pseudo_classes({{t, {{litehtml::_hover_, true}}}}));
        CHECK(!doc->pseudo_limited());
    }
    {
        PaintContainer c;
        element::ptr body;
        const char* sheet = "p::before{content:'x'} p:hover{color:#c00}";
        const std::vector<Spec> kids = {el("p", capWords().c_str()), el("p", "p", {{"id", "t"}})};
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->text_limited());
        auto t = doc->root()->select_one("#t");
        CHECK(t && doc->set_pseudo_classes({{t, {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, sheet, kids, {"t"}, "a hover beside ::before content at the text cap");
    }
}

// VENDOR.md edit 21: a patched document holds the style bytes a fresh build of it holds, whatever patched it and however
// often: what leaves the tree and what is styled again gives back what it held.
static void testStyleBytesFollowPatches() {
    const char* families = "p{font-family:'A Long Family Name', 'Another Family Name', serif}";
    auto paragraphs = [] {
        return std::vector<Spec>{el("p", "one", {{"id", "a"}}), el("p", "two", {{"id", "b"}}), el("p", "three")};
    };
    {
        PaintContainer c;
        element::ptr body;
        std::vector<Spec> kids = paragraphs();
        auto doc = structureDocument(c, families, kids, body);
        CHECK(doc->style_bytes_charged() > 0);
        CHECK(doc->remove_subtree(doc->root()->select_one("#b")));
        kids.erase(kids.begin() + 1);
        structureMatchesFresh(c, doc, families, kids, "a removal");
    }
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, families, paragraphs(), body);
        CHECK(replaceKids(doc, body, {build(doc, el("p", "new"))}));
        structureMatchesFresh(c, doc, families, {el("p", "new")}, "new children");
    }
    const char* vars = ":root{--k:#c00; --f:'A Long Family Name', serif} p{color:var(--k);font-family:var(--f)} .x{padding:1px}";
    auto wrapped = [](const char* cls) {
        litehtml::string_map attrs{{"id", "w"}};
        if (*cls) attrs["class"] = cls;
        return std::vector<Spec>{el("div", "", attrs, {el("p", "one"), el("p", "two")})};
    };
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, vars, wrapped(""), body);
        CHECK(doc->set_element_attribute(doc->root()->select_one("#w"), "class", "x"));
        structureMatchesFresh(c, doc, vars, wrapped("x"), "a class restyling var() splices below it");
    }
    const char* inherited = "#w{font-family:'A Long Family Name', 'Another Family Name', serif} .x{padding:1px}";
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, inherited, wrapped(""), body);
        CHECK(doc->set_element_attribute(doc->root()->select_one("#w"), "class", "x"));
        structureMatchesFresh(c, doc, inherited, wrapped("x"), "a class restyling an inherited string below it");
    }
    {
        const char* hover = "#t:hover{font-family:'A Long Family Name', serif}";
        std::vector<Spec> kids = {el("p", "one", {{"id", "t"}}), el("p", "two")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, hover, kids, body);
        CHECK(doc->set_pseudo_classes({{doc->root()->select_one("#t"), {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, hover, kids, {"t"}, "a hover flip");
    }
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, vars, wrapped(""), body);
        auto w = doc->root()->select_one("#w");
        for (int i = 0; i < 500; i++) {
            CHECK(doc->set_element_attribute(w, "class", i % 2 == 0 ? "x" : nullptr));
            doc->commit_patch();
        }
        structureMatchesFresh(c, doc, vars, wrapped(""), "500 class toggles over var() splices");
    }
    // An inline style's var() is spliced again at every restyle (the style attribute is added again): what it held is
    // given back first.
    {
        const char* sheet = ":root{--f:'A Long Family Name', 'Another Family Name', serif} .x{padding:1px}";
        auto inline_var = [](const char* cls) {
            litehtml::string_map attrs{{"id", "w"}};
            if (*cls) attrs["class"] = cls;
            return std::vector<Spec>{el("div", "", attrs, {el("p", "one", {{"style", "font-family:var(--f)"}})})};
        };
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, inline_var(""), body);
        auto w = doc->root()->select_one("#w");
        for (int i = 0; i < 6; i++) {
            CHECK(doc->set_element_attribute(w, "class", i % 2 == 0 ? "x" : nullptr));
            doc->commit_patch();
        }
        structureMatchesFresh(c, doc, sheet, inline_var(""), "restyles of an inline var()");
    }
    // A ::before one rule makes and a content:none rule drops gives back what it held.
    {
        const char* sheet = "p::before{content:'x';font-family:'A Long Family Name', serif} p.off::before{content:none}";
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("p", "x", {{"id", "p"}})}, body);
        auto p = doc->root()->select_one("#p");
        for (int i = 0; i < 100; i++) {
            CHECK(doc->set_element_attribute(p, "class", i % 2 == 0 ? "off" : nullptr));
            doc->commit_patch();
        }
        structureMatchesFresh(c, doc, sheet, {el("p", "x", {{"id", "p"}})}, "100 toggles of a content:none rule");
    }
}

// The animated style (edit 27) for "style": the same declarations as a second inline style; nothing for another attribute.
static const char* animated_attr(const char* attr) {
    return std::string(attr) == "style" ? litehtml::animated_style_attribute : nullptr;
}

// VENDOR.md edit 17: an inline style with custom properties and var() is patched. A restyle substitutes no var() again
// (subst_vars replaces them in the style), so the commit matches again the var() readers below an element whose custom
// properties may have changed, whether they were declared inline or by :hover.
static void testCustomPropertiesInInlineStyle() {
    const char* sheet = "p{color:var(--k, #000)} .dark{--k:#fff} #w:hover{--k:#0a0}";
    auto page = [](const char* attr, const char* parent, const char* child) {
        litehtml::string_map w{{"id", "w"}}, p{{"id", "p"}};
        if (*parent) w[attr] = parent;
        if (*child) p[attr] = child;
        return std::vector<Spec>{el("div", "", w, {el("p", "one", p), el("span", "two")})};
    };
    struct Case {
        const char* id;
        const char* attr;
        const char* parentBefore;
        const char* childBefore;
        const char* value;
        const char* what;
    };
    const Case cases[] = {
        {"w", "style", "--k:#c00", "", "--k:#00f", "a parent's custom property under a child's var()"},
        {"p", "style", "--k:#00f", "", "color:var(--k, #c00)", "a child's var() in its own style"},
        {"p", "style", "", "", "--g:3px;padding:var(--g)", "a custom property and its var() on one element"},
        {"p", "style", "", "", "--d:none;display:var(--d, block)", "a display from a var() (a replacement)"},
    };
    for (const Case& k : cases) {
        for (const char* attr : {k.attr, animated_attr(k.attr)}) {
            if (!attr) continue;
            PaintContainer c;
            element::ptr body;
            auto doc = structureDocument(c, sheet, page(attr, k.parentBefore, k.childBefore), body);
            auto target = doc->root()->select_one(std::string("#") + k.id);
            CHECK(target != nullptr);
            if (!target) continue;
            const bool set = doc->set_element_attribute(target, attr, k.value);
            if (!set) std::printf("  refused (%s): %s\n", doc->refusal(), k.what);
            CHECK(set);
            const bool parent = std::string(k.id) == "w";
            const std::string what = std::string(k.what) + (std::string(attr) == k.attr ? "" : " (animated)");
            structureMatchesFresh(c, doc, sheet,
                                  page(attr, parent ? k.value : k.parentBefore, parent ? k.childBefore : k.value),
                                  what.c_str());
        }
    }
    // A hover that sets the custom property.
    {
        std::vector<Spec> kids = page("style", "", "");
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->set_pseudo_classes({{doc->root()->select_one("#w"), {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, sheet, kids, {"w"}, "a hover declaring the parent's custom property");
    }
    // A paint-only hover on an element declaring a custom property, whose readers have ::before content: the commit
    // matches the readers again, and their render subtrees are replaced (alone, and beside a structure change).
    for (const bool structure : {false, true}) {
        const char* content = "p{color:var(--k, #000)} p::before{content:'*'} #w:hover{outline:1px solid #f0f}";
        std::vector<Spec> kids = page("style", "--k:#c00", "");
        kids.push_back(el("div", "x", {{"id", "d"}}));
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, content, kids, body);
        CHECK(doc->set_pseudo_classes({{doc->root()->select_one("#w"), {{litehtml::_hover_, true}}}}));
        if (structure) {
            auto d = doc->root()->select_one("#d");
            CHECK(doc->insert_subtree(d, d->children().size(), build(doc, el("b", "y"))));
            kids.back().kids.push_back(el("b", "y"));
        }
        pseudoMatchesFresh(c, doc, content, kids, {"w"},
                           structure ? "a hover beside a structure change, over readers with ::before content"
                                     : "a hover over readers with ::before content");
    }
}

// VENDOR.md edit 77: an attribute change whose names a rule reads beyond the element (in an ancestor position, or with
// sibling selectors in the sheets) matches again what they reach, each element whose match by a rule naming a changed
// name differs, as a document built with the change.
static void testAttributeChangeRematchesItsReach() {
    struct Case {
        const char* sheet;
        std::vector<Spec> before;
        const char* name;
        const char* value;
        std::vector<Spec> after;
        const char* what;
    };
    const Case cases[] = {
        {".a p{display:none}", {el("div", "", {{"id", "t"}}, {el("p", "x"), el("span", "y")})}, "class", "a",
         {el("div", "", {{"id", "t"}, {"class", "a"}}, {el("p", "x"), el("span", "y")})}, "a class an ancestor position names"},
        {".x + .y{color:#0a0}", {el("p", "one", {{"id", "t"}}), el("p", "two", {{"class", "y"}})}, "class", "x",
         {el("p", "one", {{"id", "t"}, {"class", "x"}}), el("p", "two", {{"class", "y"}})}, "the next sibling"},
        {"p:nth-last-child(1 of .k){color:#c00}", {el("p", "one", {{"class", "k"}}), el("p", "two", {{"id", "t"}})}, "class",
         "k", {el("p", "one", {{"class", "k"}}), el("p", "two", {{"id", "t"}, {"class", "k"}})}, "an earlier sibling"},
        {"[data-k] span{padding:1px}", {el("div", "", {{"id", "t"}}, {el("span", "s")})}, "data-k", "1",
         {el("div", "", {{"id", "t"}, {"data-k", "1"}}, {el("span", "s")})}, "an attribute an ancestor position names"},
        {"#k1 li{margin:3px}", {el("ul", "", {{"id", "t"}}, {el("li", "a")})}, "id", "k1",
         {el("ul", "", {{"id", "k1"}}, {el("li", "a")})}, "an id an ancestor position names"},
        {"a:link span{color:#00f} span{color:#000}", {el("a", "", {{"id", "t"}, {"href", "#"}}, {el("span", "s")})}, "href",
         nullptr, {el("a", "", {{"id", "t"}}, {el("span", "s")})}, "an href under a:link"},
        {"details[open] p{color:#c00}", {el("details", "", {{"id", "t"}}, {el("summary", "s"), el("p", "p")})}, "open", "",
         {el("details", "", {{"id", "t"}, {"open", ""}}, {el("summary", "s"), el("p", "p")})}, "details[open]"},
        {".big p{display:flex}", {el("div", "", {{"id", "t"}}, {el("p", "", {}, {el("span", "a"), el("span", "b")})})}, "class",
         "big", {el("div", "", {{"id", "t"}, {"class", "big"}}, {el("p", "", {}, {el("span", "a"), el("span", "b")})})},
         "a descendant's display flips"},
        {".dark{--k:#fff} p{color:var(--k, #000)}", {el("div", "", {{"id", "t"}}, {el("p", "x")})}, "class", "dark",
         {el("div", "", {{"id", "t"}, {"class", "dark"}}, {el("p", "x")})}, "a class declaring a custom property"},
    };
    for (const Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, k.before, body);
        auto t = doc->root()->select_one("#t");
        CHECK(t != nullptr);
        if (!t) continue;
        const bool set = doc->set_element_attribute(t, k.name, k.value);
        if (!set) std::printf("  refused (%s): %s\n", doc->refusal(), k.what);
        CHECK(set);
        structureMatchesFresh(c, doc, k.sheet, k.after, k.what);
    }
    // An attribute change and a pseudo-class flip in one session that one rule reads together.
    {
        const char* sheet = ".open:hover .x{display:none}";
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, {el("div", "", {{"id", "t"}}, {el("span", "x", {{"class", "x"}}), txt(" y")})},
                                     body);
        auto t = doc->root()->select_one("#t");
        CHECK(t && doc->set_element_attribute(t, "class", "open"));
        CHECK(t && doc->set_pseudo_classes({{t, {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, sheet, {el("div", "", {{"id", "t"}, {"class", "open"}}, {el("span", "x", {{"class", "x"}}), txt(" y")})},
                           {"t"}, "a class and a hover one rule reads together");
    }
    // Many siblings changed in one session under a sibling selector reach their parent's children once; a changed name
    // no rule names reaches nothing.
    {
        const char* sheet = ".x + .y{color:#0a0}";
        std::vector<Spec> kids;
        for (int n = 0; n < 200; n++) kids.push_back(el("i", "i"));
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        std::vector<litehtml::string_map> wanted(body->children().size());
        std::vector<std::pair<element::ptr, const litehtml::string_map*>> changes, unnamed;
        std::vector<litehtml::string_map> data(body->children().size());
        size_t at = 0;
        for (const auto& child : body->children()) {
            auto tag = std::dynamic_pointer_cast<litehtml::html_tag>(child);
            if (!tag) { at++; continue; }
            wanted[at] = tag->attributes();
            wanted[at]["class"] = "x";
            data[at] = tag->attributes();
            data[at]["data-q"] = "1";
            changes.emplace_back(child, &wanted[at]);
            unnamed.emplace_back(child, &data[at]);
            at++;
        }
        uint64_t steps = doc->predicate_steps();
        doc->attribute_reach(changes);
        const uint64_t walked = doc->predicate_steps() - steps;
        const uint64_t nodes = 2 * kids.size() + 1;   // the <i>s, their texts, the body
        if (walked > 2 * nodes) std::printf("  %llu steps for %zu sibling changes over %llu nodes\n", (unsigned long long)walked, changes.size(), (unsigned long long)nodes);
        CHECK(walked <= 2 * nodes);
        steps = doc->predicate_steps();
        CHECK(doc->attribute_reach(unnamed).empty());
        CHECK(doc->predicate_steps() - steps <= nodes);
    }
    // Nested changes reach once: each element of the outer subtree visited once, and the inner one once more.
    {
        const char* sheet = ".a p{color:#c00}";
        std::vector<Spec> kids = {el("div", "", {{"id", "o"}}, {el("div", "", {{"id", "i"}}, {el("p", "x"), txt(" y")}), el("span", "z")})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto o = doc->root()->select_one("#o");
        auto i = doc->root()->select_one("#i");
        CHECK(o && i);
        if (o && i) {
            uint64_t nodes = 0;
            std::vector<element::ptr> stack{o};
            while (!stack.empty()) {
                element::ptr next = stack.back();
                stack.pop_back();
                nodes++;
                for (const auto& child : next->children()) stack.push_back(child);
            }
            litehtml::string_map wantedI = std::static_pointer_cast<litehtml::html_tag>(i)->attributes();
            litehtml::string_map wantedO = std::static_pointer_cast<litehtml::html_tag>(o)->attributes();
            wantedI["class"] = "a";
            wantedO["class"] = "a";
            const uint64_t steps = doc->predicate_steps();
            doc->attribute_reach({{i, &wantedI}, {o, &wantedO}});
            // Each change a step (its names compared), #o's subtree's nodes once each, and #i once more.
            if (doc->predicate_steps() - steps != nodes + 3) std::printf("  steps %llu, nodes %llu\n", (unsigned long long)(doc->predicate_steps() - steps), (unsigned long long)nodes);
            CHECK(doc->predicate_steps() - steps == nodes + 3);
            CHECK(doc->set_element_attribute(i, "class", "a"));
            CHECK(doc->set_element_attribute(o, "class", "a"));
            structureMatchesFresh(c, doc, sheet,
                                  {el("div", "", {{"id", "o"}, {"class", "a"}},
                                      {el("div", "", {{"id", "i"}, {"class", "a"}}, {el("p", "x"), txt(" y")}), el("span", "z")})},
                                  "two nested classes in one session");
        }
    }
}

// VENDOR.md edit 17: a <table>'s presentational attributes (parse_attributes maps them to styles) and a class that
// changes its display are patched, each as a document built with it.
static void testTableAttributesMatchFresh() {
    auto table = [](const litehtml::string_map& attrs) {
        litehtml::string_map with = attrs;
        with["id"] = "t";
        return std::vector<Spec>{el("table", "", with, {el("tbody", "", {}, {el("tr", "", {}, {el("td", "c")})})}), el("p", "after")};
    };
    const char* tableSheet = ".t{display:block}";
    const std::pair<const char*, const char*> changes[] = {
        {"border", "2"}, {"bgcolor", "#ccc"}, {"width", "120"}, {"cellspacing", "4"}, {"class", "t"}};
    for (const auto& [name, value] : changes) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, tableSheet, table({}), body);
        const bool set = doc->set_element_attribute(doc->root()->select_one("#t"), name, value);
        if (!set) std::printf("  refused (%s): a table's %s\n", doc->refusal(), name);
        CHECK(set);
        structureMatchesFresh(c, doc, tableSheet, table({{name, value}}), name);
    }
}

// VENDOR.md edits 16, 18: structure and text inside an <svg>, which paints its subtree itself (its render item an image),
// replace the svg's render subtree, each as a document built with the change; the tree is never rebuilt.
static void testStructureInsideAnSvg() {
    auto svg = [](std::vector<Spec> shapes) {
        return std::vector<Spec>{el("svg", "", {{"id", "s"}, {"width", "40"}, {"height", "40"}, {"viewBox", "0 0 40 40"}}, std::move(shapes)),
                                 el("p", "after")};
    };
    auto circle = [](const char* id, const char* cx) {
        return el("circle", "", {{"id", id}, {"cx", cx}, {"cy", "10"}, {"r", "5"}, {"fill", "red"}});
    };
    auto rect = [] { return el("rect", "", {{"x", "20"}, {"y", "20"}, {"width", "5"}, {"height", "5"}, {"fill", "blue"}}); };
    auto label = [](const char* text) { return el("text", "", {{"id", "tx"}, {"x", "2"}, {"y", "35"}}, {txt(text)}); };
    struct Case {
        std::vector<Spec> before;
        std::function<bool(const litehtml::document::ptr&)> change;
        std::vector<Spec> after;
        const char* what;
    };
    const Case cases[] = {
        {svg({circle("a", "10")}),
         [&](const litehtml::document::ptr& doc) { return doc->insert_subtree(doc->root()->select_one("#s"), 0, build(doc, circle("b", "30"))); },
         svg({circle("b", "30"), circle("a", "10")}), "a circle inserted"},
        {svg({circle("a", "10"), circle("b", "30")}),
         [&](const litehtml::document::ptr& doc) { return doc->remove_subtree(doc->root()->select_one("#b")); },
         svg({circle("a", "10")}), "a circle removed"},
        {svg({circle("a", "10")}),
         [&](const litehtml::document::ptr& doc) {
             return doc->insert_subtree(doc->root()->select_one("#s"), 1, build(doc, el("g", "", {{"id", "g"}}, {rect()})));
         },
         svg({circle("a", "10"), el("g", "", {{"id", "g"}}, {rect()})}), "a <g> with a <rect> inserted"},
        {svg({el("g", "", {{"id", "g"}}, {rect()})}),
         [&](const litehtml::document::ptr& doc) {
             return replaceKids(doc, doc->root()->select_one("#g"), {build(doc, circle("a", "10")), build(doc, rect())});
         },
         svg({el("g", "", {{"id", "g"}}, {circle("a", "10"), rect()})}), "a <g>'s new children"},
        {svg({label("hi")}),
         [&](const litehtml::document::ptr& doc) {
             auto text = doc->root()->select_one("#tx");
             std::vector<element::ptr> pieces;
             return text && doc->replace_text(text, 0, text->children().size(), "bye now", pieces);
         },
         svg({label("bye now")}), "an svg <text>'s data"},
        {svg({el("use", "", {{"href", "#c"}})}),
         [&](const litehtml::document::ptr& doc) { return doc->insert_subtree(doc->root()->select_one("#s"), 0, build(doc, circle("c", "20"))); },
         svg({circle("c", "20"), el("use", "", {{"href", "#c"}})}), "a <use>'s target inserted"},
    };
    for (const Case& k : cases) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, "", k.before, body);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        const bool changed = k.change(doc);
        if (!changed) std::printf("  refused (%s): %s\n", doc->refusal(), k.what);
        CHECK(changed);
        structureMatchesFresh(c, doc, "", k.after, k.what);
        CHECK(!observer.replaced.empty());
        doc->set_render_observer(nullptr);
    }
}

// VENDOR.md edit 17: a ::before or ::after that reads var() follows its ancestors' custom properties, though its owner
// reads none: the owner is matched again (its pseudo-elements made again).
static void testPseudoElementsReadingVar() {
    const char* sheet = ".dark{--k:#c00} #w:hover{--k:#0a0} p::before{content:'B';color:var(--k,#000)}";
    auto page = [](const litehtml::string_map& attrs) {
        litehtml::string_map w = attrs;
        w["id"] = "w";
        return std::vector<Spec>{el("div", "", w, {el("p", "x")})};
    };
    const std::pair<const char*, const char*> changes[] = {{"class", "dark"}, {"style", "--k:#00f"}};
    for (const auto& [name, value] : changes) {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, page({}), body);
        CHECK(doc->set_element_attribute(doc->root()->select_one("#w"), name, value));
        structureMatchesFresh(c, doc, sheet, page({{name, value}}), name);
    }
    {
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, page({}), body);
        CHECK(doc->set_pseudo_classes({{doc->root()->select_one("#w"), {{litehtml::_hover_, true}}}}));
        pseudoMatchesFresh(c, doc, sheet, page({}), {"w"}, "a hover declaring the custom property a ::before reads");
    }
}

// Twidget edit 84: a document built as WidgetRuntime builds one: every element counted by external_element_allowed, its
// text through append_text (which asks the piece cap), then finalized and laid out.
static void countedKid(const litehtml::document::ptr& doc, const element::ptr& parent, const Spec& spec, int depth) {
    if (!doc->external_element_allowed(depth)) return;
    auto e = make(doc, spec.tag.c_str(), spec.attrs);
    add(doc, parent, e);
    if (!spec.text.empty()) text(doc, e, spec.text.c_str());
    for (const Spec& kid : spec.kids) {
        if (kid.tag.empty()) text(doc, e, kid.text.c_str());
        else countedKid(doc, e, kid, depth + 1);
    }
}

static litehtml::document::ptr countedDocument(PaintContainer& c, const std::vector<std::string>& sheets,
                                               const std::vector<Spec>& kids) {
    auto doc = std::make_shared<litehtml::document>(&c);
    doc->set_document_mode(litehtml::no_quirks_mode);
    doc->external_element_allowed(0);
    auto root = make(doc, "html");
    doc->external_element_allowed(1);
    auto head = make(doc, "head");
    add(doc, root, head);
    for (const std::string& sheet : sheets) {
        doc->external_element_allowed(2);
        auto style = make(doc, "style");
        add(doc, head, style);
        if (!sheet.empty()) text(doc, style, sheet.c_str());
    }
    doc->external_element_allowed(1);
    auto body = make(doc, "body", {{"style", "margin:0"}});
    add(doc, root, body);
    for (const Spec& kid : kids) {
        if (kid.tag.empty()) text(doc, body, kid.text.c_str());
        else countedKid(doc, body, kid, 2);
    }
    doc->finalize_from_external_root(root, litehtml::telegram_master_css());
    doc->render(litehtml::pixel_t(200.0f));
    return doc;
}

// Commits and lays out `doc`, then compares it with countedDocument(kids): placements, height, everything painted, and
// litehtml's counts and caps (pieces, elements, pseudo-elements, style bytes, and which caps were reached).
static bool replayMatchesFresh(PaintContainer& c, const litehtml::document::ptr& doc, const std::vector<std::string>& sheets,
                               const std::vector<Spec>& kids, const std::string& what) {
    doc->commit_patch();
    doc->render(litehtml::pixel_t(200.0f));
    PaintContainer fresh;
    auto reference = countedDocument(fresh, sheets, kids);
    const bool same = dump_of(doc) == dump_of(reference) && float(doc->height()) == float(reference->height()) &&
                      painted(c, doc) == painted(fresh, reference) && doc->text_elements() == reference->text_elements() &&
                      doc->build_elements() == reference->build_elements() &&
                      doc->pseudo_elements() == reference->pseudo_elements() &&
                      doc->style_bytes_charged() == reference->style_bytes_charged() &&
                      doc->text_limited() == reference->text_limited() && doc->pseudo_limited() == reference->pseudo_limited() &&
                      doc->style_bytes_limited() == reference->style_bytes_limited();
    if (!same) {
        std::printf("  differs from a build after %s: pieces %d/%d, elements %d/%d, pseudo %d/%d, style bytes %zu/%zu, "
                    "limited %d%d%d/%d%d%d, dump %s, painted %s\n",
                    what.c_str(), doc->text_elements(), reference->text_elements(), doc->build_elements(),
                    reference->build_elements(), doc->pseudo_elements(), reference->pseudo_elements(),
                    doc->style_bytes_charged(), reference->style_bytes_charged(), doc->text_limited(), doc->pseudo_limited(),
                    doc->style_bytes_limited(), reference->text_limited(), reference->pseudo_limited(),
                    reference->style_bytes_limited(), dump_of(doc) == dump_of(reference) ? "same" : "differs",
                    painted(c, doc) == painted(fresh, reference) ? "same" : "differs");
    }
    CHECK(same);
    return same;
}

// The range of `parent`'s text pieces (its generated children aside), for replace_text.
static std::pair<size_t, size_t> textRange(const element::ptr& parent) {
    size_t first = 0, count = 0, at = 0;
    for (const auto& child : parent->children()) {
        if (child->is_text()) {
            if (count == 0) first = at;
            count++;
        }
        at++;
    }
    return {first, count};
}

static std::string words(int n, const char* word = "w") {
    std::string out;
    for (int i = 0; i < n; i++) {
        if (i) out += ' ';
        out += word;
    }
    return out;
}

// Twidget edit 84 (Review Focus 2): one element matched by two ::before content rules at the text-piece cap. A build
// makes the second rule's content while the first's is alive, so the cap cuts it short; a text patch that moves the
// document text near the cap is followed by the replay, which cuts it where a build does.
static void testTwoContentRulesAtTheCapReplayAsABuild() {
    const std::vector<std::string> sheets = {"p.a::before{content:\"a1 a2\"} p.b::before{content:\"b1 b2 b3\"}"};
    const std::string filler = words(4993);
    auto kids = [&](const char* span) {
        return std::vector<Spec>{el("p", filler.c_str()), el("p", "x", {{"class", "a b"}}), el("span", span, {{"id", "s"}})};
    };
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids("s"));
    CHECK(!doc->text_limited());
    auto span = doc->root()->select_one("#s");
    const uint64_t replays = doc->generated_replays();
    std::vector<element::ptr> made;
    CHECK(doc->can_replace_text(span, 0, span->children().size(), "s t u v"));
    CHECK(doc->replace_text(span, 0, span->children().size(), "s t u v", made));
    replayMatchesFresh(c, doc, sheets, kids("s t u v"), "two content rules at the cap");
    CHECK(doc->text_limited());
    CHECK(doc->generated_replays() == replays + 1);
}

// Twidget edit 84: near a cap a patch is followed by the replay of the style pass in a build's order, so the generated
// content (::before, ::after, a form control's parts) is cut where a fresh build cuts it, whatever the patch's order.
static void testReplayFollowsBuildOrder() {
    // The text-piece cap: words inserted before ::before content, removed, and a text grown under it.
    {
        const std::vector<std::string> sheets = {"p::before{content:\"c1 c2 c3\"}"};
        const std::string filler = words(4980);
        std::vector<Spec> kids = {el("div", filler.c_str()), el("p", "one", {{"id", "one"}}), el("p", "two"), el("p", "three")};
        PaintContainer c;
        auto doc = countedDocument(c, sheets, kids);
        element::ptr body = doc->root()->select_one("body");
        auto inserted = build(doc, el("p", "a b c d", {{"id", "new"}}));
        CHECK(doc->can_insert_subtree(body, 0, inserted));
        CHECK(doc->insert_subtree(body, 0, inserted));
        inserted.reset();   // the piece counts compare what the documents hold
        kids.insert(kids.begin(), el("p", "a b c d", {{"id", "new"}}));
        replayMatchesFresh(c, doc, sheets, kids, "words inserted before the content");
        CHECK(doc->can_remove_subtree(doc->root()->select_one("#new")));
        CHECK(doc->remove_subtree(doc->root()->select_one("#new")));
        kids.erase(kids.begin());
        replayMatchesFresh(c, doc, sheets, kids, "the words removed");
        auto one = doc->root()->select_one("#one");
        std::vector<element::ptr> made;
        const auto [first, count] = textRange(one);
        CHECK(doc->replace_text(one, first, count, "one more words here", made));
        kids[1] = el("p", "one more words here", {{"id", "one"}});
        replayMatchesFresh(c, doc, sheets, kids, "a text grown under the content");
    }
    // The pseudo-element cap (edit 19): <i>s with two pseudo-elements each, 15 short of 20,000; three more fit and three
    // more cross it, and their removal brings back what was cut.
    {
        const std::vector<std::string> sheets = {"i::before,i::after{content:''}"};
        std::vector<Spec> is;
        for (int n = 0; n < 6660; n++) is.push_back(el("i"));
        std::vector<Spec> kids = {el("div", "", {{"id", "d"}}, is)};
        PaintContainer c;
        auto doc = countedDocument(c, sheets, kids);
        CHECK(!doc->pseudo_limited());
        auto d = doc->root()->select_one("#d");
        for (int round = 0; round < 2; round++) {
            for (int n = 0; n < 3; n++) {
                auto i = build(doc, el("i", "", {{"class", "added"}}));
                CHECK(doc->insert_subtree(d, 0, i));
                kids[0].kids.insert(kids[0].kids.begin(), el("i", "", {{"class", "added"}}));
            }
            replayMatchesFresh(c, doc, sheets, kids, round ? "past the pseudo-element cap" : "up to the pseudo-element cap");
        }
        CHECK(doc->pseudo_limited());
        for (int n = 0; n < 6; n++) {
            CHECK(doc->remove_subtree(doc->root()->select_one("i.added")));
            kids[0].kids.erase(kids[0].kids.begin());
        }
        replayMatchesFresh(c, doc, sheets, kids, "back under the pseudo-element cap");
        CHECK(!doc->pseudo_limited());
    }
    // A form control's parts (lh-*), made between the master and author passes, with content on one of them: an input's
    // type changed to range, then a text grown before it, near the text-piece cap.
    {
        const std::vector<std::string> sheets = {
            "lh-range-thumb::before{content:\"B1 B2 B3 B4 B5 B6 B7 B8 B9 B10\"} p::after{content:\"q1 q2\"}"};
        for (int fill : {4980, 4990, 4996}) {
            const std::string filler = words(fill);
            auto kids = [&](const char* type, const char* text) {
                return std::vector<Spec>{el("p", text, {{"id", "p"}}), el("div", filler.c_str()),
                                         el("input", "", {{"id", "in"}, {"type", type}}), el("p", "after")};
            };
            PaintContainer c;
            auto doc = countedDocument(c, sheets, kids("text", "a"));
            CHECK(doc->set_element_attribute(doc->root()->select_one("#in"), "type", "range"));
            replayMatchesFresh(c, doc, sheets, kids("range", "a"), "an input made a range at " + std::to_string(fill));
            auto p = doc->root()->select_one("#p");
            std::vector<element::ptr> made;
            const auto [first, count] = textRange(p);
            CHECK(doc->replace_text(p, first, count, "a b c", made));
            replayMatchesFresh(c, doc, sheets, kids("range", "a b c"), "a text grown before it at " + std::to_string(fill));
        }
    }
    // Counters read by content at the cap: an item inserted first renumbers every item after it.
    {
        const std::vector<std::string> sheets = {"ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n) \". \"}"};
        const std::string filler = words(4960);
        std::vector<Spec> items;
        for (int n = 0; n < 12; n++) items.push_back(el("li", "item"));
        std::vector<Spec> kids = {el("p", filler.c_str()), el("ol", "", {{"id", "ol"}}, items)};
        PaintContainer c;
        auto doc = countedDocument(c, sheets, kids);
        auto ol = doc->root()->select_one("#ol");
        auto li = build(doc, el("li", "first"));
        CHECK(doc->insert_subtree(ol, 0, li));
        kids[1].kids.insert(kids[1].kids.begin(), el("li", "first"));
        replayMatchesFresh(c, doc, sheets, kids, "an item inserted first, counters read by content at the cap");
    }
}

// Twidget edit 84 (Review Focus 3): a class that pushes the style bytes past 16 MiB, then its removal. The replay charges
// from zero in a build's order: the same elements lose their declarations as in a fresh build.
static void testStyleBytesReplayFromZero() {
    const std::string big(24000, 'a');
    // The class's declaration is larger than one element's, so it passes the budget whatever room is left.
    const std::vector<std::string> sheets = {"*{--big:" + big + "} .x{--more:" + std::string(30000, 'b') + "}"};
    auto kids = [](int elements, const char* cls) {
        std::vector<Spec> is;
        for (int n = 0; n < elements; n++) is.push_back(el("i"));
        litehtml::string_map attrs{{"id", "t"}};
        if (*cls) attrs["class"] = cls;
        return std::vector<Spec>{el("p", "target", attrs), el("div", "", {}, is)};
    };
    // Sized from a probe: the elements that leave room for three more of the --big declarations.
    int elements = 0;
    {
        PaintContainer probe;
        auto none = countedDocument(probe, sheets, kids(0, ""));
        PaintContainer probe2;
        auto hundred = countedDocument(probe2, sheets, kids(100, ""));
        const size_t perElement = (hundred->style_bytes_charged() - none->style_bytes_charged()) / 100;
        elements = int((litehtml::document::max_style_bytes - none->style_bytes_charged()) / perElement);
    }
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids(elements, ""));
    CHECK(!doc->style_bytes_limited());
    auto count = [&c] { return std::count(c.limits.begin(), c.limits.end(), std::string("style-bytes")); };
    CHECK(doc->set_element_attribute(doc->root()->select_one("#t"), "class", "x"));
    replayMatchesFresh(c, doc, sheets, kids(elements, "x"), "a class past the style budget");
    CHECK(doc->style_bytes_limited());
    // The container hears the cap each time a pass reaches it (the commit's own, the replay's); the caller posts a kind
    // once each time it is newly reached. Going back under reports nothing.
    const auto reported = count();
    CHECK(reported >= 1);
    CHECK(doc->set_element_attribute(doc->root()->select_one("#t"), "class", nullptr));
    replayMatchesFresh(c, doc, sheets, kids(elements, ""), "the class removed");
    CHECK(!doc->style_bytes_limited());
    CHECK(count() == reported);
}

// Twidget edit 84: a re-match whose generated content comes out equal changes nothing the cut reads, so no replay runs.
static void testPaintOnlyChangeDoesNotReplay() {
    const std::vector<std::string> sheets = {"p.a::before{content:\"a1 a2\"} p.b::before{content:\"b1 b2 b3\"}"};
    const std::string filler = words(4993);
    std::vector<Spec> kids = {el("p", filler.c_str()), el("p", "x", {{"class", "a b"}, {"id", "x"}}),
                              el("span", "s t u v", {{"id", "s"}})};
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids);
    CHECK(doc->text_limited());
    const uint64_t replays = doc->generated_replays();
    CHECK(doc->set_element_attribute(doc->root()->select_one("#x"), "style", "color:#c00"));
    kids[1].attrs["style"] = "color:#c00";
    replayMatchesFresh(c, doc, sheets, kids, "a paint-only change beside content at the cap");
    CHECK(doc->generated_replays() == replays);
}

// Edit 84: a build's master pass gives every <summary> its triangle before the author pass drops the .x ones, so a build
// holds them all at once. Near the text-piece cap that peak, not the content left after the author pass, decides where
// a build cuts: a text that brings the document text 50 short of the cap cuts the plain summaries' triangles.
static void testMasterContentCountsAtTheTextCap() {
    const std::vector<std::string> sheets = {"summary.x::before{content:none}"};
    auto kids = [&](int fill) {
        std::vector<Spec> k;
        k.push_back(el("p", words(fill).c_str(), {{"id", "p"}}));
        for (int n = 0; n < 100; n++) k.push_back(el("summary", "s", {{"class", "x"}}));
        for (int n = 0; n < 10; n++) k.push_back(el("summary", "t"));
        return k;
    };
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids(1000));
    CHECK(!doc->text_limited());
    const int fill = 1000 + (litehtml::document::max_text_elements - 50 - doc->document_text_pieces()) / 2;
    auto p = doc->root()->select_one("#p");
    const auto [first, count] = textRange(p);
    std::vector<element::ptr> made;
    CHECK(doc->can_replace_text(p, first, count, words(fill).c_str()));
    CHECK(doc->replace_text(p, first, count, words(fill).c_str(), made));
    made.clear();
    replayMatchesFresh(c, doc, sheets, kids(fill), "a text near the cap beside master content an author rule drops");
}

// The same at the pseudo-element cap: the master pass's triangles count toward 20,000 with the elements until the author
// pass drops them, so elements inserted near the cap cut the plain summaries' triangles in a build.
static void testMasterContentCountsAtThePseudoCap() {
    const std::vector<std::string> sheets = {"summary.x::before{content:none}"};
    // html, head, the <style>, body, the div and 110 summaries: the master pass's peak 20 short of 20,000.
    const int is = litehtml::document::max_external_elements - 20 - 110 - 115;
    std::vector<Spec> filler;
    for (int n = 0; n < is; n++) filler.push_back(el("i"));
    std::vector<Spec> kids = {el("div", "", {{"id", "d"}}, filler)};
    for (int n = 0; n < 100; n++) kids.push_back(el("summary", "s", {{"class", "x"}}));
    for (int n = 0; n < 10; n++) kids.push_back(el("summary", "t"));
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids);
    CHECK(!doc->pseudo_limited());
    auto d = doc->root()->select_one("#d");
    for (int n = 0; n < 30; n++) {
        CHECK(doc->insert_subtree(d, 0, build(doc, el("i", "", {{"class", "added"}}))));
        kids[0].kids.insert(kids[0].kids.begin(), el("i", "", {{"class", "added"}}));
    }
    replayMatchesFresh(c, doc, sheets, kids, "elements inserted near the cap beside master content an author rule drops");
}

// Edit 42: whether a subject positional rule reaches a parent's children is asked once per parent in a session, however
// many of its children the session removes: a cut that moves removes thousands under one parent in one patch.
static void testPositionParentsAreAskedOncePerSession() {
    for (const char* tag : {"li", "p"}) {
        const std::vector<std::string> sheets = {"li:first-child{color:#c00}"};
        std::vector<Spec> items;
        for (int n = 0; n < 2000; n++) items.push_back(el(tag, "x"));
        std::vector<Spec> kids = {el("ol", "", {{"id", "o"}}, items)};
        PaintContainer c;
        auto doc = countedDocument(c, sheets, kids);
        auto o = doc->root()->select_one("#o");
        const uint64_t before = doc->position_scans();
        {
            const litehtml::elements_list children = o->children();
            for (const auto& child : children) {
                if (!child->is_text()) CHECK(doc->remove_subtree(child));
            }
        }
        const uint64_t scans = doc->position_scans() - before;
        if (scans > 4000) std::printf("  %s: %llu children scanned for 2,000 removals\n", tag, (unsigned long long)scans);
        CHECK(scans <= 4000);
        kids[0].kids.clear();
        replayMatchesFresh(c, doc, sheets, kids, std::string("every ") + tag + " removed");
    }
    // A parent no rule reached is asked again once an element a rule names goes in: the second <li> inserted before the
    // first in one session takes :first-child from it.
    const std::vector<std::string> sheets = {"li:first-child{color:#c00}"};
    std::vector<Spec> kids = {el("ol", "", {{"id", "o"}})};
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids);
    auto o = doc->root()->select_one("#o");
    CHECK(doc->insert_subtree(o, 0, build(doc, el("li", "a"))));
    CHECK(doc->insert_subtree(o, 0, build(doc, el("li", "b"))));
    kids[0].kids = {el("li", "b"), el("li", "a")};
    replayMatchesFresh(c, doc, sheets, kids, "two <li>s inserted in one session");
}

// Edit 84: the replay's walks visit each node a bounded number of times, whatever the depth: an element whose ::after
// waits for its subtree is found without climbing from every element below it. Spines 200 deep with a leaf after each
// level's child are the shape where climbing costs the depth at every leaf.
static void testReplayWalksAreLinear() {
    const std::vector<std::string> sheets = {"s::before{content:'x'}"};
    std::function<Spec(int)> spine = [&](int level) {
        return level == 0 ? el("i") : el("i", "", {}, {spine(level - 1), el("u")});
    };
    auto kids = [&](int fill) {
        std::vector<Spec> k = {el("p", words(fill).c_str(), {{"id", "p"}}), el("s")};
        for (int n = 0; n < 15; n++) k.push_back(spine(200));
        return k;
    };
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids(1000));
    // The document's text grown to the cap: the ::before's piece is past it, and the commit replays.
    const int fill = 1000 + (litehtml::document::max_text_elements + 1 - doc->document_text_pieces()) / 2;
    auto p = doc->root()->select_one("#p");
    const auto [first, count] = textRange(p);
    std::vector<element::ptr> made;
    const uint64_t replays = doc->generated_replays();
    CHECK(doc->replace_text(p, first, count, words(fill).c_str(), made));
    made.clear();
    replayMatchesFresh(c, doc, sheets, kids(fill), "a word near the cap beside deep spines");
    CHECK(doc->generated_replays() == replays + 1);
    // The tree's nodes: its elements and its text pieces.
    const int64_t elements = doc->build_elements();
    const int64_t nodes = elements + doc->text_elements();
    if (doc->last_replay_visits() > 20 * nodes)
        std::printf("  the replay visited %lld nodes for %lld in the tree\n", (long long)doc->last_replay_visits(),
                    (long long)nodes);
    CHECK(doc->last_replay_visits() <= 20 * nodes);
    CHECK(doc->last_replay_weight() >= elements);
}

// Edit 85: fix_tables_layout's list of tabular render items is let go once the anonymous table boxes are made. Kept, it
// held the items a later init() replaced, and with them the text pieces under them: a <p> in a <div> straight under a
// <tr> (no <table>) kept its replaced text alive, one piece more than a fresh build counts.
static void testFixedTablesHoldNoReplacedText() {
    const std::vector<std::string> sheets = {".box{padding:2px;border:1px solid #000} .x{color:#c00}"};
    auto kids = [&](const char* inner) {
        return std::vector<Spec>{el("tbody", "", {}, {el("tr", "", {}, {el("td", "tb", {{"class", "x"}}),
                                                                          el("div", "", {{"class", "box"}}, {el("p", inner, {{"id", "p"}}), el("span", "s")})})}),
                                 el("q", "quote")};
    };
    PaintContainer c;
    auto doc = countedDocument(c, sheets, kids("inner"));
    auto p = doc->root()->select_one("#p");
    const auto [first, count] = textRange(p);
    std::vector<element::ptr> made;
    CHECK(doc->replace_text(p, first, count, "two words", made));
    made.clear();
    replayMatchesFresh(c, doc, sheets, kids("two words"), "a text in a <p> in a <div> straight under a <tr>");
}

// Edit 86: an inline-flex or inline-grid paints its children in its own stacking context, as an inline-block does, and
// the block and float passes do not reach them again: a block child is filled once and its shadow drawn once (a
// translucent one composited twice before), and a hit test at its centre finds it.
static void testAnInlineFlexPaintsItsChildrenOnce() {
    for (const char* display : {"inline-flex", "inline-grid"}) {
        const std::string sheet = std::string(".f{display:") + display + "} .b{display:block;width:20px;height:10px;"
                                  "background:#00aa00;box-shadow:0 0 0 1px rgba(0,0,0,.1)}";
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet.c_str(), {el("p", "", {}, {el("span", "", {{"class", "f"}}, {el("div", "", {{"class", "b"}, {"id", "b"}})})})}, body);
        const std::string paint = painted(c, doc);
        size_t fills = 0, shadows = 0;
        for (size_t at = paint.find("fill "); at != std::string::npos; at = paint.find("fill ", at + 1)) {
            fills += paint.compare(paint.find(' ', paint.find(' ', at) + 1) + 1, 10, "0.170.0.25") == 0;
        }
        for (size_t at = paint.find("shadow "); at != std::string::npos; at = paint.find("shadow ", at + 1)) shadows++;
        if (fills != 1 || shadows != 1) std::printf("  %s: %zu fills, %zu shadows\n%s", display, fills, shadows, paint.c_str());
        CHECK(fills == 1);
        CHECK(shadows == 1);
        auto b = doc->root()->select_one("#b");
        CHECK(b != nullptr);
        if (b) {
            const litehtml::position place = b->get_placement();
            const float x = float(place.x) + float(place.width) / 2, y = float(place.y) + float(place.height) / 2;
            CHECK(doc->root_render()->get_element_by_point(x, y, x, y, nullptr) == b);
        }
    }
}

// Edit 87: a positioned box is filed under its nearest transformed or contained ancestor (add_positioned), so a restyle
// that keeps the render tree and the positions but makes a transform or `contain` appear or go fetches the positioned
// lists again: kept, the box stayed on the list of an ancestor that no longer paints it, and nothing painted it.
static void testATransformGoingKeepsPositionedPaint() {
    const char* sheet = ".t{transform:translateX(5px)} .c{contain:paint} .r{position:absolute;left:2px;top:2px;width:10px;"
                        "height:10px;background:#0000ff}";
    for (const char* holder : {"t", "c"}) {
        std::vector<Spec> kids = {el("div", "", {{"id", "d"}, {"class", holder}}, {el("div", "", {{"class", "r"}})}),
                                  el("p", "after")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto d = doc->root()->select_one("#d");
        CHECK(d && doc->set_element_attribute(d, "class", ""));
        kids[0].attrs["class"] = "";
        structureMatchesFresh(c, doc, sheet, kids, (std::string("the ") + holder + " holder's class removed").c_str());
        CHECK(painted(c, doc).find("0.0.255.255") != std::string::npos);
        // And back.
        CHECK(d && doc->set_element_attribute(d, "class", holder));
        kids[0].attrs["class"] = holder;
        structureMatchesFresh(c, doc, sheet, kids, (std::string("the ") + holder + " holder's class back").c_str());
    }
}

// Edit 88: structure beside :empty patches. A parent whose emptiness an insertion or a removal flips is matched again at
// the commit, its own rules and content (:empty, :not(:empty)::before), and with sibling combinators in the sheets its
// later siblings' subtrees (.e:empty + p), whose boxes and content a rule can change, and the var() readers below it
// follow.
// Edit 90: sessions of insertions and removals under positional and sibling selectors, each equal to a fresh build: an
// item whose box does not change keeps its render item, one whose box the match changes is a seed.
static void testStructureSessionsUnderPositionalSelectors() {
    // Backgrounds as background-color: the shorthand declares background-attachment, which apply_retag does not call
    // paint-only, so an item a rule starts or stops colouring would be replaced for that alone.
    const char* sheet = "li:nth-child(2n){color:#f00;background-color:#eee} li + li{margin-top:3px} .x ~ li{font-weight:bold}"
                        " li:last-child{background-color:#0f0} li:first-child span{color:#00f}";
    struct Session {
        const char* name;
        const char* extra; // appended to the sheet
        std::function<bool(const litehtml::document::ptr&, const element::ptr&, std::vector<Spec>&)> patch;
        const char* boundary; // "": nothing replaced, every item that stays keeps its render item
    };
    const std::vector<Session> sessions = {
        {"an item inserted first", "",
         [](auto doc, auto list, auto& items) {
             items.insert(items.begin(), el("li", "n"));
             return doc->insert_subtree(list, 0, build(doc, el("li", "n")));
         },
         ""},
        {"an item inserted between the second and third", "",
         [](auto doc, auto list, auto& items) {
             items.insert(items.begin() + 2, el("li", "n"));
             return doc->insert_subtree(list, 2, build(doc, el("li", "n")));
         },
         ""},
        {"an item appended", "",
         [](auto doc, auto list, auto& items) {
             items.push_back(el("li", "n"));
             return doc->insert_subtree(list, list->children().size(), build(doc, el("li", "n")));
         },
         ""},
        {"the first removed", "",
         [](auto doc, auto list, auto& items) {
             items.erase(items.begin());
             return doc->remove_subtree(childAt(list, 0));
         },
         ""},
        {"the last removed", "",
         [](auto doc, auto list, auto& items) {
             items.pop_back();
             return doc->remove_subtree(childAt(list, list->children().size() - 1));
         },
         ""},
        {"the first removed and one appended", "",
         [](auto doc, auto list, auto& items) {
             items.erase(items.begin());
             items.push_back(el("li", "n"));
             return doc->remove_subtree(childAt(list, 0)) &&
                    doc->insert_subtree(list, list->children().size(), build(doc, el("li", "n")));
         },
         ""},
        {"a .y inserted before the last floats it", " .y + li{float:left;width:20px}",
         [](auto doc, auto list, auto& items) {
             items.insert(items.begin() + 2, el("li", "y", {{"class", "y"}}));
             return doc->insert_subtree(list, 2, build(doc, el("li", "y", {{"class", "y"}})));
         },
         "u"},
    };
    for (const Session& session : sessions) {
        const std::string sessionSheet = std::string(sheet) + session.extra;
        std::vector<Spec> items = {el("li", "", {}, {el("span", "a")}), el("li", "b", {{"class", "x"}}), el("li", "c")};
        std::vector<Spec> page = {el("ul", "", {{"id", "u"}}, items)};
        PaintContainer pc;
        element::ptr pageBody;
        auto patched = structureDocument(pc, sessionSheet.c_str(), page, pageBody);
        RecordingObserver observer;
        patched->set_render_observer(&observer);
        auto list = byId(pageBody, "u");
        // Held, so that an item made again cannot take a kept one's address.
        std::map<const element*, std::shared_ptr<litehtml::render_item>> held;
        for (const auto& child : list->children()) held[child.get()] = patched->live_item(*child);
        const std::shared_ptr<litehtml::render_item> listItem = patched->live_item(*list);
        CHECK(session.patch(patched, list, page[0].kids));
        // The removed items let go (their pieces count while alive).
        for (auto it = held.begin(); it != held.end();) it = it->first->parent() == list ? std::next(it) : held.erase(it);
        structureMatchesFresh(pc, patched, sessionSheet.c_str(), page, session.name);
        const std::string at = replacedAt(patched, observer);
        if (at != session.boundary)
            std::printf("  %s: replaced at \"%s\", want \"%s\" (%s)\n", session.name, at.c_str(), session.boundary,
                        patched->rebuild_reason().c_str());
        CHECK(at == session.boundary);
        if (!*session.boundary) {
            CHECK(patched->live_item(*list) == listItem);
            for (const auto& child : list->children()) {
                auto kept = held.find(child.get());
                if (kept != held.end()) CHECK(patched->live_item(*child) == kept->second);
            }
        }
        patched->set_render_observer(nullptr);
    }
}

// Edit 90: what a structure change under sibling and positional selectors matches again (take_restyled): the parent's
// element children from the first one the session changed, and their subtrees (rules that read preceding siblings only),
// or every child when a rule reads following siblings outside its subject.
static void testSiblingReachFollowsTheSelectors() {
    const auto restyledIds = [](const litehtml::document::ptr& doc) {
        std::set<std::string> ids;
        for (const auto& el : doc->take_restyled()) {
            const char* id = el->get_attr("id");
            if (id) ids.insert(id);
        }
        return ids;
    };
    struct Session {
        const char* name;
        const char* sheet;
        bool bold; // each item holds a <b id=b<item>>
        std::function<bool(const litehtml::document::ptr&, const element::ptr&, std::vector<Spec>&)> patch;
        std::set<std::string> restyled; // of the ids a, b, c, ba, bb, bc
    };
    const std::vector<Session> sessions = {
        {"an append under li + li", "li + li{color:#c00}", false,
         [](auto doc, auto list, auto& items) {
             items.push_back(el("li", "n"));
             return doc->insert_subtree(list, list->children().size(), build(doc, el("li", "n")));
         },
         {}},
        {"an insert at 1 under li + li", "li + li{color:#c00}", false,
         [](auto doc, auto list, auto& items) {
             items.insert(items.begin() + 1, el("li", "n"));
             return doc->insert_subtree(list, 1, build(doc, el("li", "n")));
         },
         {"b", "c"}},
        {"the first removed and one appended under li + li", "li + li{color:#c00}", false,
         [](auto doc, auto list, auto& items) {
             items.erase(items.begin());
             items.push_back(el("li", "n"));
             return doc->remove_subtree(childAt(list, 0)) &&
                    doc->insert_subtree(list, list->children().size(), build(doc, el("li", "n")));
         },
         {"b", "c"}},
        {"an append under li:last-child b", "li:last-child b{color:#c00}", true,
         [](auto doc, auto list, auto& items) {
             items.push_back(el("li", "n"));
             return doc->insert_subtree(list, list->children().size(), build(doc, el("li", "n")));
         },
         {"a", "b", "c", "ba", "bb", "bc"}},
    };
    for (const Session& session : sessions) {
        std::vector<Spec> items;
        for (const char* id : {"a", "b", "c"}) {
            if (session.bold)
                items.push_back(el("li", "", {{"id", id}}, {el("b", id, {{"id", std::string("b") + id}})}));
            else
                items.push_back(el("li", id, {{"id", id}}));
        }
        std::vector<Spec> page = {el("ul", "", {{"id", "u"}}, items)};
        PaintContainer pc;
        element::ptr pageBody;
        auto patched = structureDocument(pc, session.sheet, page, pageBody);
        RecordingObserver observer;
        patched->set_render_observer(&observer);
        CHECK(session.patch(patched, byId(pageBody, "u"), page[0].kids));
        patched->commit_patch();
        std::set<std::string> got = restyledIds(patched);
        structureMatchesFresh(pc, patched, session.sheet, page, session.name);
        std::set<std::string> wanted = session.restyled;
        // Only the items and their <b>s are asked about.
        const std::set<std::string> asked = {"a", "b", "c", "ba", "bb", "bc"};
        for (auto it = got.begin(); it != got.end();) it = asked.count(*it) ? std::next(it) : got.erase(it);
        if (got != wanted) {
            std::printf("  %s: restyled", session.name);
            for (const auto& id : got) std::printf(" %s", id.c_str());
            std::printf("\n");
        }
        CHECK(got == wanted);
        patched->set_render_observer(nullptr);
    }
}

// Edit 90: an element the commit matches again whose match changed nothing (no rule started or stopped matching, its
// declarations the same) is restyled but not reported to the render observer: it paints as it did. One whose match
// changed is reported.
static void testAnUnchangedReachIsNotReported() {
    const auto reported = [](const RecordingObserver& observer) {
        std::set<std::string> ids;
        for (const auto& [el, order] : observer.restyled) {
            const char* id = el->get_attr("id");
            if (id) ids.insert(id);
        }
        return ids;
    };
    struct Case {
        const char* sheet;
        std::set<std::string> wanted;
    };
    // An item inserted at 1: under li + li, b and c match as they did; under li:nth-child(2n) b, the <b>s of b and c
    // change parity.
    const std::vector<Case> cases = {{"li + li{color:#c00}", {}}, {"li:nth-child(2n) b{color:#c00}", {"bb", "bc"}}};
    for (const Case& k : cases) {
        std::vector<Spec> items;
        for (const char* id : {"a", "b", "c"}) items.push_back(el("li", "", {{"id", id}}, {el("b", id, {{"id", std::string("b") + id}})}));
        std::vector<Spec> page = {el("ul", "", {{"id", "u"}}, items)};
        PaintContainer pc;
        element::ptr pageBody;
        auto doc = structureDocument(pc, k.sheet, page, pageBody);
        RecordingObserver observer;
        doc->set_render_observer(&observer);
        CHECK(doc->insert_subtree(byId(pageBody, "u"), 1, build(doc, el("li", "n"))));
        page[0].kids.insert(page[0].kids.begin() + 1, el("li", "n"));
        structureMatchesFresh(pc, doc, k.sheet, page, k.sheet);
        const std::set<std::string> got = reported(observer);
        if (got != k.wanted) {
            std::printf("  %s: reported", k.sheet);
            for (const auto& id : got) std::printf(" %s", id.c_str());
            std::printf("\n");
        }
        CHECK(got == k.wanted);
        doc->set_render_observer(nullptr);
    }
}

// Edit 90: an element matched earlier in the session (an attribute no rule names set before a removal) is matched again by
// the reach: what it matches then may have changed with the structure.
static void testASessionsEarlierMatchIsMatchedAgainByTheReach() {
    const char* sheet = "li + li{color:#c00}";
    const auto list = [] {
        return std::vector<Spec>{el("ul", "", {{"id", "u"}}, {el("li", "a", {{"id", "a"}}), el("li", "b", {{"id", "b"}}), el("li", "c", {{"id", "c"}})})};
    };
    {
        std::vector<Spec> kids = list();
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->set_element_attribute(byId(body, "b"), "data-x", "1"));
        CHECK(doc->remove_subtree(byId(body, "a")));
        kids[0].kids[1].attrs["data-x"] = "1";
        kids[0].kids.erase(kids[0].kids.begin());
        structureMatchesFresh(c, doc, sheet, kids, "an attribute on b, then a removed");
    }
    {
        std::vector<Spec> kids = list();
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        CHECK(doc->set_element_attribute(byId(body, "a"), "data-x", "1"));
        CHECK(doc->insert_subtree(byId(body, "u"), 0, build(doc, el("li", "n"))));
        kids[0].kids[0].attrs["data-x"] = "1";
        kids[0].kids.insert(kids[0].kids.begin(), el("li", "n"));
        structureMatchesFresh(c, doc, sheet, kids, "an attribute on a, then an item inserted first");
    }
}

// Edit 88 with edit 90: an :empty flip reaches the flipped element's earlier siblings too when a backward positional
// pseudo-class has an `of S` list (:nth-last-child(1 of .e:empty) counts the following siblings S matches).
static void testAnEmptyFlipReachesEarlierSiblingsThroughOfS() {
    struct Case {
        const char* name;
        const char* sheet;
        std::vector<Spec> kids;
        bool fill; // into #d2: a span inserted, or its span removed
    };
    const std::vector<Case> cases = {
        {"a later sibling fills, in the subject", "div{height:5px} div:nth-last-child(1 of .e:empty){background-color:#c00}",
         {el("div", "", {{"class", "e"}, {"id", "d1"}}), el("div", "", {{"class", "e"}, {"id", "d2"}}), el("p", "x")}, true},
        {"a later sibling fills, outside the subject", "p{margin:0} div{height:5px} div:nth-last-child(1 of .e:empty) + p{color:#c00}",
         {el("div", "", {{"class", "e"}, {"id", "d1"}}), el("p", "x", {{"id", "p1"}}), el("div", "", {{"class", "e"}, {"id", "d2"}}),
          el("p", "y")},
         true},
        {"a later sibling empties", "div{height:5px} div:nth-last-child(1 of .e:empty){background-color:#c00}",
         {el("div", "", {{"class", "e"}, {"id", "d1"}}), el("div", "", {{"class", "e"}, {"id", "d2"}}, {el("span", "s")}), el("p", "x")},
         false},
    };
    for (const Case& k : cases) {
        std::vector<Spec> kids = k.kids;
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, kids, body);
        auto d2 = byId(body, "d2");
        for (Spec& kid : kids) {
            if (kid.attrs.count("id") && kid.attrs.at("id") == "d2") kid.kids = k.fill ? std::vector<Spec>{el("span", "s")} : std::vector<Spec>{};
        }
        CHECK(k.fill ? doc->insert_subtree(d2, 0, build(doc, el("span", "s"))) : doc->remove_subtree(childAt(d2, 0)));
        structureMatchesFresh(c, doc, k.sheet, kids, k.name);
    }
}

// Edits 88, 89: an empty parent holding a block-level ::before is a block formatting context, so blocks inserted into it
// could link; the flip of its :empty answer matches it again with the check a kept parent needs, and one whose box or
// more than its paint the flip changes is replaced, never linked into.
static void testAnEmptyParentsFlipBesideALink() {
    const char* const sheets[] = {
        ".e:empty::before{content:'';display:block;height:10px} .e:not(:empty){display:flex}",
        ".e:empty::before{content:'';display:block;height:10px} .e:not(:empty){display:grid;grid-template-columns:40px 40px}",
        ".e:empty::before{content:'';display:block;height:10px} .e:not(:empty){display:none}",
        ".e:empty::before{content:'';display:block;height:10px} .e:not(:empty){float:left;width:60px}",
        ".e:empty::before{content:'';display:block;height:10px} .e:not(:empty){font-size:30px;padding:1em}",
    };
    for (const char* sheet : sheets) {
        std::vector<Spec> kids = {el("div", "", {{"class", "e"}, {"id", "e"}}), el("p", "after")};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, sheet, kids, body);
        auto e = byId(body, "e");
        CHECK(e != nullptr);
        if (!e) continue;
        CHECK(doc->insert_subtree(e, e->children().size(), build(doc, el("p", "one"))));
        CHECK(doc->insert_subtree(e, e->children().size(), build(doc, el("p", "two"))));
        kids[0].kids = {el("p", "one"), el("p", "two")};
        structureMatchesFresh(c, doc, sheet, kids, sheet);
    }
}

static void testStructureBesideEmptyMatchesFresh() {
    const char* const sheets[] = {
        ".e:empty{outline:1px solid #f00}",
        ".e:not(:empty)::before{content:'x'}",
        ".e:empty + p{color:#c00}",
        ".e:empty{--c:#00f} .e:not(:empty){--c:#0a0} .e span{color:var(--c, #000)}",
        ".e:empty + p{display:none}",
        ".e:empty + p::before{content:'x'}",
        ".e:not(:empty) + p{float:left;width:20px}",
    };
    for (const char* sheet : sheets) {
        for (const bool asText : {false, true}) {
            std::vector<Spec> kids = {el("div", "", {{"class", "e"}, {"id", "e"}}), el("p", "after")};
            PaintContainer c;
            element::ptr body;
            auto doc = structureDocument(c, sheet, kids, body);
            auto e = doc->root()->select_one("#e");
            if (!e) {
                CHECK(e != nullptr);
                continue;
            }
            const std::string what = std::string(sheet) + (asText ? ", a Text" : ", an element");
            std::vector<element::ptr> made;
            if (asText) {
                doc->make_text_pieces(e, "t", made);
                kids[0].kids = {Spec{"", {}, "t"}};
            } else {
                made.push_back(build(doc, el("span", "s")));
                kids[0].kids = {el("span", "s")};
            }
            for (const auto& piece : made) CHECK(doc->insert_subtree(e, e->children().size(), piece));
            made.clear();
            structureMatchesFresh(c, doc, sheet, kids, (what + " gained").c_str());
            {
                const litehtml::elements_list children = e->children();
                for (const auto& child : children) {
                    if (child->tag() != litehtml::__tag_before_ && child->tag() != litehtml::__tag_after_) CHECK(doc->remove_subtree(child));
                }
            }
            kids[0].kids.clear();
            structureMatchesFresh(c, doc, sheet, kids, (what + " lost").c_str());
        }
    }
}

// The ::before or the ::after (`tag`) of `owner`, or none.
static element::ptr pseudoOf(const element::ptr& owner, litehtml::string_id tag) {
    if (!owner) return nullptr;
    for (const auto& child : owner->children()) {
        if (child->tag() == tag) return child;
    }
    return nullptr;
}

// Edit 91: a match that changes nothing keeps its owner's ::before, the same element with the same render item. An item
// inserted at 1 under li + li: b and c match as they did.
static void testAnUnchangedPseudoElementKeepsItsIdentity() {
    const char* sheet = "li::before{content:'•'} li + li{color:#c00}";
    std::vector<Spec> page = {
        el("ul", "", {{"id", "u"}}, {el("li", "a", {{"id", "a"}}), el("li", "b", {{"id", "b"}}), el("li", "c", {{"id", "c"}})})};
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheet, page, body);
    RecordingObserver observer;
    doc->set_render_observer(&observer);
    // Weak, so that what is made again lets go (its pieces count while alive) and cannot take a kept one's address.
    std::map<std::string, std::pair<std::weak_ptr<element>, std::weak_ptr<litehtml::render_item>>> before;
    for (const char* id : {"a", "b", "c"}) {
        const element::ptr pseudo = pseudoOf(byId(body, id), litehtml::__tag_before_);
        CHECK(pseudo != nullptr);
        if (pseudo) before[id] = {pseudo, doc->live_item(*pseudo)};
    }
    CHECK(doc->insert_subtree(byId(body, "u"), 1, build(doc, el("li", "n"))));
    page[0].kids.insert(page[0].kids.begin() + 1, el("li", "n"));
    structureMatchesFresh(c, doc, sheet, page, "an item inserted at 1 beside ::before content");
    if (!observer.replaced.empty())
        std::printf("  %zu replaced (%s)\n", observer.replaced.size(), doc->rebuild_reason().c_str());
    CHECK(observer.replaced.empty());
    for (const char* id : {"b", "c"}) {
        const element::ptr pseudo = pseudoOf(byId(body, id), litehtml::__tag_before_);
        const element::ptr was = before[id].first.lock();
        const std::shared_ptr<litehtml::render_item> item = before[id].second.lock();
        if (!pseudo || pseudo != was) std::printf("  %s: its ::before made again\n", id);
        CHECK(pseudo && pseudo == was);
        CHECK(pseudo && item && doc->live_item(*pseudo) == item);
    }
    doc->set_render_observer(nullptr);
}

// Edit 91: generated content is kept only when the match changes nothing and it prints as it did; otherwise it is made
// again, appears or goes, as a fresh build has it.
static void testGeneratedContentFollowsItsPrint() {
    enum class Outcome { kept, madeAgain, appears, goes };
    struct Case {
        const char* name;
        const char* sheet;
        const char* list; // the list's tag
        std::vector<litehtml::string_map> items; // a, b, c's attributes, their ids added
        std::function<bool(const litehtml::document::ptr&, const element::ptr&, std::vector<Spec>&)> patch;
        litehtml::string_id side;
        Outcome outcome;
    };
    const auto itemSpec = [](const char* id, litehtml::string_map attrs) {
        attrs["id"] = id;
        return el("li", id, attrs);
    };
    const std::vector<Case> cases = {
        {"an item inserted first under counters", "ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n)}",
         "ol", {{}, {}, {}},
         [](auto doc, auto body, auto& page) {
             page[0].kids.insert(page[0].kids.begin(), el("li", "n"));
             return doc->insert_subtree(byId(body, "u"), 0, build(doc, el("li", "n")));
         },
         litehtml::__tag_before_, Outcome::madeAgain},
        {"b's data-x set under attr()", "li::after{content:attr(data-x)}", "ul",
         {{{"data-x", "1"}}, {{"data-x", "1"}}, {{"data-x", "1"}}},
         [](auto doc, auto body, auto& page) {
             page[0].kids[1].attrs["data-x"] = "2";
             return doc->set_element_attribute(byId(body, "b"), "data-x", "2");
         },
         litehtml::__tag_after_, Outcome::madeAgain},
        {"class on added to b", "li.on::before{content:'+'}", "ul", {{}, {}, {}},
         [](auto doc, auto body, auto& page) {
             page[0].kids[1].attrs["class"] = "on";
             return doc->set_element_attribute(byId(body, "b"), "class", "on");
         },
         litehtml::__tag_before_, Outcome::appears},
        {"class on taken from b", "li.on::before{content:'+'}", "ul", {{}, {{"class", "on"}}, {}},
         [](auto doc, auto body, auto& page) {
             page[0].kids[1].attrs["class"] = "";
             return doc->set_element_attribute(byId(body, "b"), "class", "");
         },
         litehtml::__tag_before_, Outcome::goes},
        {"an item appended under :first-child", "li:first-child{color:#c00} li::before{content:'•'}", "ul", {{}, {}, {}},
         [](auto doc, auto body, auto& page) {
             page[0].kids.push_back(el("li", "n"));
             const element::ptr list = byId(body, "u");
             return doc->insert_subtree(list, list->children().size(), build(doc, el("li", "n")));
         },
         litehtml::__tag_before_, Outcome::kept},
    };
    for (const Case& k : cases) {
        std::vector<Spec> page = {el(k.list, "", {{"id", "u"}},
                                     {itemSpec("a", k.items[0]), itemSpec("b", k.items[1]), itemSpec("c", k.items[2])})};
        PaintContainer c;
        element::ptr body;
        auto doc = structureDocument(c, k.sheet, page, body);
        // Weak, so that what is made again lets go (its pieces count while alive).
        const std::weak_ptr<element> was = pseudoOf(byId(body, "b"), k.side);
        const bool had = !was.expired();
        CHECK(k.patch(doc, body, page));
        structureMatchesFresh(c, doc, k.sheet, page, k.name);
        const element::ptr now = pseudoOf(byId(body, "b"), k.side);
        const bool same = now && now == was.lock();
        bool wanted = false;
        switch (k.outcome) {
        case Outcome::kept: wanted = had && same; break;
        case Outcome::madeAgain: wanted = had && now && !same; break;
        case Outcome::appears: wanted = !had && now; break;
        case Outcome::goes: wanted = had && !now; break;
        }
        if (!wanted) std::printf("  %s: b's generated content %s, %s now, the same: %d\n", k.name, had ? "was" : "was none",
                                 now ? "one" : "none", int(same));
        CHECK(wanted);
    }
}

// Edit 91: a match that keeps an element's ::before needs no style room beside it, since the old one's charges are given
// back before the match charges the new one, as before. Room for one more item and its ::before, not two: an item
// inserted at 1 under li + li (b and c matched again) replays nothing and replaces nothing for the budget.
static void testAKeptPseudoElementNeedsNoStyleRoom() {
    const std::vector<std::string> sheets = {"li::before{content:'x';--pad:" + std::string(20000, 'p') +
                                             "} li + li{color:#c00} i{--fill:" + std::string(4000, 'f') + "}"};
    auto kids = [](int fill, bool inserted) {
        std::vector<Spec> items = {el("li", "a", {{"id", "a"}}), el("li", "b", {{"id", "b"}}), el("li", "c", {{"id", "c"}})};
        if (inserted) items.insert(items.begin() + 1, el("li", "n"));
        std::vector<Spec> is;
        for (int n = 0; n < fill; n++) is.push_back(el("i"));
        return std::vector<Spec>{el("ul", "", {{"id", "u"}}, items), el("div", "", {}, is)};
    };
    // Sized from probes: what an <i> and what an item with its ::before charge.
    size_t base = 0, perFill = 0, perItem = 0;
    {
        PaintContainer p0, p1, p2;
        element::ptr body;
        auto none = structureDocument(p0, sheets, kids(0, false), body);
        auto filled = structureDocument(p1, sheets, kids(100, false), body);
        auto more = structureDocument(p2, sheets, kids(0, true), body);
        base = none->style_bytes_charged();
        perFill = (filled->style_bytes_charged() - base) / 100;
        perItem = more->style_bytes_charged() - base;
    }
    const int fill = int((litehtml::document::max_style_bytes - base - perItem * 3 / 2) / perFill);
    PaintContainer c;
    element::ptr body;
    auto doc = structureDocument(c, sheets, kids(fill, false), body);
    CHECK(!doc->style_bytes_limited());
    const std::weak_ptr<element> was = pseudoOf(byId(body, "b"), litehtml::__tag_before_);
    const uint64_t replays = doc->generated_replays();
    CHECK(doc->insert_subtree(byId(body, "u"), 1, build(doc, el("li", "n"))));
    structureMatchesFresh(c, doc, sheets, kids(fill, true), "an item inserted at 1 with room for one ::before");
    if (doc->generated_replays() != replays || doc->style_bytes_limited())
        std::printf("  %llu replays, limited %d (%s)\n", (unsigned long long)(doc->generated_replays() - replays),
                    int(doc->style_bytes_limited()), doc->rebuild_reason().c_str());
    CHECK(doc->generated_replays() == replays);
    CHECK(!doc->style_bytes_limited());
    CHECK(doc->rebuild_reason() != "the style budget");
    const element::ptr now = pseudoOf(byId(body, "b"), litehtml::__tag_before_);
    CHECK(now && now == was.lock());
}

int main() {
    testExternalBuildMatchesParse();
    testExternalSvgMatchesParse();
    testInsertChildAtEveryIndex();
    testAcceptsChildMatchesAppendChild();
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
    testStructureBesidePseudoContent();
    testStructureCaps();
    testStructureUnderPositionalSelectorsMatchesFresh();
    testSelectorStepsAreOneBudgetPerSession();
    testACutBootReplaysAtItsFirstCommit();
    testTableRowsArePlacedOncePerLayout();
    testMatchingBoundCountsPseudoElementsAndParts();
    testFontSizeZeroMatchesFresh();
    testWalkVisitsWhatDrawPaints();
    testObserverReportsEveryRenderTreeChange();
    testStyleBytesAreBudgeted();
    testRebuildReasonsNameTheChange();
    testAfterTheBootSubtreesAreReplaced();
    testStructurePatchKeepsTheTreeOutsideItsBoundary();
    testReplacementBoundaries();
    testReplacedItemsLeaveTheirElements();
    testReplacementGivesBackTableCells();
    testReplacementGivesBackTableCellsUnderFlex();
    testReplacementWalksAreLinear();
    testPseudoClassStateRematchesItsReach();
    testCountersRunAgainInBuildOrder();
    testEnvironmentParsesPairUp();
    testEnvironmentChangesMatchFresh();
    testSchemeParsesPairUp();
    testSchemeChangeMatchesFresh();
    testSchemeChangeRestylesSvgPaint();
    testEnvironmentChangesTwiceKeepNoFreedRule();
    testSheetChangesMatchFresh();
    testUnchangedSheetsParseNothing();
    testAClassChangeBesideASheetChangeMatchesFresh();
    testSheetTestsCountIntoTheSession();
    testRootReplacementMatchesFresh();
    testRefusalsSayWhy();
    testStyleBytesFollowPatches();
    testCustomPropertiesInInlineStyle();
    testAttributeChangeRematchesItsReach();
    testTableAttributesMatchFresh();
    testStructureInsideAnSvg();
    testPseudoElementsReadingVar();
    testButtonTextIsReplacedInPlace();
    testStructureInsideAButton();
    testReplacementAtTheTableCellCap();
    testACapCrossingReplacementReportsTheRootAlone();
    testAnInlineBoxInALineIsReplacedInPlace();
    testAPositionedDescendantFollowsItsContainingBlock();
    testListItemsAreNumberedAgain();
    testSeedsInOneSession();
    testBlockChildrenLinkAndUnlink();
    testStructureRefusalsNameTheirCase();
    testAPositionalChangeBesideALink();
    testALinkedTableTakesAndGivesBackItsCells();
    testALinkBesideAReplacement();
    testAnEmptyParentsFlipBesideALink();
    testStructureSessionsUnderPositionalSelectors();
    testSiblingReachFollowsTheSelectors();
    testAnUnchangedReachIsNotReported();
    testASessionsEarlierMatchIsMatchedAgainByTheReach();
    testAnEmptyFlipReachesEarlierSiblingsThroughOfS();
    testStyleBudgetIsDeterministic();
    testVarSplicesAreBudgeted();
    testInheritedStringsAreBounded();
    testInheritedUrlsAreSharedAndCharged();
    testRefreshAfterTheLimitEqualsARebuild();
    testTwoContentRulesAtTheCapReplayAsABuild();
    testReplayFollowsBuildOrder();
    testStyleBytesReplayFromZero();
    testPaintOnlyChangeDoesNotReplay();
    testMasterContentCountsAtTheTextCap();
    testMasterContentCountsAtThePseudoCap();
    testPositionParentsAreAskedOncePerSession();
    testReplayWalksAreLinear();
    testFixedTablesHoldNoReplacedText();
    testAnInlineFlexPaintsItsChildrenOnce();
    testATransformGoingKeepsPositionedPaint();
    testStructureBesideEmptyMatchesFresh();
    testAnUnchangedPseudoElementKeepsItsIdentity();
    testGeneratedContentFollowsItsPrint();
    testAKeptPseudoElementNeedsNoStyleRoom();
    testReplaceTextBesideStructure();
    if (failures) {
        std::printf("%d failure(s)\n", failures);
        return 1;
    }
    std::printf("ok\n");
    return 0;
}
