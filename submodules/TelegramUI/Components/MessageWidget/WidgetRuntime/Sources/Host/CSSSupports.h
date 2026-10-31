// CSS.supports answered from profile 1's tables (V5c plan, Tasks 3 and 4; profile-v1.md D23: "true only when the
// validator keeps the declaration as written"), over CSS Syntax's component values (Sources/DOM/CSSComponents.h).
#pragma once

#include <span>
#include <string_view>

#include <litehtml/css_tokenizer.h>

#include "Sources/Support/Values.h"

namespace wr::css {

/// Whether the profile keeps `property: value` (policy::supported of CSSPolicy.h's verdict): `loweredProperty` trimmed
/// and ASCII-lowercased, `value` its component values.
bool supportsDeclaration(JSContext* ctx, std::string_view loweredProperty, std::span<const litehtml::css_token> value);
/// CSS.supports(property, value): the property trimmed and ASCII-lowercased, the value componentized (false past the
/// caps). Throws Thrown.
bool supportsDeclarationText(JSContext* ctx, const String& property, const String& value);
/// CSS.supports(conditionText): CSS Conditional 4's <supports-condition>, or the text in parentheses. Throws Thrown.
bool supportsCondition(JSContext* ctx, const String& conditionText);

} // namespace wr::css
