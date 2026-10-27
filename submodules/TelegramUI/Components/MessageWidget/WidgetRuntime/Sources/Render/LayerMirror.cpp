#include "Sources/Render/LayerMirror.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <new>
#include <set>
#include <utility>

#include <litehtml.h>
#include <litehtml/render_inline_context.h>
#include <litehtml/render_table.h>

#include "Sources/Render/LayerDiff.h"

namespace wr {

/// A render item the mirror has seen paint (its own paint was visited at build).
struct LayerMirror::ItemInfo {
    std::weak_ptr<litehtml::render_item> item;
    /// The context node its own paint sits in: its Box's parent, or its own Context's parent.
    LayerId context = 0;
    LayerId box = 0;
    /// The Context it opens, if it opens one.
    LayerId own = 0;
    /// An inline context's Inline nodes, in order.
    std::vector<LayerId> runs;
    /// For an inline item: the inline context whose run holds its paint.
    const litehtml::render_item* runOf = nullptr;
    /// Where its Box or its Context sits in `context`.
    MirrorPass pass = MirrorPass::Block;
    int zindex = 0;
    /// A table row: its paint is draw_background.
    bool background = false;
    /// Its place in the render tree's pre-order, numbered at build.
    uint64_t order = 0;
    /// Its id as a clipper, once it clipped something.
    LayerId clipper = 0;
    /// Its runs are split by a nested inline context (an inline table's cells).
    bool runsSplit = false;
    /// An inline element in its line opens a context of its own (a paint group): that context's run moves with the text
    /// before it, and nothing reports the move (an inline item has no box of its own), so re-capturing this inline
    /// context's runs does not place it.
    bool subContexts = false;
    /// Its own paint was visited more than once (litehtml's block pass enters an inline-flex or inline-grid, which
    /// then paints its own content again in its context): the mirror does not update what it paints.
    bool multi = false;
    int visits = 0;
};

/// A published node, and where it is.
struct LayerMirror::NodeInfo {
    LayerId parent = 0;
    /// The item it mirrors: a Box's or a Context's item, an Inline's inline context.
    const litehtml::render_item* item = nullptr;
    std::shared_ptr<const MirrorNode> node;
    /// Its place in its pass: its item's tree order (a run's: its first item's).
    uint64_t order = 0;
    const litehtml::render_item* first = nullptr;
    /// A Context in which a table caption that follows its table's rows in the tree paints. render_item_table's
    /// draw_children paints every caption before any row, so this context's children are not in tree order, and the
    /// placement rule cannot place a node in it (Ruling E39).
    bool captioned = false;
};

namespace {

using litehtml::draw_flag;
using litehtml::pixel_t;
using litehtml::render_item;

MirrorPass passOf(draw_flag flag, int zindex) {
    switch (flag) {
    case litehtml::draw_root: return MirrorPass::Own;
    case litehtml::draw_block: return MirrorPass::Block;
    case litehtml::draw_floats: return MirrorPass::Floats;
    case litehtml::draw_inlines: return MirrorPass::Inlines;
    case litehtml::draw_positioned:
        return zindex < 0 ? MirrorPass::Negative : zindex == 0 ? MirrorPass::Zero : MirrorPass::Positive;
    }
    return MirrorPass::Block;
}

bool isInlineContext(const render_item* item) {
    return dynamic_cast<const litehtml::render_item_inline_context*>(item) != nullptr;
}

bool isTableInternal(const render_item* item) {
    return dynamic_cast<const litehtml::render_item_table*>(item) ||
           dynamic_cast<const litehtml::render_item_table_part*>(item) ||
           dynamic_cast<const litehtml::render_item_table_row*>(item);
}

// draw_children's inline-level sub-contexts: an inline-block, inline-flex or inline-grid (draw_stacking_context(false)).
bool isInlineBox(const render_item& item) {
    const auto display = item.src_el()->css().get_display();
    return display == litehtml::display_inline_block || display == litehtml::display_inline_flex ||
           display == litehtml::display_inline_grid;
}

// Whether the item's own paint at `flag` is followed by its own painting context (draw_stacking_context).
bool opensContext(const render_item& item, draw_flag flag) {
    if (flag == litehtml::draw_root) {
        return !item.parent();
    }
    if (flag == litehtml::draw_positioned) {
        return true;
    }
    if (flag == litehtml::draw_floats) {
        return item.src_el()->css().get_float() != litehtml::float_none;
    }
    if (flag == litehtml::draw_inlines) {
        return isInlineBox(item);
    }
    return false;
}

// draw_children's content origin for an item painted at (x, y), in its arithmetic.
litehtml::pointF childrenOrigin(const render_item& item, pixel_t x, pixel_t y) {
    litehtml::position pos = item.pos_const();
    pos.x += x - item.get_scroll_left();
    pos.y += y - item.get_scroll_top();
    litehtml::pointF out;
    out.x = pos.x.value();
    out.y = pos.y.value();
    return out;
}

litehtml::pointF ownOrigin(const render_item& item, pixel_t x, pixel_t y) {
    litehtml::pointF out;
    out.x = x.value() + item.pos_const().x.value();
    out.y = y.value() + item.pos_const().y.value();
    return out;
}

litehtml::pointF minus(const litehtml::pointF& a, const litehtml::pointF& b) {
    litehtml::pointF out;
    out.x = a.x - b.x;
    out.y = a.y - b.y;
    return out;
}

std::shared_ptr<Layer> newContent() {
    auto layer = std::make_shared<Layer>();
    layer->kind = Layer::Kind::Root;
    return layer;
}

// `paint`, run alone where litehtml runs it (document coordinates, so draw()'s own rounding is the recorder's), appended
// to `into` moved to `origin` (its items relative to it).
void captureInto(WidgetContainer& container, Layer& into, const litehtml::pointF& origin,
                 const std::function<void()>& paint) {
    Layer painted;
    painted.kind = Layer::Kind::Root;
    container.capture(painted, paint);
    appendMoved(painted, into, -origin.x, -origin.y);
}

// An item's own paint at (x, y), where draw() paints it.
std::function<void()> ownPaint(const std::shared_ptr<render_item>& item, bool background, pixel_t x, pixel_t y) {
    return [item, background, x, y] {
        if (background) {
            item->src_el()->draw_background(0, x, y, nullptr, item);
        } else {
            item->src_el()->draw(0, x, y, nullptr, item);
        }
    };
}

// A Box's content: its item's own paint at (x, y), relative to the item's own position there.
std::shared_ptr<Layer> captureBox(WidgetContainer& container, const std::shared_ptr<render_item>& item, bool background,
                                  pixel_t x, pixel_t y) {
    auto layer = newContent();
    captureInto(container, *layer, ownOrigin(*item, x, y), ownPaint(item, background, x, y));
    return layer;
}

LayerId nextId(LayerId& counter) {
    return counter++;
}

} // namespace

// ---- The walk: build, and the replays the updates use. ----

class LayerMirror::Walker final : public litehtml::paint_visitor, public WalkListener {
public:
    enum class Mode {
        /// The whole document (walk_paint_order).
        Build,
        /// An inline context's draw_children(inlines), its content origin at (0, 0): its runs, nothing else.
        Runs,
        /// A paint group's draw_group: its parameters, nothing else.
        Params,
    };

    Walker(LayerMirror& mirror, WidgetContainer& container, Mode mode) : m(mirror), m_container(container), m_mode(mode) {}

    // Build: the root context, frozen.
    std::shared_ptr<MirrorNode> root;
    // Runs: the runs found, relative to `runOrigin` (the inline context's content origin, where the replay paints).
    std::vector<std::shared_ptr<Layer>> runs;
    litehtml::pointF runOrigin;
    // Params: the group found.
    std::shared_ptr<MirrorGroup> group;
    bool lost = false;
    // Build: the contexts in which a table caption that follows its rows paints (NodeInfo::captioned).
    std::vector<LayerId> captioned;

    // Whether `item` is a table caption that follows something else of its table in the tree: the table paints it
    // before its rows all the same (render_item_table::init collects its captions from its own children), so its
    // context's children are not in tree order (NodeInfo::captioned).
    static bool captionFollowsARow(const render_item& item) {
        if (item.src_el()->css().get_display() != litehtml::display_table_caption) {
            return false;
        }
        const std::shared_ptr<render_item> table = item.parent();
        if (!table) {
            return true;
        }
        for (const auto& child : table->children()) {
            if (child.get() == &item) {
                return false;
            }
            if (child->src_el()->css().get_display() != litehtml::display_table_caption) {
                return true;
            }
        }
        return true;
    }

    // litehtml::paint_visitor

    void open_context(const std::shared_ptr<render_item>& item, litehtml::paint_context kind) override {
        if (m_mode == Mode::Runs) {
            closeRun();
            m_skip++;
            return;
        }
        if (m_mode == Mode::Params) {
            m_depth++;
            if (m_depth == 1) {
                group = std::make_shared<MirrorGroup>();
            }
            return;
        }
        Frame* parent = m_contexts.empty() ? nullptr : &m_contexts.back();
        if (parent) {
            closeRun(*parent);
        }
        Frame frame;
        frame.item = item;
        frame.node = std::make_shared<MirrorNode>();
        MirrorNode& node = *frame.node;
        node.kind = MirrorNode::Kind::Context;
        node.id = nextId(m.m_nextId);
        node.key = m.m_keyOf(*item->src_el());
        node.escapes = m_escape;
        m_escape = false;
        switch (kind) {
        case litehtml::paint_context::root: node.context = MirrorNode::ContextKind::Root; break;
        case litehtml::paint_context::stacking: node.context = MirrorNode::ContextKind::Stacking; break;
        case litehtml::paint_context::pseudo: node.context = MirrorNode::ContextKind::Pseudo; break;
        case litehtml::paint_context::group: node.context = MirrorNode::ContextKind::Group; break;
        }
        ItemInfo& info = itemInfo(item);
        info.own = node.id;
        info.context = parent ? parent->node->id : 0;
        if (kind == litehtml::paint_context::group) {
            // An inline element's paint group, in its inline context's line (ItemInfo::subContexts).
            if (item->src_el()->is_inline() && !isInlineBox(*item)) {
                if (const render_item* line = innermostInlineContext(); line && isInlineContext(line)) {
                    if (auto at = m.m_items.find(line); at != m.m_items.end() && at->second) {
                        at->second->subContexts = true;
                    }
                }
            }
            frame.group = std::make_shared<MirrorGroup>();
            if (parent) {
                info.pass = parent->pass;
                info.zindex = parent->zindex;
                node.pass = parent->pass;
                node.zindex = parent->zindex;
                node.clips = chain(m_contexts.size() - 1);
            }
        } else {
            // The item's own paint came just before: it is this context's own Box, and it fixes the origin.
            if (!m_pending || m_pending->item != item) {
                lost = true;
                flushPending();
            }
            Pending pending = m_pending ? std::move(*m_pending) : Pending{item};
            m_pending.reset();
            frame.origin = childrenOrigin(*item, pending.x, pending.y);
            node.origin = parent ? minus(frame.origin, parent->origin) : frame.origin;
            node.pass = pending.pass;
            node.zindex = pending.zindex;
            node.clips = std::move(pending.clips);
            info.pass = pending.pass;
            info.zindex = pending.zindex;
            if (pending.box) {
                addOwnBox(frame, item, pending.box, ownOrigin(*item, pending.x, pending.y));
            }
        }
        if (parent) {
            addChild(*parent, frame.node, item.get(), item.get());
        }
        m_contexts.push_back(std::move(frame));
    }

    void close_context() noexcept override {
        if (m_mode == Mode::Runs) {
            m_skip--;
            return;
        }
        if (m_mode == Mode::Params) {
            m_depth--;
            return;
        }
        if (m_contexts.empty()) {
            return;
        }
        flushPending();
        Frame& frame = m_contexts.back();
        closeRun(frame);
        if (frame.group) {
            frame.node->group = std::move(frame.group);
        }
        if (m_contexts.size() == 1) {
            root = frame.node;
        }
        m_contexts.pop_back();
    }

    void open_pass(const std::shared_ptr<render_item>& item, draw_flag pass, int zindex) override {
        if (m_mode != Mode::Build) {
            if (m_mode == Mode::Runs && m_skip == 0 && m_passDepth++ > 0 && isInlineContext(item.get())) {
                lost = true;   // a nested inline context: its runs split these (runsSplit)
            }
            return;
        }
        flushPending();
        if (m_contexts.empty()) {
            return;
        }
        Frame& frame = m_contexts.back();
        if (isInlineContext(item.get())) {
            closeRun(frame);
            if (frame.passes > 0 && pass == litehtml::draw_inlines) {
                // An inline context's region inside another's (an inline table's cell): it splits that one's runs.
                for (size_t i = m_passes.size(); i-- > 0;) {
                    if (m_passes[i].context != m_contexts.size() - 1) {
                        break;
                    }
                    if (isInlineContext(m_passes[i].item.get())) {
                        itemInfo(m_passes[i].item).runsSplit = true;
                        break;
                    }
                }
            }
        }
        if (frame.passes == 0 && item == frame.item) {
            frame.pass = passOf(pass, zindex);
            frame.zindex = zindex;
        }
        frame.passes++;
        PassFrame scope;
        scope.item = item;
        scope.context = m_contexts.size() - 1;
        m_passes.push_back(std::move(scope));
    }

    void close_pass() noexcept override {
        if (m_mode != Mode::Build) {
            if (m_mode == Mode::Runs && m_skip == 0) {
                m_passDepth--;
            }
            return;
        }
        flushPending();
        if (m_passes.empty()) {
            return;
        }
        const PassFrame scope = std::move(m_passes.back());
        m_passes.pop_back();
        if (scope.context < m_contexts.size()) {
            Frame& frame = m_contexts[scope.context];
            frame.passes--;
            if (frame.run && frame.runContext == scope.item.get()) {
                closeRun(frame);
            }
        }
    }

    void paint_element(const std::shared_ptr<render_item>& item, draw_flag pass, pixel_t x, pixel_t y,
                       const std::function<void()>& paint) override {
        if (m_mode == Mode::Params) {
            return;
        }
        if (m_mode == Mode::Runs) {
            if (m_skip > 0) {
                return;
            }
            if (pass == litehtml::draw_inlines && isInlineBox(*item)) {
                closeRun();
                return;
            }
            if (!m_run) {
                m_run = newContent();
                runs.push_back(m_run);
            }
            captureInto(m_container, *m_run, runOrigin, paint);
            return;
        }
        flushPending();
        ItemInfo& info = itemInfo(item);
        info.background = dynamic_cast<const litehtml::render_item_table_row*>(item.get()) != nullptr;
        if (!m_contexts.empty() && captionFollowsARow(*item)) {
            captioned.push_back(m_contexts.back().node->id);
        }
        if (++info.visits > 1) {
            info.multi = true;
        }
        m_paintAt.emplace(item.get(), std::make_pair(x, y));
        if (m_contexts.empty()) {
            // The root's own paint, before its context opens.
            if (!opensContext(*item, pass)) {
                lost = true;
                return;
            }
            Pending pending{item};
            pending.x = x;
            pending.y = y;
            pending.pass = MirrorPass::Own;
            std::shared_ptr<Layer> box = captureBox(m_container, item, info.background, x, y);
            if (!box->entries.empty()) {
                pending.box = std::move(box);
            }
            m_pending = std::move(pending);
            return;
        }
        Frame& frame = m_contexts.back();
        if (pass == litehtml::draw_root && item == frame.item && frame.group) {
            // A paint group's own paint: its origin, and its own Box.
            frame.origin = childrenOrigin(*item, x, y);
            frame.node->origin =
                m_contexts.size() > 1 ? minus(frame.origin, m_contexts[m_contexts.size() - 2].origin) : frame.origin;
            std::shared_ptr<Layer> box = captureBox(m_container, item, info.background, x, y);
            if (!box->entries.empty()) {
                addOwnBox(frame, item, box, ownOrigin(*item, x, y));
            }
            return;
        }
        const MirrorPass where = passOf(pass, frame.zindex);
        if (opensContext(*item, pass)) {
            Pending pending{item};
            pending.x = x;
            pending.y = y;
            pending.pass = pass == litehtml::draw_root ? MirrorPass::Own : where;
            pending.zindex = pass == litehtml::draw_positioned ? frame.zindex : 0;
            pending.clips = chain(m_contexts.size() - 1);
            std::shared_ptr<Layer> box = captureBox(m_container, item, info.background, x, y);
            if (!box->entries.empty()) {
                pending.box = std::move(box);
            }
            m_pending = std::move(pending);
            return;
        }
        if (pass == litehtml::draw_inlines && item->src_el()->is_inline()) {
            // Inline content: its inline context's current run.
            const render_item* context = innermostInlineContext();
            if (!context) {
                lost = true;
                return;
            }
            if (!frame.run || frame.runContext != context) {
                closeRun(frame);
                startRun(frame, context, item.get());
            }
            info.runOf = context;
            info.context = frame.node->id;
            captureInto(m_container, *frame.runContent, frame.runOrigin, paint);
            return;
        }
        // A Box.
        closeRun(frame);
        info.context = frame.node->id;
        info.pass = where;
        info.zindex = pass == litehtml::draw_positioned ? frame.zindex : 0;
        std::shared_ptr<Layer> content = captureBox(m_container, item, info.background, x, y);
        if (content->entries.empty()) {
            return;
        }
        auto node = std::make_shared<MirrorNode>();
        node->kind = MirrorNode::Kind::Box;
        node->id = nextId(m.m_nextId);
        node->key = m.m_keyOf(*item->src_el());
        node->origin = minus(ownOrigin(*item, x, y), frame.origin);
        node->pass = where;
        node->zindex = info.zindex;
        node->clips = chain(m_contexts.size() - 1);
        node->content = std::move(content);
        info.box = node->id;
        addChild(frame, node, item.get(), item.get());
    }

    // WalkListener

    void walkSetClip(const litehtml::position& pos, const litehtml::border_radiuses& radius) override {
        if (m_mode != Mode::Build || m_passes.empty() || m_contexts.empty()) {
            return;
        }
        PassFrame& scope = m_passes.back();
        const Frame& frame = m_contexts[scope.context];
        ItemInfo& info = itemInfo(scope.item);
        if (!info.clipper) {
            info.clipper = nextId(m.m_nextId);
        }
        scope.clip = true;
        scope.step.clipper = info.clipper;
        scope.step.key = m.m_keyOf(*scope.item->src_el());
        scope.step.box =
            litehtml::position(pos.x.value() - frame.origin.x, pos.y.value() - frame.origin.y, pos.width, pos.height);
        scope.step.radius = radius;
    }

    void walkDelClip() override {
        if (m_mode != Mode::Build || m_contexts.empty()) {
            return;
        }
        // A pass's own clip; else a group's clip path closing; else an inline clipper's lone del_clip.
        if (!m_passes.empty() && m_passes.back().context == m_contexts.size() - 1 && m_passes.back().clip) {
            m_passes.back().clip = false;
        }
    }

    void walkSuspendClips() override {
        if (m_mode == Mode::Build) {
            m_escape = true;
        }
    }

    void walkResumeClips() override {}

    void walkBeginGroup(const litehtml::paint_group& value) override {
        if (MirrorGroup* target = currentGroup()) {
            target->group = value;
        }
    }

    void walkEndGroup() override {}

    void walkClipPath(const litehtml::vector_path& path) override {
        if (MirrorGroup* target = currentGroup()) {
            target->clipPath = path;
        }
    }

    void walkBackdrop(const litehtml::filter_paint& filter) override {
        if (MirrorGroup* target = currentGroup()) {
            BackdropItem item;
            if (filter.steps) {
                item.steps = *filter.steps;
            }
            item.bounds = filter.bounds;
            item.box = filter.box;
            item.radius = filter.radius;
            target->backdrop = std::move(item);
        }
    }

    void walkFiltered(const litehtml::filter_paint& filter, const std::function<void()>& paint) override {
        if (MirrorGroup* target = currentGroup()) {
            target->filtered = true;
            if (filter.steps) {
                target->filter = *filter.steps;
            }
        }
        // The group's parameters are all known by now: a replay for them need not paint the contents.
        if (m_mode == Mode::Params) {
            return;
        }
        paint();
    }

    void walkStray() override { lost = true; }

    // After a build walk: the side tables, the tree order and the root.
    void finish() {
        flushPending();
        // The render tree's pre-order.
        uint64_t order = 0;
        std::vector<const render_item*> stack;
        if (m.m_document && m.m_document->root_render()) {
            stack.push_back(m.m_document->root_render().get());
        }
        while (!stack.empty()) {
            const render_item* item = stack.back();
            stack.pop_back();
            auto found = m.m_items.find(item);
            if (found != m.m_items.end()) {
                found->second->order = order;
            }
            m_order[item] = order++;
            const auto& kids = const_cast<render_item*>(item)->children();
            for (auto it = kids.rbegin(); it != kids.rend(); ++it) {
                stack.push_back(it->get());
            }
        }
        for (auto& [id, node] : m.m_nodes) {
            const render_item* first = node->first ? node->first : node->item;
            auto it = m_order.find(first);
            node->order = it == m_order.end() ? 0 : it->second;
        }
    }

private:
    struct PassFrame {
        std::shared_ptr<render_item> item;
        size_t context = 0;
        bool clip = false;
        MirrorClip step;
    };
    struct Frame {
        std::shared_ptr<render_item> item;
        std::shared_ptr<MirrorNode> node;
        litehtml::pointF origin;
        MirrorPass pass = MirrorPass::Own;
        int zindex = 0;
        size_t passes = 0;
        std::shared_ptr<MirrorGroup> group;
        // The run being filled.
        MirrorNode* run = nullptr;
        const render_item* runContext = nullptr;
        Layer* runContent = nullptr;
        litehtml::pointF runOrigin;
    };
    struct Pending {
        std::shared_ptr<render_item> item;
        pixel_t x = 0;
        pixel_t y = 0;
        MirrorPass pass = MirrorPass::Block;
        int zindex = 0;
        std::vector<MirrorClip> clips;
        std::shared_ptr<Layer> box;
    };

    ItemInfo& itemInfo(const std::shared_ptr<render_item>& item) {
        auto& slot = m.m_items[item.get()];
        if (!slot) {
            slot = std::make_unique<ItemInfo>();
            slot->item = item;
            // Its element's items, as the walk saw them: a table row's is not in the element's own list.
            m.m_byElement[item->src_el().get()].push_back(item.get());
        }
        return *slot;
    }

    MirrorGroup* currentGroup() {
        if (m_mode == Mode::Params) {
            return m_depth == 1 ? group.get() : nullptr;
        }
        if (m_mode != Mode::Build || m_contexts.empty()) {
            return nullptr;
        }
        // Only the group's own calls: they come before its first pass.
        Frame& frame = m_contexts.back();
        return frame.passes == 0 ? frame.group.get() : nullptr;
    }

    // The clips open in context `index`, outermost first.
    std::vector<MirrorClip> chain(size_t index) const {
        std::vector<MirrorClip> out;
        for (const PassFrame& scope : m_passes) {
            if (scope.context == index && scope.clip) {
                out.push_back(scope.step);
            }
        }
        return out;
    }

    // Whose run inline content painted now joins: the innermost inline context the current context's passes are in;
    // else the context's own item (an inline paint group: a span's contents are painted in its group's passes).
    const render_item* innermostInlineContext() const {
        bool inPass = false;
        for (size_t i = m_passes.size(); i-- > 0;) {
            if (m_passes[i].context != m_contexts.size() - 1) {
                break;
            }
            inPass = true;
            if (isInlineContext(m_passes[i].item.get())) {
                return m_passes[i].item.get();
            }
        }
        return inPass && !m_contexts.empty() ? m_contexts.back().item.get() : nullptr;
    }

    void addChild(Frame& frame, const std::shared_ptr<MirrorNode>& node, const render_item* item, const render_item* first) {
        frame.node->children.push_back(node);
        auto info = std::make_unique<NodeInfo>();
        info->parent = frame.node->id;
        info->item = item;
        info->node = node;
        info->first = first;
        m.m_nodes[node->id] = std::move(info);
    }

    void addOwnBox(Frame& frame, const std::shared_ptr<render_item>& item, std::shared_ptr<Layer> content,
                   const litehtml::pointF& at) {
        auto box = std::make_shared<MirrorNode>();
        box->kind = MirrorNode::Kind::Box;
        box->id = nextId(m.m_nextId);
        box->key = m.m_keyOf(*item->src_el());
        box->origin = minus(at, frame.origin);
        box->pass = MirrorPass::Own;
        box->content = std::move(content);
        itemInfo(item).box = box->id;
        addChild(frame, box, item.get(), item.get());
    }

    void startRun(Frame& frame, const render_item* context, const render_item* first) {
        auto node = std::make_shared<MirrorNode>();
        node->kind = MirrorNode::Kind::Inline;
        node->id = nextId(m.m_nextId);
        node->key = m.m_keyOf(*context->src_el());
        auto at = m_paintAt.find(context);
        pixel_t x = 0, y = 0;
        if (at != m_paintAt.end()) {
            x = at->second.first;
            y = at->second.second;
        } else {
            litehtml::paint_origin(*context, x, y);
        }
        frame.runOrigin = childrenOrigin(*context, x, y);
        node->origin = minus(frame.runOrigin, frame.origin);
        node->pass = MirrorPass::Inlines;
        node->clips = chain(m_contexts.size() - 1);
        auto content = newContent();
        frame.runContent = content.get();
        node->content = std::move(content);
        frame.run = node.get();
        frame.runContext = context;
        auto& owner = m.m_items[context];
        if (!owner) {
            owner = std::make_unique<ItemInfo>();
        }
        owner->runs.push_back(node->id);
        addChild(frame, node, context, first);
    }

    void closeRun(Frame& frame) {
        frame.run = nullptr;
        frame.runContext = nullptr;
        frame.runContent = nullptr;
    }

    void closeRun() { m_run.reset(); }

    // A context's own paint is followed by its context at once: anything else between them is a walk the mirror
    // cannot represent.
    void flushPending() {
        if (m_pending) {
            m_pending.reset();
            lost = true;
        }
    }

    LayerMirror& m;
    WidgetContainer& m_container;
    Mode m_mode;
    std::vector<Frame> m_contexts;
    std::vector<PassFrame> m_passes;
    std::optional<Pending> m_pending;
    bool m_escape = false;
    std::unordered_map<const render_item*, std::pair<pixel_t, pixel_t>> m_paintAt;
    std::unordered_map<const render_item*, uint64_t> m_order;
    // Runs replay.
    std::shared_ptr<Layer> m_run;
    int m_skip = 0;
    int m_passDepth = 0;
    // Params replay.
    int m_depth = 0;
};


// ---- Publishing what the fork reported (the header comment's "Updating"). ----

class LayerMirror::Update {
public:
    explicit Update(LayerMirror& mirror) : m(mirror), m_container(*mirror.m_container) {}

    std::optional<Publish> run() {
        if (!collect() || m_unpainted) {
            return std::nullopt;
        }
        for (const render_item* item : m_paintOrder) {
            if (!paintOrder(item)) {
                return std::nullopt;
            }
        }
        for (const render_item* item : m_boxes.list) {
            if (!recaptureBox(item)) {
                return std::nullopt;
            }
        }
        for (const render_item* item : m_runs.list) {
            if (!recaptureRuns(item)) {
                return std::nullopt;
            }
        }
        for (const render_item* item : m_moved) {
            if (!moved(item)) {
                return std::nullopt;
            }
        }
        for (const render_item* item : m_clippers) {
            if (!clipped(item)) {
                return std::nullopt;
            }
        }
        if (!groups()) {
            return std::nullopt;
        }
        return freeze();
    }

private:
    template <class T>
    struct Ordered {
        std::vector<T> list;
        std::unordered_set<T> seen;
        void add(T value) {
            if (seen.insert(value).second) {
                list.push_back(value);
            }
        }
    };

    ItemInfo* info(const render_item* item) const {
        auto it = m.m_items.find(item);
        return it == m.m_items.end() ? nullptr : it->second.get();
    }

    std::shared_ptr<render_item> locked(const render_item* item) const {
        const ItemInfo* found = info(item);
        return found ? found->item.lock() : nullptr;
    }

    NodeInfo& node(LayerId id) { return *m.m_nodes.at(id); }

    const MirrorNode& current(LayerId id) const {
        auto it = m_work.find(id);
        return it != m_work.end() ? *it->second : *m.m_nodes.at(id)->node;
    }

    // Copy on write: the node's next object, made from its published one the first time.
    MirrorNode& edit(LayerId id) {
        auto it = m_work.find(id);
        if (it != m_work.end()) {
            return *it->second;
        }
        const std::shared_ptr<const MirrorNode>& published = m.m_nodes.at(id)->node;
        auto copy = std::make_shared<MirrorNode>(*published);
        m_old.emplace(id, published);
        return *m_work.emplace(id, std::move(copy)).first->second;
    }

    void emit(LayerOp::Kind kind, LayerId id, LayerId parent = 0, LayerId after = 0) {
        if (kind == LayerOp::Insert || kind == LayerOp::Remove || kind == LayerOp::Move ||
            m_emitted.insert({int(kind), id}).second) {
            m_ops.push_back({kind, id, parent, after});
        }
    }

    // The absolute content origin of a context node's item, as draw() computes it.
    litehtml::pointF contextOrigin(LayerId context) const {
        const render_item* item = m.m_nodes.at(context)->item;
        pixel_t x = 0, y = 0;
        litehtml::paint_origin(*item, x, y);
        return childrenOrigin(*item, x, y);
    }

    litehtml::pointF paintAt(const render_item& item) const {
        pixel_t x = 0, y = 0;
        litehtml::paint_origin(item, x, y);
        litehtml::pointF out;
        out.x = x.value();
        out.y = y.value();
        return out;
    }

    litehtml::pointF boxOrigin(const render_item& item, LayerId context) const {
        const litehtml::pointF at = paintAt(item);
        return minus(ownOrigin(item, pixel_t(at.x), pixel_t(at.y)), contextOrigin(context));
    }

    litehtml::pointF contentOrigin(const render_item& item, LayerId context) const {
        const litehtml::pointF at = paintAt(item);
        return minus(childrenOrigin(item, pixel_t(at.x), pixel_t(at.y)), contextOrigin(context));
    }

    // The clipping ancestors of what `from` paints, up to and including `contextItem`, outermost first, relative to the
    // context's origin (draw_children's clips: a table's and its parts' draw no clip).
    bool chainFor(const render_item* from, LayerId context, std::vector<MirrorClip>& out) {
        out.clear();
        const render_item* contextItem = m.m_nodes.at(context)->item;
        std::vector<const render_item*> path;
        for (const render_item* at = from; at;) {
            path.push_back(at);
            if (at == contextItem) {
                break;
            }
            const auto parent = at->parent();
            at = parent.get();
        }
        if (path.empty() || path.back() != contextItem) {
            return false;
        }
        const litehtml::pointF origin = contextOrigin(context);
        for (auto it = path.rbegin(); it != path.rend(); ++it) {
            const render_item* item = *it;
            if (isTableInternal(item)) {
                continue;
            }
            const litehtml::pointF at = paintAt(*item);
            litehtml::position box;
            litehtml::border_radiuses radius;
            if (!litehtml::paint_clip(*item, pixel_t(at.x), pixel_t(at.y), box, radius)) {
                continue;
            }
            MirrorClip step;
            ItemInfo* clipper = info(item);
            if (clipper) {
                if (!clipper->clipper) {
                    clipper->clipper = nextId(m.m_nextId);
                }
                step.clipper = clipper->clipper;
            } else {
                step.clipper = nextId(m.m_nextId);
            }
            step.key = m.m_keyOf(*item->src_el());
            step.box = litehtml::position(box.x.value() - origin.x, box.y.value() - origin.y, box.width, box.height);
            step.radius = radius;
            out.push_back(step);
        }
        return true;
    }

    // Where a node of (pass, z, order) goes among `context`'s children: before the first that sorts after it. nullopt
    // in a context whose children are not in that order (NodeInfo::captioned): the caller declines (lose()).
    std::optional<std::pair<size_t, LayerId>> placement(LayerId context, MirrorPass pass, int zindex,
                                                        uint64_t order) const {
        if (m.m_nodes.at(context)->captioned) {
            return std::nullopt;
        }
        const MirrorNode& parent = current(context);
        size_t index = 0;
        for (; index < parent.children.size(); index++) {
            const MirrorNode& child = *parent.children[index];
            const uint64_t childOrder = m.m_nodes.at(child.id)->order;
            const auto a = std::make_tuple(int(child.pass), child.zindex, childOrder);
            const auto b = std::make_tuple(int(pass), zindex, order);
            if (a > b) {
                break;
            }
        }
        return std::make_pair(index, index == 0 ? LayerId(0) : parent.children[index - 1]->id);
    }

    void detachChild(LayerId id) {
        NodeInfo& at = node(id);
        m_oldParent.emplace(id, at.parent);
        MirrorNode& parent = edit(at.parent);
        auto& list = parent.children;
        list.erase(std::remove_if(list.begin(), list.end(),
                                  [id](const std::shared_ptr<const MirrorNode>& child) { return child->id == id; }),
                   list.end());
    }

    // Moves `id` under `context` by the placement rule (or at `at`), with its origin and clips set; Move, Frame and
    // Clip. false where the rule cannot place it: the caller declines (lose()), which discards this update.
    [[nodiscard]] bool moveTo(LayerId id, LayerId context, const litehtml::pointF& origin, std::vector<MirrorClip> clips,
                              std::optional<size_t> at = std::nullopt) {
        detachChild(id);
        MirrorNode& moving = edit(id);
        moving.origin = origin;
        moving.clips = std::move(clips);
        const std::optional<std::pair<size_t, LayerId>> place =
            at ? std::make_pair(*at, *at == 0 ? LayerId(0) : current(context).children[*at - 1]->id)
               : placement(context, moving.pass, moving.zindex, node(id).order);
        if (!place) {
            return false;
        }
        const auto [index, after] = *place;
        MirrorNode& parent = edit(context);
        parent.children.insert(parent.children.begin() + ptrdiff_t(index), m_work.at(id));
        node(id).parent = context;
        emit(LayerOp::Move, id, context, after);
        emit(LayerOp::Frame, id);
        emit(LayerOp::Clip, id);
        return true;
    }

    void removeNode(LayerId id) {
        detachChild(id);
        emit(LayerOp::Remove, id);
        m_removed.push_back(id);
    }

    bool lose() { return false; }

    // ---- The reports. ----

    bool collect() {
        if (m.m_treeRebuilt || m.m_lost || !m.m_document) {
            return false;
        }
        std::unordered_set<const render_item*> texts(m.m_texts.begin(), m.m_texts.end());
        for (const render_item* item : m.m_removed) {
            ItemInfo* found = info(item);
            if (!found) {
                continue;
            }
            if (found->box || found->own || !found->runs.empty()) {
                return lose();
            }
            m.m_items.erase(item);
        }
        for (const auto& weak : m.m_added) {
            const auto item = weak.lock();
            if (!item) {
                continue;
            }
            const auto parent = item->parent();
            if (!parent || !texts.count(parent.get()) || !item->src_el()->is_inline() || isInlineBox(*item)) {
                return lose();
            }
        }
        for (const render_item* text : m.m_texts) {
            // Replaced text (twidget edit 16) re-captures its inline context's runs: the context itself, or for an inline
            // element's text the context it paints in (ItemInfo::runOf). An inline element that opens a context of its own
            // (a paint group) has none, its run being that context's, which is not placed here.
            const ItemInfo* found = info(text);
            const render_item* context = isInlineContext(text) ? text : (found ? found->runOf : nullptr);
            if (!found || !context) {
                return lose();
            }
            m_runs.add(context);
        }
        for (const auto& [item, what] : m.m_geometry) {
            if (!info(item)) {
                continue;
            }
            if (what & litehtml::render_observer::moved) {
                m_movedSet.add(item);
            }
            if (what & litehtml::render_observer::resized) {
                m_boxes.add(item);
                m_clipperSet.add(item);
                m_groupItems.add(item);
            }
            if (what & litehtml::render_observer::reflowed) {
                m_runs.add(item);
                if (item->src_el()->css().get_display() == litehtml::display_list_item) {
                    m_boxes.add(item);   // its marker follows its first line
                }
            }
            // A fieldset draws around its legend.
            if (const auto parent = item->parent(); parent && parent->src_el()->tag() == litehtml::_fieldset_) {
                m_boxes.add(parent.get());
            }
            // A table row paints its cells' backgrounds (draw_background): a cell that moved or resized (a column another
            // row widened) changes the row's own paint, though the row itself did not change.
            if (what & (litehtml::render_observer::moved | litehtml::render_observer::resized)) {
                if (const auto parent = item->parent();
                    parent && dynamic_cast<const litehtml::render_item_table_row*>(parent.get()) != nullptr) {
                    m_boxes.add(parent.get());
                }
            }
        }
        m_moved = m_movedSet.list;
        m_clippers = m_clipperSet.list;
        for (const auto& [el, order] : m.m_restyled) {
            restyled(el, order);
        }
        return true;
    }

    // Adds what an element's own paint lands in: its items' Boxes, and the runs of what is inline content.
    // The items of `el` the mirror saw paint.
    std::vector<const render_item*> painting(const litehtml::element& el) const {
        std::vector<const render_item*> out;
        auto it = m.m_byElement.find(&el);
        if (it != m.m_byElement.end()) {
            for (const render_item* item : it->second) {
                if (info(item)) {
                    out.push_back(item);
                }
            }
        }
        return out;
    }

    void paintedBy(const litehtml::element& el) {
        std::vector<const render_item*> items = painting(el);
        if (items.empty()) {
            // An element no item paints (an svg's shape, say): the nearest ancestor that does.
            for (auto parent = el.parent(); parent; parent = parent->parent()) {
                items = painting(*parent);
                if (!items.empty()) {
                    break;
                }
            }
        }
        for (const render_item* item : items) {
            const ItemInfo* found = info(item);
            if (found->runOf) {
                m_runs.add(found->runOf);
            } else {
                m_boxes.add(item);
            }
            if (!found->runs.empty()) {
                m_runs.add(item);
            }
        }
    }

    void restyled(const litehtml::element* el, bool order) {
        std::vector<const litehtml::element*> stack{el};
        bool body = false;
        while (!stack.empty()) {
            const litehtml::element* at = stack.back();
            stack.pop_back();
            body = body || at->is_body();
            paintedBy(*at);
            for (const auto& child : at->children()) {
                stack.push_back(child.get());
            }
        }
        // The root paints the body's background when it has none of its own.
        if (body && m.m_document->root_render()) {
            m_boxes.add(m.m_document->root_render().get());
        }
        if (order) {
            for (const render_item* item : painting(*el)) {
                m_paintOrder.push_back(item);
            }
            bool rendered = false;
            el->for_each_render_item([&](const std::shared_ptr<render_item>&) { rendered = true; });
            if (painting(*el).empty() && rendered) {
                m_unpainted = true;   // rendered but never painted (invisible): the change may show it
            }
        }
    }

    // ---- Paint order: an item becomes or stops being a paint group. ----

    // Every render item under `root` (not `root`), in pre-order.
    static std::vector<const render_item*> descendants(const render_item* root) {
        std::vector<const render_item*> out, stack;
        const auto& kids = const_cast<render_item*>(root)->children();
        for (auto it = kids.rbegin(); it != kids.rend(); ++it) {
            stack.push_back(it->get());
        }
        while (!stack.empty()) {
            const render_item* item = stack.back();
            stack.pop_back();
            out.push_back(item);
            const auto& more = const_cast<render_item*>(item)->children();
            for (auto it = more.rbegin(); it != more.rend(); ++it) {
                stack.push_back(it->get());
            }
        }
        return out;
    }

    // The items under `root` paint as they did: each still painted has its entry, none of them opens a context or
    // has runs another inline context split, and each is visible.
    bool plainSubtree(const render_item* root) const {
        for (const render_item* item : descendants(root)) {
            const ItemInfo* found = info(item);
            if (!item->is_visible()) {
                if (found) {
                    return false;
                }
                continue;
            }
            if (!found || found->own || found->runsSplit) {
                return false;
            }
        }
        return true;
    }

    static bool inFlowBlock(const render_item& item) {
        const auto& el = *item.src_el();
        return !el.is_inline() && el.css().get_float() == litehtml::float_none && !el.is_positioned() &&
               !isTableInternal(&item) && item.parent();
    }

    bool paintOrder(const render_item* item) {
        ItemInfo* found = info(item);
        const std::shared_ptr<render_item> locked = found ? found->item.lock() : nullptr;
        if (!found || !locked || !locked->is_visible()) {
            return lose();
        }
        // draw_children draws a paint group through draw_group; a table draws its cells, captions and rows itself and
        // never so, and the root is one only for a clip path (document::draw).
        const auto parent = locked->parent();
        if (!parent) {
            return lose();
        }
        const bool wasGroup = found->own && current(found->own).context == MirrorNode::ContextKind::Group;
        const bool isGroup = locked->src_el()->css().is_paint_group() && !isTableInternal(parent.get());
        if (!visibilityHolds(item)) {
            return lose();
        }
        if (wasGroup && isGroup) {
            m_groupItems.add(item);
            return true;
        }
        if (!wasGroup && !isGroup) {
            return true;
        }
        if (!inFlowBlock(*locked) || !plainSubtree(item)) {
            return lose();
        }
        return isGroup ? becomeGroup(item, *found, locked) : leaveGroup(item, *found);
    }

    // What paints under `root` is what painted: an item paints when it and every ancestor up to `root` is visible
    // (draw_children skips an invisible item and its subtree), and a table's parts never do (their rows and cells do).
    bool visibilityHolds(const render_item* root) const {
        std::vector<std::pair<const render_item*, bool>> stack;
        const auto& kids = const_cast<render_item*>(root)->children();
        for (auto it = kids.rbegin(); it != kids.rend(); ++it) {
            stack.emplace_back(it->get(), true);
        }
        while (!stack.empty()) {
            auto [item, above] = stack.back();
            stack.pop_back();
            const bool paints = above && item->is_visible();
            if (!dynamic_cast<const litehtml::render_item_table_part*>(item) && bool(info(item)) != paints) {
                return false;
            }
            const auto& more = const_cast<render_item*>(item)->children();
            for (auto it = more.rbegin(); it != more.rend(); ++it) {
                stack.emplace_back(it->get(), paints);
            }
        }
        return true;
    }

    bool becomeGroup(const render_item* item, ItemInfo& found, const std::shared_ptr<render_item>& locked) {
        const LayerId context = found.context;
        if (!context || !m.m_nodes.count(context)) {
            return lose();
        }
        // The group's parameters, from litehtml's draw_group.
        std::shared_ptr<MirrorGroup> group = params(locked);
        if (!group) {
            return lose();
        }
        auto created = std::make_shared<MirrorNode>();
        created->kind = MirrorNode::Kind::Context;
        created->context = MirrorNode::ContextKind::Group;
        created->id = nextId(m.m_nextId);
        created->key = m.m_keyOf(*locked->src_el());
        created->pass = found.pass;
        created->zindex = found.zindex;
        if (!chainFor(locked->parent().get(), context, created->clips)) {
            return lose();
        }
        created->origin = contentOrigin(*locked, context);
        created->group = std::move(group);
        const LayerId id = created->id;
        auto infoNode = std::make_unique<NodeInfo>();
        infoNode->parent = context;
        infoNode->item = item;
        infoNode->order = found.order;
        m.m_nodes[id] = std::move(infoNode);
        m_work[id] = created;
        m_inserted.insert(id);
        const std::optional<std::pair<size_t, LayerId>> place =
            placement(context, created->pass, created->zindex, found.order);
        if (!place) {
            return lose();
        }
        const auto [index, after] = *place;
        MirrorNode& parent = edit(context);
        parent.children.insert(parent.children.begin() + ptrdiff_t(index), created);
        emit(LayerOp::Insert, id, context, after);
        found.own = id;
        // Its own Box first, then every node under it, as the group paints them: the placement rule within it.
        if (found.box) {
            MirrorNode& box = edit(found.box);
            box.pass = MirrorPass::Own;
            box.zindex = 0;
            if (!moveTo(found.box, id, boxOrigin(*locked, id), {}, size_t(0))) {
                return lose();
            }
        }
        // Its own inline content, which its passes paint inside its clip.
        for (LayerId run : found.runs) {
            std::vector<MirrorClip> clips;
            if (!chainFor(item, id, clips)) {
                return lose();
            }
            if (!moveTo(run, id, contentOrigin(*locked, id), std::move(clips))) {
                return lose();
            }
        }
        for (const render_item* inner : descendants(item)) {
            ItemInfo* at = info(inner);
            if (!at) {
                continue;
            }
            if (at->box) {
                std::vector<MirrorClip> clips;
                if (!chainFor(inner->parent().get(), id, clips)) {
                    return lose();
                }
                if (!moveTo(at->box, id, boxOrigin(*inner, id), std::move(clips))) {
                    return lose();
                }
                at->context = id;
            }
            for (LayerId run : at->runs) {
                std::vector<MirrorClip> clips;
                if (!chainFor(inner, id, clips)) {
                    return lose();
                }
                if (!moveTo(run, id, contentOrigin(*inner, id), std::move(clips))) {
                    return lose();
                }
            }
            if (at->runOf || (!at->box && at->runs.empty())) {
                at->context = id;
            }
        }
        return true;
    }

    bool leaveGroup(const render_item* item, ItemInfo& found) {
        const LayerId own = found.own;
        const LayerId context = node(own).parent;
        const std::shared_ptr<render_item> locked = found.item.lock();
        if (!context || !locked) {
            return lose();
        }
        // Its children go back one by one by the placement rule, which needs them in tree order (NodeInfo::captioned).
        if (node(own).captioned) {
            return lose();
        }
        for (const auto& child : current(own).children) {
            if (child->kind == MirrorNode::Kind::Context) {
                return lose();
            }
        }
        // Everything it holds goes back to its context by the placement rule, its own Box first.
        const std::vector<std::shared_ptr<const MirrorNode>> held = current(own).children;
        for (const auto& child : held) {
            const LayerId id = child->id;
            const render_item* owner = node(id).item;
            std::vector<MirrorClip> clips;
            if (id == found.box) {
                MirrorNode& box = edit(id);
                box.pass = found.pass;
                box.zindex = found.zindex;
                if (!chainFor(locked->parent().get(), context, clips)) {
                    return lose();
                }
                if (!moveTo(id, context, boxOrigin(*locked, context), std::move(clips))) {
                    return lose();
                }
                continue;
            }
            if (child->kind == MirrorNode::Kind::Box) {
                if (!chainFor(owner->parent().get(), context, clips)) {
                    return lose();
                }
                if (!moveTo(id, context, boxOrigin(*owner, context), std::move(clips))) {
                    return lose();
                }
                if (ItemInfo* at = info(owner)) {
                    at->context = context;
                }
            } else {
                if (!chainFor(owner, context, clips)) {
                    return lose();
                }
                if (!moveTo(id, context, contentOrigin(*owner, context), std::move(clips))) {
                    return lose();
                }
            }
        }
        for (const render_item* inner : descendants(item)) {
            if (ItemInfo* at = info(inner); at && at->context == own) {
                at->context = context;
            }
        }
        removeNode(own);
        found.own = 0;
        found.context = context;
        return true;
    }

    // ---- Re-capture. ----

    bool recaptureBox(const render_item* item) {
        ItemInfo* found = info(item);
        const std::shared_ptr<render_item> locked = found ? found->item.lock() : nullptr;
        if (!found) {
            return true;
        }
        if (!locked) {
            return lose();   // an expired item is a change the mirror cannot place
        }
        if (found->multi) {
            return lose();
        }
        if (found->runOf) {
            m_runs.add(found->runOf);
            return recaptureRuns(found->runOf);
        }
        const litehtml::pointF at = paintAt(*locked);
        std::shared_ptr<Layer> content =
            captureBox(m_container, locked, found->background, pixel_t(at.x), pixel_t(at.y));
        const LayerId context = found->own ? found->own : found->context;
        if (!context || !m.m_nodes.count(context)) {
            return true;
        }
        if (found->box) {
            if (content->entries.empty()) {
                removeNode(found->box);
                found->box = 0;
                return true;
            }
            MirrorNode& box = edit(found->box);
            box.content = std::move(content);
            box.origin = boxOrigin(*locked, context);
            emit(LayerOp::Content, found->box);
            return true;
        }
        if (content->entries.empty()) {
            return true;
        }
        // A decoration that was not there: a new Box, by the placement rule (a context's own Box first).
        auto created = std::make_shared<MirrorNode>();
        created->kind = MirrorNode::Kind::Box;
        created->id = nextId(m.m_nextId);
        created->key = m.m_keyOf(*locked->src_el());
        created->pass = found->own ? MirrorPass::Own : found->pass;
        created->zindex = found->own ? 0 : found->zindex;
        created->origin = boxOrigin(*locked, context);
        created->content = std::move(content);
        if (!found->own && !chainFor(locked->parent().get(), context, created->clips)) {
            return lose();
        }
        const LayerId id = created->id;
        auto infoNode = std::make_unique<NodeInfo>();
        infoNode->parent = context;
        infoNode->item = item;
        infoNode->order = found->order;
        m.m_nodes[id] = std::move(infoNode);
        m_work[id] = created;
        m_inserted.insert(id);
        const std::optional<std::pair<size_t, LayerId>> place =
            found->own ? std::make_pair(size_t(0), LayerId(0))
                       : placement(context, created->pass, created->zindex, found->order);
        if (!place) {
            return lose();
        }
        const auto [index, after] = *place;
        MirrorNode& parent = edit(context);
        parent.children.insert(parent.children.begin() + ptrdiff_t(index), created);
        emit(LayerOp::Insert, id, context, after);
        found->box = id;
        return true;
    }

    bool recaptureRuns(const render_item* item) {
        if (!m_runsDone.insert(item).second) {
            return true;
        }
        ItemInfo* found = info(item);
        const std::shared_ptr<render_item> locked = found ? found->item.lock() : nullptr;
        if (!found || !locked || found->runs.empty()) {
            return true;
        }
        // A line that changed (text, a restyle, a reflow) moves an inline paint group in it, whose run is its own
        // context's: not placed by re-capturing this one's (ItemInfo::subContexts). A line that moved whole did not.
        if (found->runsSplit || found->multi || (found->subContexts && !m_moving)) {
            return lose();
        }
        Walker walker(m, m_container, Walker::Mode::Runs);
        {
            struct EndWalk {
                WidgetContainer& container;
                ~EndWalk() { container.endWalk(); }
            } endWalk{m_container};
            m_container.beginWalk(walker);
            // Where draw() paints it, so the runs are what record() records, moved to their origin.
            pixel_t x = 0, y = 0;
            litehtml::paint_origin(*locked, x, y);
            walker.runOrigin = childrenOrigin(*locked, x, y);
            litehtml::with_paint_visitor(walker,
                                         [&] { locked->draw_children(0, x, y, nullptr, litehtml::draw_inlines, 0); });
        }
        if (walker.lost || walker.runs.size() != found->runs.size()) {
            return lose();
        }
        const LayerId context = node(found->runs.front()).parent;
        const litehtml::pointF origin = contentOrigin(*locked, context);
        for (size_t k = 0; k < found->runs.size(); k++) {
            MirrorNode& run = edit(found->runs[k]);
            run.content = std::move(walker.runs[k]);
            run.origin = origin;
            emit(LayerOp::Content, found->runs[k]);
        }
        return true;
    }

    // ---- Geometry. ----

    // `item` and every render item under it, in pre-order.
    static std::vector<const render_item*> subtree(const render_item* item) {
        std::vector<const render_item*> out{item};
        for (const render_item* inner : descendants(item)) {
            out.push_back(inner);
        }
        return out;
    }

    // Every group Context at or under `id`.
    void groupsUnder(LayerId id) {
        std::vector<LayerId> stack{id};
        while (!stack.empty()) {
            const LayerId at = stack.back();
            stack.pop_back();
            const MirrorNode& n = current(at);
            if (n.kind != MirrorNode::Kind::Context) {
                continue;
            }
            if (n.group) {
                m_groupNodes.add(at);
            }
            for (const auto& child : n.children) {
                stack.push_back(child->id);
            }
        }
    }

    bool frame(LayerId id, const litehtml::pointF& origin) {
        MirrorNode& n = edit(id);
        n.origin = origin;
        emit(LayerOp::Frame, id);
        return true;
    }

    // An item moved within its parent: every node of its subtree whose context does not move with it (one whose item
    // is outside the subtree) gets a Frame, and a Clip when a clipper of the subtree clips it; a group's parameters,
    // in document coordinates, are computed again. Nodes inside a context that moves with it are relative to it.
    bool moved(const render_item* item) {
        const std::vector<const render_item*> items = subtree(item);
        std::unordered_set<LayerId> moving, clippers;
        for (const render_item* at : items) {
            if (const ItemInfo* found = info(at)) {
                if (found->own) {
                    moving.insert(found->own);
                }
                if (found->clipper) {
                    clippers.insert(found->clipper);
                }
            }
        }
        std::vector<LayerId> framed;
        // Painting rounds a box to whole pixels and text to the snap grid, in document coordinates: content moved by a
        // fraction of a pixel is not what painting it at its new place gives (widget-sandbox v0.1.1's line height 1.35
        // makes such moves common), so the subtree is then painted again. Any fraction: a move a hair off a whole number
        // (twidget edit 20 reports it exactly) leaves content captured at the old place a hair off a fresh walk's.
        bool fractional = false;
        auto place = [&](LayerId id, const litehtml::pointF& origin) {
            const litehtml::pointF before = current(id).origin;
            const double dx = double(origin.x) - double(before.x), dy = double(origin.y) - double(before.y);
            fractional = fractional || dx != std::round(dx) || dy != std::round(dy);
            frame(id, origin);
            framed.push_back(id);
        };
        for (const render_item* at : items) {
            const ItemInfo* found = info(at);
            if (!found) {
                continue;
            }
            if (found->multi) {
                return lose();
            }
            if (found->own) {
                groupsUnder(found->own);
                const LayerId parent = node(found->own).parent;
                if (!parent) {
                    place(found->own, childrenOrigin(*at, 0, 0));
                } else if (!moving.count(parent)) {
                    place(found->own, contentOrigin(*at, parent));
                }
            }
            if (found->box && !moving.count(node(found->box).parent)) {
                place(found->box, boxOrigin(*at, node(found->box).parent));
            }
            for (LayerId run : found->runs) {
                if (!moving.count(node(run).parent)) {
                    place(run, contentOrigin(*at, node(run).parent));
                }
            }
        }
        for (LayerId id : framed) {
            bool affected = false;
            for (const MirrorClip& clip : current(id).clips) {
                affected = affected || clippers.count(clip.clipper);
            }
            if (affected && !reclip(id)) {
                return lose();
            }
        }
        if (fractional) {
            struct Moving {
                bool& flag;
                ~Moving() { flag = false; }
            } moving{m_moving};
            m_moving = true;
            for (const render_item* at : items) {
                const ItemInfo* found = info(at);
                if (!found) {
                    continue;
                }
                if (!recaptureBox(at) || (!found->runs.empty() && !recaptureRuns(at))) {
                    return false;
                }
            }
        }
        return true;
    }

    // Recomputes a node's clips from the render tree; Clip.
    bool reclip(LayerId id) {
        const NodeInfo& at = node(id);
        const MirrorNode& n = current(id);
        if (n.pass == MirrorPass::Own) {
            return true;
        }
        const render_item* from = n.kind == MirrorNode::Kind::Inline ? at.item : at.item->parent().get();
        std::vector<MirrorClip> clips;
        if (!chainFor(from, at.parent, clips)) {
            return false;
        }
        edit(id).clips = std::move(clips);
        emit(LayerOp::Clip, id);
        return true;
    }

    // A clipper resized: every node of its subtree whose clips hold it gets them again.
    bool clipped(const render_item* item) {
        const ItemInfo* found = info(item);
        if (!found || !found->clipper) {
            return true;
        }
        for (const render_item* at : subtree(item)) {
            const ItemInfo* inner = info(at);
            if (!inner) {
                continue;
            }
            std::vector<LayerId> nodes = inner->runs;
            if (inner->own) {
                nodes.push_back(inner->own);
                for (const auto& child : current(inner->own).children) {
                    nodes.push_back(child->id);
                }
            }
            if (inner->box) {
                nodes.push_back(inner->box);
            }
            for (LayerId id : nodes) {
                if (!m.m_nodes.count(id)) {
                    continue;
                }
                bool affected = false;
                for (const MirrorClip& clip : current(id).clips) {
                    affected = affected || clip.clipper == found->clipper;
                }
                if (affected && !reclip(id)) {
                    return lose();
                }
            }
        }
        return true;
    }

    // ---- Groups. ----

    std::shared_ptr<MirrorGroup> params(const std::shared_ptr<render_item>& item) {
        Walker walker(m, m_container, Walker::Mode::Params);
        struct EndWalk {
            WidgetContainer& container;
            ~EndWalk() { container.endWalk(); }
        } endWalk{m_container};
        m_container.beginWalk(walker);
        pixel_t x = 0, y = 0;
        litehtml::paint_origin(*item, x, y, true);
        litehtml::with_paint_visitor(walker, [&] { item->draw_group(0, x, y, nullptr, item); });
        return walker.lost ? nullptr : walker.group;
    }

    bool groups() {
        for (const render_item* item : m_groupItems.list) {
            const ItemInfo* found = info(item);
            if (found && found->own && current(found->own).group) {
                m_groupNodes.add(found->own);
            }
        }
        // A group's bounds follow its ink: every group above a node an op names.
        std::vector<LayerId> named;
        for (const LayerOp& op : m_ops) {
            named.push_back(op.node);
            if (op.parent) {
                named.push_back(op.parent);
            }
        }
        for (LayerId id : named) {
            if (!m.m_nodes.count(id)) {
                continue;
            }
            for (LayerId at = node(id).parent; at; at = node(at).parent) {
                if (current(at).group) {
                    m_groupNodes.add(at);
                }
            }
        }
        for (LayerId id : m_groupNodes.list) {
            if (!m.m_nodes.count(id) || m_inserted.count(id)) {
                continue;
            }
            const std::shared_ptr<render_item> item = locked(node(id).item);
            if (!item) {
                return lose();
            }
            std::shared_ptr<MirrorGroup> group = params(item);
            if (!group) {
                return lose();
            }
            edit(id).group = std::move(group);
            emit(LayerOp::Group, id);
        }
        return true;
    }

    // ---- Publishing. ----

    // The published path of `id` before this update (its ancestors from the root) and its published object.
    bool oldPath(LayerId id, MirrorPath& out) const {
        std::vector<const MirrorNode*> path;
        auto object = [this](LayerId at) -> const MirrorNode* {
            auto old = m_old.find(at);
            if (old != m_old.end()) {
                return old->second.get();
            }
            auto it = m.m_nodes.find(at);
            return it == m.m_nodes.end() ? nullptr : it->second->node.get();
        };
        auto parentOf = [this](LayerId at) -> LayerId {
            auto old = m_oldParent.find(at);
            if (old != m_oldParent.end()) {
                return old->second;
            }
            auto it = m.m_nodes.find(at);
            return it == m.m_nodes.end() ? 0 : it->second->parent;
        };
        const MirrorNode* self = object(id);
        if (!self) {
            return false;
        }
        for (LayerId at = parentOf(id); at; at = parentOf(at)) {
            const MirrorNode* ancestor = object(at);
            if (!ancestor) {
                return false;
            }
            path.push_back(ancestor);
        }
        std::reverse(path.begin(), path.end());
        out = {std::move(path), self};
        return true;
    }

    bool newPath(LayerId id, MirrorPath& out) const {
        auto it = m.m_nodes.find(id);
        if (it == m.m_nodes.end()) {
            return false;
        }
        std::vector<const MirrorNode*> path;
        for (LayerId at = it->second->parent; at; at = m.m_nodes.at(at)->parent) {
            path.push_back(m.m_nodes.at(at)->node.get());
        }
        std::reverse(path.begin(), path.end());
        out = {std::move(path), it->second->node.get()};
        return true;
    }

    std::optional<Publish> freeze() {
        Publish published;
        if (m_ops.empty() && m_work.empty()) {
            published.tree = m.m_tree;
            published.changedRects = std::vector<litehtml::position>();
            return published;
        }
        // The old rects first, while the published objects are in place.
        std::vector<MirrorPath> rects;
        for (const LayerOp& op : m_ops) {
            if (op.kind == LayerOp::Insert || m_inserted.count(op.node)) {
                continue;
            }
            MirrorPath path;
            if (oldPath(op.node, path)) {
                rects.push_back(std::move(path));
            }
        }
        // Path copying: every edited node's ancestors are edited too, and each edited node holds the edited children.
        std::vector<LayerId> edited;
        for (const auto& [id, n] : m_work) {
            edited.push_back(id);
        }
        for (LayerId id : edited) {
            if (!m.m_nodes.count(id)) {
                continue;
            }
            for (LayerId at = node(id).parent; at; at = node(at).parent) {
                edit(at);
            }
        }
        for (auto& [id, n] : m_work) {
            for (auto& child : n->children) {
                auto it = m_work.find(child->id);
                if (it != m_work.end()) {
                    child = it->second;
                }
            }
        }
        for (auto& [id, n] : m_work) {
            if (m.m_nodes.count(id)) {
                m.m_nodes.at(id)->node = n;
            }
        }
        // What was removed leaves the tables, its subtree with it.
        for (LayerId id : m_removed) {
            std::vector<LayerId> stack{id};
            while (!stack.empty()) {
                const LayerId at = stack.back();
                stack.pop_back();
                auto it = m.m_nodes.find(at);
                if (it == m.m_nodes.end()) {
                    continue;
                }
                for (const auto& child : it->second->node->children) {
                    stack.push_back(child->id);
                }
                m.m_nodes.erase(it);
            }
        }
        const std::shared_ptr<const MirrorNode> root = m.m_nodes.at(m.m_root)->node;
        const double width = double(m.m_document->width().value());
        const double height = double(m.m_document->height().value());
        for (const LayerOp& op : m_ops) {
            if (op.kind == LayerOp::Remove) {
                continue;
            }
            MirrorPath path;
            if (newPath(op.node, path)) {
                rects.push_back(std::move(path));
            }
        }
        const std::shared_ptr<const LayerTree> before = m.m_tree;
        published.tree = std::make_shared<const LayerTree>(width, height, root, canvasColor(*m.m_document));
        if (before && (before->width() != width || before->height() != height)) {
            published.changedRects = std::nullopt;
        } else {
            published.changedRects =
                mirrorRects(before ? before->mirror() : nullptr, *root, rects, width, height);
        }
        published.ops = std::move(m_ops);
        m.m_tree = published.tree;
        m.m_width = width;
        m.m_height = height;
        return published;
    }

    LayerMirror& m;
    WidgetContainer& m_container;
    std::unordered_map<LayerId, std::shared_ptr<MirrorNode>> m_work;
    std::unordered_map<LayerId, std::shared_ptr<const MirrorNode>> m_old;
    std::unordered_map<LayerId, LayerId> m_oldParent;
    std::unordered_set<LayerId> m_inserted;
    std::vector<LayerId> m_removed;
    std::vector<LayerOp> m_ops;
    std::set<std::pair<int, LayerId>> m_emitted;
    std::unordered_set<const render_item*> m_runsDone;
    /// Set while moved() paints a fractionally moved subtree again (recaptureRuns).
    bool m_moving = false;
    Ordered<const render_item*> m_boxes, m_runs, m_movedSet, m_clipperSet, m_groupItems;
    Ordered<LayerId> m_groupNodes;
    std::vector<const render_item*> m_moved, m_clippers, m_paintOrder;
    bool m_unpainted = false;
};

std::optional<LayerMirror::Publish> LayerMirror::publish() {
    std::optional<Publish> published;
    {
        Update update(*this);
        published = update.run();
    }
    clearReports();
    return published;
}

// ---- The mirror. ----

LayerMirror::LayerMirror(KeyOf keyOf, LayerId& nextId) : m_keyOf(std::move(keyOf)), m_nextId(nextId) {}

LayerMirror::~LayerMirror() {
    detach();
}

void LayerMirror::detach() {
    if (m_document && m_observing && m_document->get_render_observer() == this) {
        m_document->set_render_observer(nullptr);
    }
    m_observing = false;
}

void LayerMirror::clearReports() {
    m_treeRebuilt = false;
    m_lost = false;
    m_removed.clear();
    m_added.clear();
    m_texts.clear();
    m_restyled.clear();
    m_geometry.clear();
}

std::shared_ptr<const LayerTree> LayerMirror::build(litehtml::document& document, WidgetContainer& container,
                                                    bool observe) {
    detach();
    m_document = &document;
    m_container = &container;
    m_items.clear();
    m_byElement.clear();
    m_nodes.clear();
    m_tree.reset();
    clearReports();
    Walker walker(*this, container, Walker::Mode::Build);
    struct EndWalk {
        WidgetContainer& container;
        ~EndWalk() { container.endWalk(); }
    } endWalk{container};
    container.beginWalk(walker);
    litehtml::walk_paint_order(document, walker, 0, pixel_t(0), pixel_t(0));
    m_walks++;
    walker.finish();
    m_width = double(document.width().value());
    m_height = double(document.height().value());
    std::shared_ptr<MirrorNode> root = walker.root;
    if (!root) {
        // An empty document: a root context with nothing in it.
        root = std::make_shared<MirrorNode>();
        root->kind = MirrorNode::Kind::Context;
        root->id = nextId(m_nextId);
    }
    m_root = root->id;
    auto info = std::make_unique<NodeInfo>();
    info->node = root;
    info->item = document.root_render().get();
    m_nodes[root->id] = std::move(info);
    for (LayerId id : walker.captioned) {
        if (auto it = m_nodes.find(id); it != m_nodes.end()) {
            it->second->captioned = true;
        }
    }
    m_lost = walker.lost;
    m_tree = std::make_shared<const LayerTree>(m_width, m_height, std::shared_ptr<const MirrorNode>(root), canvasColor(document));
    if (observe) {
        document.set_render_observer(this);
        m_observing = true;
    }
    return m_tree;
}

// litehtml::render_observer: record, never throw.

void LayerMirror::item_added(const std::shared_ptr<litehtml::render_item>& item) {
    try {
        m_added.push_back(item);
    } catch (...) {
        m_lost = true;
    }
}

void LayerMirror::item_removed(const litehtml::render_item* item) {
    try {
        m_removed.push_back(item);
    } catch (...) {
        m_lost = true;
    }
}

void LayerMirror::item_geometry_changed(const litehtml::render_item* item, unsigned what) {
    try {
        m_geometry.emplace_back(item, what);
    } catch (...) {
        m_lost = true;
    }
}

void LayerMirror::element_restyled(const litehtml::element* el, bool paint_order) {
    try {
        m_restyled.emplace_back(el, paint_order);
    } catch (...) {
        m_lost = true;
    }
}

void LayerMirror::text_replaced(const litehtml::render_item* inline_context) {
    try {
        m_texts.push_back(inline_context);
    } catch (...) {
        m_lost = true;
    }
}

void LayerMirror::tree_rebuilt() {
    m_treeRebuilt = true;
}

} // namespace wr
