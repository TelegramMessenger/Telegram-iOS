#pragma once

#include <optional>
#include <string_view>

#include "Sources/Support/Values.h"

namespace wr {

/// The namespaces the DOM and the HTML parser name; anything else is Other with its URI kept as an atom.
enum class Namespace : uint8_t { None, HTML, SVG, MathML, XLink, XML, XMLNS, Other };

inline constexpr std::string_view kHTMLNamespace = "http://www.w3.org/1999/xhtml";
inline constexpr std::string_view kSVGNamespace = "http://www.w3.org/2000/svg";
inline constexpr std::string_view kMathMLNamespace = "http://www.w3.org/1998/Math/MathML";
inline constexpr std::string_view kXLinkNamespace = "http://www.w3.org/1999/xlink";
inline constexpr std::string_view kXMLNamespace = "http://www.w3.org/XML/1998/namespace";
inline constexpr std::string_view kXMLNSNamespace = "http://www.w3.org/2000/xmlns/";

/// The namespace an URI names (None for null or "").
Namespace namespaceOf(const std::optional<String>& uri);
/// The URI of a namespace (nullopt for None; `other` for Other).
std::optional<String> namespaceURIOf(JSContext* ctx, Namespace ns, JSAtom other);

} // namespace wr
