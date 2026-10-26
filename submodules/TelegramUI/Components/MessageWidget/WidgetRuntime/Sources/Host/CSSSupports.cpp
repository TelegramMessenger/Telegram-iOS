#include "Sources/Host/CSSSupports.h"

#include <string>

#include "Sources/DOM/CSSComponents.h"
#include "Sources/Host/CSSPolicy.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Work.h"

namespace wr::css {

namespace {

std::string lowered(std::string s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
    return s;
}

} // namespace

// V4 plan, Task 2: the answers are the profile policy's verdicts (CSSPolicy.h), so CSS.supports and the renderer's copy
// can never disagree. The policy charges nothing; its walk is bounded by componentValues' caps, whose text was charged
// first, and is charged here once it has run.
bool supportsDeclaration(JSContext* ctx, std::string_view property, std::span<const litehtml::css_token> value) {
    const policy::Judged judged = policy::declaration(property, value);
    charge(ctx, uint64_t(judged.visited) * work::kNodeVisit);
    return policy::supported(judged.verdict);
}

bool supportsDeclarationText(JSContext* ctx, const String& property, const String& value) {
    bool cut = false;
    std::string name = property.utf8Prefix(256, &cut);
    if (cut) {
        return false;
    }
    const size_t first = name.find_first_not_of(" \t\n\r\f");
    const size_t last = name.find_last_not_of(" \t\n\r\f");
    name = first == std::string::npos ? std::string() : lowered(name.substr(first, last - first + 1));
    std::optional<litehtml::css_token_vector> tokens = componentValues(ctx, value);
    if (!tokens) {
        return false;
    }
    return supportsDeclaration(ctx, name, *tokens);
}

bool supportsCondition(JSContext* ctx, const String& conditionText) {
    std::optional<litehtml::css_token_vector> tokens = componentValues(ctx, conditionText);
    if (!tokens) {
        return false;
    }
    // CSSOM: the text as a condition, and if that is not true, the text in parentheses (a bare declaration).
    size_t visited = 0;
    const bool result = policy::supportsCondition(*tokens, &visited) || policy::supportsParenthesized(*tokens, &visited);
    charge(ctx, uint64_t(visited) * work::kNodeVisit);
    return result;
}

} // namespace wr::css
