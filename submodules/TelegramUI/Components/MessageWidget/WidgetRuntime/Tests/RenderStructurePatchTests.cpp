// Structure patched in place (M1c plan, Task 9; Ruling 8; twidget edit 18): a flush whose journal holds a structural
// entry patches the published litehtml document's element tree, and what it publishes is a rebuild's (Review Focus 1),
// across random edits of all three patch paths. What rebuilds instead (a document-level element, a <select>, counters,
// pseudo-element content, a mixed journal, the render limits), that nothing in a template renders, and that a stop while
// planning leaves the published state alone (Review Focus 2).
#include <algorithm>
#include <cstdint>
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

// Ruling E22: what `tree` holds back for rebuilding its document, without the steps (RenderTree::buildCharge).
uint64_t estimateWithoutSteps(const wr::RenderTree& tree) {
    return tree.buildCharge() - tree.buildChargeParts().steps;
}

// What `fresh`'s build of the DOM was charged without its steps, measured from `before`.
uint64_t chargedWithoutSteps(JSRuntime* rt, uint64_t before, const wr::RenderTree& fresh) {
    const int64_t steps = std::min(fresh.selectorSteps(), litehtml::document::default_selector_steps);
    return JS_GetWorkUnits(rt) - before - uint64_t(steps) * wr::work::kSimpleSelectorTest;
}

// A second tree's rebuild of the DOM as it now is (the published one untouched), without its steps.
uint64_t rebuildChargeWithoutSteps(RenderEnv& env) {
    JSRuntime* rt = env.env().runtime().jsRuntime();
    wr::RenderTree fresh(env.ctx(), env.host(), env.options());
    const uint64_t before = JS_GetWorkUnits(rt);
    fresh.rebuild(env.ctx());
    return chargedWithoutSteps(rt, before, fresh);
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
        std::map<std::string, uint64_t> why;
        /// The limit a near-limit group must reach at least once: a render-limit kind a build posts, or a refusal.
        std::string limit;
        bool reached = false;
        /// Script run after the boot, before the first edit (what the parser would not build: divs under a <table>).
        std::string setup;
        /// Edits of the structural kinds only (and the table insert): no journal is mixed, so the flush that first
        /// crosses the limit is a patch's to refuse.
        bool structural = false;
        /// What goes first in the body (a build's cut then drops what follows it).
        std::string prefix;
    };
    const std::string base = ".box{padding:2px;border:1px solid #000} .x{color:#c00;font-weight:bold} .y{background:#ff0}"
                             " [hidden]{display:none} li{margin:1px} td{padding:2px} p{margin:2px}";
    const std::string sibling =
        base + " li:nth-child(2n){color:#00f} p:nth-child(2n){background:#eee} .x + .y{color:#0a0} .x ~ span{text-decoration:underline}"
               " li:last-child{border-bottom:2px solid #00f} p:first-child{padding-left:3px}"
               // A compound left of a combinator walks an ancestor's siblings (fix round 2): the many <p>s below.
               " .zz ~ p span{color:#909} p:nth-child(3n of .y) b{color:#090}";
    // The fixture's three controls and 253 more: 256, so the next one crosses the limit (Ruling E6).
    std::string controls = "<div id=inputs>";
    for (int n = 0; n < 253; n++) {
        controls += "<input value=i>";
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
               "<div id=f><input value=ab><input type=checkbox checked><button>go</button></div>"
               "<svg width=30 height=30 viewBox='0 0 30 30'><circle cx=15 cy=15 r=10 fill=red></circle></svg>"
               "<template id=tpl><i class=x>tpl one</i><b>tpl two</b></template>"
               "<div id=c class=y>tail</div>" + filler + "</body>";
    };
    std::string bytes;
    {
        RenderEnv probe(pageOf(base, "<p id=filler></p>"));
        const size_t room = wr::kMaxRenderBytes - size_t(probe.render().renderBytes()) - 40;
        bytes = "<p id=filler>";
        for (size_t n = 0; n + 1000 <= room; n += 1000) {
            bytes += std::string(999, 'x') + " ";
        }
        bytes += std::string(room % 1000, 'x') + "</p>";
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
    };
    groups[3].limit = "text-pieces";
    groups[4].limit = "the selector-step budget";
    groups[5].limit = "form-controls";
    groups[6].limit = "elements";
    groups[7].limit = "bytes";
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
      case 5: return el('input', {value: 'zz'}, []);
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
            wr::RenderOptions production = env.options();
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
                    const uint32_t drawn = uint32_t(rng() % 13);
                    const uint32_t kind = group.structural ? kStructuralKinds[drawn % 7] : drawn, a = uint32_t(rng() % 1000);
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
                wr::RenderTree fresh(env.ctx(), env.host(), env.options());
                JSRuntime* rt = env.env().runtime().jsRuntime();
                const uint64_t freshStart = JS_GetWorkUnits(rt);
                fresh.rebuild(env.ctx());
                // Ruling E22: what the published state holds back for a rebuild covers what this one was charged.
                const uint64_t freshCharge = chargedWithoutSteps(rt, freshStart, fresh);
                if (estimateWithoutSteps(env.render()) < freshCharge && !reported) {
                    std::printf("  the estimate %llu is under a rebuild's %llu after: %s\n",
                                (unsigned long long)estimateWithoutSteps(env.render()), (unsigned long long)freshCharge,
                                what.c_str());
                }
                CHECK(estimateWithoutSteps(env.render()) >= freshCharge);
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
        std::printf("  %s: %llu flushes, %llu patched (%.0f%%), %llu rebuilt, %llu clean\n", group.name,
                    (unsigned long long)group.flushes, (unsigned long long)group.patched,
                    group.flushes ? 100.0 * double(group.patched) / double(group.flushes) : 0.0,
                    (unsigned long long)group.rebuilt, (unsigned long long)group.clean);
        for (const auto& [why, n] : group.why) {
            std::printf("    rebuilt %llu: %s\n", (unsigned long long)n, why.c_str());
        }
    }
    // Every group patched something and rebuilt something (random batches mix a kept node's own change with
    // structure in every group), and each near-limit group reached its limit at least once.
    for (const Group& group : groups) {
        CHECK(group.patched > 0);
        CHECK(group.rebuilt > 0);
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
    rebuilds(env, byId("s") + ".append(document.createElement('option'))", "refused by can_insert_subtree");
    rebuilds(env, byId("s") + ".firstElementChild.append(' more')", "refused by can_insert_subtree");
    rebuilds(env, byId("s") + ".remove()", "refused by can_remove_subtree");
    rebuilds(env, "const d = document.createElement('div'); d.append(document.createElement('select')); document.body.append(d)",
             "refused by can_insert_subtree");
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
    {
        // The byte budget: 1,048,000 bytes of text, then 1,000 more.
        std::string page = "<!doctype html><body><p id=big>";
        for (int n = 0; n < 1048; n++) {
            page += std::string(999, 'x') + " ";
        }
        page += "</p><p id=p>p</p></body>";
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
        // 256 form controls (Ruling E6).
        std::string page = "<!doctype html><body><div id=d>";
        for (int n = 0; n < 254; n++) {
            page += "<input>";
        }
        page += "</div></body>";
        RenderEnv env(page);
        patches(env, byId("d") + ".append(document.createElement('input'), document.createElement('button'))");
        rebuilds(env, byId("d") + ".append(document.createElement('textarea'))", "a render limit in a built subtree");
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

// Review Focus 2: a stop anywhere in the structure path's planning leaves the published document, render input,
// layout and tree as they were; a flush that gets through patches and equals a rebuild.
WR_TEST(testStructurePatchPrechargesBeforeTouchingLitehtml) {
    const std::string script =
        "const d = document.createElement('div'); d.innerHTML = '<p>' + 'a '.repeat(2000) + '</p><b>b</b>';"
        " document.getElementById('box').append(d); document.getElementById('three').remove();"
        " document.getElementById('list').append(document.getElementById('one')); 'ok'";
    uint64_t charged = 0;
    uint64_t reserve = 0;
    {
        RenderEnv env(kPage);
        CHECK_EQ(env.env().eval(script), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env.flush();
        charged = JS_GetWorkUnits(rt) - before;
        reserve = env.render().buildCharge() + uint64_t(litehtml::document::default_selector_steps) + 1000;
        CHECK_EQ(env.render().patchCount(), uint64_t(1));
        // 4,000 pieces: the layout pre-charge alone is 32,000 units.
        CHECK(charged > 32000);
    }
    int stopped = 0;
    int patched = 0;
    // Steps up to the whole flush's work, and then past it.
    std::vector<uint64_t> limits;
    for (uint64_t allowed = 1; allowed < charged; allowed += allowed < 200 ? 7 : allowed / 6) {
        limits.push_back(allowed);
    }
    // Ruling E20: a patch runs only when the budget also holds its fallback rebuild; short of that it rebuilds or stops.
    limits.push_back(charged + reserve);
    for (uint64_t allowed : limits) {
        RenderEnv env(kPage);
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const std::string input = env.render().renderInput();
        const std::string dump = env.render().layoutDump();
        const std::string layer = tree->dump();
        const uint64_t builds = env.render().buildCount();
        CHECK_EQ(env.env().eval(script), std::string("ok"));
        litehtml::document* document = env.render().document();
        const int pieces = document->text_elements();
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + allowed);
        bool aborted = false;
        try {
            env.flush();
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        if (aborted) {
            stopped++;
            CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
            CHECK(env.render().document() == document);
            CHECK(env.render().layerTree() == tree);
            CHECK_EQ(env.render().renderInput(), input);
            CHECK_EQ(env.render().layoutDump(), dump);
            CHECK_EQ(tree->dump(), layer);
            CHECK_EQ(env.render().buildCount(), builds);
            CHECK_EQ(env.render().patchCount(), uint64_t(0));
            // The subtrees made while planning went with it.
            CHECK_EQ(document->text_elements(), pieces);
        } else {
            env.env().runtime().setWorkLimit(~uint64_t(0));
            // Patched, or (short of the fallback's reserve) rebuilt: either equals a rebuild.
            if (env.render().patchCount() == 1) {
                patched++;
                CHECK_EQ(env.render().buildCount(), builds);
            } else {
                CHECK_EQ(env.render().buildCount(), builds + 1);
            }
            expectMatchesRebuild(env, "swept");
        }
    }
    if (stopped < 10 || patched < 1) {
        std::printf("  charged %llu: %d stopped, %d patched\n", (unsigned long long)charged, stopped, patched);
    }
    CHECK(stopped >= 10);
    CHECK(patched >= 1);
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

// Ruling E19: the reviewer's work probes. A patch's matching was a fresh 4,000,000 steps per inserted root and sheet,
// uncharged (7.24 s and 5.83 s); now the flush takes at most the one budget a build takes, and is charged for its steps.
WR_TEST(testSelectorStepWorkIsBounded) {
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
        JSRuntime* rt = env.env().runtime().jsRuntime();
        CHECK_EQ(env.env().eval("(() => { " + probe.script + "; })(); 'ok'"), std::string("ok"));
        const uint64_t units = JS_GetWorkUnits(rt);
        const uint64_t builds = env.render().buildCount();
        env.flush();
        const uint64_t charged = JS_GetWorkUnits(rt) - units;
        CHECK_EQ(std::string(env.render().lastPatchRefusal()), std::string("the selector-step budget"));
        CHECK_EQ(env.render().buildCount(), builds + 1);
        // One build's budget: the steps performed stop at it (past it a test is refused, and still counted, which is how
        // the cut shows), and every step performed is charged.
        const int64_t performed = std::min(env.render().selectorSteps(), litehtml::document::default_selector_steps);
        CHECK(env.render().selectorSteps() > litehtml::document::default_selector_steps);
        CHECK(charged >= uint64_t(performed) * wr::work::kSimpleSelectorTest);
        expectMatchesRebuild(env, probe.script);
    }
}

// Ruling E19 and Review Focus 2: a build whose matching runs out of the widget's work budget stops the widget (Budget) and
// leaves the published document, render input, layout and tree as they were. (Before the ruling matching was not
// charged, and this build succeeded.)
WR_TEST(testBuildStopsWhenMatchingExhaustsTheBudget) {
    std::string sheet;
    for (int i = 0; i < 15999; i++) {
        sheet += "div,";
    }
    sheet += "div{color:#ff0000}";
    std::string page = "<!doctype html><style>" + sheet + "</style><body>";
    for (int i = 0; i < 200; i++) {
        page += "<div>x</div>";
    }
    page += "</body>";
    // What a rebuild charges, and how much of it is matching.
    uint64_t total = 0;
    int64_t steps = 0;
    {
        RenderEnv env(page);
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t units = JS_GetWorkUnits(rt);
        env.rebuild();
        total = JS_GetWorkUnits(rt) - units;
        steps = env.render().selectorSteps();
        CHECK(steps >= 200 * 16000);
        CHECK(total >= uint64_t(steps));
    }
    RenderEnv env(page);
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    const std::string input = env.render().renderInput();
    const std::string dump = env.render().layoutDump();
    litehtml::document* document = env.render().document();
    JSRuntime* rt = env.env().runtime().jsRuntime();
    // Enough for everything but half the matching.
    env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + (total - uint64_t(steps)) + uint64_t(steps) / 2);
    bool aborted = false;
    try {
        env.rebuild();
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
    CHECK(env.render().document() == document);
    CHECK(env.render().layerTree() == tree);
    CHECK_EQ(env.render().renderInput(), input);
    CHECK_EQ(env.render().layoutDump(), dump);
}

// I2: a build counts every element it creates against litehtml's 20,000, the ones a parent's own appendChild then refuses
// included, and asks the piece cap for every piece a <table> then refuses. A patch counts them as a build does, or
// rebuilds. (The reviewer's probe: 16,000 table-refused divs, then a table of 5,000 directly appended rows.)
WR_TEST(testRefusedElementsCountAsABuildCounts) {
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

// Ruling E20.2, the reviewer's wabort: work limits between the patch's bound and the real steps it once took stop the
// widget, rebuild, or patch, and never end in std::abort; a stopped one leaves the published state as it was, and one
// that finished equals a rebuild.
WR_TEST(testTightBudgetNeverAbortsAPatch) {
    for (uint64_t extra : {150000ull, 250000ull, 400000ull, 600000ull, 800000ull, 1200000ull, 8000000ull}) {
        RenderEnv env(siblingAncestorPage(9000));
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        const std::string dump = env.render().layoutDump();
        litehtml::document* document = env.render().document();
        CHECK_EQ(env.env().eval("(() => { " + appendSpans(100) + "; })(); 'ok'"), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + extra);
        bool aborted = false;
        try {
            env.flush();
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        if (aborted) {
            CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
            CHECK(env.render().document() == document);
            CHECK(env.render().layerTree() == tree);
            CHECK_EQ(env.render().layoutDump(), dump);
        } else {
            env.env().runtime().setWorkLimit(~uint64_t(0));
            expectMatchesRebuild(env, "under a work limit of +" + std::to_string(extra));
        }
    }
}

// Ruling E21, the reviewer's wfilter2: apply_selector's filter loop (every rule against every element, counted by no
// step) is charged, at work::kScanEightUnits per eight (element, rule) pairs, by builds and by patches; and a build that
// cannot afford it stops before matching, where the same build of a sheet with no rules does not.
WR_TEST(testFilterLoopIsCharged) {
    std::string rules;
    for (int n = 0; rules.size() < 65536 - 16; n++) {
        rules += ".c" + std::to_string(n) + "{}";
    }
    auto page = [](const std::string& sheet, int divs) {
        std::string out = "<!doctype html><style>" + sheet + "</style><body><div id=c></div>";
        for (int i = 0; i < divs; i++) {
            out += "<div class=q></div>";
        }
        return out + "</body>";
    };
    auto rebuildCharge = [](RenderEnv& env) {
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env.rebuild();
        return JS_GetWorkUnits(rt) - before;
    };
    RenderEnv empty(page("", 5000));
    RenderEnv ruled(page(rules, 5000));
    const uint64_t plain = rebuildCharge(empty);
    const uint64_t filtered = rebuildCharge(ruled);
    const size_t count = ruled.render().document()->selector_count() - empty.render().document()->selector_count();
    CHECK(count > 8000);
    CHECK(filtered >= plain + wr::renderFilterUnits(5000, count));
    // Twice the divs, twice the loop.
    RenderEnv ruled2(page(rules, 10000));
    CHECK(rebuildCharge(ruled2) >= filtered + wr::renderFilterUnits(5000, count));
    // A patch pays for its new elements' loop.
    {
        JSRuntime* rt = ruled.env().runtime().jsRuntime();
        CHECK_EQ(ruled.env().eval("document.getElementById('c').innerHTML = '<div class=q></div>'.repeat(4000); 'ok'"), std::string("ok"));
        const uint64_t before = JS_GetWorkUnits(rt);
        ruled.flush();
        CHECK_EQ(ruled.render().patchCount(), uint64_t(1));
        CHECK(JS_GetWorkUnits(rt) - before >= wr::renderFilterUnits(4000, ruled.render().document()->selector_count()));
    }
    // A limit a sheet with no rules builds within, and the ruled one cannot: it stops (Budget) before matching, the
    // published state as it was.
    {
        RenderEnv env(page(rules, 5000));
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        litehtml::document* document = env.render().document();
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + plain + 64 * 1024 + wr::renderFilterUnits(5000, count) / 2);
        bool aborted = false;
        try {
            env.rebuild();
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        CHECK(aborted);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
        CHECK(env.render().document() == document);
        CHECK(env.render().layerTree() == tree);
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

uint64_t chargeOf(RenderEnv& env, void (RenderEnv::*what)()) {
    JSRuntime* rt = env.env().runtime().jsRuntime();
    const uint64_t before = JS_GetWorkUnits(rt);
    (env.*what)();
    return JS_GetWorkUnits(rt) - before;
}

} // namespace

// Ruling E22.1, the reviewer's pfilter: a ::before/::after rule that can create pseudo-elements for an element makes
// apply_stylesheet match two more elements for it against every rule, so the filter loop's charge counts them: three
// times the divs' pairs, in a build and in a patch; and a limit the loop without them fits stops the build before it
// matches.
WR_TEST(testFilterChargeCountsPseudoElements) {
    const std::string pseudo = "div::before{color:#f00}div::after{color:#f00}";
    RenderEnv plain(filterPage("", 5000));
    RenderEnv created(filterPage(pseudo, 5000));
    const size_t rules = created.render().document()->selector_count();
    CHECK(rules > 8000);
    const uint64_t plainBuild = chargeOf(plain, &RenderEnv::rebuild);
    const uint64_t createdBuild = chargeOf(created, &RenderEnv::rebuild);
    // The 5,001 divs' two pseudo-elements each, against the author sheet's rules (the master sheet's pass creates none
    // for a div: it is asked with the master sheet's creators).
    RenderEnv bare("<!doctype html><body></body>");
    const size_t authorRules = rules - bare.render().document()->selector_count();
    CHECK(createdBuild >= plainBuild + wr::renderFilterUnits(10002, authorRules));
    CHECK(created.render().buildChargeParts().filter >= plain.render().buildChargeParts().filter + wr::renderFilterUnits(10002, rules));
    // A `*` with only the pseudo-element creates nothing (html_tag::apply_selector), and neither does content: none.
    {
        RenderEnv none(filterPage("*::before{color:#f00} div::after{content:none}", 5000));
        CHECK(chargeOf(none, &RenderEnv::rebuild) < plainBuild + wr::renderFilterUnits(1000, rules));
    }
    // A patch pays for its new divs' pseudo-elements too. (1,000 new divs: with the 5,000 and their pseudo-elements
    // that stays under the element cap, which pseudo-elements count against since twidget edit 19; past it a patch
    // and a rebuild differ in which divs get theirs.)
    for (RenderEnv* env : {&plain, &created}) {
        CHECK_EQ(env->env().eval("document.getElementById('c').innerHTML = '<div class=q></div>'.repeat(1000); 'ok'"),
                 std::string("ok"));
    }
    const uint64_t plainPatch = chargeOf(plain, &RenderEnv::flush);
    const uint64_t createdPatch = chargeOf(created, &RenderEnv::flush);
    CHECK_EQ(plain.render().patchCount(), uint64_t(1));
    CHECK_EQ(created.render().patchCount(), uint64_t(1));
    CHECK(createdPatch >= plainPatch + wr::renderFilterUnits(2000, rules));
    expectMatchesRebuild(created, "1,000 divs with pseudo-elements");
    // Enough for the build without the pseudo-elements' share of the loop and half of it: the build stops (Budget)
    // before matching, the published state as it was.
    {
        RenderEnv env(filterPage(pseudo, 5000));
        std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
        litehtml::document* document = env.render().document();
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + plainBuild + 64 * 1024 + wr::renderFilterUnits(10002, rules) / 2);
        bool aborted = false;
        try {
            env.rebuild();
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        CHECK(aborted);
        CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
        CHECK(env.render().document() == document);
        CHECK(env.render().layerTree() == tree);
    }
}

// Ruling E28: pseudo-elements count against the element cap, and a rebuild hands the budget out in document order, so a
// patch that crosses the cap must not commit what a rebuild would not make. The 4,000 new divs of #c come before the
// 5,000 old ones.
WR_TEST(testPatchPastThePseudoCapMatchesRebuild) {
    RenderEnv env(filterPage("div::before{color:#f00}div::after{color:#f00}", 5000));
    CHECK_EQ(env.env().eval("document.getElementById('c').innerHTML = '<div class=q></div>'.repeat(4000); 'ok'"),
             std::string("ok"));
    (void)chargeOf(env, &RenderEnv::flush);
    expectMatchesRebuild(env, "4,000 divs patched past the pseudo-element cap");
}

// Ruling E28, attributes: near the cap, class changes that make `.x::after` match, last div first, must match a rebuild.
WR_TEST(testAttributePatchPastThePseudoCapMatchesRebuild) {
    RenderEnv env(filterPage("div::before{color:#f00}.x::after{color:#f00}", 9900));
    CHECK_EQ(env.env().eval("const d = document.querySelectorAll('div.q'); for (let i = d.length - 1; i >= d.length - 300; i--) d[i].setAttribute('class', 'q x'); 'ok'"),
             std::string("ok"));
    (void)chargeOf(env, &RenderEnv::flush);
    expectMatchesRebuild(env, "class changes past the pseudo-element cap");
}

// Ruling E22.2: a build's matching gets the steps the filter loop leaves of the budget. A sheet of class rules (a large
// loop, no steps) and 1,000 div rules (two million steps): with half the steps' share taken off the limit, the loop
// still fits and the steps no longer do, so the build is cut there and stops (Budget) without running past the budget,
// where it once ran all its steps and then charged them beyond it.
WR_TEST(testBuildStepsGetWhatTheFilterLoopLeaves) {
    std::string sheet;
    for (int n = 0; sheet.size() < 65536 - 4300; n++) {
        sheet += ".c" + std::to_string(n) + "{}";
    }
    for (int i = 0; i < 999; i++) {
        sheet += "div,";
    }
    sheet += "div{color:#ff0000}";
    std::string page = "<!doctype html><style>" + sheet + "</style><body>";
    for (int i = 0; i < 2000; i++) {
        page += "<div>x</div>";
    }
    page += "</body>";
    uint64_t total = 0;
    int64_t steps = 0;
    {
        RenderEnv env(page);
        total = chargeOf(env, &RenderEnv::rebuild);
        steps = env.render().selectorSteps();
        CHECK(steps >= 2000 * 1000);
        CHECK(steps < litehtml::document::default_selector_steps);
        CHECK(env.render().buildChargeParts().filter >= uint64_t(steps) / 2);
    }
    RenderEnv env(page);
    std::shared_ptr<const wr::LayerTree> tree = env.render().layerTree();
    litehtml::document* document = env.render().document();
    JSRuntime* rt = env.env().runtime().jsRuntime();
    const uint64_t limit = JS_GetWorkUnits(rt) + total - uint64_t(steps) / 2 * wr::work::kSimpleSelectorTest;
    env.env().runtime().setWorkLimit(limit);
    bool aborted = false;
    try {
        env.rebuild();
    } catch (const wr::Aborted&) {
        aborted = true;
    }
    CHECK(aborted);
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Budget);
    if (JS_GetWorkUnits(rt) > limit + 256) {
        std::printf("  the stopped build ran %llu units past the budget\n", (unsigned long long)(JS_GetWorkUnits(rt) - limit));
    }
    CHECK(JS_GetWorkUnits(rt) <= limit + 256);
    CHECK(env.render().document() == document);
    CHECK(env.render().layerTree() == tree);
}

// Ruling E22.3: what a patch's map nodes and pieces cost is what the estimate says (RenderTree.h), and growing a map from
// empty allocates at most 8 units per entry for its bucket arrays (the estimate holds 10).
WR_TEST(testMapNodeUnitsArePinned) {
    RenderEnv env("<!doctype html><body></body>");
    JSRuntime* rt = env.env().runtime().jsRuntime();
    std::vector<char> keys(20000);
    for (size_t n : {size_t(1), size_t(7), size_t(1000), size_t(20000)}) {
        wr::RenderElementMap elements(0, std::hash<const litehtml::element*>(), std::equal_to<const litehtml::element*>(),
                                      wr::JSAllocator<std::pair<const litehtml::element* const, wr::Node*>>(rt));
        elements.reserve(n);
        uint64_t before = JS_GetWorkUnits(rt);
        for (size_t i = 0; i < n; i++) {
            elements.emplace(reinterpret_cast<const litehtml::element*>(&keys[i]), nullptr);
        }
        CHECK_EQ(JS_GetWorkUnits(rt) - before, n * wr::kRenderElementMapNodeUnits);
        wr::RenderNodeMap nodes(0, std::hash<wr::Node*>(), std::equal_to<wr::Node*>(),
                                wr::JSAllocator<std::pair<wr::Node* const, wr::RenderEntry>>(rt));
        nodes.reserve(n);
        before = JS_GetWorkUnits(rt);
        for (size_t i = 0; i < n; i++) {
            nodes.try_emplace(reinterpret_cast<wr::Node*>(&keys[i]), wr::Ref<wr::Node>(), nullptr, rt);
        }
        CHECK_EQ(JS_GetWorkUnits(rt) - before, n * wr::kRenderNodeMapNodeUnits);
        wr::Vector<litehtml::element::ptr> pieces{wr::JSAllocator<litehtml::element::ptr>(rt)};
        before = JS_GetWorkUnits(rt);
        pieces.reserve(n);
        CHECK_EQ(JS_GetWorkUnits(rt) - before, n * (wr::kRenderPieceUnits - wr::kRenderElementMapNodeUnits));
    }
    wr::RenderElementMap grown(0, std::hash<const litehtml::element*>(), std::equal_to<const litehtml::element*>(),
                               wr::JSAllocator<std::pair<const litehtml::element* const, wr::Node*>>(rt));
    const uint64_t start = JS_GetWorkUnits(rt);
    bool held = true;
    for (size_t n = 1; n <= keys.size(); n++) {
        grown.emplace(reinterpret_cast<const litehtml::element*>(&keys[n - 1]), nullptr);
        held = held && JS_GetWorkUnits(rt) - start <= n * (wr::kRenderElementMapNodeUnits + 8);
    }
    CHECK(held);
}

// Ruling E22.3, the reviewer's preserve: after each patch the estimate the reserve is built on covers what rebuilding the
// DOM as it now is is charged, without the steps on either side (the reserve holds 4,000,000 of them): a text grown to
// 8,000 pieces, 4,000 subtrees, 200 inputs, big inline styles, half of it removed; and across the maps' rehash points.
WR_TEST(testReserveCoversARebuild) {
    struct Step {
        const char* what;
        std::string script;
    };
    auto run = [](const std::string& page, const std::vector<Step>& steps) {
        RenderEnv env(page);
        for (const Step& step : steps) {
            edit(env, step.script);
            JSRuntime* rt = env.env().runtime().jsRuntime();
            wr::RenderTree fresh(env.ctx(), env.host(), env.options());
            const uint64_t before = JS_GetWorkUnits(rt);
            fresh.rebuild(env.ctx());
            const uint64_t rebuilt = chargedWithoutSteps(rt, before, fresh);
            const uint64_t estimate = estimateWithoutSteps(env.render());
            if (estimate < rebuilt) {
                std::printf("  %s: the estimate %llu is under a rebuild's %llu\n", step.what, (unsigned long long)estimate,
                            (unsigned long long)rebuilt);
            }
            CHECK(estimate >= rebuilt);
            // The filter loop's bound is a tag count, kept exactly: what a rebuild's gate is asked with.
            CHECK_EQ(env.render().buildChargeParts().filter, fresh.buildChargeParts().filter);
        }
        return env.render().patchCount();
    };
    CHECK(run("<!doctype html><body><p id=t>x</p></body>",
              {{"text grows to 8,000 pieces", "document.getElementById('t').firstChild.data = 'a '.repeat(4000)"},
               {"again, 9,000", "document.getElementById('t').firstChild.data = 'b '.repeat(4500)"}}) == 2);
    CHECK(run("<!doctype html><style>div{color:red} .q span{color:blue} input{margin:1px}</style><body><div id=c></div></body>",
              {{"4,000 divs with spans", "document.getElementById('c').innerHTML = '<div class=q><span>s</span></div>'.repeat(4000)"},
               {"200 inputs", "document.getElementById('c').insertAdjacentHTML('beforeend', '<input value=abc>'.repeat(200))"},
               {"big inline styles",
                "for (const d of document.querySelectorAll('.q')) d.setAttribute('style', 'color:#123456;margin:1px 2px 3px 4px;padding:1px')"},
               {"remove half", "const c = document.getElementById('c'); for (let i = 0; i < 2000; i++) c.firstChild.remove()"}}) == 4);
    // One element more at every size up to 300: each map crosses its rehash points there.
    bool held = true;
    for (int n = 1; n <= 300; n++) {
        std::string page = "<!doctype html><body id=b>";
        for (int i = 0; i < n; i++) {
            page += "<p>x</p>";
        }
        RenderEnv env(page + "</body>");
        edit(env, "const p = document.createElement('p'); p.textContent = 'y'; document.body.append(p)");
        const uint64_t estimate = estimateWithoutSteps(env.render());
        const uint64_t rebuilt = rebuildChargeWithoutSteps(env);
        if (estimate < rebuilt || env.render().patchCount() != 1) {
            std::printf("  %d <p>s and one more: patched %llu, the estimate %llu, a rebuild %llu\n", n,
                        (unsigned long long)env.render().patchCount(), (unsigned long long)estimate,
                        (unsigned long long)rebuilt);
            held = false;
        }
    }
    CHECK(held);
}

// Ruling E22.3: the estimate is the current document's, not a running total of the patches' plans: five consecutive
// patches of one kind keep it within twice what a rebuild is charged (it was 8 times after five patches: the reviewer's
// preserve), and above it.
WR_TEST(testReserveIsStableAcrossPatches) {
    auto five = [](const char* what, const std::string& page, const std::function<std::string(int)>& script) {
        RenderEnv env(page);
        for (int i = 0; i < 5; i++) {
            patches(env, script(i));
            const uint64_t estimate = estimateWithoutSteps(env.render());
            const uint64_t rebuilt = rebuildChargeWithoutSteps(env);
            if (estimate < rebuilt || estimate > 2 * rebuilt) {
                std::printf("  %s, patch %d: the estimate %llu against a rebuild's %llu\n", what, i + 1,
                            (unsigned long long)estimate, (unsigned long long)rebuilt);
            }
            CHECK(estimate >= rebuilt);
            CHECK(estimate <= 2 * rebuilt);
        }
    };
    std::string divs = "<!doctype html><body>";
    for (int i = 0; i < 2000; i++) {
        divs += "<div class=q>d</div>";
    }
    divs += "</body>";
    std::string subtrees = "<!doctype html><body><div id=c>";
    for (int i = 0; i < 2000; i++) {
        subtrees += "<div class=q><span>s</span></div>";
    }
    subtrees += "</div></body>";
    std::string siblings = "<!doctype html><style>p + p{color:red}</style><body><div id=c>";
    for (int i = 0; i < 2000; i++) {
        siblings += "<p>x</p>";
    }
    siblings += "</div></body>";
    five("a text replaced", "<!doctype html><body><p id=t>x</p><p>" + std::string(4000, 'w') + "</p></body>", [](int i) {
        return "document.getElementById('t').firstChild.data = '" + std::string(1, char('a' + i)) + " '.repeat(" +
               std::to_string(2000 + 400 * i) + ")";
    });
    five("2,000 styles", divs, [](int i) {
        return "for (const d of document.querySelectorAll('.q')) d.setAttribute('style', 'color:#12345" + std::to_string(i) +
               ";margin:1px 2px 3px 4px;padding:1px')";
    });
    five("1,000 subtrees removed and added", subtrees, [](int i) {
        return i % 2 == 0
                   ? std::string("const c = document.getElementById('c'); for (let i = 0; i < 1000; i++) c.firstChild.remove()")
                   : std::string("document.getElementById('c').insertAdjacentHTML('beforeend', '<div class=q><span>s</span></div>'.repeat(1000))");
    });
    five("2,000 siblings rebuilt (p + p)", siblings,
         [](int) { return std::string("document.getElementById('c').append(document.createElement('p'))"); });
}

// Ruling E25, the reviewer's refused: an element a parent's appendChild refuses (a <div> appended to a <table>) is in no
// map, yet a build scans and byte-counts its attributes. Its own change beside structure elsewhere once patched, and with
// a 1,100,000-character title the rebuild hits `bytes` and stops its walk where the patch did not, so the patched layout
// and input differed from a rebuild's. An own change on a node the structure path finds unmapped now rebuilds, unless the
// node is outside the main document or under (or is) an element Ruling 4 leaves out, which no build reads.
WR_TEST(testAnUnmappedNodesOwnChangeRebuilds) {
    for (int title : {1000, 200000, 1100000}) {
        RenderEnv env("<!doctype html><body><table id=t><tbody><tr><td>c</td></tr></tbody></table><div id=c></div><p>tail</p>"
                      "</body>");
        rebuilds(env, "const d = document.createElement('div'); d.id = 'x'; " + byId("t") + ".append(d)",
                 "refused by can_insert_subtree");
        CHECK(env.render().renderLimits().empty());
        rebuilds(env, byId("c") + ".append(document.createElement('i')); " + byId("x") + ".setAttribute('title', 'y'.repeat(" +
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
// abandoned, and the same flush rebuilds: the journal is clean and the published state a rebuild's; so is an input's value.
WR_TEST(testCutAttributePatchIsReplacedByARebuild) {
    RenderEnv env("<!doctype html><style>.b{color:#f00} div{margin:1px}</style><body><div id=a class=x>one</div>"
                  "<p id=t>text</p><input id=i value=abc></body>");
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
    abandoned(byId("i") + ".setAttribute('value', 'abcdef')");
    // A text alone matches nothing: never cut.
    patches(env, byId("t") + ".firstChild.data = 'again'");
}

// Ruling E22.4: an abandoned patch is charged the steps its session performed before the flush rebuilds: two cuts of the
// same patch, at two session limits, differ by exactly the steps between them.
WR_TEST(testAbandonedPatchChargesItsSteps) {
    int64_t used = 0;
    {
        RenderEnv env(siblingAncestorPage(500));
        patches(env, appendSpans(50));
        used = env.render().lastPatchSteps();
    }
    CHECK(used > 4000);
    auto cutAt = [](int64_t cap) {
        RenderEnv env(siblingAncestorPage(500));
        env.render().setPatchStepCapForTesting(cap);
        CHECK_EQ(env.env().eval("(() => { " + appendSpans(50) + "; })(); 'ok'"), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        const uint64_t before = JS_GetWorkUnits(rt);
        env.flush();
        CHECK_EQ(std::string(env.render().lastPatchRefusal()), std::string("abandoned: the selector-step budget"));
        return JS_GetWorkUnits(rt) - before;
    };
    const uint64_t low = cutAt(used / 4);
    const uint64_t high = cutAt(used / 2);
    CHECK_EQ(high - low, uint64_t(used / 2 - used / 4) * wr::work::kSimpleSelectorTest);
}

// Ruling E22.4 with E20: a patch's session gets only what the reserve for its fallback leaves, so a cut one, charged its
// steps, still leaves the rebuild paid for. Below that reserve plus the patch's bound the patch is not attempted (before
// the cap it was, and cut); above it, an abandoned patch never stops the widget; every flush that finished equals a
// rebuild.
WR_TEST(testAbandonedPatchLeavesTheRebuildPaidFor) {
    int64_t used = 0;
    int64_t bound = 0;
    uint64_t reserve = 0;
    {
        RenderEnv env(siblingAncestorPage(500));
        patches(env, appendSpans(50));
        used = env.render().lastPatchSteps();
        bound = env.render().lastPatchStepBound();
        reserve = estimateWithoutSteps(env.render()) +
                  uint64_t(litehtml::document::default_selector_steps) * wr::work::kSimpleSelectorTest;
    }
    int abandonedCount = 0;
    for (int i = 0; i <= 60; i++) {
        RenderEnv env(siblingAncestorPage(500));
        env.render().setPatchStepCapForTesting(used / 2);
        CHECK_EQ(env.env().eval("(() => { " + appendSpans(50) + "; })(); 'ok'"), std::string("ok"));
        JSRuntime* rt = env.env().runtime().jsRuntime();
        env.env().runtime().setWorkLimit(JS_GetWorkUnits(rt) + reserve + uint64_t(bound) * uint64_t(i) / 20);
        bool aborted = false;
        try {
            env.flush();
        } catch (const wr::Aborted&) {
            aborted = true;
        }
        const bool abandoned = std::string(env.render().lastPatchRefusal()).rfind("abandoned", 0) == 0;
        abandonedCount += abandoned ? 1 : 0;
        if ((abandoned && aborted) || (abandoned && i < 20)) {
            std::printf("  abandoned (%s) at the reserve + %d/20 of the bound\n", aborted ? "then stopped" : "rebuilt", i);
        }
        CHECK(!(abandoned && aborted));
        CHECK(!(abandoned && i < 20));
        if (!aborted) {
            env.env().runtime().setWorkLimit(~uint64_t(0));
            expectMatchesRebuild(env, "a cut patch under a work limit");
        }
    }
    CHECK(abandonedCount > 0);
}
