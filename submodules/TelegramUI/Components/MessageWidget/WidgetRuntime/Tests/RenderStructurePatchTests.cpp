// Structure patched in place (M1c plan, Task 9; Ruling 8; twidget edit 18): a flush whose journal holds a structural
// entry patches the published litehtml document's element tree, and what it publishes is a rebuild's (Review Focus 1),
// across random edits of all three patch paths. The cases that patch otherwise (a document-level element, a <select>,
// counters, pseudo-element content at a cap, a kept node's own change beside structure, the render limits), that
// nothing in a template renders, and that a stop while planning leaves the published state alone (Review Focus 2).
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <random>
#include <set>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
#include "Tests/IncrementalEdits.h"
#include "Tests/LayerChurn.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

using Dumps = std::tuple<std::string, std::string, std::string>;

// Whether the three dumps of the flushed tree equal `rebuilt` (a fresh rebuild's); `what` and the dumps are printed when
// not.
bool matchesDumps(RenderEnv& env, const Dumps& rebuilt, const std::string& what, bool print = true) {
    const auto& [layout, input, layer] = rebuilt;
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const std::string flushed = tree ? tree->dump() : std::string();
    const bool same = env.render().layoutDump() == layout && env.render().renderInput() == input && flushed == layer;
    if (!same && print) {
        // Each dump from 200 bytes before the first difference, at most 3,000 bytes of it.
        auto show = [](const char* name, const std::string& a, const std::string& b) {
            if (a == b) {
                return;
            }
            size_t at = 0;
            while (at < a.size() && at < b.size() && a[at] == b[at]) {
                at++;
            }
            const size_t from = at > 200 ? at - 200 : 0;
            std::printf("  %s differs at byte %zu; flushed:\n%s\n  rebuilt:\n%s\n", name, at, a.substr(from, 3000).c_str(),
                        b.substr(from, 3000).c_str());
        };
        std::printf("  differs after: %s\n", what.c_str());
        show("render input", env.render().renderInput(), input);
        show("layout", env.render().layoutDump(), layout);
        show("layer tree", flushed, layer);
    }
    return same;
}

bool matchesRebuild(RenderEnv& env, const std::string& what, bool print = true) {
    return matchesDumps(env, wr_test::rebuildDump(env), what, print);
}

void expectMatchesRebuild(RenderEnv& env, const std::string& what) {
    CHECK(matchesRebuild(env, what));
}

// Runs `script` as the widget's own change, then flushes.
void edit(RenderEnv& env, const std::string& script) {
    CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
    env.flush();
}

// `edit`, and the flush patched: no build, one more patch, a clean journal, a rebuild's dumps.
void patches(RenderEnv& env, const std::string& script) {
    const uint64_t builds = env.render().buildCount();
    const uint64_t patched = env.render().patchCount();
    edit(env, script);
    if (env.render().patchCount() != patched + 1) {
        std::printf("  not patched (%s): %s\n", env.render().lastPatchRefusal(), script.c_str());
    }
    CHECK_EQ(env.render().patchCount(), patched + 1);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    expectMatchesRebuild(env, script);
}

// `edit`, and no rebuild: what changed is nothing a build reads (inside an element profile 1 drops), and the published
// state is a rebuild's.
void rendersNothing(RenderEnv& env, const std::string& script) {
    const uint64_t builds = env.render().buildCount();
    edit(env, script);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    expectMatchesRebuild(env, script);
}

// The options of a build after the boot's: litehtml's step budget cuts the boot alone (Ruling E19).
wr::RenderOptions laterBuild(wr::RenderOptions options) {
    options.selectorStepCut = false;
    return options;
}

size_t countOf(const std::string& haystack, const std::string& needle) {
    size_t n = 0;
    for (size_t at = haystack.find(needle); at != std::string::npos; at = haystack.find(needle, at + 1)) {
        n++;
    }
    return n;
}

const char* const kPage =
    "<!doctype html><style>.a{color:#c00;background:#00f} p{margin:2px} li{color:#0a0} .n{font-weight:bold}"
    " td{padding:3px;border:1px solid #000} .box p{color:#00c}</style>"
    "<body style='margin:0'><p id=one class=a>one</p><div id=two>two <b id=bold>bold</b></div><p id=three>three</p>"
    "<ul id=list><li>x</li><li>y</li></ul>"
    "<table id=table><tbody id=tbody><tr><td>c1</td></tr></tbody></table><div id=box class=box></div></body>";

std::string byId(const char* id) {
    return std::string("document.getElementById('") + id + "')";
}

// litehtml's counts and the limits, as a fresh build of the DOM as it now is has them (twidget edit 83).
void expectCountsOfAFreshBuild(RenderEnv& env, const std::string& what) {
    CHECK(wr_test::countsMatchAFreshBuild(env, what));
}

} // namespace

// A mixed journal (a structure change beside a kept node's own change) is one patch: the structure path applies both, and
// the flush equals a rebuild.
WR_TEST(testAMixedJournalIsOnePatch) {
    const char* const page = "<!doctype html><style>p{margin:0} .wide{display:flex} .k{color:#c00} p:active{color:#00c}"
                             "</style><body style='margin:0'><p id=p>text</p><div id=box><p>in the box</p></div>"
                             "<p id=a>a</p><p id=b>b</p><div id=d>d text</div><p id=s>s</p></body>";
    const char* const scripts[] = {
        // A text replacement and a subtree replacement in one structural flush.
        "document.getElementById('p').firstChild.data = 'changed'; const box = document.getElementById('box');"
        " box.className = 'wide'; const n = document.createElement('p'); n.textContent = 'new'; box.append(n)",
        // A kept element's class beside a removal.
        "document.getElementById('a').className = 'k'; document.getElementById('b').remove()",
        // A kept Text's data inside the subtree the same flush's insertion replaces.
        "const d = document.getElementById('d'); d.firstChild.data = 'x'; const c = document.createElement('span');"
        " c.textContent = 'c'; d.append(c)",
        // A swap beside an insertion.
        "document.getElementById('s').textContent = 'swapped'; const e = document.createElement('p'); e.textContent = 'e';"
        " document.body.append(e)",
    };
    for (const char* script : scripts) {
        RenderEnv env(page);
        patches(env, script);
    }
    // A press whose element its own pointerdown listener removes: the state change beside the removal.
    RenderEnv env(std::string(page) + "<script>document.getElementById('a').addEventListener('pointerdown',"
                                      " e => e.currentTarget.remove())</script>");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patched = env.render().patchCount();
    wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Down, 5, 50, 1, true);
    env.env().drain();
    CHECK_EQ(env.env().eval("document.getElementById('a') === null"), std::string("true"));
    if (env.render().buildCount() != builds) {
        std::printf("  not patched (%s): the pressed element removed\n", env.render().lastPatchRefusal());
    }
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(env.render().patchCount() > patched);
    expectMatchesRebuild(env, "the pressed element removed");
}

namespace {

// The litehtml element of the rendered element whose id is `id`, null when there is none.
std::shared_ptr<litehtml::element> renderedById(RenderEnv& env, const char* id) {
    for (const auto& [node, entry] : env.render().publishedBuild().nodes) {
        if (entry.element && std::string(entry.element->get_attr("id", "")) == id) {
            return entry.element;
        }
    }
    return nullptr;
}

} // namespace

// An element's own attribute change beside structure is set in place in the structure session: the flush equals a
// rebuild, and the element keeps its litehtml element ("kept") unless the flush moves or removes it with an ancestor.
WR_TEST(testOwnAttributesBesideStructureAreSetInPlace) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    struct Row {
        const char* page;
        const char* script;
        const char* kept;
    };
    const char* const dirAuto = "<!doctype html><body><p id=d dir=auto>abc <b>x</b></p><div id=e></div></body>";
    const char* const table = "<!doctype html><style>td{padding:3px;border:1px solid #000}</style><body><table>"
                              "<tbody id=tb><tr><td id=cell>c1</td><td>c2</td></tr></tbody></table></body>";
    const char* const svg = "<!doctype html><body><svg id=s width=40 height=40><circle id=c r=4 cx=8 cy=8></circle>"
                            "</svg><div id=e></div></body>";
    const Row rows[] = {
        {kPage, "document.getElementById('one').className = 'n'; document.getElementById('three').remove()", "one"},
        {kPage,
         "const l = document.getElementById('list'); l.className = 'n'; l.prepend(document.createElement('li'));"
         " l.append('tail'); l.children[1].remove()",
         "list"},
        {kPage,
         "document.getElementById('one').style.display = 'inline-block';"
         " document.body.append(document.createElement('p'))",
         "one"},
        {kPage,
         "document.getElementById('bold').title = 't';"
         " document.getElementById('box').append(document.getElementById('two'))",
         nullptr},
        {kPage, "document.getElementById('bold').title = 't'; document.getElementById('two').remove()", nullptr},
        {table,
         "document.getElementById('cell').setAttribute('colspan', '2'); const tr = document.createElement('tr');"
         " tr.append(document.createElement('td')); document.getElementById('tb').append(tr)",
         "cell"},
        {dirAuto,
         "document.getElementById('d').firstChild.data = '\u05e9\u05dc\u05d5\u05dd ';"
         " document.getElementById('e').append(document.createElement('p'))",
         "d"},
        {svg,
         "document.getElementById('c').setAttribute('r', '9');"
         " document.getElementById('e').append(document.createElement('p'))",
         "c"},
        {kPage,
         "document.getElementById('one').title = 'y'.repeat(1100000);"
         " document.body.append(document.createElement('p'))",
         nullptr},
    };
    for (const Row& row : rows) {
        RenderEnv env(row.page);
        const std::weak_ptr<litehtml::element> before = row.kept ? renderedById(env, row.kept) : nullptr;
        patches(env, row.script);
        expectCountsOfAFreshBuild(env, row.script);
        if (row.kept) {
            if (before.lock() != renderedById(env, row.kept)) {
                std::printf("  not kept (%s): %s\n", row.kept, row.script);
            }
            CHECK(before.lock() == renderedById(env, row.kept));
        }
    }
}

// A Text's own change beside structure is replaced in place in the structure session, after its insertions: the flush
// equals a rebuild, and its parent keeps its render item ("kept") where the session changed nothing else under it. A
// Text with no pieces before or after, or under a parent whose children an element reads (an svg's), is built again.
WR_TEST(testOwnTextsBesideStructureAreSetInPlace) {
    struct Row {
        const char* page;
        const char* setup;
        const char* script;
        const char* kept;
    };
    const char* const svg = "<!doctype html><body><svg width=40 height=40><text id=st x=2 y=20>a</text></svg>"
                            "<div id=e></div></body>";
    const Row rows[] = {
        {kPage, nullptr,
         "document.getElementById('one').firstChild.data = 'one more'; document.getElementById('three').remove()",
         "one"},
        {kPage, nullptr,
         "const two = document.getElementById('two'); const t = two.firstChild; t.data = 'deux ';"
         " two.insertBefore(document.createElement('i'), t)",
         nullptr},
        {kPage, nullptr,
         "document.getElementById('two').firstChild.data = 'zwei '; document.getElementById('bold').remove()", nullptr},
        {kPage, nullptr,
         "document.getElementById('bold').firstChild.data = 'B';"
         " document.getElementById('box').append(document.getElementById('two'))",
         nullptr},
        {kPage, nullptr,
         "document.getElementById('bold').firstChild.data = 'B'; document.getElementById('two').remove()", nullptr},
        {kPage, nullptr,
         "document.getElementById('one').firstChild.data = ''; document.body.append(document.createElement('p'))",
         nullptr},
        {kPage, "document.getElementById('one').firstChild.data = ''",
         "document.getElementById('one').firstChild.data = 'back'; document.body.append(document.createElement('p'))",
         nullptr},
        {kPage, nullptr,
         "document.getElementById('one').firstChild.data = 'word '.repeat(50);"
         " document.getElementById('three').remove()",
         "one"},
        {svg, nullptr,
         "document.getElementById('st').firstChild.data = 'b';"
         " document.getElementById('e').append(document.createElement('p'))",
         nullptr},
    };
    for (const Row& row : rows) {
        RenderEnv env(row.page);
        if (row.setup) {
            patches(env, row.setup);
        }
        std::weak_ptr<litehtml::render_item> before;
        if (row.kept) {
            before = env.render().document()->live_item(*renderedById(env, row.kept));
        }
        patches(env, row.script);
        expectCountsOfAFreshBuild(env, row.script);
        if (row.kept) {
            const bool kept = before.lock() == env.render().document()->live_item(*renderedById(env, row.kept));
            if (!kept) {
                std::printf("  not kept (%s): %s\n", row.kept, row.script);
            }
            CHECK(kept);
        }
    }
}

// Twidget edit 16's cap beside structure: the session counts the text pieces alive when it opens (a removal's among
// them) and the replacements' growth, so the plan does too, and a flush the session would count past the cap walks the
// cut, which cuts as a build does. Nothing stops the widget.
WR_TEST(testAnOwnTextBesideStructureNearTheTextCap) {
    const auto pageOf = [](const std::string& filler) {
        return "<!doctype html><body><style id=sty></style><p id=t>a</p><p id=gone>x y</p><div id=to></div>" + filler +
               "</body>";
    };
    std::string filler;
    {
        RenderEnv probe(pageOf("<p id=filler></p>"));
        const int room = litehtml::document::max_text_elements - 6 - probe.render().document()->document_text_pieces();
        filler = "<p id=filler>";
        for (int n = 0; n < room; n++) {
            filler += n % 2 ? " " : "w";
        }
        filler += "</p>";
    }
    // Each data grows #t's one piece: by 2 (the session counts 1 below the cap), 4 (1 past it; a build's count is 2
    // below), 19 (past it either way).
    for (const char* data : {"a b", "a b c", "a a a a a a a a a a "}) {
        RenderEnv env(pageOf(filler));
        CHECK_EQ(env.render().document()->document_text_pieces(), litehtml::document::max_text_elements - 6);
        const std::string script = std::string("document.getElementById('gone').remove();"
                                               " const p = document.createElement('p'); p.textContent = 'u v';"
                                               " document.getElementById('to').append(p);"
                                               " document.getElementById('t').firstChild.data = '") +
                                   data + "'";
        patches(env, script);
        expectCountsOfAFreshBuild(env, script);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    }
    // A <style> that gains its piece beside a Text that grows by 6, at 6 below the cap: replace_style_text counts the
    // text's growth before the sheet's piece (the patch replaces the Text first), so the plan does too.
    {
        RenderEnv env(pageOf(filler));
        const std::string script = "document.getElementById('sty').textContent = 'p{}';"
                                   " document.getElementById('t').firstChild.data = 'a b c d'";
        try {
            patches(env, script);
            expectCountsOfAFreshBuild(env, script);
        } catch (const wr::Aborted&) {
        }
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
    }
}

// The `textContent = …` idiom on an element whose only child is a Text (one mapped Text out, one new Text in, nothing
// else under that parent) is the text path's replacement: litehtml keeps its render tree and the flush publishes
// operations, beside an attribute change on another element too. Every other shape is structure: a replaced render
// subtree, which the mirror places with operations too.
WR_TEST(testATextSwapIsATextPatch) {
    RenderEnv env("<!doctype html><style>.k{color:#c00}</style><body><p id=c>0</p><div id=m>m</div>"
                  "<div id=e><b>b</b> t</div><p id=f>f</p></body>");
    const uint64_t builds = env.render().buildCount();
    uint64_t replaced = env.render().subtreeReplacements();
    // Operations.
    auto published = [&](const char* what) {
        if (env.render().layerOps().empty()) {
            std::printf("  nothing published after: %s\n", what);
        }
        CHECK(!env.render().layerOps().empty());
    };
    auto text = [&](const char* what) {
        published(what);
        if (env.render().subtreeReplacements() != replaced) {
            std::printf("  a render subtree was replaced after: %s\n", what);
        }
        CHECK_EQ(env.render().subtreeReplacements(), replaced);
    };
    for (const char* swapped : {"111", "two words", "3"}) {
        patches(env, byId("c") + ".textContent = '" + swapped + "'");
        text(swapped);
    }
    patches(env, byId("m") + ".className = 'k'; " + byId("c") + ".textContent = 'beside a class'");
    text("beside a class");
    patches(env, byId("c") + ".className = 'k'; " + byId("c") + ".textContent = 'its own class'");
    text("its own class");
    patches(env, byId("c") + ".textContent = 'a'; " + byId("f") + ".textContent = 'b'; " + byId("c") + ".firstChild.data = 'c'");
    text("two swaps and a data change");
    // An element child replaced, a second Text, the text emptied: structure, a replaced render subtree, which the mirror
    // places with operations.
    auto structure = [&](const char* what) {
        published(what);
        CHECK(env.render().subtreeReplacements() > replaced);
        replaced = env.render().subtreeReplacements();
    };
    patches(env, byId("e") + ".textContent = 'was an element'");
    structure("was an element");
    patches(env, byId("c") + ".append(' more')");
    structure("a second Text");
    patches(env, byId("c") + ".textContent = 'one again'");
    structure("one Text again");
    patches(env, byId("c") + ".textContent = ''");
    structure("emptied");
    CHECK_EQ(env.render().buildCount(), builds);
    // Beside the parent's own ::before content, which the swap leaves where it is: patched as a data change is.
    RenderEnv before("<!doctype html><style>#c::before{content:'> '}</style><body><p id=c>0</p></body>");
    uint64_t beforeReplaced = before.render().subtreeReplacements();
    patches(before, byId("c") + ".firstChild.data = 'data'");
    const uint64_t byData = before.render().subtreeReplacements() - beforeReplaced;
    beforeReplaced = before.render().subtreeReplacements();
    patches(before, byId("c") + ".textContent = 'after the marker'");
    CHECK_EQ(before.render().subtreeReplacements() - beforeReplaced, byData);
}

// The brief's shapes, each patched and each equal to a rebuild.
WR_TEST(testStructurePatchMatchesRebuild) {
    RenderEnv env(kPage);
    expectMatchesRebuild(env, "boot");
    const uint64_t builds = env.render().buildCount();
    patches(env, "const p = document.createElement('p'); p.className = 'n'; p.textContent = 'appended'; document.body.append(p)");
    patches(env, "const d = document.createElement('div'); d.className = 'a'; d.append('first ', document.createElement('i'));"
                 " document.body.insertBefore(d, document.body.firstChild)");
    patches(env, byId("three") + ".remove()");
    patches(env, byId("box") + ".append(" + byId("bold") + ")");
    patches(env, "const tr = document.createElement('tr'); tr.innerHTML = '<td>c2</td><td>c3</td>'; " + byId("tbody") + ".append(tr)");
    patches(env, "const li = document.createElement('li'); li.textContent = 'w'; " + byId("list") + ".prepend(li)");
    patches(env, byId("box") + ".innerHTML = '<p>inner <b>html</b></p><span>s</span>'");
    patches(env, byId("two") + ".textContent = 'replaced by text'");
    patches(env, byId("one") + ".append(' and more words')");
    patches(env, byId("one") + ".firstChild.remove()");
    // A move within one parent goes and is built again, so the kept children stay in the DOM's order.
    patches(env, byId("list") + ".append(" + byId("list") + ".firstElementChild)");
    patches(env, "document.body.append(" + byId("one") + "); document.body.prepend(" + byId("list") + ")");
    // Inserted then changed in the same task: built as it is.
    patches(env, "const s = document.createElement('span'); " + byId("box") + ".append(s); s.className = 'a';"
                 " s.textContent = 'set after'; s.firstChild.data = 'changed after'");
    // Inserted and removed again, and an empty Text, and a comment: nothing to link.
    patches(env, "const s = document.createElement('span'); document.body.append(s); s.remove();"
                 " document.body.append(''); document.body.append(document.createComment('c'))");
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(env.render().renderInput().find("changed after") != std::string::npos);
}

// Review Focus 1 for all three paths: random edits, flushed every 1-5, each flush equal to a rebuild.
// twidget edit 21: the patch predicates ask nothing of the style budget; only a patch that really passes it is abandoned
// (Ruling E51). One element holding a 16 KiB custom property made the old estimate (every element holding the largest
// value of every property) refuse any patch reaching 1,024 elements, though the real charge is small: these patch.
WR_TEST(testOnlyTheEstimateRefusedTheseAndTheyPatch) {
    std::string page = "<!doctype html><style>body{margin:0} #one{--x:" + std::string(16384, 'x') +
                       "} .on{padding:1px} .w:hover p{color:#c00}</style><body><div id=one></div><div class=w id=w>";
    for (int i = 0; i < 1100; i++) {
        page += "<div>d</div>";
    }
    RenderEnv env(page + "</div></body></html>");
    CHECK(env.render().document()->style_bytes_charged() < (size_t(1) << 20));
    patches(env, "document.getElementById('w').className = 'w on'");
    patches(env, "const w = document.getElementById('w'); for (let i = 0; i < 400; i++) { const p = document.createElement('p');"
                 " p.textContent = 'p'; w.append(p); }");
    const uint64_t builds = env.render().buildCount();
    const uint64_t patched = env.render().patchCount();
    wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Down, 5, 30, 1, true);
    env.env().drain();
    if (env.render().buildCount() != builds) {
        std::printf("  the tap rebuilt (%s)\n", env.render().lastPatchRefusal());
    }
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK(env.render().patchCount() > patched);
    expectMatchesRebuild(env, "a tap under .w:hover p");
}

WR_TEST(testRandomEditsMatchARebuild) {
    // The drops at the old caps, which compat keeps (widget-sandbox v0.3.0): under strict these fillers stop the widget.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    struct Group {
        const char* name;
        int firstSeed;
        int lastSeed;
        std::string sheet;
        std::string filler;
        uint64_t flushes = 0;
        uint64_t patched = 0;
        uint64_t rebuilt = 0;
        uint64_t clean = 0;
        /// Texts swapped in by the text path (RenderTree::swappedTexts).
        uint64_t swapped = 0;
        /// The limit a near-limit group must reach at least once: a render-limit kind a build posts, or a refusal.
        std::string limit;
        bool reached = false;
        /// Script run after the boot, before the first edit (what the parser would not build: divs under a <table>).
        std::string setup;
        /// Edits of the structural kinds only (and the table insert): no journal is mixed, so the flush that first
        /// crosses the limit is a patch's to refuse.
        bool structural = false;
        /// Edits mostly of the Text-swap kind, beside class, style, data and any textContent: the swap path's group.
        bool swaps = false;
        /// What goes first in the body (a build's cut then drops what follows it).
        std::string prefix;
        /// The kinds the group draws from (kEditHelpersJS's), when not the general mix.
        std::vector<uint32_t> kinds;
        /// Between batches, with a chance of 1 in 6 each: a new width, the other theme, reduced motion toggled, a tap.
        bool environment = false;
        /// Between batches, one animation frame of 16 ms (the page's animations run); the render-input-less tree is
        /// left out, as only the installed tree hears the frames.
        bool animated = false;
        /// Each batch first presses an element's centre, then removes that element.
        bool pressThenRemove = false;
        /// Pointer events that changed what :hover or :active match (an environment's taps, the presses): an
        /// environment or press group must have some.
        uint64_t actionChanges = 0;
        /// The structural group's insertions that were not make(13)'s table of refused rows: none.
        uint64_t misshaped = 0;
        /// The edits each seed makes.
        int edits = 200;
        /// Whether the theme and reduced-motion steps must each change, at least once, what a fresh build renders.
        bool environmentRenders = false;
        uint64_t themeChanges = 0;
        uint64_t motionChanges = 0;
    };
    const char* const kCounterSheet =
        " body{counter-reset:c} ul{counter-reset:c} .x{counter-reset:c} p{counter-increment:c} li{counter-increment:c}"
        " p::before{content:counter(c) ' '} li::after{content:counters(c, '.')}"
        " span::before{counter-increment:c;content:'-'} .y::after{counter-increment:c 2;content:counter(c)}"
        " *{margin:0} div > *{padding-left:1px} li:hover{color:#c0c}";
    const std::string base = ".box{padding:2px;border:1px solid #000} .x{color:#c00;font-weight:bold} .y{background:#ff0}"
                             " [hidden]{display:none} li{margin:1px} td{padding:2px} p{margin:2px}";
    // A parent's emptiness reaching its later siblings: their boxes, their content and their descendants' matches.
    const std::string kEmptySiblingSheet = " :empty + *{display:none} div:not(:empty) + p::before{content:'e'}"
                                           " p:empty ~ span{float:left;width:9px} li:empty ~ li b{display:block}";
    // Two pseudo-elements on every <i>: litehtml's element cap counts them beside the elements (twidget edit 19).
    const std::string kPseudoPair = " i::before,i::after{content:''}";
    const std::string sibling =
        base + " li:nth-child(2n){color:#00f} p:nth-child(2n){background:#eee} .x + .y{color:#0a0} .x ~ span{text-decoration:underline}"
               " li:last-child{border-bottom:2px solid #00f} p:first-child{padding-left:3px}"
               // A compound left of a combinator walks an ancestor's siblings (fix round 2): the many <p>s below.
               " .zz ~ p span{color:#909} p:nth-child(3n of .y) b{color:#090} li:last-child b{color:#c60}";
    // The fixture's three controls and 253 more: 256, so the next one crosses the limit (Ruling E6).
    // Profile 1 drops every control but <button> (V4 plan, Task 4), the one Ruling E6 counts.
    std::string controls = "<div id=inputs>";
    for (int n = 0; n < 253; n++) {
        controls += "<button value=i>i</button>";
    }
    controls += "</div>";
    // Ruling E19: 2,000 rules each div is tested against and fails (one counted step each, no declarations).
    std::string stepSheet = base;
    for (int n = 0; n < 2000; n++) {
        stepSheet += " div[data-q]{margin:0}";
    }
    // The page of a seed, and the near-limit fillers sized from what the page without them uses: the byte budget a few
    // bytes short of full (40), and the selector steps one div's worth short of litehtml's budget.
    const auto pageOf = [](const std::string& sheet, const std::string& filler, const std::string& prefix = std::string()) {
        return wr_test::editPage(sheet, filler, prefix);
    };
    // The bytes in a class (profile 1's text budgets do not count it, and they hold a document's text well under 1 MiB:
    // V4 plan, Task 7).
    std::string bytes;
    {
        RenderEnv probe(pageOf(base, "<p id=filler></p>"));
        const size_t room = wr::kMaxRenderBytes - size_t(probe.render().renderBytes()) - 40;
        bytes = "<p id=filler class=" + std::string(room - std::strlen("class"), 'x') + "></p>";
    }
    // Profile 1's document text budget 40 units short of full (V4 plan, Task 7), in paragraphs under the cap on one text.
    std::string text;
    {
        RenderEnv probe(pageOf(base, "<div id=filler></div>"));
        size_t room = wr::Limits::compat().textBudgetUnits - probe.render().renderedTextUnits().units - 40;
        text = "<div id=filler>";
        while (room > 0) {
            const size_t paragraph = std::min<size_t>(room, 60000);
            text += "<p>";
            for (size_t n = 0; n < paragraph; n += 1000) {
                const size_t word = std::min<size_t>(1000, paragraph - n);
                text += std::string(word - 1, 'x') + (word > 1 ? " " : "x");
            }
            text += "</p>";
            room -= paragraph;
        }
        text += "</div>";
    }
    // The pieces 8 short of the cap, with a <table> after the filler whose whitespace a build asks the cap for last (I2).
    const std::string lastTable = "<table id=filler2>\n<tbody><tr><td>t</td></tr></tbody>\n</table>";
    std::string pieces;
    {
        RenderEnv probe(pageOf(base, "<p id=filler></p>" + lastTable));
        const int room = litehtml::document::max_text_elements - 8 - probe.render().document()->text_elements();
        pieces = "<p id=filler>";
        for (int n = 0; n < (room + 1) / 2; n++) {
            pieces += n ? " w" : "w";
        }
        pieces += "</p>" + lastTable;
    }
    std::string steps;
    {
        auto fill = [](int divs) {
            std::string out = "<div id=filler>";
            for (int n = 0; n < divs; n++) {
                out += "<div>f</div>";
            }
            return out + "</div>";
        };
        RenderEnv none(pageOf(stepSheet, fill(0)));
        RenderEnv hundred(pageOf(stepSheet, fill(100)));
        const int64_t perDiv = (hundred.render().selectorSteps() - none.render().selectorSteps()) / 100;
        const int64_t divs = (litehtml::document::default_selector_steps - 1 - none.render().selectorSteps()) / perDiv;
        steps = fill(int(divs));
    }
    // Comments, which only the node cap counts, 11 short of it (the document node, every element, Text and Comment), first
    // in the body: an insertion in the edited content crosses it and a removal comes back.
    std::string nodes;
    {
        RenderEnv probe(pageOf(base, "", "<div id=filler></div>"));
        const int used = std::stoi(probe.env().eval(
            "let n = 1; (function walk(x) { for (let c = x.firstChild; c; c = c.nextSibling) { if (c.nodeType !== 10) n++;"
            " walk(c); } })(document); String(n)"));
        nodes = "<div id=filler>";
        for (int n = used; n < int(wr::kMaxRenderNodes) - 11; n++) {
            nodes += "<!---->";
        }
        nodes += "</div>";
    }
    // A custom property of 24,000 bytes on every element, and elements first in the body up to three of them short of the
    // style-byte budget (twidget edit 21): an insertion passes it and a removal comes back.
    const std::string styleSheet = base + " *{--big:" + std::string(24000, 'a') + "}";
    std::string styleBytes;
    {
        const auto filler = [](int elements) {
            std::string out = "<div id=filler>";
            for (int n = 0; n < elements; n++) {
                out += "<i></i>";
            }
            return out + "</div>";
        };
        RenderEnv none(pageOf(styleSheet, "", filler(0)));
        RenderEnv hundred(pageOf(styleSheet, "", filler(100)));
        const size_t charged = none.render().document()->style_bytes_charged();
        const size_t perElement = (hundred.render().document()->style_bytes_charged() - charged) / 100;
        std::printf("  style bytes: %zu charged without the filler, %zu per element\n", charged, perElement);
        styleBytes = filler(int((litehtml::document::max_style_bytes - charged) / perElement) - 3);
    }
    // A group near a limit runs three seeds: it must reach its limit, and patch, in at least one of them.
    Group groups[] = {
        {"sibling (positional and sibling selectors)", 1, 5, sibling, ""},
        {"plain", 6, 10, base, ""},
        {"pseudo (q::before content)", 11, 15, base + " q::before{content:'\\00ab'}", ""},
        {"near the text-piece cap", 16, 18, base, pieces},
        {"near the selector-step budget", 17, 19, stepSheet, steps},
        {"near the form-control limit", 18, 20, base, controls},
        {"near litehtml's element cap (pseudo-elements)", 19, 21, base + kPseudoPair, ""},
        {"near the byte budget", 20, 22, base, bytes},
        {"near the text budget", 21, 23, base, text},
        // Fidelity plan, Task 2: :empty (a parent's match follows its children) and :lang() (an ancestor's attribute),
        // with an element in a lang="ru" subtree for the edits to move in and out.
        {":empty and :lang()", 22, 24, base + " :empty{outline:1px solid #f0f} span:empty{padding:1px} :lang(ru) b{color:#0a0}"
                                    " p:not(:empty){margin:3px}", ""},
        {"Text swaps (textContent on a Text-only element, beside class, style and data)", 25, 27,
         base + " q::before{content:'\\00ab'}", ""},
        // Every kind of change (the incremental render plan, Task 7): attributes, box types, sheets, the document
        // element, the environment, animations, and these near a cap.
        {"attributes", 50, 52, base, ""},
        {"box types", 53, 55, base, ""},
        {"sheets", 56, 58, base, ""},
        {"document element", 59, 61, base, ""},
        {"environment", 62, 64, base + wr_test::kEnvironmentSheet, ""},
        {"animated with structure", 65, 67,
         base + " @keyframes turn{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}"
                " .x{animation:turn 1s linear infinite} .y{animation:turn 2s linear infinite}", ""},
        // A width flip moves the cut itself: the ::before content it adds counts toward the cap (the filler is divs).
        {"near the element cap with environment changes", 68, 70,
         base + wr_test::kEnvironmentSheet +
             " @media (max-width:300px){li{display:none} li::before,p::before,span::before,b::before,td::before{content:'*'}}",
         ""},
        {"sheets near the pseudo-element cap", 71, 73, base + " q::before{content:'\\00ab'}", ""},
        {"press then remove", 74, 76, base + " :hover{outline:1px solid #f0f} :active{background:#fcc}", ""},
        {"near the node cap", 77, 79, base, ""},
        {"near the style-byte budget", 80, 82, styleSheet, ""},
        {"custom properties", 83, 85,
         base + " .box{--k:#c0c} p{color:var(--k, #333)} li::before{content:'\\00b7';color:var(--k, #333)} li.x::before{content:none}",
         ""},
        {"svg content", 89, 91, base, ""},
        // Twidget edit 82: the document element replaced by a clone, a comment beside it added and removed, and its own
        // class beside a body append.
        {"document children", 98, 100, base, ""},
        // Twidget edit 78: counters on elements and on pseudo-elements, counter() and counters() readers, nested lists, a
        // class that resets, and rules reaching the pseudo-elements (`*`, `div > *`), under structure, class and text, and
        // with the environment's taps (:hover).
        {"counters", 92, 94, base + kCounterSheet, ""},
        {"counters with the environment", 95, 97, base + wr_test::kEnvironmentSheet + kCounterSheet, ""},
        {"names in ancestor positions", 86, 88,
         base + " .x b{color:#00f} .box p{display:inline} [data-k] span{padding:1px} #k1 li{margin:3px} .y ~ p{background:#eef}",
         ""},
        // The incremental render plan, Step 5: the document's own head and body, a <br>'s attributes, and batches of 5,000
        // journal entries.
        {"document level", 101, 103, base, ""},
        {"br attributes", 104, 106, base + " br.x{display:block;height:4px} br.box{border:1px solid #000}", ""},
        {"mass", 107, 109, base, ""},
        // Twidget edit 88: :empty beside sibling combinators whose rules change boxes and content.
        {":empty beside sibling combinators", 110, 112, base + kEmptySiblingSheet, ""},
        // Twidget edit 90: what the environment matched in a flush is matched again by a structure change's sibling reach.
        {"sibling selectors and the environment", 113, 115, sibling + wr_test::kEnvironmentSheet, ""},
    };
    groups[3].limit = "text-pieces";
    // Selector steps are a budget of each task (Ruling E19): a patch near litehtml's budget patches; the group checks
    // parity there.
    groups[5].limit = "form-controls";
    groups[6].limit = "elements";
    groups[7].limit = "bytes";
    groups[8].limit = "text-budget";
    groups[9].prefix = "<div lang=ru id=ru><b>ru</b><span></span></div>";
    groups[10].swaps = true;
    // <i>s, each with its two pseudo-elements, up to 11 short of litehtml's 20,000 with the elements and pseudo-elements
    // the page has: under W's 10,000 rendered elements, so the shared cap is litehtml's alone. The seed's insertions are
    // tables of rows the table refuses (make(13)): the table counts, its rows do not (twidget edit 83).
    const auto elementCapSetup = [&](const std::string& sheet) {
        const auto counted = [&](int is) {
            RenderEnv probe(pageOf(sheet, "", "<div id=filler>" + [&] {
                std::string out;
                for (int n = 0; n < is; n++) {
                    out += "<i></i>";
                }
                return out;
            }() + "</div>"));
            return probe.render().document()->build_elements() + probe.render().document()->pseudo_elements();
        };
        const int used = counted(0);
        const int perI = (counted(100) - used) / 100;
        return "const t = document.getElementById('filler'); for (let i = 0; i < " + std::to_string((19989 - used) / perI) +
               "; i++) t.appendChild(document.createElement('i'))";
    };
    groups[6].setup = elementCapSetup(groups[6].sheet);
    groups[6].structural = true;
    // Near litehtml's element cap every flush lays out about 6,650 elements and 13,300 pseudo-elements, and the oracle
    // builds it again: 60 edits a seed reach the cap and keep the suite's time.
    groups[6].edits = 60;
    // Many siblings for an ancestor (Ruling E20.4): a section of 150 <p>s, edited like the rest.
    {
        std::string many = "<section id=many>";
        for (int n = 0; n < 150; n++) {
            many += n % 7 ? "<p>p <span>s</span></p>" : "<p class=y>p <b>b</b></p>";
        }
        groups[0].prefix = many + "</section>";
    }
    groups[6].prefix = "<div id=filler></div>";
    const auto named = [&](const char* name) -> Group& {
        for (Group& g : groups) {
            if (std::strcmp(g.name, name) == 0) {
                return g;
            }
        }
        std::abort();
    };
    named("attributes").kinds = {21, 21, 21, 0, 1, 2, 3, 4};
    named("box types").kinds = {22, 22, 22, 0, 1, 2, 3, 4};
    named("sheets").kinds = {23, 23, 25, 25, 0, 1, 2, 3, 4};
    named("document element").kinds = {24, 24, 6, 7};
    named("environment").environment = true;
    named("environment").environmentRenders = true;
    named("sibling selectors and the environment").environment = true;
    named("sibling selectors and the environment").environmentRenders = true;
    named("animated with structure").animated = true;
    named("animated with structure").kinds = {0, 1, 2, 3, 4};
    for (const char* name : {"near the element cap with environment changes", "sheets near the pseudo-element cap"}) {
        // Group 6's page: litehtml's element cap near.
        named(name).sheet += kPseudoPair;
        named(name).setup = elementCapSetup(named(name).sheet);
        named(name).prefix = groups[6].prefix;
        named(name).edits = groups[6].edits;
    }
    named("near the element cap with environment changes").environment = true;
    // Review Focus 2 and 3 must each cross the shared element cap (pseudo-elements count toward it).
    named("near the element cap with environment changes").limit = "elements";
    named("sheets near the pseudo-element cap").limit = "elements";
    named("near the element cap with environment changes").kinds = {0, 1, 2, 3, 4, 23};
    named("sheets near the pseudo-element cap").kinds = {23, 25, 25, 0, 1, 2};
    named("near the node cap").prefix = nodes;
    named("near the node cap").limit = "nodes";
    named("near the style-byte budget").prefix = styleBytes;
    named("near the style-byte budget").limit = "style-bytes";
    named("custom properties").kinds = {26, 26, 26, 0, 1, 2, 6};
    named("names in ancestor positions").kinds = {6, 6, 21, 21, 0, 1, 2, 4};
    named("svg content").kinds = {27, 27, 21, 0, 2};
    named("document children").kinds = {28, 28, 24, 0, 2};
    named("counters").kinds = {0, 1, 2, 3, 6, 6, 4, 9};
    named("counters with the environment").kinds = {0, 1, 2, 3, 6, 6, 4, 9};
    named("counters with the environment").environment = true;
    named("press then remove").pressThenRemove = true;
    named("press then remove").kinds = {0, 1, 6, 9};
    named("document level").kinds = {29, 29, 29, 0, 6, 9};
    named("br attributes").kinds = {30, 30, 30, 0, 2};
    named("mass").kinds = {31, 31, 31, 6};
    // Each mass flush lays out 5,000 more spans, and the oracle builds it again.
    named("mass").edits = 40;
    const std::string helpers = wr_test::kEditHelpersJS;
    // The layers each flush re-creates though their element did not change (the churn metric, Tests/LayerChurn.h).
    wr_test::ChurnTally churn;
    for (Group& group : groups) {
        for (int seed = group.firstSeed; seed <= group.lastSeed; seed++) {
            RenderEnv env(pageOf(group.sheet, group.filler, group.prefix));
            wr_test::ScopedChurnProbe churnProbe(env.render(), churn);
            CHECK_EQ(env.env().eval(helpers), std::string("ok"));
            if (!group.setup.empty()) {
                CHECK_EQ(env.env().eval("(() => { " + group.setup + "; })(); 'ok'"), std::string("ok"));
                env.flush();
            }
            // Production's options beside the oracle's: the same flushes without the render input (Ruling E11), held
            // to the rebuild's layout and tree.
            // The render tree's options as they are now (its root declarations: the theme's variables, which the UA
            // layer's values read), not the construction's.
            wr::RenderOptions production = env.render().options();
            production.keepRenderInput = false;
            production.selectorStepCut = false;
            wr::RenderTree plain(env.ctx(), env.host(), production);
            plain.build(env.ctx());
            std::mt19937 rng{uint32_t(seed)};
            int edits = 0;
            bool reported = false;
            // The elements :hover and :active match, each by a number it keeps. The installed tree hears every change of
            // them (UserActions' noteRender: a pointer event, or the DOM taking the hovered or pressed element away); the
            // render-input-less tree is told here, after every pointer event and before a flush, of each element whose
            // flags changed (tellPlain), so both patch the state; a pointer task can flush the installed tree after the
            // change it heard, which the other tree does not follow.
            const auto actionState = [&] {
                return env.env().eval(
                    "(() => { const ids = globalThis.__ids || (globalThis.__ids = new WeakMap()); let out = '';"
                    " for (const e of document.querySelectorAll('*')) { const h = e.matches(':hover'), a = e.matches(':active');"
                    " if (!h && !a) continue; if (!ids.has(e)) ids.set(e, globalThis.__idn = (globalThis.__idn || 0) + 1);"
                    " out += ids.get(e) + (h ? 'h' : '') + (a ? 'a' : '') + ','; } return out; })()");
            };
            std::string heardState = actionState();
            bool pointed = false;
            // The elements :hover or :active holds on, each with both flags, as a build reads them (ElementState); the
            // render-input-less tree is told of every element whose flags changed (RenderTree::userActionStateChanged
            // journals it with its ancestors).
            using ActionElements = std::vector<std::pair<wr::Ref<wr::Element>, int>>;
            const auto actionElements = [&] {
                ActionElements out;
                wr::ElementState* state = wr::DOMState::of(env.ctx()).elementState();
                std::vector<wr::Node*> stack;
                if (wr::Element* root = wr::DOMState::of(env.ctx()).document().documentElementNode()) {
                    stack.push_back(root);
                }
                while (!stack.empty()) {
                    wr::Node* node = stack.back();
                    stack.pop_back();
                    if (!node->isElement()) {
                        continue;
                    }
                    auto& element = static_cast<wr::Element&>(*node);
                    const int flags = (state->hovered(env.ctx(), element) ? 1 : 0) | (state->active(env.ctx(), element) ? 2 : 0);
                    if (flags) {
                        out.emplace_back(wr::Ref<wr::Element>::retain(env.ctx(), &element), flags);
                    }
                    for (size_t i = 0; i < node->childCount(); i++) {
                        stack.push_back(node->childAt(i));
                    }
                }
                return out;
            };
            ActionElements heardElements = actionElements();
            const auto tellPlain = [&] {
                ActionElements now = actionElements();
                const auto flagsIn = [](const ActionElements& set, const wr::Element* element) {
                    for (const auto& [held, flags] : set) {
                        if (held.get() == element) {
                            return flags;
                        }
                    }
                    return 0;
                };
                for (const ActionElements* set : {&heardElements, &now}) {
                    for (const auto& [held, flags] : *set) {
                        if (flagsIn(heardElements, held.get()) != flagsIn(now, held.get())) {
                            plain.userActionStateChanged(held.get());
                        }
                    }
                }
                heardElements = std::move(now);
            };
            const auto actionStateChanged = [&] {
                tellPlain();
                const std::string now = actionState();
                if (now == heardState) {
                    return false;
                }
                heardState = now;
                pointed = true;
                return true;
            };
            // A pointer event is a task: it runs, and changes :hover and :active, when the loop drains.
            const auto pointer = [&](wr::PointerPhase phase, double x, double y) {
                try {
                    wr::HostState::of(env.ctx()).pointer(env.ctx(), phase, x, y, 7, true);
                } catch (const wr::Aborted&) {
                }
                env.env().drain();
                pointed = true;
                group.actionChanges += actionStateChanged();
            };
            // What a fresh build renders under `options`: a theme or reduced-motion step must change it.
            const auto freshLayers = [&](const wr::RenderOptions& options) {
                wr::RenderTree tree(env.ctx(), env.host(), options);
                tree.build(env.ctx());
                return tree.layerTree() ? tree.layerTree()->dump() : std::string();
            };
            std::optional<std::pair<double, double>> pressed;
            while (edits < group.edits) {
                const int batch = 1 + int(rng() % 5);
                std::string done;
                pointed = false;
                if (group.pressThenRemove) {
                    // The last batch's press ends, then an element's centre is pressed (hover and active state) and the
                    // element removed, in the same batch.
                    if (pressed) {
                        pointer(wr::PointerPhase::Up, pressed->first, pressed->second);
                        pressed.reset();
                    }
                    const std::string at = env.env().eval(
                        "(() => { const all = [...document.body.querySelectorAll('*')].filter(e => !e.closest('template'));"
                        " const e = all[" + std::to_string(rng() % 1000) + " % all.length]; if (!e) return '';"
                        " const r = e.getBoundingClientRect(); e.setAttribute('data-pressed', '');"
                        " return (r.x + r.width / 2) + ',' + (r.y + r.height / 2); })()");
                    const size_t comma = at.find(',');
                    if (comma != std::string::npos) {
                        const double x = std::atof(at.substr(0, comma).c_str()), y = std::atof(at.substr(comma + 1).c_str());
                        pointer(wr::PointerPhase::Down, x, y);
                        pressed = {x, y};
                        env.env().eval("document.querySelector('[data-pressed]')?.remove()");
                        done += "press " + at + " and remove";
                    }
                }
                for (int k = 0; k < batch && edits < group.edits; k++, edits++) {
                    // Insertion-heavy (append, insertBefore, and remove, move, textContent), and every insertion a table of
                    // rows it refuses (make(13)): the table counts toward the cap, the rows nothing.
                    static const uint32_t kStructuralKinds[] = {0, 1, 0, 1, 2, 3, 4};
                    static const uint32_t kSwapKinds[] = {20, 20, 20, 6, 7, 9, 4};
                    const uint32_t drawn = uint32_t(rng() % 13);
                    const uint32_t kind = group.structural      ? kStructuralKinds[drawn % 7]
                                          : group.swaps         ? kSwapKinds[drawn % 7]
                                          : !group.kinds.empty() ? group.kinds[rng() % group.kinds.size()]
                                                                : drawn,
                                   a = uint32_t(rng() % 1000);
                    uint32_t b = uint32_t(rng() % 1000);
                    const uint32_t c = uint32_t(rng() % 1000);
                    if (group.structural && kind <= 1) {
                        b = 13 + wr_test::kEditShapes * (b % 58);
                    }
                    const std::string call = "__edit(" + std::to_string(kind) + ", " + std::to_string(a) + ", " +
                                             std::to_string(b) + ", " + std::to_string(c) + ")";
                    const std::string result = env.env().eval(call);
                    if (group.structural && kind <= 1 && result.find(" table") == std::string::npos) {
                        group.misshaped++;
                    }
                    done += (done.empty() ? "" : "; ") + result + " " + call;
                }
                if (group.environment) {
                    switch (rng() % 6) {
                    case 0: {
                        static const double kWidths[] = {360, 300, 250};
                        const double width = kWidths[rng() % 3];
                        env.render().setWidth(env.ctx(), width);
                        plain.setWidth(env.ctx(), width);
                        done += "; width " + std::to_string(int(width));
                        break;
                    }
                    case 1: {
                        const wr::Theme theme = env.render().options().theme == wr::Theme::Light ? wr::Theme::Dark : wr::Theme::Light;
                        const std::string declarations = wr_test::themeDeclarations(theme);
                        const std::string was = group.environmentRenders ? freshLayers(env.render().options()) : std::string();
                        env.render().setTheme(env.ctx(), theme, declarations);
                        plain.setTheme(env.ctx(), theme, declarations);
                        if (group.environmentRenders && freshLayers(env.render().options()) != was) {
                            group.themeChanges++;
                        }
                        done += theme == wr::Theme::Dark ? "; dark" : "; light";
                        break;
                    }
                    case 2: {
                        const bool reduced = !env.render().options().reducedMotion;
                        const std::string was = group.environmentRenders ? freshLayers(env.render().options()) : std::string();
                        env.render().setReducedMotion(env.ctx(), reduced);
                        plain.setReducedMotion(env.ctx(), reduced);
                        if (group.environmentRenders && freshLayers(env.render().options()) != was) {
                            group.motionChanges++;
                        }
                        done += reduced ? "; reduced motion" : "; motion";
                        break;
                    }
                    case 3: {
                        const double x = double(rng() % 300), y = double(rng() % 400);
                        pointer(wr::PointerPhase::Down, x, y);
                        pointer(wr::PointerPhase::Up, x, y);
                        done += "; tap " + std::to_string(int(x)) + "," + std::to_string(int(y));
                        break;
                    }
                    default:
                        break;
                    }
                }
                if (group.environment || group.pressThenRemove) {
                    actionStateChanged();
                }
                const uint64_t builds = env.render().buildCount();
                const uint64_t patchedBefore = env.render().patchCount();
                const uint64_t swappedBefore = env.render().swappedTexts();
                const uint64_t plainPatches = plain.patchCount();
                const uint64_t plainBuilds = plain.buildCount();
                const size_t posted = env.env().host().diagnostics.size();
                if (group.animated) {
                    // The frame's flush is this batch's.
                    env.env().frame(16.0);
                }
                env.flush();
                plain.flush(env.ctx());
                // Nothing after the boot builds, in either tree, and nothing stops the widget.
                if ((env.render().buildCount() != builds || plain.buildCount() != plainBuilds ||
                     env.env().runtime().stopReason() != wr::StopReason::None) && !reported) {
                    std::printf("  built or stopped, seed %d: %s\n", seed, done.c_str());
                }
                CHECK_EQ(env.render().buildCount(), builds);
                CHECK_EQ(plain.buildCount(), plainBuilds);
                CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
                // The same choice with and without the render input.
                if (!group.animated && !pointed && plain.patchCount() - plainPatches != env.render().patchCount() - patchedBefore) {
                    std::printf("  the render-input-less tree chose otherwise (%s), seed %d: %s\n  installed: %llu patched, %llu"
                                " built, refusal \"%s\"; without the input: %llu patched, %llu built, refusal \"%s\"\n",
                                group.name, seed, done.c_str(), (unsigned long long)(env.render().patchCount() - patchedBefore),
                                (unsigned long long)(env.render().buildCount() - builds), env.render().lastPatchRefusal(),
                                (unsigned long long)(plain.patchCount() - plainPatches),
                                (unsigned long long)(plain.buildCount() - plainBuilds), plain.lastPatchRefusal());
                    CHECK_EQ(plain.patchCount() - plainPatches, env.render().patchCount() - patchedBefore);
                }
                std::string path = "clean";
                if (env.render().patchCount() != patchedBefore) {
                    path = "patched";
                    group.patched++;
                    group.swapped += env.render().swappedTexts() - swappedBefore;
                } else if (env.render().buildCount() != builds) {
                    path = std::string("rebuilt: ") + env.render().lastPatchRefusal();
                    group.rebuilt++;
                } else {
                    group.clean++;
                }
                group.flushes++;
                CHECK_EQ(env.render().journalNodes(), size_t(0));
                for (size_t d = posted; d < env.env().host().diagnostics.size(); d++) {
                    group.reached = group.reached || env.env().host().diagnostics[d].second == group.limit;
                }
                group.reached = group.reached || (path == "rebuilt: " + group.limit);
                const std::string what =
                    "seed " + std::to_string(seed) + ", edit " + std::to_string(edits) + " (" + path + "): " + done;
                // The oracle (rebuildDump's fresh tree, kept here for the limits a build hits, which a patch must cut
                // at as a rebuild does).
                wr::RenderTree fresh(env.ctx(), env.host(), laterBuild(env.render().options()));
                fresh.build(env.ctx());
                const Dumps rebuilt{fresh.layoutDump(), fresh.renderInput(), fresh.layerTree() ? fresh.layerTree()->dump() : std::string()};
                bool same = matchesDumps(env, rebuilt, what, !reported);
                {
                    if (fresh.renderLimits() != env.render().renderLimits()) {
                        if (!reported) {
                            std::string a, b;
                            for (const std::string& kind : env.render().renderLimits()) a += kind + " ";
                            for (const std::string& kind : fresh.renderLimits()) b += kind + " ";
                            std::printf("  limits differ after: %s\n  flushed: %s\n  rebuilt: %s\n", what.c_str(), a.c_str(), b.c_str());
                        }
                        same = false;
                    }
                }
                // litehtml's counts as a fresh build's (a patch cuts where a build cuts).
                if (fresh.document() && env.render().document() &&
                    (fresh.document()->text_elements() != env.render().document()->text_elements() ||
                     fresh.document()->build_elements() != env.render().document()->build_elements() ||
                     fresh.document()->pseudo_elements() != env.render().document()->pseudo_elements())) {
                    if (!reported) {
                        std::printf("  litehtml's counts differ after: %s (pieces %d/%d, elements %d/%d, pseudo %d/%d)\n",
                                    what.c_str(), env.render().document()->text_elements(), fresh.document()->text_elements(),
                                    env.render().document()->build_elements(), fresh.document()->build_elements(),
                                    env.render().document()->pseudo_elements(), fresh.document()->pseudo_elements());
                    }
                    same = false;
                }
                // The runtime's own running totals as a fresh build's: nothing resets them after the boot.
                if (const std::string totals = wr_test::totalsMismatch(env.render(), fresh); !totals.empty()) {
                    if (!reported) {
                        std::printf("  totals differ after: %s (%s)\n", what.c_str(), totals.c_str());
                    }
                    same = false;
                }
                // The style bytes a fresh build holds (twidget edit 21: a patch keeps them exact).
                if (fresh.document() && env.render().document() &&
                    fresh.document()->style_bytes_charged() != env.render().document()->style_bytes_charged()) {
                    if (!reported) {
                        std::printf("  style bytes %zu, a rebuild's %zu after: %s\n", env.render().document()->style_bytes_charged(),
                                    fresh.document()->style_bytes_charged(), what.c_str());
                    }
                    same = false;
                }
                // What the read APIs answer (boxes, computed style, hit tests, the selectable text), as a fresh tree answers.
                {
                    const std::string flushed = wr_test::readsDump(env.render(), env.ctx());
                    const std::string fromFresh = wr_test::readsDump(fresh, env.ctx());
                    if (flushed != fromFresh) {
                        if (!reported) {
                            size_t at = 0;
                            while (at < flushed.size() && at < fromFresh.size() && flushed[at] == fromFresh[at]) {
                                at++;
                            }
                            const size_t line = flushed.rfind('\n', at) == std::string::npos ? 0 : flushed.rfind('\n', at) + 1;
                            std::printf("  reads differ after: %s\n  flushed: %s\n  fresh:   %s\n", what.c_str(),
                                        flushed.substr(line, flushed.find('\n', at) - line).c_str(),
                                        fromFresh.substr(line, fromFresh.find('\n', at) - line).c_str());
                        }
                        same = false;
                    }
                }
                const auto& [layout, input, layer] = rebuilt;
                const bool plainSame = group.animated ||
                                       (plain.layoutDump() == layout && plain.layerTree() && plain.layerTree()->dump() == layer &&
                                        plain.renderInput().empty());
                if (!plainSame && !reported) {
                    std::printf("  without the render input, differs after: %s\n", what.c_str());
                }
                if (!same || !plainSame) {
                    reported = true;
                }
                CHECK(same);
                CHECK(plainSame);
            }
        }
    }
    for (const Group& group : groups) {
        std::printf("  %s: %llu flushes, %llu patched (%.0f%%; %llu Texts swapped), %llu rebuilt, %llu clean; %llu pointer"
                    " events changed :hover or :active; theme %llu, reduced motion %llu changed the rendering\n", group.name,
                    (unsigned long long)group.flushes, (unsigned long long)group.patched,
                    group.flushes ? 100.0 * double(group.patched) / double(group.flushes) : 0.0,
                    (unsigned long long)group.swapped, (unsigned long long)group.rebuilt, (unsigned long long)group.clean,
                    (unsigned long long)group.actionChanges, (unsigned long long)group.themeChanges,
                    (unsigned long long)group.motionChanges);
    }
    std::printf("churn (random edits): %s", churn.describe().c_str());
    // Every group patched, and each near-limit group reached its limit at least once (no flush was non-incremental:
    // checked flush by flush above).
    for (const Group& group : groups) {
        CHECK(group.patched > 0);
        CHECK(!group.swaps || group.swapped > 0);
        if (!group.limit.empty() && !group.reached) {
            std::printf("  %s never reached %s\n", group.name, group.limit.c_str());
        }
        CHECK(group.limit.empty() || group.reached);
        CHECK_EQ(group.misshaped, uint64_t(0));
        CHECK(!(group.environment || group.pressThenRemove) || group.actionChanges > 0);
        CHECK(!group.environmentRenders || (group.themeChanges > 0 && group.motionChanges > 0));
    }
}

// Twidget edit 74: an SVG element in a subtree that renders nothing can still be drawn elsewhere, by a <use> or a
// url(#…) paint that names it, so a change to it is not dropped: what references it repaints as a fresh build paints it.
WR_TEST(testAHiddenSvgReferenceTargetRepaintsItsUsers) {
    RenderEnv env("<!doctype html><body style='margin:0'>"
                  "<svg style='display:none'><defs><linearGradient id=g><stop id=s offset=0 stop-color='#f00'></stop>"
                  "<stop offset=1 stop-color='#00f'></stop></linearGradient></defs>"
                  "<circle id=dot cx=10 cy=10 r=4 fill='#0a0'></circle></svg>"
                  "<p>before</p><svg width=40 height=20><use href='#dot'></use>"
                  "<rect x=20 y=0 width=20 height=20 fill='url(#g)'></rect></svg></body>");
    expectMatchesRebuild(env, "the boot");
    env.env().eval("document.getElementById('dot').setAttribute('r', '9')");
    env.flush();
    expectMatchesRebuild(env, "a used circle's r in a hidden svg");
    env.env().eval("document.getElementById('s').setAttribute('stop-color', '#ff0')");
    env.flush();
    expectMatchesRebuild(env, "a gradient stop in a hidden svg");
}

// A sprite in a hidden HTML element: a <use> anywhere draws what is under it, so a change there (a new sprite, the sprite
// removed) repaints the users as a fresh build paints them (review I4).
WR_TEST(testAHiddenSpriteChangeRepaintsItsUsers) {
    RenderEnv env("<!doctype html><body style='margin:0'><div id=sprites style='display:none'>"
                  "<svg><circle id=dot cx=10 cy=10 r=4 fill='#0a0'></circle></svg></div>"
                  "<p>before</p><svg width=40 height=20><use href='#dot'></use></svg></body>");
    expectMatchesRebuild(env, "the boot");
    env.env().eval("const ns = 'http://www.w3.org/2000/svg'; const s = document.createElementNS(ns, 'svg');"
                   " const c = document.createElementNS(ns, 'circle'); c.id = 'dot'; c.setAttribute('cx', '10');"
                   " c.setAttribute('cy', '10'); c.setAttribute('r', '9'); c.setAttribute('fill', '#a00'); s.append(c);"
                   " document.getElementById('sprites').replaceChildren(s)");
    env.flush();
    expectMatchesRebuild(env, "the sprite replaced in a hidden div");
    env.env().eval("document.getElementById('sprites').firstChild.remove()");
    env.flush();
    expectMatchesRebuild(env, "the sprite removed from a hidden div");
}

// Review Focus 5: a <use> or a url(#…) paint resolves its target document-wide, so whatever changes one, a re-placement
// or a restyle with the render tree kept (a neutral fill), repaints every <svg> that draws it.
WR_TEST(testSvgReferenceUsersRepaint) {
    RenderEnv env("<!doctype html><body style='margin:0'>"
                  "<svg style='display:none'><defs><linearGradient id=g><stop id=s offset=0 stop-color='#f00'></stop>"
                  "<stop offset=1 stop-color='#00f'></stop></linearGradient></defs>"
                  "<circle id=dot cx=10 cy=10 r=4 fill='#0a0'></circle></svg>"
                  "<div id=sprites style='display:none'><svg><circle id=spr cx=10 cy=10 r=4 fill='#0a0'></circle></svg></div>"
                  "<p>before</p><svg width=60 height=20><use href='#dot'></use>"
                  "<rect x=20 y=0 width=20 height=20 fill='url(#g)'></rect><use href='#spr' x=40></use></svg></body>");
    expectMatchesRebuild(env, "the boot");
    const char* const changes[][2] = {
        {"document.getElementById('dot').setAttribute('r', '9')", "a used circle's r"},
        {"document.getElementById('s').setAttribute('stop-color', '#ff0')", "a gradient stop's stop-color"},
        {"const ns = 'http://www.w3.org/2000/svg'; const s = document.createElementNS(ns, 'svg');"
         " const c = document.createElementNS(ns, 'circle'); c.id = 'spr'; c.setAttribute('cx', '10');"
         " c.setAttribute('cy', '10'); c.setAttribute('r', '9'); c.setAttribute('fill', '#a00'); s.append(c);"
         " document.getElementById('sprites').replaceChildren(s)",
         "the sprite replaced"},
        {"document.getElementById('sprites').firstChild.remove()", "the sprite removed"},
        {"document.getElementById('dot').setAttribute('style', 'fill:#00f')", "a neutral fill on the used circle"},
    };
    for (const auto& [script, what] : changes) {
        const uint64_t builds = env.render().buildCount();
        env.env().eval(script);
        env.flush();
        const auto& ops = env.render().layerOps();
        if (ops.empty()) {
            std::printf("  nothing published after: %s\n", what);
        }
        CHECK(!ops.empty());
        CHECK_EQ(env.render().buildCount(), builds);
        expectMatchesRebuild(env, what);
    }
}

// The oracles' read check reaches what the edits change on a near-cap page, whose filler goes first in the body.
WR_TEST(testReadsDumpReachesPastTheFiller) {
    std::string filler = "<div id=filler>";
    for (int n = 0; n < 700; n++) {
        filler += "<div>f</div>";
    }
    RenderEnv env("<!doctype html><body>" + filler + "</div><p id=t style='font-size:31px'>t</p></body>");
    CHECK(wr_test::readsDump(env.render(), env.ctx()).find("font-size=31px") != std::string::npos);
}

// Ruling 4: nothing that is in a template's contents renders, however it gets there or leaves.
WR_TEST(testTemplateMovesNeverRender) {
    RenderEnv env("<!doctype html><body><b id=b>rendered bold</b><template id=t><i id=i>in template</i></template>"
                  "<p id=p>p</p></body>");
    CHECK(env.render().renderInput().find("rendered bold") != std::string::npos);
    CHECK(env.render().renderInput().find("in template") == std::string::npos);
    // A rendered <b> moved into the contents.
    patches(env, byId("t") + ".content.append(" + byId("b") + ")");
    CHECK(env.render().renderInput().find("rendered bold") == std::string::npos);
    CHECK(env.render().renderInput().find("in template") == std::string::npos);
    // A template's child moved into the body renders; the one left does not.
    patches(env, "document.body.append(" + byId("t") + ".content.firstChild)");
    CHECK(env.render().renderInput().find("in template") != std::string::npos);
    CHECK(env.render().renderInput().find("rendered bold") == std::string::npos);
    // A clone of the template: a template, whose contents (a copy of the <b>) do not render.
    patches(env, byId("p") + ".append(" + byId("t") + ".cloneNode(true))");
    CHECK(env.render().renderInput().find("rendered bold") == std::string::npos);
    CHECK(env.render().renderInput().find("<template") == std::string::npos);
    // The template itself moved, and the clone's <b> out of its contents.
    patches(env, byId("p") + ".prepend(" + byId("t") + ")");
    CHECK(env.render().renderInput().find("rendered bold") == std::string::npos);
    patches(env, "const c = " + byId("p") + ".lastElementChild; document.body.append(c.content.firstChild)");
    CHECK_EQ(countOf(env.render().renderInput(), "rendered bold"), size_t(1));
}

// A fragment is one insertion per child: all three render.
WR_TEST(testFragmentInsertBuildsTheSubtree) {
    RenderEnv env("<!doctype html><body><p>x</p></body>");
    patches(env, "const f = document.createDocumentFragment(); const a = document.createElement('div'); a.textContent = 'frag one';"
                 " const b = document.createElement('p'); b.innerHTML = 'frag <b>two</b>'; f.append(a, b, 'frag three');"
                 " document.body.append(f)");
    const std::string input = env.render().renderInput();
    CHECK(input.find("<div>frag one</div><p>frag <b>two</b></p>frag three</body>") != std::string::npos);
    CHECK(wr_test::findText(*env.render().layerTree(), "three") != nullptr);
}

// A move from A to B in one task, with B before A in tree order and after it: A's old element goes before B's new one
// is built, so the moved node renders once, under B (Ruling P2: the render input shows it there).
WR_TEST(testMoveBetweenParents) {
    RenderEnv env("<!doctype html><body><div id=b1><span>b</span></div><div id=a><i id=m>moved</i><span>a</span></div>"
                  "<div id=b2><span>c</span></div></body>");
    const uint64_t patched = env.render().patchCount();
    // In a task: the flush runs at its end.
    CHECK_EQ(env.env().eval("setTimeout(() => " + byId("b1") + ".append(" + byId("m") + ")); 'ok'"), std::string("ok"));
    env.env().advance(1);
    CHECK_EQ(env.render().patchCount(), patched + 1);
    expectMatchesRebuild(env, "moved to an earlier parent");
    CHECK(env.render().renderInput().find("<div id=\"b1\"><span>b</span><i id=\"m\">moved</i></div><div id=\"a\"><span>a</span></div>") !=
          std::string::npos);
    CHECK_EQ(env.env().eval("setTimeout(() => " + byId("b2") + ".prepend(" + byId("m") + ")); 'ok'"), std::string("ok"));
    env.env().advance(1);
    CHECK_EQ(env.render().patchCount(), patched + 2);
    expectMatchesRebuild(env, "moved to a later parent");
    CHECK(env.render().renderInput().find("<div id=\"b2\"><i id=\"m\">moved</i><span>c</span></div>") != std::string::npos);
    CHECK_EQ(countOf(env.render().renderInput(), "moved"), size_t(1));
    // Moved twice in one task, and changed on the way: built where it ends, as it is.
    patches(env, byId("a") + ".append(" + byId("m") + "); " + byId("b1") + ".append(" + byId("m") + "); " + byId("m") +
                     ".className = 'k'");
    CHECK(env.render().renderInput().find("<i id=\"m\" class=\"k\">moved</i></div><div id=\"a\">") != std::string::npos);
}

// With sibling combinators or positional pseudo-classes, a dirty parent's children are matched again in place where a rule
// can reach them (twidget edit 90): what each matches follows the new order.
WR_TEST(testStructureUnderSiblingSelectors) {
    RenderEnv env("<!doctype html><style>li:nth-child(2n){color:#f00;background:#eee} li + li{margin-top:3px}"
                  " .x ~ li{font-weight:bold} li:last-child{background:#0f0} li:first-child span{color:#00f}</style>"
                  "<body><ul id=l><li><span>a</span></li><li class=x>b</li><li>c</li></ul><p id=p>p</p></body>");
    patches(env, byId("l") + ".prepend(document.createElement('li'))");
    patches(env, byId("l") + ".append(" + byId("l") + ".children[1])");
    patches(env, byId("l") + ".lastElementChild.remove()");
    patches(env, byId("l") + ".insertBefore(document.createElement('li'), " + byId("l") + ".children[2])");
    patches(env, byId("p") + ".append(" + byId("l") + ".firstElementChild)");
    // An attribute change there matches again what the sibling selectors reach (twidget edit 77).
    patches(env, byId("l") + ".lastElementChild.className = 'x'");
}

// Twidget edit 90: under sibling and positional rules, the items a prepend, a removal and an append leave keep their render
// items (only their matches change, in place), and each patch equals a rebuild.
WR_TEST(testSiblingsKeepTheirRenderItemsUnderSiblingSelectors) {
    RenderEnv env("<!doctype html><style>li + li{color:#c00} li:nth-child(2n){background-color:#eee}"
                  " li:first-child span{color:#00f} li:last-child b{color:#c60}</style>"
                  "<body><ul id=l><li id=a><span>a</span><b>a</b></li><li id=b>b</li><li id=c><b>c</b></li></ul></body>");
    const auto itemOf = [&](const char* id) -> std::shared_ptr<litehtml::render_item> {
        for (const auto& [node, entry] : env.render().publishedBuild().nodes) {
            if (entry.element && std::string(entry.element->get_attr("id", "")) == id) {
                return env.render().document()->live_item(*entry.element);
            }
        }
        return nullptr;
    };
    // Held, so that an item made again cannot take a kept one's address.
    const auto a = itemOf("a"), b = itemOf("b"), c = itemOf("c"), l = itemOf("l");
    CHECK(a && b && c && l);
    patches(env, "const li = document.createElement('li'); li.textContent = 'n'; " + byId("l") + ".prepend(li)");
    CHECK(itemOf("a") == a && itemOf("b") == b && itemOf("c") == c && itemOf("l") == l);
    patches(env, byId("b") + ".remove()");
    CHECK(itemOf("a") == a && itemOf("c") == c && itemOf("l") == l);
    patches(env, "const li = document.createElement('li'); li.innerHTML = '<b>z</b>'; " + byId("l") + ".append(li)");
    CHECK(itemOf("a") == a && itemOf("c") == c && itemOf("l") == l);
}

// Twidget edit 90: an environment change (matched first in the flush) beside a structure change under a sibling rule: the
// elements the environment matched are matched again by the reach, as the structure changed what they match.
WR_TEST(testAnEnvironmentChangeBesideStructureUnderSiblingRules) {
    const char* page = "<!doctype html><style>@media (max-width: 280px){li{color:#00f}} li + li{background-color:#eee}</style>"
                       "<body><ul id=l><li id=a>a</li><li id=b>b</li><li id=c>c</li></ul></body>";
    {
        RenderEnv env(page);
        env.render().setWidth(env.ctx(), 250);
        patches(env, byId("a") + ".remove()");
    }
    {
        RenderEnv env(page);
        env.render().setWidth(env.ctx(), 250);
        patches(env, "const li = document.createElement('li'); li.textContent = 'n'; " + byId("l") + ".prepend(li)");
    }
}

// Twidget edits 88, 90: an earlier sibling reads a later sibling's :empty through :nth-last-child(1 of .e:empty): the flip
// matches it again, and the charge lists it.
WR_TEST(testAnEmptyFlipThroughOfSReachesEarlierSiblings) {
    RenderEnv env("<!doctype html><style>div{height:5px} div:nth-last-child(1 of .e:empty){background-color:#c00}</style>"
                  "<body><div class=e id=d1></div><div class=e id=d2></div><p>x</p></body>");
    patches(env, byId("d2") + ".append(document.createElement('span'))");
    patches(env, byId("d2") + ".firstChild.remove()");
}

// Twidget edit 90: an append to a long list under sibling and positional rules matches nothing again but the new item (a
// rule reads only preceding siblings): it patches, as under plain rules, and equals a fresh build.
WR_TEST(testAnAppendUnderSiblingSelectorsPatches) {
    for (const char* sheet : {"li + li{color:#c00} li:nth-child(2n) span{color:#00c}", "li.never{color:#c00} li.never span{color:#00c}"}) {
        std::string page = std::string("<!doctype html><style>") + sheet + "</style><body><ul id=l>";
        for (int i = 0; i < 1000; i++) {
            page += "<li><span>x</span></li>";
        }
        RenderEnv env(page + "</ul></body>");
        const uint64_t builds = env.render().buildCount();
        const uint64_t patched = env.render().patchCount();
        const std::string script = "const li = document.createElement('li'); li.innerHTML = '<span>y</span>';"
                                   " document.getElementById('l').append(li)";
        CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
        env.flush();
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patched + 1);
        expectMatchesRebuild(env, sheet);
    }
}

// Twidget edit 81: a <style>'s text set, appended to or changed in place, a <style> inserted (alone or in a subtree) and
// removed, and its attribute changed: each patches, equal to a rebuild.
WR_TEST(testSheetChangesPatch) {
    RenderEnv env("<!doctype html><style id=s>p{color:#333}</style><body style='margin:0'><p id=p class=a>text</p>"
                  "<ul id=l><li>x</li><li>y</li></ul></body>");
    patches(env, byId("s") + ".textContent = 'p{color:#c00} .a{padding:2px}'");
    patches(env, byId("s") + ".append(' li{color:#0a0}')");
    patches(env, byId("s") + ".firstChild.data = 'p{color:#00c}'");
    patches(env, "const s = document.createElement('style'); s.id = 'n'; s.textContent = 'li::before{content:\"-\"} p{margin:3px}';"
                 " document.head.append(s)");
    patches(env, "const s = document.createElement('style'); s.textContent = 'p{color:#0c0}'; document.body.prepend(s)");
    patches(env, byId("n") + ".remove()");
    patches(env, byId("s") + ".setAttribute('media', '(max-width:10px)')");
    patches(env, "const d = document.createElement('div'); d.id = 'd';"
                 " d.innerHTML = '<style>li{counter-increment:n} li::before{content:counter(n)}</style><i>i</i>';"
                 " document.body.append(d)");
    patches(env, byId("d") + ".remove()");
    patches(env, byId("s") + ".textContent = ''");
}

// Twidget edit 82: the document's own children: the document element replaced, removed (an empty <html>, Ruling 11)
// and put back; a comment beside it, which renders nothing (a clean flush); and the own attributes of the document's
// html, body and head beside structure.
WR_TEST(testDocumentChildrenPatch) {
    RenderEnv env("<!doctype html><html><head><style>p{color:#333}</style></head><body style='margin:0'><p id=p>text</p>"
                  "</body></html>");
    patches(env, "const h = document.createElement('html'); h.innerHTML = '<head><style>:root{--k:#c00} p{color:var(--k)}"
                 " li{counter-increment:n} li::before{content:counter(n)}</style></head><body><p>new</p><ul><li>a</li>"
                 "<li>b</li></ul></body>'; document.documentElement.replaceWith(h)");
    patches(env, "globalThis.kept = document.documentElement; kept.remove()");
    patches(env, "document.append(globalThis.kept)");
    {
        const uint64_t builds = env.render().buildCount();
        const uint64_t patched = env.render().patchCount();
        edit(env, "document.append(document.createComment('c'))");
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patched);
        CHECK_EQ(env.render().journalNodes(), size_t(0));
        expectMatchesRebuild(env, "a comment beside the document element");
    }
    patches(env, "document.documentElement.className = 'x'; document.body.append(' more')");
    patches(env, "document.documentElement.setAttribute('style', 'color:#00c'); document.body.prepend(document.createElement('hr'))");
    // The body's and the head's own attributes beside structure too (a body whose dir is auto hears every change under it).
    patches(env, "document.body.setAttribute('dir', 'auto'); document.body.append(document.createElement('hr'))");
    patches(env, "document.body.append('words')");
    patches(env, "document.head.setAttribute('data-h', '1'); document.body.prepend('z ')");
}

// What the fork or the plan refuses rebuilds, and agrees with a rebuild.
WR_TEST(testStructureFallsBack) {
    RenderEnv env("<!doctype html><style>p{color:#333}</style><body><p id=p>text</p><select id=s><option>one</option></select>"
                  "<table id=t><tbody><tr><td>c</td></tr></tbody></table><div id=d>d</div><svg id=g width=20 height=20></svg>"
                  "<button id=b>go</button></body>");
    // Sheets change in place (twidget edit 81): testSheetChangesPatch.
    patches(env, "const s = document.createElement('style'); s.textContent = 'p{color:red}'; document.body.append(s)");
    patches(env, "document.querySelector('style').append('div{color:blue}')");
    patches(env, "document.querySelector('style').firstChild.data = 'p{color:green}'");
    patches(env, "document.querySelector('style').firstChild.data = 'p{color:#111}'; " + byId("d") + ".append('z')");
    // A <select> is dropped by profile 1 (V4 plan, Task 4): what happens inside it renders nothing, and removing it or
    // inserting one removes or inserts nothing the build has.
    rendersNothing(env, byId("s") + ".append(document.createElement('option'))");
    rendersNothing(env, byId("s") + ".firstElementChild.append(' more')");
    rendersNothing(env, byId("s") + ".remove()");
    rendersNothing(env, "const d = document.createElement('div'); d.append(document.createElement('select')); document.body.append(d)");
    // A row straight under a <table> is refused by its own append and renders nothing (twidget edit 83).
    patches(env, byId("t") + ".append(document.createElement('tr'))");
    // Inside an <svg>, which paints its subtree itself: the svg's render subtree is replaced (twidget edits 16, 18).
    patches(env, byId("g") + ".append(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))");
    // A <button> reads nothing of its children (twidget edit 16): structure inside it patches.
    patches(env, byId("b") + ".append(document.createElement('b'))");
    // A kept node's own change beside structure (a mixed journal): one patch.
    patches(env, byId("p") + ".firstChild.data = 'changed'; " + byId("d") + ".append('x')");
    patches(env, byId("d") + ".className = 'k'; " + byId("d") + ".append('y')");
    // The document element gone and back: replaced in place by itself (twidget edit 82).
    patches(env, "const h = document.documentElement; h.remove(); document.append(h)");
    // And a plain change still patches afterwards.
    patches(env, byId("d") + ".append(document.createElement('br'), 'after')");
}

// Twidget edit 78: a counter's lookup walks the previous siblings at every level (element::find_counter), so a numbered
// list's patch walks the list once per item; each element visited is a selector step, counted and bounded as matching
// is. A class on one of 300 numbered items takes far more steps than on the same list unnumbered, and patches; on
// 2,000 the boot is cut by litehtml's budget and the change patches, replaying the style pass uncut (twidget edit 84),
// never stopping the widget.
WR_TEST(testCounterLookupsCountAsSelectorSteps) {
    const auto list = [](int items, bool counted) {
        std::string page = std::string("<!doctype html><style>li{color:#333} .k{color:#c00}") +
                           (counted ? " ol{counter-reset:n} li{counter-increment:n} li::before{content:counter(n) '. '}" : "") +
                           "</style><body><ol id=o>";
        for (int i = 0; i < items; i++) {
            page += "<li>i</li>";
        }
        return page + "</ol></body>";
    };
    int64_t plain = 0;
    {
        RenderEnv env(list(300, false));
        patches(env, byId("o") + ".children[150].className = 'k'");
        plain = env.render().lastPatchSteps();
    }
    {
        RenderEnv env(list(300, true));
        patches(env, byId("o") + ".children[150].className = 'k'");
        if (env.render().lastPatchSteps() <= plain + 300 * 300 / 4) {
            std::printf("  300 numbered items: %lld steps, unnumbered %lld\n", (long long)env.render().lastPatchSteps(),
                        (long long)plain);
        }
        CHECK(env.render().lastPatchSteps() > plain + 300 * 300 / 4);
    }
    {
        RenderEnv env(list(2000, true));
        CHECK(env.render().selectorSteps() > litehtml::document::default_selector_steps);
        patches(env, byId("o") + ".children[1000].className = 'k'");
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK(env.render().lastPatchSteps() > 2000 * 2000 / 2);
    }
}

// Twidget edit 78: counters run again in a build's order, so what touches a counted element patches and agrees with a
// rebuild: a tap on a numbered story (02-weekly-bare's shape: Review Focus 1), a story appended and one removed, and a
// counter reset on <body>, which the host sheet's `body` rule matches too (Review Focus 2).
WR_TEST(testCountersPatch) {
    {
        RenderEnv env("<!doctype html><style>body{margin:0} .list{counter-reset:story} .story{counter-increment:story;"
                      "height:40px} .story::before{content:\"0\" counter(story)} .story:hover{background-color:#eee}</style>"
                      "<body><div class=list id=l><div class=story>a</div><div class=story>b</div><div class=story>c</div>"
                      "</div></body>");
        const uint64_t builds = env.render().buildCount();
        const uint64_t patched = env.render().patchCount();
        wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Down, 20, 60, 1, true);
        wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Up, 20, 60, 1, true);
        env.env().drain();
        env.flush();
        if (env.render().buildCount() != builds) {
            std::printf("  not patched (%s): a tap on a numbered story\n", env.render().lastPatchRefusal());
        }
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK(env.render().patchCount() > patched);
        CHECK_EQ(env.env().eval("document.querySelectorAll('.story')[1].matches(':hover')"), std::string("true"));
        expectMatchesRebuild(env, "a tap on a numbered story");
        patches(env, "const s = document.createElement('div'); s.className = 'story'; s.textContent = 'd'; " + byId("l") +
                         ".append(s)");
        patches(env, byId("l") + ".firstElementChild.remove()");
    }
    {
        // A `*` reset reaches the ::before after its own rule, as in a build.
        RenderEnv env("<!doctype html><style>*{padding:0} ol{counter-reset:n} li{counter-increment:n;height:30px}"
                      " li::before{content:counter(n) '. ';padding:0 9px} li:hover{color:#c00}</style>"
                      "<body style='margin:0'><ol id=o><li>a</li><li>b</li><li>c</li></ol></body>");
        const uint64_t builds = env.render().buildCount();
        wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Down, 60, 45, 1, true);
        wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Up, 60, 45, 1, true);
        env.env().drain();
        env.flush();
        CHECK_EQ(env.render().buildCount(), builds);
        expectMatchesRebuild(env, "a tap on a numbered item under a * reset");
    }
    {
        RenderEnv env("<!doctype html><style>body{counter-reset:n} p{counter-increment:n} p::before{content:counter(n) '. '}"
                      "</style><body><p id=a>a</p><p>b</p></body>");
        patches(env, "const p = document.createElement('p'); p.textContent = 'z'; " + byId("a") + ".before(p)");
        patches(env, byId("a") + ".remove()");
    }
}

// Twidget edit 83: only what renders counts. A row or a <div> straight under a <table> is refused by its own append,
// renders nothing and counts nothing, so inserting, changing and removing one patches (or renders nothing), and
// litehtml's counts stay a fresh build's.
WR_TEST(testRefusedInsertionsPatch) {
    RenderEnv env("<!doctype html><body><table id=t> <tbody><tr><td>c</td></tr></tbody> </table><p>after</p></body>");
    const std::string t = byId("t");
    patches(env, t + ".append(document.createElement('tr'))");
    expectCountsOfAFreshBuild(env, "a refused row");
    patches(env, t + ".append(document.createElement('div'))");
    expectCountsOfAFreshBuild(env, "a refused div");
    rendersNothing(env, t + ".lastChild.className = 'x'.repeat(4000)");
    expectCountsOfAFreshBuild(env, "its class");
    rendersNothing(env, t + ".lastChild.append(document.createElement('p'))");
    expectCountsOfAFreshBuild(env, "a child of it");
    patches(env, t + ".lastChild.remove()");
    expectCountsOfAFreshBuild(env, "its removal");
    // A Text straight under the <table>: in the render input, with no pieces.
    patches(env, t + ".append(' x ')");
    expectCountsOfAFreshBuild(env, "a Text the table takes no pieces of");
    patches(env, t + ".lastChild.remove()");
}

// Twidget edit 83: with no document element a build renders an empty <html>, which litehtml counts; a patch that takes
// the document element away counts it too.
WR_TEST(testEmptyDocumentElementCountsAsABuild) {
    RenderEnv env("<!doctype html><body><p>p</p></body>");
    patches(env, "document.documentElement.remove()");
    CHECK_EQ(env.render().document()->build_elements(), 1);
    expectCountsOfAFreshBuild(env, "the document element's removal");
}

// Twidget edits 18 and 19: structure beside ::before/::after content patches; the commit's match makes an inserted
// element's content in its place, as a fresh build does. Near the text-piece cap, content the commit makes crosses it,
// and the commit replays the style pass in a fresh build's order (twidget edit 84).
WR_TEST(testStructureBesidePseudoContentPatches) {
    {
        RenderEnv env("<!doctype html><style>p::before{content:'\\00b7'} q::before{content:'\\00ab'}</style>"
                      "<body><p id=p>p</p><div id=d><p>one</p><p>two</p></div></body>");
        patches(env, byId("d") + ".append(document.createElement('p'))");
        patches(env, byId("d") + ".firstElementChild.remove()");
        patches(env, byId("p") + ".append(document.createElement('q'))");
        patches(env, byId("p") + ".append('x')");
        patches(env, "document.querySelector('q').remove()");
    }
    {
        // 4,997 words (9,993 pieces), the sheet's text (1) and the paragraph's own ::before (5): 1 short of the cap. An
        // empty <p> brings 5.
        std::string page = "<!doctype html><style>p::before{content:'a b c'}</style><body><p id=big>";
        for (int n = 0; n < 4997; n++) {
            page += n ? " w" : "w";
        }
        page += "</p></body>";
        RenderEnv env(page);
        CHECK_EQ(env.render().document()->text_elements(), 9999);
        CHECK(!env.render().document()->text_limited());
        patches(env, "document.body.append(document.createElement('p'))");
        CHECK(env.render().document()->text_limited());
        CHECK_EQ(env.render().document()->text_elements(), 10000);
    }
}

// The render limits decide what a build leaves out. A patch that crosses one, or one in a document a build cut, walks the
// cut as a build walks it (RenderCut.h) and patches: what crosses the cut leaves the render input or comes back to it,
// and a limit newly reached is posted.
WR_TEST(testStructurePatchCutsAtTheLimits) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    const auto lastPosted = [](RenderEnv& env) {
        return env.env().host().diagnostics.empty() ? std::string() : env.env().host().diagnostics.back().second;
    };
    {
        // The byte budget: 1,048,000 bytes of a class (profile 1's text budgets do not count it: V4 plan, Task 7), then
        // 1,000 more of text.
        std::string page = "<!doctype html><body><p id=big class=" + std::string(1048000, 'x') + "></p><p id=p>p</p></body>";
        RenderEnv env(page);
        CHECK(env.env().host().diagnostics.empty());
        patches(env, byId("p") + ".append('y'.repeat(300))");
        const size_t posted = env.env().host().diagnostics.size();
        edit(env, byId("p") + ".append('z'.repeat(1000))");
        CHECK(env.env().host().diagnostics.size() > posted && env.env().host().diagnostics[posted].second == "bytes");
        expectMatchesRebuild(env, "past the byte budget");
        expectCountsOfAFreshBuild(env, "past the byte budget");
        patches(env, byId("p") + ".append('w')");
        patches(env, byId("big") + ".remove()");
        expectCountsOfAFreshBuild(env, "the budget's cut gone");
        patches(env, byId("p") + ".append('back under')");
    }
    {
        // 256 form controls (Ruling E6): buttons, the one control profile 1 keeps; a dropped <input> counts nothing.
        std::string page = "<!doctype html><body><div id=d>";
        for (int n = 0; n < 254; n++) {
            page += "<button>b</button>";
        }
        page += "</div></body>";
        RenderEnv env(page);
        patches(env, byId("d") + ".append(document.createElement('input'), document.createElement('button'))");
        patches(env, byId("d") + ".append(document.createElement('button'), document.createElement('button'))");
        CHECK_EQ(lastPosted(env), std::string("form-controls"));
        expectCountsOfAFreshBuild(env, "past the form-control limit");
        patches(env, byId("d") + ".lastElementChild.remove()");
        patches(env, byId("d") + ".firstElementChild.remove()");
        expectCountsOfAFreshBuild(env, "back under the form-control limit");
    }
    {
        // The text-piece cap: 9,995 pieces, then 9 more (or 5 after a 3-piece removal).
        std::string page = "<!doctype html><body><p id=big>";
        for (int n = 0; n < 4996; n++) {
            page += n ? " w" : "w";
        }
        page += "</p><p id=p>a b</p></body>";
        RenderEnv env(page);
        CHECK_EQ(env.render().document()->text_elements(), 9991 + 3);
        // 3 pieces go and 7 come: 9,998, counted with the 3 released (alive until the commit).
        patches(env, byId("p") + ".firstChild.remove(); " + byId("p") + ".append('1 2 3 4')");
        CHECK_EQ(env.render().document()->text_elements(), 9991 + 7);
        // 6 more pass the cap: the walk cuts the Text that straddles it, as a build does.
        patches(env, byId("p") + ".append(' 5 6 7')");
        CHECK_EQ(env.render().document()->text_elements(), 10000);
        expectCountsOfAFreshBuild(env, "past the text-piece cap");
        patches(env, byId("big") + ".firstChild.data = 'w'");
        expectCountsOfAFreshBuild(env, "back under the text-piece cap");
    }
    {
        // The depth cap: an element at depth 256 is not built.
        std::string page = "<!doctype html><body>";
        for (int n = 0; n < 250; n++) {
            page += "<div>";
        }
        page += "<span id=deep>deep</span></body>";
        RenderEnv env(page);
        patches(env, "let e = " + byId("deep") + "; for (let i = 0; i < 3; i++) { const c = document.createElement('i'); e.append(c); e = c; }");
        patches(env, "let e = " + byId("deep") + "; for (let i = 0; i < 5; i++) { const c = document.createElement('i'); e.append(c); e = c; }");
        expectCountsOfAFreshBuild(env, "past the depth cap");
    }
}

// Review Focus 1: an insertion that takes the document past the node cap cuts what follows, its removal brings it back,
// and a change past the cut renders nothing new; each flush patches and equals a build.
WR_TEST(testTheNodeCapMovesBothWays) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    const std::string tail = "<div id=edit><p>a</p></div><p id=tail>tail</p>";
    int used = 0;
    {
        RenderEnv probe("<!doctype html><body><div id=filler></div>" + tail + "</body>");
        used = std::stoi(probe.env().eval(
            "let n = 1; (function walk(x) { for (let c = x.firstChild; c; c = c.nextSibling) { if (c.nodeType !== 10) n++;"
            " walk(c); } })(document); String(n)"));
    }
    std::string filler = "<div id=filler>";
    for (int n = used; n < int(wr::kMaxRenderNodes) - 11; n++) {
        filler += "<!---->";
    }
    RenderEnv env("<!doctype html><body>" + filler + "</div>" + tail + "</body>");
    CHECK(env.render().renderLimits().empty());
    const auto tailShown = [&] {
        return env.env().eval("document.getElementById('tail').getBoundingClientRect().height > 0") == "true";
    };
    CHECK(tailShown());
    const std::string insert = "const d = document.createElement('div'); d.id = 'many'; for (let i = 0; i < 19; i++)"
                               " d.appendChild(document.createComment('c')); document.body.insertBefore(d, " +
                               byId("edit") + ")";
    patches(env, insert);
    CHECK(!tailShown());
    CHECK(std::find(env.render().renderLimits().begin(), env.render().renderLimits().end(), "nodes") !=
          env.render().renderLimits().end());
    expectCountsOfAFreshBuild(env, "past the node cap");
    patches(env, byId("many") + ".remove()");
    CHECK(tailShown());
    CHECK(env.render().renderLimits().empty());
    patches(env, insert);
    // Past the cut nothing renders, so the journal hears nothing: no flush, and still a build's.
    rendersNothing(env, byId("tail") + ".firstChild.data = 'changed past the cut'");
    CHECK(!tailShown());
    expectCountsOfAFreshBuild(env, "a change past the cut");
}

// One task that changes thousands of nodes, each its own journal entry (appended one by one, given a class, removed one
// by one), patches and equals a fresh build.
WR_TEST(testAMassChangePatches) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><style>.c{color:#c00}</style><body><div id=m></div><p>tail</p></body>");
    for (const std::string& script :
         {std::string("const m = document.getElementById('m'); for (let i = 0; i < 9000; i++) m.appendChild(document.createElement('span'))"),
          std::string("for (const s of document.getElementById('m').children) s.className = 'c'"),
          std::string("const m = document.getElementById('m'); while (m.firstChild) m.firstChild.remove()")}) {
        const uint64_t builds = env.render().buildCount();
        const uint64_t patched = env.render().patchCount();
        CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
        CHECK(env.render().journalNodes() >= size_t(9000));
        env.flush();
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patched + 1);
        expectMatchesRebuild(env, script);
    }
}

// Twidget edit 88: one task that fills every .e and one that empties them, beside rules that change their next sibling's
// box and content and every later sibling's match, patch and equal a fresh build.
WR_TEST(testStructureBesideEmptySiblingsPatches) {
    std::string page = "<!doctype html><style>.e:empty + p{display:none} .e:not(:empty) + p::before{content:'x'}"
                       " .e:empty ~ i{color:#c00}</style><body>";
    for (int i = 0; i < 1000; i++) {
        page += "<div class=e></div><p>x</p>";
    }
    RenderEnv env(page + "<i>tail</i></body>");
    for (const char* script : {"for (const e of document.querySelectorAll('.e')) e.append(document.createElement('span'))",
                               "for (const e of document.querySelectorAll('.e')) e.firstChild.remove()"}) {
        const uint64_t builds = env.render().buildCount();
        const uint64_t patched = env.render().patchCount();
        CHECK_EQ(env.env().eval(std::string("(() => { ") + script + "; })(); 'ok'"), std::string("ok"));
        env.flush();
        if (env.render().patchCount() != patched + 1) {
            std::printf("  not patched (%s): %s\n", env.render().lastPatchRefusal(), script);
        }
        CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().patchCount(), patched + 1);
        expectMatchesRebuild(env, script);
    }
}

// The document's own head and body removed, put back, replaced, re-adopted, and at a cap; a body element elsewhere is an
// inert div; the document element replaced by a <div> and then changed in one task. Each patches through the root's
// replacement (flushRoot, twidget edit 82) or as any element does, and equals a rebuild.
WR_TEST(testTheDocumentsOwnHeadAndBodyPatch) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><head><title>t</title></head><body><div id=d>d</div><p>p</p></body>");
    patches(env, "window.ob = document.body; document.body.remove()");
    patches(env, "document.documentElement.append(window.ob)");
    patches(env, "document.head.remove()");
    patches(env, "const nb = document.createElement('body'); nb.append(...document.body.childNodes); document.body = nb");
    patches(env, "const nb2 = document.createElement('body'); nb2.textContent = 'nb2'; const old = document.body;"
                 " document.documentElement.insertBefore(nb2, old); old.id = 'z'");
    patches(env, "document.querySelector('div').appendChild(document.createElement('body'))");
    patches(env, "document.body.className = 'x'.repeat((1 << 20) + 16)");
    patches(env, "document.body.removeAttribute('class')");
    patches(env, "const d = document.createElement('div'); d.textContent = 'root'; document.documentElement.replaceWith(d)");
    patches(env, "const r = document.documentElement; r.className = 'x'; r.appendChild(document.createElement('span'))");
}

// Twidget edit 89: an ordered list's items are numbered again in place when one is inserted or removed, from its
// `start`, every list item counted (one with no marker too); each patch equals a fresh build, markers included.
WR_TEST(testAnOrderedListRenumbersInPlace) {
    RenderEnv env("<!doctype html><body><ol id=l start=3><li>a</li><li>b</li><li>c</li></ol></body>");
    const std::string list = "document.getElementById('l')";
    patches(env, "const li = document.createElement('li'); li.textContent = 'first'; " + list + ".prepend(li)");
    patches(env, list + ".children[1].remove()");
    patches(env, "const li = document.createElement('li'); li.textContent = 'plain'; li.style.listStyle = 'none'; " + list +
                     ".append(li)");
    patches(env, "const li = document.createElement('li'); li.textContent = 'again'; " + list + ".prepend(li)");
}

// Twidget edit 74: a structure patch the fork does not link (inline content beside a block, edit 89) replaces the render
// subtree of its boundary and keeps the rest of litehtml's render tree, its root and a sibling outside the boundary
// included; the patch equals a fresh build.
WR_TEST(testAStructurePatchKeepsTheRenderTreeOutsideItsSubtree) {
    RenderEnv env("<!doctype html><body style='margin:0'><div id=a><p>a</p></div><div id=b><p>b</p></div></body>");
    // Held, so that an item made again cannot take a kept one's address.
    const std::shared_ptr<litehtml::render_item> root = env.render().document()->root_render();
    const auto itemOf = [&](const char* id) -> std::shared_ptr<litehtml::render_item> {
        wr::Element* body = wr::DOMState::of(env.ctx()).document().body(env.ctx());
        for (size_t i = 0; body && i < body->childCount(); i++) {
            wr::Node* child = body->childAt(i);
            if (!child->isElement()) {
                continue;
            }
            const wr::RenderBuild& built = env.render().publishedBuild();
            auto found = built.nodes.find(child);
            if (found != built.nodes.end() && found->second.element &&
                std::string(found->second.element->get_attr("id", "")) == id) {
                return found->second.element->get_render_item();
            }
        }
        return nullptr;
    };
    const std::shared_ptr<litehtml::render_item> a = itemOf("a");
    CHECK(root != nullptr && a != nullptr);
    patches(env, "const s = document.createElement('span'); s.textContent = 'new'; document.getElementById('b').append(s)");
    CHECK(env.render().document()->root_render() == root);
    CHECK(itemOf("a") == a);
}

// A child of <html> beside its head and body is placed as any element's child is, by the structure patch, not by
// replacing the document element (flushRoot, which makes every litehtml element again): its append, its text and its
// removal each patch, equal a fresh build and keep the body's and the paragraph's litehtml elements, and its text's
// operations name only its own layers. (The fork links its render subtree under the root's and unlinks it, twidget edit
// 82, as a block appended to the body links under the body's.) A second <body> after the first renders as a div and patches so. The document's own head moved
// (built only with its document element) and a <body> inserted before the body (the document's body now) replace the
// document element.
WR_TEST(testAnHtmlChildBesideTheBodyPatchesInPlace) {
    RenderEnv env("<!doctype html><body><p>t</p></body>");
    // Held, so that an element made again cannot take a kept one's address.
    const auto elementOf = [&](wr::Node* node) -> litehtml::element::ptr {
        const wr::RenderBuild& built = env.render().publishedBuild();
        auto found = node ? built.nodes.find(node) : built.nodes.end();
        return found == built.nodes.end() ? nullptr : found->second.element;
    };
    wr::Element* body = wr::DOMState::of(env.ctx()).document().body(env.ctx());
    wr::Node* p = body && body->childCount() ? body->childAt(0) : nullptr;
    const litehtml::element::ptr bodyElement = elementOf(body);
    const litehtml::element::ptr pElement = elementOf(p);
    CHECK(bodyElement != nullptr && pElement != nullptr);
    // Each published layer's NodeKey, added to `keys`.
    std::map<wr::LayerId, wr::NodeKey> keys;
    const auto addKeys = [&] {
        std::vector<const wr::MirrorNode*> stack{env.render().layerTree()->mirror()};
        while (!stack.empty()) {
            const wr::MirrorNode* node = stack.back();
            stack.pop_back();
            keys.emplace(node->id, node->key);
            for (const auto& child : node->children) {
                stack.push_back(child.get());
            }
        }
    };
    const auto keyOf = [&](wr::Node* node) -> wr::NodeKey {
        const wr::RenderBuild& built = env.render().publishedBuild();
        auto found = built.nodes.find(node);
        return found == built.nodes.end() ? 0 : found->second.key;
    };
    const auto kept = [&](const char* step) {
        if (elementOf(body) != bodyElement || elementOf(p) != pElement) {
            std::printf("  %s made the body's or the paragraph's litehtml element again\n", step);
            CHECK(false);
        }
    };
    patches(env, "const d = document.createElement('div'); d.id = 'x'; d.textContent = 'x';"
                 " document.documentElement.append(d)");
    kept("the append");
    wr::Element* html = wr::DOMState::of(env.ctx()).document().documentElementNode();
    wr::Element* div = static_cast<wr::Element*>(html->childAt(html->childCount() - 1));
    wr::Node* text = div->childAt(0);
    addKeys();
    std::set<wr::NodeKey> own{keyOf(div), keyOf(text)};
    patches(env, byId("x") + ".firstChild.data = 'changed'");
    kept("the text");
    addKeys();
    own.insert(keyOf(text));
    own.erase(0);
    CHECK(!own.empty() && !env.render().layerOps().empty());
    for (const wr::LayerOp& op : env.render().layerOps()) {
        auto key = keys.find(op.node);
        if (key == keys.end() || !own.count(key->second)) {
            std::printf("  the text's operations name layer %llu, not the div's\n", (unsigned long long)op.node);
            CHECK(false);
        }
    }
    patches(env, byId("x") + ".remove()");
    kept("the removal");
    patches(env, "const b = document.createElement('body'); b.textContent = 'second'; document.documentElement.append(b)");
    kept("a second body");
    patches(env, "document.documentElement.append(document.head)");
    patches(env, "const b = document.createElement('body'); b.textContent = 'first';"
                 " document.documentElement.insertBefore(b, document.body)");
}

// A <style>'s text changed in a flush that walks the cut: the walk counts its sheet once, so the text units the patch
// publishes are a build's, and a later Text past the text budget is cut where a build cuts it.
WR_TEST(testASheetChangeWhileWalkingCountsOnce) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    std::string page = "<!doctype html><body><style id=s>p{color:red}/*" + std::string(2000, 'b') + "*/</style>";
    for (int i = 0; i < 4; i++) {
        page += "<p>" + std::string(65000, 'a') + "</p>";
    }
    page += "<div id=t></div></body>";
    RenderEnv env(page);
    const auto unitsOfAFreshBuild = [&] {
        wr::RenderOptions options = env.render().options();
        options.selectorStepCut = false;
        wr::RenderTree fresh(env.ctx(), env.host(), options);
        fresh.build(env.ctx());
        return fresh.renderedTextUnits().units;
    };
    const size_t room = wr::Limits::compat().textBudgetUnits - env.render().renderedTextUnits().units;
    // The sheet shrinks by 1,000 units and a Text takes 500 more than was left: the plan's sums refuse, the walk patches.
    patches(env, byId("s") + ".firstChild.data = 'p{color:red}/*' + 'b'.repeat(1000) + '*/'; " + byId("t") +
                     ".append('c'.repeat(" + std::to_string(room + 500) + "))");
    CHECK_EQ(env.render().renderedTextUnits().units, unitsOfAFreshBuild());
    patches(env, byId("t") + ".append('d'.repeat(700))");
    CHECK_EQ(env.render().renderedTextUnits().units, unitsOfAFreshBuild());
}

// Review Focus 4: a <style> added after 60 KiB of sheets passes the 64 KiB and is not applied; when the first sheet goes,
// it comes in. Each flush patches and equals a build.
WR_TEST(testASheetPastTheCssCapComesInWhenRoomIsMade) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env("<!doctype html><style id=a>p{color:#c00}/*" + std::string(60 * 1024, 'a') + "*/</style><body>"
                  "<p id=p>p</p></body>");
    const auto color = [&] { return env.env().eval("getComputedStyle(document.getElementById('p')).color"); };
    CHECK_EQ(color(), std::string("rgb(204, 0, 0)"));
    const size_t posted = env.env().host().diagnostics.size();
    edit(env, "const s = document.createElement('style'); s.id = 'b'; s.textContent = 'p{color:#0a0}/*' + 'b'.repeat(8 * 1024) +"
              " '*/'; document.body.appendChild(s)");
    CHECK(env.env().host().diagnostics.size() > posted && env.env().host().diagnostics[posted].second == "css");
    CHECK_EQ(color(), std::string("rgb(204, 0, 0)"));
    expectMatchesRebuild(env, "a sheet past the css cap");
    expectCountsOfAFreshBuild(env, "a sheet past the css cap");
    patches(env, byId("a") + ".remove()");
    CHECK_EQ(color(), std::string("rgb(0, 170, 0)"));
    expectCountsOfAFreshBuild(env, "the first sheet gone");
}

// Review Focus 5: a limit kind is posted once each time it is newly reached: crossing posts it, a change past it posts
// nothing, going back under posts nothing, and crossing again posts it again.
WR_TEST(testDiagnosticsPostOncePerHit) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    std::string page = "<!doctype html><body><p id=big class=" + std::string(1048000, 'x') + "></p><p id=p>p</p></body>";
    RenderEnv env(page);
    const auto bytesPosted = [&] {
        size_t n = 0;
        for (const auto& diagnostic : env.env().host().diagnostics) {
            n += diagnostic.second == "bytes" ? 1 : 0;
        }
        return n;
    };
    const uint64_t builds = env.render().buildCount();
    CHECK_EQ(bytesPosted(), size_t(0));
    edit(env, byId("p") + ".append('z'.repeat(1000))");
    CHECK_EQ(bytesPosted(), size_t(1));
    edit(env, byId("p") + ".append('q'.repeat(10))");
    CHECK_EQ(bytesPosted(), size_t(1));
    edit(env, byId("big") + ".className = 'x'");
    CHECK_EQ(bytesPosted(), size_t(1));
    CHECK(env.render().renderLimits().empty());
    edit(env, byId("big") + ".className = 'x'.repeat(1048000)");
    CHECK_EQ(bytesPosted(), size_t(2));
    CHECK_EQ(env.render().buildCount(), builds);
    expectMatchesRebuild(env, "crossing again");
}

// The flush publishes a new tree with changedRects against the previous one, and keeps the fonts (Ruling 19).
WR_TEST(testStructurePatchPublishesChangedRects) {
    RenderEnv env("<!doctype html><body style='height:200px;margin:0'><p id=p>one</p></body>");
    std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
    const size_t fonts = env.host().fontsCreated;
    edit(env, byId("p") + ".after(document.createElement('hr'), 'two')");
    // Before the oracle, whose own tree makes fonts of its own.
    CHECK_EQ(env.host().fontsCreated, fonts);
    CHECK_EQ(env.render().patchCount(), uint64_t(1));
    std::shared_ptr<const wr::LayerTree> after = env.render().layerTree();
    CHECK(after && after != before);
    CHECK(wr_test::findText(*after, "two") != nullptr);
    CHECK(env.render().changedRects().has_value() && !env.render().changedRects()->empty());
    CHECK(wr_test::findText(*before, "two") == nullptr);
    expectMatchesRebuild(env, "hr and text after p");
}

// ---- Fix round 1 (Ruling E19, I2, I3). ----

namespace {

// `rules` `div` rules, the last of which colours, over `divs` divs (then `tail`) in the body.
std::string stepPage(int rules, int divs, const std::string& tail = "") {
    std::string sheet;
    for (int i = 0; i < rules - 1; i++) {
        sheet += "div{margin-left:0}";
    }
    sheet += "div{color:#ff0000} .k{color:#00f}";
    std::string page = "<!doctype html><style>" + sheet + "</style><body id=b>";
    for (int i = 0; i < divs; i++) {
        page += "<div>x</div>";
    }
    return page + tail + "</body>";
}

} // namespace

// Ruling E19: litehtml's 4,000,000 selector steps cut the boot alone; every patch is held to kPatchSelectorSteps. So a
// patch and a fresh build (an uncut one) never cut at different places.
WR_TEST(testSelectorStepParityNearTheCap) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    // Under it, by less than an append would take: the append patches.
    {
        RenderEnv env(stepPage(1000, 3900));
        CHECK(env.render().selectorSteps() < litehtml::document::default_selector_steps);
        patches(env, "for (let i = 0; i < 200; i++) document.body.append(document.createElement('div'))");
    }
    // Far under it: patches; the published count is the build's.
    {
        RenderEnv env(stepPage(1000, 500));
        const int64_t before = env.render().selectorSteps();
        patches(env, "for (let i = 0; i < 10; i++) { const d = document.createElement('div'); d.textContent = 'n'; document.body.append(d); }");
        CHECK(env.render().lastPatchSteps() >= 10 * 1000);
        CHECK_EQ(env.render().selectorSteps(), before);
    }
}

// Twidget edit 84: a boot litehtml's 4,000,000 steps cut is matched again whole, uncut, by its first patch, whatever the
// patch changes (a text matches nothing), so the patched document is a fresh build's, which cuts nowhere; what follows
// patches as anywhere else.
WR_TEST(testACutBootsFirstPatchReplaysUncut) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    const char* scripts[] = {
        "document.body.firstElementChild.firstChild.data = 'y'",
        "document.body.children[7].className = 'k'",
        "const d = document.createElement('div'); d.textContent = 'last'; document.body.append(d)",
    };
    for (const char* script : scripts) {
        RenderEnv env(stepPage(1000, 4099));
        CHECK(env.render().selectorSteps() > litehtml::document::default_selector_steps);
        CHECK(env.render().stepCut());
        patches(env, script);
        CHECK(!env.render().stepCut());
        patches(env, "const d = document.createElement('div'); d.textContent = 'more'; document.body.append(d)");
        patches(env, "document.body.lastElementChild.firstChild.data = 'last of all'");
    }
}

// Ruling E19, Task 8's path: re-matching an element on the largest page that stays under the cap patches, as it does far
// from it.
WR_TEST(testAttributePatchRespectsTheSelectorBudget) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    int low = 3000;
    int high = 4100;
    while (high - low > 1) {
        const int mid = (low + high) / 2;
        RenderEnv probe(stepPage(1000, mid));
        (probe.render().selectorSteps() < litehtml::document::default_selector_steps ? low : high) = mid;
    }
    for (int divs : {low, 100}) {
        RenderEnv env(stepPage(1000, divs));
        CHECK(env.render().selectorSteps() < litehtml::document::default_selector_steps);
        patches(env, "document.body.children[7].className = 'k'");
        CHECK(env.render().lastPatchSteps() > 0);
    }
}

// Review Focus 4: patches never meet a count of the steps patches took before them. A page booting at about 3,000,000 of
// litehtml's 4,000,000 steps takes 20 patches of about 100,000 steps each (a class on a section of 100 divs that a rule
// names in an ancestor position): every one patches, as a rebuild agrees.
WR_TEST(testPatchesNeverMeetACumulativeStepCount) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    std::string sections = "<style>.on div{color:#0a0}</style>";
    for (int s = 0; s < 20; s++) {
        sections += "<section id=s" + std::to_string(s) + ">";
        for (int d = 0; d < 100; d++) {
            sections += "<div>s</div>";
        }
        sections += "</section>";
    }
    RenderEnv env(stepPage(1000, 900, sections));
    const int64_t boot = env.render().selectorSteps();
    CHECK(boot > 2500000 && boot < litehtml::document::default_selector_steps);
    int64_t total = 0;
    for (int s = 0; s < 20; s++) {
        patches(env, "document.getElementById('s" + std::to_string(s) + "').className = 'on'");
        total += env.render().lastPatchSteps();
    }
    CHECK(boot + total > litehtml::document::default_selector_steps);
    CHECK_EQ(env.render().selectorSteps(), boot);
}

// Ruling E19: the reviewer's work probes. A patch's matching was a fresh 4,000,000 steps per inserted root and sheet
// (7.24 s and 5.83 s); now a flush takes at most kPatchSelectorSteps. Each probe's boot is cut by litehtml's 4,000,000,
// and its first patch's uncut replay needs more than kPatchSelectorSteps: the widget stops, frozen on the boot's tree.
WR_TEST(testSelectorStepsAreBounded) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    struct Probe {
        std::string page;
        std::string script;
    };
    std::string deepSheet;
    for (int i = 0; i < 10000; i++) {
        deepSheet += "x div,";
    }
    deepSheet += "x div{color:#f00}";
    std::string deep = "<!doctype html><style>" + deepSheet + "</style><body>";
    for (int i = 0; i < 248; i++) {
        deep += "<div>";
    }
    deep += "<div id=deep></div></body>";
    std::string wideSheet;
    for (int i = 0; i < 15990; i++) {
        wideSheet += "div,";
    }
    wideSheet += "div{color:#ff0000} p+p{color:#000}";
    std::string wide = "<!doctype html><style>" + wideSheet + "</style><body>";
    for (int i = 0; i < 3000; i++) {
        wide += "<div>x</div>";
    }
    wide += "</body>";
    const Probe probes[] = {
        {deep, "document.getElementById('deep').innerHTML = '<div>x</div>'.repeat(300)"},
        {wide, "document.body.append(document.createElement('div'))"},
    };
    for (const Probe& probe : probes) {
        RenderEnv env(probe.page);
        CHECK(env.render().selectorSteps() > litehtml::document::default_selector_steps);
        const std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
        CHECK_EQ(env.env().eval("(() => { " + probe.script + "; })(); 'ok'"), std::string("ok"));
        try {
            env.flush();
        } catch (const wr::Aborted&) {
        }
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Internal);
        CHECK(!env.env().host().diagnostics.empty() &&
              env.env().host().diagnostics.back().second == "a replay cut at its selector-step limit");
        CHECK_EQ(env.render().buildCount(), uint64_t(1));
        CHECK(env.render().layerTree() == before);
    }
}

// Twidget edit 83: only what renders counts. Elements a parent's own append refuses count toward no cap, and a <table>'s
// whitespace asks litehtml's piece cap nothing, so neither moves a cut. (The I2 reviewer's probe: 16,000 table-refused
// divs, then a table of 5,000 directly appended rows.)
WR_TEST(testRefusedElementsCountNothing) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    {
        RenderEnv env("<!doctype html><body><table id=t></table><div id=d></div><p id=after>after</p></body>");
        // 16,000 insertions fill the journal: the setup is a build.
        edit(env, "const t = document.getElementById('t'); for (let i = 0; i < 16000; i++) t.appendChild(document.createElement('div'))");
        expectMatchesRebuild(env, "16,000 refused divs");
        expectCountsOfAFreshBuild(env, "16,000 refused divs");
        patches(env, "const x = document.createElement('table'); for (let i = 0; i < 5000; i++) x.appendChild(document.createElement('tr'));"
                     " document.getElementById('d').append(x)");
        expectCountsOfAFreshBuild(env, "a table of 5,000 refused rows");
        CHECK(wr_test::findText(*env.render().layerTree(), "after") != nullptr);
    }
    {
        // 9,994 pieces, then a <table> whose whitespace makes none: the pieces reach 10,000 and patch.
        std::string words;
        for (int n = 0; n < 4997; n++) {
            words += n ? " w" : "w";
        }
        const std::string page = "<!doctype html><body><p id=p>" + words + "</p><p id=q>a</p><table> <tbody><tr><td></td></tr></tbody></table></body>";
        RenderEnv env(page);
        CHECK_EQ(env.render().document()->text_elements(), 9993 + 1);
        patches(env, "document.getElementById('q').append(' b c')");   // 9,998
        patches(env, "document.getElementById('q').append(' d')");     // 10,000
        CHECK_EQ(env.render().document()->text_elements(), 10000);
        expectCountsOfAFreshBuild(env, "10,000 pieces beside a table's whitespace");
        // The text path counts the same.
        RenderEnv text(page);
        patches(text, "document.getElementById('q').firstChild.data = 'a b c'");
        patches(text, "document.getElementById('q').firstChild.data = 'a b c d'");
        CHECK_EQ(text.render().document()->text_elements(), 10000);
    }
}

// I3: an insertion's place in the render input comes from the first kept sibling with a place there, which a Text that
// made no pieces (whitespace under a <table>) has, apart from its place in litehtml. (The reviewer's probe.)
WR_TEST(testInsertBeforePiecelessWhitespace) {
    RenderEnv env("<!doctype html><body><table id=t>\n<tbody><tr><td>a</td></tr></tbody>\n</table></body>");
    patches(env, "const t = document.getElementById('t'); const c = document.createElement('caption'); c.textContent = 'cap';"
                 " t.insertBefore(c, t.firstChild)");
    CHECK(env.render().renderInput().find("<table id=\"t\"><caption>cap</caption>\n<tbody>") != std::string::npos);
    patches(env, "const t = document.getElementById('t'); const h = document.createElement('thead'); h.innerHTML = '<tr><td>h</td></tr>';"
                 " t.insertBefore(h, t.lastChild)");
    CHECK(env.render().renderInput().find("</tbody><thead><tr><td>h</td></tr></thead>\n</table>") != std::string::npos);
}

// twidget edit 18's table-row fix: a patch that keeps the render tree lays a captioned table out again, and its cells stay
// where a rebuild places them (the random test's caption fixture found it, in the text and the attribute paths).
WR_TEST(testPatchesBesideACaptionedTable) {
    RenderEnv env("<!doctype html><body><table><caption>cap</caption><tbody><tr><td>a</td></tr></tbody></table><p id=p>x</p></body>");
    patches(env, "document.getElementById('p').firstChild.data = 'longer text'");
    patches(env, "document.getElementById('p').className = 'q'");
    patches(env, "document.getElementById('p').firstChild.data = 'x'");
}

// ---- Fix round 2 (Rulings E20, E21). ----

namespace {

// `.a ~ p span` (the left compound walks the siblings of each span's ancestor <p>), `ps` <p>s, and an empty last one.
std::string siblingAncestorPage(int ps, const std::string& extra = "") {
    std::string page = "<!doctype html><style>.a ~ p span{color:#ff0000}" + extra + "</style><body>";
    for (int i = 0; i < ps; i++) {
        page += "<p>x</p>";
    }
    return page + "<p id=t></p></body>";
}

std::string appendSpans(int k) {
    return "const t = document.getElementById('t'); for (let i = 0; i < " + std::to_string(k) +
           "; i++) { const s = document.createElement('span'); s.textContent = 'S'; t.append(s); }";
}

} // namespace

// Spans appended under a <p> whose compound left of a combinator walks an ancestor's siblings (the body's 9,001
// children): the flush patches, as a rebuild agrees.
WR_TEST(testSpansBesideManyAncestorSiblingsPatch) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    for (int k : {100, 400}) {
        RenderEnv env(siblingAncestorPage(9000));
        patches(env, appendSpans(k));
    }
}

// Ruling E19, the reviewer's wparity: 470 spans take the document's matching past 4,000,000 steps. A patch is held to
// kPatchSelectorSteps alone, so it patches and agrees with an uncut fresh build (the spans coloured).
WR_TEST(testSelectorStepParityWithAncestorSiblings) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(siblingAncestorPage(9000, " span{color:#0000ff}"));
    patches(env, appendSpans(470));
    wr::RenderTree fresh(env.ctx(), env.host(), laterBuild(env.options()));
    fresh.build(env.ctx());
    CHECK(fresh.selectorSteps() > litehtml::document::default_selector_steps);
}

// Ruling E19: a patch's matching is bounded by kPatchSelectorSteps. A session cut there (here by the test's cap) stops
// the widget (stopInternally) with litehtml's document patched and never laid out, frozen on the tree published before,
// as a replay cut does (testAReplayCutLeavesNothingToSelect): a structural patch, an attribute, a text beside a class.
WR_TEST(testACutPatchStopsTheWidget) {
    const std::string attributes = "<!doctype html><style>.b{color:#f00} div{margin:1px}</style><body><div id=a class=x>one"
                                   "</div><p id=t>text</p><p id=i title=abc>abc</p></body>";
    struct Cut {
        std::string page;
        std::string script;
        int64_t cap;
    };
    const Cut cuts[] = {
        {siblingAncestorPage(500), appendSpans(50), 1000},
        {attributes, byId("i") + ".setAttribute('title', 'abcdef')", 0},
        {attributes, byId("a") + ".className = 'b'; " + byId("t") + ".firstChild.data = 'changed text here'", 0},
    };
    for (const Cut& cut : cuts) {
        RenderEnv env(cut.page);
        const std::shared_ptr<const wr::LayerTree> before = env.render().layerTree();
        env.render().setPatchStepCapForTesting(cut.cap);
        CHECK_EQ(env.env().eval("(() => { " + cut.script + "; })(); 'ok'"), std::string("ok"));
        // The stop is thrown to the step boundary, which the harness's own flush is.
        try {
            env.flush();
        } catch (const wr::Aborted&) {
        }
        if (env.env().runtime().stopReason() != wr::StopReason::Internal) {
            std::printf("  not stopped (%s): %s\n", env.render().lastPatchRefusal(), cut.script.c_str());
        }
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Internal);
        CHECK_EQ(env.render().buildCount(), uint64_t(1));
        CHECK(env.render().layerTree() == before);
    }
}

namespace {

// The reviewer's pfilter page: a 64 KiB sheet of class rules no element matches, then `extra`, over `divs` divs.
std::string filterPage(const std::string& extra, int divs) {
    std::string sheet;
    for (int n = 0; sheet.size() < 65536 - 120; n++) {
        sheet += ".c" + std::to_string(n) + "{}";
    }
    std::string out = "<!doctype html><style>" + sheet + extra + "</style><body><div id=c></div>";
    for (int i = 0; i < divs; i++) {
        out += "<div class=q></div>";
    }
    return out + "</body>";
}

} // namespace

// Ruling E28: pseudo-elements count against the element cap, and a rebuild hands the budget out in document order, so a
// patch that crosses the cap must not commit what a rebuild would not make. The 4,000 new divs of #c come before the
// 5,000 old ones.
WR_TEST(testPatchPastThePseudoCapMatchesRebuild) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(filterPage("div::before{color:#f00}div::after{color:#f00}", 5000));
    CHECK_EQ(env.env().eval("document.getElementById('c').innerHTML = '<div class=q></div>'.repeat(4000); 'ok'"),
             std::string("ok"));
    env.flush();
    expectMatchesRebuild(env, "4,000 divs patched past the pseudo-element cap");
}

// Ruling E28, attributes: near the cap, class changes that make `.x::after` match, last div first, must match a rebuild.
WR_TEST(testAttributePatchPastThePseudoCapMatchesRebuild) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(filterPage("div::before{color:#f00}.x::after{color:#f00}", 9900));
    CHECK_EQ(env.env().eval("const d = document.querySelectorAll('div.q'); for (let i = d.length - 1; i >= d.length - 300; i--) d[i].setAttribute('class', 'q x'); 'ok'"),
             std::string("ok"));
    env.flush();
    expectMatchesRebuild(env, "class changes past the pseudo-element cap");
}

// Ruling E25, the reviewer's refused, under twidget edit 83: an element a parent's appendChild refuses (a <div> appended
// to a <table>) is in no build and counts nothing, not even its attributes' bytes, so its own change beside structure
// elsewhere patches whatever its size, and no limit is hit.
WR_TEST(testARefusedElementsOwnChangeRendersNothing) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    for (int title : {1000, 200000, 1100000}) {
        RenderEnv env("<!doctype html><body><table id=t><tbody><tr><td>c</td></tr></tbody></table><div id=c></div><p>tail</p>"
                      "</body>");
        patches(env, "const d = document.createElement('div'); d.id = 'x'; " + byId("t") + ".append(d)");
        CHECK(env.render().renderLimits().empty());
        // A datetime: profile 1's text budgets do not count it (a title over 65,536 units is left out: V4 plan, Task 7).
        patches(env, byId("c") + ".append(document.createElement('i')); " + byId("x") + ".setAttribute('datetime', 'y'.repeat(" +
                         std::to_string(title) + "))");
        CHECK(env.render().renderLimits().empty());
        expectCountsOfAFreshBuild(env, "a refused element's datetime");
    }
    // What no build reads beside structure still patches: a <script>'s attribute (Ruling 4), a node made, changed and
    // removed again in the task, and one moved into a template's contents after its change.
    RenderEnv env("<!doctype html><body><div id=c></div><div id=s><script id=sc></script></div>"
                  "<template id=tpl><b>t</b></template></body>");
    patches(env, byId("c") + ".append(document.createElement('i')); " + byId("sc") + ".setAttribute('data-x', 'y')");
    patches(env, "const e = document.createElement('em'); document.body.append(e); e.title = 'gone'; e.remove(); " + byId("c") +
                     ".append('z')");
    patches(env, "const e = document.createElement('em'); document.body.append(e); e.title = 'kept'; " + byId("tpl") +
                     ".content.append(e); " + byId("c") + ".append('w')");
}

