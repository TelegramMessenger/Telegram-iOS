#include "Sources/Host/Profile.h"

#include <algorithm>

namespace wr::profile {

namespace {

#include "Sources/Host/ProfileTables.inc"

} // namespace

std::span<const std::string_view> table(CSSTable which) {
    switch (which) {
    case CSSTable::Properties:
        return kCSSProperties;
    case CSSTable::Functions:
        return kCSSFunctions;
    case CSSTable::Units:
        return kCSSUnits;
    case CSSTable::DisplayValues:
        return kCSSDisplayValues;
    case CSSTable::PositionValues:
        return kCSSPositionValues;
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
    }
    return {};
}

bool contains(CSSTable which, std::string_view lowered) {
    const std::span<const std::string_view> entries = table(which);
    return std::binary_search(entries.begin(), entries.end(), lowered);
}

} // namespace wr::profile
