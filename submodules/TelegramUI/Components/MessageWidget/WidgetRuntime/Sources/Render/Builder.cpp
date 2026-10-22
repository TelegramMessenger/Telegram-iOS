#include "Sources/Render/Builder.h"

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
#include "Sources/Render/WidgetContainer.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Callbacks.h"
#include "Sources/Support/Work.h"

namespace wr {

namespace {

// Whether CSS text names a user-action pseudo-class, ASCII case-insensitively (M1d plan, Task 3). A false positive (in
// a comment, a string) only costs a rebuild on a state change.
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


// Ruling 7.
constexpr size_t kMaxStyleText = 64 * 1024;
constexpr size_t kMaxStyleAttribute = 16 * 1024;
// Ruling E9: litehtml and the layer tree cost about 10.4 KB per styled element (20,000 styled divs measured 153 MB of
// litehtml and 55 MB of tree), so W renders half of litehtml's own 20,000.
constexpr size_t kMaxElements = 10000;
// Ruling E6: litehtml generates each control's parts outside its element and text caps (20,000 inputs measured 436 MB;
// the corpus maximum is 19 controls). Profile 1 drops every control but <button> (V4 plan, Task 4), which is the one
// counted, by the rendered tag.
constexpr size_t kMaxFormControls = 256;

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

/// An atom as UTF-8, converted once per user (the DOM holds every atom it is asked for while the build runs), and
/// charged at every use. The DOM bounds no name's length, so a name is charged before it is converted: by its UTF-16
/// length, a lower bound of its UTF-8 one; then up to its UTF-8 length, so the first use costs at least what a later
/// one does (Ruling E22: a patch's AtomNames is fresh where a rebuild's has the name already, and the patch's measured
/// work must cover the rebuild's).
class AtomNames {
public:
    explicit AtomNames(JSContext* ctx) : m_ctx(ctx) {}

    const std::string& name(JSAtom atom) {
        auto found = m_names.find(atom);
        if (found == m_names.end()) {
            String s = String::fromAtom(m_ctx, atom);
            chargeScan(m_ctx, s.length());
            found = m_names.emplace(atom, s.utf8ForParse()).first;
            const uint64_t scanned = uint64_t(s.length()) / 8;
            const uint64_t full = uint64_t(found->second.size()) / 8;
            if (full > scanned) {
                charge(m_ctx, (full - scanned) * work::kScanEightUnits);
            }
        } else {
            chargeScan(m_ctx, found->second.size());
        }
        return found->second;
    }

private:
    JSContext* m_ctx;
    std::unordered_map<JSAtom, std::string> m_names;
};

/// HTML's dir=auto (fidelity plan, Task 11): the direction of the first character of bidi class L, R or AL among the
/// element's descendant text, in tree order, skipping bdi, script, style and textarea elements and every element with a
/// dir of its own (ltr, rtl or auto, in any case); ltr when there is none. A node visit per node and a scan of the text
/// read are charged.
std::string_view autoDirection(JSContext* ctx, AtomNames& names, DOMState& state, Element& element) {
    // Compared, never copied: a value of any length costs what a short one does (final review C1).
    const auto ownDirection = [&](Element& e) {
        const std::optional<String> dir = e.attributeValue(ctx, state.name(Name::dir));
        return dir && (dir->equalsIgnoringASCIICase("ltr") || dir->equalsIgnoringASCIICase("rtl") ||
                       dir->equalsIgnoringASCIICase("auto"));
    };
    Node* node = element.firstChildNode();
    while (node) {
        charge(ctx, work::kNodeVisit);
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
                    chargeScan(ctx, i + 1);
                    return direction == U_LEFT_TO_RIGHT ? "ltr" : "rtl";
                }
            }
            chargeScan(ctx, view.length);
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
/// must agree with a rebuild). Each attribute is charged work::kRenderAttribute plus chargeScan of its value; profile 1
/// decides what the renderer gets of it (markup::renderAttribute, V4 plan, Task 5): one it drops by name is skipped
/// before its value is read, and one whose output name repeats an earlier one is left out; a `style` over 16 KiB is
/// left out (styleTooLong); the budget is kMaxRenderBytes counting the names and values read from `usedBefore` on, and
/// the attribute that would pass it ends the scan (overBudget). A text attribute's value and a `style`'s strings are
/// counted against profile 1's text budgets from `unitsBefore` on (V4 plan, Task 7): one that does not fit is left out
/// (textLeftOut).
RenderAttributes scanAttributes(JSContext* ctx, AtomNames& names, DOMState& state, Element& element,
                                const markup::RenderTag& rendered, size_t usedBefore, TextUnits unitsBefore,
                                bool keepInput) {
    RenderAttributes out;
    std::unordered_set<std::string> keys;
    // A host marker (data-tg-tag, data-tg-link) goes to litehtml and the render input; the widget cannot write one
    // (data-tg-* is dropped). Charged as an attribute is, it costs the widget's byte budget nothing.
    const auto addHostMarker = [&](const char* name, const std::string& value) {
        charge(ctx, work::kRenderAttribute);
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
    for (size_t i = 0; i < element.attributeCount(); i++) {
        const Attribute& attribute = element.attributeAt(i);
        charge(ctx, work::kRenderAttribute);
        const std::string qualified = qualifiedAttributeName(names, attribute);
        String value = String::adopt(ctx, JS_DupValue(ctx, attribute.value.value));
        chargeScan(ctx, value.length());
        if (!markup::attributeMayRender(ns, rendered.tag, qualified)) {
            continue;
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
            charge(ctx, uint64_t(utf8.size()) * work::kCssByte);
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
        const bool placeholder = ns == markup::ElementNamespace::HTML && rendered.tag == "img" && decided.name == "src" &&
                                 !css::policy::imageSourceKept(decided.value);
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
        if (!renderTextFits(units, unitsBefore + out.units)) {
            out.textLeftOut = true;
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
    // animations origin (VENDOR.md edit 27). Counted and charged as a style attribute is; past the budget the scan ends.
    if (const JSText* animated = animation::AnimationState::animatedStyleOf(ctx, element)) {
        const size_t name = std::char_traits<char>::length(litehtml::animated_style_attribute);
        if (usedBefore + out.bytes + name + animated->size() > kMaxRenderBytes) {
            out.overBudget = true;
            return out;
        }
        charge(ctx, uint64_t(animated->size()) * work::kCssByte);
        out.bytes += name + animated->size();
        out.map[litehtml::animated_style_attribute] = std::string(*animated);
    }
    return out;
}

class Builder {
public:
    Builder(JSContext* ctx, WidgetContainer& container, RenderBuild& build)
        : m_ctx(ctx), m_rt(JS_GetRuntime(ctx)), m_state(DOMState::of(ctx)), m_container(container), m_build(build),
          m_keepInput(container.options().keepRenderInput) {}

    /// The subtree mode (Task 9): one node's subtree, built detached with the published document, within what the rest of
    /// the document uses of the limits.
    Builder(JSContext* ctx, WidgetContainer& container, const RenderSubtreePlace& place, RenderBuild& staging,
            const RenderSubtreeTotals& totals, std::vector<litehtml::element::ptr>& roots)
        : m_ctx(ctx), m_rt(JS_GetRuntime(ctx)), m_state(DOMState::of(ctx)), m_container(container), m_build(staging),
          m_keepInput(container.options().keepRenderInput), m_roots(&roots) {
        m_doc = place.document;
        m_baseDepth = place.parentDepth;
        m_bytes = totals.bytes;
        m_units = totals.textUnits;
        m_nodes = totals.nodes;
        m_elements = totals.elements;
        m_formControls = totals.formControls;
        m_textSeq = totals.seq;
        // The parent's frame: the bottom of the stack, never closed. Its element is not built here.
        m_stack.push_back(Frame{place.parent, place.parentElement, std::string(), place.rawText, place.silent, nullptr});
    }

    /// Builds `node`'s subtree; false where a fresh build would post a render limit inside it or meet a `<style>`.
    bool runSubtree(Node& node, RenderSubtreeTotals& totals) {
        this->walk(node);
        totals.bytes = m_bytes;
        totals.textUnits = m_units;
        totals.nodes = m_nodes;
        totals.elements = m_elements;
        totals.formControls = m_formControls;
        totals.seq = m_textSeq;
        return !m_refused;
    }

    void run() {
        Document& document = m_state.document();
        m_build.document = std::make_shared<litehtml::document>(&m_container);
        m_doc = m_build.document.get();
        // The mode decides how attributes are read (html_tag::set_attr) and the quirks rules: before any element.
        m_doc->set_document_mode(modeOf(document.mode()));
        // SDK v1 §2.3: the theme's variables, on the root after its own style (twidget edit 26).
        const std::string& rootDeclarations = m_container.options().rootDeclarations;
        charge(m_ctx, uint64_t(rootDeclarations.size()) * work::kCssByte);
        m_doc->set_root_declarations(rootDeclarations);
        m_container.beginBuild();
        this->append("<!doctype html>");
        if (Element* root = document.documentElementNode()) {
            this->walk(*root);
        }
        if (!m_root) {
            // No document element, or none rendered: an empty html (Ruling 11). Nothing of the DOM maps to it.
            charge(m_ctx, work::kRenderNode);
            if (m_doc->external_element_allowed(0)) {
                m_root = m_doc->create_element("html", litehtml::string_map());
                m_build.boxes++;
            }
            this->append("<html></html>");
        }
        const std::string& hostCSS = m_container.options().hostCSS;
        charge(m_ctx, uint64_t(hostCSS.size()) * work::kCssByte);
        // Ruling E19: matching gets one selector-step budget for the whole build, litehtml's 4,000,000 or what the
        // widget's work budget allows, whichever is less, and is charged for the steps it took. Cut by the work budget, the
        // build stops the widget (Budget) and is dropped; cut by litehtml's own budget, it is the document's.
        const int64_t limit = std::min(litehtml::document::default_selector_steps, renderSelectorAllowance(m_ctx));
        // Ruling E21: apply_selector's filter loop tests every rule against every element, counted by no step: it is
        // paid for at work::kScanEightUnits per eight (element, rule) pairs. The sheets' rule counts are known only inside
        // finalize, so its gate asks before each pass whether the budget holds the loop so far (it charges nothing there:
        // nothing charges inside litehtml); declined, finalize matches nothing and the build stops the widget (Budget).
        // The elements are litehtml's bound (Ruling E22: matching_bound): each one built, the two pseudo-elements a
        // ::before/::after rule can create for it, the parts a form control makes. And the steps get what the loop leaves
        // of the budget.
        uint64_t filterUnits = 0;
        uint64_t matchedBound = 0;
        JSContext* ctx = m_ctx;
        litehtml::document* doc = m_doc;
        m_doc->set_matching_gate([ctx, doc, &filterUnits, &matchedBound](size_t rules, size_t matched) {
            filterUnits += renderFilterUnits(matched, rules);
            matchedBound = matched;
            const int64_t allowance = renderSelectorAllowance(ctx) * int64_t(work::kSimpleSelectorTest);
            if (int64_t(filterUnits) > allowance) {
                return false;
            }
            const int64_t steps = (allowance - int64_t(filterUnits)) / int64_t(work::kSimpleSelectorTest);
            doc->set_selector_step_limit(std::min(doc->selector_step_limit(), steps));
            return true;
        });
        int64_t used = 0;
        {
            struct Session {
                litehtml::document& document;
                int64_t& used;
                ~Session() {
                    used = document.end_selector_steps();
                    document.set_matching_gate(nullptr);
                }
            } session{*m_doc, used};
            m_doc->begin_selector_steps(limit);
            m_doc->finalize_from_external_root(m_root, masterWithHostCSS(hostCSS), "");
        }
        // The limit as the gate left it; cut below litehtml's own, the budget ran out.
        const int64_t cut = m_doc->selector_step_limit();
        if (m_doc->matching_gated() || (used > cut && cut < litehtml::document::default_selector_steps)) {
            Runtime::from(m_ctx).stop(StopReason::Budget);
            throw Aborted{};
        }
        charge(m_ctx, filterUnits);
        charge(m_ctx, uint64_t(std::min(used, cut)) * work::kSimpleSelectorTest);
        m_build.selectorSteps = used;
        m_build.filterUnits = filterUnits;
        m_build.stepUnits = uint64_t(std::min(used, cut)) * work::kSimpleSelectorTest;
        // The bound the last pass was asked with (all three sheets' creators): a rebuild's filter loop is at most that many
        // elements against every rule (renderFilterUnits(matched, selector_count()) covers both passes).
        m_build.matched = matchedBound;
        collectContainerLimits(m_container, m_build.limits);
        m_build.bytes = m_bytes;
        m_build.textUnits = m_units;
        m_build.nodeCount = m_nodes;
        m_build.elementCount = m_elements;
        m_build.formControlCount = m_formControls;
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

    /// What the build refuses in the subtree mode, where a full build would post a limit: the patch rebuilds.
    Step refuse() {
        m_refused = true;
        return Step::Stop;
    }

    /// Adds `count` nodes to the node count (RB §7.1 MAX_NODES); false once past kMaxRenderNodes, which a build notes and
    /// the subtree mode refuses: the walk stops.
    bool countNodes(size_t count) {
        m_nodes += count;
        if (m_nodes <= kMaxRenderNodes) {
            return true;
        }
        if (m_roots) {
            this->refuse();
        } else {
            noteLimit(m_build.limits, "nodes");
        }
        return false;
    }

    bool isScript(Node& node) const {
        return node.isElement() && static_cast<Element&>(node).hasHTMLName(m_state.name(Name::script));
    }

    /// The nodes under `root`, whose children the walk does not build, counted at work::kNodeVisit each; a `<script>`'s
    /// children are not counted (the reference's sandbox never sends them). False once past the cap.
    bool countUnbuilt(Node& root) {
        if (this->isScript(root)) {
            return true;
        }
        Node* node = root.firstChildNode();
        while (node) {
            charge(m_ctx, work::kNodeVisit);
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
            charge(m_ctx, work::kRenderNode);
            // Close the elements `node` is not inside: its parent is the innermost open one (every visited node's
            // parent was rendered: a subtree that is not is skipped whole).
            while (m_stack.size() > this->baseFrames() && m_stack.back().node != node->parent()) {
                this->close();
            }
            // Profile 1's node cap (V4 plan, Task 7), in tree order: every node the walk visits, and the ones under a node
            // whose children it does not build.
            if (!this->countNodes(1)) {
                break;
            }
            Step step = Step::SkipChildren;
            if (node != &root && m_stack.empty()) {
                step = Step::SkipChildren;
            } else if (node->isElement()) {
                step = this->element(static_cast<Element&>(*node));
            } else if (node->type() == NodeType::Text) {
                step = this->text(static_cast<CharacterData&>(*node));
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

    size_t remainingBytes() const { return kMaxRenderBytes - m_bytes; }

    Step element(Element& element) {
        const markup::RenderTag rendered = tagOf(m_ctx, m_names, m_state, element);
        if (!rendered.rendered) {
            return Step::SkipChildren;
        }
        // Which html, head and body are the document's own can move with the structure: rebuild.
        if (m_roots && element.ns() == Namespace::HTML &&
            (isRootName(rendered.tag) || isRootName(rendered.dataTgTag))) {
            return this->refuse();
        }
        // W's limits are asked before litehtml's caps, so an element past one takes no slot of litehtml's.
        if (m_elements >= kMaxElements) {
            if (m_roots) {
                return this->refuse();
            }
            noteLimit(m_build.limits, "elements");
            return Step::SkipChildren;
        }
        const bool formControl = isFormControl(rendered.tag);
        if (formControl && m_formControls >= kMaxFormControls) {
            if (m_roots) {
                return this->refuse();
            }
            noteLimit(m_build.limits, "form-controls");
            return Step::SkipChildren;
        }
        const int depth = m_baseDepth + int(m_stack.size());
        if (m_roots) {
            // litehtml's depth cap, asked without counting (twidget edit 18 counts the elements it links).
            if (depth >= litehtml::document::max_external_depth) {
                return this->refuse();
            }
        } else if (!m_doc->external_element_allowed(depth)) {
            collectContainerLimits(m_container, m_build.limits);
            return Step::SkipChildren;
        }
        // The render input's names and start tag only when it is kept (Ruling E11).
        const std::string tagName = m_keepInput ? rendered.tag : std::string();
        RenderAttributes scanned =
            scanAttributes(m_ctx, m_names, m_state, element, rendered, m_bytes, m_units, m_keepInput);
        if (m_roots && (scanned.styleTooLong || scanned.overBudget || scanned.textLeftOut)) {
            return this->refuse();
        }
        if (scanned.styleTooLong) {
            noteLimit(m_build.limits, "style-attribute");
        }
        if (scanned.textLeftOut) {
            noteLimit(m_build.limits, "text-budget");
        }
        if (scanned.overBudget) {
            noteLimit(m_build.limits, "bytes");
            return Step::Stop;
        }
        m_bytes += scanned.bytes;
        m_units += scanned.units;
        litehtml::string_map& attributes = scanned.map;
        const std::string startTag = m_keepInput ? "<" + tagName + scanned.text + ">" : std::string();

        // A `<style>` in an inserted subtree is a document-level change (its sheet), which the fork refuses: rebuild
        // before anything of it is made.
        if (m_roots && rendered.stylesheet) {
            return this->refuse();
        }
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
            if (created->parent() != parent) {
                // litehtml counted it (external_element_allowed, or the patch's predicate through refusedElements).
                m_build.refusedElements++;
                // The parent's own appendChild refused it: a <table> takes its row groups and caption only (a <style>
                // refuses too, and its children are not walked).
                return Step::SkipChildren;
            }
        }
        RenderEntry& entry = this->map(element, created);
        entry.bytes = scanned.bytes;
        entry.units = scanned.units;
        entry.seq = m_textSeq++;
        m_build.boxes++;
        m_elements++;
        if (formControl) {
            m_formControls++;
        }
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
            this->styleSheet(element, created, rawText);
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

    /// The sheet of a `<style>` (Ruling 10), within the 64 KiB of `<style>` text (Ruling 7).
    void styleSheet(Element& style, const litehtml::element::ptr& created, bool raw) {
        // Its Text children's length first, so a sheet too long to apply is never copied or converted.
        size_t units = 0;
        for (size_t i = 0; i < style.childCount(); i++) {
            charge(m_ctx, work::kRenderNode);
            Node* child = style.childAt(i);
            if (child->type() == NodeType::Text) {
                units += static_cast<CharacterData*>(child)->dataString(m_ctx).length();
            }
        }
        // work::kCssByte per byte, whether the sheet is applied or not: its length (a lower bound of its UTF-8 length)
        // now, and the rest of its UTF-8 once converted.
        charge(m_ctx, uint64_t(units) * work::kCssByte);
        const size_t room = kMaxStyleText - m_cssBytes;
        std::string utf8;
        if (units > room) {
            noteLimit(m_build.limits, "css");
            return;
        }
        String sheet = childTextContent(m_ctx, style);
        chargeScan(m_ctx, sheet.length());
        const bool fits = utf8AtMost(sheet, room, utf8);
        charge(m_ctx, uint64_t(utf8.size() - std::min(utf8.size(), units)) * work::kCssByte);
        if (!fits) {
            noteLimit(m_build.limits, "css");
            return;
        }
        // Profile 1's text budgets (V4 plan, Task 7; RB §7.2): the sheet's text, and the contents of its strings. A sheet
        // that does not fit is not applied, and counts nothing.
        const TextUnits text = renderTextUnits(sheet);
        const TextUnits strings = renderCssStringUnits(utf8);
        if (!renderTextFits(text, m_units) || !renderTextFits(strings, m_units + text)) {
            noteLimit(m_build.limits, "text-budget");
            return;
        }
        m_units += text + strings;
        if (utf8.empty()) {
            return;
        }
        std::vector<litehtml::element::ptr> pieces;
        m_doc->append_text(created, utf8.c_str(), pieces);
        collectContainerLimits(m_container, m_build.limits);
        if (pieces.empty()) {
            return;
        }
        m_cssBytes += utf8.size();
        m_build.styleSheets.push_back(utf8);
        if (!m_build.usesUserActionPseudo) {
            m_build.usesUserActionPseudo = mentionsUserActionPseudo(utf8);
        }
        for (const litehtml::element::ptr& piece : pieces) {
            m_build.elements.emplace(piece.get(), &style);
        }
        m_build.boxes += pieces.size();
        this->appendText(utf8, raw);
    }

    Step text(CharacterData& text) {
        Frame& parent = m_stack.back();
        String data = text.dataString(m_ctx);
        chargeScan(m_ctx, data.length());
        // Profile 1's text limits (V4 plan, Task 7; RB §7.1): a Text over kMaxTextValueUnits, or one the document's text
        // budgets have no room left for, is mapped and renders nothing; the walk goes on.
        const TextUnits units = renderTextUnits(data);
        if (!renderTextFits(units, m_units)) {
            if (m_roots) {
                return this->refuse();
            }
            noteLimit(m_build.limits, units.units > kMaxTextValueUnits ? "text-node" : "text-budget");
            RenderEntry& entry = this->map(text, nullptr);
            entry.seq = m_textSeq++;
            return Step::SkipChildren;
        }
        std::string utf8;
        if (!utf8AtMost(data, this->remainingBytes(), utf8)) {
            if (m_roots) {
                return this->refuse();
            }
            noteLimit(m_build.limits, "bytes");
            return Step::Stop;
        }
        m_bytes += utf8.size();
        m_units += units;
        std::vector<litehtml::element::ptr> pieces;
        bool all = true;
        if (m_roots) {
            // Made without asking the cap (twidget edit 18 counts them); the parent's own appendChild decides, as
            // append_text's does, except under the parent of the subtree, which nothing here attaches to.
            std::vector<litehtml::element::ptr> made;
            m_doc->make_text_pieces(parent.element, utf8.c_str(), made);
            for (const litehtml::element::ptr& piece : made) {
                if (m_stack.size() == 1) {
                    pieces.push_back(piece);
                    m_roots->push_back(piece);
                } else {
                    m_doc->insert_child(parent.element, parent.element->children().size(), piece);
                    if (piece->parent() == parent.element) {
                        pieces.push_back(piece);
                    } else {
                        m_build.refusedPieces++;
                    }
                }
            }
        } else {
            all = m_doc->append_text(parent.element, utf8.c_str(), pieces);
            if (!all) {
                collectContainerLimits(m_container, m_build.limits);
            }
            // A <table> takes no Text: append_text asked the piece cap for each piece it then could not append.
            if (!utf8.empty() && parent.element && parent.element->tag() == litehtml::_table_) {
                m_build.refusedPieces++;
            }
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
        m_build.textBytes += utf8.size();
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

    RenderEntry& map(Node& node, litehtml::element::ptr element) {
        if (element) {
            m_build.elements.emplace(element.get(), &node);
        }
        auto [entry, inserted] =
            m_build.nodes.try_emplace(&node, Ref<Node>::retain(m_ctx, &node), std::move(element), m_rt);
        return entry->second;
    }

    JSContext* m_ctx;
    JSRuntime* m_rt;
    DOMState& m_state;
    WidgetContainer& m_container;
    RenderBuild& m_build;
    litehtml::document* m_doc = nullptr;
    litehtml::element::ptr m_root;
    /// The open elements, the root first: at most litehtml's depth cap deep.
    std::vector<Frame> m_stack;
    AtomNames m_names{m_ctx};
    /// The render byte budget used, and the `<style>` text applied (Ruling 7).
    size_t m_bytes = 0;
    size_t m_cssBytes = 0;
    /// Profile 1's text units counted, and the nodes counted from the document node on (V4 plan, Task 7).
    TextUnits m_units;
    size_t m_nodes = 1;
    /// The elements and the form controls rendered (Rulings E9 and E6).
    size_t m_elements = 0;
    size_t m_formControls = 0;
    /// The Text entries made so far (RenderEntry::seq).
    uint32_t m_textSeq = 0;
    const bool m_keepInput;
    /// The subtree mode's: where the roots go, the parent's depth, and whether a limit refused the subtree.
    std::vector<litehtml::element::ptr>* m_roots = nullptr;
    int m_baseDepth = 0;
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
    std::swap(boxes, other.boxes);
    std::swap(textBytes, other.textBytes);
    std::swap(naturalWidth, other.naturalWidth);
    std::swap(usesUserActionPseudo, other.usesUserActionPseudo);
    styleSheets.swap(other.styleSheets);
    std::swap(bytes, other.bytes);
    std::swap(textUnits, other.textUnits);
    std::swap(nodeCount, other.nodeCount);
    std::swap(elementCount, other.elementCount);
    std::swap(formControlCount, other.formControlCount);
    std::swap(nextSeq, other.nextSeq);
    std::swap(refusedElements, other.refusedElements);
    std::swap(refusedPieces, other.refusedPieces);
    std::swap(selectorSteps, other.selectorSteps);
    std::swap(walkCharge, other.walkCharge);
    std::swap(filterUnits, other.filterUnits);
    std::swap(stepUnits, other.stepUnits);
    std::swap(matched, other.matched);
}

uint64_t renderFilterUnits(uint64_t elements, uint64_t rules) {
    return elements * rules / 8 * work::kScanEightUnits;
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

bool renderTextFits(TextUnits value, TextUnits others) {
    return value.units <= kMaxTextValueUnits && others.units + value.units <= kTextBudgetUnits &&
           others.complex + value.complex <= kComplexTextBudgetUnits;
}

int64_t renderSelectorAllowance(JSContext* ctx) {
    const uint64_t limit = Runtime::from(ctx).workLimit();
    const uint64_t units = JS_GetWorkUnits(JS_GetRuntime(ctx));
    if (limit <= units + 1) {
        return 0;
    }
    const uint64_t steps = (limit - units - 1) / work::kSimpleSelectorTest;
    return steps > uint64_t(INT64_MAX / 2) ? INT64_MAX / 2 : int64_t(steps);
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

std::string renderEscapedText(std::string_view utf8) {
    std::string out;
    appendEscaped(out, utf8, false);
    return out;
}

void buildDocument(JSContext* ctx, WidgetContainer& container, RenderBuild& build) {
    Builder(ctx, container, build).run();
}

bool buildRenderSubtree(JSContext* ctx, WidgetContainer& container, const RenderSubtreePlace& place, Node& node,
                        RenderBuild& staging, RenderSubtreeTotals& totals, std::vector<litehtml::element::ptr>& roots) {
    return Builder(ctx, container, place, staging, totals, roots).runSubtree(node, totals);
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
