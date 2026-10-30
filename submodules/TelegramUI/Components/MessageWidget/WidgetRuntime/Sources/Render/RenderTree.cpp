#include "Sources/Render/RenderTree.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Animation/CSSAnimationRules.h"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <unordered_set>
#include <utility>

#include <litehtml.h>
#include <litehtml/css_parser.h>
#include <litehtml/el_svg.h>

#include "Sources/Canvas/CanvasElement.h"
#include "Sources/Canvas/CanvasState.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/CSSPolicy.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerDiff.h"
#include "Sources/Render/RenderCut.h"
#include "Sources/Render/RenderDump.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Callbacks.h"
#include "Sources/Support/Errors.h"

namespace wr {

namespace {

/// The boot's publish: the root under parent 0, then every node in pre-order, each after its previous sibling.
std::vector<LayerOp> insertsOf(const MirrorNode& root) {
    struct At {
        const MirrorNode* node;
        LayerId parent;
        LayerId after;
    };
    std::vector<LayerOp> ops;
    std::vector<At> stack{{&root, 0, 0}};
    while (!stack.empty()) {
        const At at = stack.back();
        stack.pop_back();
        ops.push_back(LayerOp{LayerOp::Insert, at.node->id, at.parent, at.after});
        for (size_t i = at.node->children.size(); i-- > 0;) {
            stack.push_back({at.node->children[i].get(), at.node->id, i > 0 ? at.node->children[i - 1]->id : 0});
        }
    }
    return ops;
}

} // namespace

RenderTree::RenderTree(JSContext* ctx, RenderHost& host, RenderOptions options)
    : m_ctx(ctx), m_document(Ref<Document>::retain(ctx, &DOMState::of(ctx).document())),
      m_container(host, std::move(options)), m_current(ctx), m_journal(ctx) {
    // Never built: the first flush builds everything (the parser builds with raw edits and tells no listener); the
    // journal records nothing until then.
    m_document->mutationListeners().push_back(this);
    // A canvas's twcanvas: source draws its bitmap's current pixels (V5d plan, Task 4).
    m_container.setCanvasSource([ctx](uint64_t serial) -> std::optional<DecodedImage> {
        HostState* state = HostState::find(ctx);
        return state && state->canvasSlot() ? state->canvasSlot()->snapshot(serial) : std::nullopt;
    });
}

// Unregistered first. Then the members go in reverse: the tree, the journal's nodes, the build (its maps release their
// nodes, then the document its fonts), the container, and the main document's reference.
RenderTree::~RenderTree() {
    auto& listeners = m_document->mutationListeners();
    listeners.erase(std::remove(listeners.begin(), listeners.end(), static_cast<MutationListener*>(this)), listeners.end());
}

std::string RenderTree::layoutDump() const {
    return m_current.document ? dumpLayout(*m_current.document) : std::string();
}

namespace {

/// A path's box from its points and its curves' extrema (never sampled: a rect's box is exact), as the painter's fill box
/// takes it (twidget edit 72).
std::optional<RenderBox> pathBounds(const litehtml::vector_path& path) {
    float box[4];
    if (!litehtml::svg_path_bounds(path, box)) {
        return std::nullopt;
    }
    return RenderBox{box[0], box[1], box[2], box[3]};
}

/// Whether the SVG painter skips `el` (el_svg.cpp's draw_children): display none by CSS or by attribute, and the
/// elements it never draws (defs, symbol, clipPath, mask, pattern, marker, gradients, style, script, …).
bool svgSkipped(const litehtml::element::ptr& el) {
    if (el->is_text() || el->css().get_display() == litehtml::display_none) {
        return true;
    }
    if (const char* display = el->get_attr("display")) {
        std::string v = litehtml::lowcase(display);
        litehtml::trim(v);
        if (v == "none") {
            return true;
        }
    }
    const std::string name = litehtml::lowcase(el->get_tagName() ? el->get_tagName() : "");
    for (const char* never : {"defs", "style", "title", "desc", "lineargradient", "radialgradient", "clippath", "mask",
                              "pattern", "symbol", "marker", "filter", "script", "metadata"}) {
        if (name == never) {
            return true;
        }
    }
    return false;
}

/// Whether `el` or an ancestor up to its <svg> is skipped: what is not drawn has no geometry (V3b review I2).
bool svgHidden(const litehtml::element::ptr& el) {
    for (litehtml::element::ptr p = el; p; p = p->parent()) {
        if (dynamic_cast<litehtml::el_svg*>(p.get())) {
            return false;
        }
        if (svgSkipped(p)) {
            return true;
        }
    }
    return false;
}

/// The user-unit box of an SVG element: its own path's, else the union of the shapes it holds that are drawn; nullopt
/// when it is not drawn itself. An explicit stack, as every walk over a tree is.
std::optional<RenderBox> userBounds(const litehtml::element::ptr& root) {
    std::optional<RenderBox> out;
    if (svgHidden(root)) {
        return out;
    }
    std::vector<litehtml::element::ptr> pending{root};
    while (!pending.empty()) {
        litehtml::element::ptr el = pending.back();
        pending.pop_back();
        if (el != root && svgSkipped(el)) {
            continue;
        }
        litehtml::vector_path path;
        if (litehtml::svg_geometry(el, path)) {
            if (std::optional<RenderBox> box = pathBounds(path)) {
                RenderBox both = *box;
                if (out) {
                    unionOfRects({*out, *box}, both);
                }
                out = both;
            }
            continue;
        }
        for (const litehtml::element::ptr& child : el->children()) {
            pending.push_back(child);
        }
    }
    return out;
}

/// The numbers of an SVG list attribute (viewBox), separated by whitespace or commas.
std::vector<double> listNumbers(const char* text) {
    std::vector<double> out;
    if (!text) {
        return out;
    }
    const char* p = text;
    while (*p) {
        while (*p == ' ' || *p == ',' || *p == '\t' || *p == '\n' || *p == '\r') {
            p++;
        }
        if (!*p) {
            break;
        }
        char* end = nullptr;
        const double value = std::strtod(p, &end);
        if (end == p) {
            break;
        }
        out.push_back(value);
        p = end;
    }
    return out;
}

/// A shape's client box: an element inside an <svg> has no CSS box, so its user-unit box is mapped through its own
/// transform and its ancestors' up to the <svg> (as the painter draws it: twidget edit 72's svg_element_transform), then
/// into the <svg>'s content box through the viewBox (preserveAspectRatio's default, xMidYMid meet). A group's shapes'
/// own transforms are not applied. nullopt outside an <svg> or with nothing drawn.
std::optional<RenderBox> svgClientBox(const litehtml::element::ptr& el) {
    litehtml::element::ptr svg;
    for (litehtml::element::ptr p = el->parent(); p; p = p->parent()) {
        if (dynamic_cast<litehtml::el_svg*>(p.get())) {
            svg = p;
            break;
        }
    }
    if (!svg) {
        return std::nullopt;
    }
    std::optional<RenderBox> user = userBounds(el);
    RenderBox frame;
    if (!user || !elementBorderBox(*svg, frame)) {
        return std::nullopt;
    }
    litehtml::transform_matrix total;
    for (litehtml::element::ptr p = el; p && p != svg; p = p->parent()) {
        total = total.then(litehtml::svg_element_transform(p));
    }
    if (!total.is_identity()) {
        double left = 0, top = 0, right = 0, bottom = 0;
        bool first = true;
        for (const auto& [x, y] : {std::pair{user->x, user->y}, std::pair{user->x + user->width, user->y},
                                   std::pair{user->x, user->y + user->height},
                                   std::pair{user->x + user->width, user->y + user->height}}) {
            const double mx = total.a * x + total.c * y + total.tx;
            const double my = total.b * x + total.d * y + total.ty;
            left = first ? mx : std::min(left, mx);
            right = first ? mx : std::max(right, mx);
            top = first ? my : std::min(top, my);
            bottom = first ? my : std::max(bottom, my);
            first = false;
        }
        user = RenderBox{left, top, right - left, bottom - top};
    }
    double left = frame.x, top = frame.y, width = frame.width, height = frame.height;
    if (std::shared_ptr<litehtml::render_item> ri = svg->get_render_item()) {
        const double l = double(ri->border_left().value() + ri->padding_left().value());
        const double t = double(ri->border_top().value() + ri->padding_top().value());
        const double r = double(ri->border_right().value() + ri->padding_right().value());
        const double b = double(ri->border_bottom().value() + ri->padding_bottom().value());
        left += l;
        top += t;
        width = std::max(0.0, width - l - r);
        height = std::max(0.0, height - t - b);
    }
    double scale = 1, x = left, y = top;
    // The fork keeps attribute names as litehtml lowercases them.
    const char* viewBox = svg->get_attr("viewbox");
    const std::vector<double> view = listNumbers(viewBox ? viewBox : svg->get_attr("viewBox"));
    if (view.size() == 4 && view[2] > 0 && view[3] > 0) {
        scale = std::min(width / view[2], height / view[3]);
        x = left + (width - view[2] * scale) / 2 - view[0] * scale;
        y = top + (height - view[3] * scale) / 2 - view[1] * scale;
    }
    return RenderBox{x + user->x * scale, y + user->y * scale, user->width * scale, user->height * scale};
}

} // namespace

std::vector<RenderBox> RenderTree::clientRects(const Node& node) const {
    if (!m_current.document) {
        return {};
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element) {
        return {};
    }
    std::vector<RenderBox> rects = elementClientRects(*it->second.element);
    if (rects.empty()) {
        if (std::optional<RenderBox> box = svgClientBox(it->second.element)) {
            rects.push_back(*box);
        }
    }
    return rects;
}

std::vector<RenderBox> RenderTree::visualRects(const Node& node, std::vector<RenderBox> rects) const {
    if (!m_current.document) {
        return rects;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it != m_current.nodes.end() && it->second.element) {
        transformRects(*it->second.element, rects);
    }
    return rects;
}

std::optional<RenderBox> RenderTree::visualBox(const Node& node, std::optional<RenderBox> box) const {
    if (!box) {
        return box;
    }
    return visualRects(node, {*box}).front();
}

std::optional<RenderBox> RenderTree::visualBorderBox(const Node& node) const {
    RenderBox box;
    if (!unionOfRects(visualRects(node, clientRects(node)), box)) {
        return std::nullopt;
    }
    return box;
}

std::optional<RenderBox> RenderTree::borderBox(const Node& node) const {
    if (!m_current.document) {
        return std::nullopt;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element) {
        return std::nullopt;
    }
    RenderBox box;
    if (!elementBorderBox(*it->second.element, box)) {
        return svgClientBox(it->second.element);
    }
    return box;
}

bool RenderTree::beingRendered(const Node& node) const {
    if (!m_current.document) {
        return false;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element) {
        return false;
    }
    for (litehtml::element::ptr element = it->second.element; element; element = element->parent()) {
        if (element->css().get_display() == litehtml::display_none) {
            return false;
        }
    }
    return true;
}

std::optional<RenderTree::BoxMetrics> RenderTree::boxMetrics(const Node& node) const {
    if (!m_current.document) {
        return std::nullopt;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element) {
        return std::nullopt;
    }
    const litehtml::element& element = *it->second.element;
    std::shared_ptr<litehtml::render_item> box = const_cast<litehtml::element&>(element).get_render_item();
    if (!box) {
        return std::nullopt;
    }
    BoxMetrics metrics;
    metrics.borderTop = double(box->border_top().value());
    metrics.borderRight = double(box->border_right().value());
    metrics.borderBottom = double(box->border_bottom().value());
    metrics.borderLeft = double(box->border_left().value());
    metrics.paddingTop = double(box->padding_top().value());
    metrics.paddingRight = double(box->padding_right().value());
    metrics.paddingBottom = double(box->padding_bottom().value());
    metrics.paddingLeft = double(box->padding_left().value());
    const litehtml::element_position position = element.css().get_position();
    metrics.positioned = position != litehtml::element_position_static;
    metrics.fixed = position == litehtml::element_position_fixed;
    const litehtml::style_display display = element.css().get_display();
    metrics.inlineLevel = display == litehtml::display_inline || display == litehtml::display_inline_text;
    metrics.autoWidth = element.css().get_width().is_predefined();
    metrics.autoHeight = element.css().get_height().is_predefined();
    return metrics;
}

std::optional<RenderBox> RenderTree::overflowClip(const Node& node) const {
    if (!m_current.document) {
        return std::nullopt;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element || !it->second.element->css().clips_contents()) {
        return std::nullopt;
    }
    std::optional<BoxMetrics> metrics = this->boxMetrics(node);
    std::optional<RenderBox> box = this->borderBox(node);
    if (!metrics || !box) {
        return std::nullopt;
    }
    return RenderBox{box->x + metrics->borderLeft, box->y + metrics->borderTop,
                     std::max(0.0, box->width - metrics->borderLeft - metrics->borderRight),
                     std::max(0.0, box->height - metrics->borderTop - metrics->borderBottom)};
}

std::optional<RenderBox> RenderTree::svgBBox(const Node& node) const {
    if (!m_current.document) {
        return std::nullopt;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element) {
        return std::nullopt;
    }
    return userBounds(it->second.element);
}

std::string RenderTree::declaredValue(const Node& node, const std::string& property) const {
    auto it = m_current.document ? m_current.nodes.find(const_cast<Node*>(&node)) : m_current.nodes.end();
    if (it == m_current.nodes.end() || !it->second.element) {
        return {};
    }
    auto tag = std::dynamic_pointer_cast<litehtml::html_tag>(it->second.element);
    return tag ? tag->raw_declaration(property) : std::string();
}

std::optional<double> RenderTree::svgPathLength(const Node& node) const {
    auto it = m_current.document ? m_current.nodes.find(const_cast<Node*>(&node)) : m_current.nodes.end();
    litehtml::vector_path path;
    if (it == m_current.nodes.end() || !it->second.element || !litehtml::svg_geometry(it->second.element, path)) {
        return std::nullopt;
    }
    return double(litehtml::svg_path_length(path, -1, nullptr, nullptr));
}

std::optional<std::pair<double, double>> RenderTree::svgPointAtLength(const Node& node, double distance) const {
    auto it = m_current.document ? m_current.nodes.find(const_cast<Node*>(&node)) : m_current.nodes.end();
    litehtml::vector_path path;
    if (it == m_current.nodes.end() || !it->second.element || !litehtml::svg_geometry(it->second.element, path)) {
        return std::nullopt;
    }
    const float total = litehtml::svg_path_length(path, -1, nullptr, nullptr);
    float x = 0, y = 0;
    litehtml::svg_path_length(path, float(std::clamp(distance, 0.0, double(total))), &x, &y);
    return std::make_pair(double(x), double(y));
}

std::optional<double> RenderTree::svgTextLength(const Node& node) {
    auto it = m_current.document ? m_current.nodes.find(const_cast<Node*>(&node)) : m_current.nodes.end();
    if (it == m_current.nodes.end() || !it->second.element) {
        return std::nullopt;
    }
    const litehtml::element::ptr& el = it->second.element;
    std::string text;
    el->get_text(text);
    // litehtml computes the font from the presentation attributes (font-size, font-family) as from CSS.
    return double(m_container.text_width(text.c_str(), el->css().get_font()).value());
}

uint64_t RenderTree::svgTextUnits(const Node& node) const {
    auto it = m_current.document ? m_current.nodes.find(const_cast<Node*>(&node)) : m_current.nodes.end();
    if (it == m_current.nodes.end() || !it->second.element) {
        return 0;
    }
    std::string text;
    it->second.element->get_text(text);
    uint64_t units = 0;
    for (unsigned char c : text) {
        if ((c & 0xC0) != 0x80) {
            units += c >= 0xF0 ? 2 : 1;
        }
    }
    return units;
}

// Called where a publish installs its rects. Nothing throws: when the union cannot grow, it becomes everything.
void RenderTree::accumulateChangedRects() noexcept {
    if (!m_changedRects || !m_accumulatedRects) {
        m_accumulatedRects.reset();
        return;
    }
    try {
        m_accumulatedRects->insert(m_accumulatedRects->end(), m_changedRects->begin(), m_changedRects->end());
    } catch (...) {
        m_accumulatedRects.reset();
    }
}

std::optional<std::vector<litehtml::position>> RenderTree::takeChangedRects() {
    std::optional<std::vector<litehtml::position>> taken;
    taken.swap(m_accumulatedRects);
    m_accumulatedRects.emplace();
    return taken;
}

std::optional<std::string> RenderTree::computedStyleValue(const Node& node, std::string_view name, PseudoElement pseudo) const {
    if (!m_current.document) {
        return std::nullopt;
    }
    auto it = m_current.nodes.find(const_cast<Node*>(&node));
    if (it == m_current.nodes.end() || !it->second.element) {
        return std::nullopt;
    }
    return computedValue(*it->second.element, name, pseudo);
}

bool RenderTree::matchesMedia(JSContext* ctx, const std::string& query, bool atLastReport) const {
    if (!m_current.document) {
        return false;
    }
    // V4 plan, Task 3b: a query outside the profile's media types and features is false, as its @media rule is dropped:
    // one walker for both (CSSPolicy.h).
    if (!css::policy::mediaQueryInProfile(litehtml::normalize(query, litehtml::f_componentize))) {
        return false;
    }
    litehtml::media_features features;
    if (atLastReport) {
        features = m_reportedMedia;
    } else {
        m_container.get_media_features(features);
    }
    return litehtml::parse_media_query_list(query, m_current.document).check(features);
}

void RenderTree::noteMediaReported() {
    m_container.get_media_features(m_reportedMedia);
    m_mediaReports++;
}

double RenderTree::layoutWidth() const {
    return m_tree ? m_tree->width() : 0.0;
}

double RenderTree::documentHeight() const {
    std::optional<ContentSize> size = this->contentSize();
    return size ? size->height : 0.0;
}

Node* RenderTree::nodeAt(double x, double y) const {
    if (!m_current.document) {
        return nullptr;
    }
    for (litehtml::element::ptr el = hitElement(*m_current.document, x, y); el; el = el->parent()) {
        auto it = m_current.elements.find(el.get());
        if (it == m_current.elements.end()) {
            continue;
        }
        Node* node = it->second;
        return node->isElement() ? node : node->parentElementNode();
    }
    return m_document->documentElementNode();
}

namespace {

// litehtml's pixel_snap_scale() for the duration of a build, a patch or a record (RenderOptions::pixelSnapScale), put
// back as it was found: it is a thread-local the shipped renderer sets per draw too.
struct SnapScope {
    float saved;
    explicit SnapScope(double scale) : saved(litehtml::pixel_snap_scale()) {
        litehtml::pixel_snap_scale() = scale > 0 ? float(scale) : 1.0f;
    }
    ~SnapScope() { litehtml::pixel_snap_scale() = saved; }
    SnapScope(const SnapScope&) = delete;
    SnapScope& operator=(const SnapScope&) = delete;
};

} // namespace

void RenderTree::build(JSContext* ctx) {
    if (m_buildCount > 0) {
        throw std::logic_error("the render tree builds once, at the boot");
    }
    SnapScope snap(m_container.options().pixelSnapScale);
    Runtime& runtime = Runtime::from(ctx);
    // Our renderer's time is not the widget's slice (the CPU-clock limits plan, Task 2).
    Runtime::RenderScope renderScope(runtime, false);
    // Stops are final.
    if (runtime.stopReason() != StopReason::None) {
        throw Aborted{};
    }
    // A build inside a build would open a second build window on the container (a host calling back).
    if (m_flushing) {
        return;
    }
    m_flushing = true;
    struct Flushing {
        bool& flag;
        ~Flushing() { flag = false; }
    } flushing{m_flushing};
    // Everything is made aside, then swapped in: an exception here drops `next` and `tree` and leaves the published
    // state as it was.
    std::optional<RenderBuild> next;
    std::shared_ptr<const LayerTree> tree;
    std::optional<std::vector<litehtml::position>> changed;
    // Declared after `next`: after the swap it holds the previous mirror, which goes before its document.
    std::unique_ptr<LayerMirror> mirror;
    std::vector<LayerOp> ops;
    try {
        next.emplace(ctx);
        // Ruling E19: litehtml's own step budget cuts the boot.
        next->mayCutSteps = m_container.options().selectorStepCut;
        buildDocument(ctx, m_container, *next);
        next->naturalWidth =
            double(next->document->render(litehtml::pixel_t(float(m_container.options().width))).value());
        // Task 10b: the new document's mirror, keyed from the new build's maps (with the previous keys carried over).
        {
            struct Keys {
                RenderBuild*& build;
                ~Keys() { build = nullptr; }
            } keys{m_keyBuild};
            m_keyBuild = &*next;
            mirror = newMirror();
            tree = mirror->build(*next->document, m_container);
        }
        ops = insertsOf(*tree->mirror());
        // After layout and recording, which ask for fonts and images first (Ruling E10): the container's caches cut to
        // what the new document names.
        m_container.prune(*next->document);
        collectContainerLimits(m_container, next->limits);
        changed = wr::changedRects(m_tree.get(), *tree);
    } catch (...) {
        abortForCaughtException(ctx);
    }
    // Publish: nothing below throws. The build read the DOM as it is, so the journal has nothing left to say.
    m_current.swap(*next);
    m_tree.swap(tree);
    m_changedRects.swap(changed);
    this->accumulateChangedRects();
    m_mirror.swap(mirror);
    m_layerOps.swap(ops);
    m_mirrorWalks++;
    m_buildCount++;
    m_journal.markBuilt();
    m_unheardNodes = 0;
    for (const std::string& kind : m_current.limits) {
        runtime.host().diagnostic("render-limit", kind);
    }
    // `next` now holds the previous build: its document and maps go here, its tree with the last reference to it.
}

void RenderTree::flush(JSContext* ctx) {
    if (m_flushing || m_styleStepRunning || Runtime::from(ctx).stopReason() != StopReason::None) {
        return;
    }
    // Our renderer's time is not the widget's slice (the CPU-clock limits plan, Task 2).
    Runtime::RenderScope renderScope(Runtime::from(ctx), false);
    // The stress kit's renderer time (Runtime::flushMilliseconds): statistics only, on the host's clock.
    struct Timed {
        Runtime& runtime;
        const double started;
        ~Timed() { runtime.addFlushMilliseconds(runtime.host().monotonicNow() - started); }
    } timed{Runtime::from(ctx), Runtime::from(ctx).host().monotonicNow()};
    // At most two passes (V5f plan, Task 2): the second publishes what the first's style-change step started or
    // changed. Its declared values cannot change (animated values are never declarations), so it starts nothing.
    for (int pass = 0; pass < 2; pass++) {
        // Animated elements whose declarations changed join the journal first (V5e plan, Task 6), so a layout query sees
        // a seek made in the same task.
        if (animation::AnimationState* animations = animation::AnimationState::find(ctx)) {
            animations->collectRenderChanges(ctx, *this);
        }
        if (!m_journal.dirty() && m_paintedCanvases.empty()) {
            break;
        }
        animation::StyleChange change;
        if (pass == 0) {
            // Read before anything is published: a failure here leaves the published state as it was.
            try {
                change = this->pendingStyleChange(ctx);
            } catch (...) {
                abortForCaughtException(ctx);
            }
        }
        // A build restyles every element, so after one the step looks at all of them; but only when this flush changed
        // something the step reads.
        bool restyles = change.all || change.removed || !change.elements.empty();
        // A tap's :hover and :active are no declaration the step reads, but what they restyle is.
        const bool stateChanged = (m_journal.kinds() & journalBit(JournalKind::State)) != 0;
        const uint64_t builds = m_buildCount;
        this->publishJournal(ctx);
        if (m_buildCount != builds && (restyles || stateChanged)) {
            change.all = true;
            change.elements.clear();
            restyles = true;
        } else if (m_buildCount == builds && m_current.document) {
            // A patch restyled what its changes reach (twidget edits 75 and 77), which the step looks at as at what a
            // build styled, when the flush changed something it reads (an animated frame changes no declaration).
            std::vector<litehtml::element::ptr> restyled = m_current.document->take_restyled();
            if (pass == 0 && (restyles || stateChanged)) {
                try {
                    this->noteRestyled(ctx, restyled, change);
                } catch (...) {
                    abortForCaughtException(ctx);
                }
                restyles = change.all || change.removed || !change.elements.empty();
            }
        }
        if (pass == 0 && restyles && Runtime::from(ctx).stopReason() == StopReason::None) {
            struct Running {
                bool& flag;
                ~Running() { flag = false; }
            } running{m_styleStepRunning};
            m_styleStepRunning = true;
            // The step settles animations' promises, which reads a `then` the widget may define: that script is the
            // widget's, in the slice (the final review's C1).
            Runtime::ScriptScope script(Runtime::from(ctx));
            animation::AnimationState::of(ctx).stylesResolved(ctx, *this, change);
        }
    }
    m_domAttributeChanges.clear();
}

void RenderTree::noteRestyled(JSContext* ctx, const std::vector<litehtml::element::ptr>& restyled,
                              animation::StyleChange& change) {
    std::unordered_set<const Element*> seen;
    for (const Ref<Element>& element : change.elements) {
        seen.insert(element.get());
    }
    std::vector<const litehtml::element*> stack;
    for (const litehtml::element::ptr& top : restyled) {
        stack.push_back(top.get());
    }
    std::unordered_set<const litehtml::element*> walked;
    while (!stack.empty()) {
        const litehtml::element* el = stack.back();
        stack.pop_back();
        if (!walked.insert(el).second) {
            continue;
        }
        auto found = m_current.elements.find(el);
        if (found != m_current.elements.end() && found->second->isElement()) {
            Element* element = static_cast<Element*>(found->second);
            if (seen.insert(element).second) {
                change.elements.push_back(Ref<Element>::retain(ctx, element));
            }
        }
        for (const litehtml::element::ptr& child : el->children()) {
            stack.push_back(child.get());
        }
    }
}

animation::StyleChange RenderTree::pendingStyleChange(JSContext* ctx) {
    animation::StyleChange change;
    // An environment change (twidget edit 79) can change any element's declarations, as a build does.
    if (!m_journal.built() || m_journal.environmentPending()) {
        change.all = true;
        return change;
    }
    std::unordered_set<const Element*> seen;
    for (const JournalEntry& entry : m_journal.entries()) {
        Node& node = *entry.node;
        if (node.type() != NodeType::Element) {
            continue;
        }
        Element& element = static_cast<Element&>(node);
        if ((entry.kinds & journalBit(JournalKind::Attribute)) && m_domAttributeChanges.count(&element) && seen.insert(&element).second) {
            change.elements.push_back(Ref<Element>::retain(ctx, &element));
            // The before-change style a transition starts from (V5f plan, Task 5), while the tree still has it.
            animation::DeclaredValues before;
            const animation::DeclaredLookup declared = [&](std::string_view property) {
                return this->declaredValue(element, std::string(property));
            };
            for (std::string_view property : animation::kWatchedProperties) {
                std::string value = animation::watchedValue(declared, property);
                if (!value.empty()) {
                    before.emplace_back(std::string(property), std::move(value));
                }
            }
            change.before.emplace_back(&element, std::move(before));
        }
        if (entry.kinds & journalBit(JournalKind::Removed)) {
            change.removed = true;
        }
        if (entry.kinds & journalBit(JournalKind::Inserted)) {
            // Every element of an inserted subtree has its first style.
            std::vector<Node*> stack{&element};
            while (!stack.empty()) {
                Node* current = stack.back();
                stack.pop_back();
                if (current->type() != NodeType::Element) {
                    continue;
                }
                Element* e = static_cast<Element*>(current);
                if (seen.insert(e).second) {
                    change.elements.push_back(Ref<Element>::retain(ctx, e));
                }
                for (size_t i = e->childCount(); i > 0; i--) {
                    stack.push_back(e->childAt(i - 1));
                }
            }
        }
    }
    // A sheet change (twidget edit 81) can change any element's declarations, and the `@keyframes`, as a build does.
    if (this->journalTouchesSheets(ctx, true)) {
        change.all = true;
    }
    return change;
}

void RenderTree::publishJournal(JSContext* ctx) {
    SnapScope snap(m_container.options().pixelSnapScale);
    struct Repainted {
        RenderTree& tree;
        ~Repainted() {
            tree.m_paintedCanvasSet.clear();
            tree.m_paintedCanvases.clear();
        }
    } repainted{*this};
    if (!m_journal.dirty()) {
        this->publishRepaints(ctx);
        return;
    }
    // The boot's build; every later flush patches.
    if (!m_journal.built()) {
        this->build(ctx);
        return;
    }
    if (m_flushProbe) {
        m_flushProbe->beforeFlush(*this);
    }
    // A journal with a structural entry goes to the structure path (Task 9), any other to the text and attribute path
    // (Tasks 7 and 8).
    constexpr JournalKinds kStructural = journalBit(JournalKind::Inserted) | journalBit(JournalKind::Removed) |
                                         journalBit(JournalKind::Children);
    // A journal that changes a <style>'s Text or attributes goes there too: its sheet is the structure path's (twidget
    // edit 81).
    std::unordered_map<Node*, Node*> swaps;
    PatchResult result;
    // A published build whose walk hit a limit, or a change no entry holds that moved a cut: the flush walks the cut as a
    // build walks it (RenderCut.h). Otherwise the plan counts with the rest of the document's sums, and a cap it would
    // cross walks the cut instead.
    if (m_journal.cutPending() || m_current.walkLimits > 0) {
        result = this->flushStructure(ctx, true);
    } else {
        const bool structural = (m_journal.kinds() & kStructural) != 0 && !this->textSwaps(ctx, swaps);
        const bool structure = structural || this->journalTouchesSheets(ctx, false);
        result = structure ? this->flushStructure(ctx) : this->flushPatch(ctx, swaps);
        // A faster path that cannot patch hands the change on, its published state untouched: the text and attribute
        // path to the structure path, which handles every change, and that to its walk of the cut, which plans as a build
        // walks the DOM.
        if (result == PatchResult::Refused && !structure) {
            result = this->flushStructure(ctx);
        }
        if (result == PatchResult::Refused) {
            result = this->flushStructure(ctx, true);
        }
    }
    if (result == PatchResult::Patched) {
        if (m_flushProbe) {
            m_flushProbe->afterPublish(*this);
        }
        return;
    }
    // Refused walking the cut: the runtime planned what it never asks of the fork, an inconsistency.
    std::string why = m_refusal;
    if (*m_refusalReason) {
        why += std::string(": ") + m_refusalReason;
    }
    this->stopInternally(ctx, why.c_str());
}

// A bitmap's pixels change no box, so nothing is laid out: the mirror captures each painted canvas's box again.
void RenderTree::publishRepaints(JSContext* ctx) {
    if (!m_current.document || m_flushing) {
        return;
    }
    m_flushing = true;
    struct Flushing {
        bool& flag;
        ~Flushing() { flag = false; }
    } flushing{m_flushing};
    MirrorPublish published;
    try {
        this->reportRepaints();
        published = publishPatch();
    } catch (const LayerMirror::Inconsistent& inconsistent) {
        this->stopInternally(ctx, inconsistent.what());
    } catch (...) {
        abortForCaughtException(ctx);
    }
    installPatch(published);
}

void RenderTree::reportRepaints() noexcept {
    if (!m_mirror) {
        return;
    }
    for (const Ref<Element>& canvas : m_paintedCanvases) {
        auto found = m_current.nodes.find(canvas.get());
        if (found != m_current.nodes.end() && found->second.element) {
            m_mirror->element_restyled(found->second.element.get(), false);
        }
    }
}

namespace {

struct TextPlan {
    Node* node = nullptr;
    RenderEntry* entry = nullptr;
    /// A Text swap's old Text, whose entry (`entry`) the new one (`node`) takes over at the commit.
    Node* replaced = nullptr;
    litehtml::element::ptr parent;
    std::string utf8;
    /// The text as the render input carries it; only when the options keep it.
    std::string escaped;
    size_t oldCount = 0;
    size_t newCount = 0;
    /// The data's text units (RenderEntry::units).
    TextUnits units;
    /// replace_text's output: reserved, so the litehtml phase allocates nothing of ours.
    std::vector<litehtml::element::ptr> pieces;
};

/// The rendered elements' :hover and :active as the user-action state now has them, where they differ from litehtml's
/// (twidget edit 75): set_pseudo_classes flips them together and matches `reach` again, each element once.
struct StatePlan {
    std::vector<litehtml::document::pseudo_flip> flips;
    std::vector<litehtml::element::ptr> reach;
};

// The user-action state the DOM now gives a rendered element against litehtml's: a flip where they differ.
void planUserActionState(JSContext* ctx, Element& element, const litehtml::element::ptr& rendered, StatePlan& plan) {
    ElementState* state = DOMState::of(ctx).elementState();
    std::vector<std::pair<litehtml::string_id, bool>> states;
    const std::pair<litehtml::string_id, bool> wanted[] = {{litehtml::_hover_, state->hovered(ctx, element)},
                                                            {litehtml::_active_, state->active(ctx, element)}};
    for (const auto& [name, on] : wanted) {
        if (rendered->has_pseudo_class(name) != on) {
            states.emplace_back(name, on);
        }
    }
    if (!states.empty()) {
        plan.flips.emplace_back(rendered, std::move(states));
    }
}

// The flips' predicate and reach, one walk for all of them (a tap's chain nests). False: the fork refuses them.
bool planStateReach(litehtml::document& document, StatePlan& plan) {
    if (plan.flips.empty()) {
        return true;
    }
    const bool allowed = document.can_set_pseudo_classes(plan.flips);
    if (allowed) {
        plan.reach = document.pseudo_reach(plan.flips);
    }
    return allowed;
}

struct AttributePlan {
    RenderEntry* entry = nullptr;
    litehtml::element::ptr element;
    /// All of the element's attributes as the DOM now holds them, lowercased (document::set_element_attributes).
    litehtml::string_map wanted;
    /// Whether they differ from litehtml's (list_index aside): the element is re-matched once, else not at all.
    bool changed = false;
    /// The budget the element's attributes use now (RenderEntry::bytes), and their text units (RenderEntry::units).
    size_t bytes = 0;
    TextUnits units;
    /// Its start tag as the render input carries it; only when the options keep it.
    std::string startTag;
};

/// A replacement in the render input: [offset, offset + length) becomes *text.
struct InputPatch {
    size_t offset;
    uint32_t seq;
    size_t length;
    const std::string* text;
    /// The replacement's length minus the old one.
    ptrdiff_t delta;
};

/// Ruling E19: a patch's selector-step session, opened before its first litehtml change and closed after its commit, or
/// on the way out of a failure, so no session outlives the flush.
class StepSession {
public:
    /// `used` gets the steps the session used when it closes, here or on the way out of a failure.
    StepSession(litehtml::document& document, int64_t limit, int64_t& used) : m_document(document), m_used(used) {
        document.begin_selector_steps(limit);
    }
    ~StepSession() {
        if (m_open) {
            m_used = m_document.end_selector_steps();
        }
    }
    StepSession(const StepSession&) = delete;
    StepSession& operator=(const StepSession&) = delete;
    /// The steps the session used.
    int64_t close() {
        m_open = false;
        m_used = m_document.end_selector_steps();
        return m_used;
    }

private:
    litehtml::document& m_document;
    int64_t& m_used;
    bool m_open = true;
};

/// Whether `node` is in the tree whose root is `document`.
bool inDocument(Node& node, const Node* document) {
    for (Node* at = &node; at; at = at->parent()) {
        if (!at->parent()) {
            return at == document;
        }
    }
    return false;
}

/// The nodes of `root`'s inclusive subtree a build counts against kMaxRenderNodes (Builder.cpp's countNodes and
/// countUnbuilt): all but a `<script>`'s descendants.
size_t nodesForTheCap(JSContext* ctx, Node& root) {
    const JSAtom script = DOMState::of(ctx).name(Name::script);
    auto isScript = [&](Node& n) { return n.isElement() && static_cast<Element&>(n).hasHTMLName(script); };
    size_t count = 0;
    for (Node* node = &root; node;) {
        count++;
        node = node->firstChildNode() && !isScript(*node) ? node->nextInTreeOrder(&root) : node->nextSkippingChildren(&root);
    }
    return count;
}

size_t childIndex(const litehtml::element::ptr& parent, const litehtml::element* child) {
    size_t index = 0;
    for (const litehtml::element::ptr& candidate : parent->children()) {
        if (candidate.get() == child) {
            return index;
        }
        index++;
    }
    return ~size_t(0);
}

} // namespace

bool RenderTree::textSwaps(JSContext* ctx, std::unordered_map<Node*, Node*>& swaps) {
    constexpr JournalKinds kStructural = journalBit(JournalKind::Inserted) | journalBit(JournalKind::Removed) |
                                         journalBit(JournalKind::Children);
    if (!m_journal.built() || !m_current.document) {
        return false;
    }
    std::unordered_map<Node*, Node*> inserted;   // parent → its new Text
    std::unordered_map<Node*, Node*> removed;    // parent → the Text that went
    std::unordered_set<Node*> dirty;
    for (const JournalEntry& journaled : m_journal.entries()) {
        const JournalKinds kinds = journaled.kinds & kStructural;
        Node* node = journaled.node.get();
        if (kinds == 0) {
            continue;
        }
        if (kinds == journalBit(JournalKind::Children)) {
            dirty.insert(node);
            continue;
        }
        if (node->type() != NodeType::Text) {
            return false;
        }
        if (kinds == journalBit(JournalKind::Inserted)) {
            Node* parent = node->parent();
            if (!parent || !parent->isElement() || parent->childCount() != 1 || !inserted.emplace(parent, node).second) {
                return false;
            }
            continue;
        }
        if (kinds != journalBit(JournalKind::Removed)) {
            return false;
        }
        // Where its pieces were: the parent element's litehtml element, mapped back to the DOM.
        auto found = m_current.nodes.find(node);
        if (found == m_current.nodes.end() || found->second.pieces.empty() || !found->second.pieces[0]->parent()) {
            return false;
        }
        auto parent = m_current.elements.find(found->second.pieces[0]->parent().get());
        if (parent == m_current.elements.end() || !removed.emplace(parent->second, node).second) {
            return false;
        }
    }
    if (dirty.empty() || dirty.size() != inserted.size() || dirty.size() != removed.size()) {
        return false;
    }
    for (Node* parent : dirty) {
        auto in = inserted.find(parent);
        auto out = removed.find(parent);
        auto entry = m_current.nodes.find(parent);
        // The root element's text is the document's own structure.
        if (in == inserted.end() || out == removed.end() || entry == m_current.nodes.end() || !entry->second.element ||
            !entry->second.element->parent()) {
            return false;
        }
        swaps.emplace(in->second, out->second);
    }
    return true;
}

RenderTree::PatchResult RenderTree::flushPatch(JSContext* ctx, const std::unordered_map<Node*, Node*>& swaps) {
    constexpr JournalKinds kPatchable =
        journalBit(JournalKind::Text) | journalBit(JournalKind::Attribute) | journalBit(JournalKind::State);
    if (!m_journal.built() || ((m_journal.kinds() & ~kPatchable) != 0 && swaps.empty()) || !m_current.document ||
        m_flushing) {
        return this->refused("a structural journal, or no build");
    }
    m_flushing = true;
    struct Flushing {
        bool& flag;
        ~Flushing() { flag = false; }
    } flushing{m_flushing};
    litehtml::document& document = *m_current.document;
    JSRuntime* rt = JS_GetRuntime(ctx);
    const bool keepInput = m_container.options().keepRenderInput;

    std::vector<TextPlan> plans;
    std::vector<AttributePlan> attributePlans;
    StatePlan statePlan;
    std::vector<InputPatch> patches;
    // The swapped Texts' old roots: released when the flush returns, never inside the commit.
    std::vector<Ref<Node>> retired;
    RenderString newInput{JSAllocator<char>(rt)};
    std::vector<RenderElementMap::node_type> pool;
    int64_t stepLimit = 0;
    // The session's limit and the steps it performed.
    int64_t sessionLimit = 0;
    int64_t sessionUsed = 0;
    uint64_t boxes = m_current.boxes;
    uint64_t bytes = m_current.bytes;
    TextUnits units = m_current.textUnits;
    // ---- Planning: nothing of litehtml's or of the published build's is touched. ----
    try {
        const Vector<JournalEntry>& entries = m_journal.entries();
        plans.reserve(entries.size());
        attributePlans.reserve(entries.size());
        int pendingGrowth = 0;
        litehtml::document::attribute_growth attributeGrowth;
        size_t surplus = 0;
        size_t replaced = 0;
        for (const JournalEntry& journaled : entries) {
            Node& node = *journaled.node;
            // A Text swap (textSwaps): its parent's child-list change and the old Text's removal are the new Text's plan.
            if ((journaled.kinds & journalBit(JournalKind::Removed)) ||
                (journaled.kinds & ~journalBit(JournalKind::Children)) == 0) {
                continue;
            }
            if (node.isElement() && (journaled.kinds & journalBit(JournalKind::State))) {
                // A user-action state change (twidget edit 75): an element no build renders draws nothing either way.
                auto found = m_current.nodes.find(&node);
                if (found != m_current.nodes.end() && found->second.element) {
                    planUserActionState(ctx, static_cast<Element&>(node), found->second.element, statePlan);
                }
            }
            if (node.isElement() && !(journaled.kinds & journalBit(JournalKind::Attribute))) {
                continue;
            }
            if (node.isElement()) {
                // An attribute change (a mixed entry cannot be: an element has no data and a Text node no attributes).
                Element& element = static_cast<Element&>(node);
                auto found = m_current.nodes.find(&node);
                if (found == m_current.nodes.end()) {
                    // Not in the build. An element Ruling 4 leaves out (a <script>, a <template>, ...), or one its
                    // parent's own append refuses (twidget edit 83), is never in a build, whatever its attributes say, so
                    // its change renders nothing; any other missing element was left out by something else (a limit, a
                    // <style>'s children), which a change may undo: the next path's.
                    if (!this->readByABuild(ctx, element)) {
                        continue;
                    }
                    return this->refused("an unmapped element");
                }
                RenderEntry& entry = found->second;
                auto* tag = dynamic_cast<litehtml::html_tag*>(entry.element.get());
                if (!tag) {
                    return this->refused("not an html_tag");
                }
                // The tag the build made it with must still be the profile's answer (V4 plan, Task 4).
                if (litehtml::lowcase(renderTagOf(ctx, element).tag) != litehtml::lowcase(tag->get_tagName())) {
                    return this->refused("the rendered tag changed");
                }
                // The budget the other nodes leave this element (Ruling 7): a fresh build cuts at it.
                const uint64_t others = bytes - entry.bytes;
                // And the text units (V4 plan, Task 7): a fresh build counts them in tree order, so a value that does not
                // fit beside the others is one the build leaves out.
                const TextUnits otherUnits = units - entry.units;
                AttributePlan plan;
                RenderAttributes scanned = renderElementAttributes(ctx, element, size_t(others), otherUnits, keepInput,
                                                                   keepInput ? &plan.startTag : nullptr);
                if (scanned.overBudget || scanned.styleTooLong || scanned.textLeftOut) {
                    return this->refused("over a byte, style or text limit");
                }
                // A canvas's size is its twcanvas: source's: a new one is the cut walk's to judge (limit.canvas-pixels).
                if (const auto src = scanned.map.find("src"); dynamic_cast<const HTMLCanvasElement*>(&element) &&
                                                              (src == scanned.map.end() || src->second != tag->get_attr("src", ""))) {
                    return this->refused("a canvas's size changed");
                }
                // What changed: litehtml's attributes against the DOM's, by lowercased name. litehtml keeps one
                // attribute of its own, list_index, which layout writes on list items.
                const litehtml::string_map& current = tag->attributes();
                for (const auto& attribute : scanned.map) {
                    plan.wanted[litehtml::lowcase(attribute.first)] = attribute.second;
                }
                litehtml::string_map comparable = current;
                comparable.erase("list_index");
                plan.changed = comparable != plan.wanted;
                if (plan.changed) {
                    // The element is matched again: the fork's predicate (set_element_attributes asks it again at the
                    // commit).
                    const bool allowed = document.can_set_element_attributes(entry.element, plan.wanted, &attributeGrowth);
                    if (!allowed) {
                        return this->refusedBy("refused by can_set_element_attributes", document);
                    }
                }
                bytes = others + scanned.bytes;
                units = otherUnits + scanned.units;
                plan.entry = &entry;
                plan.element = entry.element;
                plan.bytes = scanned.bytes;
                plan.units = scanned.units;
                attributePlans.push_back(std::move(plan));
                continue;
            }
            if (node.type() != NodeType::Text) {
                return this->refused("not a Text");
            }
            auto swapped = swaps.find(&node);
            Node* const swappedOut = swapped == swaps.end() ? nullptr : swapped->second;
            auto found = m_current.nodes.find(swappedOut ? swappedOut : &node);
            // Text no build reads (inside an element the profile drops, or a <script>): its change renders nothing, as
            // an unrendered element's attribute change does (V4 plan, Task 4: profile 1 drops every form control).
            if (found == m_current.nodes.end() && !this->readByABuild(ctx, node)) {
                continue;
            }
            if (found == m_current.nodes.end() || found->second.pieces.empty()) {
                return this->refused("an unmapped or empty Text");
            }
            RenderEntry& entry = found->second;
            Node* domParent = node.parent();
            litehtml::element::ptr parent = entry.pieces[0]->parent();
            if (!domParent || !domParent->isElement() || !parent) {
                return this->refused("no parent");
            }
            String data = static_cast<CharacterData&>(node).dataString(ctx);
            // The budget the other nodes leave this one (Ruling 7): a fresh build cuts at it.
            const uint64_t others = bytes - entry.bytes;
            TextPlan plan;
            // Profile 1's text limits (V4 plan, Task 7): past one, a fresh build leaves the Text out.
            plan.units = renderTextUnits(data);
            const TextUnits otherUnits = units - entry.units;
            if (!renderTextFits(Runtime::from(ctx).limits(), plan.units, otherUnits)) {
                return this->refused("over a text limit");
            }
            if (others > kMaxRenderBytes || !renderUtf8AtMost(data, kMaxRenderBytes - size_t(others), plan.utf8) ||
                plan.utf8.empty()) {
                return this->refused("over the byte budget, or empty");
            }
            // Finding the pieces among their parent's children: once now, once again where the replacement is made.
            const size_t first = childIndex(parent, entry.pieces[0].get());
            plan.oldCount = entry.pieces.size();
            int growth = 0;
            if (first == ~size_t(0) ||
                !document.can_replace_text(parent, first, plan.oldCount, plan.utf8.c_str(), pendingGrowth, &growth)) {
                return this->refusedBy("refused by can_replace_text", document);
            }
            plan.newCount = size_t(int(plan.oldCount) + growth);
            pendingGrowth += growth;
            surplus += plan.newCount > plan.oldCount ? plan.newCount - plan.oldCount : 0;
            replaced += plan.oldCount;
            boxes = uint64_t(int64_t(boxes) + growth);
            bytes = others + plan.utf8.size();
            units = otherUnits + plan.units;
            if (keepInput) {
                Element& parentElement = static_cast<Element&>(*domParent);
                const bool raw = parentElement.isHTMLElement() &&
                                 DOMState::of(ctx).hasRawTextChildren(parentElement.localNameAtom());
                plan.escaped = raw ? plan.utf8 : renderEscapedText(plan.utf8);
            }
            plan.node = &node;
            plan.entry = &entry;
            plan.replaced = swappedOut;
            plan.parent = std::move(parent);
            plans.push_back(std::move(plan));
        }
        if (!planStateReach(document, statePlan)) {
            return this->refusedBy("refused by can_set_pseudo_classes", document);
        }
        // Everything the patch will allocate. Pieces: reserved per plan and in each entry; and a place for each swapped
        // Text's old root, released after the flush.
        for (TextPlan& plan : plans) {
            plan.pieces.reserve(plan.newCount);
            plan.entry->pieces.reserve(plan.newCount);
        }
        retired.reserve(swaps.size());
        // The element map: the new pieces take over the nodes of the old ones, and the surplus has spares made now.
        m_current.elements.reserve(m_current.elements.size() + surplus);
        pool.reserve(surplus + replaced);
        std::vector<char> keys(surplus);
        for (size_t i = 0; i < surplus; i++) {
            auto at = m_current.elements.emplace(reinterpret_cast<const litehtml::element*>(&keys[i]), nullptr);
            pool.push_back(m_current.elements.extract(at.first));
        }
        // The render input, composed whole: the escaped text of each Text plan and the start tag of each attribute
        // plan replace what the build wrote at their entries' places. (An entry the input does not hold, a void
        // element's child, has no place.)
        if (keepInput) {
            patches.reserve(plans.size() + attributePlans.size());
            for (const TextPlan& plan : plans) {
                const RenderEntry& entry = *plan.entry;
                if (entry.inputOffset != kNoRenderInput) {
                    patches.push_back({entry.inputOffset, entry.seq, entry.inputLength, &plan.escaped,
                                       ptrdiff_t(plan.escaped.size()) - ptrdiff_t(entry.inputLength)});
                }
            }
            for (const AttributePlan& plan : attributePlans) {
                const RenderEntry& entry = *plan.entry;
                if (entry.inputOffset != kNoRenderInput) {
                    patches.push_back({entry.inputOffset, entry.seq, entry.inputLength, &plan.startTag,
                                       ptrdiff_t(plan.startTag.size()) - ptrdiff_t(entry.inputLength)});
                }
            }
            std::sort(patches.begin(), patches.end(), [](const InputPatch& a, const InputPatch& b) {
                return a.offset != b.offset ? a.offset < b.offset : a.seq < b.seq;
            });
            ptrdiff_t total = ptrdiff_t(m_current.input.size());
            for (const InputPatch& patch : patches) {
                total += patch.delta;
            }
            newInput.reserve(size_t(total));
            size_t from = 0;
            for (const InputPatch& patch : patches) {
                newInput.append(m_current.input.data() + from, patch.offset - from);
                newInput.append(patch.text->data(), patch.text->size());
                from = patch.offset + patch.length;
            }
            newInput.append(m_current.input.data() + from, m_current.input.size() - from);
        }
        // The steps the patch's matching may take (kPatchSelectorSteps).
        stepLimit = kPatchSelectorSteps;
    } catch (...) {
        abortForCaughtException(ctx);
    }

    // ---- Patching: from here the published document is changed, and nothing below allocates ours. ----
    // The plan said every one of these would be accepted, so a refusal is a bug in the plan or in the fork's predicate,
    // and what was half-applied has no honest fallback.
    MirrorPublish published;
    std::vector<std::string> limits;
    try {
        // The session's limit (a test can cap it below what the plan allowed, to cut it: setPatchStepCapForTesting).
        sessionLimit = std::min(stepLimit, m_patchStepCap);
        StepSession steps(document, sessionLimit, sessionUsed);
        // twidget edits 79, 80: the environment is the session's first change, the root declarations first.
        if (m_journal.environmentPending()) {
            document.change_root_declarations(rootDeclarationsOf(m_container.options()));
            document.environment_changed();
        }
        for (TextPlan& plan : plans) {
            const size_t first = childIndex(plan.parent, plan.entry->pieces[0].get());
            if (first == ~size_t(0) ||
                !document.replace_text(plan.parent, first, plan.oldCount, plan.utf8.c_str(), plan.pieces)) {
                this->stopInternally(ctx, "replace_text refused");
            }
            RenderEntry& entry = *plan.entry;
            for (const litehtml::element::ptr& old : entry.pieces) {
                pool.push_back(m_current.elements.extract(old.get()));
            }
            entry.pieces.clear();
            for (const litehtml::element::ptr& piece : plan.pieces) {
                entry.pieces.push_back(piece);
                auto handle = std::move(pool.back());
                pool.pop_back();
                handle.key() = piece.get();
                handle.mapped() = plan.node;
                m_current.elements.insert(std::move(handle));
            }
            entry.bytes = plan.utf8.size();
            entry.units = plan.units;
            if (plan.replaced) {
                // The new Text takes the old one's entry and its place (a map node moves, its value does not), and a key
                // of its own when it is next asked for, as a build gives a new node: what named the old one (a selection
                // boundary) does not name it.
                auto handle = m_current.nodes.extract(plan.replaced);
                handle.key() = plan.node;
                retired.push_back(std::move(handle.mapped().node));
                handle.mapped().node = Ref<Node>::retain(ctx, plan.node);
                handle.mapped().key = 0;
                m_current.nodes.insert(std::move(handle));
            }
        }
        for (AttributePlan& plan : attributePlans) {
            if (plan.changed && !document.set_element_attributes(plan.element, plan.wanted)) {
                this->stopInternally(ctx, "set_element_attributes refused");
            }
            plan.entry->bytes = plan.bytes;
            plan.entry->units = plan.units;
        }
        if (!statePlan.flips.empty() && !document.set_pseudo_classes(statePlan.flips)) {
            this->stopInternally(ctx, "set_pseudo_classes refused");
        }
        // Twidget edit 84: near a cap the commit replays the style pass, within the patch's step limit.
        document.set_replay_step_limit(this->replayStepLimit(ctx));
        document.commit_patch();
        // The steps the matching took, a replay's (twidget edit 84) included.
        const int64_t used = steps.close();
        // Cut by the patch's step limit: a fresh build would cut elsewhere, or not at all, and no other build follows,
        // so the widget stops (stopInternally).
        if (this->ownSteps(ctx, document, used) > sessionLimit) {
            this->stopInternally(ctx, "a patch's matching cut at its selector-step limit");
        }
        m_current.stepCut = false; // the commit replayed a cut boot's matching (twidget edit 84)
        m_lastPatchSteps = used;
        // The counters and the render input, which cannot fail: the map and the document agree from here.
        m_current.boxes = boxes;
        m_current.bytes = bytes;
        m_current.textUnits = units;
        if (keepInput) {
            std::vector<ptrdiff_t> before(patches.size() + 1, 0);
            for (size_t i = 0; i < patches.size(); i++) {
                before[i + 1] = before[i] + patches[i].delta;
            }
            for (auto& [node, entry] : m_current.nodes) {
                if (entry.inputOffset == kNoRenderInput) {
                    continue;
                }
                auto at = std::lower_bound(patches.begin(), patches.end(), entry,
                                           [](const InputPatch& patch, const RenderEntry& e) {
                                               return patch.offset != e.inputOffset ? patch.offset < e.inputOffset
                                                                                    : patch.seq < e.seq;
                                           });
                const size_t index = size_t(at - patches.begin());
                if (at != patches.end() && at->offset == entry.inputOffset && at->seq == entry.seq) {
                    entry.inputLength = at->text->size();
                }
                entry.inputOffset = size_t(ptrdiff_t(entry.inputOffset) + before[index]);
                if (entry.element && entry.inputEnd != kNoRenderInput) {
                    // An element's end moves with everything replaced before it (Task 9 reads it).
                    auto end = std::lower_bound(patches.begin(), patches.end(), entry.inputEnd,
                                                [](const InputPatch& patch, size_t at) { return patch.offset < at; });
                    entry.inputEnd = size_t(ptrdiff_t(entry.inputEnd) + before[size_t(end - patches.begin())]);
                }
            }
            m_current.input.swap(newInput);
        }
        m_current.naturalWidth =
            double(document.render(litehtml::pixel_t(float(m_container.options().width))).value());
        this->styleLimits(document, limits);
        // Task 10b: the operations the fork's reports give, the painted canvases with them.
        this->reportRepaints();
        published = publishPatch();
        m_container.prune(document);
    } catch (const LayerMirror::Inconsistent& inconsistent) {
        this->stopInternally(ctx, inconsistent.what());
    } catch (...) {
        abortForCaughtException(ctx);
    }
    installPatch(published);
    m_patchCount++;
    m_swappedTexts += retired.size();
    m_journal.clear();
    // Twidget edit 84: the style pass's limits (the published build's walk hit none, or the flush walked the cut).
    m_current.walkLimits = 0;
    this->publishLimits(ctx, std::move(limits));
    return PatchResult::Patched;
}

namespace {

/// A change the structure patch makes to the render input: [offset, offset + length) becomes the staging input's
/// [from, to). A removal has from == to; an insertion length 0.
struct StructurePatch {
    size_t offset;
    size_t length;
    size_t order;
    size_t from;
    size_t to;
    /// Where its text lands in the new input.
    size_t landed;
};

/// Subtrees (an element, or a Text's pieces) inserted under `parent` before `anchor`, or at the end (before an
/// ::after) when it is null.
struct Insertion {
    litehtml::element::ptr parent;
    litehtml::element::ptr anchor;
    std::vector<litehtml::element::ptr> roots;
    /// Where their serialization goes in the render input; kNoRenderInput when they have none there.
    size_t inputAt = kNoRenderInput;
    /// Their serialization in the staging input.
    size_t from = 0;
    size_t to = 0;
};

/// The index an insertion at the end takes: before a trailing ::after.
size_t endIndex(const litehtml::element::ptr& parent) {
    const auto& children = parent->children();
    return children.size() - (!children.empty() && children.back()->tag() == litehtml::__tag_after_ ? 1 : 0);
}

bool isStyleElement(const litehtml::element& element) {
    const char* tag = element.get_tagName();
    return tag && std::strcmp(tag, "style") == 0;
}

// The document's own html, head or body as litehtml made them (another element of those names renders as an inert one).
bool isDocumentLevel(const litehtml::element& element) {
    const litehtml::string_id tag = element.tag();
    return tag == litehtml::_html_ || tag == litehtml::_head_ || tag == litehtml::_body_;
}

} // namespace

bool RenderTree::journalTouchesSheets(JSContext* ctx, bool subtrees) {
    if (!m_current.document) {
        return false;
    }
    auto renderedStyle = [this](Node* node) {
        if (!node) {
            return false;
        }
        auto found = m_current.nodes.find(node);
        return found != m_current.nodes.end() && found->second.element && isStyleElement(*found->second.element);
    };
    constexpr JournalKinds kOwn = journalBit(JournalKind::Text) | journalBit(JournalKind::Attribute);
    constexpr JournalKinds kMoved = journalBit(JournalKind::Inserted) | journalBit(JournalKind::Removed);
    for (const JournalEntry& journaled : m_journal.entries()) {
        Node& node = *journaled.node;
        if ((journaled.kinds & kOwn) != 0 && (renderedStyle(&node) || renderedStyle(node.parent()))) {
            return true;
        }
        if (!subtrees) {
            continue;
        }
        if ((journaled.kinds & journalBit(JournalKind::Children)) != 0 && renderedStyle(&node)) {
            return true;
        }
        if ((journaled.kinds & kMoved) != 0) {
            // A rendered <style> going, or one coming.
            for (Node* n = &node; n; n = n->nextInTreeOrder(&node)) {
                if (m_current.sheets.count(n) != 0 ||
                    (n->isElement() && renderTagOf(ctx, static_cast<Element&>(*n)).stylesheet)) {
                    return true;
                }
            }
        }
    }
    return false;
}

std::optional<RenderTree::SheetPlan> RenderTree::planSheets(JSContext* ctx, const RenderBuild& staging,
                                                            const std::unordered_set<Node*>& reread,
                                                            const std::unordered_set<Node*>& released, TextUnits units,
                                                            bool counted) {
    static const RenderSheet kNoSheet;
    SheetPlan plan;
    DOMState& state = DOMState::of(ctx);
    const bool keepInput = m_container.options().keepRenderInput;
    size_t cssBytes = 0;
    // The rendered elements in tree order (an unrendered element's subtree is not), as a fresh build of the patched tree
    // meets them.
    Element* root = state.document().documentElementNode();
    for (Node* node = root; node;) {
        RenderEntry* kept = nullptr;
        const RenderEntry* staged = nullptr;
        if (auto found = m_current.nodes.find(node); found != m_current.nodes.end() && released.count(node) == 0) {
            kept = &found->second;
        } else if (auto built = staging.nodes.find(node); built != staging.nodes.end()) {
            staged = &built->second;
        }
        const RenderEntry* entry = kept ? kept : staged;
        if (!node->isElement() || !entry || !entry->element) {
            node = node->nextSkippingChildren(root);
            continue;
        }
        if (!isStyleElement(*entry->element)) {
            node = node->nextInTreeOrder(root);
            continue;
        }
        Element& style = static_cast<Element&>(*node);
        const size_t room = kMaxStyleText - cssBytes;
        const RenderSheet* sheet = &kNoSheet;
        const bool read = kept && reread.count(node) != 0;
        RenderSheet fresh;
        if (read) {
            if (!renderStyleSheet(ctx, style, room, fresh)) {
                return std::nullopt;
            }
            sheet = &fresh;
        } else {
            const auto& sheets = kept ? m_current.sheets : staging.sheets;
            if (auto found = sheets.find(node); found != sheets.end()) {
                sheet = &found->second;
            }
        }
        // Ruling 7 in tree order: a fresh build applies each sheet within what those before it leave. Profile 1's
        // budgets: each value here, the document's totals below.
        const Limits& limits = Runtime::from(ctx).limits();
        if (sheet->length > room || sheet->utf8.size() > room || !renderTextFits(limits, sheet->text, TextUnits{}) ||
            !renderTextFits(limits, sheet->strings, TextUnits{})) {
            return std::nullopt;
        }
        cssBytes += sheet->utf8.size();
        if (!sheet->utf8.empty()) {
            plan.applied.push_back(sheet->utf8);
            plan.usesUserActionPseudo = plan.usesUserActionPseudo || renderMentionsUserActionPseudo(sheet->utf8);
        }
        if (read) {
            if (!counted) {
                auto published = m_current.sheets.find(node);
                const RenderSheet& old = published == m_current.sheets.end() ? kNoSheet : published->second;
                units = units - (old.text + old.strings) + (fresh.text + fresh.strings);
            }
            SheetPlan::Change change;
            change.node = node;
            change.entry = kept;
            change.pieces.reserve(1);
            if (keepInput && kept->inputOffset != kNoRenderInput) {
                const bool raw = style.isHTMLElement() && state.hasRawTextChildren(style.localNameAtom());
                change.escaped = raw ? fresh.utf8 : renderEscapedText(fresh.utf8);
            }
            plan.addedPieces += fresh.utf8.empty() ? 0 : 1;
            plan.removedPieces += kept->pieces.size();
            change.sheet = std::move(fresh);
            plan.changes.push_back(std::move(change));
        }
        node = node->nextInTreeOrder(root);
    }
    if (!counted && !renderTextFits(Runtime::from(ctx).limits(), TextUnits{}, units)) {
        return std::nullopt;
    }
    plan.units = units;
    plan.changed = plan.applied != m_current.styleSheets;
    // limit.css-rules (widget-sandbox v0.3.0): the applied sheets counted in tree order, as a build counts them, before the
    // patch touches litehtml.
    if (plan.changed) {
        size_t rules = 0;
        size_t keyframes = 0;
        for (const std::string& sheet : plan.applied) {
            renderCountCssRules(ctx, Runtime::from(ctx).limits(), sheet, rules, keyframes);
        }
    }
    plan.ruleBound = cssBytes / 2;
    return plan;
}

bool RenderTree::documentElementKept(JSContext* ctx, litehtml::document& document) const {
    Element* now = DOMState::of(ctx).document().documentElementNode();
    auto built = document.root() ? m_current.elements.find(document.root().get()) : m_current.elements.end();
    return built == m_current.elements.end() ? now == nullptr : built->second == now;
}

bool RenderTree::ownHeadAndBodyStay(JSContext* ctx, litehtml::document& document) const {
    const Node* head = nullptr;
    const Node* body = nullptr;
    if (const litehtml::element::ptr root = document.root()) {
        for (const litehtml::element::ptr& child : root->children()) {
            const litehtml::string_id tag = child->tag();
            const Node*& adopted = tag == litehtml::_head_ ? head : body;
            if ((tag == litehtml::_head_ || tag == litehtml::_body_) && !adopted) {
                auto built = m_current.elements.find(child.get());
                adopted = built == m_current.elements.end() ? nullptr : built->second;
            }
        }
    }
    Document& dom = DOMState::of(ctx).document();
    if (head != dom.head(ctx) || body != dom.body(ctx)) {
        return false;
    }
    constexpr JournalKinds kMoved = journalBit(JournalKind::Inserted) | journalBit(JournalKind::Removed);
    for (const JournalEntry& journaled : m_journal.entries()) {
        if ((journaled.node.get() == head || journaled.node.get() == body) && (journaled.kinds & kMoved) != 0) {
            return false;
        }
    }
    return true;
}

RenderTree::PatchResult RenderTree::flushRoot(JSContext* ctx, litehtml::document& document) {
    constexpr std::string_view kDoctype = "<!doctype html>";
    JSRuntime* rt = JS_GetRuntime(ctx);
    const bool keepInput = m_container.options().keepRenderInput;
    RenderBuild staging(ctx);
    RenderSubtreeTotals totals;
    size_t walkKinds = 0;
    litehtml::element::ptr root;
    std::optional<SheetPlan> sheetPlan;
    std::unordered_set<Node*> released;
    std::vector<RenderNodeMap::node_type> nodeGraveyard;
    std::vector<RenderElementMap::node_type> elementGraveyard;
    RenderString newInput{JSAllocator<char>(rt)};
    // The filter loop's bound, the session's limit and the steps it performed.
    int64_t stepLimit = 0;
    int64_t sessionLimit = 0;
    int64_t sessionUsed = 0;
    // ---- Planning: nothing of litehtml's published tree or of the published build is touched. ----
    try {
        // Everything published goes.
        released.reserve(m_current.nodes.size());
        for (const auto& [node, entry] : m_current.nodes) {
            released.insert(node);
        }
        // The new document element as a build walks it, within the document's limits counted from nothing.
        if (!buildRenderRoot(ctx, m_container, document, staging, totals, root)) {
            return this->refused("a render limit in a built subtree");
        }
        // It cut at every cap as a build does (RenderCut.h): its walk's limits.
        walkKinds = staging.limits.size();
        // Its sheets (twidget edit 81), in tree order within Ruling 7 and profile 1's budgets.
        sheetPlan = this->planSheets(ctx, staging, {}, released, totals.units);
        if (!sheetPlan) {
            return this->refused("a <style>'s sheet at a cap");
        }
        totals.units = sheetPlan->units;
        litehtml::document::structure_growth growth;
        if (!document.can_replace_root(root, &growth)) {
            return this->refusedBy("refused by can_replace_root", document);
        }
        // Everything the patch allocates: the graveyards, the maps' room, the render input.
        nodeGraveyard.reserve(m_current.nodes.size());
        elementGraveyard.reserve(m_current.elements.size());
        m_current.nodes.reserve(staging.nodes.size());
        m_current.elements.reserve(staging.elements.size());
        if (keepInput) {
            newInput.reserve(kDoctype.size() + staging.input.size());
            newInput.append(kDoctype.data(), kDoctype.size());
            newInput.append(staging.input.data(), staging.input.size());
        }
        // The steps the patch's matching may take (kPatchSelectorSteps).
        stepLimit = kPatchSelectorSteps;
    } catch (...) {
        abortForCaughtException(ctx);
    }

    // ---- Patching: from here the published document is changed, and nothing below allocates ours. ----
    MirrorPublish published;
    std::vector<std::string> limits;
    try {
        sessionLimit = std::min(stepLimit, m_patchStepCap);
        StepSession steps(document, sessionLimit, sessionUsed);
        if (!document.replace_root(root)) {
            this->stopInternally(ctx, "replace_root refused");
        }
        // twidget edits 79, 80: the environment applied to the new tree, which the commit styles fresh: the root
        // declarations set (its style takes them), the media features read again (no element of it has matched yet).
        if (m_journal.environmentPending()) {
            if (rootDeclarationsOf(m_container.options()) != document.root_declarations_text()) {
                document.set_root_declarations(rootDeclarationsOf(m_container.options()));
            }
            document.environment_changed();
        }
        // The maps: what was published goes to the graveyards (freed after the publish); what was built comes in, its
        // places after the doctype, each node that stays keeping its key (Task 10b).
        for (auto& [node, entry] : staging.nodes) {
            if (auto kept = m_current.nodes.find(node); kept != m_current.nodes.end()) {
                entry.key = kept->second.key;
            }
        }
        while (!m_current.nodes.empty()) {
            auto handle = m_current.nodes.extract(m_current.nodes.begin());
            if (handle.mapped().key && !staging.nodes.count(handle.key())) {
                forgetGeneratedKeys(handle.mapped().key);
            }
            nodeGraveyard.push_back(std::move(handle));
        }
        while (!m_current.elements.empty()) {
            elementGraveyard.push_back(m_current.elements.extract(m_current.elements.begin()));
        }
        while (!staging.nodes.empty()) {
            auto handle = staging.nodes.extract(staging.nodes.begin());
            RenderEntry& entry = handle.mapped();
            if (keepInput && entry.inputOffset != kNoRenderInput) {
                entry.inputOffset += kDoctype.size();
                if (entry.element && entry.inputEnd != kNoRenderInput) {
                    entry.inputEnd += kDoctype.size();
                }
            }
            m_current.nodes.insert(std::move(handle));
        }
        while (!staging.elements.empty()) {
            m_current.elements.insert(staging.elements.extract(staging.elements.begin()));
        }
        m_current.sheets.swap(staging.sheets);
        m_current.styleSheets.swap(sheetPlan->applied);
        m_current.usesUserActionPseudo = sheetPlan->usesUserActionPseudo;
        if (keepInput) {
            m_current.input.swap(newInput);
        }
        m_current.boxes = staging.boxes;
        m_current.bytes = totals.bytes;
        m_current.textUnits = totals.units;
        m_current.nodeCount = totals.nodes;
        m_unheardNodes = 0;
        m_current.elementCount = totals.elements;
        m_current.formControlCount = totals.formControls;
        m_current.nextSeq = totals.seq;
        // Twidget edit 84: near a cap the commit replays the style pass, within the patch's step limit.
        document.set_replay_step_limit(this->replayStepLimit(ctx));
        document.commit_patch();
        // As flushStructure: a cut session stops the widget.
        const int64_t used = steps.close();
        if (this->ownSteps(ctx, document, used) > sessionLimit) {
            this->stopInternally(ctx, "a patch's matching cut at its selector-step limit");
        }
        m_current.stepCut = false; // the commit replayed a cut boot's matching (twidget edit 84)
        m_lastPatchSteps = used;
        m_current.naturalWidth =
            double(document.render(litehtml::pixel_t(float(m_container.options().width))).value());
        limits = staging.limits;
        this->styleLimits(document, limits);
        this->reportRepaints();
        published = publishPatch();
        m_container.prune(document);
    } catch (const LayerMirror::Inconsistent& inconsistent) {
        this->stopInternally(ctx, inconsistent.what());
    } catch (...) {
        abortForCaughtException(ctx);
    }
    installPatch(published);
    m_patchCount++;
    m_journal.clear();
    // The new document element's walk, a build's (RenderCut.h), then the style pass's.
    m_current.walkLimits = walkKinds;
    this->publishLimits(ctx, std::move(limits));
    return PatchResult::Patched;
}

RenderTree::PatchResult RenderTree::flushStructure(JSContext* ctx, bool walk) {
    constexpr JournalKinds kOwn =
        journalBit(JournalKind::Text) | journalBit(JournalKind::Attribute) | journalBit(JournalKind::State);
    // publishJournal sends a journal here with a structural entry, or one that changes a <style>'s sheet (twidget edit 81).
    if (!m_journal.built() || !m_current.document || m_flushing) {
        return this->refused("no build");
    }
    m_flushing = true;
    struct Flushing {
        bool& flag;
        ~Flushing() { flag = false; }
    } flushing{m_flushing};
    litehtml::document& document = *m_current.document;
    // The walk, paid for first.
    JSRuntime* rt = JS_GetRuntime(ctx);
    const bool keepInput = m_container.options().keepRenderInput;
    DOMState& state = DOMState::of(ctx);

    // What the subtrees are built into: entries, element-map entries and serialization, moved over at the patch.
    RenderBuild staging(ctx);
    std::vector<litehtml::element::ptr> removals;
    std::vector<Insertion> insertions;
    StatePlan statePlan;
    std::vector<Node*> released;
    std::unordered_set<Node*> releasedSet;
    std::vector<StructurePatch> patches;
    std::vector<ptrdiff_t> before;
    std::vector<const StructurePatch*> landing;
    RenderString newInput{JSAllocator<char>(rt)};
    std::vector<RenderNodeMap::node_type> nodeGraveyard;
    std::vector<RenderElementMap::node_type> elementGraveyard;
    RenderSubtreeTotals totals;
    // twidget edit 81: the kept <style>s whose sheets are read again, the sheets as the patch leaves them, and spare
    // element-map nodes for the pieces their changes add.
    std::unordered_set<Node*> reread;
    std::optional<SheetPlan> sheetPlan;
    // An element's own attribute change beside structure, set in place (the document's html, head or body, twidget edit
    // 75, which no subtree build makes, and every other kept element), each planned as the attribute path plans one,
    // with its start tag's place in the staging input.
    struct OwnAttributes {
        Node* node = nullptr;
        RenderEntry* entry = nullptr;
        litehtml::element::ptr element;
        litehtml::string_map wanted;
        bool changed = false;
        size_t bytes = 0;
        TextUnits units;
        std::string startTag;
        size_t from = 0;
        size_t to = 0;
    };
    std::vector<OwnAttributes> ownAttributes;
    // A kept Text's own change beside structure, outside walk mode, where twidget edit 16 can place it: its pieces
    // replaced in place (document::replace_text) after the session's insertions, planned as the text path plans one,
    // with its text's place in the staging input.
    struct OwnText {
        Node* node = nullptr;
        RenderEntry* entry = nullptr;
        litehtml::element::ptr parent;
        std::string utf8;
        /// The text as the render input carries it; only when the options keep it.
        std::string escaped;
        TextUnits units;
        size_t first = 0;
        size_t oldCount = 0;
        size_t newCount = 0;
        /// replace_text's output: reserved, so the litehtml phase allocates nothing of ours.
        std::vector<litehtml::element::ptr> pieces;
        size_t from = 0;
        size_t to = 0;
    };
    std::vector<OwnText> ownTexts;
    // Spare element-map nodes for the pieces the Texts replaced in place add, and the nodes of those they replace.
    std::vector<RenderElementMap::node_type> textPool;
    int64_t textGrowth = 0;
    std::vector<RenderElementMap::node_type> sheetPool;
    size_t releasedSheets = 0;
    uint64_t boxes = 0;
    int64_t stepLimit = 0;
    // The session's limit and the steps it performed.
    int64_t sessionLimit = 0;
    int64_t sessionUsed = 0;
    // Walk mode (RenderCut.h): the DOM walked as a build walks it, and every node's state before it, which each subtree
    // build starts from.
    std::optional<RenderCutDiff> cut;
    std::unordered_map<const Node*, RenderCutState> cutBefore;
    // ---- Planning: nothing of litehtml's published tree or of the published build is touched. The subtrees are made
    // with the document, detached. ----
    try {
        // twidget edit 82: the document's own children changed and the document element is another, or it went and came
        // back, or the document element's own children changed which head or body is the document's own (a head or body
        // inserted before it, or it removed) or moved it: it is replaced in place, and everything else with it. Any other
        // change of the document element's children places them as any element's are.
        {
            constexpr JournalKinds kMoved = journalBit(JournalKind::Inserted) | journalBit(JournalKind::Removed);
            Node* documentElement = state.document().documentElementNode();
            bool childrenChanged = false;
            for (const JournalEntry& journaled : m_journal.entries()) {
                if ((journaled.node->type() == NodeType::Document && !this->documentElementKept(ctx, document)) ||
                    (journaled.node.get() == documentElement && (journaled.kinds & kMoved) != 0)) {
                    return this->flushRoot(ctx, document);
                }
                childrenChanged = childrenChanged || (journaled.node.get() == documentElement &&
                                                      (journaled.kinds & journalBit(JournalKind::Children)) != 0);
            }
            if (childrenChanged && !this->ownHeadAndBodyStay(ctx, document)) {
                return this->flushRoot(ctx, document);
            }
        }
        // 1. The parents whose children changed. The document's own with the same document element are a comment's or the
        // doctype's, which nothing renders (twidget edit 82); a <style>'s are its sheet, read again (twidget edit 81).
        std::vector<Node*> dirtyNodes;
        // Their membership, asked once per node a walk folds in (up to every node of a moved cut).
        std::unordered_set<Node*> dirtySet;
        std::vector<RenderEntry*> dirty;
        for (const JournalEntry& journaled : m_journal.entries()) {
            if ((journaled.kinds & journalBit(JournalKind::Children)) == 0) {
                continue;
            }
            Node& node = *journaled.node;
            if (node.type() == NodeType::Document) {
                continue;
            }
            auto found = m_current.nodes.find(&node);
            // A parent no build reads (an element the profile drops, or one inside it): its children render nothing.
            if (found == m_current.nodes.end() && !this->readByABuild(ctx, node)) {
                continue;
            }
            if (found == m_current.nodes.end() || !found->second.element) {
                // Unmapped, cut by a cap: walking the cut, its own fate decides whether it is built.
                if (walk) {
                    continue;
                }
                return this->refused("an unmapped parent's children");
            }
            if (isStyleElement(*found->second.element)) {
                reread.insert(&node);
                continue;
            }
            dirtyNodes.push_back(&node);
            dirtySet.insert(&node);
            dirty.push_back(&found->second);
        }
        // Walk mode: the DOM walked as a build walks it, first; its decisions place every change below.
        std::unordered_map<const Node*, const RenderCutNode*> cutNodes;
        if (walk) {
            // Every node's state where every child of a reached parent is built again (sibling combinators or
            // positional pseudo-classes); else the journal's nodes and their parents', with every node the cut moved.
            std::unordered_set<const Node*> wanted;
            for (const JournalEntry& journaled : m_journal.entries()) {
                wanted.insert(journaled.node.get());
                if (Node* parent = journaled.node->parent()) {
                    wanted.insert(parent);
                }
            }
            cut.emplace(renderCutDiff(ctx, m_container, m_current, wanted, document.structure_reaches_siblings()));
            cutBefore.reserve(cut->nodes.size());
            cutNodes.reserve(cut->nodes.size());
            for (const RenderCutNode& decided : cut->nodes) {
                cutBefore.emplace(decided.node, decided.before);
                cutNodes.emplace(decided.node, &decided);
            }
        }
        // A kept node's own text or attribute change beside the structure (a mixed journal). An element's own attribute
        // change is set in place in the session (document::set_element_attributes), as the document element's is, where
        // it is rendered with the tag it has: walking the cut, where the walk renders it so (whatever its own bytes and
        // units: what moves below it is folded in by itself). Outside walk mode, a Text's own change is set in place
        // where its pieces can be replaced (twidget edit 16: it has pieces, its new data is not empty, and
        // can_replace_text takes it), after the insertions. Any other node goes and is built again where it is, its
        // parent's children reconciled as a removal's and an insertion's are; a <style>'s is built again with its
        // sheet. A state change alone is set in place (step 4).
        std::vector<Node*> builtAgain;
        std::unordered_set<const Node*> setInPlace;
        for (const JournalEntry& journaled : m_journal.entries()) {
            constexpr JournalKinds kContent = journalBit(JournalKind::Text) | journalBit(JournalKind::Attribute);
            Node& node = *journaled.node;
            if ((journaled.kinds & kContent) == 0 || (journaled.kinds & journalBit(JournalKind::Removed)) != 0 ||
                !m_current.nodes.count(&node) || !node.parent()) {
                continue;
            }
            // twidget edit 82 (4a's M5): the document's html, head or body: its own attributes set in place in the session.
            if (const RenderEntry& self = m_current.nodes.find(&node)->second; self.element && isDocumentLevel(*self.element)) {
                if ((journaled.kinds & journalBit(JournalKind::Attribute)) != 0) {
                    OwnAttributes own;
                    own.node = &node;
                    ownAttributes.push_back(std::move(own));
                }
                continue;
            }
            if (node.isElement() && (journaled.kinds & journalBit(JournalKind::Attribute)) != 0) {
                auto decided = cutNodes.find(&node);
                const RenderEntry& self = m_current.nodes.find(&node)->second;
                auto* tag = dynamic_cast<litehtml::html_tag*>(self.element.get());
                if ((!walk || (decided != cutNodes.end() && decided->second->fate == RenderFate::Rendered)) && tag &&
                    !isStyleElement(*self.element) &&
                    litehtml::lowcase(renderTagOf(ctx, static_cast<Element&>(node)).tag) ==
                        litehtml::lowcase(tag->get_tagName())) {
                    OwnAttributes own;
                    own.node = &node;
                    ownAttributes.push_back(std::move(own));
                    setInPlace.insert(&node);
                    continue;
                }
            }
            if (!walk && node.type() == NodeType::Text && (journaled.kinds & journalBit(JournalKind::Text)) != 0) {
                RenderEntry& self = m_current.nodes.find(&node)->second;
                auto parentEntry = m_current.nodes.find(node.parent());
                if (!self.pieces.empty() && self.pieces[0]->parent() && parentEntry != m_current.nodes.end() &&
                    parentEntry->second.element && !isStyleElement(*parentEntry->second.element)) {
                    String data = static_cast<CharacterData&>(node).dataString(ctx);
                    OwnText own;
                    own.parent = self.pieces[0]->parent();
                    // Finding the pieces among their parent's children: once now, once again where they are replaced.
                    own.first = childIndex(own.parent, self.pieces[0].get());
                    own.oldCount = self.pieces.size();
                    if (data.length() > 0 && own.first != ~size_t(0) &&
                        renderUtf8AtMost(data, kMaxRenderBytes, own.utf8) && !own.utf8.empty() &&
                        document.can_replace_text(own.parent, own.first, own.oldCount, own.utf8.c_str())) {
                        own.node = &node;
                        own.entry = &self;
                        own.units = renderTextUnits(data);
                        if (keepInput) {
                            Element& parentElement = static_cast<Element&>(*node.parent());
                            const bool raw = parentElement.isHTMLElement() &&
                                             state.hasRawTextChildren(parentElement.localNameAtom());
                            own.escaped = raw ? own.utf8 : renderEscapedText(own.utf8);
                        }
                        ownTexts.push_back(std::move(own));
                        setInPlace.insert(&node);
                        continue;
                    }
                }
            }
            Node& parent = *node.parent();
            if (parent.type() == NodeType::Document) {
                return this->flushRoot(ctx, document);   // the document element's own change (twidget edit 82)
            }
            auto found = m_current.nodes.find(&parent);
            if (found == m_current.nodes.end() || !found->second.element) {
                if (walk) {
                    continue;
                }
                return this->refused("an unmapped node's own change");
            }
            if (isStyleElement(*found->second.element)) {
                reread.insert(&parent);
                continue;
            }
            if (dirtySet.insert(&parent).second) {
                dirtyNodes.push_back(&parent);
                dirty.push_back(&found->second);
            }
            builtAgain.push_back(&node);
        }
        // Walk mode: each node a fresh build now cuts otherwise than the published one joins the plan. One with an entry
        // is built again where it is (with what is under it); one with none that renders is built under its parent; a
        // <style> read again is built again, its sheet cut as a build cuts it.
        if (walk) {
            std::unordered_set<const Node*> folded(builtAgain.begin(), builtAgain.end());
            const auto foldedAbove = [&](Node& node) {
                for (Node* at = node.parent(); at; at = at->parent()) {
                    if (folded.count(at)) {
                        return true;
                    }
                }
                return false;
            };
            const auto fold = [&](Node& node) -> bool {
                Node* parent = node.parent();
                if (!parent || folded.count(&node) || setInPlace.count(&node) || foldedAbove(node)) {
                    return true;
                }
                auto mapped = m_current.nodes.find(&node);
                auto parentEntry = m_current.nodes.find(parent);
                if (parent->type() == NodeType::Document ||
                    (mapped != m_current.nodes.end() && mapped->second.element && isDocumentLevel(*mapped->second.element))) {
                    // The document's html, head and body: their own attributes set in place; their cut, the root built
                    // again (flushRoot).
                    if (mapped == m_current.nodes.end() || !node.isElement()) {
                        return false;
                    }
                    if (std::none_of(ownAttributes.begin(), ownAttributes.end(),
                                     [&](const OwnAttributes& own) { return own.node == &node; })) {
                        OwnAttributes own;
                        own.node = &node;
                        ownAttributes.push_back(std::move(own));
                    }
                    return true;
                }
                // Under a node with no element (unrendered, or itself built again): its own fate decides.
                if (parentEntry == m_current.nodes.end() || !parentEntry->second.element) {
                    return true;
                }
                if (isStyleElement(*parentEntry->second.element)) {
                    reread.insert(parent);
                    return true;
                }
                if (mapped != m_current.nodes.end()) {
                    builtAgain.push_back(&node);
                    folded.insert(&node);
                }
                if (dirtySet.insert(parent).second) {
                    dirtyNodes.push_back(parent);
                    dirty.push_back(&parentEntry->second);
                }
                return true;
            };
            for (const RenderCutNode& decided : cut->nodes) {
                if (decided.differs && !fold(*decided.node)) {
                    return this->flushRoot(ctx, document);
                }
            }
            std::vector<Node*> styles(reread.begin(), reread.end());
            reread.clear();
            for (Node* style : styles) {
                if (m_current.nodes.count(style) && !fold(*style)) {
                    return this->flushRoot(ctx, document);
                }
            }
        }
        // Sibling combinators or positional pseudo-classes: the fork matches again at the commit the other children a rule
        // can reach (twidget edit 90; one positional in its subject alone, edit 42, the UA layer's `body>:first-child`,
        // the reached parent's other children).
        // What the released entries held of the counts. An entry is released once; its node's place in the element map
        // goes with it at the patch.
        uint64_t releasedBoxes = 0;
        uint64_t releasedBytes = 0;
        TextUnits releasedUnits;
        size_t releasedElements = 0;
        size_t releasedForms = 0;
        size_t releasedKeys = 0;
        auto releaseEntry = [&](Node* node) {
            auto entry = m_current.nodes.find(node);
            if (entry == m_current.nodes.end() || !releasedSet.insert(node).second) {
                return;
            }
            released.push_back(node);
            releasedBytes += entry->second.bytes;
            releasedUnits += entry->second.units;
            // twidget edit 81: a <style>'s sheet goes with it, the units it counted and its piece.
            if (auto sheet = m_current.sheets.find(node); sheet != m_current.sheets.end()) {
                releasedUnits += sheet->second.text + sheet->second.strings;
                releasedSheets++;
            }
            if (entry->second.element) {
                releasedBoxes += 1 + entry->second.pieces.size();
                releasedElements++;
                releasedKeys += 1 + entry->second.pieces.size();
                releasedForms += renderIsFormControl(entry->second.element->get_tagName()) ? 1 : 0;
            } else {
                releasedBoxes += entry->second.pieces.size();
                releasedKeys += entry->second.pieces.size();
            }
        };
        // Everything mapped in a litehtml subtree that goes, and in a DOM subtree that goes: a Text that made no pieces
        // (whitespace under a <table>, an empty one) is mapped, and in the render input, with no place in litehtml.
        auto releaseElements = [&](const litehtml::element::ptr& root) {
            std::vector<const litehtml::element*> stack{root.get()};
            while (!stack.empty()) {
                const litehtml::element* element = stack.back();
                stack.pop_back();
                auto mapped = m_current.elements.find(element);
                if (mapped != m_current.elements.end()) {
                    releaseEntry(mapped->second);
                }
                for (const litehtml::element::ptr& child : element->children()) {
                    stack.push_back(child.get());
                }
            }
        };
        auto releaseNodes = [&](Node& root) {
            for (Node* node = &root; node; node = node->nextInTreeOrder(&root)) {
                releaseEntry(node);
            }
        };
        auto insideAny = [&](const litehtml::element::ptr& element, const std::unordered_set<const litehtml::element*>& set) {
            for (litehtml::element::ptr p = element->parent(); p; p = p->parent()) {
                if (set.count(p.get())) {
                    return true;
                }
            }
            return false;
        };
        // 2. What goes. Every removal is planned, and counted, before anything is built: a move from A to B keeps its
        // old element under A until A is reconciled, so B must see it as gone. A node that was mapped and removed in the
        // task (moved, within its parent or out of it, or gone) has a Removed entry: it goes, and is built again where it
        // is now.
        // Each once: walking the cut can build again a node the journal moved.
        std::vector<Node*> goners;
        std::unordered_set<Node*> gone;
        for (const JournalEntry& journaled : m_journal.entries()) {
            if ((journaled.kinds & journalBit(JournalKind::Removed)) != 0 && m_current.nodes.count(journaled.node.get()) &&
                gone.insert(journaled.node.get()).second) {
                goners.push_back(journaled.node.get());
            }
        }
        for (Node* node : builtAgain) {
            if (gone.insert(node).second) {
                goners.push_back(node);
            }
        }
        std::vector<size_t> active;
        // A goner's element, or its pieces (a Text's go together), unless they are inside another's.
        std::unordered_set<const litehtml::element*> removalSet;
        for (Node* node : goners) {
            const RenderEntry& entry = m_current.nodes.find(node)->second;
            if (entry.element) {
                // A <style>'s piece goes with it (twidget edit 81).
                removalSet.insert(entry.element.get());
                removals.push_back(entry.element);
                continue;
            }
            for (const litehtml::element::ptr& piece : entry.pieces) {
                removalSet.insert(piece.get());
                removals.push_back(piece);
            }
        }
        std::vector<litehtml::element::ptr> outermost;
        for (const litehtml::element::ptr& element : removals) {
            if (!insideAny(element, removalSet)) {
                outermost.push_back(element);
            }
        }
        removals.swap(outermost);
        for (const litehtml::element::ptr& element : removals) {
            releaseElements(element);
        }
        for (Node* node : goners) {
            releaseNodes(*node);
        }
        // A dirty parent that goes is built again with what it is in, or is gone.
        for (size_t i = 0; i < dirty.size(); i++) {
            if (!releasedSet.count(dirtyNodes[i])) {
                active.push_back(i);
            }
        }
        // 3. What comes: each DOM child with no element, built from the DOM as it is, within what the rest of the
        // document uses of the limits (Rulings 7, E6, E9): a subtree a fresh build would cut is refused, and the walk
        // of the cut cuts it as the build does.
        totals.bytes = size_t(m_current.bytes - releasedBytes);
        // Profile 1's text units leave with what is released; the node count does not (a released node may stay in the
        // DOM, unrendered), so it stays an upper bound and the subtrees add theirs (V4 plan, Task 7).
        totals.units = m_current.textUnits - releasedUnits;
        totals.nodes = m_current.nodeCount + m_unheardNodes;
        totals.elements = m_current.elementCount - releasedElements;
        totals.formControls = m_current.formControlCount - releasedForms;
        totals.seq = m_current.nextSeq;
        // An element whose own attributes are set in place but that goes with a subtree removed, moved or built again
        // (walking the cut) goes or is built with it.
        ownAttributes.erase(std::remove_if(ownAttributes.begin(), ownAttributes.end(),
                                           [&](const OwnAttributes& own) { return releasedSet.count(own.node) != 0; }),
                            ownAttributes.end());
        // The own attributes set in place (the document's html, head and body, twidget edit 82, and every other kept
        // element; walking the cut, one the walk renders), read as the build reads them (before the subtrees are built:
        // their budgets and units change what is left).
        for (OwnAttributes& own : ownAttributes) {
            Element& element = static_cast<Element&>(*own.node);
            RenderEntry& entry = m_current.nodes.find(own.node)->second;
            auto* tag = dynamic_cast<litehtml::html_tag*>(entry.element.get());
            if (!tag) {
                return this->refused("not an html_tag");
            }
            // The document's html, head or body made another tag (no longer the document's own): the root is replaced.
            if (litehtml::lowcase(renderTagOf(ctx, element).tag) != litehtml::lowcase(tag->get_tagName())) {
                return this->flushRoot(ctx, document);
            }
            // Walking the cut, from the state the walk had before the element (a build's: what it leaves out is left out).
            const auto before = walk ? cutBefore.find(own.node) : cutBefore.end();
            RenderAttributes scanned = before != cutBefore.end()
                                           ? renderElementAttributes(ctx, element, before->second.bytes, before->second.units,
                                                                     keepInput, keepInput ? &own.startTag : nullptr)
                                           : renderElementAttributes(ctx, element, totals.bytes - entry.bytes,
                                                                     totals.units - entry.units, keepInput,
                                                                     keepInput ? &own.startTag : nullptr);
            if (walk ? scanned.overBudget : (scanned.overBudget || scanned.styleTooLong || scanned.textLeftOut)) {
                // The document's html, head or body at a cap: the root is built again, cut as a build cuts it.
                return walk ? this->flushRoot(ctx, document) : this->refused("over a byte, style or text limit");
            }
            // A canvas's size is its twcanvas: source's: a new one is the cut walk's to judge (limit.canvas-pixels).
            if (const auto src = scanned.map.find("src"); !walk && dynamic_cast<const HTMLCanvasElement*>(&element) &&
                                                          (src == scanned.map.end() || src->second != tag->get_attr("src", ""))) {
                return this->refused("a canvas's size changed");
            }
            const litehtml::string_map& current = tag->attributes();
            for (const auto& attribute : scanned.map) {
                own.wanted[litehtml::lowcase(attribute.first)] = attribute.second;
            }
            litehtml::string_map comparable = current;
            comparable.erase("list_index");
            own.changed = comparable != own.wanted;
            totals.bytes = totals.bytes - entry.bytes + scanned.bytes;
            totals.units = totals.units - entry.units + scanned.units;
            own.entry = &entry;
            own.element = entry.element;
            own.bytes = scanned.bytes;
            own.units = scanned.units;
            if (keepInput && entry.inputOffset != kNoRenderInput) {
                own.from = staging.input.size();
                staging.input.append(own.startTag);
                own.to = staging.input.size();
            }
        }
        // The Texts replaced in place, within what the rest of the document leaves them, read as the text path reads
        // them (Ruling 7 and profile 1's text units: past one, a fresh build leaves the Text out, which the walk of the
        // cut plans); one that goes with a subtree built again is built with it.
        ownTexts.erase(std::remove_if(ownTexts.begin(), ownTexts.end(),
                                      [&](const OwnText& own) { return releasedSet.count(own.node) != 0; }),
                       ownTexts.end());
        for (OwnText& own : ownTexts) {
            const RenderEntry& entry = *own.entry;
            const size_t others = totals.bytes - entry.bytes;
            const TextUnits otherUnits = totals.units - entry.units;
            if (others > kMaxRenderBytes || own.utf8.size() > kMaxRenderBytes - others ||
                !renderTextFits(Runtime::from(ctx).limits(), own.units, otherUnits)) {
                return this->refused("over a byte, style or text limit");
            }
            totals.bytes = others + own.utf8.size();
            totals.units = otherUnits + own.units;
            if (keepInput && entry.inputOffset != kNoRenderInput) {
                own.from = staging.input.size();
                staging.input.append(own.escaped);
                own.to = staging.input.size();
            }
        }
        // The staging maps start with room for what goes (a replacement or a move builds about as much again).
        staging.nodes.reserve(released.size());
        staging.elements.reserve(releasedKeys);
        auto build = [&](const RenderSubtreePlace& place, Node& child, std::vector<litehtml::element::ptr>& roots) {
            if (walk) {
                // From the state the walk had before the node; one the walk did not reach is past its stop.
                auto before = cutBefore.find(&child);
                RenderCutState state = before != cutBefore.end() ? before->second : cut->end;
                state.stopped = state.stopped || before == cutBefore.end();
                static_cast<RenderCutState&>(totals) = state;
            }
            return buildRenderSubtree(ctx, m_container, place, child, staging, totals, roots, walk);
        };
        for (size_t i : active) {
            Element& parent = static_cast<Element&>(*dirtyNodes[i]);
            RenderEntry& entry = *dirty[i];
            RenderSubtreePlace place;
            place.document = &document;
            place.parent = &parent;
            place.parentElement = entry.element;
            for (litehtml::element::ptr p = entry.element->parent(); p; p = p->parent()) {
                place.parentDepth++;
            }
            place.rawText = parent.isHTMLElement() && state.hasRawTextChildren(parent.localNameAtom());
            place.silent = entry.inputOffset == kNoRenderInput ||
                           (parent.isHTMLElement() && state.isVoidHTMLElement(parent.localNameAtom()));
            // An insertion's two anchors, each the first kept sibling after it that has one: its place in litehtml (an
            // element or pieces) and its place in the render input. A Text that made no pieces (whitespace under a
            // <table>) has the second and not the first.
            std::vector<size_t> waiting;
            std::vector<size_t> waitingInput;
            for (size_t k = 0; k < parent.childCount(); k++) {
                Node* child = parent.childAt(k);
                auto kept = m_current.nodes.find(child);
                if (kept != m_current.nodes.end() && !releasedSet.count(child)) {
                    const RenderEntry& anchor = kept->second;
                    litehtml::element::ptr at =
                        anchor.element ? anchor.element : (anchor.pieces.empty() ? nullptr : anchor.pieces.front());
                    if (at) {
                        for (size_t w : waiting) {
                            insertions[w].anchor = at;
                        }
                        waiting.clear();
                    }
                    if (anchor.inputOffset != kNoRenderInput) {
                        for (size_t w : waitingInput) {
                            insertions[w].inputAt = anchor.inputOffset;
                        }
                        waitingInput.clear();
                    }
                    continue;
                }
                if (!child->isElement() && child->type() != NodeType::Text) {
                    continue;
                }
                Insertion insertion;
                insertion.parent = entry.element;
                insertion.from = staging.input.size();
                if (!build(place, *child, insertion.roots)) {
                    return walk ? this->flushRoot(ctx, document)
                                : this->refused("a render limit in a built subtree");
                }
                insertion.to = staging.input.size();
                // Nothing to link and nothing in the render input: an element Ruling 4 or its parent's own append leaves
                // out, or an empty Text (mapped, with no pieces). A Text under a parent that takes no text (a <table>'s
                // whitespace, twidget edit 83) has no pieces and is placed in the render input alone.
                if (insertion.roots.empty() && insertion.to == insertion.from) {
                    continue;
                }
                waiting.push_back(insertions.size());
                waitingInput.push_back(insertions.size());
                insertions.push_back(std::move(insertion));
            }
            for (size_t w : waitingInput) {
                insertions[w].inputAt = place.silent ? kNoRenderInput : entry.inputEnd - entry.endTagLength;
            }
        }
        // A Comment (or another node that does not render) inserted under a mapped parent is visited by a build's walk,
        // and counted against the node cap (final review C2): none was built above.
        for (const JournalEntry& journaled : m_journal.entries()) {
            Node* node = journaled.node.get();
            if ((journaled.kinds & journalBit(JournalKind::Inserted)) == 0 || !node->parent()) {
                continue;
            }
            auto parent = m_current.nodes.find(node->parent());
            if (parent == m_current.nodes.end()) {
                continue;
            }
            if (parent->second.element && isStyleElement(*parent->second.element)) {
                // twidget edit 81: nothing a <style> holds is built, and a build's walk counts all of it.
                for (Node* held = node; held; held = held->nextInTreeOrder(node)) {
                    totals.nodes++;
                }
                continue;
            }
            if (!node->isElement() && node->type() != NodeType::Text) {
                totals.nodes++;
            }
        }
        // Walking the cut, the counts are the walk's; else past the node cap, the cut is walked.
        if (walk) {
            static_cast<RenderCutState&>(totals) = cut->end;
        } else if (totals.nodes > kMaxRenderNodes) {
            return this->refused("the node cap");
        }
        // 4. Own changes beside the structure. A node built here, or going (one built again in step 1), is read with
        // its subtree; a kept element's attributes were planned above, and its state change is set in place after them.
        // A <style>'s Text is built again, as its sheet is rewritten. Ruling E25: so does any other node with no entry
        // that a build reads, which an element a parent's appendChild refuses is (a <div> under a <table>: a build
        // scans and byte-counts its attributes, and its bytes can move the budget's cut); only a node outside the main
        // document (detached, or in a template's contents) or under (or itself) an element Ruling 4 leaves out is read
        // by none.
        for (const JournalEntry& journaled : m_journal.entries()) {
            if ((journaled.kinds & kOwn) == 0) {
                continue;
            }
            Node* node = journaled.node.get();
            // A Text replaced in place was planned in step 1.
            if (staging.nodes.count(node) || releasedSet.count(node) ||
                (!node->isElement() && setInPlace.count(node))) {
                continue;
            }
            if (auto kept = m_current.nodes.find(node); kept != m_current.nodes.end()) {
                if (!node->isElement() || !kept->second.element) {
                    return this->refused("refused by can_set_pseudo_classes");
                }
                planUserActionState(ctx, static_cast<Element&>(*node), kept->second.element, statePlan);
                continue;
            }
            auto parent = node->parent() ? m_current.nodes.find(node->parent()) : m_current.nodes.end();
            if (parent != m_current.nodes.end() && parent->second.element && isStyleElement(*parent->second.element)) {
                reread.insert(node->parent());   // twidget edit 81
                continue;
            }
            // A node a build reads that has no entry was cut by a cap: walking the cut, the walk decides.
            if (!walk && this->readByABuild(ctx, *node)) {
                return this->refused("an unmapped node's own change");
            }
        }
        if (!planStateReach(document, statePlan)) {
            return this->refusedBy("refused by can_set_pseudo_classes", document);
        }
        // twidget edit 81: the sheets a fresh build of the patched tree applies, within Ruling 7's 64 KiB and
        // profile 1's budgets in tree order (past one it would post a limit, which only the walk of the cut plans), and each
        // read again placed in the input.
        if (!reread.empty() || !staging.sheets.empty() || releasedSheets > 0) {
            sheetPlan = this->planSheets(ctx, staging, reread, releasedSet, totals.units, walk);
            if (!sheetPlan) {
                return walk ? this->refused("a <style>'s sheet at a cap") : this->refused("a <style>'s sheet at a cap");
            }
            totals.units = sheetPlan->units;
            for (SheetPlan::Change& change : sheetPlan->changes) {
                if (keepInput && change.entry->inputOffset != kNoRenderInput) {
                    change.from = staging.input.size();
                    staging.input.append(change.escaped.data(), change.escaped.size());
                    change.to = staging.input.size();
                }
            }
        }
        // twidget edit 82: nothing a build renders changed (a comment or the doctype beside the document element): the
        // flush is clean, with no patch.
        if (!walk && dirty.empty() && released.empty() && staging.nodes.empty() && removals.empty() && insertions.empty() &&
            statePlan.flips.empty() && !sheetPlan && ownAttributes.empty() && ownTexts.empty() &&
            !m_journal.environmentPending() && totals.nodes == m_current.nodeCount + m_unheardNodes) {
            m_journal.clear();
            return PatchResult::Patched;
        }
        // 5. The fork's predicates, in the order the patch makes the changes, threading what each adds to the caps.
        litehtml::document::structure_growth growth;
        for (const litehtml::element::ptr& element : removals) {
            if (!document.can_remove_subtree(element, &growth)) {
                return this->refusedBy("refused by can_remove_subtree", document);
            }
        }
        for (const Insertion& insertion : insertions) {
            for (const litehtml::element::ptr& root : insertion.roots) {
                if (!document.can_insert_subtree(insertion.parent, 0, root, &growth)) {
                    return this->refusedBy("refused by can_insert_subtree", document);
                }
            }
        }
        // The Texts replaced in place (twidget edit 16), each against the text-piece cap as the session counts it: from
        // the pieces alive when it opens (the new subtrees' among them, and the removals' still), so the growth
        // threaded is the earlier replacements' alone. Each text split again for the count.
        {
            int pendingGrowth = 0;
            for (OwnText& own : ownTexts) {
                int pieceGrowth = 0;
                if (!document.can_replace_text(own.parent, own.first, own.oldCount, own.utf8.c_str(), pendingGrowth,
                                               &pieceGrowth)) {
                    return this->refusedBy("refused by can_replace_text", document);
                }
                own.newCount = size_t(int(own.oldCount) + pieceGrowth);
                pendingGrowth += pieceGrowth;
                textGrowth += pieceGrowth;
            }
        }
        // The elements whose own attributes are set in place matched again where their attributes changed (twidget edit
        // 75 for the document's html, head and body).
        {
            litehtml::document::attribute_growth attributeGrowth;
            for (const OwnAttributes& own : ownAttributes) {
                if (!own.changed) {
                    continue;
                }
                const bool allowed = document.can_set_element_attributes(own.element, own.wanted, &attributeGrowth);
                if (!allowed) {
                    return this->refusedBy("refused by can_set_element_attributes", document);
                }
            }
        }
        // twidget edit 81: each sheet read again asks replace_style_text's cap as the session counts it, in the order
        // the patch replaces them: from the pieces alive when it opens, with the Texts replaced in place before them
        // and the sheets before it.
        if (!walk && sheetPlan) {
            int64_t sheetGrowth = textGrowth;
            for (const SheetPlan::Change& change : sheetPlan->changes) {
                sheetGrowth += int64_t(change.sheet.utf8.empty() ? 0 : 1) - int64_t(change.entry->pieces.size());
                if (document.document_text_pieces() + sheetGrowth > litehtml::document::max_text_elements) {
                    return this->refused("the text-piece cap");
                }
            }
        }
        // 6. What the document will hold.
        boxes = uint64_t(int64_t(m_current.boxes + (sheetPlan ? sheetPlan->addedPieces : 0) - releasedBoxes +
                                 staging.boxes - (sheetPlan ? sheetPlan->removedPieces : 0)) +
                         textGrowth);
        // 7. Everything the patch allocates: map room for what comes, graveyard room for what goes, the render input.
        m_current.nodes.reserve(m_current.nodes.size() + staging.nodes.size());
        m_current.elements.reserve(m_current.elements.size() + staging.elements.size());
        nodeGraveyard.reserve(released.size());
        elementGraveyard.reserve(releasedKeys);
        // twidget edit 81: what the sheets' changes take: spare map nodes for the pieces they add, a place in each entry,
        // and the sheet records' room.
        if (sheetPlan) {
            m_current.elements.reserve(m_current.elements.size() + staging.elements.size() + sheetPlan->addedPieces);
            sheetPool.reserve(sheetPlan->addedPieces + sheetPlan->removedPieces);
            std::vector<char> keys(sheetPlan->addedPieces);
            for (size_t i = 0; i < keys.size(); i++) {
                auto at = m_current.elements.emplace(reinterpret_cast<const litehtml::element*>(&keys[i]), nullptr);
                sheetPool.push_back(m_current.elements.extract(at.first));
            }
            for (SheetPlan::Change& change : sheetPlan->changes) {
                change.entry->pieces.reserve(change.sheet.utf8.empty() ? 0 : 1);
                m_current.sheets.try_emplace(change.node);
            }
            m_current.sheets.reserve(m_current.sheets.size() + staging.sheets.size());
        }
        // The Texts replaced in place: their new pieces' room, and spare map nodes for the pieces they add.
        if (!ownTexts.empty()) {
            size_t surplus = 0;
            size_t replaced = 0;
            for (OwnText& own : ownTexts) {
                own.pieces.reserve(own.newCount);
                own.entry->pieces.reserve(own.newCount);
                surplus += own.newCount > own.oldCount ? own.newCount - own.oldCount : 0;
                replaced += own.oldCount;
            }
            m_current.elements.reserve(m_current.elements.size() + staging.elements.size() +
                                       (sheetPlan ? sheetPlan->addedPieces : 0) + surplus);
            textPool.reserve(surplus + replaced);
            std::vector<char> keys(surplus);
            for (size_t i = 0; i < surplus; i++) {
                auto at = m_current.elements.emplace(reinterpret_cast<const litehtml::element*>(&keys[i]), nullptr);
                textPool.push_back(m_current.elements.extract(at.first));
            }
        }
        if (keepInput) {
            size_t order = 0;
            // The goners' places, a place inside another's left out.
            {
                std::vector<std::pair<size_t, size_t>> ranges;
                for (Node* node : goners) {
                    const RenderEntry& entry = m_current.nodes.find(node)->second;
                    if (entry.inputOffset != kNoRenderInput) {
                        ranges.emplace_back(entry.inputOffset,
                                            entry.element ? entry.inputEnd : entry.inputOffset + entry.inputLength);
                    }
                }
                std::sort(ranges.begin(), ranges.end(), [](const auto& a, const auto& b) {
                    return a.first != b.first ? a.first < b.first : a.second > b.second;
                });
                size_t reach = 0;
                for (const auto& [from, to] : ranges) {
                    if (from < reach) {
                        continue;
                    }
                    patches.push_back({from, to - from, order++, 0, 0, 0});
                    reach = to;
                }
            }
            for (const Insertion& insertion : insertions) {
                if (insertion.inputAt != kNoRenderInput && insertion.to > insertion.from) {
                    patches.push_back({insertion.inputAt, 0, order++, insertion.from, insertion.to, 0});
                }
            }
            // The start tags of the elements whose own attributes are set in place.
            for (const OwnAttributes& own : ownAttributes) {
                if (own.entry->inputOffset != kNoRenderInput) {
                    patches.push_back({own.entry->inputOffset, own.entry->inputLength, order++, own.from, own.to, 0});
                }
            }
            // The text of the Texts replaced in place.
            for (const OwnText& own : ownTexts) {
                if (own.entry->inputOffset != kNoRenderInput) {
                    patches.push_back({own.entry->inputOffset, own.entry->inputLength, order++, own.from, own.to, 0});
                }
            }
            // twidget edit 81: a sheet read again replaces its <style>'s content.
            if (sheetPlan) {
                for (const SheetPlan::Change& change : sheetPlan->changes) {
                    const RenderEntry& entry = *change.entry;
                    if (entry.inputOffset == kNoRenderInput) {
                        continue;
                    }
                    const size_t from = entry.inputOffset + entry.inputLength;
                    patches.push_back({from, entry.inputEnd - entry.endTagLength - from, order++, change.from, change.to, 0});
                }
            }
            std::sort(patches.begin(), patches.end(), [](const StructurePatch& a, const StructurePatch& b) {
                return a.offset != b.offset ? a.offset < b.offset : a.order < b.order;
            });
            size_t from = 0;
            size_t total = m_current.input.size();
            for (const StructurePatch& patch : patches) {
                // Disjoint, or the plan is wrong: a refusal rather than a wrong input.
                if (patch.offset < from || patch.offset + patch.length > m_current.input.size()) {
                    return this->refused("overlapping input patches");
                }
                from = patch.offset + patch.length;
                total = total - patch.length + (patch.to - patch.from);
            }
            newInput.reserve(total);
            from = 0;
            for (StructurePatch& patch : patches) {
                newInput.append(m_current.input.data() + from, patch.offset - from);
                patch.landed = newInput.size();
                newInput.append(staging.input.data() + patch.from, patch.to - patch.from);
                from = patch.offset + patch.length;
            }
            newInput.append(m_current.input.data() + from, m_current.input.size() - from);
            before.assign(patches.size() + 1, 0);
            for (size_t i = 0; i < patches.size(); i++) {
                before[i + 1] = before[i] + ptrdiff_t(patches[i].to - patches[i].from) - ptrdiff_t(patches[i].length);
                if (patches[i].to > patches[i].from) {
                    landing.push_back(&patches[i]);
                }
            }
            std::sort(landing.begin(), landing.end(),
                      [](const StructurePatch* a, const StructurePatch* b) { return a->from < b->from; });
        }
        // The steps the patch's matching may take (kPatchSelectorSteps).
        stepLimit = kPatchSelectorSteps;
    } catch (...) {
        abortForCaughtException(ctx);
    }

    // ---- Patching: from here the published document is changed, and nothing below allocates ours. The plan's
    // predicates said every change would be accepted, so a refusal is a bug with no honest fallback. ----
    MirrorPublish published;
    std::vector<std::string> limits;
    try {
        // The session's limit (a test can cap it below what the plan allowed, to cut it: setPatchStepCapForTesting).
        sessionLimit = std::min(stepLimit, m_patchStepCap);
        StepSession steps(document, sessionLimit, sessionUsed);
        // twidget edits 79, 80: the environment is the session's first change, the root declarations first.
        if (m_journal.environmentPending()) {
            document.change_root_declarations(rootDeclarationsOf(m_container.options()));
            document.environment_changed();
        }
        for (const litehtml::element::ptr& element : removals) {
            if (!document.remove_subtree(element)) {
                this->stopInternally(ctx, "remove_subtree refused");
            }
        }
        for (const Insertion& insertion : insertions) {
            if (insertion.roots.empty()) {
                continue;
            }
            size_t index = insertion.anchor ? childIndex(insertion.parent, insertion.anchor.get()) : endIndex(insertion.parent);
            if (index == ~size_t(0)) {
                this->stopInternally(ctx, "an anchor not found");
            }
            for (const litehtml::element::ptr& root : insertion.roots) {
                if (!document.insert_subtree(insertion.parent, index++, root)) {
                    this->stopInternally(ctx, "insert_subtree refused");
                }
            }
        }
        // The Texts replaced in place (twidget edit 16), after the insertions, so a piece an insertion is anchored at
        // was there to be found; the old pieces' map nodes go to the new ones.
        for (OwnText& own : ownTexts) {
            RenderEntry& entry = *own.entry;
            const size_t first = childIndex(own.parent, entry.pieces[0].get());
            if (first == ~size_t(0) ||
                !document.replace_text(own.parent, first, own.oldCount, own.utf8.c_str(), own.pieces)) {
                this->stopInternally(ctx, "replace_text refused");
            }
            for (const litehtml::element::ptr& old : entry.pieces) {
                textPool.push_back(m_current.elements.extract(old.get()));
            }
            entry.pieces.clear();
            for (const litehtml::element::ptr& piece : own.pieces) {
                entry.pieces.push_back(piece);
                auto handle = std::move(textPool.back());
                textPool.pop_back();
                handle.key() = piece.get();
                handle.mapped() = own.node;
                m_current.elements.insert(std::move(handle));
            }
        }
        // twidget edit 81: each sheet read again, its <style>'s piece replaced; the commit applies the sheets.
        if (sheetPlan) {
            for (SheetPlan::Change& change : sheetPlan->changes) {
                if (!document.replace_style_text(change.entry->element, change.sheet.utf8, change.pieces)) {
                    this->stopInternally(ctx, "replace_style_text refused");
                }
            }
        }
        // The own attributes set in place (twidget edit 82 for the document's html, head and body).
        for (const OwnAttributes& own : ownAttributes) {
            if (own.changed && !document.set_element_attributes(own.element, own.wanted)) {
                this->stopInternally(ctx, "set_element_attributes refused");
            }
        }
        if (!statePlan.flips.empty() && !document.set_pseudo_classes(statePlan.flips)) {
            this->stopInternally(ctx, "set_pseudo_classes refused");
        }
        // The maps. What went moves to the graveyards (freed after the publish), the kept entries' places move with the
        // patches, and what came takes its place from its patch. A node built again (moved, or built again where it is)
        // keeps its key, as one a replaced document element keeps (Task 10b).
        for (auto& [node, entry] : staging.nodes) {
            if (auto kept = m_current.nodes.find(node); kept != m_current.nodes.end()) {
                entry.key = kept->second.key;
            }
        }
        for (Node* node : released) {
            auto handle = m_current.nodes.extract(node);
            if (handle.empty()) {
                continue;
            }
            const RenderEntry& entry = handle.mapped();
            // Its generated elements' keys go with it, unless it is built again (a move) and keeps its key.
            if (entry.key && !staging.nodes.count(node)) {
                forgetGeneratedKeys(entry.key);
            }
            if (entry.element) {
                elementGraveyard.push_back(m_current.elements.extract(entry.element.get()));
            }
            for (const litehtml::element::ptr& piece : entry.pieces) {
                elementGraveyard.push_back(m_current.elements.extract(piece.get()));
            }
            nodeGraveyard.push_back(std::move(handle));
        }
        // twidget edit 81: the sheets' pieces and records as the patch leaves them.
        if (sheetPlan) {
            for (SheetPlan::Change& change : sheetPlan->changes) {
                RenderEntry& entry = *change.entry;
                for (const litehtml::element::ptr& old : entry.pieces) {
                    sheetPool.push_back(m_current.elements.extract(old.get()));
                }
                entry.pieces.clear();
                for (const litehtml::element::ptr& piece : change.pieces) {
                    auto handle = std::move(sheetPool.back());
                    sheetPool.pop_back();
                    handle.key() = piece.get();
                    handle.mapped() = change.node;
                    m_current.elements.insert(std::move(handle));
                    entry.pieces.push_back(piece);
                }
                m_current.sheets.find(change.node)->second = std::move(change.sheet);
            }
            for (Node* node : released) {
                m_current.sheets.erase(node);
            }
            while (!staging.sheets.empty()) {
                m_current.sheets.insert(staging.sheets.extract(staging.sheets.begin()));
            }
            m_current.styleSheets.swap(sheetPlan->applied);
            m_current.usesUserActionPseudo = sheetPlan->usesUserActionPseudo;
        }
        if (keepInput) {
            for (auto& [node, entry] : m_current.nodes) {
                if (entry.inputOffset != kNoRenderInput) {
                    // An insertion at an entry's start goes before it (it is the anchor); a removal starts at none.
                    size_t i = size_t(std::lower_bound(patches.begin(), patches.end(), entry.inputOffset,
                                                       [](const StructurePatch& p, size_t at) { return p.offset < at; }) -
                                      patches.begin());
                    while (i < patches.size() && patches[i].offset == entry.inputOffset && patches[i].length == 0) {
                        i++;
                    }
                    entry.inputOffset = size_t(ptrdiff_t(entry.inputOffset) + before[i]);
                }
                if (entry.element && entry.inputEnd != kNoRenderInput) {
                    // One at an element's end belongs to what follows it.
                    const size_t i = size_t(std::lower_bound(patches.begin(), patches.end(), entry.inputEnd,
                                                             [](const StructurePatch& p, size_t at) { return p.offset < at; }) -
                                            patches.begin());
                    entry.inputEnd = size_t(ptrdiff_t(entry.inputEnd) + before[i]);
                }
            }
        }
        // A start lies in the patch whose staging text holds it; an end in the one it ends inside (two can touch).
        auto landStart = [&](size_t at) {
            auto it = std::upper_bound(landing.begin(), landing.end(), at,
                                       [](size_t value, const StructurePatch* p) { return value < p->from; });
            const StructurePatch* patch = *(it - 1);
            return patch->landed + (at - patch->from);
        };
        auto landEnd = [&](size_t at) {
            auto it = std::lower_bound(landing.begin(), landing.end(), at,
                                       [](const StructurePatch* p, size_t value) { return p->to < value; });
            const StructurePatch* patch = *it;
            return patch->landed + (at - patch->from);
        };
        while (!staging.nodes.empty()) {
            auto handle = staging.nodes.extract(staging.nodes.begin());
            RenderEntry& entry = handle.mapped();
            if (keepInput && entry.inputOffset != kNoRenderInput) {
                entry.inputOffset = landStart(entry.inputOffset);
                if (entry.element && entry.inputEnd != kNoRenderInput) {
                    entry.inputEnd = landEnd(entry.inputEnd);
                }
            }
            m_current.nodes.insert(std::move(handle));
        }
        while (!staging.elements.empty()) {
            m_current.elements.insert(staging.elements.extract(staging.elements.begin()));
        }
        if (keepInput) {
            m_current.input.swap(newInput);
        }
        m_current.boxes = boxes;
        m_current.bytes = totals.bytes;
        m_current.textUnits = totals.units;
        m_current.nodeCount = totals.nodes;
        m_unheardNodes = 0;
        m_current.elementCount = totals.elements;
        m_current.formControlCount = totals.formControls;
        m_current.nextSeq = totals.seq;
        for (const OwnAttributes& own : ownAttributes) {
            own.entry->bytes = own.bytes;
            own.entry->units = own.units;
            if (keepInput && own.entry->inputOffset != kNoRenderInput) {
                own.entry->inputLength = own.startTag.size();
            }
        }
        for (const OwnText& own : ownTexts) {
            own.entry->bytes = own.utf8.size();
            own.entry->units = own.units;
            if (keepInput && own.entry->inputOffset != kNoRenderInput) {
                own.entry->inputLength = own.escaped.size();
            }
        }
        // Twidget edit 84: near a cap the commit replays the style pass, within the patch's step limit.
        document.set_replay_step_limit(this->replayStepLimit(ctx));
        document.commit_patch();
        // The steps the matching took, a replay's (twidget edit 84) included.
        const int64_t used = steps.close();
        // Cut by the patch's step limit: a fresh build would cut elsewhere, or not at all, and no other build follows,
        // so the widget stops (stopInternally).
        if (this->ownSteps(ctx, document, used) > sessionLimit) {
            this->stopInternally(ctx, "a patch's matching cut at its selector-step limit");
        }
        m_current.stepCut = false; // the commit replayed a cut boot's matching (twidget edit 84)
        m_lastPatchSteps = used;
        m_current.naturalWidth =
            double(document.render(litehtml::pixel_t(float(m_container.options().width))).value());
        if (walk) {
            limits = cut->limits;
        }
        this->styleLimits(document, limits);
        // Task 10b: the operations the fork's reports give (every structural patch replaces a render subtree, which the
        // mirror places again), the painted canvases with them.
        this->reportRepaints();
        published = publishPatch();
        m_container.prune(document);
    } catch (const LayerMirror::Inconsistent& inconsistent) {
        this->stopInternally(ctx, inconsistent.what());
    } catch (...) {
        abortForCaughtException(ctx);
    }
    installPatch(published);
    m_patchCount++;
    m_journal.clear();
    // The walk's limits when the flush walked the cut (RenderCut.h), then the style pass's.
    m_current.walkLimits = walk ? cut->limits.size() : 0;
    this->publishLimits(ctx, std::move(limits));
    // The graveyards go here, after the publish: the released nodes and the elements of what went.
    return PatchResult::Patched;
}

// Task 10b.

SelectableText RenderTree::selectableText(double visibleHeight) {
    if (!m_current.document) {
        return SelectableText{};
    }
    SelectableTextSource source;
    source.root = m_current.document->root().get();
    source.keyOf = [this](const litehtml::element& element) { return this->keyOf(element); };
    source.caretOffsets = [this](litehtml::uint_ptr font, std::string_view utf8) {
        return m_container.caretOffsets(font, utf8);
    };
    source.visibleHeight = visibleHeight;
    return exportSelectableText(source);
}

NodeKey RenderTree::keyOf(const litehtml::element& element) {
    RenderBuild& build = m_keyBuild ? *m_keyBuild : m_current;
    auto mapped = build.elements.find(&element);
    if (mapped == build.elements.end()) {
        return generatedKeyOf(element);
    }
    Node* node = mapped->second;
    auto entry = build.nodes.find(node);
    if (entry == build.nodes.end()) {
        return 0;
    }
    if (!entry->second.key && &build != &m_current) {
        auto previous = m_current.nodes.find(node);
        if (previous != m_current.nodes.end()) {
            entry->second.key = previous->second.key;
        }
    }
    if (!entry->second.key) {
        entry->second.key = m_nextKey++;
    }
    return entry->second.key;
}

// A generated element (::before, ::after, a form control's lh-* part: twidget's, mapped to no node) by its owner's key
// and its tag; anything else unmapped (a generated element's text pieces, which selectable text skips by their key 0,
// an anonymous box's element) has none.
NodeKey RenderTree::generatedKeyOf(const litehtml::element& element) {
    const char* tag = element.get_tagName();
    const bool generated = element.tag() == litehtml::__tag_before_ || element.tag() == litehtml::__tag_after_ ||
                           (tag && std::strncmp(tag, "lh-", 3) == 0);
    const litehtml::element::ptr owner = generated ? element.parent() : nullptr;
    const NodeKey ownerKey = owner ? keyOf(*owner) : 0;
    if (!ownerKey) {
        return 0;
    }
    auto [at, made] = m_generatedKeys.try_emplace({ownerKey, int(element.tag())}, 0);
    if (made) {
        at->second = m_nextKey++;
    }
    return at->second;
}

void RenderTree::forgetGeneratedKeys(NodeKey owner) {
    m_generatedKeys.erase(m_generatedKeys.lower_bound({owner, std::numeric_limits<int>::min()}),
                          m_generatedKeys.upper_bound({owner, std::numeric_limits<int>::max()}));
}

NodeKey RenderTree::ownerKeyOfGenerated(NodeKey key) const {
    for (const auto& [slot, generated] : m_generatedKeys) {
        if (generated == key) {
            return slot.first;
        }
    }
    return 0;
}

std::unique_ptr<LayerMirror> RenderTree::newMirror() {
    return std::make_unique<LayerMirror>([this](const litehtml::element& element) { return this->keyOf(element); },
                                         m_nextLayerId);
}

RenderTree::MirrorPublish RenderTree::publishPatch() {
    if (!m_mirror) {
        throw LayerMirror::Inconsistent("a patch with no mirror");
    }
    MirrorPublish out;
    out.replaced = m_mirror->replacedSubtrees();
    LayerMirror::Publish ops = m_mirror->publish();
    out.tree = std::move(ops.tree);
    out.changed = std::move(ops.changedRects);
    out.ops = std::move(ops.ops);
    return out;
}

// Out of memory here is fatal at the facade (M1d), like any allocation of the flush.
RenderTree::PatchResult RenderTree::refusedBy(const char* predicate, const litehtml::document& document) {
    m_refusal = predicate;
    m_refusalReason = document.refusal();
    return PatchResult::Refused;
}

void RenderTree::publishLimits(JSContext* ctx, std::vector<std::string> next) {
    std::vector<std::string> kinds;
    for (std::string& kind : next) {
        if (std::find(kinds.begin(), kinds.end(), kind) == kinds.end()) {
            kinds.push_back(std::move(kind));
        }
    }
    std::vector<std::string> previous;
    previous.swap(m_current.limits);
    m_current.limits = std::move(kinds);
    for (const std::string& kind : m_current.limits) {
        if (std::find(previous.begin(), previous.end(), kind) == previous.end()) {
            Runtime::from(ctx).host().diagnostic("render-limit", kind);
        }
    }
}

// Nothing here throws.
void RenderTree::installPatch(MirrorPublish& published) {
    m_tree.swap(published.tree);
    m_changedRects.swap(published.changed);
    this->accumulateChangedRects();
    m_layerOps.swap(published.ops);
    m_subtreeReplacements += published.replaced;
}

void RenderTree::stopInternally(JSContext* ctx, const char* why) {
    Runtime& runtime = Runtime::from(ctx);
    try {
        runtime.host().diagnostic("render-internal", why);
    } catch (...) {
    }
    runtime.stop(StopReason::Internal);
    throw Aborted{};
}

std::shared_ptr<const LayerTree> RenderTree::freshMirrorForTesting() {
    if (!m_current.document) {
        return nullptr;
    }
    SnapScope snap(m_container.options().pixelSnapScale);
    LayerId ids = LayerId(1) << 62;
    LayerMirror mirror([this](const litehtml::element& element) { return this->keyOf(element); }, ids);
    return mirror.build(*m_current.document, m_container, false);
}

std::shared_ptr<const LayerTree> RenderTree::recordForTesting() {
    SnapScope snap(m_container.options().pixelSnapScale);
    return m_current.document ? m_container.record(*m_current.document) : nullptr;
}

void RenderTree::userActionStateChanged(Element* anchor) {
    // A rendered <button> takes the UA sheet's pressed opacity (button:not([disabled]):active, the profile's UA sheet),
    // whatever the widget's own CSS mentions (fidelity plan, Task 3).
    if (!anchor || !m_current.document || !m_journal.built() ||
        !(m_current.usesUserActionPseudo || m_current.formControlCount > 0)) {
        return;
    }
    // :hover and :active hold on the target's inclusive ancestors (UserActions).
    for (Node* node = anchor; node; node = node->parent()) {
        try {
        } catch (...) {
            abortForCaughtException(m_ctx);
        }
        if (node->isElement() && m_current.nodes.count(node)) {
            this->record(*node, JournalKind::State);
        }
    }
}

std::optional<ContentSize> RenderTree::contentSize() const {
    if (!m_current.document) {
        return std::nullopt;
    }
    return ContentSize{m_current.naturalWidth, double(m_current.document->height())};
}

bool RenderTree::readByABuild(JSContext* ctx, Node& node) const {
    for (Node* at = &node; at; at = at->parent()) {
        if (at->isElement() && (renderElementIsUnrendered(ctx, static_cast<const Element&>(*at)) ||
                                this->refusedByParent(ctx, static_cast<const Element&>(*at)))) {
            return false;
        }
        if (!at->parent()) {
            return at == m_document.get();
        }
    }
    return false;
}

int64_t RenderTree::replayStepLimit(JSContext* ctx) const {
    return std::min(kPatchSelectorSteps, m_patchStepCap);
}

int64_t RenderTree::ownSteps(JSContext* ctx, const litehtml::document& document, int64_t used) {
    if (document.last_replay_cut()) {
        this->stopInternally(ctx, "a replay cut at its selector-step limit");
    }
    return used - document.last_replay_steps();
}

void RenderTree::styleLimits(const litehtml::document& document, std::vector<std::string>& limits) {
    for (const std::string& kind : document.style_pass_limits()) {
        limits.push_back(kind == "text" ? "text-pieces" : kind == "table" ? "table-cells" : kind);
    }
}

bool RenderTree::refusedByParent(JSContext* ctx, const Element& element) const {
    Node* parent = element.parent();
    auto found = parent ? m_current.nodes.find(parent) : m_current.nodes.end();
    if (found == m_current.nodes.end() || !found->second.element) {
        return false;
    }
    return !renderParentAccepts(*found->second.element, renderTagOf(ctx, element).tag);
}

void RenderTree::flushForQuery(JSContext* ctx) {
    if (Runtime::from(ctx).stopReason() != StopReason::None) {
        throw Aborted{};
    }
    {
        // A layout query's flush is the query's time (widget-sandbox's 100 ms per task, Runtime::queryBudgetSpent).
        Runtime::RenderScope queryScope(Runtime::from(ctx), true);
        this->flush(ctx);
    }
    // limit.batch: a layout query ends the batch, as upstream's shim flushes its operations before one.
    Runtime::from(ctx).startBatch();
}

void RenderTree::setWidth(JSContext* ctx, double width) {
    if (Runtime::from(ctx).stopReason() != StopReason::None || width == m_container.options().width) {
        return;
    }
    RenderOptions options = m_container.options();
    options.width = width;
    m_container.setOptions(std::move(options));
    m_journal.markEnvironment(); // twidget edit 79: the next flush applies it in its patch
}

void RenderTree::setTheme(JSContext* ctx, Theme theme, std::string rootDeclarations) {
    if (Runtime::from(ctx).stopReason() != StopReason::None ||
        (theme == m_container.options().theme && rootDeclarations == m_container.options().rootDeclarations)) {
        return;
    }
    RenderOptions options = m_container.options();
    options.theme = theme;
    options.rootDeclarations = std::move(rootDeclarations);
    m_container.setOptions(std::move(options));
    m_journal.markEnvironment(); // twidget edit 80
}

void RenderTree::setContentSafeArea(JSContext* ctx, std::string declarations) {
    if (Runtime::from(ctx).stopReason() != StopReason::None || declarations == m_container.options().contentSafeAreaDeclarations) {
        return;
    }
    RenderOptions options = m_container.options();
    options.contentSafeAreaDeclarations = std::move(declarations);
    m_container.setOptions(std::move(options));
    m_journal.markEnvironment(); // twidget edit 80: the root declarations change in place, as the theme's
}

void RenderTree::setReducedMotion(JSContext* ctx, bool reduced) {
    if (Runtime::from(ctx).stopReason() != StopReason::None || reduced == m_container.options().reducedMotion) {
        return;
    }
    RenderOptions options = m_container.options();
    options.reducedMotion = reduced;
    m_container.setOptions(std::move(options));
    m_journal.markEnvironment(); // twidget edit 79
}

void RenderTree::canvasPainted(const Element& canvas) {
    if (!this->rendered(&canvas) || !m_journal.built()) {
        return;
    }
    if (m_paintedCanvasSet.count(&canvas) != 0) {
        return;
    }
    try {
        m_paintedCanvases.push_back(Ref<Element>::retain(m_ctx, const_cast<Element*>(&canvas)));
        m_paintedCanvasSet.insert(&canvas);
    } catch (...) {
        abortForCaughtException(m_ctx);
    }
}

bool RenderTree::rendered(const Node* node) const {
    return node && (node == m_document.get() || m_current.nodes.count(const_cast<Node*>(node)) != 0);
}

void RenderTree::record(Node& node, JournalKind kind) {
    try {
        m_journal.record(m_ctx, node, kind);
    } catch (...) {
        // The memory limit: latched, and Aborted unwinds the mutation.
        abortForCaughtException(m_ctx);
    }
}

// Each callback first asks whether the boot has built (before it there is nothing to record), and then whether the
// change touches the rendered tree (the file comment in RenderTree.h).

void RenderTree::nodeInserted(Node& node) {
    if (!m_journal.built()) {
        return;
    }
    if (this->rendered(node.parent())) {
        this->record(node, JournalKind::Inserted);
        this->noteAutoDirection(node.parent());
        return;
    }
    // dir=auto reads text the renderer does not draw (review minors, Task 2).
    this->noteAutoDirection(node.parent());
    // Not heard by the journal (an element no build renders), yet counted by a build against profile 1's node cap
    // (V4 plan, Task 7; final review C2): kept as an upper bound beside the published count.
    if (!m_current.document) {
        return;
    }
    try {
        if (!inDocument(node, m_document.get())) {
            return;
        }
        m_unheardNodes += nodesForTheCap(m_ctx, node);
    } catch (...) {
        // A failure: latched, and Aborted unwinds the mutation.
        abortForCaughtException(m_ctx);
    }
    if (m_current.nodeCount + m_unheardNodes > kMaxRenderNodes) {
        m_journal.markCut();
    }
}

void RenderTree::nodeRemoved(Node& node, Node& oldParent) {
    // The user-action state follows the tree (M1d plan, Task 3): it may journal a state change before the entry below.
    if (HostState* host = HostState::find(m_ctx)) {
        host->userActions().nodeRemoved(m_ctx, node, oldParent);
    }
    if (m_journal.built() && (this->rendered(&node) || this->rendered(&oldParent))) {
        this->record(node, JournalKind::Removed);
    } else if (m_journal.built() && m_current.document &&
               std::find(m_current.limits.begin(), m_current.limits.end(), "nodes") != m_current.limits.end()) {
        // Not heard by the journal (an element no build renders), yet counted by a build against the node cap: with the
        // published build cut there, what the cut dropped may fit now.
        try {
            if (inDocument(oldParent, m_document.get())) {
                m_journal.markCut();
            }
        } catch (...) {
            // The memory limit: latched, and Aborted unwinds the mutation.
            abortForCaughtException(m_ctx);
        }
    }
    // dir=auto reads text the renderer does not draw (review minors, Task 2).
    this->noteAutoDirection(&oldParent);
}

void RenderTree::childrenChanged(Node& parent) {
    if (m_journal.built() && this->rendered(&parent)) {
        this->record(parent, JournalKind::Children);
    }
}

void RenderTree::attributeChanged(Element& element, JSAtom localName, Namespace ns) {
    // An animated element's underlying values come from its inline style (final review M8): a change of it samples the
    // element again at the next flush, whatever the journal does.
    if (ns == Namespace::None && localName == DOMState::of(m_ctx).name(Name::style)) {
        if (animation::AnimationState* animations = animation::AnimationState::find(m_ctx)) {
            animations->styleAttributeChanged(element);
        }
    }
    // Ruling 13: an element with no parent is the parser's or a clone's, being built.
    if (element.parent() == nullptr || !m_journal.built()) {
        return;
    }
    if (this->rendered(&element) || this->rendered(element.parent())) {
        this->record(element, JournalKind::Attribute);
        m_domAttributeChanges.insert(&element);
    }
    // An element's own dir takes its text out of its dir=auto ancestor's resolution, and back in (review minors, Task 2).
    if (ns == Namespace::None && localName == DOMState::of(m_ctx).name(Name::dir)) {
        this->noteAutoDirection(element.parent());
    }
}

void RenderTree::animatedStyleChanged(Element& element) {
    if (element.parent() == nullptr || !m_journal.built()) {
        return;
    }
    if (this->rendered(&element) || this->rendered(element.parent())) {
        this->record(element, JournalKind::Attribute);
    }
}

void RenderTree::characterDataChanged(Node& node) {
    // Only Text renders: a Comment's, a CDATA section's or a processing instruction's data never does.
    if (node.type() != NodeType::Text || !m_journal.built()) {
        return;
    }
    if (this->rendered(&node) || this->rendered(node.parent())) {
        this->record(node, JournalKind::Text);
    }
    // dir=auto reads text the renderer does not draw (review minors, Task 2).
    this->noteAutoDirection(node.parent());
}

void RenderTree::noteAutoDirection(Node* from) {
    DOMState& state = DOMState::of(m_ctx);
    for (Node* node = from; node && m_journal.built(); node = node->parent()) {
        if (node->type() != NodeType::Element) {
            continue;
        }
        auto& element = static_cast<Element&>(*node);
        try {
            if (!element.isHTMLElement()) {
                continue;
            }
            const JSAtom local = element.localNameAtom();
            if (local == state.name(Name::script) || local == state.name(Name::style) || local == state.name(Name::textarea)) {
                return;
            }
            // Compared, never copied: a value or a name of any length costs what a short one does (final review C1).
            const std::optional<String> dir = element.attributeValue(m_ctx, state.name(Name::dir));
            if (!dir) {
                if (String::fromAtom(m_ctx, local).equalsASCII("bdi")) {
                    return;
                }
                continue;
            }
            const bool automatic = dir->equalsIgnoringASCIICase("auto");
            if (automatic && (this->rendered(&element) || this->rendered(element.parent()))) {
                this->record(element, JournalKind::Attribute);
            }
            if (automatic || dir->equalsIgnoringASCIICase("ltr") || dir->equalsIgnoringASCIICase("rtl")) {
                return;
            }
        } catch (const Aborted&) {
            throw;
        } catch (...) {
            abortForCaughtException(m_ctx);
        }
    }
}

RenderTree& installRender(JSContext* ctx, RenderHost& host, RenderOptions options) {
    HostState& state = HostState::of(ctx);
    state.setInitialTheme(options.theme);
    options.rootDeclarations = themeRootDeclarations(state.themeParams(), options.theme, state.buttonTokens(), state.textTokens());
    options.contentSafeAreaDeclarations = contentSafeAreaRootDeclarations(state.contentSafeArea());
    state.setRender(std::make_unique<RenderTree>(ctx, host, std::move(options)));
    return *state.render();
}

} // namespace wr
