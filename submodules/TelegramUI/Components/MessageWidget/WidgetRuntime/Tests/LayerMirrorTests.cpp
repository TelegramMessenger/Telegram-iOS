// The layer mirror (M1c plan, Task 10b; twidget edit 20): the published tree mirrors litehtml's painting as Context, Box
// and Inline nodes with stable identity, and a patch the fork's render tree survives is published as operations the fork
// reported at its own mutation points, with nothing compared. Task 4's recorder is the oracle: a mirror flattens to what
// WidgetContainer::record paints, less what no painting node owns (Ruling E37).
#include <algorithm>
#include <cctype>
#include <cmath>
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
#include "Sources/Host/HostState.h"
#include "Sources/Support/Errors.h"
#include "Tests/IncrementalEdits.h"
#include "Tests/LayerChurn.h"
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

const char* opName(LayerOp::Kind kind) {
    switch (kind) {
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

// Every node of `after` that no op names and that is not an ancestor of a named one, in `after` or in `before` (a Remove
// or a Move changes the parent it leaves), is `before`'s node with its id.
bool unnamedAreShared(const LayerTree& before, const LayerTree& after, const std::vector<LayerOp>& ops, std::string& why) {
    std::map<wr::LayerId, const MirrorNode*> was, now;
    std::map<wr::LayerId, wr::LayerId> parents, formerParents;
    if (before.mirror()) {
        collect(*before.mirror(), was, &formerParents);
    }
    if (after.mirror()) {
        collect(*after.mirror(), now, &parents);
    }
    std::set<wr::LayerId> touched;
    for (const LayerOp& op : ops) {
        for (wr::LayerId id : {op.node, op.parent}) {
            for (const auto* chain : {&parents, &formerParents}) {
                for (wr::LayerId at = id; at != 0; at = chain->count(at) ? chain->at(at) : 0) {
                    touched.insert(at);
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

// Two dumps alike but for float noise: the same text, and every number within 1/1000 px. Positions are floats (pixel_t),
// about 6e-5 px apart near 1,000 px, and a Box a Frame operation moved keeps its content's offsets as they were captured
// against its old origin, where a fresh mirror subtracts the new one: 5.33334 against 5.33333.
bool sameButForFloatNoise(const std::string& a, const std::string& b) {
    auto isNumberStart = [](const std::string& s, size_t i) {
        return std::isdigit(static_cast<unsigned char>(s[i])) ||
               ((s[i] == '-' || s[i] == '.') && i + 1 < s.size() && std::isdigit(static_cast<unsigned char>(s[i + 1])));
    };
    size_t i = 0;
    size_t j = 0;
    while (i < a.size() && j < b.size()) {
        if (isNumberStart(a, i) && isNumberStart(b, j)) {
            size_t ai = 0;
            size_t bj = 0;
            const double x = std::stod(a.substr(i, 32), &ai);
            const double y = std::stod(b.substr(j, 32), &bj);
            if (std::fabs(x - y) > 1e-3) {
                return false;
            }
            i += ai;
            j += bj;
            continue;
        }
        if (a[i] != b[j]) {
            return false;
        }
        i++;
        j++;
    }
    return i == a.size() && j == b.size();
}

// The published mirror equals a freshly built one: kinds, keys, order, origins, passes, clip chains and content (numbers
// up to float noise).
bool equalsAFreshMirror(RenderEnv& env, const std::string& what) {
    std::shared_ptr<const LayerTree> tree = env.render().layerTree();
    std::shared_ptr<const LayerTree> rebuilt = env.render().freshMirrorForTesting();
    if (!tree || !tree->mirror() || !rebuilt || !rebuilt->mirror()) {
        return false;
    }
    const std::string ours = wr::dumpMirror(*tree->mirror());
    const std::string theirs = wr::dumpMirror(*rebuilt->mirror());
    if (!sameButForFloatNoise(ours, theirs)) {
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
               " li:last-child{border-bottom:2px solid #00f} p:first-child{padding-left:3px} li:last-child b{color:#c60}";
    const auto pageOf = [](const std::string& sheet, const std::string& prefix) {
        return wr_test::editPage(sheet, "", prefix);
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
        /// The kinds the group draws from (kEditHelpersJS's), when not the general mix.
        std::vector<uint32_t> kinds = {};
        /// Between batches, with a chance of 1 in 6 each: a new width, the other theme, reduced motion toggled, a tap.
        bool environment = false;
        /// Between batches, one animation frame of 16 ms, whose flush is the batch's.
        bool animated = false;
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
        // Every kind of change (the incremental render plan, Task 8), as the render oracle has them.
        {"attributes", 50, 52, base, "", false, {21, 21, 21, 0, 1, 2, 3, 4}},
        {"box types", 53, 55, base, "", false, {22, 22, 22, 0, 1, 2, 3, 4}},
        {"sheets", 56, 58, base, "", false, {23, 23, 25, 25, 0, 1, 2, 3, 4}},
        {"document element", 59, 61, base, "", false, {24, 24, 6, 7}},
        {"environment", 62, 64, base + wr_test::kEnvironmentSheet, "", false, {}, true},
        {"animated with structure", 65, 67,
         base + " @keyframes turn{from{transform:rotate(0deg)}to{transform:rotate(360deg)}}"
                " .x{animation:turn 1s linear infinite} .y{animation:turn 2s linear infinite}",
         "", false, {0, 1, 2, 3, 4}, false, true},
        // The incremental render plan, Step 5: the document's own head and body, and a <br>'s attributes.
        {"document level", 101, 103, base, "", false, {29, 29, 29, 0, 6, 9}},
        {"br attributes", 104, 106, base + " br.x{display:block;height:4px} br.box{border:1px solid #000}", "", false,
         {30, 30, 30, 0, 2}},
        // Twidget edit 88: :empty beside sibling combinators whose rules change boxes and content.
        {":empty beside sibling combinators", 110, 112,
         base + " :empty + *{display:none} div:not(:empty) + p::before{content:'e'} p:empty ~ span{float:left;width:9px}"
                " li:empty ~ li b{display:block}",
         "", false, {0, 1, 2, 3, 4}},
    };
    const std::string helpers = wr_test::kEditHelpersJS;
    uint64_t flushes = 0, kept = 0, builds = 0, frames = 0, contents = 0, inserts = 0,
             moves = 0, removes = 0, multiple = 0;
    // The layers each flush re-creates though their element did not change (the churn metric, Tests/LayerChurn.h).
    wr_test::ChurnTally churn;
    for (const Group& group : groups) {
        // Taps that changed what :hover or :active match: an environment group must have some.
        uint64_t actionChanges = 0;
        for (int seed = group.firstSeed; seed <= group.lastSeed; seed++) {
            RenderEnv env(pageOf(group.sheet, group.prefix));
            wr_test::ScopedChurnProbe churnProbe(env.render(), churn);
            CHECK_EQ(env.env().eval(helpers), std::string("ok"));
            env.render().takeChangedRects();
            std::mt19937 rng{uint32_t(seed)};
            int edits = 0;
            bool reported = false;
            while (edits < 200) {
                const int batch = 1 + int(rng() % 5);
                std::string done;
                for (int k = 0; k < batch && edits < 200; k++, edits++) {
                    // Class and text edits only (kEditHelpersJS's kinds 6 and 9).
                    static const uint32_t kKeepTreeKinds[] = {6, 9, 9, 9};
                    const uint32_t drawn = uint32_t(rng() % 13);
                    const uint32_t kind = group.keepTree        ? kKeepTreeKinds[drawn % 4]
                                          : !group.kinds.empty() ? group.kinds[rng() % group.kinds.size()]
                                                                 : drawn,
                                   a = uint32_t(rng() % 1000),
                                   b = uint32_t(rng() % 1000), c = uint32_t(rng() % 1000);
                    const std::string call = "__edit(" + std::to_string(kind) + ", " + std::to_string(a) + ", " +
                                             std::to_string(b) + ", " + std::to_string(c) + ")";
                    done += (done.empty() ? "" : "; ") + env.env().eval(call) + " " + call;
                }
                if (group.environment) {
                    switch (rng() % 6) {
                    case 0: {
                        static const double kWidths[] = {360, 300, 250};
                        const double width = kWidths[rng() % 3];
                        env.render().setWidth(env.ctx(), width);
                        done += "; width " + std::to_string(int(width));
                        break;
                    }
                    case 1: {
                        const wr::Theme theme = env.render().options().theme == wr::Theme::Light ? wr::Theme::Dark : wr::Theme::Light;
                        env.render().setTheme(env.ctx(), theme, wr_test::themeDeclarations(theme));
                        done += theme == wr::Theme::Dark ? "; dark" : "; light";
                        break;
                    }
                    case 2:
                        env.render().setReducedMotion(env.ctx(), !env.render().options().reducedMotion);
                        done += "; reduced motion toggled";
                        break;
                    case 3: {
                        const double x = double(rng() % 300), y = double(rng() % 400);
                        const auto actionState = [&] {
                            return env.env().eval("[...document.querySelectorAll(':hover, :active')].length + ''");
                        };
                        const std::string was = actionState();
                        // Each pointer event is a task, run when the loop drains.
                        try {
                            wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Down, x, y, 7, true);
                            env.env().drain();
                            wr::HostState::of(env.ctx()).pointer(env.ctx(), wr::PointerPhase::Up, x, y, 7, true);
                            env.env().drain();
                        } catch (const wr::Aborted&) {
                        }
                        actionChanges += actionState() != was;
                        done += "; tap " + std::to_string(int(x)) + "," + std::to_string(int(y));
                        break;
                    }
                    default:
                        break;
                    }
                }
                std::shared_ptr<const LayerTree> before = env.render().layerTree();
                const uint64_t walks = env.render().mirrorWalks();
                const uint64_t patches = env.render().patchCount();
                const uint64_t built = env.render().buildCount();
                if (group.animated) {
                    // The frame's flush is this batch's.
                    env.env().frame(16.0);
                }
                env.flush();
                // Nothing after the boot builds, and nothing stops the widget.
                if ((env.render().buildCount() != built || env.env().runtime().stopReason() != wr::StopReason::None) &&
                    !reported) {
                    std::printf("  built or stopped, %s seed %d: %s\n", group.name, seed, done.c_str());
                }
                CHECK_EQ(env.render().buildCount(), built);
                CHECK(env.env().runtime().stopReason() == wr::StopReason::None);
                if (env.render().patchCount() == patches && env.render().buildCount() == built) {
                    continue;   // clean: nothing was published
                }
                flushes++;
                std::shared_ptr<const LayerTree> after = env.render().layerTree();
                const std::vector<LayerOp> ops = env.render().layerOps();
                const bool patched = env.render().patchCount() != patches;
                const std::string what = "seed " + std::to_string(seed) + ", edit " + std::to_string(edits) + " (" +
                                         (patched ? "patched" : "built") + "): " + done;
                builds += !patched;
                bool same = flattensAsRecorded(env, what);
                same = equalsAFreshMirror(env, what) && same;
                std::string why;
                // A batch that published more than once (an animation frame's second pass publishes what its
                // style-change step started) is held to its end state alone: the fresh mirror, the recorded tree and
                // the union of its rects. The operations and walks below are one publish's.
                const uint64_t publishes = (env.render().patchCount() - patches) + (env.render().buildCount() - built);
                if (publishes > 1) {
                    multiple++;
                } else {
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
                }
                // The union of the batch's publishes (an animation frame can publish twice), as the app draws from it,
                // against the diff of the published trees: they are held equal to fresh ones above, and share every node
                // no operation names, which the diff matches by identity before it matches the rest by key. A batch that
                // built shares nothing with the tree before it (the diff then matches anonymous nodes by their order
                // alone, which an insertion after the build shifts), and a build's rects are that diff's: it is held to
                // its end state alone.
                const std::optional<std::vector<litehtml::position>> changed = env.render().takeChangedRects();
                if (env.render().buildCount() == built && !covers(changed, wr::changedRects(before.get(), *after), why)) {
                    same = false;
                }
                if (!same && !reported) {
                    std::printf("  after: %s\n  %s\n  ops: %s\n", what.c_str(), why.c_str(), describe(ops).c_str());
                }
                reported = reported || !same;
                CHECK(same);
            }
        }
        if (group.environment) {
            std::printf("  %s: %llu taps changed :hover or :active\n", group.name, (unsigned long long)actionChanges);
        }
        CHECK(!group.environment || actionChanges > 0);
    }
    std::printf("  %llu flushes: %llu published operations (%llu frames, %llu contents, %llu inserts, %llu moves, %llu"
                " removes), %llu full builds, %llu batches that published more than once\n",
                (unsigned long long)flushes, (unsigned long long)kept, (unsigned long long)frames,
                (unsigned long long)contents, (unsigned long long)inserts, (unsigned long long)moves,
                (unsigned long long)removes, (unsigned long long)builds, (unsigned long long)multiple);
    std::printf("churn (ops oracle): %s", churn.describe().c_str());
    // The fixture reaches every kind of operation, and a replaced render subtree, the root's included, is placed.
    CHECK(kept > 0);
    CHECK(inserts > 0 && removes > 0);
}

// The boot's first publish is Inserts into an empty structure, so the stream a layer backend reads has one shape from the
// start: every op an Insert, the root's first under parent 0, and replayed they give the published tree, a group, a
// clipper, a positioned child and a table with a caption included; a fresh tree's build publishes the same.
WR_TEST(testTheBootPublishesInserts) {
    RenderEnv env("<!doctype html><style>body{margin:0} .g{opacity:.5} .c{overflow:hidden;height:20px}"
                  " .r{position:relative} .a{position:absolute;left:3px}</style><body><div class=g><p>group</p></div>"
                  "<div class=c><p>clipped</p><p>more</p></div><div class=r><span class=a>abs</span>rel</div>"
                  "<table><caption>cap</caption><tr><td>cell</td></tr></table></body>");
    wr::RenderTree fresh(env.ctx(), env.host(), env.render().options());
    fresh.build(env.ctx());
    for (wr::RenderTree* tree : {&env.render(), &fresh}) {
        const std::vector<LayerOp>& ops = tree->layerOps();
        const std::string why = wr_test::insertsMismatch(*tree->layerTree(), ops);
        if (!why.empty()) {
            std::printf("  %s: %s\n", tree == &fresh ? "a fresh tree's build" : "the boot", why.c_str());
        }
        CHECK(why.empty());
        CHECK(ops.size() > 4 && ops[0].parent == 0 && ops[0].node == tree->layerTree()->mirror()->id);
    }
}

// The mirror diff matches the nodes two trees share first (a mirror's publishes share every node no operation names):
// a node removed and one inserted elsewhere with its key give their own rects, not a reorder of everything shared.
WR_TEST(testTheMirrorDiffMatchesSharedNodesFirst) {
    RenderEnv env("<!doctype html><style>p{margin:0}</style><body style='margin:0;height:200px'><p>a</p><p>b</p><p>c</p></body>");
    const std::shared_ptr<const LayerTree> tree = env.render().layerTree();
    const MirrorNode& root = *tree->mirror();
    CHECK_EQ(root.children.size(), size_t(3));
    if (root.children.size() != 3) {
        return;
    }
    const auto& children = root.children;
    auto elsewhere = [&](wr::LayerId id, float y, wr::NodeKey key = 99) {
        auto node = std::make_shared<MirrorNode>(*children[0]);
        node->id = id;
        node->key = key;
        node->origin.y = y;
        return std::shared_ptr<const MirrorNode>(node);
    };
    auto treeOf = [&](std::vector<std::shared_ptr<const MirrorNode>> nodes) {
        auto copy = std::make_shared<MirrorNode>(root);
        copy->children = std::move(nodes);
        return std::make_shared<const LayerTree>(tree->width(), tree->height(), std::shared_ptr<const MirrorNode>(copy));
    };
    auto onlyBelow = [](const std::optional<std::vector<litehtml::position>>& rects) {
        CHECK(rects && !rects->empty());
        if (rects) {
            for (const auto& rect : *rects) {
                CHECK(rect.y.value() >= 140);
            }
        }
    };
    onlyBelow(wr::changedRects(treeOf({children[0], elsewhere(1001, 150), children[1], children[2]}).get(),
                               *treeOf({children[0], children[1], children[2], elsewhere(1002, 170)})));
    // Two matched by key that swap places between the same shared ones, painting the same: their order changed.
    onlyBelow(wr::changedRects(
        treeOf({children[0], elsewhere(1003, 150, 98), elsewhere(1004, 150, 99), children[1], children[2]}).get(),
        *treeOf({children[0], elsewhere(1005, 150, 99), elsewhere(1006, 150, 98), children[1], children[2]})));
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
        {
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
// shaped again is paragraph 1's. (A whole-pixel line: a fractional move paints again, testAFractionalMovePaintsAgain.)
WR_TEST(testAMovedParagraphIsAFrameNotACapture) {
    RenderEnv env("<!doctype html><style>p{margin:0;background:#eee;line-height:20px}</style><body style='margin:0;height:200px'>"
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

// v0.1.1 plan, Task 2: the UA layer's line height (1.35 of 15px: 20.25px) moves the paragraphs after one that gains a
// line by a fraction of a pixel, and painting rounds in document coordinates, so the moved content is painted again
// (Content) rather than framed alone, and the mirror is a fresh one's.
WR_TEST(testAFractionalMovePaintsAgain) {
    RenderEnv env("<!doctype html><style>p{margin:0;background:#eee}</style><body style='margin:0;height:200px'>"
                  "<p id=p1>short</p><p id=p2>the second paragraph</p><p id=p3>the third</p></body>");
    std::shared_ptr<const LayerTree> before = env.render().layerTree();
    const MirrorNode* second = before ? inlineWith(*before, "second") : nullptr;
    CHECK(second != nullptr);
    if (!before || !second) {
        return;
    }
    const std::set<wr::LayerId> moved = idsWithKey(*before, second->key);
    const uint64_t builds = env.render().buildCount();
    edit(env, "document.getElementById('p1').firstChild.data = 'a first paragraph long enough to take two lines'");
    CHECK_EQ(env.render().buildCount(), builds);
    std::map<wr::LayerId, std::set<LayerOp::Kind>> named;
    for (const LayerOp& op : env.render().layerOps()) {
        named[op.node].insert(op.kind);
    }
    for (wr::LayerId id : moved) {
        CHECK(named.count(id) && named[id].count(LayerOp::Content));
    }
    CHECK(equalsAFreshMirror(env, "a fractional move"));
}

// A paint-order property changed by a class: position and float replace the element's render subtree (placed again);
// opacity keeps it, and the element's node becomes a Context (a remove and an insert) with its contents moved into it.
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
            const std::string what = std::string(on ? "add " : "remove ") + cls;
            CHECK(flattensAsRecorded(env, what));
            CHECK(equalsAFreshMirror(env, what));
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

// A flush that re-placed what changed (Step 3): published as operations and no build walk, replayed on the
// previous tree into the new one, every node no operation names the same object, and equal to a fresh mirror.
bool placedWithOperations(RenderEnv& env, const std::string& script, const std::string& what) {
    std::shared_ptr<const LayerTree> before = env.render().layerTree();
    const uint64_t patches = env.render().patchCount();
    const uint64_t walks = env.render().mirrorWalks();
    edit(env, script);
    const std::vector<LayerOp>& ops = env.render().layerOps();
    std::shared_ptr<const LayerTree> after = env.render().layerTree();
    std::string why;
    if (env.render().patchCount() != patches + 1) {
        why = "not one patch";
    } else if (env.render().mirrorWalks() != walks) {
        why = "walked as a build";
    } else {
        IdTree structure = IdTree::of(*before->mirror());
        bool applies = true;
        for (const LayerOp& op : ops) {
            applies = structure.apply(op) && applies;
        }
        if (!applies || !(structure == IdTree::of(*after->mirror()))) {
            why = "the ops do not replay into the new tree";
        } else {
            unnamedAreShared(*before, *after, ops, why);
        }
    }
    if (!why.empty()) {
        std::printf("  %s: %s\n  ops: %s\n", what.c_str(), why.c_str(), describe(ops).c_str());
    }
    const bool flattens = flattensAsRecorded(env, what);
    const bool fresh = equalsAFreshMirror(env, what);
    return why.empty() && flattens && fresh;
}

size_t countOps(const std::vector<LayerOp>& ops, LayerOp::Kind kind) {
    return size_t(std::count_if(ops.begin(), ops.end(), [kind](const LayerOp& op) { return op.kind == kind; }));
}

// A structural edit the fork does not link (inline content beside a block, twidget edit 89) replaces #b's render subtree
// (edit 74), and the mirror removes its old nodes and inserts the new ones where a fresh walk has them; #a's nodes are
// the same objects, the paragraph after moves.
WR_TEST(testAReplacedSubtreeIsPlacedWithOperations) {
    RenderEnv env("<!doctype html><style>p{margin:0} div{border:1px solid #000;margin:2px}</style><body style='margin:0;height:200px'>"
                  "<div id=a><p>a</p></div><div id=b><p>b</p></div><p>after</p></body>");
    CHECK(placedWithOperations(env, "const s = document.createElement('span'); s.textContent = 'new'; document.getElementById('b').append(s)",
                               "a span appended to #b"));
    const std::vector<LayerOp>& ops = env.render().layerOps();
    CHECK(countOps(ops, LayerOp::Remove) > 0);
    CHECK(countOps(ops, LayerOp::Insert) > 0);
    CHECK(countOps(ops, LayerOp::Frame) > 0);
}

// A block appended to #b is linked (twidget edit 89): the mirror inserts its nodes where a fresh walk has them and removes
// none; #b's border is re-captured and the paragraph after moves.
WR_TEST(testALinkedSubtreeIsPlacedWithOperations) {
    RenderEnv env("<!doctype html><style>p{margin:0} div{border:1px solid #000;margin:2px}</style><body style='margin:0;height:200px'>"
                  "<div id=a><p>a</p></div><div id=b><p>b</p></div><p>after</p></body>");
    CHECK(placedWithOperations(env, "const p = document.createElement('p'); p.textContent = 'new'; document.getElementById('b').append(p)",
                               "a paragraph appended to #b"));
    const std::vector<LayerOp>& ops = env.render().layerOps();
    CHECK_EQ(countOps(ops, LayerOp::Remove), size_t(0));
    CHECK(countOps(ops, LayerOp::Insert) > 0);
    CHECK(countOps(ops, LayerOp::Frame) > 0);
}

// A run whose text was replaced is placed by its new first piece: a later re-placement before it renumbers it by that.
WR_TEST(testARunWhoseTextWasReplacedKeepsItsPlace) {
    RenderEnv env("<!doctype html><style>p{margin:0}</style><body style='margin:0;height:200px'>"
                  "<p>one</p><div id=b><p>b</p></div><p id=c>three</p></body>");
    CHECK(placedWithOperations(env, "document.getElementById('c').firstChild.data = 'three, changed'", "#c's text"));
    CHECK(placedWithOperations(env, "const p = document.createElement('p'); p.textContent = 'new'; document.getElementById('b').append(p)",
                               "a paragraph appended to #b before #c"));
}

// A text replaced in the publish that replaces a subtree before it: its run is placed by its new pieces, not its old.
WR_TEST(testATextReplacedBesideAReplacementKeepsItsPlace) {
    RenderEnv env("<!doctype html><style>p{margin:0} .k::before{content:'one two three four five six seven'}</style>"
                  "<body style='margin:0;height:300px'><div id=b><p>b</p></div><p id=c>three</p></body>");
    CHECK(placedWithOperations(env, "document.getElementById('b').className = 'k'; document.getElementById('c').firstChild.data = 'changed'",
                               "::before content into #b, and #c's text"));
}

// The root paints the body's background when it has none of its own: a replaced body repaints the canvas.
WR_TEST(testAReplacedBodyRepaintsTheCanvas) {
    RenderEnv env("<!doctype html><style>p{margin:0} .y{background:#ff0;font-size:20px}</style><body style='margin:0;height:200px'>"
                  "<p>a</p></body>");
    CHECK(placedWithOperations(env, "document.body.className = 'y'", "a background and a font size on the body"));
}

// Review Focus 1: a positioned descendant of the replaced subtree paints in a stacking context outside it.
WR_TEST(testAReplacedSubtreesPositionedChildPaintsOutside) {
    RenderEnv env("<!doctype html><style>p{margin:0}</style><body style='margin:0;height:200px'><div style='position:relative'>"
                  "<div id=b><span style='position:absolute;left:5px;top:7px;z-index:2;background:#ff0'>abs</span></div></div></body>");
    CHECK(placedWithOperations(env, "const s = document.createElement('span'); s.textContent = 'new'; document.getElementById('b').append(s)",
                               "a span beside a positioned span"));
}

// Review Focus 2: an inline-block replaced in a line goes back between the line's runs.
WR_TEST(testAnInlineBoxReplacedInALineKeepsItsPlace) {
    RenderEnv env("<!doctype html><style>.big{font-size:24px} #k{background:#eee}</style><body style='margin:0;height:200px'>"
                  "<p>text <span id=k style='display:inline-block'>k</span> more text</p></body>");
    CHECK(placedWithOperations(env, "document.getElementById('k').setAttribute('class', 'big')", "an inline-block's font size"));
}

// Review Focus 3: two replacements in one publish, and a text replacement inside a subtree the same publish replaces
// (an attribute change beside a text change is one patch), whose report the re-placement makes stale.
WR_TEST(testReplacementsInOnePublish) {
    {
        RenderEnv env("<!doctype html><style>p{margin:0} div{border:1px solid #000}</style><body style='margin:0;height:200px'>"
                      "<div id=x><p>x</p></div><div id=y><p>y</p></div></body>");
        CHECK(placedWithOperations(env,
                                   "for (const id of ['x', 'y']) { const p = document.createElement('p'); p.textContent = id + id;"
                                   " document.getElementById(id).append(p); }",
                                   "an append into each of two siblings"));
    }
    {
        RenderEnv env("<!doctype html><style>p{margin:0} .big{font-size:24px}</style><body style='margin:0;height:200px'>"
                      "<div id=b><p id=q>q</p></div><p>after</p></body>");
        CHECK(placedWithOperations(env, "document.getElementById('b').className = 'big';"
                                        " document.getElementById('q').firstChild.data = 'changed'",
                                   "a text change inside a subtree the fork replaces"));
    }
}

// A line whose runs a re-placement builds again moves an inline paint group in it, which nothing reports: its inline
// context is built again whole.
WR_TEST(testALineHoldingAGroupIsBuiltWhole) {
    const char* const page = "<!doctype html><style>p{margin:0} .big{font-size:24px}</style><body style='margin:0;height:200px'>"
                             "<p id=p>text <span id=k style='display:inline-block'>k</span> then <span style='opacity:.5'>faded"
                             "</span> end</p><p>q <span id=s>s</span></p></body>";
    {
        RenderEnv env(page);
        CHECK(placedWithOperations(env, "document.getElementById('k').className = 'big'", "an inline-block before the group grows"));
    }
    {
        RenderEnv env(page);
        CHECK(placedWithOperations(env, "document.getElementById('p').firstChild.data = 'a much longer text ';"
                                        " document.getElementById('s').style.opacity = '.5'",
                                   "the text before the group, beside a span placed again"));
    }
}

// Review Focus 4: a change of paint order or visibility anywhere but a plain in-flow block is re-placed (its subtree's
// nodes removed and built again by the placement rule), not reset.
WR_TEST(testPaintOrderChangesArePlaced) {
    struct Case {
        const char* body;
        std::vector<const char*> scripts;
        const char* what;
    };
    const Case cases[] = {
        {"<p>text <span id=t>span</span> more text</p>", {"document.getElementById('t').style.opacity = '.5'"},
         "opacity on an inline span in a line"},
        {"<div id=t style='float:left;width:40px;height:20px;background:#ccc'>f</div><p>text beside the float</p>",
         {"document.getElementById('t').style.opacity = '.5'"}, "opacity on a float"},
        {"<div id=t style='background:#eee'>text<span style='position:absolute;left:5px;top:30px;background:#ff0'>abs</span></div>",
         {"document.getElementById('t').style.visibility = 'hidden'", "document.getElementById('t').style.visibility = 'visible'"},
         "visibility on a div holding a positioned child"},
        {"<div id=t style='position:relative;z-index:1;height:20px;background:#eee'>a</div>"
         "<div style='position:relative;z-index:2;margin-top:-10px;height:20px;background:#ccc'>b</div>",
         {"document.getElementById('t').style.zIndex = '3'"}, "z-index on a positioned box"},
        {"<div style='margin-top:20px'><div id=t>x<span style='position:absolute;left:5px;top:5px;background:#ff0'>abs</span>"
         "</div></div>",
         {"document.getElementById('t').style.position = 'relative'"}, "position:relative over a positioned descendant"},
        {"<div id=t style='background:#eee'><p>text <span id=s>span</span> more</p></div>",
         {"document.getElementById('t').style.opacity = '.5'; document.getElementById('s').style.opacity = '.5'",
          "document.getElementById('t').style.opacity = ''; document.getElementById('s').style.opacity = ''"},
         "a block's group in place around a span placed again"},
        {"<div id=t style='background:#eee'><div id=b><p>b</p></div><p>after</p></div>",
         {"document.getElementById('t').style.opacity = '.5'; document.getElementById('b').className = 'big'",
          "document.getElementById('t').style.opacity = ''; document.getElementById('b').className = ''"},
         "a block's group in place around a subtree the fork replaced"},
        {"<div id=t style='opacity:.5;background:#eee'><div id=b style='background:#ccc;height:10px'></div><p>after</p></div>",
         {"document.getElementById('t').style.opacity = ''; document.getElementById('b').className = 'h'"},
         "a group left around a subtree the fork replaced with nothing visible"},
    };
    for (const Case& c : cases) {
        RenderEnv env(std::string("<!doctype html><style>p{margin:0} .big{font-size:24px} .h{visibility:hidden;font-size:24px}"
                                  "</style>"
                                  "<body style='margin:0;height:200px'>") + c.body +
                      "</body>");
        for (const char* script : c.scripts) {
            CHECK(placedWithOperations(env, script, std::string(c.what) + ": " + script));
        }
    }
}

// A line holding an inline paint group changes in place: a change of its text or its style, or of the group's own text,
// re-places the line's inline context whole (the group moves with the text before it, which nothing reports).
WR_TEST(testALineHoldingAGroupChangesInPlace) {
    const char* const scripts[][2] = {
        {"document.getElementById('p').firstChild.data = 'a much longer start '", "the text before the group"},
        {"document.getElementById('p').className = 'red'", "a color class on the line's paragraph"},
        {"document.getElementById('s').firstChild.data = 'changed'", "the group's own text"},
    };
    for (const auto& [script, what] : scripts) {
        RenderEnv env("<!doctype html><style>p{margin:0} .red{color:#c00}</style><body style='margin:0;height:200px'>"
                      "<p id=p>start <span id=s style='opacity:.5'>faded</span> end</p><p>after</p></body>");
        CHECK(placedWithOperations(env, script, what));
    }
}

// The root's replacement (a change of the document element the fork does not keep the tree for) is placed with
// operations: the root Context keeps its id, its children go, and the new tree's top nodes are inserted under it.
WR_TEST(testTheRootsReplacementIsPlaced) {
    const char* const scripts[][2] = {
        {"document.documentElement.className = 'flex'", "a class that makes the root a flex container"},
        {"document.documentElement.dir = 'rtl'", "dir"},
        {"document.documentElement.style.fontSize = '20px'", "an inline font size"},
    };
    for (const auto& [script, what] : scripts) {
        RenderEnv env("<!doctype html><style>p{margin:0} .flex{display:flex}</style><body style='margin:0;height:200px'>"
                      "<p>one <span>two</span></p><div style='position:relative'><span style='position:absolute;left:5px'>"
                      "abs</span></div></body>");
        CHECK(placedWithOperations(env, script, what));
    }
}

// A clipper that moves takes its clip with it: what it clips gets a Frame and a Clip, its own Box a Frame alone (its
// clip covers its children, not itself), and the clip chain equals a fresh walk's (paint_clip against draw_children).
WR_TEST(testAMovedClipperClipsWhatItHolds) {
    RenderEnv env("<!doctype html><style>p{margin:0;line-height:20px}</style><body style='margin:0;height:200px'><p id=p1>short</p>"
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

// A table row paints its cells' backgrounds itself (draw_background): a text change in another row that widens a column
// moves and resizes the row's cells without changing the row, and the row's own paint is captured again (found by
// testOpsMatchAFreshMirror's seed 4 once profile 1 dropped the fixture's inputs, V4 plan, Task 4).
WR_TEST(testARowRepaintsWhenItsCellsMove) {
    RenderEnv env("<!doctype html><style>td{padding:2px}</style><body style='margin:0'><table>"
                  "<tr style='background:#ccc'><td>a</td><td>b</td></tr><tr><td id=w>c</td><td>d</td></tr></table></body>");
    const uint64_t patches = env.render().patchCount();
    edit(env, "document.getElementById('w').firstChild.data = 'a much wider first column'");
    CHECK_EQ(env.render().patchCount(), patches + 1);
    CHECK(flattensAsRecorded(env, "a column widened"));
    CHECK(equalsAFreshMirror(env, "a column widened"));
}

// A line whose runs an inline table splits (ItemInfo::runsSplit) is placed again whole when its text changes, as a line
// holding an inline paint group is; the mirror publishes operations.
WR_TEST(testAnInlineTableLineIsPlacedAgain) {
    {
        RenderEnv env("<!doctype html><body style='margin:0'><p id=q>p <span style='display:inline-table'>"
                      "<span style='display:table-cell'>c</span></span> x</p></body>");
        edit(env, "document.getElementById('q').firstChild.data = 'pp '");
        CHECK(equalsAFreshMirror(env, "an inline table's line, its text changed"));
        CHECK(flattensAsRecorded(env, "an inline table's line, its text changed"));
        edit(env, "document.getElementById('q').lastChild.data = ' x and more words after the table'");
        CHECK(equalsAFreshMirror(env, "an inline table's line, its last text changed"));
    }
    {
        RenderEnv env("<!doctype html><style>.x{color:#c00}</style><body style='margin:0'><p id=p>text</p></body>");
        edit(env, "document.getElementById('p').setAttribute('class', 'x')");
    }
}

// Twidget edit 86: an inline-flex's flex items (blockified, block-level) are painted once, in its own context, so a
// structural patch that moves the line holding it moves its nodes, as a fresh mirror places them (the fitness rings'
// badge).
WR_TEST(testAMovedInlineFlexPublishesOperations) {
    RenderEnv env("<!doctype html><style>.badge{display:inline-flex;padding:2px;background:rgba(255,120,0,.2)}"
                  " .badge i{box-shadow:0 0 0 1px rgba(0,0,0,.1)}</style><body style='margin:0'><div id=top></div>"
                  "<p>streak <span class=badge><i>\xF0\x9F\x94\xA5</i> 12</span></p></body>");
    edit(env, "const d = document.createElement('div'); d.textContent = 'moved down'; document.getElementById('top').append(d)");
    CHECK(equalsAFreshMirror(env, "the line holding an inline-flex moved"));
    CHECK(flattensAsRecorded(env, "the line holding an inline-flex moved"));
}

// A table paints every caption before any row (render_item_table::draw_children), and the mirror numbers tree order as
// it paints (a table's captions before its other children), so a neutral class change that gives a cell, a row or the
// caption its first decoration is one Insert, placed where a fresh walk has it, wherever the caption is in the tree.
WR_TEST(testANewBoxBesideACaptionIsPlaced) {
    // The caption has a Box of its own unless it is the target: in the table's block pass it then paints before the
    // cells' Boxes, which it follows in the tree.
    const char* const targets[] = {"td2", "tr2", "cap"};
    for (const bool after : {true, false}) {
        for (const std::string target : targets) {
            const std::string caption =
                "<caption id=cap" + std::string(target == "cap" ? "" : " style='border:1px solid #000'") + ">cap</caption>";
            const std::string rows = "<tr><td class=y>c1</td></tr><tr id=tr2><td id=td2>c2</td></tr>";
            // No border: the UA layer's cell border would be the cell's first decoration.
            RenderEnv env("<!doctype html><style>.y{background-color:#eee} .d{background-color:#ff0} td{padding:2px;border:0}</style>"
                          "<body style='margin:0;height:200px'><table style='background-color:#ddd'>" +
                          (after ? rows + caption : caption + rows) + "</table></body>");
            CHECK(env.render().renderInput().find(after ? "</tbody><caption" : "</caption><tbody") != std::string::npos);
            const uint64_t patches = env.render().patchCount();
            const std::shared_ptr<const LayerTree> before = env.render().layerTree();
            const std::string what =
                "the first decoration of #" + target + (after ? ", the caption after the rows" : ", the caption first");
            edit(env, "document.getElementById('" + target + "').setAttribute('class', 'd')");
            CHECK_EQ(env.render().patchCount(), patches + 1);
            const std::vector<LayerOp>& ops = env.render().layerOps();
            bool expected = true;
            // One Insert, placed where a fresh walk has it.
            IdTree structure = IdTree::of(*before->mirror());
            size_t inserts = 0;
            for (const LayerOp& op : ops) {
                expected = structure.apply(op) && expected;
                inserts += op.kind == LayerOp::Insert;
            }
            expected = expected && inserts == 1 && structure == IdTree::of(*env.render().layerTree()->mirror());
            if (!expected) {
                std::printf("  unexpected ops: %s\n  ops: %s\n", what.c_str(), describe(ops).c_str());
            }
            CHECK(expected);
            CHECK(flattensAsRecorded(env, what));
            CHECK(equalsAFreshMirror(env, what));
        }
    }
}


// Nothing declines: a report the placement rule cannot place (an item added outside a text replacement or a
// replacement) makes publish() throw LayerMirror::Inconsistent, publishing nothing.
WR_TEST(testAnUnplaceableReportIsInconsistent) {
    wr_test::RenderEnv env("<!doctype html><body><p>a</p><p>b</p></body>");
    litehtml::document& document = *env.render().document();
    wr::LayerId next = wr::LayerId(1) << 40;
    wr::LayerMirror mirror([](const litehtml::element&) { return wr::NodeKey(0); }, next);
    const std::shared_ptr<const LayerTree> built = mirror.build(document, env.render().container(), false);
    mirror.item_added(document.root_render()->children().front());
    bool inconsistent = false;
    try {
        mirror.publish();
    } catch (const wr::LayerMirror::Inconsistent&) {
        inconsistent = true;
    }
    CHECK(inconsistent);
    CHECK(mirror.tree() == built);
}

// An inconsistency stops the widget (RenderTree::stopInternally): the `render-internal` diagnostic,
// StopReason::Internal, and the tree published before the flush kept.
WR_TEST(testAnInconsistencyStopsTheWidget) {
    wr_test::RenderEnv env("<!doctype html><body><p id=a>a</p><p>b</p></body>");
    const std::shared_ptr<const LayerTree> before = env.render().layerTree();
    litehtml::document& document = *env.render().document();
    // A report the placement rule cannot place, into the tree's own mirror (the document's render observer).
    document.get_render_observer()->item_added(document.root_render()->children().front());
    CHECK_EQ(env.env().eval("document.getElementById('a').firstChild.data = 'changed'; 'ok'"), std::string("ok"));
    const size_t posted = env.env().host().diagnostics.size();
    try {
        env.flush();
    } catch (const wr::Aborted&) {
    }
    CHECK(env.env().runtime().stopReason() == wr::StopReason::Internal);
    bool diagnosed = false;
    for (size_t d = posted; d < env.env().host().diagnostics.size(); d++) {
        diagnosed = diagnosed || env.env().host().diagnostics[d].first == "render-internal";
    }
    CHECK(diagnosed);
    CHECK(env.render().layerTree() == before);
}
