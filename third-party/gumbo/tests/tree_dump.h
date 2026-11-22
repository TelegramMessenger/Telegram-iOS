// Prints a gumbo tree in html5lib's tree-construction format ("| <html>", two spaces per level), which is what
// html5lib's .dat files expect and what the fork tests compare against.
#pragma once

#include <algorithm>
#include <cctype>
#include <string>
#include <utility>
#include <vector>

#include "gumbo.h"

namespace gumbo_test {

inline std::string tagName(const GumboElement& e) {
    if (e.tag_namespace == GUMBO_NAMESPACE_SVG && e.original_tag.length > 0) {
        GumboStringPiece piece = e.original_tag;
        gumbo_tag_from_original_text(&piece);
        if (const char* normalized = gumbo_normalize_svg_tagname(&piece)) {
            return normalized;
        }
    }
    if (e.tag != GUMBO_TAG_UNKNOWN) {
        return gumbo_normalized_tagname(e.tag);
    }
    GumboStringPiece piece = e.original_tag;
    gumbo_tag_from_original_text(&piece);
    std::string name(piece.data, piece.length);
    for (char& c : name) {
        c = char(std::tolower(static_cast<unsigned char>(c)));
    }
    return name;
}

inline std::string attributeName(const GumboAttribute& a) {
    switch (a.attr_namespace) {
    case GUMBO_ATTR_NAMESPACE_XLINK:
        return std::string("xlink ") + a.name;
    case GUMBO_ATTR_NAMESPACE_XML:
        return std::string("xml ") + a.name;
    case GUMBO_ATTR_NAMESPACE_XMLNS:
        return std::string("xmlns ") + a.name;
    default:
        return a.name;
    }
}

inline bool isText(const GumboNode* n) {
    return n->type == GUMBO_NODE_TEXT || n->type == GUMBO_NODE_WHITESPACE || n->type == GUMBO_NODE_CDATA;
}

inline void appendLine(std::string& out, int indent, const std::string& text) {
    out += "| ";
    out.append(size_t(indent) * 2, ' ');
    out += text;
    out += '\n';
}

inline void dumpChildren(const GumboVector& children, int indent, std::string& out);

inline void dumpNode(const GumboNode* n, int indent, std::string& out) {
    if (n->type == GUMBO_NODE_COMMENT) {
        appendLine(out, indent, std::string("<!-- ") + n->v.text.text + " -->");
        return;
    }
    if (n->type != GUMBO_NODE_ELEMENT && n->type != GUMBO_NODE_TEMPLATE) {
        return;
    }
    const GumboElement& e = n->v.element;
    const char* prefix = e.tag_namespace == GUMBO_NAMESPACE_SVG ? "svg " : e.tag_namespace == GUMBO_NAMESPACE_MATHML ? "math " : "";
    appendLine(out, indent, std::string("<") + prefix + tagName(e) + ">");
    std::vector<std::pair<std::string, std::string>> attributes;
    for (unsigned int i = 0; i < e.attributes.length; i++) {
        const auto* a = static_cast<const GumboAttribute*>(e.attributes.data[i]);
        attributes.emplace_back(attributeName(*a), a->value);
    }
    std::sort(attributes.begin(), attributes.end());
    for (const auto& a : attributes) {
        appendLine(out, indent + 1, a.first + "=\"" + a.second + "\"");
    }
    if (n->type == GUMBO_NODE_TEMPLATE) {
        appendLine(out, indent + 1, "content");
        dumpChildren(e.children, indent + 2, out);
    } else {
        dumpChildren(e.children, indent + 1, out);
    }
}

// Adjacent text nodes print as one, as html5lib's trees have them.
inline void dumpChildren(const GumboVector& children, int indent, std::string& out) {
    for (unsigned int i = 0; i < children.length; i++) {
        const auto* child = static_cast<const GumboNode*>(children.data[i]);
        if (!isText(child)) {
            dumpNode(child, indent, out);
            continue;
        }
        std::string text = child->v.text.text;
        while (i + 1 < children.length && isText(static_cast<const GumboNode*>(children.data[i + 1]))) {
            text += static_cast<const GumboNode*>(children.data[++i])->v.text.text;
        }
        appendLine(out, indent, "\"" + text + "\"");
    }
}

// A whole document, or with `fragment` the children of the fragment parser's root.
inline std::string dumpTree(const GumboOutput* output, bool fragment) {
    std::string out;
    if (fragment) {
        dumpChildren(output->root->v.element.children, 0, out);
        return out;
    }
    const GumboDocument& d = output->document->v.document;
    if (d.has_doctype) {
        std::string doctype = std::string("<!DOCTYPE ") + d.name;
        if (*d.public_identifier || *d.system_identifier) {
            doctype += std::string(" \"") + d.public_identifier + "\" \"" + d.system_identifier + "\"";
        }
        appendLine(out, 0, doctype + ">");
    }
    dumpChildren(d.children, 0, out);
    return out;
}

} // namespace gumbo_test
