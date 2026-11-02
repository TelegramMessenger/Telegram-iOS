#pragma once

#include <cstddef>
#include <string_view>

namespace wr {

/// Style rules and `@keyframes` blocks in a stylesheet, as widget-sandbox v0.3.0's validator counts them
/// (validator.ts countCssRules): a rule inside `@media`, `@supports` or another at-rule counts, the keyframe selectors
/// inside `@keyframes` do not; strings and comments hold no blocks.
struct CSSRuleCount {
    size_t rules = 0;
    size_t keyframes = 0;
};

CSSRuleCount countCssRules(std::string_view css);

} // namespace wr
