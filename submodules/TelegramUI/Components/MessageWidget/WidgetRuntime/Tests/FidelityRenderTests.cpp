// Rendering fidelity (fidelity plan): what conformance's in-profile checks expect of the renderer, case by case, each
// through a widget's own document (RenderEnv) and, where a patch can change it, held to a rebuild.
#include <cstdio>
#include <string>
#include <tuple>
#include <variant>

#include "Sources/Render/LayerTree.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

void checkEval(RenderEnv& env, const std::string& code, const std::string& want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("    %s\n    got  %s\n    want %s\n", code.c_str(), got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

std::string page(const std::string& css, const std::string& body) {
    return "<!doctype html><html><head><style>body{margin:0}" + css + "</style></head><body>" + body +
           "<script>window.$ = id => document.getElementById(id);"
           "window.cs = (id, p) => getComputedStyle($(id)).getPropertyValue(p);"
           "window.box = id => { const r = $(id).getBoundingClientRect(); return [r.x, r.width].join('/'); };"
           "</script></body></html>";
}

void expectMatchesRebuild(RenderEnv& env, const char* what) {
    auto [layout, input, tree] = wr_test::rebuildDump(env);
    const bool same = env.render().layoutDump() == layout && env.render().renderInput() == input &&
                      env.render().layerTree()->dump() == tree;
    if (!same) {
        std::printf("    %s: the flush differs from a rebuild\n", what);
    }
    CHECK(same);
}

size_t imageMarkers(const wr::Layer& layer) {
    size_t count = 0;
    for (const auto& entry : layer.entries) {
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            if (const auto* marker = std::get_if<wr::ListMarkerItem>(&item->payload)) {
                count += marker->image ? 1 : 0;
            }
        } else {
            count += imageMarkers(*std::get<std::unique_ptr<wr::Layer>>(entry));
        }
    }
    return count;
}

/// The origin boxes of the image items, "x,y,w,h" joined by spaces, in paint order.
std::string imageOrigins(const wr::Layer& layer) {
    std::string out;
    for (const auto& entry : layer.entries) {
        std::string piece;
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            if (const auto* image = std::get_if<wr::ImageItem>(&item->payload)) {
                const litehtml::position& o = image->layer.origin_box;
                char buf[96];
                std::snprintf(buf, sizeof(buf), "%g,%g,%g,%g", float(o.x), float(o.y), float(o.width), float(o.height));
                piece = buf;
            }
        } else {
            piece = imageOrigins(*std::get<std::unique_ptr<wr::Layer>>(entry));
        }
        if (!piece.empty()) {
            out += (out.empty() ? "" : " ") + piece;
        }
    }
    return out;
}

/// Every path and text the layer tree paints, in document coordinates (each layer's group matrix applied): a path as
/// "path r,g,b x0,y0,x1,y1" (the bounds of its points), a text as "text 'value' r,g,b x,y".
void svgPaints(const wr::Layer& layer, const litehtml::transform_matrix& toRoot, std::vector<std::string>& out) {
    for (const auto& entry : layer.entries) {
        if (const wr::PaintItem* item = std::get_if<wr::PaintItem>(&entry)) {
            char buf[160];
            if (const auto* path = std::get_if<wr::PathItem>(&item->payload)) {
                const auto& pts = path->path.points;
                float x0 = 1e9f, y0 = 1e9f, x1 = -1e9f, y1 = -1e9f;
                for (size_t i = 0; i + 1 < pts.size(); i += 2) {
                    const float x = toRoot.a * pts[i] + toRoot.c * pts[i + 1] + toRoot.tx;
                    const float y = toRoot.b * pts[i] + toRoot.d * pts[i + 1] + toRoot.ty;
                    x0 = std::min(x0, x), y0 = std::min(y0, y), x1 = std::max(x1, x), y1 = std::max(y1, y);
                }
                const auto& c = path->path.fill_color;
                std::snprintf(buf, sizeof(buf), "path %d,%d,%d %g,%g,%g,%g", c.red, c.green, c.blue, x0, y0, x1, y1);
                out.push_back(buf);
            } else if (const auto* text = std::get_if<wr::TextItem>(&item->payload)) {
                const float x = toRoot.a * float(text->pos.x) + toRoot.c * float(text->pos.y) + toRoot.tx;
                const float y = toRoot.b * float(text->pos.x) + toRoot.d * float(text->pos.y) + toRoot.ty;
                std::snprintf(buf, sizeof(buf), "text '%s' %d,%d,%d %g,%g", text->text.c_str(), text->color.red,
                              text->color.green, text->color.blue, x, y);
                out.push_back(buf);
            }
        } else {
            const wr::Layer& child = *std::get<std::unique_ptr<wr::Layer>>(entry);
            svgPaints(child, child.kind == wr::Layer::Kind::Group ? child.group.matrix.then(toRoot) : toRoot, out);
        }
    }
}

std::vector<std::string> svgPaints(RenderEnv& env) {
    std::vector<std::string> out;
    if (std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree()) {
        svgPaints(tree->root(), litehtml::transform_matrix(), out);
    }
    return out;
}

void expectPaints(RenderEnv& env, const std::vector<std::string>& want) {
    const std::vector<std::string> got = svgPaints(env);
    if (got != want) {
        for (const std::string& line : got) {
            std::printf("    got  %s\n", line.c_str());
        }
        for (const std::string& line : want) {
            std::printf("    want %s\n", line.c_str());
        }
    }
    CHECK(got == want);
}

// A 40×20 RGBA PNG, its left half red and its right half blue.
const char* const kPng40x20 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAYAAAD/Rn+7AAAALElEQVR42u3OsQ0AAAzCMP5/mj7BVHnIGjlNumy8awABAQEBAQEBAQEBPwMPbG46G0q0eUoAAAAASUVORK5CYII=";

// A 3×2 RGBA PNG (signature, IHDR, IDAT, IEND).
const char* const kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

} // namespace

/// css.color.basic: CSS Color 4's named colours litehtml lacked, and two it had wrong.
WR_TEST(testTheNamedColours) {
    RenderEnv env(page("", "<div id=a style='background:rebeccapurple'>a</div><div id=b style='color:indianred'>b</div>"
                           "<div id=c style='color:indigo'>c</div><div id=d style='color:mediumpurple'>d</div>"
                           "<div id=e style='color:palevioletred'>e</div>"));
    checkEval(env, "cs('a', 'background-color')", "rgb(102, 51, 153)");
    checkEval(env, "cs('b', 'color')", "rgb(205, 92, 92)");
    checkEval(env, "cs('c', 'color')", "rgb(75, 0, 130)");
    checkEval(env, "cs('d', 'color')", "rgb(147, 112, 219)");
    checkEval(env, "cs('e', 'color')", "rgb(219, 112, 147)");
}

/// css.display.table: an auto column with no content takes what a fixed column leaves (CSS 2.1 §17.5.2.2).
WR_TEST(testAnEmptyAutoColumnTakesTheRest) {
    RenderEnv env(page("#tbl{display:table;width:200px} #tbl>div{display:table-cell;height:10px}",
                       "<div id=tbl><div id=c1 style='width:50px'></div><div id=c2></div></div>"));
    checkEval(env, "box('c1') + ' ' + box('c2')", "0/50 50/150");
}

/// D2: list-style's shorthand takes an image (a URL token is no list-style-type keyword).
WR_TEST(testListStyleTakesAnImage) {
    RenderEnv env(page(std::string("li{list-style:url(") + kPng3x2 + ") inside}", "<ul><li>a</li><li>b</li></ul>"));
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    CHECK(tree && imageMarkers(tree->root()) == 2);
    checkEval(env, "getComputedStyle(document.querySelector('li')).listStyleType", "disc");
}

/// D2: an image bullet set on the list reaches its items however long its URL (twidget edit 60): they share the list's
/// copy, where an inherited URL over 1 KiB was dropped.
WR_TEST(testAListsLongImageBulletReachesItsItems) {
    const std::string url = std::string(kPng3x2) + "#" + std::string(2000, 'a');
    RenderEnv env(page("ul{list-style:url(" + url + ") inside}", "<ul><li>a</li><li>b <b>c</b></li></ul>"));
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    CHECK(tree && imageMarkers(tree->root()) == 2);
}

/// html.attr.global: :lang() matches the language an element's own or an ancestor's lang attribute gives (Selectors 4:
/// case-insensitive, a prefix up to a hyphen), never the container's default; a lang change re-matches as a rebuild.
WR_TEST(testLangFollowsTheAttribute) {
    RenderEnv env(page(":lang(ru) .lg{color:rgb(0,100,0)} :lang(en){color:rgb(0,0,100)}",
                       "<div id=ru lang=RU-ru><span class=lg id=lg>x</span></div><div id=plain><span class=lg id=pl>y</span></div>"
                       "<div lang=en><p id=en>z</p></div>"));
    checkEval(env, "cs('lg', 'color')", "rgb(0, 100, 0)");
    checkEval(env, "cs('pl', 'color') !== 'rgb(0, 100, 0)' && cs('pl', 'color') !== 'rgb(0, 0, 100)'", "true");
    checkEval(env, "cs('en', 'color')", "rgb(0, 0, 100)");
    env.env().eval("$('ru').setAttribute('lang', 'de'); $('plain').setAttribute('lang', 'ru'); 1");
    env.flush();
    checkEval(env, "cs('lg', 'color') !== 'rgb(0, 100, 0)'", "true");
    checkEval(env, "cs('pl', 'color')", "rgb(0, 100, 0)");
    expectMatchesRebuild(env, "lang changed");
}

/// sel.structural: :empty matches an element with no element children and no text; a patch that fills or empties one
/// re-matches as a rebuild.
WR_TEST(testEmptyMatchesAndFollowsPatches) {
    RenderEnv env(page("#st .m:empty{color:rgb(28,0,0)} #st .m:not(:empty){color:rgb(29,0,0)}",
                       "<div id=st><span class=m id=e></span><span class=m id=n>x</span><span class=m id=c><!--c--></span>"
                       "</div>"));
    checkEval(env, "cs('e', 'color')", "rgb(28, 0, 0)");
    checkEval(env, "cs('n', 'color')", "rgb(29, 0, 0)");
    checkEval(env, "cs('c', 'color')", "rgb(28, 0, 0)");
    env.env().eval("$('e').textContent = 'now'; 1");
    env.flush();
    checkEval(env, "cs('e', 'color')", "rgb(29, 0, 0)");
    expectMatchesRebuild(env, "filled");
    env.env().eval("$('n').firstChild.data = ''; 1");
    env.flush();
    checkEval(env, "cs('n', 'color')", "rgb(28, 0, 0)");
    expectMatchesRebuild(env, "emptied by a text change");
    env.env().eval("$('e').firstChild.remove(); 1");
    env.flush();
    checkEval(env, "cs('e', 'color')", "rgb(28, 0, 0)");
    expectMatchesRebuild(env, "emptied by a removal");
}

/// Fidelity plan, Task 3 (html.el.a-fragment, html.el.a-external): a link is drawn as one, in the chat's link colour,
/// a fragment and an external href (rewritten to "#" with data-tg-link) alike; since widget-sandbox v0.1.1 the UA layer
/// draws it with no underline (`a[href]`).
WR_TEST(testALinkLooksLikeOne) {
    RenderEnv env(page("", "<span id=base>b</span> <a id=afrag href=#x>f</a> <a id=aext href='https://example.org/'>e</a>"
                           " <a id=bare>n</a>"));
    checkEval(env, "cs('afrag', 'color') !== cs('base', 'color')", "true");
    checkEval(env, "cs('afrag', 'color') === cs('aext', 'color')", "true");
    checkEval(env, "cs('afrag', 'color') === getComputedStyle(document.documentElement).getPropertyValue('--tg-theme-link-color')"
                   " || cs('afrag', 'color').startsWith('rgb(51, 144, 236')", "true");
    checkEval(env, "cs('afrag', 'text-decoration-line') + ' ' + cs('aext', 'text-decoration-line')", "none none");
    // An anchor with no href is no link.
    checkEval(env, "cs('bare', 'text-decoration-line')", "none");
}

/// Fidelity plan, Task 3 (html.el.details): a summary is a list item whose marker is the disclosure triangle, and a
/// closed details stays as tall as its summary.
WR_TEST(testASummaryIsAListItem) {
    RenderEnv env(page("", "<details id=det><summary id=sum>s</summary><p>hidden</p></details>"));
    checkEval(env, "cs('sum', 'display')", "list-item");
    checkEval(env, "Math.abs($('det').getBoundingClientRect().height - $('sum').getBoundingClientRect().height) < 0.5", "true");
}

/// Fidelity plan, Task 3 (html.el.inline-text): <q> adds quotation marks.
WR_TEST(testQAddsQuotationMarks) {
    RenderEnv env(page("", "<div><q id=q>quoted</q></div><div><span id=plain>quoted</span></div>"));
    checkEval(env, "$('q').getBoundingClientRect().width > $('plain').getBoundingClientRect().width + 2", "true");
}

/// Fidelity plan, Task 5 (css.font.variant-numeric): font-feature-settings "tnum" asks the host for tabular figures, as
/// font-variant-numeric: tabular-nums does; "tnum" 0 or off does not.
WR_TEST(testFontFeatureSettingsTnum) {
    RenderEnv env(page("#t{font-family:serif;font-size:21px;font-feature-settings:\"tnum\"}"
                       " #o{font-family:serif;font-size:22px;font-feature-settings:\"tnum\" 0}"
                       " #k{font-family:serif;font-size:23px;font-feature-settings:'liga' 1, 'tnum' on}",
                       "<span id=t>1111</span><span id=o>1111</span><span id=k>1111</span>"));
    bool t = false, o = false, k = false;
    for (const auto& created : env.host().createdFonts) {
        const float size = float(created.description.size);
        t = t || (size == 21.0f && created.description.tabular_nums);
        o = o || (size == 22.0f && created.description.tabular_nums);
        k = k || (size == 23.0f && created.description.tabular_nums);
    }
    CHECK(t);
    CHECK(!o);
    CHECK(k);
}

/// Fidelity plan, Task 5 (css.text.transform's word-spacing check): word-spacing adds to every space, and is inherited.
WR_TEST(testWordSpacing) {
    RenderEnv env(page("", "<div><span id=plain>a b c</span></div><div style='word-spacing:10px'><span id=w>a b c</span></div>"));
    checkEval(env, "Math.round($('w').getBoundingClientRect().width - $('plain').getBoundingClientRect().width)", "20");
}

/// Fidelity plan, Task 5 (css.text.wrap): word-break: break-all breaks a long word at its box's edge.
WR_TEST(testWordBreakBreakAll) {
    RenderEnv env(page("#wb,#nb{width:40px;font:16px/16px serif} #wb{word-break:break-all} #nb{overflow-wrap:normal}",
                       "<div id=wb>aaaaaaaaaaaaaaaaaaaa</div><div id=nb>aaaaaaaaaaaaaaaaaaaa</div>"));
    checkEval(env, "$('wb').getBoundingClientRect().height >= 31", "true");
    checkEval(env, "$('nb').getBoundingClientRect().height", "16");
}

/// The fake host breaks between code points, never inside one (CoreTextRenderHost between composed character
/// sequences): a word of three-byte characters broken anywhere in a box narrower than one paints each whole, one per line.
WR_TEST(testABreakAnywhereKeepsCharactersWhole) {
    RenderEnv env(page("#wb{width:20px;font:16px/16px serif;word-break:break-all}", "<div id=wb>−−−</div>"));
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    CHECK(tree != nullptr);
    if (!tree) {
        return;
    }
    size_t pieces = 0;
    for (const wr::TextItem* item : wr_test::textItems(*tree)) {
        CHECK_EQ(item->text, std::string("−"));
        pieces++;
    }
    CHECK_EQ(pieces, size_t(3));
}

/// Fidelity plan, Task 6 (css.value.keywords, html.el.structure): initial, unset and revert, through the profile.
WR_TEST(testTheCSSWideKeywords) {
    RenderEnv env(page("p{margin-top:0;margin-bottom:2px} #marg p{margin:revert} #initial{display:initial}"
                       " #unset-parent{color:rgb(0,0,140)} #unset{color:rgb(200,0,0);color:unset}"
                       " #revert{display:inline;display:revert} #ci{--x:rgb(9,9,9)} #cis{--x:initial;color:var(--x,rgb(1,2,3))}",
                       "<div id=marg><p id=p1>p</p></div><div id=initial>i</div><div id=unset-parent><span id=unset>u</span>"
                       "</div><div id=revert>r</div><div id=ci><span id=cis>c</span></div>"));
    checkEval(env, "cs('p1', 'margin-top') === cs('p1', 'font-size') && cs('p1', 'margin-bottom') === cs('p1', 'font-size')",
              "true");
    checkEval(env, "cs('initial', 'display')", "inline");
    checkEval(env, "cs('unset', 'color')", "rgb(0, 0, 140)");
    checkEval(env, "cs('revert', 'display')", "block");
    checkEval(env, "cs('cis', 'color')", "rgb(1, 2, 3)");
}

/// v0.1.1 plan, Task 1 (twidget edit 41): a layer in the master sheet (the profile's UA layer) ranks above litehtml's
/// own rules and revert skips it: `p{margin:revert}` is litehtml's 1em, not the layer's 3px; a class patched in place
/// under the layer matches a rebuild.
WR_TEST(testRevertSkipsTheMastersLayer) {
    wr::RenderOptions options;
    options.hostCSS += " @layer tw-ua{p{margin:3px 0} .k{margin:5px 0}}";
    RenderEnv env(page(".r{margin:revert}", "<p id=p>p</p><p id=r class=r>r</p><p id=k>k</p>"), options);
    checkEval(env, "cs('p', 'margin-top')", "3px");
    checkEval(env, "cs('r', 'margin-top') === cs('r', 'font-size')", "true");
    env.env().eval("$('k').className = 'k'; 1");
    env.flush();
    checkEval(env, "cs('k', 'margin-top')", "5px");
    expectMatchesRebuild(env, "layered class");
    env.env().eval("$('k').className = 'r'; 1");
    env.flush();
    checkEval(env, "cs('k', 'margin-top') === cs('k', 'font-size')", "true");
    expectMatchesRebuild(env, "revert under the layer");
}

/// Fidelity plan, Task 6: a class that brings a revert in, patched in place, matches a rebuild; so does taking it away.
WR_TEST(testARevertFollowsAClassPatch) {
    RenderEnv env(page("p{margin:0} .r{margin:revert}", "<p id=p>x</p>"));
    env.env().eval("$('p').className = 'r'; 1");
    env.flush();
    checkEval(env, "cs('p', 'margin-top') === cs('p', 'font-size')", "true");
    expectMatchesRebuild(env, "revert added");
    env.env().eval("$('p').className = ''; 1");
    env.flush();
    checkEval(env, "cs('p', 'margin-top')", "0px");
    expectMatchesRebuild(env, "revert removed");
}

/// Fidelity plan, Task 7 (css.transform.2d): getBoundingClientRect and getClientRects are the bounds of the transformed
/// box (CSSOM View), an ancestor's transform included; offsetLeft, offsetTop and offsetWidth stay the layout box.
WR_TEST(testRectsAreTransformed) {
    RenderEnv env(page(".b{width:40px;height:20px} #tx{transform:translateX(30px)} #rot{transform:rotate(90deg)}"
                       " #sc{transform:scale(2);transform-origin:0 0;width:10px} #outer{transform:translateX(7px)}",
                       "<div class=b id=tx></div><div class=b id=rot></div><div class=b id=sc></div>"
                       "<div id=outer><div class=b id=inner></div></div>"
                       "<script>window.rr = (id, r = $(id).getBoundingClientRect()) =>"
                       " [r.x, r.y - $(id).offsetTop, r.width, r.height].map(Math.round).join('/');</script>"));
    checkEval(env, "rr('tx') + ' ' + $('tx').offsetLeft + ' ' + $('tx').offsetWidth", "30/0/40/20 0 40");
    checkEval(env, "Math.round($('tx').getClientRects()[0].x)", "30");
    checkEval(env, "rr('rot')", "10/-10/20/40");
    checkEval(env, "rr('sc')", "0/0/20/40");
    checkEval(env, "rr('inner')", "7/0/40/20");
}

/// Fidelity plan, Task 7 (css.transform.2d): the translate, rotate and scale properties move the box, before transform
/// in the order translate, rotate, scale (CSS Transforms 2 §6); getComputedStyle's transform is transform's alone.
WR_TEST(testTheIndividualTransformProperties) {
    RenderEnv env(page(".b{width:40px;height:20px} #tr{translate:10px 5px} #rp{rotate:90deg} #sp{scale:2;transform-origin:0 0}"
                       " #ord{translate:10px 0;rotate:90deg;transform:translateX(10px)}",
                       "<div class=b id=tr></div><div class=b id=rp></div><div class=b id=sp></div><div class=b id=ord></div>"
                       "<script>window.rr = (id, r = $(id).getBoundingClientRect()) =>"
                       " [r.x, r.y - $(id).offsetTop, r.width, r.height].map(Math.round).join('/');</script>"));
    checkEval(env, "rr('tr')", "10/5/40/20");
    checkEval(env, "rr('rp')", "10/-10/20/40");
    checkEval(env, "rr('sp')", "0/0/80/40");
    // Applied right to left about the centre: transform, then rotate, then translate (the reverse order gives x 30).
    checkEval(env, "rr('ord')", "20/0/20/40");
    checkEval(env, "cs('tr', 'transform')", "none");
}

/// Fidelity plan, Task 7: a translate, rotate or scale set from script moves the box, and the flush matches a rebuild
/// (they start and end a paint group as transform does).
WR_TEST(testAnIndividualTransformPatchMatchesARebuild) {
    RenderEnv env(page("#t{width:40px;height:20px;background:red}", "<div id=t></div><div id=u>u</div>"));
    for (const char* change : {"$('t').style.translate = '10px 5px'", "$('t').style.rotate = '90deg'", "$('t').style.scale = '2'",
                               "$('t').style.translate = ''", "$('t').style.cssText = ''"}) {
        env.env().eval(std::string(change) + "; 1");
        env.flush();
        expectMatchesRebuild(env, change);
    }
    env.env().eval("$('t').style.translate = '10px 5px'; 1");
    env.flush();
    checkEval(env, "Math.round($('t').getBoundingClientRect().x)", "10");
}

/// Fidelity plan, Task 8 (css.box.object-fit): an image is drawn at the size object-fit gives it from its natural size,
/// placed by object-position (default centred), and clipped to its content box.
WR_TEST(testObjectFitAndPosition) {
    const std::string src = std::string(" src='") + kPng40x20 + "'";
    RenderEnv env(page("img{display:block;width:34px;height:40px}",
                       "<img" + src + "><img" + src + " style='object-fit:cover'><img" + src +
                           " style='object-fit:contain;object-position:0 100%'><img" + src + " style='object-fit:none'><img" +
                           src + " style='object-fit:scale-down'>"));
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const std::string got = tree ? imageOrigins(tree->root()) : std::string();
    const std::string want = "0,0,34,40 -23,40,80,40 0,103,34,17 -3,130,40,20 0,171.5,34,17";
    if (got != want) {
        std::printf("    got  %s\n    want %s\n", got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

/// Fidelity plan, Task 9 (svg.structure): <use> of a <symbol> opens a viewport (its width and height, the symbol's
/// viewBox, xMidYMid meet) at the use's x and y, inside the use's own transform; the stage's two uses.
WR_TEST(testUseInstantiatesASymbol) {
    RenderEnv env(page("", "<svg width=80 height=60 viewBox='0 0 40 30'><defs><symbol id=sym viewBox='0 0 10 10'>"
                           "<path d='M0 0H10V10Z' fill='rgb(51,102,204)'/></symbol></defs>"
                           "<use href='#sym' x=22 y=2 width=14 height=14 /><use href='#sym' x=4 y=16 width=10 height=10 "
                           "transform='scale(1.2)' /></svg>"));
    expectPaints(env, {"path 51,102,204 44,4,72,32", "path 51,102,204 9.6,38.4,33.6,62.4"});
}

/// Fidelity plan, Task 9 (svg.structure): <use> of an element other than a symbol draws it at x and y; a use of itself,
/// of an ancestor or of a cycle draws nothing more, and an exponential chain stops at the instance budget.
WR_TEST(testUseOfAnElementAndHostileUses) {
    RenderEnv env(page("", "<svg width=100 height=100><rect id=r width=10 height=10 fill='rgb(1,0,0)'/>"
                           "<use href='#r' x=20 y=30 /><use id=me href='#me'/><g id=g><use href='#g'/></g>"
                           "<g id=c1><use href='#c2'/></g><g id=c2><use href='#c1'/></g></svg>"));
    expectPaints(env, {"path 1,0,0 0,0,10,10", "path 1,0,0 20,30,30,40"});
    // Twenty levels of ten uses each: 10^20 instances unbounded.
    std::string chain = "<svg width=10 height=10><defs><g id=a0><rect width=1 height=1 fill='rgb(2,0,0)'/></g>";
    for (int level = 1; level <= 20; level++) {
        chain += "<g id=a" + std::to_string(level) + ">";
        for (int i = 0; i < 10; i++) {
            chain += "<use href='#a" + std::to_string(level - 1) + "'/>";
        }
        chain += "</g>";
    }
    chain += "</defs><use href='#a4'/><use href='#a20'/></svg>";
    RenderEnv hostile(page("", chain));
    const std::vector<std::string> paints = svgPaints(hostile);
    // a4 is four levels deep: 10^4 rects, more than the budget allows; a20 is deeper than the nesting limit.
    std::printf("    hostile chain: %zu paths\n", paints.size());
    CHECK(!paints.empty() && paints.size() <= 8192);
}

/// Review minors, Task 1 (M2): the font cache's key holds a calc length's tree, not its value at a zero percentage
/// base, so two decoration thicknesses with equal px parts get fonts of their own.
WR_TEST(testCalcDecorationThicknessKeysTheFont) {
    RenderEnv env(page("", "<p style='font-size:20px'><span style='text-decoration:underline;text-decoration-thickness:"
                           "calc(10% + 1px)'>a</span> <span style='text-decoration:underline;text-decoration-thickness:"
                           "calc(30% + 1px)'>b</span></p>"));
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const std::string dump = tree ? tree->dump() : std::string();
    CHECK(dump.find("%:10") != std::string::npos);
    CHECK(dump.find("%:30") != std::string::npos);
}

/// Fidelity plan, Task 9, review: the instance budget is the document's, not each <svg>'s, so many small svgs each using
/// a large fan-out record at most 8,192 instanced elements together (each svg having its own budget let a few KB of markup
/// record gigabytes of paths). A later svg draws what the earlier ones left.
WR_TEST(testUseBudgetIsTheDocuments) {
    std::string html = "<svg width=0 height=0><defs><g id=a0><rect width=1 height=1 fill='rgb(3,0,0)'/></g>";
    for (int level = 1; level <= 4; level++) {
        html += "<g id=a" + std::to_string(level) + ">";
        for (int i = 0; i < 10; i++) {
            html += "<use href='#a" + std::to_string(level - 1) + "'/>";
        }
        html += "</g>";
    }
    html += "</defs></svg>";
    for (int i = 0; i < 12; i++) {
        html += "<svg width=2 height=2><use href='#a4'/></svg>";
    }
    RenderEnv env(page("", html));
    const std::vector<std::string> paints = svgPaints(env);
    std::printf("    twelve svgs: %zu paths\n", paints.size());
    CHECK(!paints.empty() && paints.size() <= 8192);
}

/// Fidelity plan, Task 9: a change to a symbol that another <svg> uses repaints the use, as a rebuild would.
WR_TEST(testAChangedSymbolRepaintsItsUses) {
    RenderEnv env(page("", "<svg width=10 height=10><defs><symbol id=s viewBox='0 0 10 10'><rect id=r width=10 height=10 "
                           "fill='rgb(1,0,0)'/></symbol></defs></svg><svg width=20 height=20><use href='#s' width=20 "
                           "height=20 /></svg>"));
    // The two inline svgs sit side by side: the use draws at x 10.
    expectPaints(env, {"path 1,0,0 10,0,30,20"});
    for (const char* change : {"$('r').setAttribute('fill', 'rgb(2,0,0)')", "$('r').setAttribute('width', '5')",
                               "$('r').remove()"}) {
        env.env().eval(std::string(change) + "; 1");
        env.flush();
        expectMatchesRebuild(env, change);
    }
}

/// Fidelity plan, Task 9 (svg.text): a tspan's own fill, and its dx and dy, move the run after it; text-anchor moves the
/// whole chunk.
WR_TEST(testTspanRuns) {
    RenderEnv env(page("text{font:16px/16px serif}",
                       "<svg width=100 height=60><text x=4 y=24 fill='rgb(34,34,34)'>Ab<tspan fill='rgb(204,51,51)' dy=6>c"
                       "</tspan>d</text><text x=96 y=52 text-anchor=end fill='rgb(51,102,204)'>xy<tspan dx=2>z</tspan></text>"
                       "</svg>"));
    const std::vector<std::string> paints = svgPaints(env);
    for (const std::string& line : paints) {
        std::printf("    %s\n", line.c_str());
    }
    // The fake host's text is 8 px a byte: Ab is 16 wide, so c starts at 20, 6 lower, and d after it, at its height.
    CHECK(paints.size() == 5);
    if (paints.size() == 5) {
        float ax = 0, ay = 0, cx = 0, cy = 0, dx = 0, dy = 0, xx = 0, zx = 0;
        std::sscanf(paints[0].c_str(), "text 'Ab' 34,34,34 %g,%g", &ax, &ay);
        CHECK(std::sscanf(paints[1].c_str(), "text 'c' 204,51,51 %g,%g", &cx, &cy) == 2);
        CHECK(std::sscanf(paints[2].c_str(), "text 'd' 34,34,34 %g,%g", &dx, &dy) == 2);
        CHECK(cx - ax == 16 && cy - ay == 6 && dx - cx == 8 && dy == cy);
        // xy and z (dx 2) are one chunk 26 wide ending at 96: xy at 70, z at 88.
        CHECK(std::sscanf(paints[3].c_str(), "text 'xy' 51,102,204 %g", &xx) == 1 && xx == 70);
        CHECK(std::sscanf(paints[4].c_str(), "text 'z' 51,102,204 %g", &zx) == 1 && zx == 88);
    }
}

/// Fidelity plan, Task 12 (css.box.size): width fit-content is min(max-content, max(min-content, available)); max-content
/// and min-content are the content's own widths. The fake host's text is 8 px a byte.
WR_TEST(testIntrinsicWidths) {
    const std::string words = "aaaa bbbb cccc dddd eeee ffff gggg hhhh iiii jjjj kkkk";
    RenderEnv env(page("#w{width:200px;font:16px/16px serif} .fc{width:fit-content} .mx{width:max-content}"
                       " .mn{width:min-content}",
                       "<div id=w><div class=fc id=a>x</div><div class=fc id=b>" + words + "</div><div class=mx id=c>" + words +
                           "</div><div class=mn id=d>aaaa bbbb</div><div class=fc id=e>abcdefghijklmnopqrstuvwxyz0123</div></div>"));
    checkEval(env, "box('a')", "0/8");
    checkEval(env, "box('b')", "0/200");
    checkEval(env, "box('c')", "0/432");
    checkEval(env, "box('d')", "0/32");
    // A word wider than the box: min-content wins.
    checkEval(env, "box('e')", "0/240");
}

/// Fidelity plan, Task 12 (css.text.overflow): a line that overflows a clipping block with text-overflow: ellipsis ends
/// in "…" drawn in the block's colour, after what of its text fits; a line that fits gets none.
WR_TEST(testTextOverflowEllipsis) {
    RenderEnv env(page(".el{width:66px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:rgb(51,102,204);"
                       "font:16px/16px serif}",
                       "<div class=el id=a><span style='color:rgb(34,34,34)'>abcdefghijkl</span></div>"
                       "<div class=el id=b>abc</div>"));
    const std::vector<std::string> paints = svgPaints(env);
    for (const std::string& line : paints) {
        std::printf("    %s\n", line.c_str());
    }
    // 66 wide, the ellipsis (3 bytes in UTF-8, 24 px here) leaves 42: five letters (40 px) of the span, then the
    // ellipsis at 40 in the block's colour; the second line fits whole.
    const std::vector<std::string> want = {"text 'abcde' 34,34,34 0,0", "text '\xE2\x80\xA6' 51,102,204 40,0",
                                           "text 'abc' 51,102,204 0,16"};
    CHECK(paints == want);
    // A text change re-cuts the line, as a rebuild would; one that fits loses the ellipsis.
    for (const char* change : {"$('b').firstChild.data = 'abcdefghijklmnop'", "$('a').firstChild.firstChild.data = 'ab'"}) {
        env.env().eval(std::string(change) + "; 1");
        env.flush();
        expectMatchesRebuild(env, change);
    }
    // a now fits whole; b is cut and gets the ellipsis.
    CHECK(svgPaints(env).size() == 3);
}

/// Fidelity plan, Task 5 (css.value.content): quotes is kept, inherited and read back; auto by default.
WR_TEST(testQuotesReadsBack) {
    RenderEnv env(page("#q{quotes:\"\xC2\xAB\" \"\xC2\xBB\"}", "<div id=q><span id=in>x</span></div><div id=n>n</div>"));
    checkEval(env, "/\xC2\xAB/.test(cs('q', 'quotes'))", "true");
    checkEval(env, "cs('in', 'quotes') === cs('q', 'quotes')", "true");
    checkEval(env, "cs('n', 'quotes')", "auto");
}

/// Fidelity T11, RTL phase 1 (html.attr.dir, css.text.align, css.text.rtl; css.box.logical out of profile): dir and
/// the `direction` property set the direction, inherited; start and end resolve against it (an RTL line starts at the
/// right edge, end is the left); an over-constrained block in an RTL parent ignores its left margin and sits flush
/// right; dir=auto takes the direction of its first strong character, the DOM keeping "auto"; dir is matched whatever
/// its case.
WR_TEST(testRightToLeftPhaseOne) {
    RenderEnv env(page("div{width:200px}",
                       "<div id=box dir=rtl><span id=s>abc</span><p id=child></p></div>"
                       "<div id=end dir=rtl style='text-align:end'><span id=e>abc</span></div>"
                       "<div id=parent dir=rtl><div id=b style='width:20px;margin:0;height:5px'></div></div>"
                       "<div id=heb dir=auto>\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d</div><div id=lat dir=auto>hello</div>"
                       "<div id=css style='direction:rtl'></div><div id=upper dir=RTL></div><div id=plain><span id=l>abc</span></div>"));
    checkEval(env, "['box', 'child', 'heb', 'lat', 'css', 'upper', 'plain'].map(id => cs(id, 'direction')).join()",
              "rtl,rtl,rtl,ltr,rtl,rtl,ltr");
    checkEval(env, "[cs('box', 'text-align'), $('heb').getAttribute('dir'), $('heb').dir].join()", "start,auto,auto");
    // The RTL start is the right edge; end is the left; LTR start stays left.
    checkEval(env, "(r => Math.round(r.right))($('s').getBoundingClientRect())", "200");
    checkEval(env, "(r => Math.round(r.left))($('e').getBoundingClientRect())", "0");
    checkEval(env, "(r => Math.round(r.left))($('l').getBoundingClientRect())", "0");
    checkEval(env, "(r => [r.left, r.right].map(Math.round).join())($('b').getBoundingClientRect())", "180,200");
}

/// Review minors, Task 5 (M8): a bidi unit takes the level of its first strong character, not of its first character:
/// a piece can start with a neutral ("(" before a Hebrew word), whose level is the paragraph's here. Both Hebrew words
/// are at level 1, so they swap and the earlier ends rightmost, as in Chrome (whose box for it also holds the "(" left
/// of the run, so only the right edges compare).
WR_TEST(testABidiUnitTakesItsStrongLevel) {
    RenderEnv env(page("p{margin:0;width:300px}", "<p>ab <b id=b>(\xd7\x90\xd7\x90</b> <i id=i>\xd7\x91\xd7\x91</i></p>"));
    checkEval(env, "$('b').getBoundingClientRect().right > $('i').getBoundingClientRect().right", "true");
}

/// Review minors, Task 4 (M7): an element's client rect maps through its own and every ancestor's transform composed,
/// not through a bounding box per level: a rotation undone by the child's leaves the child's own box, and a scale(0)
/// collapses to a finite point.
WR_TEST(testNestedTransformsCompose) {
    RenderEnv env(page("div{width:100px;height:100px}", "<div id=out style='margin:50px;transform:rotate(45deg)'>"
                       "<div id=in style='transform:rotate(-45deg)'></div></div><div style='margin:50px;transform:"
                       "rotate(45deg)'><div id=z style='transform:scale(0)'></div></div>"));
    checkEval(env, "(o => (i => [i.width, i.height, i.left + i.width / 2 - (o.left + o.width / 2), i.top + i.height / 2 - "
                   "(o.top + o.height / 2)].map(Math.round).join())($('in').getBoundingClientRect()))"
                   "($('out').getBoundingClientRect())",
              "100,100,0,0");
    checkEval(env, "(r => [r.width, r.height, Number.isFinite(r.left) && Number.isFinite(r.top)].join())"
                   "($('z').getBoundingClientRect())",
              "0,0,true");
    // Composed in double, as each level used to map: two nested scale(1e20) are 1e40, past a float, and stay finite.
    RenderEnv huge(page("div{width:10px;height:10px}", "<div style='transform:scale(1e20)'><div id=h "
                        "style='transform:scale(1e20)'></div></div>"));
    checkEval(huge, "(r => [r.left, r.top, r.width, r.height].every(Number.isFinite))($('h').getBoundingClientRect())",
              "true");
}

/// Review minors, Task 3 (M6): revert-layer in an unlayered author rule rolls back to the UA layer's value (in the
/// reference the layer is an author-origin @layer), where revert skips the layer to the engine's own UA value; a property
/// the layer does not set rolls back as revert does.
WR_TEST(testRevertLayerStopsAtTheUALayer) {
    RenderEnv env(page("", "<p id=a style='margin:revert'>x</p><p id=b style='margin:revert-layer'>x</p><p id=c>x</p>"
                           "<u id=d style='text-decoration:revert-layer'>x</u>"));
    // <u>'s underline is the engine's alone: revert-layer finds nothing in the layer and keeps rolling back to it.
    checkEval(env, "[cs('b', 'margin-top') == cs('c', 'margin-top'), cs('a', 'margin-top') == cs('a', 'font-size'), "
                   "cs('a', 'margin-top') == cs('c', 'margin-top'), cs('d', 'text-decoration-line')].join()",
              "true,true,false,underline");
}

/// Review minors, Task 2 (M5): the resolved direction reaches the renderer as a host marker (data-tg-dir), so an author's
/// [dir] selectors see the attribute as written, as in a browser: [dir=auto] matches a dir=auto element and [dir=rtl]
/// does not, whatever it resolves to; a widget's own data-tg-dir is dropped and steers nothing.
WR_TEST(testAuthorDirSelectorsSeeTheAttributeAsWritten) {
    RenderEnv env(page("[dir=rtl]{color:rgb(255,0,0)} [dir=auto]{background-color:rgb(0,0,255)}",
                       "<p id=p dir=auto>\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d</p><p id=q data-tg-dir=rtl>abc</p><p id=plain>abc</p>"));
    checkEval(env, "[cs('p', 'direction'), cs('p', 'color') == cs('plain', 'color'), "
                   "cs('p', 'background-color') == cs('plain', 'background-color'), cs('q', 'direction')].join()",
              "rtl,true,false,ltr");
}

/// Review minors, final review C1: the dir=auto walks (RenderTree::noteAutoDirection up from every change,
/// autoDirection down from an auto element at each flush) compare each element's dir and name without copying them, so
/// their uncharged work does not grow with a value's length: 64 nested elements with a 1 MiB dir each under an auto root,
/// and 50 text changes with a layout query each, copied about 3 GB before.
WR_TEST(testDirAutoWalksDoNotCopyLongValues) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(page("", "<div id=root dir=auto></div>"));
    checkEval(env, "const v = 'x'.repeat(1 << 20); let n = $('root'); for (let i = 0; i < 64; i++) { const e = "
                   "document.createElement('div'); e.setAttribute('dir', v); n.appendChild(e); n = e; } "
                   "window.leaf = n.appendChild(document.createTextNode('a')); 1",
              "1");
    env.flush();
    const auto start = std::chrono::steady_clock::now();
    checkEval(env, "for (let i = 0; i < 50; i++) { leaf.data = 'b' + i; $('root').getBoundingClientRect(); } 1", "1");
    const double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    std::printf("    50 changes under 64 long dir values: %.3f s\n", seconds);
    CHECK(seconds < 1.0);
}

/// Review minors, Task 2 (M4): dir=auto is resolved again when a descendant's dir changes (an element with its own dir is
/// skipped by the resolution) and when text the renderer does not draw changes (the resolution reads the DOM), each as a
/// rebuild resolves it.
WR_TEST(testDirAutoFollowsDescendantsAndUnrenderedText) {
    RenderEnv env(page("p{width:200px}", "<p dir=auto id=p><span dir=ltr id=s>Hi</span> \xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d</p>"
                                          "<p dir=auto id=r><noscript id=n>abc</noscript>\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d</p>"));
    checkEval(env, "[cs('p', 'direction'), cs('r', 'direction')].join()", "rtl,ltr");
    checkEval(env, "$('s').removeAttribute('dir'); 1", "1");
    env.flush();
    checkEval(env, "cs('p', 'direction')", "ltr");
    expectMatchesRebuild(env, "a descendant's dir removed");
    checkEval(env, "$('n').firstChild.data = '\xd7\x90\xd7\x91\xd7\x92'; 1", "1");
    env.flush();
    checkEval(env, "cs('r', 'direction')", "rtl");
    expectMatchesRebuild(env, "text under an unrendered element");
}

/// The direction follows the DOM: a dir set by script re-aligns the subtree it inherits into, and a text edit under
/// dir=auto that changes its first strong character changes its direction, each as a rebuild would lay it out.
WR_TEST(testDirectionFollowsPatches) {
    RenderEnv env(page("div{width:200px}", "<div id=box><p id=p style='margin:0'><span id=s>abc</span></p></div>"
                                           "<div id=auto dir=auto><span id=t>hello</span></div>"));
    checkEval(env, "$('box').dir = 'rtl'; 1", "1");
    env.flush();
    checkEval(env, "[cs('p', 'direction'), Math.round($('s').getBoundingClientRect().right)].join()", "rtl,200");
    expectMatchesRebuild(env, "dir set by script");
    checkEval(env, "$('t').firstChild.data = '\xd7\xa9\xd7\x9c\xd7\x95\xd7\x9d'; 1", "1");
    env.flush();
    checkEval(env, "cs('auto', 'direction')", "rtl");
    expectMatchesRebuild(env, "dir=auto after a text edit");
}

/// Fidelity T13, RTL phase 2 (html.attr.dir's "lays out inline boxes right to left"; UAX #9 rule L2 over a line's
/// items): in an RTL paragraph the items run right to left, inline-blocks and words alike; an LTR run inside keeps its
/// own order; an LTR paragraph is untouched; a span's box covers its items wherever they moved, and hit tests find them
/// where they are drawn.
WR_TEST(testRightToLeftLineOrder) {
    RenderEnv env(page("div{width:200px} i{display:inline-block;width:10px;height:8px}",
                       "<div dir=rtl><i id=a></i><i id=b></i></div>"
                       "<div dir=rtl id=mixed><span id=h1>\xd7\x90\xd7\x91</span> <span id=e1>one</span> <span id=e2>two</span>"
                       " <span id=h2>\xd7\x92\xd7\x93</span></div>"
                       "<div id=ltr><i id=c></i><i id=d></i></div>"));
    const auto right = [](const char* id) { return std::string("Math.round($('") + id + "').getBoundingClientRect().right)"; };
    const auto left = [](const char* id) { return std::string("Math.round($('") + id + "').getBoundingClientRect().left)"; };
    checkEval(env, "[" + right("a") + ", " + right("b") + "].join()", "200,190");
    // Logical: Hebrew, "one two", Hebrew. Visual, right to left: h1, then the LTR run (one left of two), then h2.
    checkEval(env, "[" + right("h1") + " === 200, " + left("h1") + " > " + right("e2") + ", " + right("e1") + " < " + left("e2") + ", " +
                       right("h2") + " < " + left("e1") + "].join()",
              "true,true,true,true");
    checkEval(env, "[" + left("c") + ", " + left("d") + "].join()", "0,10");
    // The topmost element at a's centre is a, where it is drawn.
    checkEval(env, "(r => document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2).id)($('a').getBoundingClientRect())", "a");
}

/// Fidelity T10 (css.value.math): calc(), min(), max() and clamp() mixing a percentage with a length resolve against
/// the containing block at layout; font-relative terms resolve at compute; a percentage height in an auto-height
/// parent behaves as auto, as a plain one does; CSS.supports and the widget's sheet keep such a declaration; a script
/// change to one lays out as a rebuild does.
WR_TEST(testMathWithPercentages) {
    RenderEnv env(page("#p{width:200px;font-size:10px} #p > div{height:4px}",
                       "<div id=p>"
                       "<div id=a style='width:calc(50% - 10px)'></div>"
                       "<div id=b style='width:min(50px, 30%)'></div>"
                       "<div id=c style='width:max(10px, 20%)'></div>"
                       "<div id=d style='width:clamp(20px, 50%, 60px)'></div>"
                       "<div id=e style='width:calc(1em + 2px)'></div>"
                       "<div id=f style='width:calc(100% - 2em)'></div>"
                       "<div id=g style='width:20px;margin-left:calc(25% + 1px)'></div>"
                       "<div id=h style='width:clamp(10px, calc(50% - 10px), 80px)'></div>"
                       "<div id=i style='width:calc((100% - 20px) / 2)'></div>"
                       "</div>"
                       "<div id=auto><div id=k style='height:calc(50% - 10px)'><i style='display:block;height:7px'></i></div></div>"));
    checkEval(env, "['a', 'b', 'c', 'd', 'e', 'f', 'h', 'i'].map(id => Math.round($(id).getBoundingClientRect().width)).join()",
              "90,50,40,60,12,180,80,90");
    checkEval(env, "Math.round($('g').getBoundingClientRect().left)", "51");
    checkEval(env, "Math.round($('k').getBoundingClientRect().height)", "7");
    checkEval(env, "[CSS.supports('width', 'calc(50% - 10px)'), CSS.supports('width', 'clamp(20px, 50%, 60px)')].join()",
              "true,true");
    checkEval(env, "$('a').style.width = 'calc(25% + 5px)'; 1", "1");
    env.flush();
    checkEval(env, "Math.round($('a').getBoundingClientRect().width)", "55");
    expectMatchesRebuild(env, "a calc width set by script");
}

/// widget-sandbox v0.3.0 auto/28 (css.display.grid): a poll's option rows (corpus bot-demos/02-poll), each a <button>
/// grid `52px 1fr auto`: the auto column fits its count, so the count ends at the row's end (its right padding, 8 px,
/// before it), and a bar across columns 2–3 runs from 52 px to the row's end, whatever the label's length (an
/// ellipsised one included) and the fill's width.
WR_TEST(testAPollRowsAutoColumnFitsItsCount) {
    const char* rows[][3] = {{"Friday", "0", "0%"}, {"Saturday after lunch, if it does not rain", "803", "60%"},
                             {"Sunday", "1", "100%"}};
    std::string body = "<div id=os>";
    for (const auto& row : rows) {
        body += std::string("<button><span class=p>0%</span><span class=l><span class=n>") + row[0] +
                "</span></span><span class=c><span>" + row[1] + "</span></span><i class=b><i style='width:" + row[2] +
                "'></i></i></button>";
    }
    body += "</div>";
    RenderEnv env(page("#os button{display:grid;grid-template-columns:52px 1fr auto;align-items:center;row-gap:6px;"
                       "width:100%;margin:0;padding:8px 8px 10px 0;background:none;border-radius:12px;color:inherit;"
                       "font:inherit;text-align:left}"
                       ".p{font-size:14px;font-weight:600;text-align:right;padding-right:10px;white-space:nowrap}"
                       ".l{display:flex;align-items:center;gap:6px;min-width:0}"
                       ".n{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}"
                       ".c{font-size:13px;padding-left:8px}"
                       ".b{grid-column:2/4;height:6px;border-radius:3px;background:#ddd}"
                       ".b i{display:block;height:100%;border-radius:3px;background:#36c}",
                       body));
    // Per row: the count's right edge, the bar's left and right edges, from the row's left; the row's width.
    checkEval(env,
              "[...document.querySelectorAll('#os button')].map(b => { const r = b.getBoundingClientRect(), "
              "c = b.children[2].firstChild.getBoundingClientRect(), t = b.children[3].getBoundingClientRect(); "
              "return [c.right - r.left, t.left - r.left, t.right - r.left, r.width].map(Math.round).join(); }).join(' ')",
              "292,52,292,300 292,52,292,300 292,52,292,300");
}

/// widget-sandbox v0.3.0 auto/29 (css.display.grid): the grid-template shorthand sets the rows, then the columns
/// after its slash.
WR_TEST(testGridTemplateSetsRowsThenColumns) {
    RenderEnv env(page("#g{display:grid;width:240px;height:120px;grid-template:repeat(3,1fr)/repeat(2,1fr)}",
                       "<div id=g><i></i><i></i><i></i><i id=c3></i><i></i><i id=c5></i></div>"));
    checkEval(env,
              "['c3', 'c5'].map(id => { const r = $(id).getBoundingClientRect(); "
              "return [r.x, r.y, r.width, r.height].join(); }).join(' ')",
              "120,40,120,40 120,80,120,40");
}

/// widget-sandbox v0.3.0 auto/29 (css.box.aspect-ratio): an aspect-ratio box's height follows the width its max-width
/// leaves, not the width available to it.
WR_TEST(testAspectRatioFollowsTheMaxWidth) {
    RenderEnv env(page("#bd{position:relative;max-width:264px;margin:auto;aspect-ratio:1}", "<div id=bd></div>"));
    checkEval(env, "(r => [r.x, r.y, r.width, r.height].join())($('bd').getBoundingClientRect())", "18,0,264,264");
}

/// widget-sandbox v0.3.0 auto/29 (css.display.grid, css.box.size): a tic-tac-toe board (corpus bot-demos/04-tic-tac-toe)
/// as it builds itself: nine buttons in an absolutely positioned `repeat(3,1fr)/repeat(3,1fr)` grid over a square
/// board; a mark, an <svg> 58 % of its button, sits centred in its own cell and leaves the cells equal thirds.
WR_TEST(testABoardsMarksSitInTheirCells) {
    RenderEnv env(page("svg{fill:none}#bd{position:relative;max-width:264px;margin:auto;aspect-ratio:1}"
                       "#g{position:absolute;inset:0;display:grid;grid-template:repeat(3,1fr)/repeat(3,1fr)}"
                       "#g button{padding:0;border-radius:16px;background:none;display:grid;place-items:center}"
                       "#g svg{width:58%;height:58%;stroke-width:2.6}",
                       "<div id=bd><div id=g></div></div>"));
    checkEval(env,
              "for (let i = 0; i < 9; i++) $('g').appendChild(document.createElement('button')); "
              "const c = $('g').children; "
              "c[4].innerHTML = '<svg viewBox=\"0 0 24 24\"><path d=\"M6.5 6.5l11 11\"/></svg>'; "
              "c[5].innerHTML = '<svg viewBox=\"0 0 24 24\"><circle cx=\"12\" cy=\"12\" r=\"6.5\"/></svg>'; "
              "const at = e => (r => [r.x, r.y, r.width, r.height].map(v => Math.round(v * 10) / 10).join())"
              "(e.getBoundingClientRect()); "
              "[at(c[0]), at(c[4]), at(c[5]), at(c[8]), at(c[4].firstChild), at(c[5].firstChild)].join(' ')",
              "18,0,88,88 106,88,88,88 194,88,88,88 194,176,88,88 124.5,106.5,51,51 212.5,106.5,51,51");
}

/// widget-sandbox v0.3.0 auto/30 (css.transform.2d): a shape's CSS transform with `transform-box: fill-box` scales about
/// its own box (`transform-origin: center` is the circle's centre), and getBoundingClientRect reports the transformed
/// box the painter draws; without it the reference box is the view box, so `scale(3)` scales about the user space's
/// origin. A moved shape takes its box along.
WR_TEST(testFillBoxScalesAShapeAboutItself) {
    RenderEnv env(page("svg{display:block}.pu{transform-box:fill-box;transform-origin:center}#d2,#d4{transform:scale(3)}",
                       "<svg width=300 height=96 viewBox='0 0 300 96'><circle id=d1 cx=284 cy=20 r=4 fill='rgb(1,0,0)'/>"
                       "<circle class=pu id=d2 cx=284 cy=20 r=4 fill='rgb(2,0,0)'/>"
                       "<circle id=d4 cx=20 cy=10 r=4 fill='rgb(3,0,0)'/></svg>"));
    const char* boxes = "['d1', 'd2', 'd4'].map(id => (r => [r.x, r.y, r.width, r.height].join())"
                        "($(id).getBoundingClientRect())).join(' ')";
    checkEval(env, boxes, "280,16,8,8 272,8,24,24 48,18,24,24");
    expectPaints(env, {"path 1,0,0 280,16,288,24", "path 2,0,0 272,8,296,32", "path 3,0,0 48,18,72,42"});
    checkEval(env, "$('d2').setAttribute('cx', '100'); $('d2').setAttribute('cy', '70'); 1", "1");
    env.flush();
    checkEval(env, boxes, "280,16,8,8 88,58,24,24 48,18,24,24");
    expectPaints(env, {"path 1,0,0 280,16,288,24", "path 2,0,0 88,58,112,82", "path 3,0,0 48,18,72,42"});
    expectMatchesRebuild(env, "a fill-box shape moved");
}
