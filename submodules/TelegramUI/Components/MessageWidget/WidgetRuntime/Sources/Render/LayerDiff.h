// The layer tree's diff (M1c plan, Task 4): which rects of the canvas a new tree paints differently from the previous
// one. From Task 10b on a flush that patches publishes the rects its operations name (LayerMirror), and this diff is the
// tests' oracle (Ruling 8): nothing in the update path compares trees.
//
// Two mirrors (LayerTree::mirror) are compared node by node instead of item by item: in each pair of matched contexts
// the children are matched first by identity (the same object in both trees: a mirror's publishes share every node no
// operation names), then by kind, NodeKey and their order among the rest of that kind and key, so an inserted node does
// not make every later one differ, an anonymous one (key 0) included. A matched Box or Inline that differs (origin, pass, clips or content), an
// unmatched node, and a matched context whose own properties differ give their old and new rects (a context's: all it
// holds); children that changed order give every matched child's, the order being the shared ones' when the trees share
// nodes (a pair matched by key that sits elsewhere among them gives its own). Backdrops then as below.
//
// The walk is positional: both trees are walked in parallel, entry by entry, from the root.
// - Equal items produce nothing. Items are compared by kind and payload (samePaint); fonts, images and a text item's
//   shared font description by identity.
// - Two layers with equal own properties (sameLayerProperties) are entered and compared entry by entry.
// - Anything else (items that differ, a layer whose own properties differ, an item facing a layer, an entry present in
//   only one tree) produces, for each side present, its bounds; for a layer, its bounds together with everything
//   inside it, so contents that overflow a group's bounds (a child's shadow) are not missed.
// - Each rect is mapped to root coordinates through the enclosing groups' matrices (the bounding box of the mapped
//   corners). A rect inside a Filter layer is first grown by the filter's reach (litehtml::filter_reach: a blur or a
//   drop shadow spreads what changed), in that layer's coordinates. A matrix that composes to a non-finite one maps
//   to the whole canvas. (Every transform_matrix is a 2D affine one, and litehtml already resets a non-finite CSS
//   transform to identity, so "a group whose matrix is not affine" only arises this way.)
// - Then backdrops: a backdrop filters what is painted behind it, so it changes when anything it samples changes, even
//   when its own item is equal. Every Backdrop item of both trees (the `before` one covers a backdrop that moved or
//   vanished), its bounds in root coordinates grown by its steps' reach, that overlaps a changed rect is added as a
//   changed rect; that repeats until none is added, since an added backdrop can reach another. A tree with more than
//   64 Backdrop items (kMaxDiffedBackdrops, Ruling E3) answers nullopt instead, which bounds this step at 64 × 64.
// - Empty rects are dropped, and a rect equal to the one before it is not repeated.
//
// Positional comparison over-reports after an insertion, since every later entry then differs, and never
// under-reports.
#pragma once

#include <optional>
#include <vector>

#include <litehtml/types.h>

#include "Sources/Render/LayerTree.h"

namespace wr {

/// The rects, in root (canvas) coordinates, that `after` paints differently from `before`. nullopt means everything
/// changed: there is no previous tree, the two differ in size, or either holds more than 64 Backdrop items.
std::optional<std::vector<litehtml::position>> changedRects(const LayerTree* before, const LayerTree& after);

/// For a mirror's operations (LayerMirror): the rect in root coordinates each node paints (a Context: everything it
/// holds), each given with its ancestors from the root (the root first, the node not included), then every backdrop of
/// `before` or `after` that overlaps one, as changedRects adds them. nullopt past 64 backdrops in either tree.
using MirrorPath = std::pair<std::vector<const MirrorNode*>, const MirrorNode*>;
std::optional<std::vector<litehtml::position>> mirrorRects(const MirrorNode* before, const MirrorNode& after,
                                                           const std::vector<MirrorPath>& nodes, double width,
                                                           double height);

} // namespace wr
