// Profile 1's tables (V5c plan, Task 1; V4 plan, Task 1): what the renderer's copy of a widget keeps, generated from the
// vendored profile.json (IDL/generate-profile-tables.py → ProfileTables.inc). CSS.supports and the profile policy read
// them.
#pragma once

#include <cstdint>
#include <optional>
#include <span>
#include <string_view>

namespace wr::profile {

/// TelegramWidget.profile and isProfileAtLeast: the profile these tables are (ProfileTablesTests pins it against the
/// JSON).
inline constexpr int kVersion = 1;

enum class CSSTable : uint8_t {
    Properties,
    Functions,
    Units,
    /// css.values: each property's keyword set, as "property:keyword" (keywordAllowed reads it).
    ValueSets,
    /// The properties css.values restricts.
    ValuedProperties,
    /// The position values the validator rewrites (sticky → relative), and the overflow ones (auto → hidden).
    PositionRewrites,
    OverflowRewrites,
    FilterFunctions,
    /// 3D transform functions: a declaration with one is dropped.
    Transform3D,
    GenericFonts,
    /// With the ones the validator rewrites (disabled, enabled).
    PseudoClasses,
    PseudoElements,
    /// The image types of a kept data: URL.
    ImageTypes,
    /// The at-rules kept (media, supports, keyframes, -webkit-keyframes).
    AtRules,
    /// The media types and features a kept @media and matchMedia may name.
    MediaTypes,
    MediaFeatures,
};

enum class MarkupTable : uint8_t {
    /// The HTML attributes kept as written, besides the prefixed ones, style and the URL rules.
    HTMLAttributes,
    /// data- and aria-.
    HTMLAttributePrefixes,
    /// Lowered; svgElementName and svgAttributeName give the canonical spelling.
    SVGElements,
    SVGAttributes,
    /// The attributes strict attr() may read and the text budgets charge, besides data-* and aria-* (the reference's
    /// css-sanitizer.ts:62-72; not in profile.json).
    TextAttributes,
    /// The SVG attributes whose value is a CSS value (the reference's allowlist.ts:63-66; not in profile.json).
    CSSValuedSVGAttributes,
};

/// The table, sorted, in the profile's (lower-case) spelling.
std::span<const std::string_view> table(CSSTable which);
std::span<const std::string_view> table(MarkupTable which);
/// Whether `lowered` (already ASCII-lowercased) is in the table.
bool contains(CSSTable which, std::string_view lowered);
/// Whether `keyword` is in css.values' set for `property` (both lowered); true for a property without a set.
bool keywordAllowed(std::string_view property, std::string_view keyword);
bool contains(MarkupTable which, std::string_view lowered);

/// What the renderer's copy does with an HTML element (html.elements): keep it, render it as a span or a div (with
/// data-tg-tag), or drop it with its subtree.
enum class ElementAction : uint8_t { Keep, Span, Div, Drop };
struct NamedElementAction {
    std::string_view name;
    ElementAction action;
};
/// html.elements, sorted by name.
std::span<const NamedElementAction> htmlElementActions();
/// The action for a lowered HTML element name; nullopt for a name the table lacks (style included).
std::optional<ElementAction> htmlElementAction(std::string_view lowered);
/// html.unknown: an element the table lacks.
ElementAction unknownHTMLAction();
/// The canonical spelling (linearGradient, viewBox) of a lowered SVG element or attribute the profile keeps.
std::optional<std::string_view> svgElementName(std::string_view lowered);
std::optional<std::string_view> svgAttributeName(std::string_view lowered);

/// css.fonts: an alias's generic family (-apple-system → system-ui), a ui-* family's fallback, the default family.
std::optional<std::string_view> fontAlias(std::string_view lowered);
std::optional<std::string_view> fontFallback(std::string_view lowered);
std::string_view defaultFont();
/// css.pseudoRewrite's replacement text ([disabled], :not([disabled])), and css.rewrite's targets (relative, hidden).
std::optional<std::string_view> pseudoRewrite(std::string_view lowered);
std::optional<std::string_view> positionRewrite(std::string_view lowered);
std::optional<std::string_view> overflowRewrite(std::string_view lowered);
/// Profile 1's UA stylesheet (SDK v1 §2.4), as the master sheet takes it: unlayered, without :where().
std::string_view uaStylesheet();

} // namespace wr::profile
