#include "Sources/Host/CSSSupports.h"

#include <string>
#include <vector>

#include "Sources/DOM/CSSComponents.h"
#include "Sources/Host/Profile.h"
#include "Sources/Support/Errors.h"
#include "Sources/Support/Work.h"

namespace wr::css {

namespace {

using litehtml::css_token;
using profile::CSSTable;

std::string lowered(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
    return out;
}

bool isGlobalKeyword(std::string_view ident) {
    return ident == "inherit" || ident == "initial" || ident == "unset" || ident == "revert" || ident == "revert-layer";
}

bool isWhitespace(const css_token& t) {
    return t.type == litehtml::WHITESPACE;
}

bool isDelim(const css_token& t, char c) {
    return t.ch == c;
}

/// A kept url(): a #fragment, or a data: URL of a profile image type followed by ";" or ",".
bool urlKept(std::string_view url) {
    size_t start = 0;
    while (start < url.size() && (url[start] == ' ' || url[start] == '\t' || url[start] == '\n')) {
        start++;
    }
    url.remove_prefix(start);
    if (!url.empty() && url[0] == '#') {
        return true;
    }
    if (url.size() < 5 || lowered(url.substr(0, 5)) != "data:") {
        return false;
    }
    const std::string_view rest = url.substr(5);
    const size_t end = rest.find_first_of(";,");
    return end != std::string_view::npos && profile::contains(CSSTable::ImageTypes, lowered(rest.substr(0, end)));
}

/// What a walk over every component value found (profile-v1.md's rules 3 and 4, and what later rules need).
struct Scan {
    bool ok = true;
    bool hasVar = false;
    bool has3D = false;
};

void scan(JSContext* ctx, std::span<const css_token> values, Scan& out) {
    for (const css_token& t : values) {
        charge(ctx, work::kNodeVisit);
        switch (t.type) {
        case litehtml::BAD_STRING:
        case litehtml::BAD_URL:
        case litehtml::BANG:
        case litehtml::SEMICOLON:
        case litehtml::RIGHT_PAREN:
        case litehtml::RIGHT_BRACKET:
        case litehtml::RIGHT_BRACE:
        case litehtml::CURLY_BLOCK:
            out.ok = false;
            return;
        case litehtml::URL:
            if (!urlKept(t.str())) {
                out.ok = false;
                return;
            }
            break;
        case litehtml::DIMENSION:
            if (!profile::contains(CSSTable::Units, lowered(t.unit()))) {
                out.ok = false;
                return;
            }
            break;
        case litehtml::CV_FUNCTION: {
            const std::string name = lowered(t.name());
            if (name == "url") {
                // url("…"): one string, and a kept URL.
                const css_token* string = nullptr;
                for (const css_token& arg : t.value) {
                    if (isWhitespace(arg)) {
                        continue;
                    }
                    if (string || arg.type != litehtml::STRING) {
                        out.ok = false;
                        return;
                    }
                    string = &arg;
                }
                if (!string || !urlKept(string->str())) {
                    out.ok = false;
                    return;
                }
                break;
            }
            if (!profile::contains(CSSTable::Functions, name)) {
                out.ok = false;
                return;
            }
            out.hasVar = out.hasVar || name == "var" || name == "env" || name == "attr";
            out.has3D = out.has3D || profile::contains(CSSTable::Transform3D, name);
            scan(ctx, t.value, out);
            if (!out.ok) {
                return;
            }
            break;
        }
        case litehtml::ROUND_BLOCK:
        case litehtml::SQUARE_BLOCK:
            scan(ctx, t.value, out);
            if (!out.ok) {
                return;
            }
            break;
        default:
            break;
        }
    }
}

/// The top-level values that are not whitespace.
std::vector<const css_token*> items(std::span<const css_token> values) {
    std::vector<const css_token*> out;
    for (const css_token& t : values) {
        if (!isWhitespace(t)) {
            out.push_back(&t);
        }
    }
    return out;
}

/// font-family's list (or the family part of font): every comma-separated family a single generic family or global
/// keyword; a family that is (or holds) a function, var() in practice, is left to it.
bool familiesKept(const std::vector<const css_token*>& list) {
    std::vector<const css_token*> group;
    auto groupKept = [&]() {
        if (group.empty()) {
            return false;
        }
        for (const css_token* t : group) {
            if (t->type == litehtml::CV_FUNCTION) {
                return true;
            }
        }
        if (group.size() != 1 || group[0]->type != litehtml::IDENT) {
            return false;
        }
        const std::string family = group[0]->ident();
        return profile::contains(CSSTable::GenericFonts, family) || isGlobalKeyword(family);
    };
    for (const css_token* t : list) {
        if (t->type == litehtml::COMMA) {
            if (!groupKept()) {
                return false;
            }
            group.clear();
        } else {
            group.push_back(t);
        }
    }
    return groupKept();
}

bool isFontSize(const css_token& t) {
    static const char* const kSizeKeywords[] = {"xx-small", "x-small", "small",   "medium",  "large",
                                               "x-large",  "xx-large", "xxx-large", "smaller", "larger"};
    if (t.type == litehtml::DIMENSION || t.type == litehtml::PERCENTAGE) {
        return true;
    }
    if (t.type == litehtml::IDENT) {
        const std::string ident = t.ident();
        for (const char* k : kSizeKeywords) {
            if (ident == k) {
                return true;
            }
        }
        return false;
    }
    if (t.type == litehtml::CV_FUNCTION) {
        const std::string name = lowered(t.name());
        return name == "calc" || name == "min" || name == "max" || name == "clamp";
    }
    return false;
}

} // namespace

bool supportsDeclaration(JSContext* ctx, std::string_view property, std::span<const css_token> value) {
    const std::vector<const css_token*> top = items(value);
    if (property.empty() || top.empty()) {
        return false;
    }
    const bool custom = property.size() >= 2 && property.substr(0, 2) == "--";
    if (!custom && !profile::contains(CSSTable::Properties, property)) {
        return false;
    }
    Scan found;
    scan(ctx, value, found);
    if (!found.ok) {
        return false;
    }
    if (custom) {
        return true;
    }
    std::vector<std::string> idents;
    for (const css_token* t : top) {
        if (t->type == litehtml::IDENT) {
            idents.push_back(t->ident());
        }
    }
    if (top.size() == 1 && idents.size() == 1 && isGlobalKeyword(idents[0])) {
        return true;
    }
    // A substituted value skips only the value tables (V5c final review, I1): what it holds besides var() or attr()
    // is still rewritten or dropped by the rules below, so the validator would not keep it as written.
    const bool singleIdent = top.size() == 1 && idents.size() == 1;
    if (property == "display" && !found.hasVar) {
        return singleIdent && profile::contains(CSSTable::DisplayValues, idents[0]);
    }
    if (property == "position" && !found.hasVar && !(singleIdent && profile::contains(CSSTable::PositionValues, idents[0]))) {
        return false;
    }
    auto anyIdentIn = [&](CSSTable table) {
        for (const std::string& ident : idents) {
            if (profile::contains(table, ident)) {
                return true;
            }
        }
        return false;
    };
    if (property == "position" && anyIdentIn(CSSTable::PositionRewrites)) {
        return false;
    }
    if ((property == "overflow" || property == "overflow-x" || property == "overflow-y") && anyIdentIn(CSSTable::OverflowRewrites)) {
        return false;
    }
    if (property == "background-clip") {
        for (const std::string& ident : idents) {
            if (ident == "text") {
                return false;
            }
        }
    }
    if (property == "transform" && found.has3D) {
        return false;
    }
    if (property == "rotate") {
        int numbers = 0;
        for (const css_token* t : top) {
            numbers += t->type == litehtml::NUMBER ? 1 : 0;
        }
        for (const std::string& ident : idents) {
            if (ident == "x" || ident == "y" || ident == "z") {
                return false;
            }
        }
        if (numbers > 1) {
            return false;
        }
    }
    if (property == "translate" || property == "scale") {
        int components = 0;
        for (const css_token* t : top) {
            components += (t->type != litehtml::COMMA && !isDelim(*t, '/')) ? 1 : 0;
        }
        if (components > 2) {
            return false;
        }
    }
    if (property == "filter" || property == "backdrop-filter" || property == "-webkit-backdrop-filter") {
        for (const css_token* t : top) {
            if (t->type == litehtml::URL) {
                return false;
            }
            // The validator keeps a substituted item in a filter list (V5c fix-wave review, I1).
            if (t->type == litehtml::CV_FUNCTION) {
                const std::string name = lowered(t->name());
                if (name != "var" && name != "attr" && !profile::contains(CSSTable::FilterFunctions, name)) {
                    return false;
                }
            }
        }
    }
    if (property == "font-family" && !familiesKept(top)) {
        return false;
    }
    if (property == "font") {
        for (size_t i = 0; i < top.size(); i++) {
            if (!isFontSize(*top[i])) {
                continue;
            }
            size_t families = i + 1;
            if (families < top.size() && isDelim(*top[families], '/')) {
                families += 2;
            }
            const std::vector<const css_token*> rest(top.begin() + std::ptrdiff_t(std::min(families, top.size())), top.end());
            // Nothing after the size is invalid (`font: 12px`) unless a substitution may carry the family.
            if (rest.empty() ? !found.hasVar : !familiesKept(rest)) {
                return false;
            }
            break;
        }
    }
    return true;
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

namespace {

/// A condition's value, or a syntax error (CSS Conditional: then the whole condition is false).
enum class Result { Invalid, False, True };

Result asResult(bool value) {
    return value ? Result::True : Result::False;
}

/// selector(…) under the profile: every :pseudo-class in PseudoClasses and ::pseudo-element in PseudoElements, no
/// nesting selector (&); attribute selectors are not looked into, a pseudo-class function's arguments are.
bool selectorKept(JSContext* ctx, std::span<const css_token> tokens) {
    bool any = false;
    for (size_t k = 0; k < tokens.size(); k++) {
        charge(ctx, work::kNodeVisit);
        const css_token& t = tokens[k];
        if (isWhitespace(t)) {
            continue;
        }
        any = true;
        if (isDelim(t, '&') || t.type == litehtml::CURLY_BLOCK || t.type == litehtml::SEMICOLON) {
            return false;
        }
        if (t.type == litehtml::CV_FUNCTION) {
            return false;  // a function outside a pseudo-class is no selector
        }
        if (t.type != litehtml::COLON) {
            continue;
        }
        const bool element = k + 1 < tokens.size() && tokens[k + 1].type == litehtml::COLON;
        const size_t at = k + (element ? 2 : 1);
        if (at >= tokens.size() || (tokens[at].type != litehtml::IDENT && tokens[at].type != litehtml::CV_FUNCTION)) {
            return false;
        }
        const css_token& pseudo = tokens[at];
        const std::string name = lowered(pseudo.name());
        if (!profile::contains(element ? CSSTable::PseudoElements : CSSTable::PseudoClasses, name)) {
            return false;
        }
        // A pseudo-class function's arguments (:not(…), :is(…), :nth-child(2n+1)) keep to the profile too.
        if (pseudo.type == litehtml::CV_FUNCTION && !pseudo.value.empty() && !selectorKept(ctx, pseudo.value)) {
            return false;
        }
        k = at;
    }
    return any;
}

/// CSS Conditional 4's <supports-condition> over component values; recursion is bounded by the componentizer's
/// kMaxBracketDepth.
class ConditionParser {
public:
    ConditionParser(JSContext* ctx, std::span<const css_token> tokens) : m_ctx(ctx), m_tokens(tokens) {}

    /// The whole span as one condition.
    Result whole() {
        const Result r = this->condition();
        return r == Result::Invalid || !this->atEnd() ? Result::Invalid : r;
    }

    /// A parenthesized block's contents: a condition, else a declaration, else general-enclosed (false).
    static Result parenContents(JSContext* ctx, std::span<const css_token> inner) {
        const Result nested = ConditionParser(ctx, inner).whole();
        if (nested != Result::Invalid) {
            return nested;
        }
        size_t j = 0;
        while (j < inner.size() && isWhitespace(inner[j])) {
            j++;
        }
        if (j >= inner.size() || inner[j].type != litehtml::IDENT) {
            return Result::False;
        }
        const std::string name = inner[j].ident();
        j++;
        while (j < inner.size() && isWhitespace(inner[j])) {
            j++;
        }
        if (j >= inner.size() || inner[j].type != litehtml::COLON) {
            return Result::False;
        }
        return asResult(supportsDeclaration(ctx, name, inner.subspan(j + 1)));
    }

private:
    void skipWhitespace() {
        while (m_i < m_tokens.size() && isWhitespace(m_tokens[m_i])) {
            m_i++;
        }
    }
    bool atEnd() {
        this->skipWhitespace();
        return m_i >= m_tokens.size();
    }
    /// `word` (ASCII case-insensitive) as an identifier followed by whitespace, consumed.
    bool keyword(std::string_view word) {
        this->skipWhitespace();
        if (m_i + 1 < m_tokens.size() && m_tokens[m_i].type == litehtml::IDENT && m_tokens[m_i].ident() == word &&
            isWhitespace(m_tokens[m_i + 1])) {
            m_i++;
            return true;
        }
        return false;
    }
    Result inParens() {
        this->skipWhitespace();
        if (m_i >= m_tokens.size()) {
            return Result::Invalid;
        }
        charge(m_ctx, work::kNodeVisit);
        const css_token& t = m_tokens[m_i];
        if (t.type == litehtml::ROUND_BLOCK) {
            m_i++;
            return parenContents(m_ctx, t.value);
        }
        if (t.type == litehtml::CV_FUNCTION) {
            m_i++;
            // selector(…), or general-enclosed (an unknown function: false).
            return lowered(t.name()) == "selector" ? asResult(selectorKept(m_ctx, t.value)) : Result::False;
        }
        return Result::Invalid;
    }
    Result condition() {
        if (this->keyword("not")) {
            const Result r = this->inParens();
            return r == Result::Invalid ? r : (r == Result::True ? Result::False : Result::True);
        }
        Result r = this->inParens();
        if (r == Result::Invalid) {
            return r;
        }
        int op = 0;  // 1 and, 2 or: mixing them without parentheses is invalid
        for (;;) {
            const size_t save = m_i;
            const int next = this->keyword("and") ? 1 : this->keyword("or") ? 2 : 0;
            if (!next) {
                m_i = save;
                return r;
            }
            if (op && op != next) {
                return Result::Invalid;
            }
            op = next;
            const Result rhs = this->inParens();
            if (rhs == Result::Invalid) {
                return rhs;
            }
            r = op == 1 ? asResult(r == Result::True && rhs == Result::True) : asResult(r == Result::True || rhs == Result::True);
        }
    }

    JSContext* m_ctx;
    std::span<const css_token> m_tokens;
    size_t m_i = 0;
};

} // namespace

bool supportsCondition(JSContext* ctx, const String& conditionText) {
    std::optional<litehtml::css_token_vector> tokens = componentValues(ctx, conditionText);
    if (!tokens) {
        return false;
    }
    // CSSOM: the text as a condition, and if that is not true, the text in parentheses (a bare declaration).
    if (ConditionParser(ctx, *tokens).whole() == Result::True) {
        return true;
    }
    return ConditionParser::parenContents(ctx, *tokens) == Result::True;
}

} // namespace wr::css
