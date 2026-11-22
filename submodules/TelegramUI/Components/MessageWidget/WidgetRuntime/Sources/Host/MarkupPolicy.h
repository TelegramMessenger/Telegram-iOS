// Profile 1's markup rules (V4 plan, Tasks 4 and 5): what the renderer's copy of an element is, and which of its
// attributes it carries, as the reference validator decides them (widget-sandbox v0.1.0 validator.ts, opEl and
// sanitizeAttr; .superpowers research RB §1 and §2), read from the profile's tables (Profile.h). Pure: nothing here
// throws or reads the DOM, so a build, a patch and the render input decide alike.
#pragma once

#include <cstdint>
#include <string>
#include <string_view>

namespace wr::markup {

enum class ElementNamespace : uint8_t { HTML, SVG, Other };

/// An element as the renderer's copy holds it.
struct RenderTag {
    /// Whether it (and so its subtree) is in the build at all.
    bool rendered = false;
    /// A <style> (in either namespace): its text is a sheet.
    bool stylesheet = false;
    /// The tag litehtml gets: the lowered HTML name, the canonical SVG name, or span / div.
    std::string tag;
    /// The lowered original name when the element is rendered under another tag (data-tg-tag's value), else empty.
    std::string dataTgTag;
};

/// RB §1.1–§1.4: a name over 64 code units or outside `^[a-zA-Z][\w.\-]*$`, or any namespace but HTML and SVG, is not
/// rendered; `style` is a sheet; an HTML element follows html.elements (an unknown one html.unknown), and an html, head
/// or body that is not the document's own (`adoptedRoot` false) is a div; an SVG element must be in svg.elements.
RenderTag renderTagFor(ElementNamespace ns, std::string_view localName, bool adoptedRoot);

/// An attribute as the renderer's copy carries it.
struct RenderAttributeDecision {
    bool kept = false;
    /// The name litehtml gets: lowered (data-*, aria-*, HTML), canonical (SVG: viewBox), href for an SVG xlink:href.
    std::string name;
    std::string value;
    /// An external link: data-tg-link="" goes with href="#" (RB §2.4).
    bool addsLink = false;
};

/// RB §2.1–§2.4, in the reference's order: a malformed name or one starting "on" is dropped; style is kept (its CSS
/// meets the profile's hooks); the URL attributes follow their rules (a[href] becomes a fragment or "#" plus a link
/// marker, an SVG use or gradient href must be a fragment, an HTML img src is kept as written for the image rule, every
/// other URL attribute is dropped); data-tg-* is the host's; data-* and aria-* are kept; anything else must be in the
/// namespace's attribute table, and an SVG attribute whose value is CSS must pass the CSS value rules.
RenderAttributeDecision renderAttribute(ElementNamespace ns, std::string_view renderedTag, std::string_view qualifiedName,
                                        std::string_view value);
/// False when renderAttribute drops the attribute whatever its value (its name decides): the builder then skips it
/// before converting its value.
bool attributeMayRender(ElementNamespace ns, std::string_view renderedTag, std::string_view qualifiedName);

} // namespace wr::markup
