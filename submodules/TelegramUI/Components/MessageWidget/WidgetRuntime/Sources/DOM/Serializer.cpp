#include "Sources/DOM/Serializer.h"

#include <string_view>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"

namespace wr {

namespace {

/// One run of the algorithm. Nothing it calls runs script, so the tree holds still while it walks: the views it keeps
/// (nodes, attribute entries) stay valid.
class Serializer {
public:
    explicit Serializer(JSContext* ctx)
        : m_ctx(ctx), m_state(DOMState::of(ctx)), m_out(JSAllocator<char16_t>(JS_GetRuntime(ctx))), m_stack(JSAllocator<Frame>(JS_GetRuntime(ctx))) {}

    void children(Node& node) {
        // Step 1: a void element serializes as nothing, whatever children script gave it.
        if (this->serializesAsVoid(node)) {
            return;
        }
        this->run(Frame{nullptr, this->childList(node), 0, this->hasRawTextChildren(node)});
    }

    void outer(Node& node) {
        // The fictional parent is not an element, so it would write a Text child escaped (outerHTML's is an element).
        if (this->start(node, false)) {
            auto& element = static_cast<Element&>(node);
            this->run(Frame{&element, this->childList(element), 0, this->hasRawTextChildren(element)});
        }
    }

    String finish() {
        this->chargeVisit(0);
        return String::fromUTF16(m_ctx, m_out.data(), m_out.size());
    }

private:
    /// A child list being written: the algorithm's recursion, kept on the heap.
    struct Frame {
        /// The element whose end tag follows the list; nullptr for the list serializeChildren writes.
        Element* element;
        /// The node whose children are written, or nullptr for no children (a template without contents).
        Node* list;
        size_t next;
        /// The children's parent is an element whose Text children are written as they are.
        bool rawText;
    };

    void run(Frame first) {
        m_stack.push_back(first);
        while (!m_stack.empty()) {
            Frame& frame = m_stack.back();
            if (!frame.list || frame.next == frame.list->childCount()) {
                if (frame.element) {
                    this->endTag(*frame.element);
                }
                m_stack.pop_back();
                continue;
            }
            Node& child = *frame.list->childAt(frame.next++);
            if (this->start(child, frame.rawText)) {
                auto& element = static_cast<Element&>(child);
                // `frame` is not used past here: the push may move it.
                m_stack.push_back(Frame{&element, this->childList(element), 0, this->hasRawTextChildren(element)});
            }
        }
    }

    bool serializesAsVoid(const Node& node) const {
        return node.isElement() && static_cast<const Element&>(node).isHTMLElement() && m_state.isVoidHTMLElement(static_cast<const Element&>(node).localNameAtom());
    }

    bool hasRawTextChildren(const Node& node) const {
        return node.isElement() && static_cast<const Element&>(node).isHTMLElement() && m_state.hasRawTextChildren(static_cast<const Element&>(node).localNameAtom());
    }

    /// The node whose children `node`'s serialization writes: a template's contents (step 3), else the node itself. A
    /// template that has no contents yet has none to write: reading markup does not make them.
    Node* childList(Node& node) {
        if (node.isElement() && static_cast<Element&>(node).hasHTMLName(m_state.name(Name::template_))) {
            auto& element = static_cast<HTMLTemplateElement&>(node);
            return element.hostsContents() ? element.content(m_ctx) : nullptr;
        }
        return &node;
    }

    /// Writes `node`, or an element's start tag, and answers whether the element's children and end tag follow.
    /// `rawTextParent`: the node's parent is an HTML element whose Text children are written as they are.
    bool start(Node& node, bool rawTextParent) {
        switch (node.type()) {
        case NodeType::Element: {
            auto& element = static_cast<Element&>(node);
            this->chargeVisit(work::kNodeVisit * (1 + element.attributeCount()));
            this->unit('<');
            this->tagName(element);
            for (size_t i = 0; i < element.attributeCount(); i++) {
                const Attribute& attribute = element.attributeAt(i);
                this->unit(' ');
                this->attributeName(attribute);
                this->ascii("=\"");
                this->escaped(String::adopt(m_ctx, JS_DupValue(m_ctx, attribute.value.value)), true);
                this->unit('"');
            }
            this->unit('>');
            return !this->serializesAsVoid(element);
        }
        case NodeType::Text: {
            this->chargeVisit(work::kNodeVisit);
            const String data = static_cast<CharacterData&>(node).dataString(m_ctx);
            if (rawTextParent) {
                this->append(data);
            } else {
                this->escaped(data, false);
            }
            return false;
        }
        case NodeType::Comment:
            this->chargeVisit(work::kNodeVisit);
            this->ascii("<!--");
            this->append(static_cast<CharacterData&>(node).dataString(m_ctx));
            this->ascii("-->");
            return false;
        case NodeType::DocumentType:
            this->chargeVisit(work::kNodeVisit);
            this->ascii("<!DOCTYPE ");
            this->append(static_cast<DocumentType&>(node).name(m_ctx));
            this->unit('>');
            return false;
        default:
            // This DOM makes no ProcessingInstruction or CDATASection nodes, and the rest are never children.
            this->chargeVisit(work::kNodeVisit);
            return false;
        }
    }

    void endTag(const Element& element) {
        this->ascii("</");
        this->tagName(element);
        this->unit('>');
    }

    /// An HTML, SVG or MathML element's local name; any other element's qualified name.
    void tagName(const Element& element) {
        Namespace ns = element.ns();
        if (ns != Namespace::HTML && ns != Namespace::SVG && ns != Namespace::MathML && element.prefixAtom() != JS_ATOM_NULL) {
            this->atom(element.prefixAtom());
            this->unit(':');
        }
        this->atom(element.localNameAtom());
    }

    /// The attribute's serialized name.
    void attributeName(const Attribute& attribute) {
        switch (attribute.ns) {
        case Namespace::None:
            break;
        case Namespace::XML:
            this->ascii("xml:");
            break;
        case Namespace::XMLNS:
            // The spec's case reads the local name only: an `xmlns` attribute with any prefix is "xmlns".
            if (attribute.localName.atom == m_state.name(Name::xmlns)) {
                this->ascii("xmlns");
                return;
            }
            this->ascii("xmlns:");
            break;
        case Namespace::XLink:
            this->ascii("xlink:");
            break;
        default:
            // Any other namespace: the qualified name.
            if (attribute.prefix.atom != JS_ATOM_NULL) {
                this->atom(attribute.prefix.atom);
                this->unit(':');
            }
            break;
        }
        this->atom(attribute.localName.atom);
    }

    /// Charges `visitUnits`, and work::kSerializeFourBytes per four units written since the last charge, so a long
    /// serialization is charged as it goes, one node's output behind at most. Fewer than four units carry over to the
    /// next charge: the whole costs floor(length / 4), however many nodes wrote it.
    void chargeVisit(uint64_t visitUnits) {
        size_t fours = (m_out.size() - m_charged) / 4;
        m_charged += fours * 4;
        charge(m_ctx, visitUnits + uint64_t(fours) * work::kSerializeFourBytes);
    }

    void unit(char16_t c) { m_out.push_back(c); }

    void ascii(std::string_view text) {
        for (char c : text) {
            m_out.push_back(char16_t(c));
        }
    }

    void atom(JSAtom atom) { this->append(String::fromAtom(m_ctx, atom)); }

    void append(const String& s) {
        JSStringView view = s.view();
        if (view.latin1) {
            m_out.insert(m_out.end(), view.latin1, view.latin1 + view.length);
        } else if (view.utf16) {
            m_out.insert(m_out.end(), view.utf16, view.utf16 + view.length);
        }
    }

    /// HTML's "escaping a string" (since 2025): &, U+00A0, < and > in both modes; " in attribute mode too.
    void escaped(const String& s, bool attributeMode) {
        JSStringView view = s.view();
        if (view.latin1) {
            this->escapedUnits(view.latin1, view.length, attributeMode);
        } else if (view.utf16) {
            this->escapedUnits(view.utf16, view.length, attributeMode);
        }
    }

    template <class Unit>
    void escapedUnits(const Unit* units, uint32_t length, bool attributeMode) {
        uint32_t written = 0;
        for (uint32_t i = 0; i < length; i++) {
            std::string_view entity;
            switch (units[i]) {
            case '&':
                entity = "&amp;";
                break;
            case 0xA0:
                entity = "&nbsp;";
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
            default:
                break;
            }
            if (!entity.empty()) {
                m_out.insert(m_out.end(), units + written, units + i);
                this->ascii(entity);
                written = i + 1;
            }
        }
        m_out.insert(m_out.end(), units + written, units + length);
    }

    JSContext* m_ctx;
    DOMState& m_state;
    Vector<char16_t> m_out;
    /// How much of m_out has been charged for: a multiple of four.
    size_t m_charged = 0;
    Vector<Frame> m_stack;
};

} // namespace

String serializeChildren(JSContext* ctx, Node& node) {
    Serializer serializer(ctx);
    serializer.children(node);
    return serializer.finish();
}

String serializeOuter(JSContext* ctx, Node& node) {
    Serializer serializer(ctx);
    serializer.outer(node);
    return serializer.finish();
}

} // namespace wr
