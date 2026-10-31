#include "Sources/Render/Builder.h"
#include "Sources/Render/RenderCut.h"

#include <algorithm>
#include <string_view>
#include <unordered_set>

#include <litehtml.h>
#include <litehtml/telegram_master_css.h>

#include "Generated/Bindings.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/Canvas/CanvasElement.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/CSSPolicy.h"
#include "Sources/Host/ICU.h"
#include "Sources/Host/MarkupPolicy.h"
#include "Sources/Host/Profile.h"
#include "Sources/Render/CSSRuleCount.h"
#include "Sources/Render/WidgetContainer.h"
#include "Sources/Runtime/LimitStops.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Callbacks.h"

namespace wr {

namespace {

// Whether CSS text names a user-action pseudo-class, ASCII case-insensitively (M1d plan, Task 3). A false positive (in
// a comment, a string) only costs a patch on a state change.
bool mentionsUserActionPseudo(const std::string& css) {
    static constexpr const char* kNames[] = {":hover", ":active", ":focus"};
    for (size_t i = 0; i < css.size(); i++) {
        if (css[i] != ':') {
            continue;
        }
        for (const char* name : kNames) {
            size_t n = 0;
            while (name[n] && i + n < css.size()) {
                char c = css[i + n];
                if (c >= 'A' && c <= 'Z') {
                    c = char(c - 'A' + 'a');
                }
                if (c != name[n]) {
                    break;
                }
                n++;
            }
            if (!name[n]) {
                return true;
            }
        }
    }
    return false;
}

// litehtml's pseudo-classes of a new element from the user-action state (UserActions): :hover and :active are
// litehtml's own ids, :focus and :focus-within match through the element's pseudo-class set (css_selector.cpp).
void syncUserActionState(JSContext* ctx, Element& element, litehtml::element& created) {
    ElementState* state = DOMState::of(ctx).elementState();
    if (state->hovered(ctx, element)) {
        created.set_pseudo_class(litehtml::_hover_, true);
    }
    if (state->active(ctx, element)) {
        created.set_pseudo_class(litehtml::_active_, true);
    }
    if (state->focused(ctx, element)) {
        created.set_pseudo_class(litehtml::_id("focus"), true);
    }
    if (state->focusWithin(ctx, element)) {
        created.set_pseudo_class(litehtml::_id("focus-within"), true);
    }
}


// Ruling 7 (kMaxStyleText is Builder.h's).
constexpr size_t kMaxStyleAttribute = 16 * 1024;

char asciiLower(char c) {
    return c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c;
}

bool equalsIgnoringASCIICase(std::string_view a, std::string_view b) {
    return a.size() == b.size() && std::equal(a.begin(), a.end(), b.begin(), [](char x, char y) {
               return asciiLower(x) == asciiLower(y);
           });
}

// The control litehtml makes of a rendered tag (el_button) that Ruling E6 counts.
bool isFormControl(std::string_view renderedTag) {
    return equalsIgnoringASCIICase(renderedTag, "button");
}

bool isRootName(std::string_view lowered) {
    return lowered == "html" || lowered == "head" || lowered == "body";
}

litehtml::document_mode modeOf(DocumentMode mode) {
    switch (mode) {
    case DocumentMode::NoQuirks:
        return litehtml::no_quirks_mode;
    case DocumentMode::Quirks:
        return litehtml::quirks_mode;
    case DocumentMode::LimitedQuirks:
        return litehtml::limited_quirks_mode;
    }
    return litehtml::no_quirks_mode;
}

// `s` as UTF-8 for the parser (a lone surrogate becomes U+FFFD, as gumbo would make it) when it is at most `maxBytes`
// long; false, converting only up to the limit, when it is longer. A UTF-16 length is a lower bound of the UTF-8 one.
// litehtml takes C strings: it gets a string up to its first NUL, and so does the render input. (The parser never puts a
// NUL in a document; script can.)
bool utf8AtMost(const String& s, size_t maxBytes, std::string& out) {
    if (s.length() > maxBytes) {
        return false;
    }
    bool cut = false;
    out = s.utf8Prefix(maxBytes, &cut, true);
    if (cut) {
        return false;
    }
    if (size_t nul = out.find('\0'); nul != std::string::npos) {
        out.resize(nul);
    }
    return true;
}

// HTML's "escaping a string" over UTF-8, as the Serializer's escapedUnits does over UTF-16: &, U+00A0 (C2 A0), < and >
// in both modes; " in attribute mode too. C2 is never a continuation byte, so C2 A0 is always U+00A0.
template <class Out>
void appendEscaped(Out& out, std::string_view utf8, bool attributeMode) {
    size_t written = 0;
    for (size_t i = 0; i < utf8.size(); i++) {
        std::string_view entity;
        size_t length = 1;
        switch (static_cast<unsigned char>(utf8[i])) {
        case '&':
            entity = "&amp;";
            break;
        case '<':
            entity = "&lt;";
            break;
        case '>':
            entity = "&gt;";
            break;
        case '"':
            if (attributeMode) {
                entity = "&quot;";
            }
            break;
        case 0xC2:
            if (i + 1 < utf8.size() && static_cast<unsigned char>(utf8[i + 1]) == 0xA0) {
                entity = "&nbsp;";
                length = 2;
            }
            break;
        default:
            break;
        }
        if (!entity.empty()) {
            out.append(utf8.data() + written, i - written);
            out.append(entity.data(), entity.size());
            written = i + length;
            i += length - 1;
        }
    }
    out.append(utf8.data() + written, utf8.size() - written);
}

void noteLimit(std::vector<std::string>& limits, std::string_view kind) {
    if (std::find(limits.begin(), limits.end(), kind) == limits.end()) {
        limits.emplace_back(kind);
    }
}

/// An atom as UTF-8, converted once per user (the DOM holds every atom it is asked for while the build runs).
class AtomNames {
public:
    explicit AtomNames(JSContext* ctx) : m_ctx(ctx) {}

    const std::string& name(JSAtom atom) {
        auto found = m_names.find(atom);
        if (found == m_names.end()) {
            String s = String::fromAtom(m_ctx, atom);
            found = m_names.emplace(atom, s.utf8ForParse()).first;
        }
        return found->second;
    }

private:
    JSContext* m_ctx;
    std::unordered_map<JSAtom, std::string> m_names;
};

/// HTML's dir=auto (fidelity plan, Task 11): the direction of the first character of bidi class L, R or AL among the
/// element's descendant text, in tree order, skipping bdi, script, style and textarea elements and every element with a
/// dir of its own (ltr, rtl or auto, in any case); ltr when there is none.
std::string_view autoDirection(JSContext* ctx, AtomNames& names, DOMState& state, Element& element) {
    // Compared, never copied: a value of any length costs what a short one does (final review C1).
    const auto ownDirection = [&](Element& e) {
        const std::optional<String> dir = e.attributeValue(ctx, state.name(Name::dir));
        return dir && (dir->equalsIgnoringASCIICase("ltr") || dir->equalsIgnoringASCIICase("rtl") ||
                       dir->equalsIgnoringASCIICase("auto"));
    };
    Node* node = element.firstChildNode();
    while (node) {
        bool descend = true;
        if (node->type() == NodeType::Element) {
            auto& child = static_cast<Element&>(*node);
            const std::string& local = names.name(child.localNameAtom());
            descend = !(child.isHTMLElement() && (local == "bdi" || local == "script" || local == "style" || local == "textarea")) &&
                      !ownDirection(child);
        } else if (node->type() == NodeType::Text) {
            const String data = static_cast<CharacterData&>(*node).dataString(ctx);
            const JSStringView view = data.view();
            for (uint32_t i = 0; i < view.length; i++) {
                UChar32 c = view.utf16 ? view.utf16[i] : view.latin1[i];
                if (view.utf16 && U16_IS_LEAD(c) && i + 1 < view.length && U16_IS_TRAIL(view.utf16[i + 1])) {
                    c = U16_GET_SUPPLEMENTARY(c, view.utf16[i + 1]);
                    i++;
                }
                const UCharDirection direction = u_charDirection(c);
                if (direction == U_LEFT_TO_RIGHT || direction == U_RIGHT_TO_LEFT || direction == U_RIGHT_TO_LEFT_ARABIC) {
                    return direction == U_LEFT_TO_RIGHT ? "ltr" : "rtl";
                }
            }
            descend = false;
        } else {
            descend = false;
        }
        if (descend && node->firstChildNode()) {
            node = node->firstChildNode();
            continue;
        }
        while (node != &element && !node->nextSiblingNode()) {
            node = node->parent();
        }
        node = node == &element ? nullptr : node->nextSiblingNode();
    }
    return "ltr";
}

/// The attribute's qualified name, which litehtml is given (Ruling 4).
std::string qualifiedAttributeName(AtomNames& names, const Attribute& attribute) {
    if (attribute.prefix.atom == JS_ATOM_NULL) {
        return names.name(attribute.localName.atom);
    }
    return names.name(attribute.prefix.atom) + ":" + names.name(attribute.localName.atom);
}

/// What the renderer's copy of `element` is (V4 plan, Task 4): profile 1's one decision (MarkupPolicy.h), read by the
/// build, the patches and the render input alike. An html, head or body is the document's own only when it is the
/// document element, its head or its body.
markup::RenderTag tagOf(JSContext* ctx, AtomNames& names, DOMState& state, const Element& element) {
    const std::string& localName = names.name(element.localNameAtom());
    markup::ElementNamespace ns = markup::ElementNamespace::Other;
    if (element.ns() == Namespace::HTML) {
        ns = markup::ElementNamespace::HTML;
    } else if (element.ns() == Namespace::SVG) {
        ns = markup::ElementNamespace::SVG;
    }
    bool adopted = false;
    if (ns == markup::ElementNamespace::HTML) {
        std::string lowered = localName;
        std::transform(lowered.begin(), lowered.end(), lowered.begin(), asciiLower);
        if (isRootName(lowered)) {
            Document& document = state.document();
            adopted = &element == document.documentElementNode() || &element == document.head(ctx) ||
                      &element == document.body(ctx);
        }
    }
    return markup::renderTagFor(ns, localName, adopted);
}

/// RB §7.2: the attributes the text budgets count, in either namespace: TextAttributes, data-* and aria-* (the host's
/// own markers are made by the scan, never read, so they cost nothing).
bool isTextAttribute(std::string_view name) {
    return profile::contains(profile::MarkupTable::TextAttributes, name) || name.starts_with("data-") ||
           name.starts_with("aria-");
}

/// The one reading of an element's attributes for litehtml, the build's and the in-place patch's (Ruling 8: a patch
/// must agree with a fresh build). Profile 1 decides what the renderer gets of each attribute (markup::renderAttribute, V4
/// plan, Task 5): one it drops by name is skipped before its value is read, and one whose output name repeats an
/// earlier one is left out; a `style` over 16 KiB is left out (styleTooLong); the budget is kMaxRenderBytes counting
/// the names and values read from `usedBefore` on, and the attribute that would pass it ends the scan (overBudget). A
/// text attribute's value and a `style`'s strings are counted against profile 1's text budgets from `unitsBefore` on
/// (V4 plan, Task 7): one that does not fit is left out (textLeftOut).
RenderAttributes scanAttributes(JSContext* ctx, AtomNames& names, DOMState& state, Element& element,
                                const markup::RenderTag& rendered, size_t usedBefore, TextUnits unitsBefore,
                                bool keepInput) {
    RenderAttributes out;
    std::unordered_set<std::string> keys;
    // A host marker (data-tg-tag, data-tg-link) goes to litehtml and the render input; the widget cannot write one
    // (data-tg-* is dropped). It costs the widget's byte budget nothing.
    const auto addHostMarker = [&](const char* name, const std::string& value) {
        keys.insert(name);
        if (keepInput) {
            out.text += ' ';
            out.text += name;
            out.text += "=\"";
            appendEscaped(out.text, value, true);
            out.text += '"';
        }
        out.map.emplace(name, value);
    };
    // A renamed element's original name (V4 plan, Task 4), first.
    if (!rendered.dataTgTag.empty()) {
        addHostMarker("data-tg-tag", rendered.dataTgTag);
    }
    const markup::ElementNamespace ns = element.ns() == Namespace::HTML  ? markup::ElementNamespace::HTML
                                        : element.ns() == Namespace::SVG ? markup::ElementNamespace::SVG
                                                                         : markup::ElementNamespace::Other;
    // A canvas's width, height and src are the builder's (below): the render input records those, not the widget's.
    const auto* canvas = element.isHTMLElement() && element.localNameAtom() == state.name(Name::canvas)
                             ? dynamic_cast<const HTMLCanvasElement*>(&element)
                             : nullptr;
    const Limits& limits = Runtime::from(ctx).limits();
    for (size_t i = 0; i < element.attributeCount(); i++) {
        const Attribute& attribute = element.attributeAt(i);
        const std::string qualified = qualifiedAttributeName(names, attribute);
        String value = String::adopt(ctx, JS_DupValue(ctx, attribute.value.value));
        if (!markup::attributeMayRender(ns, rendered.tag, qualified)) {
            continue;
        }
        // limit.attribute (widget-sandbox v0.3.0): any value the renderer's copy may hold, an inline style and a src
        // included; past it the widget stops. Compat has no such cap (the byte budget below bounds it).
        if (limits.stops && limits.attributeUnits && value.length() > limits.attributeUnits) {
            stopForAttribute(ctx, value.length());
        }
        // The budget used with this attribute's name.
        const size_t used = usedBefore + out.bytes + qualified.size();
        std::string key = qualified;
        std::transform(key.begin(), key.end(), key.begin(), asciiLower);
        std::string utf8;
        if (key == "style") {
            if (!utf8AtMost(value, kMaxStyleAttribute, utf8)) {
                out.styleTooLong = true;
                continue;
            }
            if (used + utf8.size() > kMaxRenderBytes) {
                out.overBudget = true;
                return out;
            }
        } else if (used > kMaxRenderBytes || !utf8AtMost(value, kMaxRenderBytes - used, utf8)) {
            out.overBudget = true;
            return out;
        }
        out.bytes += qualified.size() + utf8.size();
        markup::RenderAttributeDecision decided = markup::renderAttribute(ns, rendered.tag, qualified, utf8);
        if (!decided.kept || !keys.insert(decided.name).second) {
            continue;
        }
        // dir (fidelity plan, Task 11; review minors, Task 2): given to the renderer lowercased, as HTML matches [dir]
        // values whatever their case, but otherwise as written, so an author's [dir=auto] matches and [dir=rtl] does not
        // match an auto that resolves to rtl. The direction it gives, auto resolved here to the direction of the
        // element's text, reaches the UA's rules as the host marker data-tg-dir.
        std::string hostDirection;
        if (ns == markup::ElementNamespace::HTML && decided.name == "dir") {
            std::transform(decided.value.begin(), decided.value.end(), decided.value.begin(), asciiLower);
            if (decided.value == "ltr" || decided.value == "rtl") {
                hostDirection = decided.value;
            } else if (decided.value == "auto") {
                hostDirection = std::string(autoDirection(ctx, names, state, element));
            }
        }
        // An <img src> profile 1 refuses, the empty one included, renders the 48 px placeholder (V4 plan, Task 6; RB
        // §2.4, §3.5); the DOM's HTMLImageElement::state decides alike.
        // widget-sandbox v0.3.0: one claiming more than 1024² pixels too; bytes of no format stay, to be broken.
        const bool placeholder = ns == markup::ElementNamespace::HTML && rendered.tag == "img" && decided.name == "src" &&
                                 css::policy::imageSource(decided.value) == css::policy::ImageSource::Refused;
        if (placeholder) {
            decided.value = std::string(WidgetContainer::kPlaceholderURL);
        }
        // RB §7.2: a text attribute's value, and the strings of a `style` (raw text: OP12), count against the text
        // budgets; one that does not fit is left out (RB §7.3: a slot refused at creation is omitted).
        TextUnits units;
        if (decided.name == "style") {
            units = renderCssStringUnits(decided.value);
        } else if (isTextAttribute(decided.name)) {
            units = renderTextUnits(value);
        }
        const TextFit fit = renderTextFit(limits, units, unitsBefore + out.units);
        if (fit != TextFit::Fits) {
            // A text attribute past the value cap passed the attribute cap first, under strict.
            out.textLeftOut = true;
            out.overTextBudget = out.overTextBudget || fit == TextFit::OverBudget;
            continue;
        }
        out.units += units;
        if (keepInput && !(canvas && (decided.name == "width" || decided.name == "height" || decided.name == "src"))) {
            out.text += ' ';
            out.text += decided.name;
            out.text += "=\"";
            appendEscaped(out.text, decided.value, true);
            out.text += '"';
        }
        out.map.emplace(decided.name, std::move(decided.value));
        // An external link (RB §2.4): href="#" and the host's marker. A tap reads the DOM's own href, as the
        // reference's does; the marker only labels the link.
        if (decided.addsLink) {
            addHostMarker("data-tg-link", std::string());
        }
        if (placeholder) {
            addHostMarker("data-tg-placeholder", std::string());
        }
        if (!hostDirection.empty()) {
            addHostMarker("data-tg-dir", hostDirection);
        }
    }
    // A canvas draws as litehtml's image of its bitmap (V5d plan, Task 4): a source of its own, whatever src the widget
    // set, naming the canvas and its size. Its width and height are that size, its intrinsic one, and not the dimension
    // properties litehtml's image maps them to (HTML maps a canvas's only to its aspect ratio).
    if (canvas) {
        out.map.erase("width");
        out.map.erase("height");
        out.map["src"] = WidgetContainer::canvasURL({canvas->serial(), canvas->width(ctx), canvas->height(ctx)});
        if (keepInput) {
            out.text += " src=\"";
            appendEscaped(out.text, out.map["src"], true);
            out.text += '"';
        }
    }
    // An animated element's sampled declarations (V5e plan, Task 6), folded in by litehtml after `style` as the
    // animations origin (VENDOR.md edit 27). Counted as a style attribute is; past the budget the scan ends.
    if (const JSText* animated = animation::AnimationState::animatedStyleOf(ctx, element)) {
        const size_t name = std::char_traits<char>::length(litehtml::animated_style_attribute);
        if (usedBefore + out.bytes + name + animated->size() > kMaxRenderBytes) {
            out.overBudget = true;
            return out;
        }
        out.bytes += name + animated->size();
        out.map[litehtml::animated_style_attribute] = std::string(*animated);
    }
    return out;
}

class Builder {
public:
    Builder(JSContext* ctx, WidgetContainer& container, RenderBuild& build)
        : m_ctx(ctx), m_rt(JS_GetRuntime(ctx)), m_state(DOMState::of(ctx)), m_container(container), m_build(build),
          m_cut(RenderCutState{.nodes = 1}), m_keepInput(container.options().keepRenderInput), m_seen(size_t(0), std::hash<const Node*>(), std::equal_to<const Node*>(), JSAllocator<const Node*>(m_rt)) {}

    /// The dry mode (renderCutDiff): the build's walk over the document, deciding and making nothing; `scratch` takes
    /// what the walk would write to a build.
    Builder(JSContext* ctx, WidgetContainer& container, RenderBuild& scratch, const RenderBuild& published,
            const std::unordered_set<const Node*>& wanted, RenderCutDiff& diff, bool all)
        : m_ctx(ctx), m_rt(JS_GetRuntime(ctx)), m_state(DOMState::of(ctx)), m_container(container), m_build(scratch),
          m_cut(RenderCutState{.nodes = 1}), m_keepInput(false), m_seen(size_t(0), std::hash<const Node*>(), std::equal_to<const Node*>(), JSAllocator<const Node*>(m_rt)), m_dry(true), m_published(&published),
          m_wanted(&wanted), m_diff(&diff), m_all(all) {}

    /// The subtree mode (Task 9): one node's subtree, built detached with the published document, within what the rest of
    /// the document uses of the limits.
    Builder(JSContext* ctx, WidgetContainer& container, const RenderSubtreePlace& place, RenderBuild& staging,
            const RenderSubtreeTotals& totals, std::vector<litehtml::element::ptr>& roots, bool applyCut)
        : m_ctx(ctx), m_rt(JS_GetRuntime(ctx)), m_state(DOMState::of(ctx)), m_container(container), m_build(staging),
          m_cut(totals), m_keepInput(container.options().keepRenderInput), m_seen(size_t(0), std::hash<const Node*>(), std::equal_to<const Node*>(), JSAllocator<const Node*>(m_rt)), m_roots(&roots),
          m_applyCut(applyCut) {
        m_doc = place.document;
        m_baseDepth = place.parentDepth;
        m_documentElement = place.documentElement;
        m_textSeq = totals.seq;
        // The parent's frame: the bottom of the stack, never closed. Its element is not built here.
        m_stack.push_back(Frame{place.parent, place.parentElement, std::string(), place.rawText, place.silent, nullptr});
    }

    /// Builds `node`'s subtree; false where a fresh build would post a render limit inside it.
    bool runSubtree(Node& node, RenderSubtreeTotals& totals) {
        // A subtree past the walk's stop (the byte budget's, the node cap's) is not walked, as a build does not reach it.
        if (!(m_applyCut && m_cut.state().stopped)) {
            this->walk(node);
        }
        for (const std::string& kind : m_cut.limits()) {
            noteLimit(m_build.limits, kind);
        }
        static_cast<RenderCutState&>(totals) = m_cut.state();
        totals.seq = m_textSeq;
        return !m_refused;
    }

    /// The dry mode's walk, as run() walks: then the published entries it did not reach, and the wanted nodes it did not
    /// visit.
    void runDry() {
        // Room for every node the walk can reach that has an entry, so the maps grow nothing as it goes.
        m_seen.reserve(m_published->nodes.size() + m_wanted->size());
        if (m_all) {
            m_diff->nodes.reserve(m_published->nodes.size() + m_wanted->size());
        }
        if (Element* root = m_state.document().documentElementNode()) {
            this->walk(*root);
        }
        if (!m_rootMade) {
            // No document element, or none rendered: the empty html (Ruling 11), which litehtml counts.
            m_cut.addLitehtmlElement();
        }
        for (const auto& [node, entry] : m_published->nodes) {
            if (renders(entry) && !m_seen.count(node)) {
                m_diff->nodes.push_back(RenderCutNode{node, RenderFate::Stopped, m_cut.state(), 0, {}, 0, true});
                m_seen.insert(node);
            }
        }
        for (const Node* node : *m_wanted) {
            if (!m_seen.count(node)) {
                m_diff->nodes.push_back(
                    RenderCutNode{const_cast<Node*>(node), RenderFate::Unrendered, m_cut.state(), 0, {}, 0, false});
            }
        }
        m_diff->limits = m_cut.limits();
        m_diff->end = m_cut.state();
    }

    void run() {
        Document& document = m_state.document();
        m_build.document = std::make_shared<litehtml::document>(&m_container);
        m_doc = m_build.document.get();
        // The mode decides how attributes are read (html_tag::set_attr) and the quirks rules: before any element.
        m_doc->set_document_mode(modeOf(document.mode()));
        // SDK v1 §2.3: the theme's variables, on the root after its own style (twidget edit 26); §2.17: the content safe
        // area's after them.
        m_doc->set_root_declarations(rootDeclarationsOf(m_container.options()));
        m_container.beginBuild();
        this->append("<!doctype html>");
        if (Element* root = document.documentElementNode()) {
            this->walk(*root);
        }
        if (!m_root) {
            // No document element, or none rendered: an empty html (Ruling 11). Nothing of the DOM maps to it.
            if (m_doc->external_element_allowed(0)) {
                m_cut.addLitehtmlElement();
                m_root = m_doc->create_element("html", litehtml::string_map());
                m_build.boxes++;
            }
            this->append("<html></html>");
        }
        const std::string& hostCSS = m_container.options().hostCSS;
        // Ruling E19: matching gets one selector-step budget for the whole build: the first build litehtml's 4,000,000,
        // cut there as the document's (its first patch replays the style pass uncut, twidget edit 84); a test's fresh
        // tree no cut.
        const int64_t litehtmlCut = m_build.mayCutSteps ? litehtml::document::default_selector_steps : INT64_MAX / 2;
        int64_t used = 0;
        {
            struct Session {
                litehtml::document& document;
                int64_t& used;
                ~Session() { used = document.end_selector_steps(); }
            } session{*m_doc, used};
            m_doc->begin_selector_steps(litehtmlCut);
            m_doc->finalize_from_external_root(m_root, masterWithHostCSS(hostCSS), "");
        }
        m_build.selectorSteps = used;
        m_build.stepCut = used > litehtmlCut;
        // Twidget edit 84: the first patch matches the whole document again, uncut, as a build with no cut would.
        if (m_build.stepCut) {
            m_doc->note_match_cut();
        }
        // The walk's limits in the order first hit, then what matching hit.
        m_build.limits = m_cut.limits();
        m_build.walkLimits = m_build.limits.size();
        collectContainerLimits(m_container, m_build.limits);
        const RenderCutState& totals = m_cut.state();
        m_build.bytes = totals.bytes;
        m_build.textUnits = totals.units;
        m_build.nodeCount = totals.nodes;
        m_build.elementCount = totals.elements;
        m_build.formControlCount = totals.formControls;
        m_build.nextSeq = m_textSeq;
    }

private:
    enum class Step : uint8_t { Descend, SkipChildren, Stop };

    /// An element whose children are being built. `endTag` is empty for an HTML void element, which serializes
    /// without one; `silent` keeps its content and end tag out of the render input (a void element's children, which
    /// script can add and litehtml lays out, serialize as nothing, as Serializer.cpp writes them).
    struct Frame {
        Node* node;
        litehtml::element::ptr element;
        std::string endTag;
        bool rawText;
        bool silent;
        /// The element's entry, whose end the close records.
        RenderEntry* entry;
    };

    /// A subtree build: the bottom frame is the parent's, which this build neither opens nor closes.
    size_t baseFrames() const { return m_roots ? 1 : 0; }

    /// Whether a cap refuses: in the subtree mode, unless it applies the cut (a patch walking the cut, RenderCut.h).
    bool refusing() const { return m_roots && !m_applyCut; }
    /// Whether litehtml's element and piece caps are this walk's to count (a subtree's are the fork's predicate's).
    bool countsLitehtml() const { return !m_roots || m_applyCut; }

    /// What the build refuses in the subtree mode, where a full build would post a limit: the patch walks the cut
    /// instead (RenderCut.h).
    Step refuse() {
        m_refused = true;
        return Step::Stop;
    }

    /// Adds `count` nodes to the node count (RB §7.1 MAX_NODES); false once past kMaxRenderNodes, which a build notes and
    /// the subtree mode refuses: the walk stops.
    bool countNodes(size_t count) {
        if (m_cut.addNodes(count)) {
            return true;
        }
        if (this->refusing()) {
            this->refuse();
        } else {
            m_cut.note("nodes");
            m_cut.stop();
        }
        return false;
    }

    bool isScript(Node& node) const {
        return node.isElement() && static_cast<Element&>(node).hasHTMLName(m_state.name(Name::script));
    }

    /// The nodes under `root`, whose children the walk does not build, counted toward the node cap; a `<script>`'s
    /// children are not counted (the reference's sandbox never sends them). False once past the cap.
    bool countUnbuilt(Node& root) {
        if (this->isScript(root)) {
            return true;
        }
        Node* node = root.firstChildNode();
        while (node) {
            if (!this->countNodes(1)) {
                return false;
            }
            const bool descend = node->firstChildNode() && !this->isScript(*node);
            node = descend ? node->nextInTreeOrder(&root) : node->nextSkippingChildren(&root);
        }
        return true;
    }

    void walk(Node& root) {
        Node* node = &root;
        while (node) {
            // Close the elements `node` is not inside: its parent is the innermost open one (every visited node's
            // parent was rendered: a subtree that is not is skipped whole).
            while (m_stack.size() > this->baseFrames() && m_stack.back().node != node->parent()) {
                this->close();
            }
            // Profile 1's node cap (V4 plan, Task 7), in tree order: every node the walk visits, and the ones under a node
            // whose children it does not build. What the caps held before the node is its cut state (RenderCutNode).
            const RenderCutState before = m_cut.state();
            if (!this->countNodes(1)) {
                break;
            }
            Step step = Step::SkipChildren;
            if (node != &root && m_stack.empty()) {
                step = Step::SkipChildren;
            } else if (node->isElement()) {
                step = this->element(static_cast<Element&>(*node), before);
            } else if (node->type() == NodeType::Text) {
                step = this->text(static_cast<CharacterData&>(*node), before);
            }
            if (step == Step::Stop) {
                break;
            }
            if (step == Step::SkipChildren && node->firstChildNode() && !this->countUnbuilt(*node)) {
                break;
            }
            node = step == Step::Descend ? node->nextInTreeOrder(&root) : node->nextSkippingChildren(&root);
        }
        while (m_stack.size() > this->baseFrames()) {
            this->close();
        }
    }

    void close() {
        Frame& frame = m_stack.back();
        if (!frame.silent) {
            this->append(frame.endTag);
            if (frame.entry && frame.entry->inputOffset != kNoRenderInput) {
                frame.entry->inputEnd = m_build.input.size();
                frame.entry->endTagLength = frame.endTag.size();
            }
        }
        m_stack.pop_back();
    }

    bool silent() const { return !m_stack.empty() && m_stack.back().silent; }

    void append(std::string_view text) {
        if (m_keepInput && !this->silent()) {
            m_build.input.append(text.data(), text.size());
        }
    }

    void appendText(std::string_view utf8, bool raw) {
        if (!m_keepInput || this->silent()) {
            return;
        }
        if (raw) {
            m_build.input.append(utf8.data(), utf8.size());
        } else {
            appendEscaped(m_build.input, utf8, false);
        }
    }

    const std::string& name(JSAtom atom) { return m_names.name(atom); }

    Step element(Element& element, const RenderCutState& before) {
        const markup::RenderTag rendered = tagOf(m_ctx, m_names, m_state, element);
        if (!rendered.rendered) {
            this->decided(element, RenderFate::Unrendered, before);
            return Step::SkipChildren;
        }
        // Twidget edit 83: only what renders counts. An element its parent's own append refuses (a <div> or a <tr>
        // straight under a <table>) renders nothing; it is asked first, so no limit counts it.
        if (!m_stack.empty() && m_stack.back().element && !renderParentAccepts(*m_stack.back().element, rendered.tag)) {
            this->decided(element, RenderFate::Unrendered, before);
            return Step::SkipChildren;
        }
        // The document's own head or body (rendered as one) is built with its document element alone (flushRoot,
        // twidget edit 82), which every change to which they are routes to; another one is an inert div or span.
        if (m_roots && !m_documentElement && element.ns() == Namespace::HTML && isRootName(rendered.tag)) {
            return this->refuse();
        }
        // W's limits are asked before litehtml's caps, so an element past one takes no slot of litehtml's. The subtree
        // mode asks litehtml's depth without counting (twidget edit 18 counts the elements it links).
        const bool formControl = isFormControl(rendered.tag);
        const int depth = m_baseDepth + int(m_stack.size());
        if (const char* limit = m_cut.elementLimit(formControl, depth, this->countsLitehtml())) {
            if (this->refusing()) {
                return this->refuse();
            }
            m_cut.note(limit);
            this->decided(element, RenderFate::Cut, before);
            return Step::SkipChildren;
        }
        // The render input's names and start tag only when it is kept (Ruling E11).
        const std::string tagName = m_keepInput ? rendered.tag : std::string();
        RenderAttributes scanned =
            scanAttributes(m_ctx, m_names, m_state, element, rendered, before.bytes, before.units, m_keepInput);
        if (this->refusing() && (scanned.styleTooLong || scanned.overBudget || scanned.textLeftOut)) {
            return this->refuse();
        }
        if (scanned.overTextBudget && m_limits.stops) {
            stopForTextBudget(m_ctx);
        }
        if (scanned.styleTooLong) {
            m_cut.note("style-attribute");
        }
        if (scanned.textLeftOut) {
            m_cut.note("text-budget");
        }
        if (scanned.overBudget) {
            m_cut.note("bytes");
            m_cut.stop();
            this->decided(element, RenderFate::Stopped, before);
            return Step::Stop;
        }
        // litehtml counts it once it renders (only what renders counts): after its attributes fit the byte budget. It
        // counts the same elements the cut does, so this does not refuse; its own answer goes.
        if (!m_roots && !m_dry && !m_doc->external_element_allowed(depth)) {
            m_cut.note(depth >= litehtml::document::max_external_depth ? "depth" : "elements");
            return Step::SkipChildren;
        }
        m_cut.add(scanned.bytes, scanned.units);
        m_cut.addElement(formControl, this->countsLitehtml());
        // limit.canvas-pixels (widget-sandbox v0.3.0): the canvases a walk of the whole document sees (the boot's build,
        // the cut walk's dry mode, a document element built again), width × height together; past Limits::canvasPixels the
        // widget stops. A subtree outside the walk refuses one, so the patch walks the cut and the walk judges the document's.
        if (element.isHTMLElement() && element.localNameAtom() == m_state.name(Name::canvas)) {
            if (this->refusing()) {
                return this->refuse();
            }
            const auto* canvas = dynamic_cast<const HTMLCanvasElement*>(&element);
            if (canvas && (!m_roots || m_documentElement)) {
                m_canvasPixels += uint64_t(canvas->width(m_ctx)) * canvas->height(m_ctx);
                if (m_limits.stops && m_limits.canvasPixels && m_canvasPixels > m_limits.canvasPixels) {
                    stopForLimit(m_ctx, "Canvas limit exceeded: canvases of " + std::to_string(m_canvasPixels) +
                                            " pixels together (max " + std::to_string(m_limits.canvasPixels) + ")");
                }
            }
        }
        if (m_dry) {
            const uint32_t pieces = rendered.stylesheet ? this->styleSheet(element, nullptr, false, nullptr) : 0;
            this->decided(element, RenderFate::Rendered, before, scanned.bytes, scanned.units, pieces);
            if (m_stack.empty()) {
                m_rootMade = true;
            }
            if (rendered.stylesheet) {
                return Step::SkipChildren;
            }
            m_stack.push_back(Frame{&element, this->prototype(rendered.tag), std::string(), false, true, nullptr});
            return Step::Descend;
        }
        litehtml::string_map& attributes = scanned.map;
        const std::string startTag = m_keepInput ? "<" + tagName + scanned.text + ">" : std::string();

        litehtml::element::ptr created = m_doc->create_element(rendered.tag.c_str(), attributes);
        syncUserActionState(m_ctx, element, *created);
        if (m_roots && m_stack.size() == 1) {
            // The subtree's root, left detached.
            m_roots->push_back(created);
        } else if (m_stack.empty()) {
            m_root = created;
        } else {
            const litehtml::element::ptr& parent = m_stack.back().element;
            m_doc->insert_child(parent, parent->children().size(), created);
        }
        RenderEntry& entry = this->map(element, created);
        entry.bytes = scanned.bytes;
        entry.units = scanned.units;
        entry.seq = m_textSeq++;
        m_build.boxes++;
        if (m_keepInput && !this->silent()) {
            // The start tag, for the in-place attribute patch (Task 8).
            entry.inputOffset = m_build.input.size();
            entry.inputLength = startTag.size();
        }
        this->append(startTag);

        // A renamed element is never void or raw text: its DOM name's answers are not its rendered tag's.
        const bool kept = rendered.dataTgTag.empty();
        const bool rawText = kept && element.isHTMLElement() && m_state.hasRawTextChildren(element.localNameAtom());
        if (rendered.stylesheet) {
            // litehtml makes every element named style an el_style, whatever its namespace.
            this->styleSheet(element, created, rawText, &entry);
            const std::string endTag = "</" + tagName + ">";
            this->append(endTag);
            if (entry.inputOffset != kNoRenderInput) {
                entry.inputEnd = m_build.input.size();
                entry.endTagLength = endTag.size();
            }
            return Step::SkipChildren;
        }
        const bool isVoid = kept && element.isHTMLElement() && m_state.isVoidHTMLElement(element.localNameAtom());
        if (isVoid && entry.inputOffset != kNoRenderInput) {
            // No end tag, and its content is out of the input.
            entry.inputEnd = entry.inputOffset + entry.inputLength;
            entry.endTagLength = 0;
        }
        m_stack.push_back(Frame{&element, created, isVoid ? std::string() : "</" + tagName + ">", rawText,
                                this->silent() || isVoid, &entry});
        return Step::Descend;
    }

    /// The sheet of a `<style>` (Ruling 10), within the 64 KiB of `<style>` text (Ruling 7), its piece its entry's; the
    /// pieces it made (one, or none when not applied). The subtree mode refuses where a build posts a limit, and makes
    /// the piece without asking the cap (twidget edit 18 counts it); the 64 KiB there are the subtree's, which the patch
    /// checks against the document's (edit 81). The dry mode decides and makes nothing.
    uint32_t styleSheet(Element& style, const litehtml::element::ptr& created, bool raw, RenderEntry* entry) {
        // limit.text-node (widget-sandbox v0.3.0): the sheet's text is one text value; past the cap the widget stops.
        if (m_limits.stops) {
            size_t units = 0;
            for (size_t i = 0; i < style.childCount(); i++) {
                Node* child = style.childAt(i);
                if (child->type() == NodeType::Text) {
                    units += static_cast<CharacterData*>(child)->dataString(m_ctx).length();
                }
            }
            if (units > m_limits.textValueUnits) {
                stopForTextValue(m_ctx, units);
            }
        }
        RenderSheet sheet;
        if (!renderStyleSheet(m_ctx, style, m_cut.cssRoom(), sheet)) {
            if (this->refusing()) {
                this->refuse();
                return 0;
            }
            m_cut.note("css");
            return 0;
        }
        // Profile 1's text budgets (V4 plan, Task 7; RB §7.2): the sheet's text, and the contents of its strings. A sheet
        // that does not fit is not applied, and counts nothing.
        const TextUnits units = m_cut.state().units;
        const TextFit textFit = renderTextFit(m_limits, sheet.text, units);
        const TextFit fit = textFit != TextFit::Fits ? textFit : renderTextFit(m_limits, sheet.strings, units + sheet.text);
        if (fit != TextFit::Fits) {
            if (this->refusing()) {
                this->refuse();
                return 0;
            }
            if (fit == TextFit::OverBudget && m_limits.stops) {
                stopForTextBudget(m_ctx);
            }
            m_cut.note("text-budget");
            return 0;
        }
        m_cut.addUnits(sheet.text + sheet.strings);
        if (m_dry) {
            if (sheet.utf8.empty() || m_cut.keepPieces(1) == 0) {
                return 0;
            }
            m_cut.addCss(sheet.utf8.size());
            return 1;
        }
        // limit.css-rules (widget-sandbox v0.3.0): counted over the sheets a walk of the whole document applies (the
        // boot's build, a document element built again); a patch's sheets are the plan's to count (RenderTree::planSheets).
        if (!m_roots || m_documentElement) {
            renderCountCssRules(m_ctx, m_limits, sheet.utf8, m_cssRules, m_cssKeyframes);
        }
        std::vector<litehtml::element::ptr> pieces;
        if (!sheet.utf8.empty()) {
            if (m_roots && m_applyCut && m_cut.keepPieces(1) == 0) {
                // Past the piece cap, as append_text would refuse it: the sheet is not applied.
            } else if (m_roots) {
                m_doc->make_text_pieces(created, sheet.utf8.c_str(), pieces);
                for (const litehtml::element::ptr& piece : pieces) {
                    created->appendChild(piece);
                }
                if (!m_applyCut) {
                    m_cut.addPieces(pieces.size());
                }
            } else {
                if (!m_doc->append_text(created, sheet.utf8.c_str(), pieces)) {
                    m_cut.note("text-pieces");
                }
                m_cut.addPieces(pieces.size());
            }
            if (pieces.empty()) {
                sheet.utf8.clear();
            } else {
                m_cut.addCss(sheet.utf8.size());
                m_build.styleSheets.push_back(sheet.utf8);
                if (!m_build.usesUserActionPseudo) {
                    m_build.usesUserActionPseudo = mentionsUserActionPseudo(sheet.utf8);
                }
                entry->pieces.reserve(pieces.size());
                for (const litehtml::element::ptr& piece : pieces) {
                    m_build.elements.emplace(piece.get(), &style);
                    entry->pieces.push_back(piece);
                }
                m_build.boxes += pieces.size();
                this->appendText(sheet.utf8, raw);
            }
        }
        m_build.sheets.insert_or_assign(&style, std::move(sheet));
        return uint32_t(pieces.size());
    }

    Step text(CharacterData& text, const RenderCutState& before) {
        Frame& parent = m_stack.back();
        String data = text.dataString(m_ctx);
        // Profile 1's text limits (V4 plan, Task 7; RB §7.1): a Text over Limits::textValueUnits, or one the document's text
        // budgets have no room left for, is mapped and renders nothing; the walk goes on.
        const TextUnits units = renderTextUnits(data);
        const TextFit fit = renderTextFit(m_limits, units, before.units);
        if (fit != TextFit::Fits) {
            // widget-sandbox v0.3.0: under strict a value past its cap stops the widget, and so does the document's text
            // past its budget where a build counts it (a subtree's count is its own part's).
            if (fit == TextFit::ValueTooLong && m_limits.stops) {
                stopForTextValue(m_ctx, units.units);
            }
            if (this->refusing()) {
                return this->refuse();
            }
            if (fit == TextFit::OverBudget && m_limits.stops) {
                stopForTextBudget(m_ctx);
            }
            m_cut.note(fit == TextFit::ValueTooLong ? "text-node" : "text-budget");
            if (m_dry) {
                this->decided(text, RenderFate::Cut, before);
                return Step::SkipChildren;
            }
            RenderEntry& entry = this->map(text, nullptr);
            entry.seq = m_textSeq++;
            return Step::SkipChildren;
        }
        std::string utf8;
        if (!utf8AtMost(data, m_cut.remainingBytes(), utf8)) {
            if (this->refusing()) {
                return this->refuse();
            }
            m_cut.note("bytes");
            m_cut.stop();
            this->decided(text, RenderFate::Stopped, before);
            return Step::Stop;
        }
        m_cut.add(utf8.size(), units);
        const bool takesText = !parent.element || parent.element->accepts_text();
        if (m_dry) {
            const uint32_t pieces = takesText ? m_cut.keepPieces(this->countPieces(*parent.element, utf8)) : 0;
            this->decided(text, RenderFate::Rendered, before, utf8.size(), units, pieces);
            return Step::SkipChildren;
        }
        std::vector<litehtml::element::ptr> pieces;
        bool all = true;
        if (!takesText) {
            // Twidget edit 83: a parent that takes no text (a <table>'s whitespace): in the render input, and its bytes
            // and units count, but litehtml holds nothing, so its piece cap is not asked.
        } else if (m_roots) {
            // Made without asking the cap (twidget edit 18 counts them), except under the parent of the subtree, which
            // nothing here attaches to. Applying the cut, the pieces past the cap go, as append_text would not make them.
            m_doc->make_text_pieces(parent.element, utf8.c_str(), pieces);
            if (m_applyCut) {
                const uint32_t kept = m_cut.keepPieces(uint32_t(pieces.size()));
                all = kept == pieces.size();
                pieces.resize(kept);
            } else {
                m_cut.addPieces(pieces.size());
            }
            for (const litehtml::element::ptr& piece : pieces) {
                if (m_stack.size() == 1) {
                    m_roots->push_back(piece);
                } else {
                    m_doc->insert_child(parent.element, parent.element->children().size(), piece);
                }
            }
        } else {
            all = m_doc->append_text(parent.element, utf8.c_str(), pieces);
            if (!all) {
                m_cut.note("text-pieces");
            }
            m_cut.addPieces(pieces.size());
        }
        RenderEntry& entry = this->map(text, nullptr);
        entry.bytes = utf8.size();
        entry.units = units;
        entry.seq = m_textSeq++;
        const size_t inputStart = m_build.input.size();
        entry.pieces.reserve(pieces.size());
        for (const litehtml::element::ptr& piece : pieces) {
            entry.pieces.push_back(piece);
            m_build.elements.emplace(piece.get(), &text);
        }
        m_build.boxes += pieces.size();
        if (all) {
            this->appendText(utf8, parent.rawText);
        } else if (m_keepInput) {
            // The piece cap stopped it: what renders is the pieces made.
            std::string made;
            for (const litehtml::element::ptr& piece : pieces) {
                piece->get_text(made);
            }
            this->appendText(made, parent.rawText);
        }
        // An empty one has no place (RenderEntry::inputOffset).
        if (m_keepInput && !this->silent() && m_build.input.size() > inputStart) {
            entry.inputOffset = inputStart;
            entry.inputLength = m_build.input.size() - inputStart;
        }
        return Step::SkipChildren;
    }

    /// The pieces append_text makes of `utf8` under `parent`: one under a raw-text parent, else the container's split's
    /// words and spaces.
    uint32_t countPieces(const litehtml::element& parent, const std::string& utf8) {
        if (parent.tag() == litehtml::_style_ || parent.tag() == litehtml::_script_) {
            return 1;
        }
        uint32_t count = 0;
        m_container.split_text(utf8.c_str(), [&](const char*) { count++; }, [&](const char*) { count++; });
        return count;
    }

    /// The dry mode's: one element of litehtml's for each rendered tag, never linked, standing for a parent whose
    /// acceptance and raw text the walk asks.
    litehtml::element::ptr prototype(const std::string& tag) {
        auto found = m_prototypes.find(tag);
        if (found != m_prototypes.end()) {
            return found->second;
        }
        if (!m_scratch) {
            m_scratch = std::make_shared<litehtml::document>(&m_container);
        }
        litehtml::element::ptr made = m_scratch->create_element(tag.c_str(), litehtml::string_map());
        m_prototypes.emplace(tag, made);
        return made;
    }

    /// Whether a published entry renders something a fresh build that leaves its node out would not have: an element,
    /// pieces, or a place in the render input (a Text under a parent that takes no text: twidget edit 83).
    static bool renders(const RenderEntry& entry) {
        return entry.element || !entry.pieces.empty() || entry.inputOffset != kNoRenderInput;
    }

    /// The dry mode's record of a node's decision: kept when it differs from the published entry, or is wanted.
    void decided(Node& node, RenderFate fate, const RenderCutState& before, size_t bytes = 0, TextUnits units = {},
                 uint32_t pieces = 0) {
        if (!m_dry) {
            return;
        }
        auto found = m_published->nodes.find(&node);
        const bool mapped = found != m_published->nodes.end();
        bool differs;
        if (fate == RenderFate::Rendered) {
            differs = !mapped || bool(found->second.element) != node.isElement() || found->second.bytes != bytes ||
                      found->second.units.units != units.units || found->second.units.complex != units.complex ||
                      found->second.pieces.size() != pieces;
        } else {
            differs = mapped && renders(found->second);
        }
        if (differs || m_all || m_wanted->count(&node)) {
            m_diff->nodes.push_back(RenderCutNode{&node, fate, before, bytes, units, pieces, differs});
        }
        m_seen.insert(&node);
    }

    RenderEntry& map(Node& node, litehtml::element::ptr element) {
        if (element) {
            m_build.elements.emplace(element.get(), &node);
        }
        auto [entry, inserted] =
            m_build.nodes.try_emplace(&node, Ref<Node>::retain(m_ctx, &node), std::move(element), m_rt);
        return entry->second;
    }

    JSContext* m_ctx;
    /// The runtime's counted caps (widget-sandbox v0.3.0): strict or compat.
    const Limits& m_limits = Runtime::from(m_ctx).limits();
    JSRuntime* m_rt;
    DOMState& m_state;
    WidgetContainer& m_container;
    RenderBuild& m_build;
    litehtml::document* m_doc = nullptr;
    litehtml::element::ptr m_root;
    /// The open elements, the root first: at most litehtml's depth cap deep.
    std::vector<Frame> m_stack;
    AtomNames m_names{m_ctx};
    /// What the walk has used of the caps, and the limits it hit (RenderCut.h); the nodes counted from the document node.
    RenderCut m_cut;
    /// The pixels of the canvases built so far (limit.canvas-pixels).
    uint64_t m_canvasPixels = 0;
    /// The style rules and @keyframes of the sheets applied so far (limit.css-rules).
    size_t m_cssRules = 0;
    size_t m_cssKeyframes = 0;
    /// The Text entries made so far (RenderEntry::seq).
    uint32_t m_textSeq = 0;
    const bool m_keepInput;
    /// The dry mode's: the nodes it decided or recorded; whether it rendered a root; the published build it compares
    /// with, the wanted nodes and its answer; the prototypes of its parents' elements, made with a scratch document.
    std::unordered_set<const Node*, std::hash<const Node*>, std::equal_to<const Node*>, JSAllocator<const Node*>> m_seen;
    bool m_dry = false;
    bool m_rootMade = false;
    const RenderBuild* m_published = nullptr;
    const std::unordered_set<const Node*>* m_wanted = nullptr;
    RenderCutDiff* m_diff = nullptr;
    bool m_all = false;
    litehtml::document::ptr m_scratch;
    std::unordered_map<std::string, litehtml::element::ptr> m_prototypes;
    /// The subtree mode's: where the roots go, the parent's depth, and whether a limit refused the subtree.
    std::vector<litehtml::element::ptr>* m_roots = nullptr;
    /// The subtree mode's: whether it cuts at the caps as a build does instead of refusing (RenderCut.h).
    bool m_applyCut = false;
    int m_baseDepth = 0;
    bool m_documentElement = false;
    bool m_refused = false;
};

} // namespace

RenderBuild::RenderBuild(JSContext* ctx)
    : nodes(JSAllocator<std::pair<Node* const, RenderEntry>>(JS_GetRuntime(ctx))),
      elements(JSAllocator<std::pair<const litehtml::element* const, Node*>>(JS_GetRuntime(ctx))),
      input(JSAllocator<char>(JS_GetRuntime(ctx))) {}

void RenderBuild::swap(RenderBuild& other) noexcept {
    document.swap(other.document);
    nodes.swap(other.nodes);
    elements.swap(other.elements);
    input.swap(other.input);
    limits.swap(other.limits);
    std::swap(walkLimits, other.walkLimits);
    std::swap(boxes, other.boxes);
    std::swap(naturalWidth, other.naturalWidth);
    std::swap(usesUserActionPseudo, other.usesUserActionPseudo);
    styleSheets.swap(other.styleSheets);
    sheets.swap(other.sheets);
    std::swap(bytes, other.bytes);
    std::swap(textUnits, other.textUnits);
    std::swap(nodeCount, other.nodeCount);
    std::swap(elementCount, other.elementCount);
    std::swap(formControlCount, other.formControlCount);
    std::swap(nextSeq, other.nextSeq);
    std::swap(selectorSteps, other.selectorSteps);
    std::swap(mayCutSteps, other.mayCutSteps);
    std::swap(stepCut, other.stepCut);
}

TextUnits renderTextUnits(const String& s) {
    const JSStringView view = s.view();
    TextUnits out;
    out.units = view.length;
    if (view.utf16) {
        for (uint32_t i = 0; i < view.length; i++) {
            out.complex += view.utf16[i] >= 0x0590 ? 1 : 0;
        }
    }
    return out;
}

TextUnits renderCssStringUnits(std::string_view css) {
    TextUnits out;
    // One character of the UTF-8 at `i`, counted as UTF-16 units.
    const auto count = [&](size_t& i) {
        const unsigned char lead = static_cast<unsigned char>(css[i]);
        const size_t length = lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
        uint32_t cp = length == 1 ? lead : lead & (0xFF >> (length + 1));
        for (size_t k = 1; k < length && i + k < css.size(); k++) {
            cp = (cp << 6) | (static_cast<unsigned char>(css[i + k]) & 0x3F);
        }
        const size_t units = cp >= 0x10000 ? 2 : 1;
        out.units += units;
        out.complex += cp >= 0x0590 ? units : 0;
        i += length;
    };
    const auto skip = [&](size_t& i) {
        const unsigned char lead = static_cast<unsigned char>(css[i]);
        i += lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
    };
    size_t i = 0;
    while (i < css.size()) {
        const char c = css[i];
        if (c == '\\') {
            // Outside a string a backslash skips itself and the next character.
            skip(i);
            if (i < css.size()) {
                skip(i);
            }
        } else if (c == '"' || c == '\'') {
            i++;
            while (i < css.size() && css[i] != c) {
                if (css[i] == '\\') {
                    i++;
                    if (i >= css.size()) {
                        break;
                    }
                }
                count(i);
            }
            i++;
        } else {
            skip(i);
        }
    }
    return out;
}

TextFit renderTextFit(const Limits& limits, TextUnits value, TextUnits others) {
    if (value.units > limits.textValueUnits) {
        return TextFit::ValueTooLong;
    }
    if (others.units + value.units > limits.textBudgetUnits) {
        return TextFit::OverBudget;
    }
    if (others.complex + value.complex > kComplexTextBudgetUnits) {
        return TextFit::OverComplexBudget;
    }
    return TextFit::Fits;
}

RenderAttributes renderElementAttributes(JSContext* ctx, Element& element, size_t usedBefore, TextUnits unitsBefore,
                                         bool keepInput, std::string* startTag) {
    AtomNames names(ctx);
    DOMState& state = DOMState::of(ctx);
    const markup::RenderTag rendered = tagOf(ctx, names, state, element);
    RenderAttributes out = scanAttributes(ctx, names, state, element, rendered, usedBefore, unitsBefore, keepInput && startTag);
    if (startTag && keepInput && !out.overBudget) {
        *startTag = "<" + rendered.tag + out.text + ">";
    }
    return out;
}

markup::RenderTag renderTagOf(JSContext* ctx, const Element& element) {
    AtomNames names(ctx);
    return tagOf(ctx, names, DOMState::of(ctx), element);
}

bool renderElementIsUnrendered(JSContext* ctx, const Element& element) {
    return !renderTagOf(ctx, element).rendered;
}

bool renderUtf8AtMost(const String& s, size_t maxBytes, std::string& out) {
    return utf8AtMost(s, maxBytes, out);
}

void renderCountCssRules(JSContext* ctx, const Limits& limits, const std::string& sheet, size_t& rules, size_t& keyframes) {
    if (!limits.stops || (!limits.cssRules && !limits.cssKeyframes)) {
        return;
    }
    const CSSRuleCount count = countCssRules(sheet);
    rules += count.rules;
    keyframes += count.keyframes;
    if (limits.cssRules && rules > limits.cssRules) {
        stopForLimit(ctx, "CSS limit exceeded: " + std::to_string(rules) + " rules in the document's stylesheets (max " +
                              std::to_string(limits.cssRules) + ")");
    }
    if (limits.cssKeyframes && keyframes > limits.cssKeyframes) {
        stopForLimit(ctx, "CSS limit exceeded: " + std::to_string(keyframes) + " @keyframes in the document's stylesheets (max " +
                              std::to_string(limits.cssKeyframes) + ")");
    }
}

bool renderStyleSheet(JSContext* ctx, Element& style, size_t room, RenderSheet& sheet) {
    // Its Text children's length first, so a sheet too long to apply is never copied or converted.
    size_t units = 0;
    for (size_t i = 0; i < style.childCount(); i++) {
        Node* child = style.childAt(i);
        if (child->type() == NodeType::Text) {
            units += static_cast<CharacterData*>(child)->dataString(ctx).length();
        }
    }
    sheet.length = units;
    if (units > room) {
        return false;
    }
    String text = childTextContent(ctx, style);
    const bool fits = utf8AtMost(text, room, sheet.utf8);
    if (!fits) {
        return false;
    }
    sheet.text = renderTextUnits(text);
    sheet.strings = renderCssStringUnits(sheet.utf8);
    return true;
}

bool renderMentionsUserActionPseudo(const std::string& css) {
    return mentionsUserActionPseudo(css);
}

std::string renderEscapedText(std::string_view utf8) {
    std::string out;
    appendEscaped(out, utf8, false);
    return out;
}

void buildDocument(JSContext* ctx, WidgetContainer& container, RenderBuild& build) {
    Builder(ctx, container, build).run();
}

bool buildRenderSubtree(JSContext* ctx, WidgetContainer& container, const RenderSubtreePlace& place, Node& node,
                        RenderBuild& staging, RenderSubtreeTotals& totals, std::vector<litehtml::element::ptr>& roots,
                        bool applyCut) {
    return Builder(ctx, container, place, staging, totals, roots, applyCut).runSubtree(node, totals);
}

bool buildRenderRoot(JSContext* ctx, WidgetContainer& container, litehtml::document& document, RenderBuild& staging,
                     RenderSubtreeTotals& totals, litehtml::element::ptr& root) {
    Document& dom = DOMState::of(ctx).document();
    RenderSubtreePlace place;
    place.document = &document;
    place.parent = &dom;
    place.parentDepth = -1;
    place.documentElement = true;
    // Everything else goes: the limits count from the document node alone, as a build's.
    totals = RenderSubtreeTotals{};
    totals.nodes = 1;
    std::vector<litehtml::element::ptr> roots;
    if (Element* element = dom.documentElementNode()) {
        if (!Builder(ctx, container, place, staging, totals, roots, true).runSubtree(*element, totals)) {
            return false;
        }
    }
    if (roots.empty()) {
        // No document element, or none rendered: an empty html (Ruling 11). Nothing of the DOM maps to it.
        totals.litehtmlElements++;
        roots.push_back(document.create_element("html", litehtml::string_map()));
        staging.boxes++;
        if (container.options().keepRenderInput) {
            staging.input.append("<html></html>");
        }
    }
    root = roots.front();
    return true;
}

RenderCutDiff renderCutDiff(JSContext* ctx, WidgetContainer& container, const RenderBuild& published,
                            const std::unordered_set<const Node*>& wanted, bool all) {
    RenderCutDiff diff(JS_GetRuntime(ctx));
    RenderBuild scratch(ctx);
    Builder(ctx, container, scratch, published, wanted, diff, all).runDry();
    return diff;
}

bool renderParentAccepts(const litehtml::element& parent, const std::string& tag) {
    litehtml::string_id id;
    // A name litehtml never interned is none of the tags a parent restricts its children to.
    if (!litehtml::_find_id(tag, id)) {
        id = litehtml::empty_id;
    }
    return parent.accepts_child(id);
}

bool renderIsFormControl(const char* tag) {
    return tag && isFormControl(tag);
}

void collectContainerLimits(const WidgetContainer& container, std::vector<std::string>& limits) {
    for (const std::string& kind : container.limitsHit()) {
        if (kind == "text") {
            noteLimit(limits, "text-pieces");
        } else if (kind == "table") {
            noteLimit(limits, "table-cells");
        } else {
            noteLimit(limits, kind);
        }
    }
}

namespace {

/// What HTML's rendering section gives elements that twidget's master sheet (shared with LHDocument, which renders
/// HTML messages its own way) and the profile's UA layer leave out, for the conformance set (fidelity plan, Task 3): a
/// summary as a list item (its marker stays the master's ::before triangle), <q>'s quotation marks. A link's colour is
/// the layer's (`a[href]`, no underline: widget-sandbox v0.1.1).
constexpr std::string_view kWidgetUAStylesheet =
    "summary{display:list-item;list-style-type:none}"
    "q::before{content:\"\\201C\"}q::after{content:\"\\201D\"}"
    // HTML's [dir] rules (fidelity plan, Task 11), on the Builder's marker of the direction dir gives (auto resolved).
    "[data-tg-dir=ltr]{direction:ltr}[data-tg-dir=rtl]{direction:rtl}";

} // namespace

std::string masterWithHostCSS(const std::string& hostCSS) {
    std::string master = litehtml::telegram_master_css();
    master += "\n";
    master += kWidgetUAStylesheet;
    // The profile's UA stylesheet (SDK v1 §2.4: a <button> the widget did not style), then the host's root CSS.
    master += "\n";
    master += profile::uaStylesheet();
    master += "\n";
    master += hostCSS;
    return master;
}

} // namespace wr
