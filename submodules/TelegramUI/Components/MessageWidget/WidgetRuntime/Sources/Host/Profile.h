// Profile 1's tables (V5c plan, Task 1): what the validator keeps, generated from the vendored profile.json
// (IDL/generate-profile-tables.py → ProfileTables.inc). CSS.supports reads them now; V4's validator will too.
#pragma once

#include <cstdint>
#include <span>
#include <string_view>

namespace wr::profile {

/// TelegramWidget.profile: the profile these tables are (ProfileTablesTests pins it against the JSON).
inline constexpr int kVersion = 1;

enum class CSSTable : uint8_t {
    Properties,
    Functions,
    Units,
    DisplayValues,
    PositionValues,
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
};

/// The table, sorted, in the profile's (lower-case) spelling.
std::span<const std::string_view> table(CSSTable which);
/// Whether `lowered` (already ASCII-lowercased) is in the table.
bool contains(CSSTable which, std::string_view lowered);

} // namespace wr::profile
