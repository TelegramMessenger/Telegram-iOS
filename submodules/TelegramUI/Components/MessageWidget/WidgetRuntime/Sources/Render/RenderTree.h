// The render tree (M1c plan, Tasks 5–10b): the runtime's main document rendered by litehtml, laid out and mirrored
// into the layer tree the app paints (Ruling 3; Task 10b's LayerMirror).
//
// Task 5 is the full build: rebuild() makes a new litehtml document from the DOM (Builder.h: no HTML string, no
// validator), lays it out and mirrors it (one walk of its paint order, Task 10b), and publishes all of it at once.
//
// Task 6 is the journal and the flush (Ruling 13). The tree is a MutationListener on the main document; its callbacks
// only record, into the Journal (Journal.h), which nodes of the rendered tree changed and how. A change is recorded
// when it touches the rendered tree, decided by one hash lookup in the published build's map per node asked about:
// - an insertion when the new parent is mapped or is the main document (which is not mapped);
// - a removal when the node or its old parent is;
// - a children change when the parent is;
// - an attribute or Text data change when the node or its parent is: a `<style>`'s Text children are not mapped, and
//   neither is a node the byte budget cut, whose change may bring it back. An attribute change on an element with no
//   parent is dropped first (Ruling 13): that is all of the parse's and cloning's. A Comment's data never renders.
// That keeps out everything script builds before it attaches it (a detached subtree, a fragment, a clone; a template's
// contents live in another document and are never heard), and a subtree inserted into the rendered tree is one entry
// for its root, which the flush reads whole. A failure in a callback (the budget, the memory limit) latches the stop
// and throws Aborted, as ScriptElements does.
// The flush runs at the end of every task and animation frame and in boot after the parse (Sources/Host), and when the
// host asks (HostState::flushRender). Any dirty state is a full rebuild, except as the in-place paths below say.
//
// Task 7, the text fast path (Ruling 8). A flush whose journal holds only Text entries (JournalKinds == Text, or with
// Task 8's Attribute: an Inserted, Removed or Children entry beside them, which a node removed after it was mapped
// produces, makes it not text-only) patches the published litehtml document instead of building a new one, when every
// entry is a mapped Text node with pieces, whose new text is not empty, under a parent the fork lets be patched
// (document::can_replace_text: not a form control, an svg or a raw-text element), and the published build hit no
// render limit (a limit decides what
// a fresh build leaves out, and a smaller text could let more in), the text keeps the document within the byte budget
// (Ruling 7) and within the text-piece cap. Anything else rebuilds, which is the oracle.
// It plans before it touches litehtml (Review Focus 2): every charge (the entries, their conversions, the layout
// pre-charge) and every allocation the patch needs (the new render input, the spare nodes of the element map, the
// reserved vectors) come first, and the only thing left after the first litehtml call is work that cannot fail, so a
// stop leaves the last published document, input and tree exactly as they were. Then it makes the replacements
// (document::replace_text), commits them (commit_patch), lays out and publishes the mirror's operations (Task 10b); the
// fonts the container holds are not reset (no beginBuild/endBuild: a patch asks only for the fonts of its new text).
//
// Task 8, attributes and inline style (Ruling 8; twidget edit 17). The same flush (flushPatch) also takes Attribute
// entries: the journal's kinds may be Text and Attribute and nothing else. The journal keeps the kind of change, not the
// attribute's name, so the plan finds what changed itself: it reads the element's attributes as the build does
// (renderElementAttributes, the one reading the build uses: qualified names, the first of a repeated name, the 16 KiB
// `style` cap, the byte budget, all charged) and compares them, by lowercased name, with what the litehtml element
// holds (everything but list_index, which layout writes on list items). The changed element is one document::
// set_element_attributes, asked first with can_set_element_attributes, so a refusal anywhere rebuilds before litehtml is
// touched. These rebuild: a `style` over 16 KiB (the build would leave it out and post `style-attribute`), a change
// that would pass the byte budget, a mapped element the fork does not patch, a selector the change could reach, and
// any flush after a build that hit a render limit. An element Ruling 4 leaves out (a <script>, a <template>, ...) is
// in no build, so a change to its attributes renders nothing and is ignored; any other unmapped element (cut by a limit,
// or a <style>'s child) rebuilds. An element's entry keeps the budget its attributes use and the place of its start tag
// in the render input, which the patch replaces as it does a text's. A tag, a form control's count and the element count
// cannot change with an attribute, so those limits are not asked again. A re-match can move the text-piece cap through
// pseudo-element content (a fresh build makes all of it in document order with the old and new of each alive together,
// so near the cap a patch and a rebuild cut at different words): while any ::before or ::after rule that declares
// `content` could match an element of the document (document::pseudo_content_possible, read from the selectors as
// litehtml parsed them), neither the attribute nor the text path patches, and the flush rebuilds. The table-cell cap
// needs no refusal for agreement (restyle_after_patch recounts the cells from the root, as a build does); the fork's
// predicate refuses a rise past it all the same, as defence in depth. Each
// changed element is applied in one call with all its attributes (document::set_element_attributes), one re-match, and
// charged for them all. litehtml's `commit_patch` ends the session
// (text and attributes together), and the plan is exact: a refusal after the first mutation is a bug and aborts.
//
// Task 9, structure (Ruling 8; twidget edit 18). A journal with a structural entry (Inserted, Removed, Children) goes to
// flushStructure, any other to flushPatch: that is the selection rule across the three paths. The structure path takes
// Text and Attribute entries only on nodes it builds or removes (they are read with their subtree) and on nodes no build
// reads (outside the main document, or under an element Ruling 4 leaves out); a kept node's own change beside structure
// (a mixed journal) rebuilds, and so does one on any other node with no entry (Ruling E25: an element a parent's
// appendChild refuses has none, yet a build scans and byte-counts its attributes). The dirty parents are the mapped
// elements with a Children entry (the document's own, the document element, and a `<style>`'s, its sheet, rebuild), and
// they are reconciled in two passes, every removal planned and counted before anything is built:
// - **What goes:** every mapped node with a Removed entry (moved out, moved within its parent, or gone: each of these
//   records one), its element or its Text's pieces removed (document::remove_subtree) unless inside another removal,
//   and every entry under it released, found both in its litehtml subtree and in its DOM subtree (a Text that made no
//   pieces, whitespace under a `<table>`, is mapped and in the render input with no place in litehtml).
// - **What comes:** each DOM child of a dirty parent with no entry left is built (buildRenderSubtree: the build's own
//   walk, so build and patch agree by construction) within what the rest of the document uses of the limits, and
//   inserted (document::insert_subtree) before the next kept sibling that has an element or pieces, or at the end before
//   an ::after. A move from A to B keeps its old element under A until A goes, which is why removals come first.
// - With sibling combinators or positional pseudo-classes in the sheets (document::structure_reaches_siblings), every
//   child of a dirty parent is built again instead (document::replace_children), and a dirty parent inside another's
//   children is built with them.
// Inserted nodes whose parent has no element are not journaled (detached, in a template, under an element Ruling 4 leaves
// out). These rebuild: any refusal of the fork's predicates (can_remove_subtree, can_insert_subtree, can_replace_children:
// a document-level element, a parent in a select, form control or svg, a table's appendChild refusal, counters,
// pseudo-element content the tree with the subtree could have, litehtml's depth, element, text-piece and cell caps), a
// subtree a fresh build would cut (Ruling 7's byte budget and `style` cap, E6's form controls, E9's elements, the depth)
// or that holds a `<style>`, a mixed journal, and any flush after a build that hit a limit. The plan builds the new
// subtrees detached with the published document, asks every predicate in the order the patch makes the changes (threading
// what each adds to the caps), pre-charges and allocates, and composes the render input; the patch makes the changes,
// moves what went to graveyards freed after the publish, moves the kept entries' places with the input's patches and the
// new ones in, and commits. An element's entry keeps where its serialization ends (inputEnd, endTagLength), and an empty
// Text has no place, so no two entries start at one offset. An insertion has two anchors: its place in litehtml (the next
// kept sibling with an element or pieces) and its place in the render input (the next kept sibling with a place there),
// which differ at a Text that made no pieces.
// What litehtml counts that the maps do not (I2): a build counts every element it creates against its 20,000, the ones a
// parent's own appendChild then refuses (a <div> or <tr> straight under a <table>) included, and asks the piece cap for
// every piece, a <table>'s refused whitespace included. The build and every patch keep those counts (refusedElements,
// refusedPieces: upper bounds, since nothing subtracts them until the next build), and a structure patch that could take
// the linked and refused elements past 20,000, or the pieces to the cap beside a refused piece (the text path asks the
// same), rebuilds.
//
// Matching (Ruling E19). litehtml counts a step for each selector it tests against an element and gives up at
// 4,000,000; that budget is one per build or patch session (twidget edit 18), not one per outermost pass. A build runs
// with min(4,000,000, the widget's remaining work in work::kSimpleSelectorTest steps), charges the steps performed, and,
// cut by the widget's budget rather than litehtml's, stops the widget (Budget) and is dropped; the published build
// records the steps it used (selectorSteps, U). A patch that matches (an attribute re-match, an inserted or replaced
// subtree; a text matches nothing) bounds its steps first (document::selector_step_bound, B) and rebuilds when U + B
// would reach 4,000,000 (so a patch and a rebuild never cut at different places) or B is more than the widget's budget
// allows; otherwise it runs its session limited to that allowance, which it cannot reach, charges the steps used (only
// when there are any: the plan's own charges may have passed the budget unnoticed, QuickJS polling it every 100 units,
// and a charge would then stop the widget with the document patched), and adds them to U. U only grows between builds,
// so patches refuse sooner than they must, never later.
// Correctness does not rest on B (Ruling E20): exact bounds of litehtml's matching kept failing (a compound left of a
// combinator walks an ancestor's siblings, which B now counts). A patch's session is limited to what U leaves of
// 4,000,000 (and to the work budget's steps); a session that is cut there is abandoned, and so is any can't-happen after
// the document was changed (a fork refusal the predicates did not foresee, an anchor not found): the patched document is
// dropped and the same flush rebuilds, so a cut patch is always replaced by a fresh build. No patch ends in std::abort.
// That rebuild should not be stoppable by the budget, so a patch is attempted only when the remaining work covers it
// (fallbackRoom): rebuildEstimate of the document as the patch leaves it, with all of litehtml's 4,000,000 steps. The
// patch's own session gets only what that reserve leaves (its step limit is capped there), and an abandoned patch is
// charged the steps it performed before the flush rebuilds, out of the reserve.
// The estimate (Ruling E22) is an ESTIMATE of what rebuilding the CURRENT DOM is charged, not a proven bound: it is kept
// from the build's measured work and adjusted by each patch, part by part, and review found shapes it under-counted
// (fix round 4). If a fallback rebuild is ever stopped by the budget, the widget stops (Budget) with the old published
// tree, while document() holds the abandoned patch: a recorded gap (the dry-run bound of Ruling E24 was set aside, the
// user, 2026-10-18). Its parts:
// - the walk (RenderBuild::walkCharge): the build's measured work less its other parts and less the final bucket arrays of
//   its maps (part of the maps' growth, below); each committed patch adds the work it measured making what it adds,
//   which covers what a rebuild charges for the same nodes (the same functions, AtomNames' first use costing at least
//   a later one), and takes off what a rebuild certainly charged for what it replaces or releases (a lower bound per
//   entry: the node, its attributes' kRenderAttribute and a style's kCssByte, a text's scan at one byte in three, its
//   pieces, its map nodes), so it leaves out no addition, and repeated patches of one node grow it only by what each
//   measured past that lower bound (five patches of a kind keep the estimate within twice a rebuild's charge);
// - the maps' and the render input's growth from empty, which a rebuild repeats: at most 8 units per entry for each
//   map's bucket arrays (libc++ about doubles them) and one unit per byte for the input's reallocations (measured:
//   7.999 and 1.000 at worst), held to 10 and 1.25, from the counts as they are. A structure patch's staging maps start
//   with room for what it releases, and what they grow past it, less their final bucket arrays, stays in its measure;
// - the layout pre-charge, from boxes and textBytes as they are; the filter loop, renderFilterUnits(matched, every rule),
//   which covers both of finalize's passes (RenderBuild::matched); the steps (4,000,000 in the reserve; buildCharge
//   shows the published U). Out of memory is not covered either: a stop by the memory limit inside that rebuild leaves
// document() the patched one beside the old published tree (M1d makes out-of-memory fatal at the facade).
// Matching's filter loop (Ruling E21): apply_selector tests every rule against every element, and no step counts that, so
// it is charged at work::kScanEightUnits per eight (element, rule) pairs: by a patch's plan for the elements it matches,
// and by a build through finalize's matching gate (twidget edit 18), which asks before each pass whether the budget holds
// it; declined, the build stops (Budget) before that pass matches anything. The elements (Ruling E22) are litehtml's
// matching_weight of each: itself, the two pseudo-elements a ::before/::after rule can create for its tag, a form
// control's three parts with theirs. The gate also lowers the build's step limit to what the loop leaves of the budget.
//
// Task 10b, the layer mirror (twidget edit 20; LayerMirror.h). The published tree mirrors litehtml's painting (Context,
// Box and Inline nodes with stable LayerIds, keyed by their DOM node's NodeKey from the element → node map, which ends
// Ruling 20's deferral), and every flush re-lays out and applies the fork's reported changes to the mirror as operations;
// nothing is compared (Ruling 8, from this task on). A build walks the new document once (walk_paint_order) into a new
// mirror and publishes Reset; a patch the fork's render tree survives (a text patch whose renderers were replaced in
// place, a neutral class change) publishes the mirror's operations; a patch after which the fork rebuilt its render tree
// (every structural patch, any other attribute patch), or whose reports the mirror cannot place, builds a new mirror of
// the patched document and publishes Reset (treeRebuildResets, unplaceableResets). layerOps() is what the last publish
// carried; a Reset's changedRects come from LayerDiff's mirror diff of the two trees, an operation's from the nodes it
// names.
//
// Atomic (Review Focus 2): a build, its charges, its layout and its mirror happen on a new document with new maps.
// Only when all of it has succeeded are they swapped in, the tree published and changedRects set from the previous
// tree; any exception leaves the old document, maps, render input and tree in place.
//
// Charging (Ruling 9): the build charges as it walks (Builder.h). Layout, painting and shaping are pre-charged before
// render(): work::kLayoutBox per element and piece built, plus chargeScan of the text's UTF-8 bytes. Matching is charged
// per selector step after it (Ruling E19, above), from inside a session whose limit is what the budget allows. Nothing
// charges inside a litehtml call, so no exception unwinds through litehtml.
//
// The maps (Ruling 14), the journal and the render input (kept only for tests: RenderOptions::keepRenderInput, Ruling
// E11) go through QuickJS's allocator. Each mapped or journaled node is held by an untraced, counted root (a Ref<Node>),
// released when its build is replaced or its entry goes, and in the destructor, so a RenderTree must be destroyed while
// its context and the main document are alive (HostState declares it last, and Runtime::~Runtime resets the host's
// extension before the DOM's).
//
// The memory bound. litehtml, the container and the layer tree use the system heap, outside the widget's memory limit;
// the render limits (Rulings 7, E6 and E9) bound them. RenderBuildTests' testHostileSizesAreBoundedAndCharged holds the
// heap growth of each hostile single build under 160 MB and prints them.
// - Headline, the styled-element case: 10,000 styled elements (Ruling E9) at ~10.4 KB each, litehtml and their tree
//   items (20,000 divs with a border, a background, a shadow, a radius and a clip measured 153 MB of litehtml and 55 MB
//   of tree), ≈ 104 MB published and ≈ 210 MB at a rebuild's peak, when the old and new documents and trees are alive
//   together (atomicity).
// - Unstyled, 10,000 elements at ~3.4 KB (20,000 divs measured 67 MB, painting nothing): ≈ 34 MB published, ≈ 68 MB
//   at a rebuild's peak.
// The sum for one published build at every limit:
// - 10,000 styled elements ≈ 104 MB;
// - 10,000 pieces × ~3.6 KB ≈ 36 MB (10,000 one-word Text nodes measured 36 MB, their 10,000 text items included);
// - 256 form controls (Ruling E6) × ~22 KB, their generated parts escaping litehtml's caps ≈ 6 MB (20,000 `<input>`s
//   measured 436 MB before the limit; 256 measure 5 MB);
// - 1 MiB of strings copied into litehtml ≈ 1 MB, and at most as much again of refused URLs the container keeps
//   cached until a build no longer asks for them (a URL is an attribute value or CSS text: the byte budget and the CSS
//   caps bound it) ≈ 1 MB;
// - the glyph runs: 8 B per glyph, ≈ 8 MB for 1 MiB of text (Task 4; ~300 B per item is in the terms above);
// - (64 KiB + 16 KiB) × ~545 B of transient CSS parse (litehtml.md §7) ≈ 45 MB, during finalize only.
// That is ≈ 156 MB published, ≈ 200 MB at a first build's peak and ≈ 360 MB at a rebuild's. Today's renderer has the
// same order of exposure: it also keeps the previous document alive while it builds the next.
// Not closed by the render limits:
// - a computed list value (box-shadow, background layers) is copied into every element it applies to and painted once
//   per entry: a 100-shadow box-shadow on 1,000 divs measured 107 MB of litehtml and 27 MB of tree (100,000 items). The
//   next task closes it at parse (twidget edit 15 caps list-valued CSS; Ruling E7);
// - litehtml's process-global caches (master and author sheets, declarations) and interned names (Ruling 12).
#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <unordered_set>
#include <vector>

#include <litehtml/types.h>

#include "Sources/DOM/Document.h"
#include "Sources/Render/Builder.h"
#include "Sources/Render/Journal.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderHost.h"
#include "Sources/Render/HitTest.h"
#include "Sources/Render/ComputedStyle.h"
#include "Sources/Render/LayerMirror.h"
#include "Sources/Render/WidgetContainer.h"

namespace litehtml {
class document;
}

namespace wr {

namespace animation {
struct StyleChange;
}

/// The published layout's size in CSS px (RenderTree::contentSize).
struct ContentSize {
    double width = 0;
    double height = 0;
};

class RenderTree final : public MutationListener {
public:
    /// Builds nothing: layerTree() is nullptr until the first build, which the first flush makes. Registers with the
    /// main document's mutation listeners (DOMState), and the destructor unregisters.
    RenderTree(JSContext* ctx, RenderHost& host, RenderOptions options);
    ~RenderTree() override;
    RenderTree(const RenderTree&) = delete;
    RenderTree& operator=(const RenderTree&) = delete;

    /// The whole document from the DOM, laid out at the options' width and mirrored (Reset); then published, with
    /// changedRects from the previous tree, and the render-limit kinds the build hit posted to the host (Ruling 7:
    /// each once per build, as `render-limit` diagnostics, after the publish). The container's build window closes
    /// after the mirror's walk (Ruling E10). Atomic. Throws Aborted when the build
    /// stops the widget (the budget, the memory limit, a C++ failure; abortForCaughtException latched it), and at once,
    /// building nothing, when the runtime has already stopped. A clean journal on success. A rebuild entered from
    /// inside a build (a host that calls back, against RenderHost's contract) returns at once.
    void rebuild(JSContext* ctx);

    /// Applies the journal, lays out, updates the mirror and publishes: in Task 6, whenever anything is dirty (the journal has an
    /// entry, it collapsed, a width or theme changed, nothing was built yet), a full rebuild (Ruling 8). Atomic, as
    /// rebuild is. Nothing when clean, once the runtime has stopped (the last published tree stays: spec §5, "Flush"),
    /// or when re-entered (a host calling back from inside the build). Throws Aborted when its build stops the widget.
    void flush(JSContext* ctx);
    /// The flush a layout query makes from inside its binding (M2), so the query reads the current layout. The same
    /// flush, except that a stopped runtime throws Aborted, as every native path a binding reaches does; a stop in its
    /// build throws Aborted too, which unwinds the binding to the step boundary.
    void flushForQuery(JSContext* ctx);
    /// The layout width (RenderOptions::width) and the color scheme (RenderOptions::theme, Ruling 6), stored on the
    /// container; a change marks a rebuild, which the next flush makes (Rulings 6 and 16: viewport units and the
    /// scheme are folded at parse). The same value again changes nothing. Once the runtime has stopped, nothing is
    /// stored or built.
    void setWidth(JSContext* ctx, double width);
    /// The scheme, with the root's theme declarations (RenderOptions::rootDeclarations): either changed marks a rebuild.
    void setTheme(JSContext* ctx, Theme theme, std::string rootDeclarations);
    /// The options a build uses now: the construction's, with the width and theme set since.
    const RenderOptions& options() const { return m_container.options(); }

    /// A canvas's bitmap changed (V5d plan, Task 4): when the canvas is rendered, the next flush republishes it, today
    /// as a full rebuild (its box is the only rect that changes). An unrendered canvas changes nothing.
    void canvasPainted(const Element& canvas);
    /// An <img>'s source decoded, kept nowhere (WidgetContainer::decodeImageUncached).
    std::optional<DecodedImage> decodeImageUncached(std::string_view src) { return m_container.decodeImageUncached(src); }
    /// The image layout already decoded for `src` (WidgetContainer::decodedByLayout).
    std::optional<DecodedImage> decodedByLayout(std::string_view src) const { return m_container.decodedByLayout(src); }
    /// The host the tree lays out and paints with (canvas bitmaps and fonts come from it too, V5d).
    RenderHost& host() const { return m_container.host(); }
    /// The published tree; nullptr before the first build.
    std::shared_ptr<const LayerTree> layerTree() const { return m_tree; }
    /// What the host sizes the widget by (M1d plan, Task 1): the content's own width as the last layout returned it
    /// (litehtml::document::render, today's renderer's "natural" width; the fork declares content_width() but never
    /// defines it), and the document's height. nullopt before the first build.
    std::optional<ContentSize> contentSize() const;
    /// The focus, hover or active state changed (UserActions, M1d plan Task 3): the next flush rebuilds when the
    /// published build's CSS names a user-action pseudo-class, so the new state is matched and drawn.
    void userActionStateChanged();
    /// What the last publish changed against the one before it: nullopt for everything (the first publish, a size
    /// change; LayerDiff.h).
    const std::optional<std::vector<litehtml::position>>& changedRects() const { return m_changedRects; }
    /// What every publish since the last take changed, together (V3 plan, Task 3): a step whose script queries the
    /// layout publishes mid-step and again at its end, and the host draws the union. nullopt for everything (one of
    /// them changed everything, or the union could not grow). Leaves an empty union behind.
    std::optional<std::vector<litehtml::position>> takeChangedRects();
    /// The published litehtml document; nullptr before the first build.
    litehtml::document* document() const { return m_current.document.get(); }
    /// Every load the container refused so far (WidgetContainer::refusedLoads).
    uint64_t refusedLoads() const { return m_container.refusedLoads(); }
    /// Hit-testing and boxes (Task 10), in the document's coordinates (layoutDump's), reading the published layout and
    /// never flushing. A node with no element (a Text node, one not rendered), or no document, has no box.
    /// The border box: a block's placement grown by its padding and border, an inline element's the union of its inline
    /// boxes, a table row's the union of its cells.
    std::optional<RenderBox> borderBox(const Node& node) const;
    /// One rect per inline box, or the border box for a block; empty when there is none.
    std::vector<RenderBox> clientRects(const Node& node) const;
    /// Layout boxes of `node` (clientRects, overflowClip) where they are drawn: mapped through the transforms of its
    /// element and every ancestor (transformRects), as getClientRects and IntersectionObserver report them. Unchanged
    /// for a node with no element. borderBox, clientRects and the offset and client members stay the layout's.
    std::vector<RenderBox> visualRects(const Node& node, std::vector<RenderBox> rects) const;
    std::optional<RenderBox> visualBox(const Node& node, std::optional<RenderBox> box) const;
    /// The union of the visual client rects (getBoundingClientRect).
    std::optional<RenderBox> visualBorderBox(const Node& node) const;
    /// What CSSOM View's client and offset members read of an element's first box (V3 plan, Task 3): its border widths
    /// in CSS px, whether it is positioned (any `position` but static) or fixed, and whether it lays out inline (an
    /// inline box has no client area). nullopt for a node that is not rendered.
    struct BoxMetrics {
        double borderTop = 0, borderRight = 0, borderBottom = 0, borderLeft = 0;
        double paddingTop = 0, paddingRight = 0, paddingBottom = 0, paddingLeft = 0;
        bool positioned = false, fixed = false, inlineLevel = false;
    };
    std::optional<BoxMetrics> boxMetrics(const Node& node) const;
    /// The padding box of an element that clips its contents (overflow other than visible), which Intersection Observer
    /// clips a target by; nullopt for any other node.
    std::optional<RenderBox> overflowClip(const Node& node) const;
    /// SVG geometry (V3b plan, Task 4), in the element's user units (litehtml::svg_geometry; no transforms applied): a
    /// shape's box from its path's points and curve extrema, or the union of the shapes a container holds; `visited`
    /// gains the elements walked. nullopt when nothing is rendered there.
    std::optional<RenderBox> svgBBox(const Node& node, uint64_t& visited) const;
    std::optional<double> svgPathLength(const Node& node) const;
    /// The point at `distance` along the shape's path, clamped to its ends.
    std::optional<std::pair<double, double>> svgPointAtLength(const Node& node, double distance) const;
    /// A text element's text: its advance in its font, scaled to its font-size attribute, and its UTF-16 length.
    std::optional<double> svgTextLength(const Node& node);
    uint64_t svgTextUnits(const Node& node) const;
    /// The width the document is laid out at (RenderOptions::width) and its height: the viewport's size, as a widget
    /// has no viewport of its own. 0 before the first build.
    double layoutWidth() const;
    double documentHeight() const;
    /// CSSOM View's media query evaluation (V3b plan, Task 1): `query` through litehtml's media query parser, checked
    /// against the container's media features exactly as @media is, so the two agree; with `atLastReport`, against the
    /// features the last noteMediaReported() kept. Charged work::kCssByte per byte. False before the first build (a
    /// length needs the document).
    bool matchesMedia(JSContext* ctx, const std::string& query, bool atLastReport = false) const;
    /// Keeps the current media features as the last report's, and counts the report.
    void noteMediaReported();
    uint64_t mediaReports() const { return m_mediaReports; }
    /// The boxes the published layout laid out (RenderBuild::boxes): what a hit test over the whole tree walks.
    uint64_t boxCount() const { return m_current.boxes; }
    /// getComputedStyle's value of `name` (V3 plan, Task 4; ComputedStyle.h) for a rendered node or its pseudo-element;
    /// nullopt when the node is not rendered.
    std::optional<std::string> computedStyleValue(const Node& node, std::string_view name, PseudoElement pseudo) const;
    /// The cascaded declaration of `property` on a rendered element, as written (V5f plan, Task 2): litehtml's raw
    /// declarations, which the fork keeps for the animation and transition properties and the properties they animate
    /// (style.cpp's raw_declaration_names). Empty when nothing declares it or the node is not rendered. Animated values
    /// are never declarations (the animated layer opens with `-lh-anim`).
    std::string declaredValue(const Node& node, const std::string& property) const;
    /// The `<style>` texts the published build applied, in tree order (RenderBuild::styleSheets).
    const std::vector<std::string>& styleSheets() const { return m_current.styleSheets; }
    /// The node under the point: the nearest ancestor-or-self of what litehtml hits that maps to a node (a Text piece
    /// to its parent element; a pseudo-element to its host), honouring `pointer-events: none` and descending into an
    /// `<svg>`. The document element when nothing is hit; nullptr with no document.
    Node* nodeAt(double x, double y) const;
    /// dumpLayout(*document()), "" before the first build.
    std::string layoutDump() const;
    /// `<!doctype html>` and then the rendered tree in HTML's serialization, as Serializer.cpp writes it: the rendered
    /// elements with the attributes they were built with, in the DOM's order (a left-out `style` and a repeated name
    /// are not there); void elements without end tags (and without the children script gave them, which render);
    /// text escaped as escapedUnits escapes it, a raw-text parent's text raw; a `<style>`'s sheet as it was applied
    /// (nothing when it was not). What the published document was built from: parsing it through litehtml's own
    /// parser lays out the same (testBuildPathParity) for a no-quirks document whose `<pre>` text does not start with
    /// a newline. For tests: built only when the options keep it (RenderOptions::keepRenderInput, Ruling E11); "" when
    /// they do not, and before the first build.
    std::string renderInput() const { return std::string(m_current.input.data(), m_current.input.size()); }
    /// Full builds published so far (tests).
    uint64_t buildCount() const { return m_buildCount; }
    /// Flushes that patched the published document in place and published its tree, without a build (tests).
    uint64_t patchCount() const { return m_patchCount; }
    /// Distinct nodes the journal recorded since the last flush; 0 while a full rebuild is pending (tests).
    size_t journalNodes() const { return m_journal.nodes(); }
    /// Why the last flush that could not patch rebuilt instead (an in-place path's refusal), for tests' reports.
    const char* lastPatchRefusal() const { return m_refusal; }
    /// Ruling E19, for tests: the selector steps the published matching used (the build's and every committed patch's),
    /// and the last patch's steps and the bound its plan held them to.
    int64_t selectorSteps() const { return m_current.selectorSteps; }
    /// Ruling E20, for tests: caps the selector steps a patch's matching may take, so a test can cut one where the bound
    /// said it would fit and see the patch abandoned and the flush rebuild. INT64_MAX (the default): no cap.
    void setPatchStepCapForTesting(int64_t cap) { m_patchStepCap = cap; }
    /// Rulings E20 and E22, for tests: rebuildEstimate of the document as it now is, with the steps the published
    /// matching used (at most litehtml's 4,000,000) where the fallback's reserve holds all 4,000,000. Without its steps it
    /// estimates what rebuilding the current DOM is charged without its steps (not a proven bound: the file comment).
    uint64_t buildCharge() const;
    /// buildCharge's parts, for tests: the walk, the maps' and input's growth, the layout pre-charge, the filter loop and
    /// the steps.
    struct ChargeParts {
        uint64_t walk = 0;
        uint64_t growth = 0;
        uint64_t layout = 0;
        uint64_t filter = 0;
        uint64_t steps = 0;
    };
    ChargeParts buildChargeParts() const;
    /// The render byte budget the published build uses (Ruling 7), for tests.
    uint64_t renderBytes() const { return m_current.bytes; }
    /// Profile 1's text units the published build counts (V4 plan, Task 7), for tests.
    TextUnits renderedTextUnits() const { return m_current.textUnits; }
    /// The render-limit kinds the published build hit (a patch agrees with a rebuild on them), for tests.
    const std::vector<std::string>& renderLimits() const { return m_current.limits; }
    int64_t lastPatchSteps() const { return m_lastPatchSteps; }
    int64_t lastPatchStepBound() const { return m_lastPatchStepBound; }
    /// Task 10b: the operations the last publish carried (one Reset for a new mirror); the walks of litehtml's paint order
    /// so far (one per new mirror); and the patched flushes that published Reset because the fork rebuilt its render tree,
    /// and because the mirror could not place a reported change (tests).
    const std::vector<LayerOp>& layerOps() const { return m_layerOps; }
    uint64_t mirrorWalks() const { return m_mirrorWalks; }
    uint64_t treeRebuildResets() const { return m_treeRebuildResets; }
    uint64_t unplaceableResets() const { return m_unplaceableResets; }
    /// For tests: a mirror of the published document built afresh, through the same container and keys, which observes
    /// nothing; and WidgetContainer::record of it, the oracle. nullptr before the first build.
    std::shared_ptr<const LayerTree> freshMirrorForTesting();
    std::shared_ptr<const LayerTree> recordForTesting();

    // MutationListener: record only (the file comment has what is recorded). Runs no script, reads no attribute value
    // and calls nothing JS-visible.
    void childrenChanged(Node& parent) override;
    void nodeInserted(Node& node) override;
    void nodeRemoved(Node& node, Node& oldParent) override;
    void attributeChanged(Element& element, JSAtom localName, Namespace ns) override;
    /// An element's animated declarations changed (V5e plan, Task 6; animation::AnimationState::collectRenderChanges): an
    /// attribute change to the builder's animated_style_attribute, journaled as attributeChanged journals one.
    void animatedStyleChanged(Element& element);
    void characterDataChanged(Node& node) override;

private:
    /// Whether `node` is the main document or a node the published build maps. O(1); nullptr is not.
    bool rendered(const Node* node) const;
    /// Journal::record; a failure latches the stop and throws Aborted.
    void record(Node& node, JournalKind kind);
    /// A change of the text inside `from` (a text edit, an insertion, a removal) can change the direction a dir=auto
    /// ancestor resolves to (fidelity plan, Task 11; Builder's autoDirection): the nearest ancestor with a dir of its
    /// own, from `from` up, is recorded for its attributes to be scanned again when that dir is auto. The walk stops
    /// there, or at a bdi, script, style or textarea, which auto skips. A node visit per element, charged.
    void noteAutoDirection(Node* from);
    /// What an in-place path did: patched and published; refused, having changed nothing; or abandoned after changing the
    /// published document (Ruling E20: a can't-happen, or a matching cut), which the caller replaces by a rebuild.
    enum class PatchResult { Refused, Patched, Abandoned };
    /// The in-place fast path (Tasks 7 and 8). Throws Aborted when the widget stops while planning, with the published
    /// state untouched.
    PatchResult flushPatch(JSContext* ctx);
    /// The journal applied: patched in place, else rebuilt (the body flush ran before V5f).
    void publishJournal(JSContext* ctx);
    /// What applying the journal resolves styles for again (V5f plan, Task 2): everything when a rebuild is pending; else
    /// the elements whose DOM attributes changed and every element of each inserted subtree. Read before the journal
    /// is applied; charged a node visit per entry and per subtree node.
    animation::StyleChange pendingStyleChange(JSContext* ctx);
    /// The structure fast path (Task 9; twidget edit 18), for a journal with a structural entry. Throws Aborted as
    /// flushPatch does.
    PatchResult flushStructure(JSContext* ctx);
    /// Ruling E22: what rebuildEstimate reads of a document: the walk (RenderBuild::walkCharge), the maps' entries and
    /// the render input's length, the boxes and text bytes, the filter loop's elements (RenderBuild::matched).
    struct RebuildCounts {
        uint64_t walk = 0;
        uint64_t nodes = 0;
        uint64_t elements = 0;
        uint64_t input = 0;
        uint64_t boxes = 0;
        uint64_t textBytes = 0;
        uint64_t matched = 0;
    };
    /// The published document's.
    RebuildCounts currentCounts() const;
    /// Rulings E20 and E22: an upper bound of what rebuilding a document of these counts is charged, its steps at
    /// `stepUnits` (the file comment has each part).
    uint64_t rebuildEstimate(const RebuildCounts& counts, uint64_t stepUnits) const;
    /// Ruling E20: the work the widget's budget has left past the rebuild that would replace an abandoned patch, in full:
    /// rebuildEstimate of the document as the patch leaves it with all of litehtml's 4,000,000 steps, the most a build
    /// can take; negative when it cannot pay for it. A patch's session is limited to it.
    int64_t fallbackRoom(JSContext* ctx, const RebuildCounts& after) const;
    /// Ruling E25: whether a build of the main document reads `node`, as far as the DOM tells: it is in the main document
    /// and neither it nor an ancestor is an element Ruling 4 leaves out. Charges work::kNodeVisit per node it walks up.
    bool readByABuild(JSContext* ctx, Node& node) const;
    /// Task 10b: an element's NodeKey in the build the mirror is being built for (m_keyBuild, else the published one),
    /// given when first asked, the key a rebuild's previous entry for the node had when there is one.
    NodeKey keyOf(const litehtml::element& element);
    /// A new mirror of `document`, observing it, keyed from `build`; its walk is counted.
    std::unique_ptr<LayerMirror> newMirror();
    /// The mirror's patch publish, or a new mirror and Reset (counted) when it declines: what a patch flush publishes.
    struct MirrorPublish {
        std::shared_ptr<const LayerTree> tree;
        std::optional<std::vector<litehtml::position>> changed;
        std::vector<LayerOp> ops;
        std::unique_ptr<LayerMirror> mirror;   // a new mirror to install, or null
        bool treeRebuilt = false;
    };
    MirrorPublish publishPatch(litehtml::document& document);
    void installPatch(MirrorPublish& published);

    JSContext* m_ctx;
    /// The main document, whose listeners this is one of: held, so the destructor can unregister.
    Ref<Document> m_document;
    /// Declared before the build: a litehtml document calls its container until it is destroyed.
    WidgetContainer m_container;
    /// The media features the last media report saw, and the reports so far (Window::reportMediaChanges).
    litehtml::media_features m_reportedMedia;
    uint64_t m_mediaReports = 0;
    /// The published build: its document, its maps and its render input.
    RenderBuild m_current;
    /// Elements whose DOM attributes changed since the last flush (attributeChanged; not the animated layer's changes):
    /// what an attribute patch resolved styles for again. Compared, never dereferenced.
    std::unordered_set<const Element*> m_domAttributeChanges;
    /// What changed since the published build. Dirty (a rebuild pending) until the first build.
    Journal m_journal;
    /// The nodes inserted into the main document since the published build where the journal does not hear them (under
    /// an element no build renders): a build counts them against kMaxRenderNodes (V4 plan, Task 7), so the published
    /// count plus these stays an upper bound, and past the cap the next flush rebuilds (final review C2).
    size_t m_unheardNodes = 0;
    std::shared_ptr<const LayerTree> m_tree;
    std::optional<std::vector<litehtml::position>> m_changedRects;
    /// The union takeChangedRects hands over: every publish adds its m_changedRects (accumulateChangedRects).
    std::optional<std::vector<litehtml::position>> m_accumulatedRects{std::in_place};
    void accumulateChangedRects() noexcept;
    /// Task 10b: the mirror of the published document, declared after m_current so it goes first (it observes the
    /// document); the LayerId and NodeKey counters (never reused); the build keys come from while a rebuild builds.
    std::unique_ptr<LayerMirror> m_mirror;
    LayerId m_nextLayerId = 1;
    uint64_t m_nextKey = 1;
    RenderBuild* m_keyBuild = nullptr;
    std::vector<LayerOp> m_layerOps;
    uint64_t m_mirrorWalks = 0;
    uint64_t m_treeRebuildResets = 0;
    uint64_t m_unplaceableResets = 0;
    uint64_t m_buildCount = 0;
    uint64_t m_patchCount = 0;
    /// Set while a build runs: a flush or rebuild entered then returns at once.
    bool m_flushing = false;
    /// The style-change step is running (V5f): script it runs (a promise's `then` getter) cannot flush again, so the step
    /// is never re-entered; the outer flush's second pass publishes what that script changed.
    bool m_styleStepRunning = false;
    /// lastPatchRefusal, lastPatchSteps, lastPatchStepBound.
    const char* m_refusal = "";
    int64_t m_lastPatchSteps = 0;
    int64_t m_patchStepCap = INT64_MAX;
    int64_t m_lastPatchStepBound = 0;
    PatchResult refused(const char* why) {
        m_refusal = why;
        return PatchResult::Refused;
    }
};

/// Makes the runtime's render tree over `host` with `options`, and puts it in the HostState (HostState::render()),
/// which owns it from then on, replacing any tree before it. Call after installHost and before boot, so the boot's
/// flush builds the parsed markup. `host` must outlive the runtime.
RenderTree& installRender(JSContext* ctx, RenderHost& host, RenderOptions options);

} // namespace wr
