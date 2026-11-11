// The layer tree (M1c plan, Task 4): litehtml's paint calls, recorded by WidgetContainer::record into plain data the
// app paints later (Ruling 3), possibly on another thread while the runtime builds the next tree.
//
// Plain data (Global Constraints, "The layer tree is plain data"):
// - Nothing in it points into a document, a container or the container's font-handle table: no Node*, no litehtml
//   element or document pointer, no uint_ptr handle. litehtml's list_marker keeps its `baseurl` and `font` fields, but
//   they are always nullptr and 0 here.
// - Fonts and images are held by std::shared_ptr; a HostFont or HostImage is self-contained, so a tree stays valid
//   after its document, its container and the host that made them are gone (Review Focus 5).
// - Every paint argument is copied by value, filter steps included (filter_paint::steps points into the element's
//   style, and its `owner` is an element pointer: the steps are copied and the owner dropped).
// - Once published it is immutable, shared as std::shared_ptr<const LayerTree>, and safe to read on any thread.
//
// Coordinates: litehtml paints in document coordinates. A Group's matrix maps its contents to its parent (row
// vectors, as CGAffineTransform: x' = a·x + c·y + tx, y' = b·x + d·y + ty), so a Group's entries and its
// `group.bounds` are in its own, untransformed space. Filter and Isolated layers do not move their contents.
//
// Nothing here recurses over the tree: building, dumping, counting, diffing and destroying walk it with explicit
// stacks (Global Constraints, "Stack"), since layers nest about as deep as the elements that open them.
//
// The mirror (Task 10b). The runtime publishes a different shape of the same tree: MirrorNode, which mirrors litehtml's
// painting (LayerMirror.h) as painting contexts (Context), the decorations one render item's own draw paints (Box) and
// the runs of an inline context's content (Inline), with stable identity, kept current by operations. A mirror's items
// are relative to their node's origin, and its clips are each node's chain of clipping ancestors in its context; root()
// and dump() of a mirror's LayerTree are its flattening: the origins composed back to document coordinates and the clip
// chains and group parameters turned back into the layers and items record() makes, so record() is its oracle.
#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <variant>
#include <vector>

#include <litehtml/document_container.h>

#include "Sources/Render/RenderHost.h"

namespace wr {

/// draw_text. The text is shaped when it is recorded, with the font that measured it (Ruling 19): `shaped` has one
/// glyph and one advance per glyph, and the app never re-shapes.
struct TextItem {
    std::string text;
    std::shared_ptr<const HostFont> font;
    /// The font's description, from create_font: one immutable object per cached font, shared by its handles and by
    /// every item in that font (Ruling E4), since the family is the computed font-family text verbatim.
    std::shared_ptr<const litehtml::font_description> description;
    ShapedText shaped;
    litehtml::web_color color;
    litehtml::position pos;
};

/// draw_list_marker. `marker.baseurl` is nullptr and `marker.font` is 0 (handles never leave the container), and
/// `marker.image` is empty with no buffer: the marker is copied field by field and the URL never, since it would be
/// held once per marker and the app needs only the decoded image.
struct ListMarkerItem {
    litehtml::list_marker marker;
    std::shared_ptr<const HostFont> font;      // the font behind marker's handle; null when it had none
    std::optional<DecodedImage> image;         // an image marker whose data: URL the container decoded
};

/// draw_image of a URL the container accepted and the host decoded.
struct ImageItem {
    litehtml::background_layer layer;
    DecodedImage image;
};

/// draw_solid_fill.
struct FillItem {
    litehtml::background_layer layer;
    litehtml::web_color color;
};

struct LinearGradientItem {
    litehtml::background_layer layer;
    litehtml::background_layer::linear_gradient gradient;
};

struct RadialGradientItem {
    litehtml::background_layer layer;
    litehtml::background_layer::radial_gradient gradient;
};

struct ConicGradientItem {
    litehtml::background_layer layer;
    litehtml::background_layer::conic_gradient gradient;
};

struct BordersItem {
    litehtml::borders borders;
    litehtml::position drawPos;
    bool root = false;
};

struct BoxShadowItem {
    litehtml::position box;
    litehtml::border_radiuses radius;
    litehtml::shadow_paint shadow;
};

/// draw_path: an SVG shape or a form control's glyph.
struct PathItem {
    litehtml::vector_path path;
};

/// draw_backdrop: the filter_paint by value, its steps copied and its owner dropped. The backdrop is filtered inside
/// `box`, rounded by `radius`.
struct BackdropItem {
    litehtml::filter_vector steps;
    litehtml::position bounds;
    litehtml::position box;
    litehtml::border_radiuses radius;
};

/// set_clip: clips what follows in its layer, up to the matching del_clip.
struct ClipItem {
    litehtml::position pos;
    litehtml::border_radiuses radius;
};

/// set_clip_path: as set_clip, to a path; litehtml closes it with del_clip.
struct ClipPathItem {
    litehtml::vector_path path;
};

struct PaintItem {
    enum class Kind : uint8_t { Text, ListMarker, Image, SolidFill, LinearGradient, RadialGradient, ConicGradient,
                                Borders, BoxShadow, Path, Backdrop, SetClip, DelClip, SuspendClips, ResumeClips,
                                SetClipPath };
    Kind kind = Kind::DelClip;
    /// What it paints, in its layer's coordinates. Where LHContainer, whose drawing code M1d's renderer is, pads its
    /// own dirty rects, these are its allowances exactly (Ruling E5; the sites are cited in WidgetContainer.cpp):
    /// - text: `pos` grown on every side by max(4, height / 2) plus the widest text shadow's 2·blur + max(|x|, |y|)
    ///   (shadows clamped and capped at 8 as LHContainer keeps them); empty text, nothing;
    /// - list marker: `marker.pos`;
    /// - image, solid fill, gradients: `layer.clip_box`;
    /// - borders: `drawPos`;
    /// - box shadow: `box` grown on every side by blur + |spread| + max(|x|, |y|) + 2; an inset one, `box`; a
    ///   transparent one, nothing;
    /// - path: the path's bounds (on its curves, not its control points) grown by
    ///   stroke_width × max(miter_limit, 1) / 2 + 1 when stroked, by 1 (antialiasing) when only filled; nothing when
    ///   neither or when it has no point;
    /// - clip path: the path's bounds;
    /// - set clip: `pos`;
    /// - backdrop: its enclosing layer's bounds (a Group's `group.bounds`, a Root's or Isolated's `box`; litehtml
    ///   never opens a backdrop directly in a Filter, which would take the backdrop's own `bounds`);
    /// - del clip, suspend clips, resume clips: empty.
    litehtml::position bounds;
    /// The call's arguments by value, the alternative `kind` names; std::monostate for the bare clip ops.
    std::variant<TextItem, ListMarkerItem, ImageItem, FillItem, LinearGradientItem, RadialGradientItem,
                 ConicGradientItem, BordersItem, BoxShadowItem, PathItem, BackdropItem, ClipItem, ClipPathItem,
                 std::monostate> payload;
};

struct Layer {
    enum class Kind : uint8_t { Root, Group, Filter, Isolated };
    Kind kind = Kind::Root;
    /// Group: begin_group's paint_group. Its bounds are the layer's.
    litehtml::paint_group group;
    /// Filter: draw_filtered's steps, copied.
    litehtml::filter_vector filter;
    /// The layer's bounds unless it is a Group: Isolated, draw_isolated's box; Filter, the union of its entries'
    /// bounds, set when its paint returns; Root, the document's (0, 0, width, height).
    litehtml::position box;
    /// In paint order. A child Layer is heap-allocated, so its address is stable while its parent grows.
    std::vector<std::variant<PaintItem, std::unique_ptr<Layer>>> entries;   // LayerEntry, below

    Layer() = default;
    /// Takes the subtree apart with an explicit stack instead of recursing once per level.
    ~Layer();
    Layer(Layer&&) noexcept = default;
    Layer& operator=(Layer&&) noexcept = default;
    Layer(const Layer&) = delete;
    Layer& operator=(const Layer&) = delete;
};

using LayerEntry = std::variant<PaintItem, std::unique_ptr<Layer>>;

/// A layer's bounds in its own coordinates: `group.bounds` for a Group, `box` otherwise.
const litehtml::position& layerBounds(const Layer& layer);

/// An entry's bounds in the coordinates of the layer holding it: an item's bounds; a child Group's bounds mapped
/// through its matrix; another child layer's box.
litehtml::position entryBounds(const LayerEntry& entry);

/// The bounding box of `rect`'s four corners mapped through `matrix`; `rect` itself for the identity.
litehtml::position mapRect(const litehtml::transform_matrix& matrix, const litehtml::position& rect);

/// Whether a rect covers no area (a zero, negative or NaN width or height): it paints nothing.
bool hasNoArea(const litehtml::position& rect);

/// The smallest rect holding both; a rect with no area adds nothing.
litehtml::position unite(const litehtml::position& a, const litehtml::position& b);

/// Whether two items paint the same: kind, bounds and every payload field compared exactly (floats by value, never by
/// litehtml's pixel epsilon); fonts, images and a text item's shared font description by identity. dump() prints the
/// same fields, except that it prints the description by value, shows no identity, and summarizes the glyphs (see
/// LayerTree::dump).
bool samePaint(const PaintItem& a, const PaintItem& b);

/// Whether two layers' own properties are equal: kind, then a Group's paint_group, a Filter's steps or an Isolated
/// layer's box. A Filter's box is derived from its entries and is not compared; the entries are.
bool sameLayerProperties(const Layer& a, const Layer& b);

/// The bounds the recorder gives `item` (PaintItem::bounds's rules, from its payload; a backdrop's from `enclosing`, the
/// layer it is drawn in). WidgetContainer.cpp holds the rules; a mirror's flattening recomputes moved items' bounds by them.
litehtml::position paintBounds(const PaintItem& item, const Layer& enclosing);

// ---- The mirror (Task 10b). ----

/// A DOM node's key in its RenderTree (the element → node map's); for a ::before, an ::after or a form control's part,
/// one derived from its element's and its tag (RenderTree::keyOf); 0 for what no node owns (an anonymous box, a text
/// piece of generated content).
using NodeKey = uint64_t;
/// A mirror node's identity: assigned when it is made, kept for its life, never reused within a RenderTree.
using LayerId = uint64_t;

/// One clipping ancestor of a node inside its context: the clip draw_children opens for it, relative to the context's
/// origin.
struct MirrorClip {
    /// The clipping item's id, which the nodes it clips share: consecutive nodes of one pass under one clip share its
    /// set-clip when flattened.
    LayerId clipper = 0;
    NodeKey key = 0;
    litehtml::position box;
    litehtml::border_radiuses radius;
};

/// Where a node sits in its context, in the context's paint order: the context item's own paint first, then
/// positioned with a negative z-index (by z), block, floats, inlines, positioned at z 0, positioned with a positive one.
enum class MirrorPass : uint8_t { Own, Negative, Block, Floats, Inlines, Zero, Positive };

/// A paint group's parameters as litehtml's draw_group computes them, in document coordinates: the group, a clip path,
/// a backdrop (its paint bounds are the group's) and a filter.
struct MirrorGroup {
    litehtml::paint_group group;
    std::optional<litehtml::vector_path> clipPath;
    std::optional<BackdropItem> backdrop;
    bool filtered = false;
    litehtml::filter_vector filter;
};

/// A published mirror node. Immutable once published, shared between consecutive trees while unchanged; holds no
/// pointer into a document, an element, a container or a host handle (Review Focus 5).
struct MirrorNode {
    enum class Kind : uint8_t { Context, Box, Inline };
    enum class ContextKind : uint8_t { Root, Stacking, Pseudo, Group };
    Kind kind = Kind::Box;
    LayerId id = 0;
    NodeKey key = 0;
    /// A Box's or an Inline's position relative to its context's origin; a Context's origin relative to its parent's.
    litehtml::pointF origin;
    MirrorPass pass = MirrorPass::Block;
    int zindex = 0;
    /// The clipping ancestors inside its own context (for a Context: in its parent context), outermost first.
    std::vector<MirrorClip> clips;
    /// Box and Inline: what they paint, relative to `origin` (a layer whose entries are record()'s, translated).
    std::shared_ptr<const Layer> content;
    /// Context: its kind; whether it escapes its clips (a fixed item outside every group: suspend-clips before it,
    /// resume-clips after); its group parameters (null: none); its children, its passes concatenated.
    ContextKind context = ContextKind::Root;
    bool escapes = false;
    std::shared_ptr<const MirrorGroup> group;
    std::vector<std::shared_ptr<const MirrorNode>> children;
};

/// Appends `from`'s entries to `into`, every position in `into`'s coordinates moved by (dx, dy): items with their bounds
/// recomputed by the recorder's rules (paintBounds), an Isolated or a Filter layer's contents with it, a Group's matrix
/// (its contents are in its own space). A mirror captures an item's paint where litehtml paints it and moves it to its
/// node's origin; flattening moves it back.
void appendMoved(const Layer& from, Layer& into, float dx, float dy);
/// Whether two contents paint the same: the same entries, items by samePaint, layers by sameLayerProperties and theirs.
bool sameContent(const Layer& a, const Layer& b);
/// Whether two groups' parameters are equal (null: no group).
bool sameMirrorGroup(const MirrorGroup* a, const MirrorGroup* b);

/// LayerTree::canvasColor for `document` as laid out now: the background litehtml paints on the root (its own, or the
/// body's it propagates), currentColor resolved against the element that sets it.
litehtml::web_color canvasColor(litehtml::document& document);

/// Stable text for tests: one line per node, depth-indented, then a Box's or an Inline's content as LayerTree::dump
/// prints entries; its kind, key, origin, pass, clips, a Context's kind, escape and group. No id is printed, so a mirror
/// and one built afresh dump the same.
std::string dumpMirror(const MirrorNode& node);
/// `layer`'s entries as LayerTree::dump prints them, each line indented by `depth` levels.
std::string dumpEntries(const Layer& layer, size_t depth);

class LayerTree {
public:
    /// `root` must be a Root layer; WidgetContainer::record is its producer. `canvas` is canvasColor's.
    LayerTree(double width, double height, Layer root, litehtml::web_color canvas = litehtml::web_color::transparent);
    /// A mirror (LayerMirror); `root` must be a Root Context.
    LayerTree(double width, double height, std::shared_ptr<const MirrorNode> root,
              litehtml::web_color canvas = litehtml::web_color::transparent);
    LayerTree(const LayerTree&) = delete;
    LayerTree& operator=(const LayerTree&) = delete;

    /// The recorded root; a mirror's flattening, made once, on first use (safe on any thread).
    const Layer& root() const;
    /// The mirror, or nullptr for a recorded tree.
    const MirrorNode* mirror() const { return m_mirror.get(); }
    double width() const { return m_width; }
    double height() const { return m_height; }
    /// The canvas's colour (CSS 2.1 §14.2): the root's background colour, or the body's when the root has none, never
    /// currentColor; transparent when neither sets one. The tree paints it over the root's box only, so a host whose
    /// view is taller than the document (the bubble's minimum, a fixed height) paints it under the tree.
    const litehtml::web_color& canvasColor() const { return m_canvas; }
    /// Every PaintItem in root(), at any depth (layers are not items).
    size_t itemCount() const;

    /// Stable text, one line per entry, for tests and failure messages; two trees whose dumps are equal paint the same
    /// up to font and image identity. The format:
    /// - The first line is `root <width>x<height> items=<itemCount>`.
    /// - Then each entry in paint order on its own line, indented two spaces per layer depth (the root's entries by
    ///   two), its contents on the lines after it, one level deeper.
    /// - An item's line is its kind (`text`, `list-marker`, `image`, `solid-fill`, `linear-gradient`,
    ///   `radial-gradient`, `conic-gradient`, `borders`, `box-shadow`, `path`, `backdrop`, `set-clip`, `del-clip`,
    ///   `suspend-clips`, `resume-clips`, `set-clip-path`), then ` bounds=(x,y,w,h)`, then its payload as
    ///   ` name=value` fields.
    /// - A layer's line is its kind (`group`, `filter`, `isolated`), then its properties as ` name=value` fields:
    ///   a group's `opacity`, `matrix=(a,b,c,d,tx,ty)`, `backface`, `bounds`, `exact`; a filter's `steps` and `box`;
    ///   an isolated layer's `box`.
    /// - Values: numbers by %g; flags 0 or 1; enums by their numeric value, except filter kinds by name (`blur`, …);
    ///   colours `#rrggbbaa`, with `!current` for currentColor; lengths as the number and its unit (`2px`, `50%`), or
    ///   `predef<N>`; strings in double quotes with `\`, `"` and control bytes escaped; structures and lists in
    ///   parentheses, comma-separated, with `-` for an absent optional.
    /// - Fonts and images are not printed by identity, which is not stable: a text item prints its font description,
    ///   a list marker `font=0|1`, and an image its decoded size. Shaped text prints `glyphs=<count>` and
    ///   `advance=<sum>`, not every glyph.
    /// No pointer value is ever printed.
    std::string dump() const;

private:
    void flatten() const;

    double m_width;
    double m_height;
    litehtml::web_color m_canvas;
    std::shared_ptr<const MirrorNode> m_mirror;
    mutable std::once_flag m_flattened;
    mutable size_t m_itemCount = 0;
    mutable Layer m_root;
};

} // namespace wr
