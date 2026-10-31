#include "Sources/Host/MarkupPolicy.h"

#include <litehtml/css_parser.h>

#include "Sources/Host/CSSPolicy.h"
#include "Sources/Host/Profile.h"

namespace wr::markup {

namespace {

std::string lowered(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
    return out;
}

bool isASCIIAlpha(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

/// `^[a-zA-Z][\w.\-]*$`, at most 64 code units (the reference's opEl; a non-ASCII byte fails, as \w is ASCII there).
bool wellFormedTagName(std::string_view name) {
    if (name.empty() || name.size() > 64 || !isASCIIAlpha(name[0])) {
        return false;
    }
    for (char c : name) {
        if (!(isASCIIAlpha(c) || (c >= '0' && c <= '9') || c == '_' || c == '.' || c == '-')) {
            return false;
        }
    }
    return true;
}

bool startsWith(std::string_view s, std::string_view prefix) {
    return s.size() >= prefix.size() && s.substr(0, prefix.size()) == prefix;
}

/// `^[a-zA-Z_][\w.:\-]*$` (the reference's canonAttrName).
bool wellFormedAttributeName(std::string_view name) {
    if (name.empty() || !(isASCIIAlpha(name[0]) || name[0] == '_')) {
        return false;
    }
    for (char c : name) {
        if (!(isASCIIAlpha(c) || (c >= '0' && c <= '9') || c == '_' || c == '.' || c == ':' || c == '-')) {
            return false;
        }
    }
    return true;
}

/// The attributes that carry a URL (the reference's URL_ATTRS): each follows the URL rules or is dropped.
bool isURLAttribute(std::string_view name) {
    static constexpr std::string_view kNames[] = {
        "action", "archive", "attributionsrc", "background", "cite", "classid", "codebase", "data", "dynsrc", "formaction",
        "href", "icon", "imagesizes", "imagesrcset", "longdesc", "lowsrc", "manifest", "ping", "poster", "profile", "src",
        "srcdoc", "srcset", "usemap"};
    for (std::string_view known : kNames) {
        if (name == known) {
            return true;
        }
    }
    return false;
}

RenderAttributeDecision kept(std::string name, std::string_view value, bool addsLink = false) {
    RenderAttributeDecision out;
    out.kept = true;
    out.name = std::move(name);
    out.value = std::string(value);
    out.addsLink = addsLink;
    return out;
}

/// Name-only verdict: false drops whatever the value; true lets renderAttribute decide (after the URL and SVG rules).
bool nameMayRender(ElementNamespace ns, const std::string& name) {
    if (startsWith(name, "on")) {
        return false;
    }
    if (name == "style" || isURLAttribute(name) || (ns == ElementNamespace::SVG && name == "xlink:href")) {
        return true;
    }
    if (startsWith(name, "data-tg-")) {
        return false;
    }
    for (std::string_view prefix : profile::table(profile::MarkupTable::HTMLAttributePrefixes)) {
        if (startsWith(name, prefix)) {
            return true;
        }
    }
    if (ns == ElementNamespace::HTML) {
        return profile::contains(profile::MarkupTable::HTMLAttributes, name);
    }
    return ns == ElementNamespace::SVG && profile::svgAttributeName(name).has_value();
}

RenderTag renamed(std::string_view tag, const std::string& original) {
    RenderTag out;
    out.rendered = true;
    out.tag = std::string(tag);
    out.dataTgTag = original;
    return out;
}

} // namespace

RenderTag renderTagFor(ElementNamespace ns, std::string_view localName, bool adoptedRoot) {
    if (ns == ElementNamespace::Other || !wellFormedTagName(localName)) {
        return {};
    }
    const std::string name = lowered(localName);
    if (name == "style") {
        RenderTag sheet;
        sheet.rendered = true;
        sheet.stylesheet = true;
        sheet.tag = "style";
        return sheet;
    }
    if (ns == ElementNamespace::SVG) {
        const std::optional<std::string_view> canonical = profile::svgElementName(name);
        if (!canonical) {
            return {};
        }
        RenderTag kept;
        kept.rendered = true;
        kept.tag = std::string(*canonical);
        return kept;
    }
    if ((name == "html" || name == "head" || name == "body") && !adoptedRoot) {
        return renamed("div", name);
    }
    const profile::ElementAction action = profile::htmlElementAction(name).value_or(profile::unknownHTMLAction());
    switch (action) {
    case profile::ElementAction::Keep: {
        RenderTag kept;
        kept.rendered = true;
        kept.tag = name;
        return kept;
    }
    case profile::ElementAction::Span:
        return renamed("span", name);
    case profile::ElementAction::Div:
        return renamed("div", name);
    case profile::ElementAction::Drop:
        return {};
    }
    return {};
}

RenderAttributeDecision renderAttribute(ElementNamespace ns, std::string_view renderedTag, std::string_view qualifiedName,
                                        std::string_view value) {
    if (!wellFormedAttributeName(qualifiedName)) {
        return {};
    }
    std::string name = lowered(qualifiedName);
    if (!nameMayRender(ns, name)) {
        return {};
    }
    const std::string tag = lowered(renderedTag);
    if (ns == ElementNamespace::SVG && name == "xlink:href") {
        name = "href";
    }
    if (name == "style") {
        return kept(name, value);
    }
    if (isURLAttribute(name)) {
        if (name == "href" && tag == "a") {
            if (std::optional<std::string> fragment = css::policy::fragmentHref(value)) {
                return kept(name, *fragment);
            }
            const std::string normalized = css::policy::normalizedUrl(value);
            const bool malformedFragment = !normalized.empty() && normalized[0] == '#';
            return kept(name, "#", !malformedFragment);
        }
        if (ns == ElementNamespace::SVG && name == "href" &&
            (tag == "use" || tag == "lineargradient" || tag == "radialgradient")) {
            if (std::optional<std::string> fragment = css::policy::fragmentHref(value)) {
                return kept(name, *fragment);
            }
            return {};
        }
        if (ns == ElementNamespace::HTML && name == "src" && tag == "img") {
            return kept(name, value);
        }
        return {};
    }
    for (std::string_view prefix : profile::table(profile::MarkupTable::HTMLAttributePrefixes)) {
        if (startsWith(name, prefix)) {
            return kept(name, value);
        }
    }
    if (ns == ElementNamespace::HTML) {
        return kept(name, value);
    }
    // SVG: the canonical spelling; a CSS value meets the CSS value rules; a font family list is reduced.
    const std::string canonical(*profile::svgAttributeName(name));
    if (profile::contains(profile::MarkupTable::CSSValuedSVGAttributes, name)) {
        const css::policy::Judged judged =
            css::policy::value(litehtml::normalize(std::string(value), litehtml::f_componentize));
        if (judged.verdict == css::policy::Verdict::Drop) {
            return {};
        }
        // sdk-v1 §2.17: env() as the policy rewrote it.
        return kept(canonical, judged.verdict == css::policy::Verdict::Keep ? std::string(value) : litehtml::get_repr(judged.value));
    }
    if (name == "font-family") {
        return kept(canonical, css::policy::reduceFontFamilyText(value));
    }
    return kept(canonical, value);
}

bool attributeMayRender(ElementNamespace ns, std::string_view, std::string_view qualifiedName) {
    return wellFormedAttributeName(qualifiedName) && nameMayRender(ns, lowered(qualifiedName));
}

} // namespace wr::markup
