// The render tests' harness (M1c plan, Tasks 5 and 6): a booted runtime whose RenderTree, over a FakeRenderHost, is
// installed in its HostState before the boot.
#pragma once

#include <functional>
#include <memory>
#include <string>
#include <string_view>
#include <tuple>
#include <vector>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderHost.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/FakeRenderHost.h"
#include "Tests/HostHarness.h"

namespace wr_test {

/// A FakeRenderHost, then a HostEnv booted from `html` (HostEnv::booted) with a RenderTree over the host installed
/// first in its beforeBoot hook (wr::installRender, Task 6), so the boot's flush builds the parsed markup. The HostState
/// owns the tree and the RenderEnv the host, declared first so it outlives the runtime. `beforeBoot`, when given, runs
/// after the install (natives, host settings). The constructor drains the loop unless `drain` is false.
/// Markup without a doctype boots a quirks-mode document, which the render build follows (Document::mode()). The
/// options always keep the render input (RenderOptions::keepRenderInput), whatever `options` says.
class RenderEnv {
public:
    explicit RenderEnv(std::string_view html, wr::RenderOptions options = {}, bool drain = true,
                       const std::function<void(HostEnv&)>& beforeBoot = {});
    ~RenderEnv();
    RenderEnv(const RenderEnv&) = delete;
    RenderEnv& operator=(const RenderEnv&) = delete;

    HostEnv& env() { return *m_env; }
    /// The installed tree (HostState::render()).
    wr::RenderTree& render() { return *m_tree; }
    FakeRenderHost& host() { return m_host; }
    const wr::RenderOptions& options() const { return m_options; }
    JSContext* ctx() { return m_env->ctx(); }
    /// A new RenderTree over the same host and the tree's current options, built now from the DOM as it is (a boot's
    /// build), then installed in place of the old one, which goes; a build that throws (Aborted on a stop) leaves the old
    /// one installed. For tests of what a build of a DOM makes.
    void buildAfresh();
    /// render().flush(ctx()); throws what it throws (Aborted on a stop).
    void flush() { m_tree->flush(this->ctx()); }

private:
    FakeRenderHost m_host;
    wr::RenderOptions m_options;
    std::unique_ptr<HostEnv> m_env;
    /// The HostState's: it goes with the runtime, before the host.
    wr::RenderTree* m_tree = nullptr;
};

/// A fresh RenderTree over the same DOM, host and options, rebuilt now: {layoutDump, renderInput, layer-tree dump}.
/// Its render-limit diagnostics go to the same TestHost. While it lives it listens to the main document too, and
/// records nothing (a tree that has not built yet journals nothing).
std::tuple<std::string, std::string, std::string> rebuildDump(RenderEnv& env);

/// "" when `ops` are a first publish's: Inserts only, the root's first (under parent 0), which applied in order to an
/// empty structure give `tree`'s, each node's children in their order; else what differs.
std::string insertsMismatch(const wr::LayerTree& tree, const std::vector<wr::LayerOp>& ops);

/// The published build's running totals (wr::RenderBuild: boxes, text and render bytes, text units, elements, form
/// controls, sheets) that differ from `fresh`'s, named; "" when none does. The node count is left out: a patch keeps it
/// an upper bound (RenderBuild::nodeCount).
std::string totalsMismatch(const wr::RenderTree& flushed, const wr::RenderTree& fresh);
/// Whether litehtml's counts (text pieces, elements, pseudo-elements), the published limits and the published build's
/// running totals (totalsMismatch) are a fresh build's of the DOM as it now is (a patch cuts where a build cuts); what
/// differs is printed with `what`. The fresh build posts its render-limit diagnostics to the same TestHost.
bool countsMatchAFreshBuild(RenderEnv& env, const std::string& what);

/// What `tree` answers to the read APIs, for comparing a patched tree with a fresh one over the same DOM: for each of the
/// first 600 elements in tree order (by position) outside the subtrees of #filler, #filler2 and #inputs (the near-cap
/// pages' filler, which the edits never touch), its border box, client rects and their visual rects, and
/// getComputedStyle's display, position, width, height, color, font-size, transform and opacity, and its ::before's
/// content; the node hit at every 32 px of the first 1,000 px of the document (by position); and the selectable text of
/// that height, its units and runs.
std::string readsDump(wr::RenderTree& tree, JSContext* ctx);

/// The oracle's normalisation (Ruling E37): a copy of a WidgetContainer::record tree without the empty set-clip/del-clip
/// pairs draw_children opens on every pass that reaches a clipping item, and the lone del-clip of a display:inline clipper,
/// at every depth (a pair holding only dropped pairs goes too; set-clip-path pairs stay). The published mirror flattens to
/// this: no painting node owns what it drops.
std::shared_ptr<const wr::LayerTree> normalized(const wr::LayerTree& recorded);

/// Every text item of a tree, in paint order (an explicit stack, as everything over a tree is).
std::vector<const wr::TextItem*> textItems(const wr::LayerTree& tree);
/// The first text item whose text is `text`; nullptr when there is none.
const wr::TextItem* findText(const wr::LayerTree& tree, const std::string& text);

} // namespace wr_test
