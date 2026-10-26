#include "Sources/Host/Profile.h"

#include <algorithm>
#include <string>

namespace wr::profile {

namespace {

struct NamePair {
    std::string_view key;
    std::string_view value;
};

#include "Sources/Host/ProfileTables.inc"

std::string_view entryKey(const NamePair& entry) {
    return entry.key;
}

std::string_view entryKey(const NamedElementAction& entry) {
    return entry.name;
}

template <class Entry, size_t N>
const Entry* findEntry(const Entry (&entries)[N], std::string_view key) {
    const Entry* found = std::lower_bound(std::begin(entries), std::end(entries), key,
                                          [](const Entry& entry, std::string_view k) { return entryKey(entry) < k; });
    return found != std::end(entries) && entryKey(*found) == key ? found : nullptr;
}

template <size_t N>
std::optional<std::string_view> lookUp(const NamePair (&entries)[N], std::string_view key) {
    const NamePair* found = findEntry(entries, key);
    return found ? std::optional<std::string_view>(found->value) : std::nullopt;
}

} // namespace

std::span<const std::string_view> table(CSSTable which) {
    switch (which) {
    case CSSTable::Properties:
        return kCSSProperties;
    case CSSTable::Functions:
        return kCSSFunctions;
    case CSSTable::Units:
        return kCSSUnits;
    case CSSTable::ValueSets:
        return kCSSValueSets;
    case CSSTable::ValuedProperties:
        return kCSSValuedProperties;
    case CSSTable::PositionRewrites:
        return kCSSPositionRewrites;
    case CSSTable::OverflowRewrites:
        return kCSSOverflowRewrites;
    case CSSTable::FilterFunctions:
        return kCSSFilterFunctions;
    case CSSTable::Transform3D:
        return kCSSTransform3D;
    case CSSTable::GenericFonts:
        return kCSSGenericFonts;
    case CSSTable::PseudoClasses:
        return kCSSPseudoClasses;
    case CSSTable::PseudoElements:
        return kCSSPseudoElements;
    case CSSTable::ImageTypes:
        return kImageTypes;
    case CSSTable::AtRules:
        return kCSSAtRules;
    case CSSTable::MediaTypes:
        return kCSSMediaTypes;
    case CSSTable::MediaFeatures:
        return kCSSMediaFeatures;
    }
    return {};
}

std::span<const std::string_view> table(MarkupTable which) {
    switch (which) {
    case MarkupTable::HTMLAttributes:
        return kHTMLAttributes;
    case MarkupTable::HTMLAttributePrefixes:
        return kHTMLAttributePrefixes;
    case MarkupTable::SVGElements:
        return kSVGElements;
    case MarkupTable::SVGAttributes:
        return kSVGAttributes;
    case MarkupTable::TextAttributes:
        return kTextAttributes;
    case MarkupTable::CSSValuedSVGAttributes:
        return kCSSValuedSVGAttributes;
    }
    return {};
}

bool contains(CSSTable which, std::string_view lowered) {
    const std::span<const std::string_view> entries = table(which);
    return std::binary_search(entries.begin(), entries.end(), lowered);
}

bool keywordAllowed(std::string_view property, std::string_view keyword) {
    if (!contains(CSSTable::ValuedProperties, property)) {
        return true;
    }
    std::string entry(property);
    entry += ':';
    entry += keyword;
    return contains(CSSTable::ValueSets, entry);
}

bool contains(MarkupTable which, std::string_view lowered) {
    const std::span<const std::string_view> entries = table(which);
    return std::binary_search(entries.begin(), entries.end(), lowered);
}

std::span<const NamedElementAction> htmlElementActions() {
    return kHTMLElementActions;
}

std::optional<ElementAction> htmlElementAction(std::string_view lowered) {
    const NamedElementAction* found = findEntry(kHTMLElementActions, lowered);
    return found ? std::optional<ElementAction>(found->action) : std::nullopt;
}

ElementAction unknownHTMLAction() {
    return kUnknownHTMLAction;
}

std::optional<std::string_view> svgElementName(std::string_view lowered) {
    return lookUp(kSVGElementNames, lowered);
}

std::optional<std::string_view> svgAttributeName(std::string_view lowered) {
    return lookUp(kSVGAttributeNames, lowered);
}

std::optional<std::string_view> fontAlias(std::string_view lowered) {
    return lookUp(kFontAliases, lowered);
}

std::optional<std::string_view> fontFallback(std::string_view lowered) {
    return lookUp(kFontFallbacks, lowered);
}

std::string_view defaultFont() {
    return kDefaultFont;
}

std::optional<std::string_view> pseudoRewrite(std::string_view lowered) {
    return lookUp(kPseudoRewrites, lowered);
}

std::optional<std::string_view> positionRewrite(std::string_view lowered) {
    return lookUp(kPositionRewrites, lowered);
}

std::optional<std::string_view> overflowRewrite(std::string_view lowered) {
    return lookUp(kOverflowRewrites, lowered);
}

std::string_view uaStylesheet() {
    return kUAStylesheet;
}

} // namespace wr::profile
