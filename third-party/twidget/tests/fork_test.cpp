#include "test_container.h"

#include <litehtml/css_parser.h>
#include <litehtml/render_item.h>
#include <litehtml/render_table.h>

#include <chrono>
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

// Records the colour stops of every gradient the document draws, as "offset:r,g,b" joined by spaces.
struct GradientContainer : litehtml_test::TestContainer {
    std::vector<std::string> stops;
    void record(const litehtml::background_layer::gradient_base& g) {
        std::string out;
        for (const auto& p : g.color_points) {
            char buf[64];
            std::snprintf(buf, sizeof(buf), "%s%.4g:%d,%d,%d", out.empty() ? "" : " ", p.offset, p.color.red, p.color.green, p.color.blue);
            out += buf;
        }
        stops.push_back(out);
    }
    void draw_linear_gradient(litehtml::uint_ptr, const litehtml::background_layer&, const litehtml::background_layer::linear_gradient& g) override { record(g); }
    void draw_conic_gradient(litehtml::uint_ptr, const litehtml::background_layer&, const litehtml::background_layer::conic_gradient& g) override { record(g); }
};

// Records the fill colour of every path the document draws, as "r,g,b" joined by spaces.
struct PathContainer : litehtml_test::TestContainer {
    std::string fills;
    void draw_path(litehtml::uint_ptr, const litehtml::vector_path& path) override {
        if (!path.fill) return;
        char buf[32];
        std::snprintf(buf, sizeof(buf), "%s%d,%d,%d", fills.empty() ? "" : " ", path.fill_color.red, path.fill_color.green, path.fill_color.blue);
        fills += buf;
    }
};

// Text pieces (el_text, el_space) reachable from `el`, ::before/::after content included.
static int text_pieces(const litehtml::element::ptr& el) {
    int count = el->is_text() ? 1 : 0;
    for (const auto& child : el->children()) count += text_pieces(child);
    return count;
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

    }

    // CSS-wide keywords (VENDOR.md edit 33): initial is the property's initial value, unset inherits an inherited
    // property and is initial otherwise, revert is the master sheet's value (or unset where it has none), and a custom
    // property set to initial has no value, so var() takes its fallback.
    {
        auto kw = litehtml_test::layout(c,
            "<html><head><style>p{margin:0} #c{color:rgb(0,0,140);--x:rgb(9,9,9)}"
            " #r{margin:revert;display:inline;display:revert} #i{display:initial} #u{color:rgb(200,0,0);color:unset;"
            "margin-top:5px;margin-top:unset} #rc{color:rgb(200,0,0);color:revert} #v{--x:initial;color:var(--x,rgb(1,2,3))}"
            "</style></head><body><div id=c><p id=r>r</p><div id=i>i</div><p id=u>u</p><p id=rc>x</p><span id=v>v</span>"
            "</div></body></html>");
        const auto& r = by_id(kw, "r")->css();
        CHECK(r.get_display() == litehtml::display_block);
        CHECK(float(r.get_margins().top.val()) == float(r.get_font_size()) && float(r.get_margins().bottom.val()) == float(r.get_font_size()));
        CHECK(by_id(kw, "i")->css().get_display() == litehtml::display_inline);
        const auto& u = by_id(kw, "u")->css();
        CHECK(u.get_color() == litehtml::web_color(0, 0, 140) && float(u.get_margins().top.val()) == 0.0f);
        CHECK(by_id(kw, "rc")->css().get_color() == litehtml::web_color(0, 0, 140));
        CHECK(by_id(kw, "v")->css().get_color() == litehtml::web_color(1, 2, 3));
    }

    // CSS Images 3 §3.4.3's colour-stop fix-up (VENDOR.md edit 35): a position below an earlier one is raised to it, an
    // explicit 0 on the last stop stays 0 (then raised), and unpositioned stops are spaced evenly between their neighbours.
    {
        GradientContainer g;
        auto doc = litehtml_test::layout(g,
            "<body style='margin:0'><div style='width:100px;height:100px;background:conic-gradient(rgb(1,0,0) 0 25%,rgb(2,0,0) 0 50%,"
            "rgb(3,0,0) 0 75%,rgb(4,0,0) 0)'></div>"
            "<div style='width:100px;height:10px;background:linear-gradient(90deg,rgb(1,0,0) 20%,rgb(2,0,0),rgb(3,0,0) 80%)'></div>"
            "<div style='width:100px;height:10px;background:linear-gradient(90deg,rgb(1,0,0),rgb(2,0,0) 40%,rgb(3,0,0) 10%,rgb(4,0,0))'></div>"
            "</body>");
        doc->draw(0, litehtml::pixel_t(0.0f), litehtml::pixel_t(0.0f), nullptr);
        const std::vector<std::string> want = {
            "0:1,0,0 0.25:1,0,0 0.25:2,0,0 0.5:2,0,0 0.5:3,0,0 0.75:3,0,0 0.75:4,0,0 1:4,0,0",
            "0:1,0,0 0.2:1,0,0 0.5:2,0,0 0.8:3,0,0 1:3,0,0",
            "0:1,0,0 0.4:2,0,0 0.4:3,0,0 1:4,0,0",
        };
        CHECK(g.stops.size() == want.size());
        for (size_t i = 0; i < want.size() && i < g.stops.size(); i++) {
            if (g.stops[i] != want[i]) std::printf("  gradient %zu: %s\n          want %s\n", i, g.stops[i].c_str(), want[i].c_str());
            CHECK(g.stops[i] == want[i]);
        }
    }

    // A master @layer block is an origin above the master's other rules (VENDOR.md edit 41): its rules beat the
    // engine's whatever their specificity, keep their own order among themselves, and revert skips them, rolling back
    // to the engine's sheet as a browser rolls an author layer back to its UA sheet.
    {
        c.width = 300;
        const std::string master = std::string(litehtml::master_css) +
            "div span{color:rgb(3,0,0)} @layer tw{span{color:rgb(2,0,0)} div div span{color:rgb(1,0,0)} p{margin:3px 0}}";
        auto doc = litehtml::document::createFromString(litehtml::estring(
            "<html><head><style>p.r{margin:revert}</style></head><body><div><span id=a>a</span><div><span id=b>b</span>"
            "</div></div><p id=p>p</p><p id=r class=r>r</p></body></html>"), &c, master);
        doc->render(litehtml::pixel_t(300.0f));
        CHECK(by_id(doc, "a")->css().get_color() == litehtml::web_color(2, 0, 0));
        CHECK(by_id(doc, "b")->css().get_color() == litehtml::web_color(1, 0, 0));
        CHECK(float(by_id(doc, "p")->css().get_margins().top.val()) == 3.0f);
        const auto& r = by_id(doc, "r")->css();
        CHECK(float(r.get_margins().top.val()) == float(r.get_font_size()));
        // An author sheet's @layer keeps today's reading: its rules are unlayered.
        auto author = litehtml::document::createFromString(litehtml::estring(
            "<html><head><style>@layer x{#q{color:rgb(5,0,0)}} span{color:rgb(6,0,0)}</style></head><body><span id=q>q</span>"
            "</body></html>"), &c);
        author->render(litehtml::pixel_t(300.0f));
        CHECK(by_id(author, "q")->css().get_color() == litehtml::web_color(5, 0, 0));
    }

    // VENDOR.md edit 43: a rule's declarations reach the element in their written order, so a var() shorthand after a
    // shorthand that sets its longhands (`border:0; border-top:1px solid var(--c)`) still wins once var() is resolved.
    {
        auto doc = litehtml_test::layout(c,
            "<html><head><style>html{--c:#123456} #h{border:0;border-top:2px solid var(--c);height:0}"
            " #k{border-top:3px solid var(--c);border:0}</style></head><body><div id=h></div><div id=k></div></body></html>");
        const auto& h = by_id(doc, "h")->css().get_borders().top;
        CHECK(float(h.width.val()) == 2.0f && h.style == litehtml::border_style_solid);
        CHECK(h.color == litehtml::web_color(0x12, 0x34, 0x56));
        CHECK(float(by_id(doc, "k")->css().get_borders().top.width.val()) == 0.0f);
    }

    // VENDOR.md edit 44: a relatively positioned inline box moves its content with it (CSS 2 §9.4.3), nested ones adding
    // up, and its own box (the inline box geometry reads).
    {
        auto doc = litehtml_test::layout(c,
            "<html><head><style>sub,sup{vertical-align:baseline;font-size:inherit}</style></head>"
            "<body style='margin:0'><div><span id=b>x</span><sup id=p style='position:relative;top:-5px'>2</sup>"
            "<sub id=q style='position:relative;bottom:-4px'><span id=qq style='position:relative;left:3px'>3</span></sub></div></body></html>");
        auto first_text = [](const litehtml::element::ptr& el) {
            for (auto e = el; e; e = e->children().empty() ? nullptr : e->children().front()) {
                if (e->is_text()) return e;
            }
            return litehtml::element::ptr();
        };
        const float base = float(first_text(by_id(doc, "b"))->get_placement().y);
        const auto p = first_text(by_id(doc, "p"));
        const auto qq = first_text(by_id(doc, "qq"));
        const auto q = by_id(doc, "q");
        CHECK(p && qq);
        if (p && qq) {
            CHECK(float(p->get_placement().y) == base - 5.0f);
            CHECK(float(qq->get_placement().y) == base + 4.0f);
            CHECK(float(qq->get_placement().x) > float(p->get_placement().x) + 3.0f);
        }
        // The positioned inline's own box moved too.
        bool found = false;
        q->get_render_item()->for_inline_boxes([&](const litehtml::position& box, bool, bool) {
            found = true;
            CHECK(float(box.y) >= base + 4.0f - 1.0f);
            return true;
        });
        CHECK(found);
    }

    // Edit 46: direction is inherited; start and end resolve against it where a line is built (the computed value
    // keeps start); an over-constrained block in a right-to-left parent ignores margin-left and ends at the right.
    {
        auto doc = litehtml_test::layout(c, "<body style='margin:0'><div id=r style='direction:rtl;width:200px'>"
                                            "<p id=p style='margin:0'><span id=s>ab</span></p>"
                                            "<div id=b style='width:20px;height:5px;margin:0 10px 0 0'></div>"
                                            "<p id=e style='margin:0;text-align:end'><span id=t>ab</span></p></div>"
                                            "<div style='width:200px'><p style='margin:0'><span id=l>ab</span></p></div></body>");
        const auto p = by_id(doc, "p");
        CHECK(p && p->css().get_direction() == litehtml::direction_rtl && p->css().get_text_align() == litehtml::text_align_start);
        const auto right_of = [](const litehtml::element::ptr& el) {
            const auto pos = el->get_placement();
            return float(pos.x + pos.width);
        };
        // A span's text piece: an inline element's own placement does not follow its line items.
        const auto text_of = [&](const char* id) { return by_id(doc, id)->children().front(); };
        CHECK(std::abs(right_of(text_of("s")) - 200.0f) < 0.5f);
        CHECK(float(text_of("t")->get_placement().x) < 0.5f);
        CHECK(float(text_of("l")->get_placement().x) < 0.5f);
        CHECK(std::abs(right_of(by_id(doc, "b")) - 190.0f) < 0.5f);
    }

    // Edit 47: a line's units in visual order from the container's levels (rule L2), a span's box over its items
    // wherever they moved. This container answers 1 for a unit starting with a right-to-left character and the paragraph's own
    // level otherwise (U+0590 to U+07FF: Hebrew and Arabic); without it (the default hook) the order stays logical.
    {
        struct BidiContainer : litehtml_test::TestContainer {
            bool bidi_levels(const std::vector<std::string>& runs, bool rtl, std::vector<uint8_t>& levels) override {
                levels.clear();
                for (const auto& run : runs) {
                    const unsigned char lead = run.empty() ? 0 : static_cast<unsigned char>(run[0]);
                    const bool strong = lead >= 0xD6 && lead <= 0xDF;
                    levels.push_back(strong || rtl ? 1 : 0);
                }
                return true;
            }
        } bc;
        auto doc = litehtml_test::layout(bc, "<body style='margin:0'><div style='direction:rtl;width:200px'>"
                                             "<i id=a style='display:inline-block;width:10px;height:8px'></i>"
                                             "<i id=b style='display:inline-block;width:10px;height:8px'></i></div>"
                                             "<div style='width:200px'><span id=s><i id=c style='display:inline-block;width:10px;height:8px'></i>"
                                             "<i id=d style='display:inline-block;width:10px;height:8px'></i></span></div></body>");
        const auto x = [&](const char* id) { return float(by_id(doc, id)->get_placement().x); };
        CHECK(std::abs(x("a") - 190.0f) < 0.5f && std::abs(x("b") - 180.0f) < 0.5f);
        CHECK(std::abs(x("c") - 0.0f) < 0.5f && std::abs(x("d") - 10.0f) < 0.5f);
        // The default hook keeps the logical order.
        auto plain = litehtml_test::layout(c, "<body style='margin:0'><div style='direction:rtl;width:200px'>"
                                              "<i id=a style='display:inline-block;width:10px;height:8px'></i>"
                                              "<i id=b style='display:inline-block;width:10px;height:8px'></i></div></body>");
        CHECK(float(by_id(plain, "a")->get_placement().x) < float(by_id(plain, "b")->get_placement().x));
    }

    // Edit 48: a math function mixing a percentage with a length keeps its tree to layout, font-relative terms folded at
    // compute; the trees are counted references. A length copied, moved and assigned releases its tree with the last
    // copy. Documents share trees with style::add's process-wide declaration cache, so a repeated layout and patch of the
    // same page must leave no more trees alive than the first did.
    {
        const int64_t before = litehtml::calc_node::live();
        {
            const auto tokens = litehtml::normalize(std::string("calc(50% - 10px)"), litehtml::f_componentize);
            litehtml::css_length a;
            CHECK(!tokens.empty() && a.from_token(tokens[0], litehtml::f_length_percentage) && a.is_calc());
            CHECK(litehtml::calc_node::live() > before);
            litehtml::css_length b = a;
            litehtml::css_length m = std::move(b);
            litehtml::css_length d;
            d = m;
            d = a;
            m = 4.0f;
            CHECK(!m.is_calc() && d.is_calc() && std::abs(float(d.calc_value(200, litehtml::calc_fonts())) - 90.0f) < 0.01f);
        }
        CHECK(litehtml::calc_node::live() == before);

        // A tree holds at most 64 nodes (calc_node::max_nodes): one tree is shared by every element a cached declaration
        // styles and evaluated for each at every layout, and a var() splice can make one declaration as large as the
        // style budget. Each min(1px, 1%) is three nodes and the sum one more: 21 of them fit, 22 do not. A sum is refused
        // as soon as its children pass the cap, so 50,000 of them times a million factors (fifteen seconds when every
        // factor walked every child) end at once.
        {
            const auto sum_of_mins = [](int count, int factors) {
                std::string text = "calc((min(1px, 1%)";
                for (int i = 1; i < count; i++) text += " + min(1px, 1%)";
                text += ")";
                for (int i = 0; i < factors; i++) text += "*1";
                return text + ")";
            };
            const auto parse = [](const std::string& text, litehtml::css_length& l) {
                const auto tokens = litehtml::normalize(text, litehtml::f_componentize);
                return !tokens.empty() && l.from_token(tokens[0], litehtml::f_length_percentage) && l.is_calc();
            };
            litehtml::css_length fits;
            CHECK(parse(sum_of_mins(21, 3), fits) && fits.calc()->nodes == 64);
            CHECK(std::abs(float(fits.calc_value(200, litehtml::calc_fonts())) - 21.0f) < 0.01f);
            litehtml::css_length over;
            CHECK(!parse(sum_of_mins(22, 0), over) && !over.is_calc());
            const auto tokens = litehtml::normalize(sum_of_mins(50000, 1000000), litehtml::f_componentize);
            const auto start = std::chrono::steady_clock::now();
            litehtml::css_length big;
            CHECK(!tokens.empty() && !big.from_token(tokens[0], litehtml::f_length_percentage));
            CHECK(std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count() < 2.0);
        }

        const std::string page = "<html><body style='margin:0'><div style='width:200px;font-size:10px'>"
                                 "<div id=a style='width:calc(50% - 10px);height:2px'></div>"
                                 "<div id=b style='width:clamp(20px, 50%, 60px);height:2px;margin-left:calc(1em + 25%)'></div>"
                                 "</div></body></html>";
        const auto round = [&] {
            auto doc = litehtml_test::layout(c, page, 300);
            const auto a = by_id(doc, "a");
            const auto b = by_id(doc, "b");
            CHECK(a && std::abs(float(a->get_placement().width) - 90.0f) < 0.5f);
            CHECK(b && std::abs(float(b->get_placement().width) - 60.0f) < 0.5f && std::abs(float(b->get_placement().x) - 60.0f) < 0.5f);
            CHECK(a && a->css().get_width().is_calc() && a->css().get_width().units() == litehtml::css_units_percentage);
            auto second = litehtml_test::layout(c, std::string(page).replace(page.find("50% - 10px"), 10, "25% + 10px"), 300);
            const auto a2 = by_id(second, "a");
            CHECK(a2 && std::abs(float(a2->get_placement().width) - 60.0f) < 0.5f);
        };
        round();
        const int64_t cached = litehtml::calc_node::live();
        round();
        round();
        CHECK(litehtml::calc_node::live() == cached);
    }

    // Edit 48: a calc on a property that takes no negative value is clamped at 0 (CSS clamps a math function's result to
    // the property's range), so flex-basis: calc(50% - 8px) is a basis rather than auto, and a width or font size never
    // goes negative; a term that overflows makes no tree, as the parse-time fold refuses it.
    {
        auto doc = litehtml_test::layout(c, "<html><body style='margin:0'><div style='width:200px'>"
                                            "<div id=neg style='width:calc(50% - 300px);height:1px'></div>"
                                            "<div style='display:flex'><div id=basis style='flex:0 0 calc(50% - 8px);height:1px'></div></div>"
                                            "<div id=font style='font-size:calc(10% - 100px)'>x</div>"
                                            "<div id=inf style='width:calc(1% + 1e38px * 1e38 * 1e38);height:1px'></div>"
                                            "</div></body></html>", 300);
        const auto w = [&](const char* id) { auto el = by_id(doc, id); return el ? float(el->get_placement().width) : -1.0f; };
        CHECK(std::abs(w("neg") - 0.0f) < 0.5f);
        CHECK(std::abs(w("basis") - 92.0f) < 0.5f);
        const auto font = by_id(doc, "font");
        CHECK(font && float(font->css().get_font_size()) >= 0.0f);
        CHECK(std::abs(w("inf") - 200.0f) < 0.5f);
    }

    // Edit 39: a block whose width is min-content, max-content or fit-content measures its content in passes that lay a
    // nested keyword box out as auto, and only its fitted pass lays them out in full, at most 8 keyword boxes deep: every
    // pass laying out every nested keyword box in full was exponential in their nesting (2^d renders, uncharged).
    {
        const auto nested = [](int depth) {
            std::string html = "<html><body style='margin:0'><style>div{width:max-content}</style>";
            for (int i = 0; i < depth; i++) html += "<div>";
            html += "word";
            for (int i = 0; i < depth; i++) html += "</div>";
            return html + "</body></html>";
        };
        const auto start = std::chrono::steady_clock::now();
        auto deep = litehtml_test::layout(c, nested(40), 300);
        const double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
        CHECK(seconds < 2.0);
        CHECK(deep && std::abs(float(deep->root()->get_placement().width) - 300.0f) < 0.5f);
        // The nested keyword box still sizes itself in the fitted pass: "ab" beside a longer sibling.
        auto fitted = litehtml_test::layout(c, "<html><body style='margin:0'><div style='width:max-content'>"
                                               "<div id=in style='width:max-content'>ab</div><div>abcdefgh</div></div></body></html>", 300);
        const auto in = by_id(fitted, "in");
        CHECK(in && std::abs(float(in->get_placement().width) - 16.0f) < 0.5f);
        CHECK(in && std::abs(float(in->parent()->get_placement().width) - 64.0f) < 0.5f);
    }

    // Edit 49: a calc text-indent applies whatever its value at a zero percentage base (min(10%, 40px) is 0 there), and
    // a calc font size with a percentage reads its em as the parent's size, as the percentage does.
    {
        auto doc = litehtml_test::layout(c, "<html><body style='margin:0'>"
                                            "<div style='width:200px;text-indent:min(10%, 40px)'><span id=t1>aaaaaaaaaaaaaaaaaaaaaaaa</span> <span id=t2>bb</span></div>"
                                            "<div style='width:200px;text-indent:calc(-10% + 4px)'><span id=t3>cc</span></div>"
                                            "<div style='font-size:20px'><div id=f style='font-size:calc(1em + 10%)'>x</div></div>"
                                            "</body></html>", 300);
        const auto text_x = [&](const char* id) { auto el = by_id(doc, id); return el ? float(el->children().front()->get_placement().x) : -1000.0f; };
        CHECK(std::abs(text_x("t1") - 20.0f) < 0.5f);
        CHECK(std::abs(text_x("t2") - 0.0f) < 0.5f);
        CHECK(std::abs(text_x("t3") + 16.0f) < 0.5f);
        const auto f = by_id(doc, "f");
        CHECK(f && std::abs(float(f->css().get_font_size()) - 22.0f) < 0.01f);
    }

    // Edit 56: a translation whose length mixes a percentage with a length (calc(), nested with a product, and through
    // the translate property) is its share of the box's own size plus the length, as a width's calc is; the fold of one
    // unit refused it, and the whole transform was dropped.
    for (const char* style : {"transform:translateX(calc(100% + 10px))", "transform:translateX(calc(50% - 1 * (100% + 10px) + 50px))",
                              "translate:calc(100% + 10px) 0", "transform:translate(min(150%, 30px), calc(50% - 4px))"}) {
        GroupContainer g;
        auto doc = litehtml_test::layout(g, std::string("<body style='margin:0'><div style='width:20px;height:8px;") + style + "'></div></body>");
        doc->draw(0, litehtml::pixel_t(0.0f), litehtml::pixel_t(0.0f), nullptr);
        const bool ok = g.groups.size() == 1 && std::abs(g.groups[0].tx - 30.0f) < 0.01f && std::abs(g.groups[0].ty) < 0.01f;
        if (!ok) std::printf("  %s: %zu groups, tx %g ty %g\n", style, g.groups.size(), g.groups.empty() ? 0.0 : double(g.groups[0].tx), g.groups.empty() ? 0.0 : double(g.groups[0].ty));
        CHECK(ok);
    }

    // Edit 57: a declaration whose var() never resolves is invalid at computed-value time, so the property is unset: a
    // shorthand's longhands too, over earlier ones (it left them in force), while a longhand written after it stands and
    // a fallback still applies.
    {
        auto doc = litehtml_test::layout(c, "<html><body style='margin:0'><div style='display:flex'>"
                                            "<div id=f1 style='flex-grow:3;flex:var(--nope)'>a</div>"
                                            "<div id=f2 style='flex:var(--nope);flex-grow:2'>b</div>"
                                            "<div id=f3 style='flex-grow:3;flex:var(--nope, 4)'>c</div></div>"
                                            "<div id=m style='margin-left:10px;margin:var(--nope)'>m</div>"
                                            "<div id=b style='border-top:5px solid red;border:var(--nope)'>b</div>"
                                            "</body></html>", 300);
        const auto grow = [&](const char* id) { auto el = by_id(doc, id); return el ? el->css().get_flex_grow() : -1.0f; };
        CHECK(grow("f1") == 0.0f);
        CHECK(grow("f2") == 2.0f);
        CHECK(grow("f3") == 4.0f);
        const auto m = by_id(doc, "m");
        CHECK(m && float(m->get_placement().x) == 0.0f);
        const auto b = by_id(doc, "b");
        CHECK(b && b->css().get_borders().top.style == litehtml::border_style_none);
        if (grow("f1") != 0.0f || grow("f2") != 2.0f || grow("f3") != 4.0f)
            std::printf("  unresolved var(): flex-grow %g %g %g\n", grow("f1"), grow("f2"), grow("f3"));
    }

    // Edit 58: a <use>'s instance inherits from the use, not from where its target sits: a symbol's path with no fill of
    // its own takes each use's fill, while a fill set inside the symbol stands.
    {
        PathContainer p;
        auto doc = litehtml_test::layout(p, "<body style='margin:0'><svg width='100' height='50' viewBox='0 0 100 50'><defs>"
                                            "<symbol id='s' viewBox='0 0 10 10'><path d='M0 0H10V10Z'/></symbol>"
                                            "<symbol id='k' viewBox='0 0 10 10'><path fill='#00ff00' d='M0 0H10V10Z'/></symbol></defs>"
                                            "<use href='#s' width='10' height='10' fill='#ff0000'/>"
                                            "<use href='#s' x='20' width='10' height='10' fill='#0000ff'/>"
                                            "<use href='#k' x='40' width='10' height='10' fill='#ff0000'/>"
                                            "<symbol id='c' viewBox='0 0 10 10'><path fill='currentColor' d='M0 0H10V10Z'/></symbol>"
                                            "<use href='#c' x='60' width='10' height='10' style='color:#ff00ff'/></svg></body>");
        doc->draw(0, litehtml::pixel_t(0.0f), litehtml::pixel_t(0.0f), nullptr);
        // currentColor too: the use's colour.
        if (p.fills != "255,0,0 0,0,255 0,255,0 255,0,255") std::printf("  use fills: %s\n", p.fills.c_str());
        CHECK(p.fills == "255,0,0 0,0,255 0,255,0 255,0,255");
    }

    // Edit 59: a top caption moves a table's rows down by its height once: the cells' positions carry it, so a cell's
    // placement, and a hit where it is drawn, are those of the same table under a block as tall as the caption.
    {
        const std::string rows = "<tr><td id=c style='height:30px;width:60px;padding:0'>x</td></tr></table></body>";
        auto captioned = litehtml_test::layout(c, "<body style='margin:0'><table style='border-spacing:0'>"
                                                  "<caption style='height:40px;padding:0'>c</caption>" + rows);
        auto block = litehtml_test::layout(c, "<body style='margin:0'><div style='height:40px'></div><table style='border-spacing:0'>" + rows);
        const float y = float(by_id(captioned, "c")->get_placement().y), expected = float(by_id(block, "c")->get_placement().y);
        if (y != expected) std::printf("  captioned cell y %g, under a block %g\n", y, expected);
        CHECK(y == expected);
        const auto any = [](const std::shared_ptr<litehtml::render_item>&) { return true; };
        const litehtml::pixel_t x(40.0f), at(expected + 15.0f);
        const auto hit = captioned->root_render()->get_element_by_point(x, at, x, at, any);
        CHECK(hit && hit == by_id(captioned, "c"));
    }

    // Edit 61: a row and a row group have a box, from the table's grid, placed as their cells are: a row across the
    // columns over its height, a group over its rows.
    {
        auto doc = litehtml_test::layout(c, "<body style='margin:0'><table id=t style='border-spacing:0'>"
                                            "<caption style='height:40px;padding:0'>c</caption><tbody id=g>"
                                            "<tr id=r1><td id=a style='height:30px;width:60px;padding:0'>x</td><td id=b style='width:20px;padding:0'>y</td></tr>"
                                            "<tr id=r2><td id=d style='height:20px;padding:0'>z</td><td style='padding:0'>w</td></tr></tbody></table></body>");
        const auto table = std::dynamic_pointer_cast<litehtml::render_item_table>(by_id(doc, "t")->get_render_item());
        litehtml::position r1, g;
        CHECK(table && table->part_placement(by_id(doc, "r1").get(), r1) && table->part_placement(by_id(doc, "g").get(), g));
        const auto a = by_id(doc, "a")->get_placement(), b = by_id(doc, "b")->get_placement(), d = by_id(doc, "d")->get_placement();
        if (float(r1.y) != float(a.y) || float(r1.x) != float(a.x) || float(r1.width) != float(b.right() - a.x) || float(r1.height) != float(a.height))
            std::printf("  row box %g,%g %gx%g\n", float(r1.x), float(r1.y), float(r1.width), float(r1.height));
        CHECK(float(r1.x) == float(a.x) && float(r1.y) == float(a.y));
        CHECK(float(r1.width) == float(b.right() - a.x) && float(r1.height) == float(a.height));
        CHECK(float(g.y) == float(a.y) && float(g.bottom()) == float(d.bottom()) && float(g.width) == float(r1.width));
        litehtml::position none;
        CHECK(table && !table->part_placement(by_id(doc, "a").get(), none));
    }

    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("twidget fork: OK\n");
    return 0;
}
