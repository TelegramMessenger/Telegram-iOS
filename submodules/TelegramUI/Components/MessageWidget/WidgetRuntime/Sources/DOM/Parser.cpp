#include "Sources/DOM/Parser.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Sources/DOM/ParserInternal.h"
#include "gumbo.h"

namespace wr {

namespace {

class GumboOutputGuard {
public:
    GumboOutputGuard(const GumboOptions& options, GumboOutput* output) : m_options(options), m_output(output) {}
    ~GumboOutputGuard() { gumbo_destroy_output(&m_options, m_output); }
    GumboOutputGuard(const GumboOutputGuard&) = delete;
    GumboOutputGuard& operator=(const GumboOutputGuard&) = delete;

private:
    GumboOptions m_options;
    GumboOutput* m_output;
};

/// A tag name read from the source text, as the tokenizer's tag name state makes it: ASCII lowercased, and a NUL
/// replaced by U+FFFD (gumbo keeps only the source text of a name it has no tag for).
std::string nameFromSource(const char* data, size_t length) {
    std::string out;
    out.reserve(length);
    for (size_t i = 0; i < length; i++) {
        char c = data[i];
        if (c == '\0') {
            out += "\xEF\xBF\xBD";
        } else {
            out += char(std::tolower(static_cast<unsigned char>(c)));
        }
    }
    return out;
}

/// Builds DOM nodes from gumbo's tree. It recurses once per level (appendChildren, build, buildElement), which is safe
/// only because ParseLimits::maxDepth bounds it: deeper content is never visited. gumbo itself is iterative and keeps
/// its tree within its own max_tree_depth (512).
class Builder {
public:
    /// `inTemplateContents`: the nodes go into a template's contents, which are not connected.
    Builder(JSContext* ctx, Document& document, const ParseLimits& limits, bool fragment, bool inTemplateContents = false)
        : m_ctx(ctx), m_document(document), m_limits(limits), m_fragment(fragment), m_inTemplateContents(inTemplateContents) {}

    /// Appends `children` to `parent`; `depth` is the depth of the children (the document's children are at 1).
    void appendChildren(const GumboVector& children, Node& parent, uint32_t depth) {
        if (depth > m_limits.maxDepth) {
            return;
        }
        for (unsigned int i = 0; i < children.length; i++) {
            const GumboNode& node = child(children, i);
            Ref<Node> built;
            if (isText(node)) {
                // HTML's "insert a character" appends to the Text node right before the insertion point, so the DOM
                // never has two adjacent Text children from parsing. gumbo makes a node per flush of its text buffer
                // (foster-parented text, say), so a run of them becomes one Text. `parent` is this parse's own (gumbo
                // drops text at the document level) and gets all its children here, so the run is the whole of what
                // precedes. The run's text is joined once: appending to a Text per node would copy it per node.
                unsigned int end = i + 1;
                while (end < children.length && isText(child(children, end))) {
                    end++;
                }
                if (end == i + 1) {
                    built = Text::make(m_ctx, m_document, String::fromUTF8(m_ctx, node.v.text.text));
                } else {
                    std::string data;
                    for (unsigned int j = i; j < end; j++) {
                        data += child(children, j).v.text.text;
                    }
                    built = Text::make(m_ctx, m_document, String::fromUTF8(m_ctx, data));
                }
                i = end - 1;
            } else {
                built = this->build(node, depth);
            }
            if (built) {
                parent.insertChildAt(m_ctx, parent.childCount(), *built);
            }
        }
    }

private:
    static const GumboNode& child(const GumboVector& children, unsigned int i) { return *static_cast<const GumboNode*>(children.data[i]); }
    static bool isText(const GumboNode& node) {
        return node.type == GUMBO_NODE_TEXT || node.type == GUMBO_NODE_WHITESPACE || node.type == GUMBO_NODE_CDATA;
    }

    /// An element or a comment (text runs are appendChildren's).
    Ref<Node> build(const GumboNode& node, uint32_t depth) {
        switch (node.type) {
        case GUMBO_NODE_ELEMENT:
        case GUMBO_NODE_TEMPLATE:
            return this->buildElement(node, depth);
        case GUMBO_NODE_COMMENT:
            return Ref<Node>(Comment::make(m_ctx, m_document, String::fromUTF8(m_ctx, node.v.text.text)));
        default:
            return Ref<Node>();
        }
    }

    std::string elementName(const GumboElement& e, Namespace ns) {
        GumboStringPiece piece = e.original_tag;
        if (piece.length > 0) {
            gumbo_tag_from_original_text(&piece);
        }
        if (ns == Namespace::SVG && piece.length > 0) {
            if (const char* normalized = gumbo_normalize_svg_tagname(&piece)) {
                return normalized;
            }
            return nameFromSource(piece.data, piece.length);
        }
        if (e.tag != GUMBO_TAG_UNKNOWN) {
            return gumbo_normalized_tagname(e.tag);
        }
        return nameFromSource(piece.data, piece.length);
    }

    Ref<Node> buildElement(const GumboNode& node, uint32_t depth) {
        const GumboElement& e = node.v.element;
        Namespace ns = e.tag_namespace == GUMBO_NAMESPACE_SVG ? Namespace::SVG : e.tag_namespace == GUMBO_NAMESPACE_MATHML ? Namespace::MathML : Namespace::HTML;
        Atom name = Atom::fromUTF8(m_ctx, this->elementName(e, ns));
        Ref<Element> element = createElementNode(m_ctx, m_document, ns, name.get(), JS_ATOM_NULL, JS_ATOM_NULL);
        for (unsigned int i = 0; i < e.attributes.length; i++) {
            const auto* a = static_cast<const GumboAttribute*>(e.attributes.data[i]);
            Namespace attributeNamespace = Namespace::None;
            const char* prefix = nullptr;
            switch (a->attr_namespace) {
            case GUMBO_ATTR_NAMESPACE_XLINK:
                attributeNamespace = Namespace::XLink;
                prefix = "xlink";
                break;
            case GUMBO_ATTR_NAMESPACE_XML:
                attributeNamespace = Namespace::XML;
                prefix = "xml";
                break;
            case GUMBO_ATTR_NAMESPACE_XMLNS:
                attributeNamespace = Namespace::XMLNS;
                // "xmlns" itself has no prefix; "xmlns:xlink" has the prefix xmlns.
                prefix = std::string_view(a->name) == "xmlns" ? nullptr : "xmlns";
                break;
            default:
                break;
            }
            Atom local = Atom::fromUTF8(m_ctx, a->name);
            Atom prefixAtom = prefix ? Atom::fromUTF8(m_ctx, prefix) : Atom();
            element->appendAttribute(m_ctx, attributeNamespace, JS_ATOM_NULL, prefixAtom.get(), local.get(), String::fromUTF8(m_ctx, a->value), nullptr);
        }
        if (ns == Namespace::HTML && element->hasHTMLName(DOMState::of(m_ctx).name(Name::script))) {
            // HTML's tree builder sets force async false for every script it makes, and the fragment parser marks each
            // of its scripts already started. The document parser sets a script's parser document, except in template
            // contents, where it sets none and leaves what "prepare the script element" at </script> would: that clears
            // the parser document, sets force async true unless the script has an async attribute (step 4), and returns
            // (step 7, not connected), so the script runs as a script-inserted one if the contents are inserted later.
            auto* script = static_cast<HTMLScriptElement*>(element.get());
            script->setForceAsync(false);
            if (m_fragment) {
                script->setAlreadyStarted(true);
            } else if (m_inTemplateContents) {
                script->setForceAsync(!script->hasAttributeAtom(m_ctx, DOMState::of(m_ctx).name(Name::async)));
            } else {
                script->setParserDocument(m_ctx, &m_document);
            }
        }
        if (node.type == GUMBO_NODE_TEMPLATE) {
            // gumbo gives an HTML <template> its contents as children; the DOM keeps them in the template's contents.
            DocumentFragment* content = static_cast<HTMLTemplateElement*>(element.get())->content(m_ctx);
            Builder inner(m_ctx, content->nodeDocument(), m_limits, m_fragment, true);
            inner.appendChildren(e.children, *content, depth + 1);
        } else {
            this->appendChildren(e.children, *element, depth + 1);
        }
        return Ref<Node>(std::move(element));
    }

    JSContext* m_ctx;
    Document& m_document;
    const ParseLimits& m_limits;
    bool m_fragment;
    bool m_inTemplateContents;
};

/// The length of gumbo's longest tag name ("annotation-xml"), from its own table.
size_t longestGumboTagName() {
    static const size_t longest = [] {
        size_t n = 0;
        for (int t = 0; t < GUMBO_TAG_LAST; t++) {
            n = std::max(n, std::strlen(gumbo_normalized_tagname(GumboTag(t))));
        }
        return n;
    }();
    return longest;
}

/// gumbo's tag for an element's local name. Only an ASCII name no longer than gumbo's longest can be one of its tags,
/// so any other is unknown without being read past that length: a local name can be megabytes long (Task 18, fix
/// round 1).
GumboTag tagOfLocalName(JSContext* ctx, JSAtom localName) {
    String name = String::fromAtom(ctx, localName);
    JSStringView v = name.view();
    char ascii[32];
    if (v.length > longestGumboTagName() || v.length > sizeof(ascii)) {
        return GUMBO_TAG_UNKNOWN;
    }
    for (uint32_t i = 0; i < v.length; i++) {
        char16_t c = v.latin1 ? v.latin1[i] : v.utf16[i];
        if (c >= 0x80) {
            return GUMBO_TAG_UNKNOWN;
        }
        ascii[i] = char(c);
    }
    return gumbo_tagn_enum(ascii, v.length);
}

GumboTag contextTag(JSContext* ctx, Element& context) {
    GumboTag tag = tagOfLocalName(ctx, context.localNameAtom());
    if (tag == GUMBO_TAG_UNKNOWN) {
        // An unknown HTML element parses its content like a <div>; foreign content like its namespace's root.
        return context.ns() == Namespace::HTML ? GUMBO_TAG_DIV : context.ns() == Namespace::MathML ? GUMBO_TAG_MATH : GUMBO_TAG_SVG;
    }
    return tag;
}

} // namespace

GumboOptions optionsFor(const ParseLimits& limits) {
    GumboOptions options = kGumboDefaultOptions;
    options.max_attributes = int(limits.maxAttributes);
    options.max_nodes = int(limits.maxNodes);
    options.max_total_attributes = int(limits.maxTotalAttributes);
    options.max_total_attribute_bytes = int(limits.maxTotalAttributeBytes);
    return options;
}

// The transient-heap bound. gumbo parses through malloc_wrapper, on the system allocator, so its tree is heap OUTSIDE
// the widget's memory limit (the DOM the Builder makes from it is js_malloc, counted). The limits do not stop one
// another, so every term below can be near its cap at once and the bound is their sum. Each limit is checked between
// tokens (as max_nodes is), and a token that is reprocessed in another insertion mode is handled again before that
// check, so each term carries one main-loop iteration's overshoot. I is the decoded input: what gumbo stores, at most
// 3 bytes per UTF-16 unit of script markup (kMaxDecodedBytesPerUnit) and 3 bytes per byte of a document.
//
// One iteration's clones. A reconstruction clones at most the formatting list's entries after its last marker
// (max_formatting_elements, 512). One iteration can reconstruct twice: a tag arriving after table text flushes the
// text with foster parenting (a reconstruction), and an <a> reprocessed in the table then runs the adoption agency,
// which pops those clones, and reconstructs them again (`<a><b>...</div><table>x<a>`: 1,017 clones from 508 entries).
// The adoption agency clones the formatting element once per outer iteration (8) and at most 3 inner nodes per
// iteration. So C = 2 x 512 + 8 x (1 + 3) = 1,056 clones, each of one element.
//
//   - Nodes: max_nodes (100,000) + C + 16 (the token's own element and what it implies: html, head, body, tbody, tr,
//     colgroup), each a GumboNode (144 B) plus 48 B: its own initial child vector (8), its slot in its parent's
//     children (8 B, at most 24 B while that vector doubles, old and new both live), its start tag's attribute
//     vector (8), and a text or comment string's NUL (1).
//   - Attributes: max_total_attributes (100,000) + (C + 1) x max_attributes (256) for the token's clones and its own,
//     each a GumboAttribute (104 B) plus its vector slot (at most 24 B while doubling).
//   - Attribute strings: max_total_attribute_bytes (8 MiB), plus the iteration's copies. Each entry of the formatting
//     list comes from a distinct start tag (a clone replaces its entry), so the entries' decoded bytes sum to at most
//     I. Within one iteration the adoption agency copies one entry at most 8 times and a reconstruction once more; on
//     the two-reconstruction path the adoption agency finds no furthest block above the flushed clones and copies
//     nothing, so an entry is copied at most twice there. So 9 x I, plus two NULs per copied attribute.
//     (`<a href="<3 MiB>">` + 8 `<div>` + `<a>`: the last token copies the value 8 times. A randomized search of
//     800,000 shapes over table, caption, template, select and foster-parenting contexts found no token copying one
//     value more than 8 times.)
//   - Text, tokenizer buffers and a token gumbo does not keep: 4 x I. Each decoded byte is held once in a final
//     string (a text node, a comment, a doctype) and in buffer capacity at most 3 times (a string buffer doubles,
//     and old and new are both live while it copies); the text, tag and temporary buffers hold disjoint parts of
//     the input. Measured on one text node: 2.25 x I for ASCII, 2.67 x I for CJK.
//   - Lists: the formatting list's entries are distinct elements or markers, the stack of open elements and the
//     template insertion modes are at most max_tree_depth (512): (nodes + 3 x 512) slots at 24 B.
//   - Fixed: the output, document node, parser and tokenizer states and their initial vectors and buffers, under
//     2 KiB; 16 KiB allowed.
//
// At the script cap (I = 3 MiB) that is 119,144,832 B (~113.6 MiB); at the boot document's 256 KiB source cap
// (I = 768 KiB), 88,473,984 B (~84.4 MiB). The terms that dominate are fixed by the limits: attribute structs 47.4 MB
// (34.6 MB of them one iteration's clone overshoot), attribute strings 37.2 MB (8.4 MB cap + 28.3 MB of one token's
// copies) and nodes 19.4 MB. ParserTests `testTransientHeapIsBounded` checks every shape against it for its own size
// — the peak, and the nodes, attributes and attribute bytes the tree keeps against their terms — with the real
// options, as a document and as a fragment, and pins this number. On top of it, the Builder holds the
// UTF-8 copy of script markup (<= 3 MiB) and one joined-text std::string, both bounded by the same length cap.
TransientHeapTerms transientHeapTerms(const ParseLimits& limits, size_t decodedInputBytes) {
    const GumboOptions options = optionsFor(limits);
    const size_t I = decodedInputBytes;
    const size_t perTag = size_t(options.max_attributes);
    const size_t depth = size_t(options.max_tree_depth);
    // Two reconstructions and the adoption agency's clones in one main-loop iteration (above).
    const size_t clones = 2 * size_t(options.max_formatting_elements) + 8 * (1 + 3);
    TransientHeapTerms terms;
    terms.nodes = size_t(options.max_nodes) + clones + 16;
    terms.attributes = size_t(options.max_total_attributes) + (clones + 1) * perTag;
    terms.attributeBytes = size_t(options.max_total_attribute_bytes) + 9 * I + 2 * (clones + 1) * perTag;
    const size_t text = 4 * I;
    const size_t lists = (terms.nodes + 3 * depth) * 24;
    const size_t fixed = 16 * 1024;
    terms.bytes = terms.nodes * (sizeof(GumboNode) + 48) + terms.attributes * (sizeof(GumboAttribute) + 24) + terms.attributeBytes + text +
                  lists + fixed;
    return terms;
}

ParseOutcome parseDocumentInto(JSContext* ctx, Document& document, std::string_view html, const ParseLimits& limits) {
    GumboOptions options = optionsFor(limits);
    GumboOutput* output = gumbo_parse_with_options(&options, html.data(), html.size());
    GumboOutputGuard guard(options, output);
    const GumboDocument& doc = output->document->v.document;
    if (doc.has_doctype) {
        // gumbo gives a doctype token's three fields as strings, empty when absent.
        Ref<DocumentType> doctype = create<DocumentType>(ctx, idl::kDocumentType, ctx, document, String::fromUTF8(ctx, doc.name),
                                                         String::fromUTF8(ctx, doc.public_identifier), String::fromUTF8(ctx, doc.system_identifier));
        document.insertChildAt(ctx, 0, *doctype);
    }
    switch (doc.doc_type_quirks_mode) {
    case GUMBO_DOCTYPE_QUIRKS:
        document.setMode(DocumentMode::Quirks);
        break;
    case GUMBO_DOCTYPE_LIMITED_QUIRKS:
        document.setMode(DocumentMode::LimitedQuirks);
        break;
    default:
        document.setMode(DocumentMode::NoQuirks);
        break;
    }
    Builder builder(ctx, document, limits, false);
    builder.appendChildren(doc.children, document, 1);
    document.noteMutation();
    return ParseOutcome{output->stopped_at_node_limit, output->stopped_at_attribute_limit};
}

Ref<DocumentFragment> parseFragment(JSContext* ctx, Element& context, std::string_view html, const ParseLimits& limits) {
    GumboOptions options = optionsFor(limits);
    options.fragment_context = contextTag(ctx, context);
    options.fragment_namespace = context.ns() == Namespace::SVG ? GUMBO_NAMESPACE_SVG : context.ns() == Namespace::MathML ? GUMBO_NAMESPACE_MATHML : GUMBO_NAMESPACE_HTML;
    GumboOutput* output = gumbo_parse_with_options(&options, html.data(), html.size());
    GumboOutputGuard guard(options, output);
    Document& document = context.nodeDocument();
    Ref<DocumentFragment> fragment = document.createDocumentFragment(ctx);
    Builder builder(ctx, document, limits, true);
    builder.appendChildren(output->root->v.element.children, *fragment, 1);
    return fragment;
}

} // namespace wr
