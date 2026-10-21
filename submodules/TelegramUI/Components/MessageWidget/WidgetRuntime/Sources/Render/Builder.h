// The DOM → litehtml build (M1c plan, Task 5): the whole litehtml document made from the runtime's main document,
// element by element (twidget edit 12), with no HTML string and no validator (Ruling 2).
//
// The walk is iterative, in tree order (Global Constraints, "Stack"), from the document element (Ruling 11):
// - Every node it visits is charged work::kRenderNode first, and every name it converts chargeScan before converting.
// - An element named in Ruling 4's list (in any namespace, by its local name compared ASCII case-insensitively, since
//   litehtml lowercases tag names) is skipped with its subtree. So is the 10,001st rendered element and every later one
//   (Ruling E9, `elements`, asked before litehtml's own 20,000), and one litehtml's caps refuse
//   (external_element_allowed: depth 256). Template contents are never walked: they are not children.
//   Comments, doctypes and processing instructions are skipped.
// - Any other element is created with its local name and its attributes by qualified name, as the DOM holds them. Each
//   attribute is charged work::kRenderAttribute plus chargeScan of its value; one whose name equals an earlier one's
//   ASCII case-insensitively is left out (litehtml keeps one value per lowercased name: the first, as an HTML parser
//   would); a `style` attribute over 16 KiB of UTF-8 is left out and posts `style-attribute`, and a kept one is
//   charged work::kCssByte per byte.
// - A `<style>`'s sheet is its Text children's data (Ruling 10), charged work::kCssByte per UTF-8 byte and appended as
//   one piece. A sheet that would take the document past 64 KiB of `<style>` text is not applied and posts `css`. A
//   `<style>`'s own children are not walked.
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
// - Matching (Ruling E19): finalize runs in one selector-step session limited to min(4,000,000, what the work budget
//   allows), and its steps are charged after it; cut by the work budget, the build stops the widget (Budget). Its filter
//   loop (Ruling E21: every rule against every element) is asked for before each pass through finalize's matching gate
//   and charged after it, so a build that cannot afford it stops before matching. It counts
//   the elements and pieces a parent's appendChild refuses (RenderBuild::refusedElements, refusedPieces), which litehtml
//   counts and the maps do not.
// Nothing charges inside a litehtml call: the charges come before the calls they pay for (matching's after: it is
// counted, and limited, inside).
//
// The same walk builds one subtree for the in-place structure patch (Task 9, buildRenderSubtree): detached, with the
// published document, its text made with make_text_pieces (twidget edit 18 counts the pieces), within the limits the rest
// of the document leaves, and refusing (the patch then rebuilds) wherever this build would post a limit or meet a
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
    /// a rebuild makes for the same node; 0 until then.
    uint64_t key = 0;
};

using RenderNodeMap = std::unordered_map<Node*, RenderEntry, std::hash<Node*>, std::equal_to<Node*>,
                                         JSAllocator<std::pair<Node* const, RenderEntry>>>;
/// Every litehtml element and piece the build made → the DOM node it renders (a `<style>`'s sheet piece → the style).
using RenderElementMap = std::unordered_map<const litehtml::element*, Node*, std::hash<const litehtml::element*>,
                                            std::equal_to<const litehtml::element*>,
                                            JSAllocator<std::pair<const litehtml::element* const, Node*>>>;
using RenderString = std::basic_string<char, std::char_traits<char>, JSAllocator<char>>;

/// Ruling E22: what the maps' entries cost a build in work units (QuickJS counts every allocated byte at
/// JS_WORK_ALLOC_SHIFT): libc++'s hash node is the next pointer, the cached hash and the value. A piece costs its
/// shared_ptr in its entry's pieces (reserved exactly) and its element-map node. RenderStructurePatchTests pins them.
inline constexpr uint64_t kRenderElementMapNodeUnits =
    (2 * sizeof(void*) + sizeof(std::pair<const litehtml::element* const, Node*>)) >> JS_WORK_ALLOC_SHIFT;
inline constexpr uint64_t kRenderNodeMapNodeUnits =
    (2 * sizeof(void*) + sizeof(std::pair<Node* const, RenderEntry>)) >> JS_WORK_ALLOC_SHIFT;
inline constexpr uint64_t kRenderPieceUnits =
    (sizeof(litehtml::element::ptr) >> JS_WORK_ALLOC_SHIFT) + kRenderElementMapNodeUnits;

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
    /// What the layout pre-charge pays for (Ruling 9): every element and piece built, and the text's UTF-8 bytes.
    uint64_t boxes = 0;
    uint64_t textBytes = 0;
    /// What the last layout of this document returned (litehtml::document::render): the content's own width, which
    /// the host's width fits to (RenderTree::contentSize, M1d plan Task 1). A patch's relayout updates it.
    double naturalWidth = 0;
    /// Whether this build's `<style>` text names a user-action pseudo-class (:hover, :active, :focus…): only then does
    /// a change of the focus, hover or active state rebuild (RenderTree::userActionStateChanged, M1d plan Task 3).
    bool usesUserActionPseudo = false;
    /// The `<style>` texts this build applied, UTF-8, in tree order (V5f plan, Task 2: `@keyframes` are read from them).
    /// At most kMaxStyleText bytes together.
    std::vector<std::string> styleSheets;
    /// The render byte budget this build used (Ruling 7), which the text patch keeps in step.
    uint64_t bytes = 0;
    /// The elements and form controls rendered (Rulings E9 and E6), and the next RenderEntry::seq: what a structure
    /// patch (Task 9) counts its insertions from.
    size_t elementCount = 0;
    size_t formControlCount = 0;
    uint32_t nextSeq = 0;
    /// What litehtml counted that the maps do not hold (I2): elements a parent's own appendChild refused (a `<div>` or a
    /// `<tr>` straight under a `<table>`), each counted by external_element_allowed in a build, and Text pieces refused so
    /// (each asked of the piece cap). A patch adds what its subtrees make; nothing subtracts, so the counts are upper
    /// bounds until the next build.
    size_t refusedElements = 0;
    size_t refusedPieces = 0;
    /// The selector steps the matching took (Ruling E19): the build's, plus every committed patch's. Past
    /// litehtml::document::default_selector_steps the build's matching was cut, and no patch that matches is made.
    int64_t selectorSteps = 0;
    /// Rulings E20 and E22, an estimate of what rebuilding the document now would cost, in parts (RenderTree::rebuildEstimate
    /// adds them, with an estimate of the maps' and the render input's growth from empty). Not a proven bound: RenderTree.h
    /// has the parts and the recorded gap when a fallback rebuild is stopped by the budget.
    /// - walkCharge: the walk's work (the nodes, attributes, names, text, CSS and the allocations of all of it): the
    ///   build's total, measured, less its layout pre-charge, filter loop and steps (filterUnits, stepUnits) and less its
    ///   maps' final bucket arrays; then each committed patch adds the work it measured making what it adds (its subtrees'
    ///   builds, its texts' conversion and pieces, its attributes' scan) and takes off a lower bound of what a build
    ///   charged for what it replaces or releases (RenderTree.cpp, entryLowerUnits), never below 0;
    /// - the filter loop's (element, rule) pairs: `matched` is litehtml's matching_bound of the tree, as the build's gate
    ///   was last asked with it (each element, the two pseudo-elements the sheets can create for it, a form control's
    ///   three parts with theirs: a tag decides it, so attributes never change it), less what each committed patch removed and plus
    ///   what it inserted, by the same measure; against all the document's rules, an upper bound of both passes;
    /// - the layout pre-charge, from `boxes` and `textBytes` as they are; and the steps, from selectorSteps.
    uint64_t walkCharge = 0;
    uint64_t filterUnits = 0;
    uint64_t stepUnits = 0;
    uint64_t matched = 0;
};

/// Ruling E19: the selector steps the widget's remaining work budget allows, at work::kSimpleSelectorTest each, keeping
/// one unit back so that charging them never reaches the limit.
int64_t renderSelectorAllowance(JSContext* ctx);
/// Ruling E21: what apply_selector's filter loop over `elements` elements and `rules` rules is charged (every pair is
/// tested, and no step counts it): work::kScanEightUnits per eight pairs.
uint64_t renderFilterUnits(uint64_t elements, uint64_t rules);

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
};

/// What the rest of the document uses of the limits a subtree is built within, carried from one subtree to the next:
/// the byte budget (Ruling 7), the elements (E9) and form controls (E6), and the next RenderEntry::seq.
struct RenderSubtreeTotals {
    size_t bytes = 0;
    size_t elements = 0;
    size_t formControls = 0;
    uint32_t seq = 0;
};

/// The build's steps up to layout: set_document_mode from the DOM's mode, beginBuild, the walk, then
/// finalize_from_external_root with litehtml::telegram_master_css() and the options' host CSS. The caller runs
/// endBuild after layout and recording (Ruling E10), so what they ask for counts for this build. Fills `build`, which
/// must be empty. Throws Thrown (a charge), std::bad_alloc, or Aborted; `build` is then to be dropped.
void buildDocument(JSContext* ctx, WidgetContainer& container, RenderBuild& build);

/// `node`'s subtree as the build makes it (Task 9), for document::insert_subtree: the same walk, charges, names, attributes,
/// text pieces (made with make_text_pieces, which asks the cap nothing: the fork's predicate counts them) and render input.
/// Its entries and element-map entries go into `staging`'s maps, its serialization is appended to `staging.input` (the
/// entries' offsets are into it), and boxes, textBytes and bytes are added to `staging`'s; `roots` gets what goes under
/// the parent: the element, or a Text's pieces (none for an element Ruling 4 leaves out, or an empty Text, which is
/// still mapped). False, with what was made to be dropped, where a fresh build of the document would post a render
/// limit inside the subtree (the elements, form controls, depth, byte budget or a `style` attribute) or meet a
/// `<style>`: the patch rebuilds instead. Throws Thrown (a charge) or std::bad_alloc.
bool buildRenderSubtree(JSContext* ctx, WidgetContainer& container, const RenderSubtreePlace& place, Node& node,
                        RenderBuild& staging, RenderSubtreeTotals& totals, std::vector<litehtml::element::ptr>& roots);
/// Whether litehtml makes a form control (Ruling E6) of an element named `tag` (litehtml's lowercased tag name).
bool renderIsFormControl(const char* tag);

/// `s` as the build converts it for litehtml: UTF-8, a lone surrogate as U+FFFD, cut at its first NUL. False, with `out`
/// unspecified, when that is longer than `maxBytes`; a UTF-16 length is a lower bound, so a longer string is refused
/// unconverted.
bool renderUtf8AtMost(const String& s, size_t maxBytes, std::string& out);
/// HTML's escaping of text, as the render input carries it (a raw-text parent's text is not escaped).
std::string renderEscapedText(std::string_view utf8);

/// `element`'s attributes as the build reads them, and, when `startTag` is given and the input is kept, its start tag as
/// the render input carries it. `usedBefore` is the budget the rest of the document uses. Charges as the build does.
/// Throws Thrown (a charge) or std::bad_alloc.
RenderAttributes renderElementAttributes(JSContext* ctx, Element& element, size_t usedBefore, bool keepInput,
                                         std::string* startTag);
/// Whether Ruling 4 leaves `element` out of the rendered tree (by its local name): such an element, and its subtree,
/// are never in the build, so a change to them is never rendered. Charges the name.
bool renderElementIsUnrendered(JSContext* ctx, const Element& element);

/// Adds the kinds `container` reported since its beginBuild that `limits` does not have yet, by Ruling 7's names
/// (litehtml's "text" is `text-pieces`, its "table" `table-cells`).
void collectContainerLimits(const WidgetContainer& container, std::vector<std::string>& limits);

/// The master sheet a build is finalized with: litehtml's, then the host's (RenderOptions::hostCSS), as LHDocument's
/// MasterWithCSS joins them. The host's rules are the user agent's, so the author's own win over them; litehtml caches
/// the parsed result by this text.
std::string masterWithHostCSS(const std::string& hostCSS);

} // namespace wr
