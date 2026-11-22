#include "Sources/Host/CSSPolicy.h"

#include <algorithm>
#include <optional>
#include <string>
#include <vector>

#include <litehtml/css_parser.h>

#include "Sources/Host/Profile.h"

namespace wr::css::policy {

namespace {

using litehtml::css_token;
using litehtml::css_token_vector;
using profile::CSSTable;
using profile::MarkupTable;

std::string lowered(std::string_view s) {
    std::string out(s);
    for (char& c : out) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
    return out;
}

bool startsWith(std::string_view s, std::string_view prefix) {
    return s.size() >= prefix.size() && s.substr(0, prefix.size()) == prefix;
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

/// Tokens of a table's text (a rewrite target, a regenerated list): component values, each with its repr.
css_token_vector tokensOf(std::string_view text) {
    return litehtml::normalize(std::string(text), litehtml::f_componentize);
}

/// The indices of the top-level values that are not whitespace.
std::vector<size_t> topItems(std::span<const css_token> values) {
    std::vector<size_t> out;
    for (size_t i = 0; i < values.size(); i++) {
        if (!isWhitespace(values[i])) {
            out.push_back(i);
        }
    }
    return out;
}

// MARK: URLs

/// Decodes the UTF-8 code point at `s[i]`, advancing `i`; a malformed byte is returned as itself.
uint32_t nextCodePoint(std::string_view s, size_t& i) {
    const auto byte = [&](size_t k) { return static_cast<unsigned char>(s[k]); };
    const unsigned char b = byte(i);
    size_t length = b < 0x80 ? 1 : (b >> 5) == 0x6 ? 2 : (b >> 4) == 0xE ? 3 : (b >> 3) == 0x1E ? 4 : 1;
    if (i + length > s.size()) {
        length = 1;
    }
    uint32_t cp = length == 1 ? b : length == 2 ? (b & 0x1F) : length == 3 ? (b & 0x0F) : (b & 0x07);
    for (size_t k = 1; k < length; k++) {
        cp = (cp << 6) | (byte(i + k) & 0x3F);
    }
    i += length;
    return cp;
}

/// JavaScript's \s.
bool isJSWhitespace(uint32_t cp) {
    return cp == 0x09 || cp == 0x0A || cp == 0x0B || cp == 0x0C || cp == 0x0D || cp == 0x20 || cp == 0xA0 ||
           cp == 0x1680 || (cp >= 0x2000 && cp <= 0x200A) || cp == 0x2028 || cp == 0x2029 || cp == 0x202F ||
           cp == 0x205F || cp == 0x3000 || cp == 0xFEFF;
}

/// `^#[^\s"'()\\<>]*$`.
bool wellFormedFragment(std::string_view url) {
    if (url.empty() || url[0] != '#') {
        return false;
    }
    for (size_t i = 1; i < url.size();) {
        const uint32_t cp = nextCodePoint(url, i);
        if (isJSWhitespace(cp) || cp == '"' || cp == '\'' || cp == '(' || cp == ')' || cp == '\\' || cp == '<' || cp == '>') {
            return false;
        }
    }
    return true;
}

/// RB §3.2's checkUrl(raw, "image"): the normalized URL, or nullopt.
std::optional<std::string> checkedImageURL(std::string_view raw) {
    std::string url = normalizedUrl(raw);
    if (!url.empty() && url[0] == '#') {
        return wellFormedFragment(url) ? std::optional<std::string>(url) : std::nullopt;
    }
    if (url.size() < 5 || lowered(url.substr(0, 5)) != "data:") {
        return std::nullopt;
    }
    const size_t comma = url.find(',', 5);
    if (comma == std::string::npos) {
        return std::nullopt;
    }
    std::string_view mime = std::string_view(url).substr(5, comma - 5);
    mime = mime.substr(0, mime.find(';'));
    const size_t first = mime.find_first_not_of(" \t\n\r\f");
    const size_t last = mime.find_last_not_of(" \t\n\r\f");
    const std::string type = first == std::string_view::npos ? std::string() : lowered(mime.substr(first, last - first + 1));
    return profile::contains(CSSTable::ImageTypes, type) ? std::optional<std::string>(url) : std::nullopt;
}

// MARK: values

/// What a walk over every component value found (RB §4.5) and what the later rules need.
struct Scan {
    bool ok = true;
    bool hasVar = false;
    bool has3D = false;
    bool hasLightDark = false;
};

/// Strict attr(): the attribute must be a text attribute, data-* or aria-* (RB §4.5).
bool attrReadsText(std::span<const css_token> arguments) {
    for (const css_token& t : arguments) {
        if (isWhitespace(t)) {
            continue;
        }
        if (t.type != litehtml::IDENT) {
            return false;
        }
        const std::string name = t.ident();
        if (profile::contains(MarkupTable::TextAttributes, name)) {
            return true;
        }
        for (std::string_view prefix : profile::table(MarkupTable::HTMLAttributePrefixes)) {
            if (startsWith(name, prefix)) {
                return true;
            }
        }
        return false;
    }
    return false;
}

void scan(std::span<const css_token> values, Scan& out) {
    for (const css_token& t : values) {
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
            // env() is rewritten before the scan (rewriteEnv): none is left for the renderer.
            if (name == "env" || !profile::contains(CSSTable::Functions, name)) {
                out.ok = false;
                return;
            }
            if (name == "attr" && !attrReadsText(t.value)) {
                out.ok = false;
                return;
            }
            out.hasVar = out.hasVar || name == "var" || name == "attr";
            out.has3D = out.has3D || profile::contains(CSSTable::Transform3D, name);
            out.hasLightDark = out.hasLightDark || name == "light-dark";
            // Every argument is checked, both light-dark() branches included (RB §4.5, §11 item 17).
            scan(t.value, out);
            if (!out.ok) {
                return;
            }
            break;
        }
        case litehtml::ROUND_BLOCK:
        case litehtml::SQUARE_BLOCK:
            scan(t.value, out);
            if (!out.ok) {
                return;
            }
            break;
        default:
            break;
        }
    }
}

// MARK: fonts

bool isFontSize(const css_token& t) {
    static const char* const kSizeKeywords[] = {"xx-small", "x-small", "small",     "medium",  "large",
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

struct FontReduction {
    bool changed = false;
    bool augmented = false;
    /// The list as the renderer gets it, when changed or augmented.
    std::string text;
};

/// RB §4.7 over the family list in `values[from, to)`.
FontReduction reduceFamilies(const css_token_vector& values, size_t from, size_t to) {
    struct Entry {
        std::string text;
        std::string key;  // lowered single name; "" for a group holding a function
    };
    FontReduction out;
    std::vector<Entry> kept;
    // The named entries' keys: deduplicated, so at most the profile's generic families, aliases and global keywords,
    // whatever the list's length (a function group is never a key; final review C1).
    std::vector<std::string> keys;
    auto present = [&](std::string_view key) {
        return !key.empty() && std::find(keys.begin(), keys.end(), key) != keys.end();
    };
    auto keep = [&](std::string text, std::string key) {
        keys.push_back(key);
        kept.push_back({std::move(text), std::move(key)});
    };
    std::vector<const css_token*> group;
    auto closeGroup = [&]() {
        bool hasFunction = false;
        for (const css_token* t : group) {
            hasFunction = hasFunction || t->type == litehtml::CV_FUNCTION;
        }
        if (hasFunction) {
            std::string text;
            for (const css_token* t : group) {
                text += (text.empty() ? "" : " ") + t->get_repr();
            }
            kept.push_back({text, ""});
        } else if (group.size() == 1 && group[0]->type == litehtml::IDENT) {
            const std::string name = group[0]->ident();
            if (std::optional<std::string_view> alias = profile::fontAlias(name)) {
                out.changed = true;
                if (!present(*alias)) {
                    keep(std::string(*alias), std::string(*alias));
                }
            } else if (profile::contains(CSSTable::GenericFonts, name) || isGlobalKeyword(name)) {
                if (present(name)) {
                    out.changed = true;
                } else {
                    keep(group[0]->str(), name);
                }
            } else {
                out.changed = true;
            }
        } else {
            out.changed = true;
        }
        group.clear();
    };
    for (size_t i = from; i < to; i++) {
        const css_token& t = values[i];
        if (isWhitespace(t)) {
            continue;
        }
        if (t.type == litehtml::COMMA) {
            closeGroup();
        } else {
            group.push_back(&t);
        }
    }
    closeGroup();
    // A ui-* family's fallback, unless it already follows.
    std::vector<Entry> withFallbacks;
    for (size_t i = 0; i < kept.size(); i++) {
        withFallbacks.push_back(kept[i]);
        const std::optional<std::string_view> fallback = profile::fontFallback(kept[i].key);
        if (!fallback) {
            continue;
        }
        const bool later = std::any_of(kept.begin() + std::ptrdiff_t(i) + 1, kept.end(),
                                       [&](const Entry& e) { return e.key == *fallback; });
        const bool already = std::any_of(withFallbacks.begin(), withFallbacks.end(),
                                         [&](const Entry& e) { return e.key == *fallback; });
        if (!later && !already) {
            withFallbacks.push_back({std::string(*fallback), std::string(*fallback)});
            out.augmented = true;
        }
    }
    if (withFallbacks.empty()) {
        withFallbacks.push_back({std::string(profile::defaultFont()), std::string(profile::defaultFont())});
        out.changed = true;
    }
    for (const Entry& e : withFallbacks) {
        out.text += (out.text.empty() ? "" : ",") + e.text;
    }
    return out;
}

/// Replaces `values[from, end)` with the tokens of `text`.
void replaceTail(css_token_vector& values, size_t from, std::string_view text) {
    css_token_vector replacement = tokensOf(text);
    values.erase(values.begin() + std::ptrdiff_t(from), values.end());
    values.insert(values.end(), replacement.begin(), replacement.end());
}

// MARK: env()

/// The env() names the validator rewrites to the root variable the renderer sets (sdk-policy.ts
/// SAFE_AREA_ENV_VARIABLES): exact names, as in CSS.
std::optional<std::string_view> safeAreaVariable(std::string_view name) {
    if (name == "safe-area-inset-top") {
        return "--tg-content-safe-area-inset-top";
    }
    if (name == "safe-area-inset-right") {
        return "--tg-content-safe-area-inset-right";
    }
    if (name == "safe-area-inset-bottom") {
        return "--tg-content-safe-area-inset-bottom";
    }
    if (name == "safe-area-inset-left") {
        return "--tg-content-safe-area-inset-left";
    }
    return std::nullopt;
}

/// widget-sandbox v0.4.0 (sdk-v1 §2.17, css-sanitizer.ts): every env() in `values`, at any depth, as the validator
/// rewrites it. A safe-area inset becomes var(--tg-content-safe-area-inset-…[, fallback]) (`safeArea`); another name
/// becomes its fallback (`resolved`). False, which drops the declaration, for another name without a fallback or with an
/// empty one (a safe-area inset keeps an empty one: `var(--…,)`), and for an env() that is not a name with an optional
/// fallback.
bool rewriteEnv(css_token_vector& values, bool& safeArea, bool& resolved) {
    for (size_t i = 0; i < values.size(); i++) {
        if (values[i].type != litehtml::CV_FUNCTION && values[i].type != litehtml::ROUND_BLOCK &&
            values[i].type != litehtml::SQUARE_BLOCK) {
            continue;
        }
        // Inside first: a fallback may hold an env() of its own.
        if (!rewriteEnv(values[i].value, safeArea, resolved)) {
            return false;
        }
        if (values[i].type != litehtml::CV_FUNCTION || lowered(values[i].name()) != "env") {
            continue;
        }
        const css_token_vector& args = values[i].value;
        size_t k = 0;
        while (k < args.size() && isWhitespace(args[k])) {
            k++;
        }
        if (k == args.size() || args[k].type != litehtml::IDENT) {
            return false;
        }
        const std::string name = args[k].name();
        k++;
        while (k < args.size() && isWhitespace(args[k])) {
            k++;
        }
        std::optional<css_token_vector> fallback;
        if (k < args.size()) {
            if (args[k].type != litehtml::COMMA) {
                return false;
            }
            size_t from = k + 1;
            size_t to = args.size();
            while (from < to && isWhitespace(args[from])) {
                from++;
            }
            while (to > from && isWhitespace(args[to - 1])) {
                to--;
            }
            // An empty fallback, as upstream's resolveEnv reads it: kept for a safe-area inset (var() takes one), nothing
            // to resolve to for another name.
            fallback = css_token_vector(args.begin() + std::ptrdiff_t(from), args.begin() + std::ptrdiff_t(to));
        }
        css_token_vector replacement;
        if (const std::optional<std::string_view> variable = safeAreaVariable(name)) {
            const std::string rest = fallback ? (fallback->empty() ? std::string(",") : ", " + litehtml::get_repr(*fallback)) : std::string();
            replacement = tokensOf("var(" + std::string(*variable) + rest + ")");
            safeArea = true;
        } else if (fallback && !fallback->empty()) {
            replacement = std::move(*fallback);
            resolved = true;
        } else {
            return false;
        }
        values.erase(values.begin() + std::ptrdiff_t(i));
        values.insert(values.begin() + std::ptrdiff_t(i), replacement.begin(), replacement.end());
        i += replacement.size() - 1;
    }
    return true;
}

Verdict verdictOf(bool changed, bool augmented) {
    return changed ? Verdict::Rewrite : augmented ? Verdict::Augment : Verdict::Keep;
}

bool isFilterProperty(std::string_view name) {
    return name == "filter" || name == "backdrop-filter" || name == "-webkit-backdrop-filter";
}

bool isOverflowProperty(std::string_view name) {
    return name == "overflow" || name == "overflow-x" || name == "overflow-y";
}

// MARK: selectors

/// RB §5 over one complex selector's tokens, rewriting :disabled and :enabled; false for a bad one. A rewrite is made
/// into a fresh vector in one pass (css_token has no move, so an erase or insert in the middle copied the rest of the
/// group every time: final review C1).
bool walkSelector(css_token_vector& tokens, bool& augmented) {
    css_token_vector rewritten;
    bool rewriting = false;
    // The tokens [copied, k) not yet in `rewritten`.
    size_t copied = 0;
    for (size_t k = 0; k < tokens.size(); k++) {
        const css_token& t = tokens[k];
        if (isDelim(t, '&')) {
            return false;
        }
        if (t.type != litehtml::COLON) {
            continue;
        }
        const bool element = k + 1 < tokens.size() && tokens[k + 1].type == litehtml::COLON;
        const size_t at = k + (element ? 2 : 1);
        if (at >= tokens.size() || (tokens[at].type != litehtml::IDENT && tokens[at].type != litehtml::CV_FUNCTION)) {
            continue;  // malformed: litehtml's strict parse decides
        }
        const std::string name = lowered(tokens[at].name());
        if (element) {
            if (!profile::contains(CSSTable::PseudoElements, name)) {
                return false;
            }
            k = at;
            continue;
        }
        if (!profile::contains(CSSTable::PseudoClasses, name)) {
            return false;
        }
        if (tokens[at].type == litehtml::IDENT) {
            if (std::optional<std::string_view> rewrite = profile::pseudoRewrite(name)) {
                if (!rewriting) {
                    rewriting = true;
                    rewritten.reserve(tokens.size());
                }
                rewritten.insert(rewritten.end(), tokens.begin() + std::ptrdiff_t(copied), tokens.begin() + std::ptrdiff_t(k));
                const css_token_vector replacement = tokensOf(*rewrite);
                rewritten.insert(rewritten.end(), replacement.begin(), replacement.end());
                copied = at + 1;
                augmented = true;
                k = at;
                continue;
            }
        } else if (!walkSelector(tokens[at].value, augmented)) {
            return false;
        }
        k = at;
    }
    if (rewriting) {
        rewritten.insert(rewritten.end(), tokens.begin() + std::ptrdiff_t(copied), tokens.end());
        tokens = std::move(rewritten);
    }
    return true;
}

/// selector(…) in a condition: well formed (no block, no `;`, no function outside a pseudo-class, a name after every
/// colon) and kept by the profile.
bool selectorSupported(std::span<const css_token> tokens) {
    bool any = false;
    for (size_t k = 0; k < tokens.size(); k++) {
        const css_token& t = tokens[k];
        if (isWhitespace(t)) {
            continue;
        }
        any = true;
        if (t.type == litehtml::CURLY_BLOCK || t.type == litehtml::SEMICOLON || t.type == litehtml::CV_FUNCTION) {
            return false;
        }
        if (t.type == litehtml::COLON) {
            const bool element = k + 1 < tokens.size() && tokens[k + 1].type == litehtml::COLON;
            const size_t at = k + (element ? 2 : 1);
            if (at >= tokens.size() || (tokens[at].type != litehtml::IDENT && tokens[at].type != litehtml::CV_FUNCTION)) {
                return false;
            }
            k = at;
        }
    }
    if (!any) {
        return false;
    }
    const Judged judged = selector(tokens);
    return supported(judged.verdict);
}

// MARK: media

bool isMediaLogicWord(std::string_view ident) {
    return ident == "and" || ident == "or" || ident == "not" || ident == "only";
}

bool mediaFeature(std::string_view lowered) {
    return profile::contains(CSSTable::MediaFeatures, lowered);
}

bool mediaBlockInProfile(std::span<const css_token> inner);

/// A nested condition: logic words and blocks only (each block in profile).
std::optional<bool> nestedCondition(std::span<const css_token> inner) {
    bool any = false;
    for (const css_token& t : inner) {
        if (isWhitespace(t)) {
            continue;
        }
        if (t.type == litehtml::IDENT && (t.ident() == "and" || t.ident() == "or" || t.ident() == "not")) {
            continue;
        }
        if (t.type != litehtml::ROUND_BLOCK) {
            return std::nullopt;
        }
        any = true;
    }
    if (!any) {
        return std::nullopt;
    }
    for (const css_token& t : inner) {
        if (t.type == litehtml::ROUND_BLOCK && !mediaBlockInProfile(t.value)) {
            return false;
        }
    }
    return true;
}

bool mediaBlockInProfile(std::span<const css_token> inner) {
    std::vector<const css_token*> items;
    for (const css_token& t : inner) {
        if (!isWhitespace(t)) {
            items.push_back(&t);
        }
    }
    if (items.empty()) {
        return true;
    }
    if (std::optional<bool> nested = nestedCondition(inner)) {
        return *nested;
    }
    // `feature: value`: the name before the colon; the value is never checked.
    if (items.size() >= 2 && items[0]->type == litehtml::IDENT && items[1]->type == litehtml::COLON) {
        return mediaFeature(items[0]->ident());
    }
    // A range: every identifier is a feature (a dimension is a value, plan OP2).
    bool range = false;
    for (const css_token* t : items) {
        range = range || isDelim(*t, '<') || isDelim(*t, '>') || isDelim(*t, '=');
    }
    if (range) {
        for (const css_token* t : items) {
            if (t->type == litehtml::IDENT && !mediaFeature(t->ident())) {
                return false;
            }
            if (t->type != litehtml::IDENT && t->type != litehtml::NUMBER && t->type != litehtml::DIMENSION &&
                !isDelim(*t, '<') && !isDelim(*t, '>') && !isDelim(*t, '=') && !isDelim(*t, '/')) {
                return false;
            }
        }
        return true;
    }
    // The boolean form, `(feature)`.
    return items.size() == 1 && items[0]->type == litehtml::IDENT && mediaFeature(items[0]->ident());
}

bool mediaQueryInProfileImpl(std::span<const css_token> prelude) {
    for (const css_token& t : prelude) {
        if (isWhitespace(t) || t.type == litehtml::COMMA) {
            continue;
        }
        if (t.type == litehtml::IDENT) {
            const std::string ident = t.ident();
            if (!isMediaLogicWord(ident) && !profile::contains(CSSTable::MediaTypes, ident)) {
                return false;
            }
            continue;
        }
        if (t.type == litehtml::ROUND_BLOCK) {
            if (!mediaBlockInProfile(t.value)) {
                return false;
            }
            continue;
        }
        return false;
    }
    return true;
}

// MARK: @supports

/// A condition's value, or a syntax error (CSS Conditional: then the whole condition is false).
enum class Result { Invalid, False, True };

Result asResult(bool value) {
    return value ? Result::True : Result::False;
}

Result parenContents(std::span<const css_token> inner);

/// CSS Conditional 4's <supports-condition> over component values; recursion is bounded by the componentizer's
/// bracket depth.
class ConditionParser {
public:
    ConditionParser(std::span<const css_token> tokens) : m_tokens(tokens) {}

    /// The whole span as one condition.
    Result whole() {
        const Result r = this->condition();
        return r == Result::Invalid || !this->atEnd() ? Result::Invalid : r;
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
        const css_token& t = m_tokens[m_i];
        if (t.type == litehtml::ROUND_BLOCK) {
            m_i++;
            return parenContents(t.value);
        }
        if (t.type == litehtml::CV_FUNCTION) {
            m_i++;
            // selector(…), or general-enclosed (an unknown function: false).
            return lowered(t.name()) == "selector" ? asResult(selectorSupported(t.value)) : Result::False;
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
        int op = 0;  // 1 and, 2 or: mixing them without parentheses is invalid (plan OP3)
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

    std::span<const css_token> m_tokens;
    size_t m_i = 0;
};

/// A parenthesized block's contents: a condition, else a declaration, else general-enclosed (false).
Result parenContents(std::span<const css_token> inner) {
    const Result nested = ConditionParser(inner).whole();
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
    const Judged judged = declaration(name, inner.subspan(j + 1));
    return asResult(supported(judged.verdict));
}

} // namespace

Judged declaration(std::string_view name, std::span<const css_token> input) {
    Judged out;
    if (name.empty() || topItems(input).empty()) {
        return out;
    }
    const bool custom = startsWith(name, "--");
    if (!custom && !profile::contains(CSSTable::Properties, name)) {
        return out;
    }
    css_token_vector values(input.begin(), input.end());
    // sdk-v1 §2.17: env() first, as the validator rewrites it. A safe-area inset is kept (CSS.supports says yes); another
    // name's fallback is a rewrite (it says no).
    bool safeArea = false;
    bool resolved = false;
    if (!rewriteEnv(values, safeArea, resolved)) {
        return out;
    }
    bool changed = resolved;
    bool augmented = safeArea;
    // RB §4.4: the filter list is pruned before the value is checked.
    if (!custom && isFilterProperty(name)) {
        // In one pass into a fresh list: a removed item goes with the whitespace before it, or, with none before it, the
        // one after it. Erasing in place copied the rest of the list per item (final review C1).
        auto pruned = [](const css_token& t) {
            const std::string function = t.type == litehtml::CV_FUNCTION ? lowered(t.name()) : std::string();
            return t.type == litehtml::URL ||
                   (t.type == litehtml::CV_FUNCTION && function != "var" && function != "attr" &&
                    !profile::contains(CSSTable::FilterFunctions, function));
        };
        if (std::any_of(values.begin(), values.end(), pruned)) {
            css_token_vector kept;
            kept.reserve(values.size());
            bool skipWhitespace = false;
            for (const css_token& t : values) {
                if (skipWhitespace) {
                    skipWhitespace = false;
                    if (isWhitespace(t)) {
                        continue;
                    }
                }
                if (!pruned(t)) {
                    kept.push_back(t);
                    continue;
                }
                if (!kept.empty() && isWhitespace(kept.back())) {
                    kept.pop_back();
                } else {
                    skipWhitespace = true;
                }
            }
            values = std::move(kept);
            changed = true;
        }
        if (topItems(values).empty()) {
            return out;
        }
    }
    Scan scanned;
    scan(values, scanned);
    if (!scanned.ok) {
        return out;
    }
    augmented = augmented || scanned.hasLightDark;
    if (custom) {
        out.verdict = verdictOf(changed, augmented);
        out.value = std::move(values);
        return out;
    }
    std::vector<size_t> top = topItems(values);
    auto identAt = [&](size_t k) { return values[top[k]].type == litehtml::IDENT ? values[top[k]].ident() : std::string(); };
    if (top.size() == 1 && isGlobalKeyword(identAt(0))) {
        out.verdict = verdictOf(changed, augmented);
        out.value = std::move(values);
        return out;
    }
    // RB §4.6's rewrites, per top-level identifier.
    const bool position = name == "position";
    if (position || isOverflowProperty(name)) {
        for (size_t k = 0; k < top.size(); k++) {
            const std::string ident = identAt(k);
            const std::optional<std::string_view> target = position ? profile::positionRewrite(ident) : profile::overflowRewrite(ident);
            if (target) {
                values[top[k]] = tokensOf(*target).front();
                changed = true;
            }
        }
    }
    // The value sets (css.values: display, position, user-select, …), unless a substitution may carry the value.
    if (profile::contains(CSSTable::ValuedProperties, name) && !scanned.hasVar &&
        !(top.size() == 1 && profile::keywordAllowed(name, identAt(0)))) {
        return out;
    }
    std::vector<std::string> idents;
    int numbers = 0;
    int components = 0;
    for (size_t k = 0; k < top.size(); k++) {
        const css_token& t = values[top[k]];
        if (t.type == litehtml::IDENT) {
            idents.push_back(t.ident());
        }
        numbers += t.type == litehtml::NUMBER ? 1 : 0;
        components += (t.type != litehtml::COMMA && !isDelim(t, '/')) ? 1 : 0;
    }
    auto hasIdent = [&](std::string_view ident) { return std::find(idents.begin(), idents.end(), ident) != idents.end(); };
    if (name == "background-clip" && hasIdent("text")) {
        return out;
    }
    if (name == "transform" && scanned.has3D) {
        return out;
    }
    if (name == "rotate" && (hasIdent("x") || hasIdent("y") || hasIdent("z") || numbers > 1)) {
        return out;
    }
    if ((name == "translate" || name == "scale") && components > 2) {
        return out;
    }
    if (name == "color-scheme" && hasIdent("light") && hasIdent("dark")) {
        augmented = true;
    }
    size_t familyStart = values.size();
    if (name == "font-family") {
        familyStart = top.front();
    } else if (name == "font") {
        for (size_t k = 0; k < top.size(); k++) {
            if (!isFontSize(values[top[k]])) {
                continue;
            }
            size_t families = k + 1;
            if (families < top.size() && isDelim(values[top[families]], '/')) {
                families += 2;
            }
            if (families >= top.size()) {
                // Nothing after the size is no family (`font: 12px`), unless a substitution may carry it.
                if (!scanned.hasVar) {
                    return out;
                }
            } else {
                familyStart = top[families];
            }
            break;
        }
    }
    if (familyStart < values.size()) {
        const FontReduction reduced = reduceFamilies(values, familyStart, values.size());
        if (reduced.changed || reduced.augmented) {
            replaceTail(values, familyStart, reduced.text);
            changed = changed || reduced.changed;
            augmented = augmented || reduced.augmented;
        }
    }
    out.verdict = verdictOf(changed, augmented);
    out.value = std::move(values);
    return out;
}

Judged value(std::span<const css_token> input) {
    Judged out;
    css_token_vector values(input.begin(), input.end());
    bool safeArea = false;
    bool resolved = false;
    if (!rewriteEnv(values, safeArea, resolved)) {
        return out;
    }
    Scan scanned;
    scan(values, scanned);
    if (!scanned.ok) {
        return out;
    }
    out.verdict = verdictOf(resolved, safeArea || scanned.hasLightDark);
    out.value = std::move(values);
    return out;
}

Judged selector(std::span<const css_token> complexSelector) {
    Judged out;
    css_token_vector tokens(complexSelector.begin(), complexSelector.end());
    bool augmented = false;
    if (!walkSelector(tokens, augmented)) {
        return out;
    }
    out.verdict = augmented ? Verdict::Augment : Verdict::Keep;
    out.value = std::move(tokens);
    return out;
}

bool atRuleKept(std::string_view loweredName) {
    return profile::contains(CSSTable::AtRules, loweredName);
}

bool mediaQueryInProfile(std::span<const css_token> prelude) {
    return mediaQueryInProfileImpl(prelude);
}

bool supportsCondition(std::span<const css_token> condition) {
    return ConditionParser(condition).whole() == Result::True;
}

bool supportsParenthesized(std::span<const css_token> inner) {
    return parenContents(inner) == Result::True;
}

std::string normalizedUrl(std::string_view url) {
    std::string out;
    out.reserve(url.size());
    for (char c : url) {
        if (c != '\t' && c != '\n' && c != '\r') {
            out += c;
        }
    }
    const auto control = [](char c) { return static_cast<unsigned char>(c) <= 0x20; };
    size_t first = 0;
    while (first < out.size() && control(out[first])) {
        first++;
    }
    size_t last = out.size();
    while (last > first && control(out[last - 1])) {
        last--;
    }
    return out.substr(first, last - first);
}

bool urlKept(std::string_view url) {
    // A fragment, or a data: image the bytes of which a decoder takes at a size it may hold (widget-sandbox v0.3.0: a
    // broken one is dropped with its declaration too, which draws what a failed image draws).
    const std::optional<std::string> checked = checkedImageURL(url);
    return checked && ((!checked->empty() && (*checked)[0] == '#') || imageSource(*checked) == ImageSource::Kept);
}

bool imageSourceKept(std::string_view src) {
    return imageSource(src) == ImageSource::Kept;
}

ImageSource imageSource(std::string_view src) {
    const std::optional<std::string> url = checkedImageURL(src);
    if (!url || url->empty() || (*url)[0] == '#') {
        return ImageSource::Refused;
    }
    // widget-sandbox v0.3.0: the bytes pick the decoder; past kMaxDataImagePixels the placeholder, as a refused URL.
    const std::optional<std::pair<uint32_t, uint32_t>> size = dataImageSize(*url);
    if (!size) {
        return ImageSource::Broken;
    }
    return uint64_t(size->first) * size->second <= kMaxDataImagePixels ? ImageSource::Kept : ImageSource::Refused;
}

std::optional<std::string> fragmentHref(std::string_view href) {
    std::string url = normalizedUrl(href);
    return wellFormedFragment(url) ? std::optional<std::string>(url) : std::nullopt;
}

std::string reduceFontFamilyText(std::string_view family) {
    const css_token_vector values = tokensOf(family);
    const FontReduction reduced = reduceFamilies(values, 0, values.size());
    return reduced.changed || reduced.augmented ? reduced.text : std::string(family);
}

} // namespace wr::css::policy
