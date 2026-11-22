#include "Sources/DOM/Namespaces.h"

namespace wr {

Namespace namespaceOf(const std::optional<String>& uri) {
    if (!uri || uri->empty()) {
        return Namespace::None;
    }
    if (uri->equalsASCII(kHTMLNamespace)) return Namespace::HTML;
    if (uri->equalsASCII(kSVGNamespace)) return Namespace::SVG;
    if (uri->equalsASCII(kMathMLNamespace)) return Namespace::MathML;
    if (uri->equalsASCII(kXLinkNamespace)) return Namespace::XLink;
    if (uri->equalsASCII(kXMLNamespace)) return Namespace::XML;
    if (uri->equalsASCII(kXMLNSNamespace)) return Namespace::XMLNS;
    return Namespace::Other;
}

std::optional<String> namespaceURIOf(JSContext* ctx, Namespace ns, JSAtom other) {
    switch (ns) {
    case Namespace::None: return std::nullopt;
    case Namespace::HTML: return String::fromUTF8(ctx, kHTMLNamespace);
    case Namespace::SVG: return String::fromUTF8(ctx, kSVGNamespace);
    case Namespace::MathML: return String::fromUTF8(ctx, kMathMLNamespace);
    case Namespace::XLink: return String::fromUTF8(ctx, kXLinkNamespace);
    case Namespace::XML: return String::fromUTF8(ctx, kXMLNamespace);
    case Namespace::XMLNS: return String::fromUTF8(ctx, kXMLNSNamespace);
    case Namespace::Other: return String::fromAtom(ctx, other);
    }
    return std::nullopt;
}

} // namespace wr
