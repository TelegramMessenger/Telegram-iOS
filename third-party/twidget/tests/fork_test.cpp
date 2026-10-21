#include "test_container.h"

#include <litehtml/render_item.h>

#include <cmath>
#include <cstdio>

static int failures = 0;

static litehtml::element::ptr by_id(const litehtml::document::ptr& doc, const char* id) {
    return doc->root()->select_one(std::string("#") + id);
}

// Records the matrix of every paint group the document opens while drawing.
struct GroupContainer : litehtml_test::TestContainer {
    std::vector<litehtml::transform_matrix> groups;
    void begin_group(litehtml::uint_ptr, const litehtml::paint_group& group) override { groups.push_back(group.matrix); }
};

// Text pieces (el_text, el_space) reachable from `el`, ::before/::after content included.
static int text_pieces(const litehtml::element::ptr& el) {
    int count = el->is_text() ? 1 : 0;
    for (const auto& child : el->children()) count += text_pieces(child);
    return count;
}

// `html` as LHDocument builds it: patched in place from `previous` where litehtml can, else built afresh.
static litehtml::document::ptr patched(litehtml_test::TestContainer& c, litehtml::document::ptr previous, const std::string& html) {
    if (!previous || !previous->update_from_string(html, nullptr))
        previous = litehtml::document::createUpdatableFromString(html, &c, litehtml::master_css);
    previous->render(litehtml::pixel_t(300.0f));
    return previous;
}

static bool finite(const litehtml::transform_matrix& m) {
    return std::isfinite(m.a) && std::isfinite(m.b) && std::isfinite(m.c) && std::isfinite(m.d) && std::isfinite(m.tx) &&
           std::isfinite(m.ty);
}

int main() {
    litehtml_test::TestContainer c;
    const char* item = "style='width:50px;height:10px;flex:none'";

    // Verbatim from the branch's flex_gap_test.cpp (Task 3, 599d20928b). Shrink-to-fit of a WRAPPED
    // row: a float in a 165px box. Its flex container wraps [a,b][c], but its max-content width is the
    // sum of base sizes plus EVERY gap: 3 * 50 + 2 * 10 = 170. 170 > 165, so the float keeps 165; the
    // fork's undercounted 160 shrinks it to 160.
    auto fit = litehtml_test::layout(c, std::string("<body style='margin:0'><div style='width:165px'><div id=w style='float:left'>") +
        "<div style='display:flex;flex-wrap:wrap;gap:4px 10px'>" +
        "<div id=a " + item + "></div><div id=b " + item + "></div><div id=c " + item + "></div></div></div></div></body>");
    {
        auto el = by_id(fit, "w");
        CHECK(el && float(el->get_placement().width) == 165.0f);
    }

    // tabular-nums reaches the font description the container is asked for.
    c.fonts.clear();
    litehtml_test::layout(c, "<p style='font-variant-numeric:tabular-nums'>1</p>");
    bool tabular = false;
    for (const auto& f : c.fonts) tabular |= f.tabular_nums;
    CHECK(tabular);

    // Non-finite transform and box-shadow values parse as unset (css_effects.h: box_shadow{x, y, blur,
    // spread: css_length}; transform_function{x, y: css_length; v[6]: float}).
    auto nf = litehtml_test::layout(c,
        "<div id=a style='transform:matrix(1e999,0,0,1,0,0);box-shadow:0 0 0 1e999px red;width:10px;height:10px'></div>"
        "<div id=b style='transform:translate(1e999px,0) scale(0e999);box-shadow:1e999px 0 0 red'></div>");
    for (const char* id : {"a", "b"}) {
        const auto& css = by_id(nf, id)->css();
        for (const auto& s : css.get_box_shadows())
            CHECK(std::isfinite(s.x.val()) && std::isfinite(s.y.val()) && std::isfinite(s.blur.val()) && std::isfinite(s.spread.val()));
        for (const auto& f : css.get_transform()) {
            CHECK(std::isfinite(f.x.val()) && std::isfinite(f.y.val()));
            for (float v : f.v) CHECK(std::isfinite(v));
        }
    }
    // Both are dropped whole, not trimmed: no shadow or transform function is left.
    CHECK(by_id(nf, "a")->css().get_box_shadows().empty() && by_id(nf, "a")->css().get_transform().empty());
    CHECK(by_id(nf, "b")->css().get_box_shadows().empty() && by_id(nf, "b")->css().get_transform().empty());

    // A finite length whose pixels are not finite (1e38em at 16px is inf as a float) is unset too, and
    // finite values still parse.
    auto em = litehtml_test::layout(c,
        "<div id=a style='transform:translate(1e38em,0);box-shadow:1e38em 0 red'></div>"
        "<div id=b style='transform:translate(5px,1em) rotate(1e38deg) scale(2);box-shadow:1px 2px 3px red,0 0 1em blue'></div>");
    CHECK(by_id(em, "a")->css().get_box_shadows().empty() && by_id(em, "a")->css().get_transform().empty());
    CHECK(by_id(em, "b")->css().get_box_shadows().size() == 2 && by_id(em, "b")->css().get_transform().size() == 3);

    // Finite factors can still compose to a non-finite matrix at paint time: two 1e20 scales, a huge percentage
    // (resolved against the box only when drawn), a huge transform-origin. The group is then drawn untransformed
    // (identity), as an unset transform; a finite transform still reaches the painter as itself.
    for (const char* style : {"transform:scale(1e20) scale(1e20)", "transform:translate(3e38%)",
                              "transform:rotate(10deg);transform-origin:3e38% 0"}) {
        GroupContainer g;
        auto doc = litehtml_test::layout(g, std::string("<body style='margin:0'><div style='width:200px;height:10px;") + style + "'></div></body>");
        doc->draw(0, litehtml::pixel_t(0.0f), litehtml::pixel_t(0.0f), nullptr);
        CHECK(!g.groups.empty());
        for (const auto& m : g.groups) {
            if (!finite(m)) std::printf("  %s -> [%g %g %g %g %g %g]\n", style, m.a, m.b, m.c, m.d, m.tx, m.ty);
            CHECK(finite(m) && m.is_identity());
        }
    }
    {
        GroupContainer g;
        auto doc = litehtml_test::layout(g, "<body style='margin:0'><div style='width:200px;height:10px;transform:translate(5px,2px) scale(2)'></div></body>");
        doc->draw(0, litehtml::pixel_t(0.0f), litehtml::pixel_t(0.0f), nullptr);
        CHECK(g.groups.size() == 1 && g.groups[0].a == 2.0f && g.groups[0].d == 2.0f);
    }

    // A point over a flex container, between its items, hits the flex container, also when it sits in a
    // positioned element: the hit then travels up through the positioned element's static ancestors,
    // which keep it only if the element has a render item registered (run_on_renderers), and a flex
    // container never registered its own. The hit came back as the positioned element's parent (#o).
    {
        auto doc = litehtml_test::layout(c, "<body style='margin:0'><div id=o><div id=b style='position:relative;padding:10px'>"
                                            "<div id=t style='display:flex;justify-content:space-between'><span>a</span><span>b</span></div>"
                                            "</div></div></body>");
        const auto any = [](const std::shared_ptr<litehtml::render_item>&) { return true; };
        const auto hit = doc->root_render()->get_element_by_point(litehtml::pixel_t(150.0f), litehtml::pixel_t(12.0f), litehtml::pixel_t(150.0f), litehtml::pixel_t(12.0f), any);
        if (hit != by_id(doc, "t")) std::printf("  flex gap hit id=%s\n", hit ? hit->get_attr("id", "(none)") : "null");
        CHECK(hit && hit == by_id(doc, "t"));
        CHECK(float(by_id(doc, "t")->get_placement().width) == 280.0f);
    }

    // A computed line height keeps its fraction, as WebKit's does: 15px at 1.35, 1.35em and 20.25px are each a
    // 20.25px line box (the test fonts are 16px tall, so the line height decides), and each block starts where
    // the one above ends. Floored to a whole pixel (twidget 4f877c7), each line was 20px.
    {
        auto doc = litehtml_test::layout(c, "<body style='margin:0;font-size:15px'><div id=n style='line-height:1.35'>a</div>"
                                            "<div id=e style='line-height:1.35em'>a</div><div id=l style='line-height:20.25px'>a</div></body>");
        float y = 0.0f;
        for (const char* id : {"n", "e", "l"}) {
            const auto box = by_id(doc, id)->get_placement();
            if (std::fabs(float(box.height) - 20.25f) > 0.01f || std::fabs(float(box.y) - y) > 0.01f)
                std::printf("  line-height %s -> y %g height %g\n", id, float(box.y), float(box.height));
            CHECK(std::fabs(float(box.height) - 20.25f) <= 0.01f);
            CHECK(std::fabs(float(box.y) - y) <= 0.01f);
            y += 20.25f;
        }
    }

    // Text pieces (el_text and el_space: a word, or one whitespace character) are capped per document, however they
    // are made: from a text node, a whitespace run between blocks, a patch that changes a text run, and ::before/::after
    // content, which a short stylesheet multiplies by every element it matches. Each piece costs ~2.8 KB (measured at
    // -O0), and 3.5 KB of HTML made 400,000 of them (+1 GB, 2.7 s) through ::before.
    {
        const int cap = litehtml::document::max_text_elements;
        CHECK(cap == 10000);
        std::string words;
        for (int i = 0; i < 30000; i++) words += "a ";
        auto doc = litehtml_test::layout(c, "<body><p>" + words + "</p></body>");
        int pieces = text_pieces(doc->root());
        if (pieces > cap) std::printf("  text node: %d pieces\n", pieces);
        CHECK(pieces <= cap && pieces >= cap - 1);

        doc = litehtml_test::layout(c, "<body><div>a</div>" + std::string(30000, ' ') + "<div>b</div></body>");
        pieces = text_pieces(doc->root());
        if (pieces > cap) std::printf("  whitespace run: %d pieces\n", pieces);
        CHECK(pieces <= cap);

        std::string content, tags;
        for (int i = 0; i < 1000; i++) content += "a ";
        for (int i = 0; i < 50; i++) tags += "<b></b>";
        doc = litehtml_test::layout(c, "<html><head><style>b::before{content:\"" + content + "\"}</style></head><body>" + tags + "</body></html>");
        pieces = text_pieces(doc->root());
        if (pieces > cap) std::printf("  ::before: %d pieces\n", pieces);
        CHECK(pieces <= cap);

        // A page under the cap is built whole, and the document's count is its pieces.
        doc = litehtml_test::layout(c, "<body><p>one two</p><p>three</p></body>");
        CHECK(text_pieces(doc->root()) == 4 && doc->text_elements() == 4);

        // A patch that grows a text run, and one that adds a subtree, stay under the cap (LHDocument builds afresh
        // when the patch is refused, as `patched` does).
        auto updatable = patched(c, nullptr, "<body><p id=t>a b</p></body>");
        updatable = patched(c, updatable, "<body><p id=t>" + words + "</p></body>");
        pieces = text_pieces(updatable->root());
        if (pieces > cap) std::printf("  patched text run: %d pieces\n", pieces);
        CHECK(pieces <= cap);
        updatable = patched(c, nullptr, "<body><p id=t>a b</p></body>");
        // A structure patch past the cap is refused (LHDocument then builds afresh, under the cap).
        CHECK(!updatable->update_from_string("<body><p id=t>a b</p><div>" + words + "</div></body>", nullptr));
        updatable = patched(c, updatable, "<body><p id=t>a b</p><div>" + words + "</div></body>");
        pieces = text_pieces(updatable->root());
        if (pieces > cap) std::printf("  patched subtree: %d pieces\n", pieces);
        CHECK(pieces <= cap);

        // A structure patch under the cap keeps its whole text: the replacement pieces are made while the ones they
        // replace are still alive, and a ~6,000-piece paragraph came out with 4,001 pieces.
        {
            std::string first = "u", second = "v";
            for (int i = 1; i < 3000; i++) {
                first += " u";
                second += " v";
            }
            auto structured = patched(c, nullptr, "<body><p id=t>" + first + "</p></body>");
            CHECK(text_pieces(structured->root()) == 5999);
            const bool reused = structured->update_from_string("<body><p id=t>" + second + "</p><div>x</div></body>", nullptr);
            if (!reused)
                structured = litehtml::document::createUpdatableFromString("<body><p id=t>" + second + "</p><div>x</div></body>", &c, litehtml::master_css);
            structured->render(litehtml::pixel_t(300.0f));
            pieces = text_pieces(structured->root());
            if (pieces != 6000 || !reused) std::printf("  structure patch (reused %d): %d pieces, want 6000\n", int(reused), pieces);
            CHECK(reused && pieces == 6000);
        }

        // Pieces a patch replaces stop counting. A few pieces outlive their tree in litehtml's caches, so the count is
        // the tree's plus a constant few (1 here, 7 below, measured); a count that only grew would move that difference,
        // and would refuse the patches (cutting the text) once ~10,000 pieces had been made. 40 patches of a text run
        // make ~240,000 pieces in all.
        const auto steady = [&](const litehtml::document::ptr& d, int want, int& slack, const char* what, int round) {
            const int tree = text_pieces(d->root());
            const int extra = d->text_elements() - tree;
            if (tree != want || extra < 0 || extra > 16 || (slack >= 0 && extra != slack)) {
                std::printf("  %s %d: %d pieces (count %d), want %d\n", what, round, tree, d->text_elements(), want);
                return false;
            }
            slack = extra;
            return true;
        };
        updatable = patched(c, nullptr, "<body><p id=t>a</p></body>");
        bool whole = true;
        int slack = -1;
        for (int round = 0; round < 40 && whole; round++) {
            const int count = 3000 + round;
            std::string run = "w";
            for (int i = 1; i < count; i++) run += " w";
            updatable = patched(c, updatable, "<body><p id=t>" + run + "</p></body>");
            whole = steady(updatable, 2 * count - 1, slack, "patch", round);
        }
        CHECK(whole);

        // The same for ::before content, which a restyle makes again: 400 elements toggling a class in place (a
        // 3-piece and a 5-piece content) make ~48,000 pieces over 30 patches.
        const auto page = [](bool on) {
            std::string html = "<html><head><style>b::before{content:\"p q\"}b.on::before{content:\"r s t\"}</style></head><body><div>";
            for (int i = 0; i < 400; i++) html += on ? "<b class=on></b>" : "<b class=off></b>";
            return html + "</div></body></html>";
        };
        updatable = patched(c, nullptr, page(false));
        slack = -1;
        whole = steady(updatable, 1200, slack, "restyle", -1);
        for (int round = 0; round < 30 && whole; round++) {
            updatable = patched(c, updatable, page(round % 2 == 0));
            whole = steady(updatable, round % 2 == 0 ? 2000 : 1200, slack, "restyle", round);
        }
        CHECK(whole);
    }

    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget fork: OK\n");
    return 0;
}
