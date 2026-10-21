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
/// after the install (a work limit, natives). The constructor drains the loop unless `drain` is false.
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
    /// render().rebuild(ctx()); throws what it throws (Aborted on a stop).
    void rebuild() { m_tree->rebuild(this->ctx()); }
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
