#include "Tests/Html5libDump.h"

#include <algorithm>
#include <utility>
#include <vector>

namespace wr_test {

namespace {

void appendLine(std::string& out, int indent, const std::string& text) {
    out += "| ";
    out.append(size_t(indent) * 2, ' ');
    out += text;
    out += '\n';
}

std::string atomText(JSContext* ctx, JSAtom atom) {
    return wr::String::fromAtom(ctx, atom).utf8();
}

std::string heldText(JSContext* ctx, const wr::Held& held) {
    return held.isUndefined() ? std::string() : wr::String::adopt(ctx, JS_DupValue(ctx, held.value)).utf8();
}

// html5lib's attribute names: "xlink href", "xml lang", "xmlns xlink" for the adjusted foreign attributes.
std::string attributeName(JSContext* ctx, const wr::Attribute& a) {
    std::string local = atomText(ctx, a.localName.atom);
    switch (a.ns) {
    case wr::Namespace::XLink:
        return "xlink " + local;
    case wr::Namespace::XML:
        return "xml " + local;
    case wr::Namespace::XMLNS:
        return "xmlns " + local;
    default:
        return local;
    }
}

void dumpChildren(JSContext* ctx, wr::Node& parent, int indent, std::string& out);

void dumpElement(JSContext* ctx, wr::Element& e, int indent, std::string& out) {
    const char* prefix = e.ns() == wr::Namespace::SVG ? "svg " : e.ns() == wr::Namespace::MathML ? "math " : "";
    appendLine(out, indent, std::string("<") + prefix + atomText(ctx, e.localNameAtom()) + ">");
    std::vector<std::pair<std::string, std::string>> attributes;
    for (size_t i = 0; i < e.attributeCount(); i++) {
        const wr::Attribute& a = e.attributeAt(i);
        attributes.emplace_back(attributeName(ctx, a), heldText(ctx, a.value));
    }
    std::sort(attributes.begin(), attributes.end());
    for (const auto& a : attributes) {
        appendLine(out, indent + 1, a.first + "=\"" + a.second + "\"");
    }
    if (e.hasHTMLName(wr::DOMState::of(ctx).name(wr::Name::template_)) && e.hostsContents()) {
        appendLine(out, indent + 1, "content");
        dumpChildren(ctx, *static_cast<wr::HTMLTemplateElement&>(e).content(ctx), indent + 2, out);
    } else {
        dumpChildren(ctx, e, indent + 1, out);
    }
}

// Each Text child prints on a line of its own. html5lib's trees never have two adjacent ones, and neither should the
// DOM the Builder makes (it joins gumbo's text runs): joining them here, as gumbo's dump must, would hide a run it left
// split. It recurses once per level, which the Builder's depth limit (256) bounds: this is a test's dump, not the
// library, where no recursion may grow with input.
void dumpChildren(JSContext* ctx, wr::Node& parent, int indent, std::string& out) {
    for (size_t i = 0; i < parent.childCount(); i++) {
        wr::Node* child = parent.childAt(i);
        switch (child->type()) {
        case wr::NodeType::Element:
            dumpElement(ctx, static_cast<wr::Element&>(*child), indent, out);
            break;
        case wr::NodeType::Comment:
            appendLine(out, indent, "<!-- " + static_cast<wr::CharacterData*>(child)->dataString(ctx).utf8() + " -->");
            break;
        case wr::NodeType::Text:
            appendLine(out, indent, "\"" + static_cast<wr::CharacterData*>(child)->dataString(ctx).utf8() + "\"");
            break;
        case wr::NodeType::DocumentType: {
            auto* doctype = static_cast<wr::DocumentType*>(child);
            std::string line = "<!DOCTYPE " + doctype->name(ctx).utf8();
            std::string publicId = doctype->publicId(ctx).utf8();
            std::string systemId = doctype->systemId(ctx).utf8();
            if (!publicId.empty() || !systemId.empty()) {
                line += " \"" + publicId + "\" \"" + systemId + "\"";
            }
            appendLine(out, indent, line + ">");
            break;
        }
        default:
            break;
        }
    }
}

} // namespace

std::string html5libDumpDocument(JSContext* ctx, wr::Document& document) {
    std::string out;
    dumpChildren(ctx, document, 0, out);
    return out;
}

std::string html5libDumpChildren(JSContext* ctx, wr::Node& parent) {
    std::string out;
    dumpChildren(ctx, parent, 0, out);
    return out;
}

} // namespace wr_test
