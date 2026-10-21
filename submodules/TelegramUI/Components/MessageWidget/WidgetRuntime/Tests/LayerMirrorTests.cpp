// The layer mirror (M1c plan, Task 10b; twidget edit 20): the published tree mirrors litehtml's painting as Context, Box
// and Inline nodes with stable identity, and a patch the fork's render tree survives is published as operations the fork
// reported at its own mutation points, with nothing compared. Task 4's recorder is the oracle: a mirror flattens to what
// WidgetContainer::record paints, less what no painting node owns (Ruling E37).
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <functional>
#include <map>
#include <memory>
#include <optional>
#include <random>
#include <set>
#include <string>
#include <utility>
#include <variant>
#include <vector>

#include <litehtml.h>

#include "Sources/Render/LayerDiff.h"
#include "Sources/Render/LayerMirror.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Sources/Render/WidgetContainer.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/RenderHarness.h"

using wr::Layer;
using wr::LayerOp;
using wr::LayerTree;
using wr::MirrorNode;
using wr::PaintItem;
using wr_test::RenderEnv;

namespace {

// The oracle's normalisation (Ruling E37) is wr_test::normalized (RenderHarness.h).

// ---- Walking a mirror. ----

void collect(const MirrorNode& root, std::map<wr::LayerId, const MirrorNode*>& out,
             std::map<wr::LayerId, wr::LayerId>* parents = nullptr) {
    std::vector<std::pair<const MirrorNode*, wr::LayerId>> stack{{&root, 0}};
    while (!stack.empty()) {
        auto [node, parent] = stack.back();
        stack.pop_back();
        out[node->id] = node;
        if (parents) {
            (*parents)[node->id] = parent;
        }
        for (const auto& child : node->children) {
            stack.emplace_back(child.get(), node->id);
        }
    }
}

std::map<wr::LayerId, const MirrorNode*> nodesOf(const LayerTree& tree) {
    std::map<wr::LayerId, const MirrorNode*> out;
    if (tree.mirror()) {
        collect(*tree.mirror(), out);
    }
    return out;
}

// Every text item of a Box or Inline node's content, at any depth.
std::vector<const wr::TextItem*> textsOf(const MirrorNode& node) {
    std::vector<const wr::TextItem*> out;
    if (!node.content) {
        return out;
    }
    std::vector<const Layer*> stack{node.content.get()};
    while (!stack.empty()) {
        const Layer* layer = stack.back();
        stack.pop_back();
        for (const auto& entry : layer->entries) {
            if (const PaintItem* item = std::get_if<PaintItem>(&entry)) {
                if (const auto* text = std::get_if<wr::TextItem>(&item->payload)) {
                    out.push_back(text);
                }
            } else {
                stack.push_back(std::get<std::unique_ptr<Layer>>(entry).get());
            }
        }
    }
    return out;
}

// The Inline node that draws `text`.
const MirrorNode* inlineWith(const LayerTree& tree, const std::string& text) {
    for (const auto& [id, node] : nodesOf(tree)) {
        if (node->kind != MirrorNode::Kind::Inline) {
            continue;
        }
        for (const wr::TextItem* item : textsOf(*node)) {
            if (item->text == text) {
                return node;
            }
        }
    }
    return nullptr;
}

// The ids of every node keyed `key`.
std::set<wr::LayerId> idsWithKey(const LayerTree& tree, wr::NodeKey key) {
    std::set<wr::LayerId> out;
    for (const auto& [id, node] : nodesOf(tree)) {
        if (key != 0 && node->key == key) {
            out.insert(id);
        }
    }
    return out;
}

bool isReset(const std::vector<LayerOp>& ops) {
    return ops.size() == 1 && ops[0].kind == LayerOp::Reset;
}

const char* opName(LayerOp::Kind kind) {
    switch (kind) {
    case LayerOp::Reset: return "reset";
    case LayerOp::Insert: return "insert";
    case LayerOp::Remove: return "remove";
    case LayerOp::Move: return "move";
    case LayerOp::Frame: return "frame";
    case LayerOp::Content: return "content";
    case LayerOp::Clip: return "clip";
    case LayerOp::Group: return "group";
    }
    return "?";
}

std::string describe(const std::vector<LayerOp>& ops) {
    std::string out;
    for (const LayerOp& op : ops) {
        char line[96];
        std::snprintf(line, sizeof(line), "%s %llu (parent %llu, after %llu); ", opName(op.kind),
                      (unsigned long long)op.node, (unsigned long long)op.parent, (unsigned long long)op.after);
        out += line;
    }
    return out;
}

// Every node of `after` that no op names and that is not an ancestor of a named one is `before`'s node with its id.
bool unnamedAreShared(const LayerTree& before, const LayerTree& after, const std::vector<LayerOp>& ops, std::string& why) {
    std::map<wr::LayerId, const MirrorNode*> was, now;
    std::map<wr::LayerId, wr::LayerId> parents;
    if (before.mirror()) {
        collect(*before.mirror(), was);
    }
    if (after.mirror()) {
        collect(*after.mirror(), now, &parents);
    }
    std::set<wr::LayerId> touched;
    for (const LayerOp& op : ops) {
        for (wr::LayerId id : {op.node, op.parent}) {
            for (wr::LayerId at = id; at != 0; at = parents.count(at) ? parents[at] : 0) {
                if (!touched.insert(at).second) {
                    break;
                }
            }
        }
    }
    for (const auto& [id, node] : now) {
        if (touched.count(id)) {
            continue;
        }
        auto old = was.find(id);
        if (old == was.end() || old->second != node) {
            why = "node " + std::to_string(id) + (old == was.end() ? " is new" : " is a new object") + " with no op";
            return false;
        }
    }
    return true;
}

// The previous tree's id structure with the published ops applied in order, as the app applies them.
struct IdTree {
    std::map<wr::LayerId, std::vector<wr::LayerId>> children;
    std::map<wr::LayerId, wr::LayerId> parent;
    wr::LayerId root = 0;

    static IdTree of(const MirrorNode& root) {
        IdTree tree;
        tree.root = root.id;
        std::vector<const MirrorNode*> stack{&root};
        while (!stack.empty()) {
            const MirrorNode* node = stack.back();
            stack.pop_back();
            auto& list = tree.children[node->id];
            for (const auto& child : node->children) {
                list.push_back(child->id);
                tree.parent[child->id] = node->id;
                stack.push_back(child.get());
            }
        }
        return tree;
    }

    void detach(wr::LayerId node) {
        auto p = parent.find(node);
        if (p == parent.end()) {
            return;
        }
        auto& list = children[p->second];
        list.erase(std::remove(list.begin(), list.end(), node), list.end());
        parent.erase(p);
    }

    bool attach(wr::LayerId node, wr::LayerId to, wr::LayerId after) {
        auto it = children.find(to);
        if (it == children.end()) {
            return false;
        }
        auto& list = it->second;
        auto at = list.begin();
        if (after != 0) {
            at = std::find(list.begin(), list.end(), after);
            if (at == list.end()) {
                return false;
            }
            ++at;
        }
        list.insert(at, node);
        parent[node] = to;
        children[node];
        return true;
    }

    // false for an op that cannot apply (an unknown node, parent or sibling).
    bool apply(const LayerOp& op) {
        switch (op.kind) {
        case LayerOp::Insert:
            if (children.count(op.node)) {
                return false;
            }
            return attach(op.node, op.parent, op.after);
        case LayerOp::Remove: {
            if (!children.count(op.node) || op.node == root) {
                return false;
            }
            detach(op.node);
            std::vector<wr::LayerId> stack{op.node};
            while (!stack.empty()) {
                const wr::LayerId at = stack.back();
                stack.pop_back();
                for (wr::LayerId child : children[at]) {
                    stack.push_back(child);
                    parent.erase(child);
                }
                children.erase(at);
            }
            return true;
        }
        case LayerOp::Move:
            if (!children.count(op.node)) {
                return false;
            }
            detach(op.node);
            return attach(op.node, op.parent, op.after);
        case LayerOp::Frame:
        case LayerOp::Content:
        case LayerOp::Clip:
        case LayerOp::Group:
            return children.count(op.node) != 0;
        case LayerOp::Reset:
            return false;
        }
        return false;
    }

    bool operator==(const IdTree& other) const { return root == other.root && children == other.children; }
};

bool contains(const litehtml::position& outer, const litehtml::position& inner) {
    return outer.x.value() <= inner.x.value() && outer.y.value() <= inner.y.value() &&
           outer.x.value() + outer.width.value() >= inner.x.value() + inner.width.value() &&
           outer.y.value() + outer.height.value() >= inner.y.value() + inner.height.value();
}

// Whether `reported` covers every rect of `oracle`: nullopt covers everything; each oracle rect lies in a reported one.
bool covers(const std::optional<std::vector<litehtml::position>>& reported,
            const std::optional<std::vector<litehtml::position>>& oracle, std::string& why) {
    if (!reported) {
        return true;
    }
    if (!oracle) {
        why = "the oracle says everything changed";
        return false;
    }
    for (const auto& rect : *oracle) {
        bool in = false;
        for (const auto& r : *reported) {
            in = in || contains(r, rect);
        }
        if (!in) {
            char text[128];
            std::snprintf(text, sizeof(text), "(%g,%g,%g,%g) is not covered", double(rect.x.value()), double(rect.y.value()),
                          double(rect.width.value()), double(rect.height.value()));
            why = text;
            return false;
        }
    }
    return true;
}

// Runs `script` as the widget's own change, then flushes.
void edit(RenderEnv& env, const std::string& script) {
    CHECK_EQ(env.env().eval("(() => { " + script + "; })(); 'ok'"), std::string("ok"));
    env.flush();
}

// The published tree flattens as record() paints, normalised (Ruling E37), and is a mirror.
bool flattensAsRecorded(RenderEnv& env, const std::string& what) {
    std::shared_ptr<const LayerTree> tree = env.render().layerTree();
    std::shared_ptr<const LayerTree> recorded = env.render().recordForTesting();
    if (!tree || !recorded || !tree->mirror()) {
        std::printf("  no mirror after: %s\n", what.c_str());
        return false;
    }
    const std::string ours = tree->dump();
    const std::string theirs = wr_test::normalized(*recorded)->dump();
    if (ours != theirs) {
        // From the first differing line after the header (which holds the item count).
        const size_t start = std::min(ours.find('\n'), theirs.find('\n'));
        size_t at = start == std::string::npos ? 0 : start;
        while (at < ours.size() && at < theirs.size() && ours[at] == theirs[at]) {
            at++;
        }
        const size_t from = at > 300 ? at - 300 : 0;
        std::printf("  the mirror flattens differently after: %s (byte %zu)\n  %s / %s\n  mirror:\n%s\n  record:\n%s\n",
                    what.c_str(), at, ours.substr(0, ours.find('\n')).c_str(), theirs.substr(0, theirs.find('\n')).c_str(),
                    ours.substr(from, 2500).c_str(), theirs.substr(from, 2500).c_str());
        return false;
    }
    return true;
}

// The published mirror equals a freshly built one: kinds, keys, order, origins, passes, clip chains and content.
bool equalsAFreshMirror(RenderEnv& env, const std::string& what, std::shared_ptr<const LayerTree>* fresh = nullptr) {
    std::shared_ptr<const LayerTree> tree = env.render().layerTree();
    std::shared_ptr<const LayerTree> rebuilt = env.render().freshMirrorForTesting();
    if (fresh) {
        *fresh = rebuilt;
    }
    if (!tree || !tree->mirror() || !rebuilt || !rebuilt->mirror()) {
        return false;
    }
    const std::string ours = wr::dumpMirror(*tree->mirror());
    const std::string theirs = wr::dumpMirror(*rebuilt->mirror());
    if (ours != theirs) {
        size_t at = 0;
        while (at < ours.size() && at < theirs.size() && ours[at] == theirs[at]) {
            at++;
        }
        const size_t from = at > 300 ? at - 300 : 0;
        std::printf("  the mirror differs from a fresh one after: %s (byte %zu)\n  published:\n%s\n  fresh:\n%s\n", what.c_str(),
                    at, ours.substr(from, 2500).c_str(), theirs.substr(from, 2500).c_str());
        return false;
    }
    return true;
}

// Task 4's fixture (LayerTreeTests' kEveryKind and its image).
const char* const kPng3x2 =
    "data:image/png;base64,"
    "iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAYAAACddGYaAAAAEUlEQVR4nGP4z8DwH4YZkDkAm34L9XKwuTwAAAAASUVORK5CYII=";

std::string everyKindHtml() {
    return std::string("<div style='border:1px solid red'>text</div>"
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
                       "<svg width=20 height=20><path d='M0 10 C0 0 10 0 10 10' fill='#00ff00' /></svg>") +
           "<img src='" + kPng3x2 + "'>";
}

// Task 5's parity fixtures (RenderBuildTests' testBuildPathParity).
const char* const kTask5Fixtures[] = {
    "<!doctype html><p>Some text runs: <b>bold</b>, <i>italic</i>, <span style='font-size:20px'>larger</span> and "
    "<small>small</small>, long enough to wrap twice at this width, with <sub>sub</sub> and <sup>super</sup>.</p>",
    "<!doctype html><table border=1 cellpadding=2><tr><th>head</th><th>wider head</th></tr><tr><td>a</td><td>bb</td>"
    "</tr><tr><td colspan=2>a cell across both columns with some text</td></tr></table>",
    "<!doctype html><pre>line one\n  line two, indented\n\tthree after a tab\n\n</pre><p>after &amp; &lt;x&gt; "
    "&nbsp;nbsp</p>",
    "<!doctype html><ul><li>one<ol><li>a</li><li>b<ul><li>deep</li></ul></li></ol></li><li>two</li></ul>\n"
    "<p title='a \"quoted\" &amp; value'>x</p>",
    "<!doctype html><head><style>.box { padding: 4px; margin: 2px; border: 1px solid red } .wide { width: 120px } "
    ".row { display: flex; gap: 6px } .row > * { flex: 1 } p > b { margin-left: 3px }</style></head><body>\n"
    "<div class='box wide'>x</div><div class=box>y z</div>\n"
    "<div class=row><span>left</span><span class=box>right</span></div></body>",
    "<!doctype html><form><input type=text value=hi><input type=checkbox checked><input type=radio>"
    "<input type=range><select><option>one</option><option selected>two</option></select><button>Go</button>"
    "<textarea>t</textarea><input placeholder='a placeholder'></form>",
    "<!doctype html><svg viewBox='0 0 20 20' width=20 height=20><defs><linearGradient id=g><stop offset=0 "
    "stop-color=red /></linearGradient></defs><rect width=10 height=10 fill='url(#g)'/></svg><p>after</p>",
};

} // namespace

// The mirror, flattened with its origins composed, paints what record() paints, for Task 4's fixture (a mirror over a
// document litehtml parsed, every node anonymous) and every Task 5 fixture (the runtime's published tree).
WR_TEST(testMirrorReplaysAsLitehtmlDraws) {
    {
        wr_test::FakeRenderHost host;
        wr::RenderOptions options;
        options.width = 300;
        wr::WidgetContainer container(host, options);
        litehtml::document::ptr document =
            litehtml::document::createFromString(litehtml::estring(everyKindHtml()), &container);
        document->render(litehtml::pixel_t(300.0f));
        wr::LayerId ids = 1;
        // Optional, so it can go before the document, as RenderTree's does: it observes the document.
        std::optional<wr::LayerMirror> mirror;
        mirror.emplace([](const litehtml::element&) { return wr::NodeKey(0); }, ids);
        std::shared_ptr<const LayerTree> tree = mirror->build(*document, container);
        CHECK(tree && tree->mirror());
        CHECK_EQ(mirror->walks(), uint64_t(1));
        const std::string ours = tree ? tree->dump() : std::string();
        const std::string theirs = wr_test::normalized(*container.record(*document))->dump();
        CHECK_EQ(ours, theirs);
        if (ours != theirs) {
            std::printf("  mirror:\n%s\n  record:\n%s\n", ours.c_str(), theirs.c_str());
        }
        // One of every node kind, and every node has an id of its own.
        std::set<MirrorNode::Kind> kinds;
        std::set<MirrorNode::ContextKind> contexts;
        const auto nodes = tree ? nodesOf(*tree) : std::map<wr::LayerId, const MirrorNode*>{};
        for (const auto& [id, node] : nodes) {
            kinds.insert(node->kind);
            if (node->kind == MirrorNode::Kind::Context) {
                contexts.insert(node->context);
            }
            CHECK(id != 0);
        }
        CHECK(kinds.size() == 3);
        CHECK(contexts.count(MirrorNode::ContextKind::Root) && contexts.count(MirrorNode::ContextKind::Group) &&
              contexts.count(MirrorNode::ContextKind::Stacking));
        // The tree outlives the mirror, the document and the container (Review Focus 5).
        mirror.reset();
        document.reset();
        CHECK(!ours.empty() && tree->dump() == ours);
    }
    for (const char* fixture : kTask5Fixtures) {
        RenderEnv env(fixture);
        CHECK(flattensAsRecorded(env, fixture));
        CHECK(equalsAFreshMirror(env, fixture));
        // NodeKeys come from the element → node map: a rendered element's nodes are keyed.
        size_t keyed = 0;
        for (const auto& [id, node] : nodesOf(*env.render().layerTree())) {
            keyed += node->key != 0;
        }
        CHECK(keyed >= 2);
    }
}

// Review Focus 1 for the mirror: Task 9's random edits, each flush's mirror equal to record() and to a fresh mirror,
// identity kept across the flushes the fork's render tree survives, which publish operations, and the rects covering
// what changed.
WR_TEST(testOpsMatchAFreshMirror) {
    const std::string base = ".box{padding:2px;border:1px solid #000} .x{color:#c00;font-weight:bold} .y{background:#ff0}"
                             " [hidden]{display:none} li{margin:1px} td{padding:2px} p{margin:2px}";
    const std::string sibling =
        base + " li:nth-child(2n){color:#00f} p:nth-child(2n){background:#eee} .x + .y{color:#0a0} .x ~ span{text-decoration:underline}"
               " li:last-child{border-bottom:2px solid #00f} p:first-child{padding-left:3px}";
    auto pageOf = [](const std::string& sheet, const std::string& prefix) {
        return "<!doctype html><style>" + sheet + "</style><body style='margin:0'>" + prefix +
               "<div id=a class=box><p class=x>alpha <b>bold</b> text</p><p>beta</p><span class=y>gamma</span></div>"
               "<ul id=l><li>one</li><li class=x>two</li><li>three</li></ul>"
               "<table id=t>\n<caption>cap</caption>\n<thead><tr><td>h1</td></tr></thead>\n"
               "<tbody><tr><td>c1</td><td class=y>c2</td></tr>\n<tr><td>c3</td><td>c4</td></tr></tbody>\n</table>"
               "<pre id=pre>pre  text\n line</pre>"
               "<div id=f><input value=ab><input type=checkbox checked><button>go</button></div>"
               "<svg width=30 height=30 viewBox='0 0 30 30'><circle cx=15 cy=15 r=10 fill=red></circle></svg>"
               "<template id=tpl><i class=x>tpl one</i><b>tpl two</b></template>"
               "<div id=c class=y>tail</div></body>";
    };
    std::string many = "<section id=many>";
    for (int n = 0; n < 40; n++) {
        many += n % 7 ? "<p>p <span>s</span></p>" : "<p class=y>p <b>b</b></p>";
    }
    many += "</section>";
    struct Group {
        const char* name;
        int firstSeed;
        int lastSeed;
        std::string sheet;
        std::string prefix;
        /// Text and class edits only: flushes the fork's render tree survives, which publish operations.
        bool keepTree = false;
    };
    // Beyond Task 9's twenty seeds: a sheet whose class rules are paint-only (no attribute or positional selector, so
    // class changes are patched with the render tree kept), `z` adding opacity, so the operations themselves are
    // exercised: re-captures, frames, a box becoming a group and back.
    const std::string neutral = ".box{padding:2px;border:1px solid #000} .x{color:#c00} .y{background-color:#ff0}"
                                " .z{opacity:.5} li{margin:1px} td{padding:2px} p{margin:2px}";
    const Group groups[] = {
        {"sibling", 1, 5, sibling, ""},
        {"plain", 6, 10, base, ""},
        {"pseudo", 11, 15, base + " q::before{content:'\\00ab'}", ""},
        {"plain, many paragraphs", 16, 20, base, many},
        {"paint-only classes", 21, 30, neutral, many},
        {"paint-only classes, text and class edits only", 31, 40, neutral, many, true},
    };
    const std::string helpers = R"JS(
globalThis.__edit = (() => {
  const tpl = document.getElementById('tpl');
  const excluded = n => n.localName === 'template';
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
    switch (k % 12) {
      case 0: return document.createTextNode('new text');
      case 1: return el('p', {class: 'x'}, ['para ', el('b', {}, ['in'])]);
      case 2: return el('span', {class: 'y'}, ['sp']);
      case 3: return el('li', {}, ['item']);
      case 4: return el('div', {class: 'box'}, [el('p', {}, ['inner']), el('span', {}, ['s'])]);
      case 5: return el('input', {value: 'zz'}, []);
      case 6: return el('b', {}, ['b']);
      case 7: return el('tr', {}, [el('td', {}, ['r1']), el('td', {class: 'y'}, ['r2'])]);
      case 8: return el('q', {}, ['quote']);
      case 10: return el('pre', {}, ['p  re\n x']);
      default: return document.createTextNode(' ');
    }
  }
  const words = ['', 'a', 'two words', 'three little words', 'x & <y>', '  spaced  out  ', 'longer text that wraps around the line',
                 'a much longer text that certainly wraps across more than one line at this width'];
  const htmls = ['', '<b>b</b> text', '<p class=x>p</p><span class=y>s</span>', '<li>l1</li><li class=x>l2</li>', 'plain'];
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
        case 9: case 10: case 11: { const t = pick(texts(), a); if (t) t.data = words[b % words.length]; return 'data'; }
        default: tpl.content.append(make(b)); return 'template append';
      }
    } catch (e) {
      return 'threw ' + e.name;
    }
  };
})(); 'ok'
)JS";
    uint64_t flushes = 0, kept = 0, rebuilds = 0, unplaceable = 0, builds = 0, frames = 0, contents = 0, inserts = 0,
             moves = 0, removes = 0;
    for (const Group& group : groups) {
        for (int seed = group.firstSeed; seed <= group.lastSeed; seed++) {
            RenderEnv env(pageOf(group.sheet, group.prefix));
            CHECK_EQ(env.env().eval(helpers), std::string("ok"));
            std::shared_ptr<const LayerTree> freshBefore = env.render().freshMirrorForTesting();
            std::mt19937 rng{uint32_t(seed)};
            int edits = 0;
            bool reported = false;
            while (edits < 200) {
                const int batch = 1 + int(rng() % 5);
                std::string done;
                for (int k = 0; k < batch && edits < 200; k++, edits++) {
                    static const uint32_t kKeepTreeKinds[] = {6, 9, 10, 11};
                    const uint32_t drawn = uint32_t(rng() % 13);
                    const uint32_t kind = group.keepTree ? kKeepTreeKinds[drawn % 4] : drawn, a = uint32_t(rng() % 1000),
                                   b = uint32_t(rng() % 1000), c = uint32_t(rng() % 1000);
                    const std::string call = "__edit(" + std::to_string(kind) + ", " + std::to_string(a) + ", " +
                                             std::to_string(b) + ", " + std::to_string(c) + ")";
                    done += (done.empty() ? "" : "; ") + env.env().eval(call) + " " + call;
                }
                std::shared_ptr<const LayerTree> before = env.render().layerTree();
                const uint64_t walks = env.render().mirrorWalks();
                const uint64_t patches = env.render().patchCount();
                const uint64_t built = env.render().buildCount();
                const uint64_t treeResets = env.render().treeRebuildResets();
                const uint64_t lostResets = env.render().unplaceableResets();
                env.flush();
                if (env.render().patchCount() == patches && env.render().buildCount() == built) {
                    continue;   // clean: nothing was published
                }
                flushes++;
                std::shared_ptr<const LayerTree> after = env.render().layerTree();
                const std::vector<LayerOp> ops = env.render().layerOps();
                const bool reset = isReset(ops);
                const bool patched = env.render().patchCount() != patches;
                const std::string what = "seed " + std::to_string(seed) + ", edit " + std::to_string(edits) + " (" +
                                         (patched ? (reset ? "patched, reset" : "patched, ops") : "rebuilt") + "): " + done;
                rebuilds += env.render().treeRebuildResets() - treeResets;
                unplaceable += env.render().unplaceableResets() - lostResets;
                builds += !patched;
                bool same = flattensAsRecorded(env, what);
                std::shared_ptr<const LayerTree> freshAfter;
                same = equalsAFreshMirror(env, what, &freshAfter) && same;
                std::string why;
                if (!reset) {
                    kept++;
                    // Surviving nodes keep their ids: every node of `before` that no Remove took is still there.
                    std::map<wr::LayerId, const MirrorNode*> was = nodesOf(*before), now = nodesOf(*after);
                    IdTree structure = IdTree::of(*before->mirror());
                    bool applies = true;
                    for (const LayerOp& op : ops) {
                        applies = structure.apply(op) && applies;
                        frames += op.kind == LayerOp::Frame;
                        contents += op.kind == LayerOp::Content;
                        inserts += op.kind == LayerOp::Insert;
                        moves += op.kind == LayerOp::Move;
                        removes += op.kind == LayerOp::Remove;
                    }
                    for (const auto& [id, node] : was) {
                        if (structure.children.count(id) && !now.count(id)) {
                            applies = false;
                        }
                    }
                    if (!applies && !reported) {
                        std::printf("  the ops do not apply after: %s\n  ops: %s\n", what.c_str(), describe(ops).c_str());
                    }
                    same = applies && same;
                    // The ops, applied to the previous tree as the app applies them, give the new tree (Ruling E39): a
                    // wrong parent or `after` in an Insert or a Move shows here.
                    const bool replays = applies && structure == IdTree::of(*after->mirror());
                    if (applies && !replays && !reported) {
                        std::printf("  the ops replayed on the previous tree are not the new tree after: %s\n  ops: %s\n",
                                    what.c_str(), describe(ops).c_str());
                    }
                    same = replays && same;
                    // The walk ran only for a build, and what no op names is the same object.
                    if (env.render().mirrorWalks() != walks) {
                        why = "walked on a flush that published operations";
                        same = false;
                    } else if (!unnamedAreShared(*before, *after, ops, why)) {
                        same = false;
                    }
                } else if (patched && env.render().mirrorWalks() != walks + 1) {
                    why = "a reset that did not walk once";
                    same = false;
                }
                if (!covers(env.render().changedRects(), wr::changedRects(freshBefore.get(), *freshAfter), why)) {
                    same = false;
                }
                if (!same && !reported) {
                    std::printf("  after: %s\n  %s\n  ops: %s\n", what.c_str(), why.c_str(), describe(ops).c_str());
                }
                reported = reported || !same;
                CHECK(same);
                freshBefore = freshAfter;
            }
        }
    }
    std::printf("  %llu flushes: %llu published operations (%llu frames, %llu contents, %llu inserts, %llu moves, %llu"
                " removes), %llu reset after the fork rebuilt its render tree, %llu reset for a change the mirror could not"
                " place, %llu full builds\n",
                (unsigned long long)flushes, (unsigned long long)kept, (unsigned long long)frames,
                (unsigned long long)contents, (unsigned long long)inserts, (unsigned long long)moves,
                (unsigned long long)removes, (unsigned long long)rebuilds, (unsigned long long)unplaceable,
                (unsigned long long)builds);
    // The fixture reaches both kinds of flush.
    CHECK(kept > 0);
    CHECK(rebuilds > 0);
}

// The app's contract: the ops, applied in order to the previous tree's id structure, give the new tree's.
WR_TEST(testOpsReplayOnThePreviousTree) {
    RenderEnv env("<!doctype html><style>p{margin:0} .c{color:#c00} .d{color:#00c;background-color:#eee} .op{opacity:.5}</style>"
                  "<body style='margin:0'><p id=p1>one</p><div id=t><p>inside the target</p></div><p id=p2>two</p></body>");
    const char* const scripts[] = {
        "document.getElementById('p1').firstChild.data = 'a text long enough to wrap onto a second line at this width'",
        "document.getElementById('p2').className = 'd'",
        "document.getElementById('t').className = 'op'",
        "document.getElementById('p1').firstChild.data = 'short again'",
        "document.getElementById('t').className = ''",
        "document.body.append(document.createElement('p'))",
        "document.getElementById('p2').className = 'c'",
    };
    size_t opFlushes = 0;
    for (const char* script : scripts) {
        std::shared_ptr<const LayerTree> before = env.render().layerTree();
        edit(env, script);
        std::shared_ptr<const LayerTree> after = env.render().layerTree();
        const std::vector<LayerOp>& ops = env.render().layerOps();
        CHECK(before && after && before->mirror() && after->mirror());
        if (!before || !after || !before->mirror() || !after->mirror()) {
            continue;
        }
        CHECK(!ops.empty());
        IdTree structure = IdTree::of(*before->mirror());
        if (isReset(ops)) {
            structure = IdTree::of(*after->mirror());
        } else {
            opFlushes++;
            bool applies = true;
            for (const LayerOp& op : ops) {
                applies = structure.apply(op) && applies;
            }
            CHECK(applies);
        }
        const bool same = structure == IdTree::of(*after->mirror());
        if (!same) {
            std::printf("  the replayed structure differs after: %s\n  ops: %s\n", script, describe(ops).c_str());
        }
        CHECK(same);
        CHECK(flattensAsRecorded(env, script));
        CHECK(equalsAFreshMirror(env, script));
    }
    CHECK(opFlushes >= 4);
}

// A text change that gives paragraph 1 an extra line moves the paragraphs after it: Frames only, and the only text
// shaped again is paragraph 1's.
WR_TEST(testAMovedParagraphIsAFrameNotACapture) {
    RenderEnv env("<!doctype html><style>p{margin:0;background:#eee}</style><body style='margin:0;height:200px'>"
                  "<p id=p1>short</p><p id=p2>the second paragraph</p><p id=p3>the third</p></body>");
    std::shared_ptr<const LayerTree> before = env.render().layerTree();
    const MirrorNode* second = before ? inlineWith(*before, "second") : nullptr;
    const MirrorNode* third = before ? inlineWith(*before, "third") : nullptr;
    CHECK(second && third);
    if (!before || !second || !third) {
        return;
    }
    std::set<wr::LayerId> moved = idsWithKey(*before, second->key);
    for (wr::LayerId id : idsWithKey(*before, third->key)) {
        moved.insert(id);
    }
    CHECK(moved.size() == 4);   // each paragraph's Box (its background) and Inline
    const size_t shapes = env.host().shapeCalls;
    const uint64_t patches = env.render().patchCount();
    const uint64_t builds = env.render().buildCount();
    const uint64_t walks = env.render().mirrorWalks();
    edit(env, "document.getElementById('p1').firstChild.data = 'a first paragraph long enough to take two lines'");
    CHECK_EQ(env.render().patchCount(), patches + 1);
    CHECK_EQ(env.render().buildCount(), builds);
    CHECK_EQ(env.render().mirrorWalks(), walks);
    std::shared_ptr<const LayerTree> after = env.render().layerTree();
    const std::vector<LayerOp>& ops = env.render().layerOps();
    CHECK(!isReset(ops));
    std::map<wr::LayerId, std::set<LayerOp::Kind>> named;
    for (const LayerOp& op : ops) {
        named[op.node].insert(op.kind);
    }
    for (wr::LayerId id : moved) {
        const bool onlyFrame = named.count(id) && named[id] == std::set<LayerOp::Kind>{LayerOp::Frame};
        if (!onlyFrame) {
            std::printf("  node %llu is not a frame alone: %s\n", (unsigned long long)id, describe(ops).c_str());
        }
        CHECK(onlyFrame);
    }
    // Shaping: paragraph 1's new runs and nothing else.
    const MirrorNode* first = after ? inlineWith(*after, "first") : nullptr;
    CHECK(first != nullptr);
    if (first) {
        const size_t runs = textsOf(*first).size();
        CHECK(runs > 4);
        CHECK_EQ(env.host().shapeCalls - shapes, runs);
    }
    // A moved node keeps its content object.
    const auto now = nodesOf(*after);
    const auto was = nodesOf(*before);
    for (wr::LayerId id : moved) {
        CHECK(now.count(id) && was.count(id) && now.at(id)->content == was.at(id)->content);
        CHECK(now.count(id) && was.count(id) && now.at(id)->origin.y > was.at(id)->origin.y);
    }
    CHECK(flattensAsRecorded(env, "p1 takes two lines"));
    CHECK(equalsAFreshMirror(env, "p1 takes two lines"));
    CHECK(env.render().changedRects().has_value() && !env.render().changedRects()->empty());
}

// A paint-order property changed by a class: position and float rebuild the fork's render tree (Reset); opacity keeps
// it, and the element's node becomes a Context (a remove and an insert) with its contents moved into it.
WR_TEST(testPaintOrderChangeIsAMove) {
    RenderEnv env("<!doctype html><style>p{margin:0} .pos{position:relative;z-index:1} .fl{float:left} .op{opacity:.5}"
                  "</style><body style='margin:0'><p id=a>alpha</p><div id=t style='background:#0f0'><p>target text</p>"
                  "</div><p id=b>beta</p></body>");
    const char* const classes[] = {"pos", "fl", "op"};
    bool opacityKept = false;
    for (const char* cls : classes) {
        for (const bool on : {true, false}) {
            std::shared_ptr<const LayerTree> before = env.render().layerTree();
            const uint64_t walks = env.render().mirrorWalks();
            edit(env, std::string("document.getElementById('t').className = '") + (on ? cls : "") + "'");
            const std::vector<LayerOp>& ops = env.render().layerOps();
            const bool reset = isReset(ops);
            std::printf("  %s %s: %s\n", on ? "adding" : "removing", cls,
                        reset ? "Reset (the fork rebuilt its render tree)" : "operations");
            const std::string what = std::string(on ? "add " : "remove ") + cls;
            CHECK(flattensAsRecorded(env, what));
            CHECK(equalsAFreshMirror(env, what));
            if (reset) {
                CHECK_EQ(env.render().mirrorWalks(), walks + 1);
                continue;
            }
            CHECK_EQ(env.render().mirrorWalks(), walks);
            bool reordered = false, removed = false, inserted = false;
            for (const LayerOp& op : ops) {
                reordered = reordered || op.kind == LayerOp::Move;
                removed = removed || op.kind == LayerOp::Remove;
                inserted = inserted || op.kind == LayerOp::Insert;
            }
            CHECK(reordered || (removed && inserted));
            std::string why;
            const bool shared = before && unnamedAreShared(*before, *env.render().layerTree(), ops, why);
            if (!shared) {
                std::printf("  %s: %s\n  ops: %s\n", what.c_str(), why.c_str(), describe(ops).c_str());
            }
            CHECK(shared);
            if (std::string(cls) == "op") {
                opacityKept = true;
            }
        }
    }
    // A class change that only adds opacity is one the fork patches with its render tree kept.
    CHECK(opacityKept);
}

// A text patch and a neutral class patch in one subtree keep an untouched element's nodes, as the same objects.
WR_TEST(testIdentitySurvivesATreeKeepingPatch) {
    RenderEnv env("<!doctype html><style>p{margin:0} .c{color:#c00} .d{color:#00c}</style><body style='margin:0'>"
                  "<div id=a><p id=a1>one</p><p id=a2 class=c>two</p></div>"
                  "<div id=b><p id=b1 style='background:#eee'>keep</p></div></body>");
    const char* const scripts[] = {
        "document.getElementById('a1').firstChild.data = 'six'",
        "document.getElementById('a2').className = 'd'",
    };
    for (const char* script : scripts) {
        std::shared_ptr<const LayerTree> before = env.render().layerTree();
        const MirrorNode* keep = before ? inlineWith(*before, "keep") : nullptr;
        CHECK(keep != nullptr);
        if (!keep) {
            return;
        }
        const std::set<wr::LayerId> ids = idsWithKey(*before, keep->key);
        CHECK_EQ(ids.size(), size_t(2));
        const uint64_t patches = env.render().patchCount();
        const uint64_t builds = env.render().buildCount();
        const uint64_t walks = env.render().mirrorWalks();
        edit(env, script);
        CHECK_EQ(env.render().patchCount(), patches + 1);
        CHECK_EQ(env.render().buildCount(), builds);
        CHECK_EQ(env.render().mirrorWalks(), walks);
        CHECK(!isReset(env.render().layerOps()));
        std::shared_ptr<const LayerTree> after = env.render().layerTree();
        const auto was = nodesOf(*before);
        const auto now = nodesOf(*after);
        for (wr::LayerId id : ids) {
            const bool same = now.count(id) && was.count(id) && now.at(id) == was.at(id);
            if (!same) {
                std::printf("  b1's node %llu is not the same object after: %s\n  ops: %s\n", (unsigned long long)id, script,
                            describe(env.render().layerOps()).c_str());
            }
            CHECK(same);
        }
        std::string why;
        CHECK(unnamedAreShared(*before, *after, env.render().layerOps(), why));
        CHECK(flattensAsRecorded(env, script));
        CHECK(equalsAFreshMirror(env, script));
    }
}

// A structural edit: the fork rebuilds its render tree, so the flush publishes Reset and a mirror built afresh.
WR_TEST(testStructuralEditPublishesReset) {
    RenderEnv env("<!doctype html><style>p{margin:0}</style><body style='margin:0;height:200px'><p id=p1>one</p><p>two</p>"
                  "</body>");
    std::shared_ptr<const LayerTree> before = env.render().layerTree();
    const uint64_t patches = env.render().patchCount();
    const uint64_t walks = env.render().mirrorWalks();
    const uint64_t resets = env.render().treeRebuildResets();
    edit(env, "const p = document.createElement('p'); p.textContent = 'three'; document.body.append(p)");
    CHECK_EQ(env.render().patchCount(), patches + 1);
    CHECK(isReset(env.render().layerOps()));
    CHECK_EQ(env.render().mirrorWalks(), walks + 1);
    CHECK_EQ(env.render().treeRebuildResets(), resets + 1);
    CHECK(flattensAsRecorded(env, "append a paragraph"));
    CHECK(equalsAFreshMirror(env, "append a paragraph"));
    // A Reset publishes new nodes: none of the old ids survives.
    const auto was = nodesOf(*before);
    for (const auto& [id, node] : nodesOf(*env.render().layerTree())) {
        CHECK(!was.count(id));
    }
    CHECK(env.render().changedRects().has_value() && !env.render().changedRects()->empty());
}

// A clipper that moves takes its clip with it: what it clips gets a Frame and a Clip, its own Box a Frame alone (its
// clip covers its children, not itself), and the clip chain equals a fresh walk's (paint_clip against draw_children).
WR_TEST(testAMovedClipperClipsWhatItHolds) {
    RenderEnv env("<!doctype html><style>p{margin:0}</style><body style='margin:0;height:200px'><p id=p1>short</p>"
                  "<div style='overflow:hidden;border-radius:4px;background:#eee'><p>clipped text</p></div></body>");
    std::shared_ptr<const LayerTree> before = env.render().layerTree();
    const MirrorNode* run = before ? inlineWith(*before, "clipped") : nullptr;
    CHECK(run != nullptr);
    if (!run) {
        return;
    }
    CHECK_EQ(run->clips.size(), size_t(1));
    const wr::LayerId runId = run->id;
    // The div's Box: the Box keyed as the clip's clipper is.
    wr::LayerId boxId = 0;
    for (const auto& [id, node] : nodesOf(*before)) {
        if (node->kind == MirrorNode::Kind::Box && !run->clips.empty() && node->key == run->clips[0].key) {
            boxId = id;
        }
    }
    CHECK(boxId != 0);
    const uint64_t patches = env.render().patchCount();
    const uint64_t walks = env.render().mirrorWalks();
    edit(env, "document.getElementById('p1').firstChild.data = 'a first paragraph long enough to take two lines'");
    CHECK_EQ(env.render().patchCount(), patches + 1);
    CHECK_EQ(env.render().mirrorWalks(), walks);
    const std::vector<LayerOp>& ops = env.render().layerOps();
    CHECK(!isReset(ops));
    std::map<wr::LayerId, std::set<LayerOp::Kind>> named;
    for (const LayerOp& op : ops) {
        named[op.node].insert(op.kind);
    }
    const bool runFramed = named.count(runId) && named[runId] == std::set<LayerOp::Kind>{LayerOp::Frame, LayerOp::Clip};
    const bool boxFramed = named.count(boxId) && named[boxId] == std::set<LayerOp::Kind>{LayerOp::Frame};
    if (!runFramed || !boxFramed) {
        std::printf("  ops: %s\n", describe(ops).c_str());
    }
    CHECK(runFramed);
    CHECK(boxFramed);
    std::shared_ptr<const LayerTree> after = env.render().layerTree();
    const auto now = nodesOf(*after);
    CHECK(now.count(runId) && now.at(runId)->clips.size() == 1 &&
          now.at(runId)->clips[0].box.y.value() > run->clips[0].box.y.value());
    CHECK(flattensAsRecorded(env, "the clipper moved"));
    CHECK(equalsAFreshMirror(env, "the clipper moved"));
}

// A table paints every caption before any row (render_item_table::draw_children), so in its context a caption that
// follows the rows in the tree paints before them: there the context's children are not in tree order, and the
// placement rule cannot place a new node (Ruling E39). A neutral class change that gives a cell, a row or the caption its
// first decoration keeps the render tree; the mirror declines it, and the Reset's tree is a fresh mirror's. A caption
// before the rows paints in tree order, so there the same change is an Insert.
WR_TEST(testANewBoxBesideACaptionAfterTheRowsIsAReset) {
    // The caption has a Box of its own unless it is the target: in the table's block pass it then paints before the
    // cells' Boxes, which it follows in the tree.
    const char* const targets[] = {"td2", "tr2", "cap"};
    for (const bool after : {true, false}) {
        for (const std::string target : targets) {
            const std::string caption =
                "<caption id=cap" + std::string(target == "cap" ? "" : " style='border:1px solid #000'") + ">cap</caption>";
            const std::string rows = "<tr><td class=y>c1</td></tr><tr id=tr2><td id=td2>c2</td></tr>";
            RenderEnv env("<!doctype html><style>.y{background-color:#eee} .d{background-color:#ff0} td{padding:2px}</style>"
                          "<body style='margin:0;height:200px'><table style='background-color:#ddd'>" +
                          (after ? rows + caption : caption + rows) + "</table></body>");
            CHECK(env.render().renderInput().find(after ? "</tbody><caption" : "</caption><tbody") != std::string::npos);
            const uint64_t patches = env.render().patchCount();
            const uint64_t lost = env.render().unplaceableResets();
            const std::shared_ptr<const LayerTree> before = env.render().layerTree();
            const std::string what =
                "the first decoration of #" + target + (after ? ", the caption after the rows" : ", the caption first");
            edit(env, "document.getElementById('" + target + "').setAttribute('class', 'd')");
            CHECK_EQ(env.render().patchCount(), patches + 1);
            const std::vector<LayerOp>& ops = env.render().layerOps();
            bool expected = isReset(ops) == after && env.render().unplaceableResets() == lost + (after ? 1 : 0);
            if (!after) {
                // One Insert, placed where a fresh walk has it.
                IdTree structure = IdTree::of(*before->mirror());
                size_t inserts = 0;
                for (const LayerOp& op : ops) {
                    expected = structure.apply(op) && expected;
                    inserts += op.kind == LayerOp::Insert;
                }
                expected = expected && inserts == 1 && structure == IdTree::of(*env.render().layerTree()->mirror());
            }
            if (!expected) {
                std::printf("  unexpected ops: %s\n  ops: %s\n", what.c_str(), describe(ops).c_str());
            }
            CHECK(expected);
            CHECK(flattensAsRecorded(env, what));
            CHECK(equalsAFreshMirror(env, what));
        }
    }
}
