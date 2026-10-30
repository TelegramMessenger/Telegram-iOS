// The render tree (M1c plan, Tasks 5–10b): the runtime's main document rendered by litehtml, laid out and mirrored
// into the layer tree the app paints (Ruling 3; Task 10b's LayerMirror).
//
// Task 5 is the boot's build: build() makes the litehtml document from the DOM (Builder.h: no HTML string, no
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
// for its root, which the flush reads whole. A failure in a callback (the memory limit) latches the stop and throws
// Aborted, as ScriptElements does.
// The flush runs at the end of every task and animation frame and in boot after the parse (Sources/Host), and when the
// host asks (HostState::flushRender). The first flush builds; every later one patches, by the paths below, each handing
// what it cannot patch to the next before it touches litehtml (publishJournal), and the last one's refusal stops the
// widget as an inconsistency (stopInternally): nothing after the boot builds a new document.
//
// Task 7, the text fast path (Ruling 8). A flush whose journal holds only Text entries (JournalKinds == Text, or with
// Task 8's Attribute: an Inserted, Removed or Children entry beside them, which a node removed after it was mapped
// produces, makes it not text-only) patches the published litehtml document instead of building a new one, when every
// entry is a mapped Text node with pieces, whose new text is not empty, under a parent the fork lets be patched
// (document::can_replace_text: not a form control, an svg or a raw-text element). A text past the byte budget (Ruling 7),
// a text budget or the text-piece cap, an emptied one, and any text after a build whose walk hit a limit walk the cut
// instead ("The caps", below). Anything else goes to the structure path.
// It plans before it touches litehtml (Review Focus 2): every allocation the patch needs (the new render input, the
// spare nodes of the element map, the reserved vectors) comes first, and the only thing left after the first litehtml
// call is work that cannot fail, so a stop leaves the last published document, input and tree exactly as they were; the
// one exception is matching or a replay cut at the patch's step limit ("Matching" below), which stops the widget after
// the commit with litehtml's document patched and never laid out, the tree published before it kept. Then it makes the replacements
// (document::replace_text), commits them (commit_patch), lays out and publishes the mirror's operations (Task 10b); the
// fonts the container holds are not reset (no beginBuild/endBuild: a patch asks only for the fonts of its new text).
//
// Task 8, attributes and inline style (Ruling 8; twidget edit 17). The same flush (flushPatch) also takes Attribute
// entries: the journal's kinds may be Text and Attribute and nothing else. The journal keeps the kind of change, not the
// attribute's name, so the plan finds what changed itself: it reads the element's attributes as the build does
// (renderElementAttributes, the one reading the build uses: qualified names, the first of a repeated name, the 16 KiB
// `style` cap, the byte budget) and compares them, by lowercased name, with what the litehtml element
// holds (everything but list_index, which layout writes on list items). The changed element is one document::
// set_element_attributes, asked first with can_set_element_attributes, so a refusal anywhere hands the change to the
// structure path before litehtml is touched (profile 1 renders no element the fork has no attribute patch for: every form
// control, and so nothing inside a <select>, is dropped). A `style` over 16 KiB (the build leaves it out and posts
// `style-attribute`), a change past the byte budget or a text budget, and an element a cap cut walk the cut ("The caps",
// below). An element Ruling 4 leaves out (a <script>, a <template>, ...) is in no build, so a change to its attributes
// renders nothing and is ignored, and a change to a `<style>` or its Text goes to the structure path (twidget edit 81).
// An element's entry keeps the budget its attributes use and the place of its start tag
// in the render input, which the patch replaces as it does a text's. A tag, a form control's count and the element count
// cannot change with an attribute, so those limits are not asked again. A re-match makes its element's pseudo-element
// content again, which a build makes after the text in match order: near the text-piece, pseudo-element or style-byte cap
// the commit replays the style pass in a build's order (twidget edit 84; a replay cut at the patch's step limit stops the
// widget), and the patch's limits are the ones that pass reached (document::style_pass_limits).
// The table-cell cap is counted from the root again when a replacement moves its cut. Each
// changed element is applied in one call with all its attributes (document::set_element_attributes), one re-match for
// them all. litehtml's `commit_patch` ends the session
// (text and attributes together), and the plan is exact: a refusal after the first mutation is an inconsistency, and the
// widget stops (stopInternally).
//
// Task 9, structure (Ruling 8; twidget edit 18). A journal with a structural entry (Inserted, Removed, Children) goes to
// flushStructure, any other to flushPatch: that is the selection rule across the three paths, with one exception. A Text
// swap, the `textContent = …` idiom (a mapped element whose only child is a Text inserted since the flush, and the one
// mapped Text with pieces that went from under it; textSwaps), is a text replacement: when every structural entry
// belongs to one, flushPatch plans the new Text against the old one's entry (its pieces, its place in the render
// input, its budgets), replaces the pieces as a data change does, so litehtml keeps its render tree, and at the commit
// gives the new Text that entry, with a new NodeKey (a new node's, as a build gives it); the old one's root is released
// after the flush. Beside it the
// journal's attribute and text changes on kept nodes patch as usual. The structure path takes
// Text and Attribute entries on nodes it builds or removes (they are read with their subtree), on nodes no build reads
// (outside the main document, or under an element Ruling 4 leaves out) and on kept nodes beside structure (a mixed
// journal): a kept element's own attributes are set in place in the session (document::set_element_attributes,
// planned as the attribute path plans them, its start tag and budgets kept in step), outside walk mode a kept Text's
// pieces are replaced in place after the insertions (document::replace_text, planned as the text path plans it, the
// text-piece cap counted as the open session counts it, from the pieces alive when it opens) where it has pieces before
// and after and can_replace_text takes it, and any other kept node goes and is built again where it is; one on any
// other node with no entry, which a cap cut, walks
// the cut ("The caps", below). The dirty parents are the mapped
// elements with a Children entry (the document's own replace the document element in place when it is another node,
// flushRoot, and else render nothing: twidget edit 82; the document element's replace it too when they change which head
// or body is the document's own or move either, ownHeadAndBodyStay, and else are an element's like any other; a
// `<style>`'s, and its Text's or its own change, are its sheet:
// planSheets reads it again, twidget edit 81), and they are reconciled in two passes, every removal planned and counted
// before anything is built:
// - **What goes:** every mapped node with a Removed entry (moved out, moved within its parent, or gone: each of these
//   records one), its element or its Text's pieces removed (document::remove_subtree) unless inside another removal,
//   and every entry under it released, found both in its litehtml subtree and in its DOM subtree (a Text that made no
//   pieces, whitespace under a `<table>`, is mapped and in the render input with no place in litehtml).
// - **What comes:** each DOM child of a dirty parent with no entry left is built (buildRenderSubtree: the build's own
//   walk, so build and patch agree by construction) within what the rest of the document uses of the limits, and
//   inserted (document::insert_subtree) before the next kept sibling that has an element or pieces, or at the end before
//   an ::after. A move from A to B keeps its old element under A until A goes, which is why removals come first.
// - With sibling combinators or positional pseudo-classes in the sheets (document::structure_reaches_siblings), the fork
//   matches again at the commit the other children a rule can reach and their subtrees (twidget edit 90).
// Inserted nodes whose parent has no element are not journaled (detached, in a template, under an element Ruling 4 leaves
// out). A refusal of the fork's predicates hands the change to walk mode, and one there is an inconsistency (the
// runtime passes only mapped DOM nodes, and profile 1 drops every element whose children an element reads). A subtree a fresh build would cut (Ruling 7's byte budget and `style` cap, E6's form controls, E9's
// elements, the depth), sheets a fresh build would cut (Ruling 7's 64 KiB of `<style>` text and profile 1's budgets, in
// tree order) and the fork's depth, element and text-piece caps walk the cut ("The caps", below). The plan builds the new
// subtrees detached with the published document, asks every predicate in the order the patch makes the changes (threading
// what each adds to the caps), allocates, and composes the render input; the patch makes the changes, moves what went
// to graveyards freed after the publish, moves the kept entries' places with the input's patches and the new ones in,
// and commits. An element's entry keeps where its serialization ends (inputEnd, endTagLength), and an empty
// Text has no place, so no two entries start at one offset. An insertion has two anchors: its place in litehtml (the next
// kept sibling with an element or pieces) and its place in the render input (the next kept sibling with a place there),
// which differ at a Text that made no pieces.
// Only what renders counts (twidget edit 83): an element a parent's own append refuses (a <div> or a <tr> straight under a
// <table>) is in no build and counts toward no limit, so its changes, and those of anything under it, render nothing, and
// inserting one inserts nothing (RenderTree::refusedByParent, readByABuild).
//
// The caps (RenderCut.h). A build hands every cap out in tree order, and a patch cuts where a fresh build of the DOM as
// it now is would cut. A flush plans against the rest of the document's sums (sum mode), unless the published build's
// walk hit a limit (RenderBuild::walkLimits) or a change the journal does not hear may have moved a cut
// (Journal::markCut: a node inserted or removed under an element no build renders, with the node cap in play). A cap
// the sums would cross switches the same flush to walk mode before any litehtml call. Walk mode walks the DOM as a build
// walks it (renderCutDiff) and folds in every node whose fate, pieces, bytes or units differ from its entry: one with an
// entry is built again where it is, one with none that renders is built under its parent, and an element's own attribute
// change is set in place wherever the walk renders it with its tag, as in sum mode (a <style>'s is built again with its
// sheet). The walk keeps the state before every node only where every child of a reached parent is built
// again (sibling combinators or positional pseudo-classes); else before the journal's nodes, their parents and the nodes
// the cut moved. Each subtree is built in cut
// mode from the walk's state before it (buildRenderSubtree's applyCut: it notes limits, skips and stops as a build
// does), and the totals are the walk's end. The document's html, head or body at a cap is built again through the
// root (flushRoot), cut as a build cuts it. The published limits are the walk's, then the kinds litehtml's style pass
// reached (document::style_pass_limits: the replay recomputes those, so they need no walk); publishLimits posts each
// kind the previous list lacked, once per hit. widget-sandbox v0.3.0's strict caps that stop the widget are judged where
// a whole document is counted: canvas pixels by the walk (a canvas in a new subtree, or one resized, is refused in sum
// mode), CSS rules and @keyframes by the sheet plan over every applied sheet (planSheets), a text value wherever it is
// read, the document's text where a build or the walk counts it.
//
// Matching (Ruling E19). litehtml counts a step for each selector it tests against an element; the steps are a budget
// of each build or patch session. The boot's build matches within litehtml's 4,000,000 (RenderOptions::selectorStepCut,
// RenderBuild::stepCut: a hostile boot is cut there), and such a document's first patch matches it whole again, uncut
// (twidget edit 84's replay); it records the steps it used (selectorSteps). A patch's matching (an attribute re-match,
// an inserted or replaced subtree, a replay; a text matches nothing) runs in a session of kPatchSelectorSteps, and
// nothing counts what earlier patches took. A session cut by that limit stops the widget (stopInternally) with
// litehtml's document patched and never laid out and the published tree kept, as when a replay is cut. Any other
// can't-happen after the document was changed (a fork refusal the predicates did not foresee, an anchor not found) is an
// inconsistency: the widget stops (stopInternally). No patch ends in std::abort.
//
// Task 10b, the layer mirror (twidget edit 20; LayerMirror.h). The published tree mirrors litehtml's painting (Context,
// Box and Inline nodes with stable LayerIds, keyed by their DOM node's NodeKey from the element → node map, which ends
// Ruling 20's deferral), and every flush re-lays out and applies the fork's reported changes to the mirror as operations;
// nothing is compared (Ruling 8, from this task on). The boot's build walks the document once (walk_paint_order) into
// the mirror and publishes Inserts of the whole tree, the root's first; every patch publishes the mirror's operations: what the fork kept is re-captured, what it
// replaced (twidget edit 74: every structural patch, any other attribute patch) is placed again (LayerMirror.h). A report
// the mirror cannot place is an inconsistency: the widget stops (stopInternally). layerOps() is what the last publish
// carried; an operation's changedRects come from the nodes it names, and the boot's from no previous tree.
//
// Atomic (Review Focus 2): the boot's build, its layout and its mirror happen on a new document with new maps, swapped
// in and published only when all of it has succeeded. A patch is atomic in what it publishes: a stop after its commit
// (matching or a replay cut at its limit, an inconsistency) leaves the published tree, and the widget frozen on it.
//
// Time (the CPU-clock limits plan, Task 2): a flush (the boot's build or a patch) runs inside a Runtime::RenderScope,
// which measures its CPU time as the renderer's and keeps it out of the widget's slice; a layout query's flush (flushForQuery) is
// the task's layout-query time too, which the 100 ms limit reads (Runtime::queryBudgetSpent).
//
// The maps (Ruling 14), the journal and the render input (kept only for tests: RenderOptions::keepRenderInput, Ruling
// E11) go through QuickJS's allocator. Each mapped or journaled node is held by an untraced, counted root (a Ref<Node>),
// released when its build is replaced or its entry goes, and in the destructor, so a RenderTree must be destroyed while
// its context and the main document are alive (HostState declares it last, and Runtime::~Runtime resets the host's
// extension before the DOM's).
//
// The memory bound. litehtml, the container and the layer tree use the system heap, outside the widget's memory limit;
// the render limits (Rulings 7, E6 and E9) bound them. RenderBuildTests' testHostileSizesAreBounded holds the heap
// growth of each hostile single build under 160 MB and prints them.
// - Headline, the styled-element case: 10,000 styled elements (Ruling E9) at ~10.4 KB each, litehtml and their tree
//   items (20,000 divs with a border, a background, a shadow, a radius and a clip measured 153 MB of litehtml and 55 MB
//   of tree), ≈ 104 MB published.
// - Unstyled, 10,000 elements at ~3.4 KB (20,000 divs measured 67 MB, painting nothing): ≈ 34 MB published.
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
// That is ≈ 156 MB published, and ≈ 200 MB at the boot's build's peak; a patch never holds two documents.
// Not closed by the render limits:
// - a computed list value (box-shadow, background layers) is copied into every element it applies to and painted once
//   per entry: a 100-shadow box-shadow on 1,000 divs measured 107 MB of litehtml and 27 MB of tree (100,000 items). The
//   next task closes it at parse (twidget edit 15 caps list-valued CSS; Ruling E7);
// - litehtml's process-global caches (master and author sheets, declarations) and interned names (Ruling 12).
#pragma once

#include <cstddef>
#include <cstdint>
#include <map>
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
#include "Sources/Render/SelectableText.h"
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

/// Ruling E19: the selector steps a patch's matching may take, its replay's included (twidget edit 84): seven builds'
/// worth of litehtml's 4,000,000, since the replay after a boot cut there needs more than one build's. Past them the
/// widget stops (RenderTree::stopInternally).
inline constexpr int64_t kPatchSelectorSteps = 28'000'000;

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

    /// The boot's build: the whole document from the DOM, laid out at the options' width and mirrored (Inserts); then
    /// published, with changedRects from no tree, and the render-limit kinds the build hit posted to the host (Ruling 7:
    /// each once, as `render-limit` diagnostics, after the publish). The container's build window closes after the
    /// mirror's walk (Ruling E10). Atomic. Throws Aborted when the build stops the widget (a strict cap, the memory limit,
    /// a C++ failure; abortForCaughtException latched it), and at once, building nothing, when the runtime has already
    /// stopped; std::logic_error when the tree has built already (the first flush calls it; a test calls it on a tree of
    /// its own). The journal records from here. A build entered from inside a build (a host that calls back, against
    /// RenderHost's contract) returns at once.
    void build(JSContext* ctx);

    /// Applies the journal, lays out, updates the mirror and publishes: the first time, the boot's build; then a patch
    /// whenever anything is dirty (the journal has an entry, a width, theme or reduced motion changed). Atomic in what it
    /// publishes. Nothing when clean, once the runtime has stopped (the last published tree stays: spec §5, "Flush"),
    /// or when re-entered (a host calling back from inside the build). Throws Aborted when the widget stops in it.
    void flush(JSContext* ctx);
    /// The flush a layout query makes from inside its binding (M2), so the query reads the current layout. The same
    /// flush, except that a stopped runtime throws Aborted, as every native path a binding reaches does; a stop in its
    /// build throws Aborted too, which unwinds the binding to the step boundary.
    void flushForQuery(JSContext* ctx);
    /// The layout width (RenderOptions::width) and the color scheme (RenderOptions::theme, Ruling 6), stored on the
    /// container; the next flush applies a change in its patch (twidget edit 79). The same value again changes nothing.
    /// Once the runtime has stopped, nothing is stored.
    void setWidth(JSContext* ctx, double width);
    /// The scheme, with the root's theme declarations (RenderOptions::rootDeclarations): the next flush applies a change
    /// in its patch (twidget edit 80).
    void setTheme(JSContext* ctx, Theme theme, std::string rootDeclarations);
    /// The root's content safe area declarations (RenderOptions::contentSafeAreaDeclarations): a change, as the theme's, is
    /// applied in place at the next flush (twidget edit 80).
    void setContentSafeArea(JSContext* ctx, std::string declarations);
    /// prefers-reduced-motion (RenderOptions::reducedMotion): the next flush applies a change in its patch. Never throws.
    void setReducedMotion(JSContext* ctx, bool reduced);
    /// The options a build uses now: the construction's, with the width and theme set since.
    const RenderOptions& options() const { return m_container.options(); }

    /// A canvas's bitmap changed (V5d plan, Task 4): when the canvas is rendered, the next flush republishes its box
    /// alone, which the mirror captures again (Content) with the bitmap's current snapshot, beside the patch that flush
    /// publishes or with none; nothing is laid out for it. An unrendered canvas changes nothing. Throws Aborted when
    /// recording the canvas fails (out of memory).
    void canvasPainted(const Element& canvas);
    /// An <img>'s source decoded, kept nowhere (WidgetContainer::decodeImageUncached).
    std::optional<DecodedImage> decodeImageUncached(std::string_view src) { return m_container.decodeImageUncached(src); }
    /// The image layout already decoded for `src` (WidgetContainer::decodedByLayout).
    std::optional<DecodedImage> decodedByLayout(std::string_view src) const { return m_container.decodedByLayout(src); }
    /// Tests: the container's cached fonts and images (WidgetContainer::cachedFonts, cachedImages).
    size_t cachedFonts() const { return m_container.cachedFonts(); }
    size_t cachedImages() const { return m_container.cachedImages(); }
    /// The host the tree lays out and paints with (canvas bitmaps and fonts come from it too, V5d).
    RenderHost& host() const { return m_container.host(); }
    /// The published tree; nullptr before the first build.
    std::shared_ptr<const LayerTree> layerTree() const { return m_tree; }
    /// What the host sizes the widget by (M1d plan, Task 1): the content's own width as the last layout returned it
    /// (litehtml::document::render, today's renderer's "natural" width; the fork declares content_width() but never
    /// defines it), and the document's height. nullopt before the first build.
    std::optional<ContentSize> contentSize() const;
    /// The hover or active state of `anchor` and its inclusive ancestors may have changed (UserActions, M1d plan Task
    /// 3): when the published build's CSS names a user-action pseudo-class or it has a form control (the UA sheet's
    /// pressed button), each of them that the build renders is journaled (JournalKind::State), and the next flush
    /// matches what the change reaches again (twidget edit 75).
    void userActionStateChanged(Element* anchor);
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
        /// The CSS leaves the width / height auto (or another keyword): the content sizes it.
        bool autoWidth = false, autoHeight = false;
    };
    std::optional<BoxMetrics> boxMetrics(const Node& node) const;
    /// HTML's "being rendered": `node` is laid out and neither it nor an ancestor is display: none (litehtml keeps an
    /// empty render item for a display: none element). What img's width and height ask (widget-sandbox v0.2.3).
    bool beingRendered(const Node& node) const;
    /// The padding box of an element that clips its contents (overflow other than visible), which Intersection Observer
    /// clips a target by; nullopt for any other node.
    std::optional<RenderBox> overflowClip(const Node& node) const;
    /// SVG geometry (V3b plan, Task 4), in the element's user units (litehtml::svg_geometry; no transforms applied): a
    /// shape's box from its path's points and curve extrema, or the union of the shapes a container holds. nullopt when
    /// nothing is rendered there.
    std::optional<RenderBox> svgBBox(const Node& node) const;
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
    /// features the last noteMediaReported() kept. False before the first build (a length needs the document).
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
    /// The selectable text of the published layout (sdk-v1 §5.10; SelectableText.h). Text whose box lies wholly at or
    /// below `visibleHeight` is left out. Runs no script and flushes nothing; it may give Text nodes their NodeKeys, as
    /// a mirror does.
    SelectableText selectableText(double visibleHeight);
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
    /// Texts those patches swapped in for a Text that went (textSwaps), for tests.
    uint64_t swappedTexts() const { return m_swappedTexts; }
    /// Distinct nodes the journal recorded since the last flush; 0 before the boot's build (tests).
    size_t journalNodes() const { return m_journal.nodes(); }
    /// The last refusal a path handed on to the next (publishJournal), for tests' reports.
    const char* lastPatchRefusal() const { return m_refusal; }
    /// Ruling E19, for tests: the selector steps the published build's matching used, and the last patch's steps.
    int64_t selectorSteps() const { return m_current.selectorSteps; }
    /// Whether the published build is the boot's, its matching cut at litehtml's 4,000,000 steps, and no patch has replayed
    /// its style pass since (twidget edit 84).
    bool stepCut() const { return m_current.stepCut; }
    /// For tests: caps the selector steps a patch's matching may take, its replay's included (twidget edit 84), so a test
    /// can cut one and see the widget stop (stopInternally). INT64_MAX (the default): no cap.
    void setPatchStepCapForTesting(int64_t cap) { m_patchStepCap = cap; }
    /// For tests: told before each flush after the boot that has a journal to apply (before anything is applied), and
    /// after that flush published; a flush that stops the widget is told only before. Null by default.
    struct FlushProbe {
        virtual ~FlushProbe() = default;
        virtual void beforeFlush(const RenderTree& tree) = 0;
        virtual void afterPublish(const RenderTree& tree) = 0;
    };
    void setFlushProbeForTesting(FlushProbe* probe) { m_flushProbe = probe; }
    /// For tests: the journal the next flush applies.
    const Journal& journalForTesting() const { return m_journal; }
    /// keyOf, for tests.
    NodeKey keyOfForTesting(const litehtml::element& element) { return keyOf(element); }
    /// The owner's NodeKey of a generated element's (keyOf a ::before, an ::after or a form control's lh-* part); 0 for
    /// any other key. Tests.
    NodeKey ownerKeyOfGenerated(NodeKey key) const;
    /// The render byte budget the published build uses (Ruling 7), for tests.
    uint64_t renderBytes() const { return m_current.bytes; }
    /// The elements the published build rendered (Ruling E9), for tests.
    size_t renderedElements() const { return m_current.elementCount; }
    /// Profile 1's text units the published build counts (V4 plan, Task 7), for tests.
    TextUnits renderedTextUnits() const { return m_current.textUnits; }
    /// The published build, for the cut walk (RenderCut.h) and tests.
    const RenderBuild& publishedBuild() const { return m_current; }
    WidgetContainer& container() { return m_container; }
    /// The render-limit kinds the published build hit (a patch agrees with a fresh build on them), for tests.
    const std::vector<std::string>& renderLimits() const { return m_current.limits; }
    int64_t lastPatchSteps() const { return m_lastPatchSteps; }
    /// Task 10b: the operations the last publish carried (the boot's: Inserts of the whole tree); the walks of litehtml's
    /// paint order so far (one, the boot's); and the fork's replacements of a render subtree, which the mirror places with
    /// operations (tests).
    const std::vector<LayerOp>& layerOps() const { return m_layerOps; }
    uint64_t mirrorWalks() const { return m_mirrorWalks; }
    uint64_t subtreeReplacements() const { return m_subtreeReplacements; }
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
    /// there, or at a bdi, script, style or textarea, which auto skips.
    void noteAutoDirection(Node* from);
    /// What a path did: patched and published; or refused, having changed nothing, for the next path to take the change
    /// (publishJournal).
    enum class PatchResult { Refused, Patched };
    /// The in-place fast path (Tasks 7 and 8), and the Text swaps it takes for structure (textSwaps). Throws Aborted when
    /// the widget stops while planning, with the published state untouched.
    PatchResult flushPatch(JSContext* ctx, const std::unordered_map<Node*, Node*>& swaps);
    /// Whether every structural entry of the journal belongs to a Text swap, the `textContent = …` idiom: a mapped
    /// element whose only child is a Text inserted since the last flush, and the one mapped Text with pieces under it that
    /// went. Fills `swaps` (the new Text → the old one) when it answers true.
    bool textSwaps(JSContext* ctx, std::unordered_map<Node*, Node*>& swaps);
    /// The journal applied: the boot's build, then patches (the text and attribute path, the structure path, its walk of
    /// the cut; a refusal walking the cut stops the widget, stopInternally); with no journal, the painted canvases alone
    /// (publishRepaints).
    void publishJournal(JSContext* ctx);
    /// The painted canvases' boxes captured again and published, nothing else changed.
    void publishRepaints(JSContext* ctx);
    /// Reports each painted canvas the published build maps to the mirror as restyled in place, so the next publish
    /// captures its box again. Never throws.
    void reportRepaints() noexcept;
    /// What applying the journal resolves styles for again (V5f plan, Task 2): everything before the boot's build, when
    /// the environment changes or when a sheet does (twidget edit 81: `@keyframes` are read again); else the elements whose DOM
    /// attributes changed and every element of each inserted subtree. Read before the journal is applied.
    animation::StyleChange pendingStyleChange(JSContext* ctx);
    /// Twidget edit 81: whether the journal changes a rendered `<style>`'s Text or attributes, or (with `subtrees`) its
    /// children, or inserts or removes a subtree holding a `<style>`.
    bool journalTouchesSheets(JSContext* ctx, bool subtrees);
    /// Twidget edit 81: the sheets as a structure patch leaves them (planSheets).
    struct SheetPlan {
        /// A kept `<style>` whose sheet is read again: its new sheet, the piece replace_style_text makes (reserved), its
        /// text as the render input carries it, and where that goes in the staging input.
        struct Change {
            Node* node = nullptr;
            RenderEntry* entry = nullptr;
            RenderSheet sheet;
            std::vector<litehtml::element::ptr> pieces;
            std::string escaped;
            size_t from = 0;
            size_t to = 0;
        };
        std::vector<Change> changes;
        /// RenderBuild::styleSheets after the patch, and whether one names a user-action pseudo-class.
        std::vector<std::string> applied;
        bool usesUserActionPseudo = false;
        /// The text units the document counts after the patch (the budgets checked), and the pieces the changes add and
        /// remove.
        TextUnits units;
        size_t addedPieces = 0;
        size_t removedPieces = 0;
        /// Whether the applied sheets change (the fork then tests every new rule against every element), and a bound of
        /// the rules the new author sheets hold (a rule takes two bytes at least).
        bool changed = false;
        uint64_t ruleBound = 0;
    };
    /// The sheets a fresh build of the patched tree applies, in tree order: each `<style>` kept, built in `staging`, or
    /// kept and in `reread` (read again from the DOM, as a build reads it); `released` are going. `units` are the
    /// document's text units without the reread sheets' change, or, when `counted` (walking the cut: the walk read every
    /// sheet as it now is), with it, kept as they are. Nullopt where a fresh build would post a `<style>` limit (`css`,
    /// `text-budget`): the patch walks the cut.
    std::optional<SheetPlan> planSheets(JSContext* ctx, const RenderBuild& staging, const std::unordered_set<Node*>& reread,
                                        const std::unordered_set<Node*>& released, TextUnits units, bool counted = false);
    /// The structure fast path (Task 9; twidget edit 18), for a journal with a structural entry other than Text swaps, or
    /// one that changes a `<style>`'s sheet (twidget edit 81). Throws Aborted as flushPatch does.
    PatchResult flushStructure(JSContext* ctx, bool walk = false);
    /// Twidget edit 82: whether the DOM's document element is the one the published build rendered (none and the empty
    /// `<html>` of Ruling 11 alike).
    bool documentElementKept(JSContext* ctx, litehtml::document& document) const;
    /// Twidget edit 82: whether the DOM's head and body (Document::head, body) are the ones the published build adopted
    /// (the children of its root rendered as head and body: one it did not adopt renders as a div), neither of them moved
    /// (the subtree builder builds the document's own head and body only with their document element).
    bool ownHeadAndBodyStay(JSContext* ctx, litehtml::document& document) const;
    /// Twidget edit 82: flushStructure's path when the document element is another: everything published goes, the new
    /// document element is built detached (buildRenderRoot) and document::replace_root takes it, in one patch session
    /// with the environment. Throws Aborted as flushStructure does.
    PatchResult flushRoot(JSContext* ctx, litehtml::document& document);
    /// Ruling E25: whether a build of the main document reads `node`, as far as the DOM tells: it is in the main document
    /// and neither it nor an ancestor is an element Ruling 4 leaves out.
    bool readByABuild(JSContext* ctx, Node& node) const;
    /// Twidget edit 83: whether `element`'s parent is mapped to a litehtml element whose own append refuses it (a <div>
    /// or a <tr> straight under a <table>): then it renders nothing and counts nothing, nor does anything under it.
    bool refusedByParent(JSContext* ctx, const Element& element) const;
    /// Twidget edit 84: the commit's replay of the style pass near a cap. Its step limit, kPatchSelectorSteps (or the
    /// test's cap); after the commit, the patch's own steps (the session's less the replay's), a replay cut by its limit
    /// stopping the widget (stopInternally); and the kinds the
    /// style pass reached, by Ruling 7's names.
    int64_t replayStepLimit(JSContext* ctx) const;
    int64_t ownSteps(JSContext* ctx, const litehtml::document& document, int64_t used);
    static void styleLimits(const litehtml::document& document, std::vector<std::string>& limits);
    /// Replaces the published limits with `next` (each kind once, in order) and posts, as `render-limit` diagnostics,
    /// each kind the previous list lacked: a kind newly reached is posted once, one no longer reached leaves the list.
    void publishLimits(JSContext* ctx, std::vector<std::string> next);
    /// Task 10b: an element's NodeKey in the build the mirror is being built for (m_keyBuild, else the published one),
    /// given when first asked.
    NodeKey keyOf(const litehtml::element& element);
    /// A new mirror of `document`, observing it, keyed from `build`; its walk is counted.
    std::unique_ptr<LayerMirror> newMirror();
    /// The mirror's patch publish: what a patch flush publishes. Throws as LayerMirror::publish does.
    struct MirrorPublish {
        std::shared_ptr<const LayerTree> tree;
        std::optional<std::vector<litehtml::position>> changed;
        std::vector<LayerOp> ops;
        /// The fork's replacements of a render subtree (LayerMirror::replacedSubtrees).
        size_t replaced = 0;
    };
    MirrorPublish publishPatch();
    /// An inconsistency (LayerMirror::Inconsistent): posts the host diagnostic `render-internal` with `why`, stops the
    /// widget (StopReason::Internal) and throws Aborted. The published state stays as it was.
    [[noreturn]] void stopInternally(JSContext* ctx, const char* why);
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
    /// The rendered canvases painted since the last flush (canvasPainted), each once, held as a journal entry holds its
    /// node; and the set of them, for the once.
    std::vector<Ref<Element>> m_paintedCanvases;
    std::unordered_set<const Element*> m_paintedCanvasSet;
    /// Elements whose DOM attributes changed since the last flush (attributeChanged; not the animated layer's changes):
    /// what an attribute patch resolved styles for again. Compared, never dereferenced.
    std::unordered_set<const Element*> m_domAttributeChanges;
    /// What changed since the published build. Dirty, recording nothing, until the boot's build.
    Journal m_journal;
    /// The nodes inserted into the main document since the published build where the journal does not hear them (under
    /// an element no build renders): a build counts them against kMaxRenderNodes (V4 plan, Task 7), so the published
    /// count plus these stays an upper bound, and past the cap the next flush walks the cut (final review C2).
    size_t m_unheardNodes = 0;
    std::shared_ptr<const LayerTree> m_tree;
    std::optional<std::vector<litehtml::position>> m_changedRects;
    /// The union takeChangedRects hands over: every publish adds its m_changedRects (accumulateChangedRects).
    std::optional<std::vector<litehtml::position>> m_accumulatedRects{std::in_place};
    void accumulateChangedRects() noexcept;
    /// Task 10b: the mirror of the published document, declared after m_current so it goes first (it observes the
    /// document); the LayerId and NodeKey counters (never reused); the build keys come from while the boot builds.
    std::unique_ptr<LayerMirror> m_mirror;
    LayerId m_nextLayerId = 1;
    uint64_t m_nextKey = 1;
    RenderBuild* m_keyBuild = nullptr;
    /// The keys of twidget's generated elements (::before, ::after, a form control's lh-* parts), which map to no node: by
    /// their owner's key and their tag, so a generated element made again for the same owner and slot keeps its key. An
    /// owner's go when its entry leaves the build and no staged entry takes its key.
    std::map<std::pair<NodeKey, int>, NodeKey> m_generatedKeys;
    NodeKey generatedKeyOf(const litehtml::element& element);
    void forgetGeneratedKeys(NodeKey owner);
    std::vector<LayerOp> m_layerOps;
    uint64_t m_mirrorWalks = 0;
    uint64_t m_subtreeReplacements = 0;
    uint64_t m_buildCount = 0;
    uint64_t m_patchCount = 0;
    uint64_t m_swappedTexts = 0;
    /// Set while a build or a patch runs: a flush or build entered then returns at once.
    bool m_flushing = false;
    /// The style-change step is running (V5f): script it runs (a promise's `then` getter) cannot flush again, so the step
    /// is never re-entered; the outer flush's second pass publishes what that script changed.
    bool m_styleStepRunning = false;
    /// lastPatchRefusal, lastPatchSteps.
    const char* m_refusal = "";
    /// Why the fork's predicate refused, when one did (twidget edit 76: document::refusal()); named with m_refusal.
    const char* m_refusalReason = "";
    int64_t m_lastPatchSteps = 0;
    int64_t m_patchStepCap = INT64_MAX;
    FlushProbe* m_flushProbe = nullptr;
    PatchResult refused(const char* why) {
        m_refusal = why;
        m_refusalReason = "";
        return PatchResult::Refused;
    }
    /// A refusal by the fork's `predicate`, with the reason `document` gives (twidget edit 76).
    PatchResult refusedBy(const char* predicate, const litehtml::document& document);
    /// Adds to `change` the elements under `restyled` (a patch's restyled elements, each with its subtree) that it does
    /// not hold, a node visit each (twidget edit 77).
    void noteRestyled(JSContext* ctx, const std::vector<litehtml::element::ptr>& restyled, animation::StyleChange& change);
};

/// Makes the runtime's render tree over `host` with `options`, and puts it in the HostState (HostState::render()),
/// which owns it from then on, replacing any tree before it. Call after installHost and before boot, so the boot's
/// flush builds the parsed markup. `host` must outlive the runtime.
RenderTree& installRender(JSContext* ctx, RenderHost& host, RenderOptions options);

} // namespace wr
