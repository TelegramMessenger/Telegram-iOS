// Structure patched in place (M1c plan, Task 9; Ruling 8; twidget edit 18): a flush whose journal holds a structural
// entry patches the published litehtml document's element tree, and what it publishes is a rebuild's (Review Focus 1),
// across random edits of all three patch paths. What rebuilds instead (a document-level element, a <select>, counters,
// pseudo-element content, a mixed journal, the render limits), that nothing in a template renders, and that a stop while
// planning leaves the published state alone (Review Focus 2).
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <cstdio>
#include <functional>
#include <map>
#include <memory>
#include <random>
#include <string>
#include <tuple>
#include <vector>

#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Support/Errors.h"
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

// `edit`, and the flush rebuilt, for `why` (RenderTree::lastPatchRefusal), and agrees with a rebuild.
void rebuilds(RenderEnv& env, const std::string& script, const std::string& why) {
    const uint64_t builds = env.render().buildCount();
    const uint64_t patched = env.render().patchCount();
    edit(env, script);
    CHECK_EQ(env.render().buildCount(), builds + 1);
    CHECK_EQ(env.render().patchCount(), patched);
    if (env.render().lastPatchRefusal() != why) {
        std::printf("  rebuilt for '%s', not '%s': %s\n", env.render().lastPatchRefusal(), why.c_str(), script.c_str());
    }
    CHECK_EQ(std::string(env.render().lastPatchRefusal()), why);
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

} // namespace

// The `textContent = …` idiom on an element whose only child is a Text (one mapped Text out, one new Text in, nothing
// else under that parent) is the text path's replacement: litehtml keeps its render tree and the flush publishes
// operations, not a Reset, beside an attribute change on another element too. Every other shape is structure.
WR_TEST(testATextSwapIsATextPatch) {
    RenderEnv env("<!doctype html><style>.k{color:#c00}</style><body><p id=c>0</p><div id=m>m</div>"
                  "<div id=e><b>b</b> t</div><p id=f>f</p></body>");
    const uint64_t builds = env.render().buildCount();
    uint64_t resets = env.render().treeRebuildResets();
    auto noReset = [&](const char* what) {
        if (env.render().treeRebuildResets() != resets) {
            std::printf("  a Reset after: %s\n", what);
        }
        CHECK_EQ(env.render().treeRebuildResets(), resets);
        CHECK(!env.render().layerOps().empty() && env.render().layerOps()[0].kind != wr::LayerOp::Reset);
    };
    for (const char* text : {"111", "two words", "3"}) {
        patches(env, byId("c") + ".textContent = '" + text + "'");
        noReset(text);
    }
    patches(env, byId("m") + ".className = 'k'; " + byId("c") + ".textContent = 'beside a class'");
    noReset("beside a class");
    patches(env, byId("c") + ".className = 'k'; " + byId("c") + ".textContent = 'its own class'");
    noReset("its own class");
    patches(env, byId("c") + ".textContent = 'a'; " + byId("f") + ".textContent = 'b'; " + byId("c") + ".firstChild.data = 'c'");
    noReset("two swaps and a data change");
    // An element child replaced, a second Text, the text emptied: structure, which Resets.
    patches(env, byId("e") + ".textContent = 'was an element'");
    CHECK(env.render().treeRebuildResets() == ++resets);
    patches(env, byId("c") + ".append(' more')");
    CHECK(env.render().treeRebuildResets() == ++resets);
    patches(env, byId("c") + ".textContent = 'one again'");
    CHECK(env.render().treeRebuildResets() == ++resets);
    patches(env, byId("c") + ".textContent = ''");
    CHECK(env.render().treeRebuildResets() == ++resets);
    CHECK_EQ(env.render().buildCount(), builds);
    // Beside the parent's own ::before content, which the swap leaves where it is: patched as a data change is.
    RenderEnv before("<!doctype html><style>#c::before{content:'> '}</style><body><p id=c>0</p></body>");
    uint64_t beforeResets = before.render().treeRebuildResets();
    patches(before, byId("c") + ".firstChild.data = 'data'");
    const uint64_t byData = before.render().treeRebuildResets() - beforeResets;
    beforeResets = before.render().treeRebuildResets();
    patches(before, byId("c") + ".textContent = 'after the marker'");
    CHECK_EQ(before.render().treeRebuildResets() - beforeResets, byData);
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
        std::map<std::string, uint64_t> why;
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
        /// Whether the group must patch at least once: :empty makes every child-list change rebuild, and a <q> the edits
        /// insert (the UA sheet's quote marks are ::before content) every text change, so that group checks parity only.
        bool mustPatch = true;
    };
    const std::string base = ".box{padding:2px;border:1px solid #000} .x{color:#c00;font-weight:bold} .y{background:#ff0}"
                             " [hidden]{display:none} li{margin:1px} td{padding:2px} p{margin:2px}";
    const std::string sibling =
        base + " li:nth-child(2n){color:#00f} p:nth-child(2n){background:#eee} .x + .y{color:#0a0} .x ~ span{text-decoration:underline}"
               " li:last-child{border-bottom:2px solid #00f} p:first-child{padding-left:3px}"
               // A compound left of a combinator walks an ancestor's siblings (fix round 2): the many <p>s below.
               " .zz ~ p span{color:#909} p:nth-child(3n of .y) b{color:#090}";
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
    auto pageOf = [](const std::string& sheet, const std::string& filler, const std::string& prefix = std::string()) {
        return "<!doctype html><style>" + sheet + "</style><body style='margin:0'>" + prefix +
               "<div id=a class=box><p class=x>alpha <b>bold</b> text</p><p>beta</p><span class=y>gamma</span></div>"
               "<ul id=l><li>one</li><li class=x>two</li><li>three</li></ul>"
               "<table id=t>\n<caption>cap</caption>\n<thead><tr><td>h1</td></tr></thead>\n"
               "<tbody><tr><td>c1</td><td class=y>c2</td></tr>\n<tr><td>c3</td><td>c4</td></tr></tbody>\n</table>"
               "<pre id=pre>pre  text\n line</pre>"
               "<div id=f><button value=ab>ab</button><button disabled>d</button><button>go</button></div>"
               "<svg width=30 height=30 viewBox='0 0 30 30'><circle cx=15 cy=15 r=10 fill=red></circle></svg>"
               "<template id=tpl><i class=x>tpl one</i><b>tpl two</b></template>"
               "<div id=c class=y>tail</div>" + filler + "</body>";
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
    Group groups[] = {
        {"sibling (positional and sibling selectors)", 1, 5, sibling, ""},
        {"plain", 6, 10, base, ""},
        {"pseudo (q::before content)", 11, 15, base + " q::before{content:'\\00ab'}", ""},
        {"near the text-piece cap", 16, 16, base, pieces},
        {"near the selector-step budget", 17, 17, stepSheet, steps},
        {"near the form-control limit", 18, 18, base, controls},
        {"near litehtml's element cap (refused elements)", 19, 19, base, ""},
        {"near the byte budget", 20, 20, base, bytes},
        {"near the text budget", 21, 21, base, text},
        // Fidelity plan, Task 2: :empty (a parent's match follows its children) and :lang() (an ancestor's attribute),
        // with an element in a lang="ru" subtree for the edits to move in and out.
        {":empty and :lang()", 22, 24, base + " :empty{outline:1px solid #f0f} span:empty{padding:1px} :lang(ru) b{color:#0a0}"
                                    " p:not(:empty){margin:3px}", ""},
        {"Text swaps (textContent on a Text-only element, beside class, style and data)", 25, 27,
         base + " q::before{content:'\\00ab'}", ""},
    };
    groups[3].limit = "text-pieces";
    groups[4].limit = "the selector-step budget";
    groups[5].limit = "form-controls";
    groups[6].limit = "elements";
    groups[7].limit = "bytes";
    groups[8].limit = "text-budget";
    groups[9].prefix = "<div lang=ru id=ru><b>ru</b><span></span></div>";
    groups[9].mustPatch = false;
    groups[10].swaps = true;
    // Divs the <table> refuses, up to 11 short of litehtml's 20,000 with the elements the page renders (all but the
    // <template>): litehtml counts each refused one, the maps none (I2). The seed's insertions are tables of refused rows
    // (make(13): one element linked, two refused), so a build's count crosses the cap before the linked count the fork
    // itself checks does.
    groups[6].setup = "const t = document.getElementById('filler'); const n = 19989 - (document.getElementsByTagName('*').length - 1);"
                      " for (let i = 0; i < n; i++) t.appendChild(document.createElement('div'))";
    groups[6].structural = true;
    // Many siblings for an ancestor (Ruling E20.4): a section of 150 <p>s, edited like the rest.
    {
        std::string many = "<section id=many>";
        for (int n = 0; n < 150; n++) {
            many += n % 7 ? "<p>p <span>s</span></p>" : "<p class=y>p <b>b</b></p>";
        }
        groups[0].prefix = many + "</section>";
    }
    groups[6].prefix = "<table id=filler></table>";
    const std::string helpers = R"JS(
globalThis.__edit = (() => {
  const tpl = document.getElementById('tpl');
  const excluded = n => n.id === 'filler' || n.id === 'filler2' || n.id === 'inputs' || n.localName === 'template';
  function walk(root, out) {
    for (let n = root.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 1 && excluded(n)) continue;
      if (n.nodeType !== 1 && n.nodeType !== 3) continue;
      out.push(n);
      if (n.nodeType === 1) walk(n, out);
    }
    return out;
  }
  const nodes = () => walk(document.body, []);
  const elements = () => nodes().filter(n => n.nodeType === 1);
  const containers = () => [document.body].concat(elements());
  const texts = () => nodes().filter(n => n.nodeType === 3);
  const pick = (list, i) => list.length ? list[i % list.length] : null;
  function el(tag, attrs, kids) {
    const e = document.createElement(tag);
    for (const k in attrs) e.setAttribute(k, attrs[k]);
    for (const c of kids) e.append(c);
    return e;
  }
  function make(k) {
    switch (k % 16) {
      case 0: return document.createTextNode('new text');
      case 1: return el('p', {class: 'x'}, ['para ', el('b', {}, ['in'])]);
      case 2: return el('span', {class: 'y'}, ['sp']);
      case 3: return el('li', {}, ['item']);
      case 4: return el('div', {class: 'box'}, [el('p', {}, ['inner']), el('span', {}, ['s'])]);
      case 5: return el('button', {value: 'zz'}, ['zz']);
      case 6: return el('b', {}, ['b']);
      case 7: return el('tr', {}, [el('td', {}, ['r1']), el('td', {class: 'y'}, ['r2'])]);
      case 8: return el('q', {}, ['quote']);
      case 9: {
        const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        s.setAttribute('width', '10'); s.setAttribute('height', '10');
        const r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
        r.setAttribute('width', '5'); r.setAttribute('height', '5'); r.setAttribute('fill', 'blue');
        s.append(r);
        return s;
      }
      case 10: return el('pre', {}, ['p  re\n x']);
      // Tables as the parser makes them (whitespace a <table> refuses, row groups, a caption) and as script can (rows
      // and a div straight under a <table>, which its appendChild refuses), and the parts that go into one.
      case 12: return el('table', {}, ['\n', el('caption', {}, ['cap']), '\n', el('thead', {}, [el('tr', {}, [el('td', {}, ['h'])])]),
                                       el('tbody', {}, [el('tr', {}, [el('td', {}, ['b'])])]), '\n']);
      case 13: return el('table', {}, [el('tr', {}, [el('td', {}, ['r'])]), el('div', {}, ['refused div']), ' ']);
      case 14: return el('tbody', {}, ['\n', el('tr', {}, [el('td', {class: 'y'}, ['tb'])])]);
      case 15: return el('caption', {}, ['c']);
      default: return document.createTextNode(' ');
    }
  }
  const words = ['', 'a', 'two words', 'three little words', 'x & <y>', '  spaced  out  ', 'longer text that wraps around the line'];
  const htmls = ['', '<b>b</b> text', '<p class=x>p</p><span class=y>s</span>', '<li>l1</li><li class=x>l2</li>', 'plain',
                 '<i>i</i><input value=q>', '<q>q</q>'];
  const classes = ['', 'x', 'y', 'x y', 'box', 'z'];
  const styles = ['', 'color:#090', 'padding:3px', 'display:none', 'font-size:20px', 'background:#ccc;margin:2px'];
  return (kind, a, b, c) => {
    try {
      switch (kind) {
        case 0: { const p = pick(containers(), a); p.append(make(b)); return 'append'; }
        case 1: { const p = pick(containers(), a); p.insertBefore(make(b), p.childNodes[c % (p.childNodes.length + 1)] || null); return 'insertBefore'; }
        case 2: { const n = pick(nodes(), a); if (n) n.remove(); return 'remove'; }
        case 3: {
          const n = pick(nodes(), a), p = pick(containers(), b);
          if (n) p.insertBefore(n, p.childNodes[c % (p.childNodes.length + 1)] || null);
          return 'move';
        }
        case 4: { const e = pick(elements(), a); if (e) e.textContent = words[b % words.length]; return 'textContent'; }
        case 5: { const e = pick(elements(), a); if (e) e.innerHTML = htmls[b % htmls.length]; return 'innerHTML'; }
        case 6: { const e = pick(elements(), a); if (e) e.setAttribute('class', classes[b % classes.length]); return 'class'; }
        case 7: { const e = pick(elements(), a); if (e) e.setAttribute('style', styles[b % styles.length]); return 'style'; }
        case 8: {
          const e = pick(elements(), a);
          if (e) { if (e.hasAttribute('hidden')) e.removeAttribute('hidden'); else e.setAttribute('hidden', ''); }
          return 'hidden';
        }
        case 9: { const t = pick(texts(), a); if (t) t.data = words[b % words.length]; return 'data'; }
        // textContent on an element whose only child is a Text: the text path's swap (RenderTree::textSwaps).
        case 20: {
          const e = pick(elements().filter(e => e.childNodes.length === 1 && e.firstChild.nodeType === 3), a);
          if (e) e.textContent = words[b % words.length];
          return 'swap';
        }
        case 12: {
          // A row group or a caption into a table, before one of its children (whitespace included), or a refused subtree.
          const tables = elements().filter(e => e.localName === 'table');
          const t = pick(tables, a);
          if (!t) return 'table insert (no table)';
          const part = [make(14), make(15), el('thead', {}, [el('tr', {}, [el('td', {}, ['th'])])]), make(13)][b % 4];
          t.insertBefore(part, t.childNodes[c % (t.childNodes.length + 1)] || null);
          return 'table insert';
        }
        case 10: tpl.content.append(make(b)); return 'template append';
        default: {
          const n = tpl.content.firstChild, p = pick(containers(), a);
          if (n) p.append(n);
          return 'template move out';
        }
      }
    } catch (e) {
      return 'threw ' + e.name;
    }
  };
})(); 'ok'
)JS";
    for (Group& group : groups) {
        for (int seed = group.firstSeed; seed <= group.lastSeed; seed++) {
            RenderEnv env(pageOf(group.sheet, group.filler, group.prefix));
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
            wr::RenderTree plain(env.ctx(), env.host(), production);
            plain.rebuild(env.ctx());
            std::mt19937 rng{uint32_t(seed)};
            int edits = 0;
            bool reported = false;
            while (edits < 200) {
                const int batch = 1 + int(rng() % 5);
                std::string done;
                for (int k = 0; k < batch && edits < 200; k++, edits++) {
                    // Insertion-heavy (append, insertBefore, and remove, move, textContent), and every insertion a table of
                    // refused rows (make(13)), so the seed reaches its cap through the refused elements.
                    static const uint32_t kStructuralKinds[] = {0, 1, 0, 1, 2, 3, 4};
                    static const uint32_t kSwapKinds[] = {20, 20, 20, 6, 7, 9, 4};
                    const uint32_t drawn = uint32_t(rng() % 13);
                    const uint32_t kind = group.structural ? kStructuralKinds[drawn % 7]
                                          : group.swaps    ? kSwapKinds[drawn % 7]
                                                           : drawn,
                                   a = uint32_t(rng() % 1000);
                    uint32_t b = uint32_t(rng() % 1000);
                    const uint32_t c = uint32_t(rng() % 1000);
                    if (group.structural && kind <= 1) {
                        b = 13 + 16 * (b % 60);
                    }
                    const std::string call = "__edit(" + std::to_string(kind) + ", " + std::to_string(a) + ", " +
                                             std::to_string(b) + ", " + std::to_string(c) + ")";
                    done += (done.empty() ? "" : "; ") + env.env().eval(call) + " " + call;
                }
                const uint64_t builds = env.render().buildCount();
                const uint64_t patchedBefore = env.render().patchCount();
                const uint64_t swappedBefore = env.render().swappedTexts();
                const uint64_t plainPatches = plain.patchCount();
                const size_t posted = env.env().host().diagnostics.size();
                env.flush();
                plain.flush(env.ctx());
                // The same choice with and without the render input.
                CHECK_EQ(plain.patchCount() - plainPatches, env.render().patchCount() - patchedBefore);
                std::string path = "clean";
                if (env.render().patchCount() != patchedBefore) {
                    path = "patched";
                    group.patched++;
                    group.swapped += env.render().swappedTexts() - swappedBefore;
                    // Ruling E19: the plan's bound held the patch's steps.
                    CHECK(env.render().lastPatchSteps() <= env.render().lastPatchStepBound());
                } else if (env.render().buildCount() != builds) {
                    path = std::string("rebuilt: ") + env.render().lastPatchRefusal();
                    group.rebuilt++;
                    group.why[env.render().lastPatchRefusal()]++;
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
                wr::RenderTree fresh(env.ctx(), env.host(), env.render().options());
                fresh.rebuild(env.ctx());
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
                const auto& [layout, input, layer] = rebuilt;
                const bool plainSame = plain.layoutDump() == layout && plain.layerTree() && plain.layerTree()->dump() == layer &&
                                       plain.renderInput().empty();
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
        std::printf("  %s: %llu flushes, %llu patched (%.0f%%; %llu Texts swapped), %llu rebuilt, %llu clean\n", group.name,
                    (unsigned long long)group.flushes, (unsigned long long)group.patched,
                    group.flushes ? 100.0 * double(group.patched) / double(group.flushes) : 0.0,
                    (unsigned long long)group.swapped, (unsigned long long)group.rebuilt, (unsigned long long)group.clean);
        for (const auto& [why, n] : group.why) {
            std::printf("    rebuilt %llu: %s\n", (unsigned long long)n, why.c_str());
        }
    }
    // Every group patched something and rebuilt something (random batches mix a kept node's own change with
    // structure in every group), and each near-limit group reached its limit at least once.
    for (const Group& group : groups) {
        CHECK(group.patched > 0 || !group.mustPatch);
        CHECK(group.rebuilt > 0);
        CHECK(!group.swaps || group.swapped > 0);
        if (!group.limit.empty() && !group.reached) {
            std::printf("  %s never reached %s\n", group.name, group.limit.c_str());
        }
        CHECK(group.limit.empty() || group.reached);
    }
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

// With sibling combinators or positional pseudo-classes, a dirty parent's children are all built again
// (document::replace_children): what each matches follows the new order.
WR_TEST(testStructureUnderSiblingSelectors) {
    RenderEnv env("<!doctype html><style>li:nth-child(2n){color:#f00;background:#eee} li + li{margin-top:3px}"
                  " .x ~ li{font-weight:bold} li:last-child{background:#0f0} li:first-child span{color:#00f}</style>"
                  "<body><ul id=l><li><span>a</span></li><li class=x>b</li><li>c</li></ul><p id=p>p</p></body>");
    patches(env, byId("l") + ".prepend(document.createElement('li'))");
    patches(env, byId("l") + ".append(" + byId("l") + ".children[1])");
    patches(env, byId("l") + ".lastElementChild.remove()");
    patches(env, byId("l") + ".insertBefore(document.createElement('li'), " + byId("l") + ".children[2])");
    patches(env, byId("p") + ".append(" + byId("l") + ".firstElementChild)");
    // An attribute change there is the attribute path's to refuse (selector_scope), and it rebuilds.
    rebuilds(env, byId("l") + ".lastElementChild.className = 'x'", "refused by can_set_element_attributes");
}

// What the fork or the plan refuses rebuilds, and agrees with a rebuild.
WR_TEST(testStructureFallsBack) {
    RenderEnv env("<!doctype html><style>p{color:#333}</style><body><p id=p>text</p><select id=s><option>one</option></select>"
                  "<table id=t><tbody><tr><td>c</td></tr></tbody></table><div id=d>d</div><svg id=g width=20 height=20></svg>"
                  "<button id=b>go</button></body>");
    rebuilds(env, "const s = document.createElement('style'); s.textContent = 'p{color:red}'; document.body.append(s)",
             "a render limit in a built subtree");
    rebuilds(env, "document.querySelector('style').append('div{color:blue}')", "a <style>'s children");
    // A Text-only journal is the text path's, which leaves a <style>'s (unmapped) Text to the rebuild.
    rebuilds(env, "document.querySelector('style').firstChild.data = 'p{color:green}'", "an unmapped or empty Text");
    rebuilds(env, "document.querySelector('style').firstChild.data = 'p{color:#111}'; " + byId("d") + ".append('z')",
             "a <style>'s text");
    // A <select> is dropped by profile 1 (V4 plan, Task 4): what happens inside it renders nothing, and removing it or
    // inserting one removes or inserts nothing the build has.
    rendersNothing(env, byId("s") + ".append(document.createElement('option'))");
    rendersNothing(env, byId("s") + ".firstElementChild.append(' more')");
    rendersNothing(env, byId("s") + ".remove()");
    rendersNothing(env, "const d = document.createElement('div'); d.append(document.createElement('select')); document.body.append(d)");
    rebuilds(env, byId("t") + ".append(document.createElement('tr'))", "refused by can_insert_subtree");
    rebuilds(env, byId("g") + ".append(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))", "refused by can_insert_subtree");
    rebuilds(env, byId("b") + ".append(document.createElement('b'))", "refused by can_insert_subtree");
    // A kept node's own change beside structure: the mixed journal rebuilds.
    rebuilds(env, byId("p") + ".firstChild.data = 'changed'; " + byId("d") + ".append('x')", "mixed: a kept node's own change");
    rebuilds(env, byId("d") + ".className = 'k'; " + byId("d") + ".append('y')", "mixed: a kept node's own change");
    // The document element replaced.
    rebuilds(env, "const h = document.documentElement; h.remove(); document.append(h)", "the document's children");
    // And a plain change still patches afterwards.
    patches(env, byId("d") + ".append(document.createElement('br'), 'after')");
}

WR_TEST(testStructureRebuildsUnderCountersAndPseudoContent) {
    {
        RenderEnv env("<!doctype html><style>li{counter-increment:n}</style><body><ul id=l><li>a</li></ul></body>");
        rebuilds(env, byId("l") + ".append(document.createElement('li'))", "refused by can_insert_subtree");
        rebuilds(env, byId("l") + ".firstElementChild.remove()", "refused by can_remove_subtree");
    }
    {
        RenderEnv env("<!doctype html><style>q::before{content:'\\00ab'}</style><body><p id=p>p</p></body>");
        patches(env, byId("p") + ".append(document.createElement('b'))");
        rebuilds(env, byId("p") + ".append(document.createElement('q'))", "refused by can_insert_subtree");
        rebuilds(env, byId("p") + ".append('x')", "pseudo-element content");
        rebuilds(env, "document.querySelector('q').remove()", "pseudo-element content");
        patches(env, byId("p") + ".append('y')");
    }
}

// The render limits decide what a build leaves out, so a change that would cross one rebuilds (and the rebuild posts
// it), and a build that hit one is never patched.
WR_TEST(testStructurePatchRespectsLimits) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    {
        // The byte budget: 1,048,000 bytes of a class (profile 1's text budgets do not count it: V4 plan, Task 7), then
        // 1,000 more of text.
        std::string page = "<!doctype html><body><p id=big class=" + std::string(1048000, 'x') + "></p><p id=p>p</p></body>";
        RenderEnv env(page);
        CHECK(env.env().host().diagnostics.empty());
        patches(env, byId("p") + ".append('y'.repeat(300))");
        rebuilds(env, byId("p") + ".append('z'.repeat(1000))", "a render limit in a built subtree");
        CHECK(!env.env().host().diagnostics.empty() && env.env().host().diagnostics.back().second == "bytes");
        rebuilds(env, byId("p") + ".append('w')", "a rebuild pending, no build, or a limit hit");
        rebuilds(env, byId("big") + ".remove()", "a rebuild pending, no build, or a limit hit");
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
        rebuilds(env, byId("d") + ".append(document.createElement('button'), document.createElement('button'))",
                 "a render limit in a built subtree");
        rebuilds(env, byId("d") + ".lastElementChild.remove()", "a rebuild pending, no build, or a limit hit");
        patches(env, byId("d") + ".firstElementChild.remove()");
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
        // 6 more pass the cap: the rebuild cuts them, and posts it.
        rebuilds(env, byId("p") + ".append(' 5 6 7')", "refused by can_insert_subtree");
        CHECK(!env.env().host().diagnostics.empty() && env.env().host().diagnostics.back().second == "text-pieces");
        CHECK_EQ(env.render().document()->text_elements(), 10000);
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
        rebuilds(env, "let e = " + byId("deep") + "; for (let i = 0; i < 5; i++) { const c = document.createElement('i'); e.append(c); e = c; }",
                 "a render limit in a built subtree");
    }
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

// Ruling E19: the reviewer's parity probe. litehtml's 4,000,000 selector steps are one budget for the whole build; a
// patch whose matching could take the document past them rebuilds, so a patch and a rebuild never cut at different places.
WR_TEST(testSelectorStepParityNearTheCap) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    // Past the cap: the build was cut, and any patch that matches rebuilds (and agrees: the appended div uncoloured).
    {
        RenderEnv env(stepPage(1000, 4099));
        CHECK(env.render().selectorSteps() > litehtml::document::default_selector_steps);
        rebuilds(env, "const d = document.createElement('div'); d.textContent = 'last'; document.body.append(d)",
                 "the selector-step budget");
        // A text matches nothing, so it still patches.
        patches(env, "document.body.lastElementChild.firstChild.data = 'last of all'");
    }
    // Under it, by less than an append would take: rebuilds too.
    {
        RenderEnv env(stepPage(1000, 3900));
        CHECK(env.render().selectorSteps() < litehtml::document::default_selector_steps);
        rebuilds(env, "for (let i = 0; i < 200; i++) document.body.append(document.createElement('div'))", "the selector-step budget");
    }
    // Far under it: patches, within its bound, and the published count follows.
    {
        RenderEnv env(stepPage(1000, 500));
        const int64_t before = env.render().selectorSteps();
        patches(env, "for (let i = 0; i < 10; i++) { const d = document.createElement('div'); d.textContent = 'n'; document.body.append(d); }");
        CHECK(env.render().lastPatchSteps() >= 10 * 1000);
        CHECK(env.render().lastPatchSteps() <= env.render().lastPatchStepBound());
        CHECK_EQ(env.render().selectorSteps(), before + env.render().lastPatchSteps());
    }
}

// Ruling E19, Task 8's path: re-matching an element whose steps could pass the cap rebuilds. The page is the largest that
// stays under the cap, so one div's re-match does not fit.
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
    RenderEnv env(stepPage(1000, low));
    CHECK(env.render().selectorSteps() < litehtml::document::default_selector_steps);
    rebuilds(env, "document.body.children[7].className = 'k'", "the selector-step budget");
    // Far from it, the same change patches within its bound.
    RenderEnv small(stepPage(1000, 100));
    patches(small, "document.body.children[7].className = 'k'");
    CHECK(small.render().lastPatchSteps() > 0 && small.render().lastPatchSteps() <= small.render().lastPatchStepBound());
}

// Ruling E19: the reviewer's work probes. A patch's matching was a fresh 4,000,000 steps per inserted root and sheet
// (7.24 s and 5.83 s); now the flush takes at most the one budget a build takes.
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
        CHECK_EQ(env.env().eval("(() => { " + probe.script + "; })(); 'ok'"), std::string("ok"));
        const uint64_t builds = env.render().buildCount();
        env.flush();
        CHECK_EQ(std::string(env.render().lastPatchRefusal()), std::string("the selector-step budget"));
        CHECK_EQ(env.render().buildCount(), builds + 1);
        // litehtml's budget: the steps performed stop at it (past it a test is refused, and still counted, which is how
        // the cut shows).
        CHECK(env.render().selectorSteps() > litehtml::document::default_selector_steps);
        expectMatchesRebuild(env, probe.script);
    }
}

// I2: a build counts every element it creates against litehtml's 20,000, the ones a parent's own appendChild then refuses
// included, and asks the piece cap for every piece a <table> then refuses. A patch counts them as a build does, or
// rebuilds. (The reviewer's probe: 16,000 table-refused divs, then a table of 5,000 directly appended rows.)
WR_TEST(testRefusedElementsCountAsABuildCounts) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    {
        RenderEnv env("<!doctype html><body><table id=t></table><div id=d></div><p id=after>after</p></body>");
        edit(env, "const t = document.getElementById('t'); for (let i = 0; i < 16000; i++) t.appendChild(document.createElement('div'))");
        expectMatchesRebuild(env, "16,000 refused divs");
        // Under the cap with them: patches.
        patches(env, "const x = document.createElement('table'); for (let i = 0; i < 1000; i++) x.appendChild(document.createElement('tr'));"
                     " document.getElementById('d').append(x)");
        // Past it: rebuilds, and the rebuild posts the cap and leaves out what follows.
        const size_t posted = env.env().host().diagnostics.size();
        rebuilds(env, "const x = document.createElement('table'); for (let i = 0; i < 5000; i++) x.appendChild(document.createElement('tr'));"
                      " document.getElementById('d').append(x)",
                 "litehtml's element cap with refused elements");
        CHECK(env.env().host().diagnostics.size() > posted && env.env().host().diagnostics.back().second == "elements");
        CHECK(wr_test::findText(*env.render().layerTree(), "after") == nullptr);
    }
    {
        // 9,994 pieces, then a <table> whose whitespace a build asks the cap for last: at 10,000 that ask fails.
        std::string words;
        for (int n = 0; n < 4997; n++) {
            words += n ? " w" : "w";
        }
        const std::string page = "<!doctype html><body><p id=p>" + words + "</p><p id=q>a</p><table> <tbody><tr><td></td></tr></tbody></table></body>";
        RenderEnv env(page);
        CHECK_EQ(env.render().document()->text_elements(), 9993 + 1);
        patches(env, "document.getElementById('q').append(' b c')");   // 9,998
        rebuilds(env, "document.getElementById('q').append(' d')", "the text-piece cap beside refused pieces");   // 10,000
        CHECK(!env.env().host().diagnostics.empty() && env.env().host().diagnostics.back().second == "text-pieces");
        // The text path asks the same.
        RenderEnv text(page);
        patches(text, "document.getElementById('q').firstChild.data = 'a b c'");
        rebuilds(text, "document.getElementById('q').firstChild.data = 'a b c d'", "the text-piece cap beside refused pieces");
        // Without a refused piece, the same 10,000 patches.
        RenderEnv plain("<!doctype html><body><p id=p>" + words + "</p><p id=q>a</p><table><tbody><tr><td></td></tr></tbody></table></body>");
        patches(plain, "document.getElementById('q').append(' b c d')");
        CHECK_EQ(plain.render().document()->text_elements(), 10000);
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

// Ruling E20.4, the reviewer's wbound: the bound sees the siblings an ancestor's compound walks (the <p>'s, the body's
// 9,001 children), so it holds the patch's steps; and whatever the flush does, it equals a rebuild.
WR_TEST(testSelectorStepBoundSeesAncestorSiblings) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    for (int k : {100, 400}) {
        RenderEnv env(siblingAncestorPage(9000));
        const uint64_t patched = env.render().patchCount();
        edit(env, appendSpans(k));
        if (env.render().patchCount() > patched) {
            CHECK(env.render().lastPatchSteps() <= env.render().lastPatchStepBound());
        }
        expectMatchesRebuild(env, "spans under a <p> with 9,000 siblings, k=" + std::to_string(k));
    }
}

// Ruling E20, the reviewer's wparity: 470 spans take the document past 4,000,000 steps, where a fresh build is cut and
// leaves spans uncoloured; the flush agrees with it (the bound refuses the patch, or a cut session is abandoned).
WR_TEST(testSelectorStepParityWithAncestorSiblings) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    RenderEnv env(siblingAncestorPage(9000, " span{color:#0000ff}"));
    edit(env, appendSpans(470));
    expectMatchesRebuild(env, "470 spans past the step budget");
    wr::RenderTree fresh(env.ctx(), env.host(), env.options());
    fresh.rebuild(env.ctx());
    CHECK(fresh.selectorSteps() > litehtml::document::default_selector_steps);
    CHECK_EQ(env.render().selectorSteps() > litehtml::document::default_selector_steps, true);
}

// Ruling E20.1 and E20.3: a patch whose matching is cut after it changed the document (here by the test's cap, where the
// bound said it fits) is abandoned, and the same flush rebuilds: no std::abort, and the published state is a rebuild's.
WR_TEST(testCutPatchIsReplacedByARebuild) {
    RenderEnv env(siblingAncestorPage(500));
    const uint64_t builds = env.render().buildCount();
    const uint64_t patched = env.render().patchCount();
    env.render().setPatchStepCapForTesting(1000);
    edit(env, appendSpans(50));
    CHECK_EQ(std::string(env.render().lastPatchRefusal()), std::string("abandoned: the selector-step budget"));
    CHECK_EQ(env.render().buildCount(), builds + 1);
    CHECK_EQ(env.render().patchCount(), patched);
    CHECK_EQ(env.render().journalNodes(), size_t(0));
    expectMatchesRebuild(env, "an abandoned patch");
    // A text patch's session matches nothing, so it is never cut.
    patches(env, "document.querySelector('span').firstChild.data = 'T'");
    env.render().setPatchStepCapForTesting(INT64_MAX);
    patches(env, appendSpans(5));
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

// Ruling E25, the reviewer's refused: an element a parent's appendChild refuses (a <div> appended to a <table>) is in no
// map, yet a build scans and byte-counts its attributes. Its own change beside structure elsewhere once patched, and with
// a 1,100,000-character title the rebuild hits `bytes` and stops its walk where the patch did not, so the patched layout
// and input differed from a rebuild's. An own change on a node the structure path finds unmapped now rebuilds, unless the
// node is outside the main document or under (or is) an element Ruling 4 leaves out, which no build reads.
WR_TEST(testAnUnmappedNodesOwnChangeRebuilds) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    for (int title : {1000, 200000, 1100000}) {
        RenderEnv env("<!doctype html><body><table id=t><tbody><tr><td>c</td></tr></tbody></table><div id=c></div><p>tail</p>"
                      "</body>");
        rebuilds(env, "const d = document.createElement('div'); d.id = 'x'; " + byId("t") + ".append(d)",
                 "refused by can_insert_subtree");
        CHECK(env.render().renderLimits().empty());
        // A datetime: profile 1's text budgets do not count it (a title over 65,536 units is left out: V4 plan, Task 7).
        rebuilds(env, byId("c") + ".append(document.createElement('i')); " + byId("x") + ".setAttribute('datetime', 'y'.repeat(" +
                          std::to_string(title) + "))",
                 "an unmapped node's own change");
        // The limits too are a fresh build's: `bytes` for the longest title.
        wr::RenderTree fresh(env.ctx(), env.host(), env.options());
        fresh.rebuild(env.ctx());
        CHECK(env.render().renderLimits() == fresh.renderLimits());
        CHECK_EQ(env.render().renderLimits().size(), size_t(title > 1000000 ? 1 : 0));
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

// Ruling E22.5, the reviewer's pabandon: a text-and-attribute patch whose re-match is cut (the test's cap at 0) is
// abandoned, and the same flush rebuilds: the journal is clean and the published state a rebuild's; so is an attribute
// alone (profile 1 drops the <input> this once used, V4 plan, Task 4).
WR_TEST(testCutAttributePatchIsReplacedByARebuild) {
    RenderEnv env("<!doctype html><style>.b{color:#f00} div{margin:1px}</style><body><div id=a class=x>one</div>"
                  "<p id=t>text</p><p id=i title=abc>abc</p></body>");
    env.render().setPatchStepCapForTesting(0);
    auto abandoned = [&](const std::string& script) {
        const uint64_t builds = env.render().buildCount();
        const uint64_t patched = env.render().patchCount();
        edit(env, script);
        CHECK_EQ(std::string(env.render().lastPatchRefusal()), std::string("abandoned: the selector-step budget"));
        CHECK_EQ(env.render().buildCount(), builds + 1);
        CHECK_EQ(env.render().patchCount(), patched);
        CHECK_EQ(env.render().journalNodes(), size_t(0));
        expectMatchesRebuild(env, script);
    };
    abandoned(byId("a") + ".className = 'b'; " + byId("t") + ".firstChild.data = 'changed text here'");
    abandoned(byId("i") + ".setAttribute('title', 'abcdef')");
    // A text alone matches nothing: never cut.
    patches(env, byId("t") + ".firstChild.data = 'again'");
}

