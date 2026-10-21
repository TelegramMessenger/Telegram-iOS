// The layer mirror (M1c plan, Task 10b; twidget edit 20): the published tree mirrors litehtml's painting, with stable
// identity, and is kept current by operations the fork reports at its own mutation points. Nothing in the update path
// compares anything: no tree diff, no placement comparison outside the fork's write sites, no re-walk.
//
// The model (litehtml's, read in the fork): a render item's own paint happens exactly once, in one pass of one painting
// context. The contexts are the root, a positioned item's stacking context, a float's or an inline-block's pseudo-context
// (its positioned descendants still belong to the enclosing stacking context) and a paint group (opacity, transform,
// filter, clip-path, backdrop-filter, sticky), which paints its own positioned descendants. A context's passes run in
// order: its own item's paint, positioned with z < 0, block, floats, inlines, positioned at z = 0, positioned with z > 0.
// The nodes (LayerTree.h, MirrorNode):
// - Context, one per painting context: its group parameters and its children, its passes concatenated;
// - Box, one per render item whose own draw paints a decoration (background, borders, a list marker, an image, a form
//   control, an svg), holding that one call's items, captured alone, in its context's pass;
// - Inline, one per run of an inline context's inlines-pass content (span decorations and text runs, in order); each
//   sub-context or nested inline context it contains splits it, so a paragraph of text is one node.
// Each node's items are relative to its origin (a Box's: its item's position; an Inline's: its inline context's
// content origin; a Context's: its item's content origin), its origin is relative to its context's (a Context's to its
// parent's), and its clips are the clipping ancestors inside its context, outermost first. Flattening composes them back
// (LayerTree::root), which is what makes WidgetContainer::record the oracle.
//
// Building: build() runs walk_paint_order once (the only walk) with this mirror as the visitor, and the container in walk
// mode (WidgetContainer::beginWalk), so draw()'s own calls (clips, groups, filters, backdrops, clip escapes) reach the
// mirror in draw()'s order, and each item's own paint is captured alone (WidgetContainer::capture), at coordinates that
// make its items relative to its node's origin.
//
// Updating: the mirror is the document's render_observer. What the fork reports between two publishes is applied at the
// next publish(), as operations:
// - a text replacement (edit 16) re-captures its inline context's runs (Content); the pieces it added and removed belong
//   to those runs;
// - layout's changed boxes (reported at the write, edit 20): a move gives a Frame to every node whose origin depends on
//   the item in its context (its own nodes, its descendants' up to the sub-contexts, the sub-contexts themselves) and a
//   Clip to those a moved clipper clips; a resize re-captures its Box (Content) and gives a Clip to what it clips; an
//   inline context's re-flowed content re-captures its runs. Nodes that merely moved are never re-captured;
// - a restyle with the render tree kept (edit 17): its subtree's Boxes and runs are re-captured (Content); an item that
//   becomes or stops being a paint group gets a Context inserted or removed and its subtree's nodes moved (Move, Frame,
//   Clip), placed by the placement rule below; a group whose parameters changed gets Group;
// - a group whose subtree changed, moved or was re-captured has its parameters computed again (Group), since its bounds
//   follow its ink.
// The placement rule: a node goes into its context, in the pass its item's style gives, after the nearest earlier node
// in tree order in that pass (tree order: the render tree's pre-order, numbered at build). Nothing walks the paint order.
// A table paints its captions before its rows, so in a context where a caption that follows its rows in the tree paints,
// the children are not in tree order and nothing is placed: the update declines (Ruling E39).
// Published nodes are immutable: an operation on a node publishes a new object with the same id and copies its path to
// the root; every other node is the same object as in the previous tree. A report the mirror cannot place (an item added
// or removed outside a text replacement, a paint-order change it does not model, a paint call outside a capture, a node
// the placement rule cannot place) makes publish() decline, and the caller builds a new mirror and publishes Reset, as
// it does when the fork reports tree_rebuilt (any structural patch, and any attribute patch apply_retag does not call
// neutral). That fallback is correct and counted (RenderTree::treeRebuildResets, unplaceableResets).
//
// Lifetime: a mirror observes one document and must be destroyed before it (it detaches itself). Its side tables hold
// render items weakly and elements only between a report and the next publish. Nothing published points into the
// document, an element, the container or a host handle (Review Focus 5).
#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <optional>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <litehtml/document.h>
#include <litehtml/render_item.h>

#include "Sources/Render/LayerTree.h"
#include "Sources/Render/WidgetContainer.h"

namespace wr {

/// One operation on the published structure, which the app applies to its layers in order (M1d: one CALayer per node).
struct LayerOp {
    enum Kind : uint8_t {
        /// Everything is new: the tree replaces the previous one (a build). The only op of its publish.
        Reset,
        /// `node` is new, the child of `parent` after `after` (0: first). Its own children follow as their own Inserts.
        Insert,
        /// `node` and everything under it are gone.
        Remove,
        /// `node`, with what it holds, moves under `parent` after `after` (0: first).
        Move,
        /// `node`'s origin changed; what it holds did not.
        Frame,
        /// `node` (a Box or an Inline) paints something else.
        Content,
        /// `node`'s clips changed.
        Clip,
        /// `node` (a Context)'s group parameters changed.
        Group,
    };
    Kind kind = Reset;
    LayerId node = 0;
    LayerId parent = 0;
    LayerId after = 0;
};

class LayerMirror final : public litehtml::render_observer {
public:
    /// The NodeKey of an element's DOM node, 0 for what no node owns. Must not throw.
    using KeyOf = std::function<NodeKey(const litehtml::element&)>;
    /// Ids come from `nextId`, which the owner keeps for its life (LayerId: never reused within a RenderTree).
    LayerMirror(KeyOf keyOf, LayerId& nextId);
    ~LayerMirror() override;
    LayerMirror(const LayerMirror&) = delete;
    LayerMirror& operator=(const LayerMirror&) = delete;

    /// Walks `document` (laid out through `container`) once into a new mirror and returns its tree. With `observe`, the
    /// mirror becomes the document's render observer until it is destroyed (or another build observes). Throws
    /// std::bad_alloc, leaving the mirror empty.
    std::shared_ptr<const LayerTree> build(litehtml::document& document, WidgetContainer& container, bool observe = true);

    struct Publish {
        std::shared_ptr<const LayerTree> tree;
        std::vector<LayerOp> ops;
        /// From the operations: each named node's old and new rects (LayerDiff's mirrorRects); nullopt for everything.
        std::optional<std::vector<litehtml::position>> changedRects;
    };
    /// Whether the fork dropped and rebuilt its render tree since the last build or publish: the next publish needs a
    /// new mirror (Reset).
    bool treeRebuilt() const { return m_treeRebuilt; }
    /// Applies what the fork reported since the last build or publish (the file comment) and returns the next tree with
    /// its operations; nullopt, with nothing published, when the fork rebuilt its render tree or a report cannot be
    /// placed: the caller builds a new mirror. An empty report publishes the same tree and no operation. Throws
    /// std::bad_alloc, publishing nothing.
    std::optional<Publish> publish();
    /// walk_paint_order runs (tests): one per build.
    uint64_t walks() const { return m_walks; }
    std::shared_ptr<const LayerTree> tree() const { return m_tree; }

    // litehtml::render_observer: record only. Never throws (a failure to record makes the next publish decline).
    void item_added(const std::shared_ptr<litehtml::render_item>& item) override;
    void item_removed(const litehtml::render_item* item) override;
    void item_geometry_changed(const litehtml::render_item* item, unsigned what) override;
    void element_restyled(const litehtml::element* el, bool paint_order) override;
    void text_replaced(const litehtml::render_item* inline_context) override;
    void tree_rebuilt() override;

    /// What the side tables keep for a render item and a node (LayerMirror.cpp).
    struct ItemInfo;
    struct NodeInfo;

private:
    class Walker;
    class Update;
    friend class Walker;
    friend class Update;

    void detach();
    void clearReports();

    KeyOf m_keyOf;
    LayerId& m_nextId;
    litehtml::document* m_document = nullptr;
    WidgetContainer* m_container = nullptr;
    bool m_observing = false;
    uint64_t m_walks = 0;
    double m_width = 0;
    double m_height = 0;
    std::shared_ptr<const LayerTree> m_tree;
    std::unordered_map<const litehtml::render_item*, std::unique_ptr<ItemInfo>> m_items;
    /// Each element's items the walk saw paint (litehtml's own list leaves a table row's out).
    std::unordered_map<const litehtml::element*, std::vector<const litehtml::render_item*>> m_byElement;
    std::unordered_map<LayerId, std::unique_ptr<NodeInfo>> m_nodes;
    LayerId m_root = 0;

    // What the fork reported since the last publish.
    bool m_treeRebuilt = false;
    bool m_lost = false;
    std::vector<const litehtml::render_item*> m_removed;
    std::vector<std::weak_ptr<litehtml::render_item>> m_added;
    std::vector<const litehtml::render_item*> m_texts;
    std::vector<std::pair<const litehtml::element*, bool>> m_restyled;
    std::vector<std::pair<const litehtml::render_item*, unsigned>> m_geometry;
};

} // namespace wr
