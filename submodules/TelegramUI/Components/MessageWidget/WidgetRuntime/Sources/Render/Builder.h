// The DOM → litehtml build (M1c plan, Task 5): the whole litehtml document made from the runtime's main document,
// element by element (twidget edit 12), with no HTML string and no validator (Ruling 2).
//
// The walk is iterative, in tree order (Global Constraints, "Stack"), from the document element (Ruling 11):
// - An element named in Ruling 4's list (in any namespace, by its local name compared ASCII case-insensitively, since
//   litehtml lowercases tag names) is skipped with its subtree. So is the 10,001st rendered element and every later one
//   (Ruling E9, `elements`, asked before litehtml's own 20,000), and one litehtml's caps refuse
//   (external_element_allowed: depth 256). Template contents are never walked: they are not children.
//   Comments, doctypes and processing instructions are skipped.
// - Any other element is created with its local name and its attributes by qualified name, as the DOM holds them. An
//   attribute whose name equals an earlier one's ASCII case-insensitively is left out (litehtml keeps one value per
//   lowercased name: the first, as an HTML parser would); a `style` attribute over 16 KiB of UTF-8 is left out and
//   posts `style-attribute`.
// - A `<style>`'s sheet is its Text children's data (Ruling 10), appended as one piece. A sheet that would take the
//   document past 64 KiB of `<style>` text is not applied and posts `css`. A `<style>`'s own children are not walked.
// - Any other Text node is appended as litehtml's pieces (split_text's words and spaces) and mapped to them.
// - The render byte budget (Ruling 7): 1 MiB of UTF-8, in tree order, counting attribute names and values and text.
//   (Ruling 7 says values; counting the names as well is a superset, and it also bounds the attribute count, whose
//   names are otherwise free.) The node that would pass it is not rendered, nor anything after it: the walk ends, and
//   `bytes` is posted.
// - A string is never converted past the limit it is checked against: a UTF-16 length is a lower bound of its UTF-8
//   length, so a longer one is refused unconverted, and a shorter one is converted only up to the limit.
// - At most 256 form controls (input, textarea, select, button: by local name, ASCII case-insensitively, in any
//   namespace, as litehtml makes them) render per document, in tree order (Ruling E6): litehtml generates each
//   control's parts outside its element and text caps. A later one is skipped with its subtree, the rest of the
//   document still renders, and `form-controls` is posted.
// - With no document element, or none rendered, the root is an empty `html`.
// - Matching (Ruling E19): finalize runs in one selector-step session of litehtml's 4,000,000 (default_selector_steps;
//   none in a test's fresh tree, RenderOptions::selectorStepCut); a matching cut there is the document's, and
//   RenderBuild::selectorSteps records the steps it took.
// - Only what renders counts (twidget edit 83): the parent's own append is asked before any limit counts an element, and
//   one it refuses (a <div> or a <tr> straight under a <table>) renders nothing, with its subtree. A Text under a parent
//   that takes no text is in the render input (its bytes and units count) and asks litehtml's piece cap nothing.
//
// The same walk builds one subtree for the in-place structure patch (Task 9, buildRenderSubtree): detached, with the
// published document, its text made with make_text_pieces (twidget edit 18 counts the pieces), within the limits the rest
// of the document leaves, and refusing (the patch then walks the cut) wherever this build would post a limit or meet a
// `<style>`.
#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include <litehtml/document.h>
#include <litehtml/element.h>

#include "Sources/Host/MarkupPolicy.h"
#include "Sources/Runtime/Limits.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/PlatformObject.h"
#include "Sources/Support/Values.h"

namespace wr {

class Element;
class Node;
class WidgetContainer;

/// Ruling 7: the render byte budget, in UTF-8 bytes of text and attribute names and values.
inline constexpr size_t kMaxRenderBytes = 1024 * 1024;
/// RenderEntry::inputOffset of a node with no text in the render input.
inline constexpr size_t kNoRenderInput = ~size_t(0);

/// Ruling 7: the `<style>` text a document applies, in UTF-8 bytes together.
inline constexpr size_t kMaxStyleText = 64 * 1024;
/// Ruling E9: litehtml and the layer tree cost about 10.4 KB per styled element (20,000 styled divs measured 153 MB of
/// litehtml and 55 MB of tree), so W renders half of litehtml's own 20,000.
inline constexpr size_t kMaxElements = 10000;
/// Ruling E6: litehtml generates each control's parts outside its element and text caps (20,000 inputs measured 436 MB;
/// the corpus maximum is 19 controls). Profile 1 drops every control but <button> (V4 plan, Task 4), which is the one
/// counted, by the rendered tag.
inline constexpr size_t kMaxFormControls = 256;

/// Profile 1's strict text limits (V4 plan, Task 7; RB §7.1), in UTF-16 units: one text value (a Text's data, a text
/// attribute, the strings of a `style` attribute or a sheet) and the document's text are the runtime's Limits
/// (widget-sandbox v0.3.0: 32,768 and 49,152 under strict, past which the widget stops); its complex-script text is
/// 8,192 under both policies, past which the text is dropped. And the node cap: the document node, every element, Text
/// and Comment, rendered or not, a `<script>`'s children aside.
inline constexpr size_t kComplexTextBudgetUnits = 8192;
inline constexpr size_t kMaxRenderNodes = 50000;

/// Text as profile 1's budgets count it (RB §7.2): UTF-16 units, and the complex ones, units >= U+0590 (each surrogate
/// of an emoji, typographic punctuation, CJK, ...).
struct TextUnits {
    size_t units = 0;
    size_t complex = 0;

    TextUnits& operator+=(TextUnits other) {
        units += other.units;
        complex += other.complex;
        return *this;
    }
    friend TextUnits operator+(TextUnits a, TextUnits b) { return a += b; }
    /// `b` must be part of `a`: a total less what one of its parts counted.
    friend TextUnits operator-(TextUnits a, TextUnits b) { return {a.units - b.units, a.complex - b.complex}; }
};

/// `s`'s units. O(length).
TextUnits renderTextUnits(const String& s);
/// RB §7.2's cssStringText over raw CSS text (UTF-8): the contents of its quoted strings, a backslash inside one taking
/// the next character and one outside skipping two; counted as UTF-16 units.
TextUnits renderCssStringUnits(std::string_view css);
/// Where a value stands beside `others`, checked in this order: at most Limits::textValueUnits, the document's units
/// within Limits::textBudgetUnits, its complex units within kComplexTextBudgetUnits (reaching a budget exactly is
/// allowed). Under strict the first two stop the widget (stopForTextValue, stopForTextBudget); the last drops the text.
enum class TextFit { Fits, ValueTooLong, OverBudget, OverComplexBudget };
TextFit renderTextFit(const Limits& limits, TextUnits value, TextUnits others);
inline bool renderTextFits(const Limits& limits, TextUnits value, TextUnits others) {
    return renderTextFit(limits, value, others) == TextFit::Fits;
}

/// Twidget edit 81: a `<style>`'s sheet as the build counted it: its UTF-8 as applied (litehtml's one piece; empty for
/// none), its length in UTF-16 units (what the 64 KiB check compares first), and the text units of its text and of its
/// strings (profile 1's budgets).
struct RenderSheet {
    std::string utf8;
    size_t length = 0;
    TextUnits text;
    TextUnits strings;
};

/// An element's attributes as the build gives them to litehtml (Builder.cpp's scanAttributes), the one reading the build
/// and the in-place attribute patch (Task 8) share.
struct RenderAttributes {
    /// What create_element is given: the attributes' qualified names as the DOM spells them (litehtml lowercases them),
    /// the first of a name repeated in ASCII case-insensitively, and each value as UTF-8 up to its first NUL.
    litehtml::string_map map;
    /// The attributes as the render input's start tag carries them (` a="v"` each); only when asked to keep the input.
    std::string text;
    /// The budget they use (Ruling 7): their names and values in UTF-8.
    size_t bytes = 0;
    /// A `style` over 16 KiB was left out (the build posts `style-attribute`).
    bool styleTooLong = false;
    /// The text units of its text attributes and its `style` strings (V4 plan, Task 7); and whether one was left out
    /// for not fitting beside what the rest of the document counts (the build posts `text-budget`).
    TextUnits units;
    bool textLeftOut = false;
    /// The one left out passed the document's text budget (not only the complex-script one): under strict a build
    /// stops the widget (stopForTextBudget).
    bool overTextBudget = false;
    /// The budget ran out at an attribute (the build posts `bytes` and stops); the other fields are then partial.
    bool overBudget = false;
};

/// A rendered DOM node, as RenderTree maps it (Ruling 14).
struct RenderEntry {
    RenderEntry(Ref<Node> node, litehtml::element::ptr element, JSRuntime* rt)
        : node(std::move(node)), element(std::move(element)), pieces(JSAllocator<litehtml::element::ptr>(rt)) {}

    /// An untraced, counted root (Global Constraints, "Payload rules"): released when the entry goes.
    Ref<Node> node;
    /// An element's litehtml element; null for a Text node.
    litehtml::element::ptr element;
    /// A Text node's pieces, in order; none when its data is empty or the piece cap refused all of it.
    Vector<litehtml::element::ptr> pieces;
    // For the in-place patches (Tasks 7 and 8):
    /// The UTF-8 bytes of its data that the byte budget counted (RenderBuild::bytes); an element's, those of its
    /// attributes' names and values.
    size_t bytes = 0;
    /// The text units the strict budgets counted for it (V4 plan, Task 7): a Text's data; an element's text attributes
    /// and `style` strings (a `<style>`'s sheet is counted in RenderBuild::textUnits only). Zero for a Text not rendered.
    TextUnits units;
    /// Where its escaped text sits in RenderBuild::input, and how long it is there; an element's, where its start tag
    /// is. kNoRenderInput when the render input is not kept or it is not in it (a void element's children serialize as
    /// nothing; an empty Text has no place, so no two entries start at one offset).
    size_t inputOffset = kNoRenderInput;
    size_t inputLength = 0;
    /// An element's: where its serialization ends (after its end tag; a void element's, after its start tag), and the
    /// length of its end tag, so its content ends at inputEnd - endTagLength (Task 9 inserts and removes there).
    size_t inputEnd = kNoRenderInput;
    size_t endTagLength = 0;
    /// Its place among the build's Text and element entries, in tree order: orders two entries at the same inputOffset.
    uint32_t seq = 0;
    /// Task 10b: its NodeKey in the RenderTree (LayerTree.h), given the first time a mirror asks and carried to the entry
    /// the structure patch (RenderTree::flushStructure, a moved node) or a replaced document element's build
    /// (RenderTree::flushRoot) makes for the same node; 0 until then.
    uint64_t key = 0;
};

using RenderNodeMap = std::unordered_map<Node*, RenderEntry, std::hash<Node*>, std::equal_to<Node*>,
                                         JSAllocator<std::pair<Node* const, RenderEntry>>>;
/// Every litehtml element and piece the build made → the DOM node it renders (a `<style>`'s sheet piece → the style).
using RenderElementMap = std::unordered_map<const litehtml::element*, Node*, std::hash<const litehtml::element*>,
                                            std::equal_to<const litehtml::element*>,
                                            JSAllocator<std::pair<const litehtml::element* const, Node*>>>;
using RenderString = std::basic_string<char, std::char_traits<char>, JSAllocator<char>>;

/// One build's output. RenderTree keeps the published one; a build in progress is another, swapped in only when it
/// has succeeded. The maps and the render input go through QuickJS's allocator (Global Constraints, "Memory").
struct RenderBuild {
    explicit RenderBuild(JSContext* ctx);
    RenderBuild(const RenderBuild&) = delete;
    RenderBuild& operator=(const RenderBuild&) = delete;
    /// Exchanges everything with `other`; never throws.
    void swap(RenderBuild& other) noexcept;

    /// Declared first, so it is destroyed after the maps that point into it.
    litehtml::document::ptr document;
    RenderNodeMap nodes;
    RenderElementMap elements;
    /// `<!doctype html>` and the rendered tree in HTML's serialization (RenderTree::renderInput); empty unless the
    /// options keep it (RenderOptions::keepRenderInput, Ruling E11).
    RenderString input;
    /// The render-limit kinds this build hit, each once, in the order first hit: Ruling 7's `elements`, `depth`,
    /// `text-pieces`, `table-cells`, `css`, `style-attribute` and `bytes`, and Ruling E6's `form-controls`.
    std::vector<std::string> limits;
    /// The leading kinds of `limits` the walk noted (RenderCut.h): a patch walks the cut while there are any. The rest are
    /// the style pass's (twidget edit 84), which the commit's replay recomputes.
    size_t walkLimits = 0;
    /// Every element and piece built (RenderTree::boxCount).
    uint64_t boxes = 0;
    /// What the last layout of this document returned (litehtml::document::render): the content's own width, which
    /// the host's width fits to (RenderTree::contentSize, M1d plan Task 1). A patch's relayout updates it.
    double naturalWidth = 0;
    /// Whether this build's `<style>` text names a user-action pseudo-class (:hover, :active, :focus…): only then does
    /// a change of the focus, hover or active state restyle (RenderTree::userActionStateChanged, M1d plan Task 3).
    bool usesUserActionPseudo = false;
    /// The `<style>` texts this build applied, UTF-8, in tree order (V5f plan, Task 2: `@keyframes` are read from them).
    /// At most kMaxStyleText bytes together.
    std::vector<std::string> styleSheets;
    /// Twidget edit 81: each `<style>` the build counted, by its node (its entry's pieces are its sheet's piece), which a
    /// sheet patch compares and keeps in step.
    std::unordered_map<const Node*, RenderSheet> sheets;
    /// The render byte budget this build used (Ruling 7), which the text patch keeps in step.
    uint64_t bytes = 0;
    /// The text units the strict budgets counted (V4 plan, Task 7), which the patches keep in step; and the nodes counted
    /// against kMaxRenderNodes, which a structure patch only adds to (a removed node may stay in the DOM unrendered), so
    /// that after one it is an upper bound until the next build; RenderTree counts the insertions its journal does not
    /// hear beside it.
    TextUnits textUnits;
    size_t nodeCount = 0;
    /// The elements and form controls rendered (Rulings E9 and E6), and the next RenderEntry::seq: what a structure
    /// patch (Task 9) counts its insertions from.
    size_t elementCount = 0;
    size_t formControlCount = 0;
    uint32_t nextSeq = 0;
    /// The selector steps the build's matching took (Ruling E19). Whether the build may cut its matching at litehtml's
    /// 4,000,000 steps (the first build: RenderOptions::selectorStepCut; set before buildDocument), and whether it did:
    /// then the document is marked (note_match_cut) and its first patch replays the style pass uncut (twidget edit 84).
    int64_t selectorSteps = 0;
    bool mayCutSteps = false;
    bool stepCut = false;
};

/// Where a subtree built for an in-place insertion (Task 9) goes in the published document.
struct RenderSubtreePlace {
    /// The published document: the subtree is made with it and left detached (twidget edit 18 links it).
    litehtml::document* document = nullptr;
    /// The DOM parent, and its litehtml element, which a Text child's pieces are made for (nothing is attached to it).
    Node* parent = nullptr;
    litehtml::element::ptr parentElement;
    /// The parent element's depth, as external_element_allowed counts it (the root's is 0).
    int parentDepth = 0;
    /// Whether the parent's Text children serialize raw, and whether its content is out of the render input (it is a
    /// void element or inside one).
    bool rawText = false;
    bool silent = false;
    /// Twidget edit 82: the subtree is the document element's (the parent is the Document), whose html, head and body
    /// are the document's own.
    bool documentElement = false;
};

/// What a build has used of the caps before a node, in tree order (RenderCut.h): Rulings 7, E6 and E9, profile 1's
/// budgets, and litehtml's 20,000 elements and 10,000 text pieces for the document's own content.
struct RenderCutState {
    size_t elements = 0, formControls = 0, bytes = 0, cssBytes = 0, nodes = 0;
    TextUnits units;
    int litehtmlElements = 0, pieces = 0;
    /// The byte budget or the node cap stopped the walk: every later node is Stopped.
    bool stopped = false;
};

/// What the rest of the document uses of the limits a subtree is built within, carried from one subtree to the next,
/// and the next RenderEntry::seq.
struct RenderSubtreeTotals : RenderCutState {
    uint32_t seq = 0;
};

/// The build's steps up to layout: set_document_mode from the DOM's mode, beginBuild, the walk, then
/// finalize_from_external_root with litehtml::telegram_master_css() and the options' host CSS. The caller runs
/// endBuild after layout and recording (Ruling E10), so what they ask for counts for this build. Fills `build`, which
/// must be empty. Throws Thrown (a name's conversion at the memory limit), std::bad_alloc, or Aborted (a strict cap);
/// `build` is then to be dropped.
void buildDocument(JSContext* ctx, WidgetContainer& container, RenderBuild& build);

/// `node`'s subtree as the build makes it (Task 9), for document::insert_subtree: the same walk, names, attributes,
/// text pieces (made with make_text_pieces, which asks the cap nothing: the fork's predicate counts them) and render
/// input.
/// Its entries and element-map entries go into `staging`'s maps, its serialization is appended to `staging.input` (the
/// entries' offsets are into it), and boxes and bytes are added to `staging`'s; `roots` gets what goes under
/// the parent: the element, or a Text's pieces (none for an element Ruling 4 leaves out, or an empty Text, which is
/// still mapped). False, with what was made to be dropped, where a fresh build of the document would post a render
/// limit inside the subtree (the elements, form controls, depth, byte budget, a `style` attribute, or a `<style>`'s sheet
/// against the subtree's own: the caller checks the document's, twidget edit 81), or a document-level element. With
/// `applyCut` (a patch walking the cut, RenderCut.h) the walk cuts at every cap as a build does, from the state `totals`
/// holds before the subtree, litehtml's element and piece caps included, and notes the limits in `staging.limits`: only a
/// document-level element refuses. Throws Thrown (a name's conversion at the memory limit), std::bad_alloc or
/// Aborted (a strict cap).
bool buildRenderSubtree(JSContext* ctx, WidgetContainer& container, const RenderSubtreePlace& place, Node& node,
                        RenderBuild& staging, RenderSubtreeTotals& totals, std::vector<litehtml::element::ptr>& roots,
                        bool applyCut = false);
/// Twidget edit 82: the document element's subtree as a build makes it (an empty `<html>` when there is none, or none
/// rendered: Ruling 11), detached with the published document, for document::replace_root: buildRenderSubtree's walk with
/// the document's limits counted from nothing (everything else goes), cutting at every cap as a build does and noting the
/// limits in `staging.limits` (its walk's), its serialization after the doctype in `staging.input`. Throws Thrown (a
/// name's conversion at the memory limit), std::bad_alloc or Aborted (a strict cap).
bool buildRenderRoot(JSContext* ctx, WidgetContainer& container, litehtml::document& document, RenderBuild& staging,
                     RenderSubtreeTotals& totals, litehtml::element::ptr& root);
/// Twidget edit 83: whether `parent`'s own append takes the element litehtml makes for the rendered tag `tag`. One it
/// refuses renders nothing and counts toward no limit (only what renders counts).
bool renderParentAccepts(const litehtml::element& parent, const std::string& tag);
/// Whether litehtml makes a form control (Ruling E6) of an element named `tag` (litehtml's lowercased tag name).
bool renderIsFormControl(const char* tag);

/// `s` as the build converts it for litehtml: UTF-8, a lone surrogate as U+FFFD, cut at its first NUL. False, with `out`
/// unspecified, when that is longer than `maxBytes`; a UTF-16 length is a lower bound, so a longer string is refused
/// unconverted.
bool renderUtf8AtMost(const String& s, size_t maxBytes, std::string& out);
/// Twidget edit 81: `style`'s sheet as a build reads it with `room` bytes of `<style>` text left (Ruling 7); false when
/// it does not fit the room (the build posts `css`). Throws Thrown (a conversion at the memory limit) or std::bad_alloc.
bool renderStyleSheet(JSContext* ctx, Element& style, size_t room, RenderSheet& sheet);
/// limit.css-rules (widget-sandbox v0.3.0): adds `sheet`'s style rules and @keyframes, as upstream's validator counts them
/// over a sheet as written, to `rules` and `keyframes`, the counts of the sheets before it in tree order; past
/// Limits::cssRules or Limits::cssKeyframes the widget stops (strict only). Throws Aborted then.
void renderCountCssRules(JSContext* ctx, const Limits& limits, const std::string& sheet, size_t& rules, size_t& keyframes);
/// Whether CSS text names a user-action pseudo-class (RenderBuild::usesUserActionPseudo).
bool renderMentionsUserActionPseudo(const std::string& css);
/// HTML's escaping of text, as the render input carries it (a raw-text parent's text is not escaped).
std::string renderEscapedText(std::string_view utf8);

/// `element`'s attributes as the build reads them, and, when `startTag` is given and the input is kept, its start tag as
/// the render input carries it. `usedBefore` and `unitsBefore` are the byte budget and the text units the rest of the
/// document uses. Throws Thrown (a name's conversion at the memory limit), std::bad_alloc or Aborted (the strict
/// attribute cap).
RenderAttributes renderElementAttributes(JSContext* ctx, Element& element, size_t usedBefore, TextUnits unitsBefore,
                                         bool keepInput, std::string* startTag);
/// What the renderer's copy of `element` is (V4 plan, Task 4): profile 1's one decision (MarkupPolicy.h), read by the
/// build, both patches and the render input. Converts the name.
markup::RenderTag renderTagOf(JSContext* ctx, const Element& element);
/// Whether the profile leaves `element` out of the rendered tree: such an element, and its subtree, are never in the
/// build, so a change to them is never rendered. Converts the name.
bool renderElementIsUnrendered(JSContext* ctx, const Element& element);

/// Adds the kinds `container` reported since its beginBuild that `limits` does not have yet, by Ruling 7's names
/// (litehtml's "text" is `text-pieces`, its "table" `table-cells`).
void collectContainerLimits(const WidgetContainer& container, std::vector<std::string>& limits);

/// The master sheet a build is finalized with: litehtml's, then the host's (RenderOptions::hostCSS), as LHDocument's
/// MasterWithCSS joins them. The host's rules are the user agent's, so the author's own win over them; litehtml caches
/// the parsed result by this text.
std::string masterWithHostCSS(const std::string& hostCSS);

} // namespace wr
