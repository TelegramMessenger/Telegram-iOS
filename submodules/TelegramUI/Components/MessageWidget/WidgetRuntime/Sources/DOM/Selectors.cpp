#include "Sources/DOM/Selectors.h"

#include <algorithm>
#include <array>
#include <climits>
#include <string>
#include <string_view>
#include <utility>

#include "Generated/Bindings.h"
#include "Sources/DOM/CSSComponents.h"
#include "Sources/DOM/DOM.h"
#include <litehtml/css_parser.h>
#include <litehtml/css_tokenizer.h>

namespace wr {

namespace {

constexpr int kMaxNesting = 32;
constexpr int kMaxCompounds = 1024;
/// How much of the selector a SyntaxError's message quotes: QuickJS keeps 255 bytes of a DOMException's message.
constexpr size_t kMaxQuotedBytes = 200;

using css::cssInput;

/// The SyntaxError, quoting at most kMaxQuotedBytes of the selector (cut at a character boundary). It converts only
/// that much, so a selector over the length cap is refused in O(1).
[[noreturn]] void syntaxError(const String& text) {
    std::string quoted = cssInput(text, kMaxQuotedBytes);
    bool cut = text.length() > kMaxQuotedBytes || quoted.size() > kMaxQuotedBytes;
    if (quoted.size() > kMaxQuotedBytes) {
        size_t end = kMaxQuotedBytes;
        while (end > 0 && (static_cast<unsigned char>(quoted[end]) & 0xC0) == 0x80) {
            end--;
        }
        quoted.resize(end);
    }
    if (cut) {
        quoted += "\xE2\x80\xA6"; // …
    }
    throw DOMError{"SyntaxError", "'" + quoted + "' is not a valid selector."};
}

using litehtml::css_token;
using litehtml::css_token_vector;

/// HTML's attributes whose values attribute selectors match case-insensitively on HTML elements (HTML,
/// "case-sensitivity of selectors").
constexpr std::string_view kCaseInsensitiveAttributes[] = {
    "accept", "accept-charset", "align", "alink", "axis", "bgcolor", "charset", "checked", "clear", "codetype", "color",
    "compact", "declare", "defer", "dir", "direction", "disabled", "enctype", "face", "frame", "hreflang", "http-equiv",
    "lang", "language", "link", "media", "method", "multiple", "nohref", "noresize", "noshade", "nowrap", "readonly",
    "rel", "rev", "rules", "scope", "scrolling", "selected", "shape", "target", "text", "type", "valign", "valuetype",
    "vlink",
};

std::string asciiLower(std::string s) {
    for (char& c : s) {
        if (c >= 'A' && c <= 'Z') {
            c = char(c + 32);
        }
    }
    return s;
}

char16_t fold(char16_t c, bool ci) {
    return ci && c >= 'A' && c <= 'Z' ? char16_t(c + 32) : c;
}

/// The UTF-16 units of a string, for comparisons without copying.
struct Units {
    JSStringView v;
    uint32_t size() const { return v.length; }
    char16_t operator[](uint32_t i) const { return v.latin1 ? char16_t(v.latin1[i]) : char16_t(v.utf16[i]); }
};

/// Knuth-Morris-Pratt's failure table for `n`, ASCII case-folded when `ci`.
std::vector<uint32_t> failureTable(Units n, bool ci) {
    std::vector<uint32_t> failure(n.size(), 0);
    for (uint32_t i = 1, k = 0; i < n.size(); i++) {
        while (k > 0 && fold(n[i], ci) != fold(n[k], ci)) {
            k = failure[k - 1];
        }
        if (fold(n[i], ci) == fold(n[k], ci)) {
            k++;
        }
        failure[i] = k;
    }
    return failure;
}

/// A run of tokens inside the one componentized vector: the parser never copies a token, so no part of the input is
/// copied once per level it is nested in.
struct Tokens {
    const css_token* data = nullptr;
    size_t size = 0;
    const css_token& operator[](size_t i) const { return data[i]; }
    bool empty() const { return size == 0; }
    Tokens slice(size_t from, size_t to) const { return Tokens{data + from, to - from}; }
    static Tokens of(const css_token_vector& v) { return Tokens{v.data(), v.size()}; }
};

bool isDelim(const css_token& t, char c) {
    return t.ch == c;
}

bool isWhitespace(const css_token& t) {
    return t.type == litehtml::WHITESPACE;
}

/// Without leading and trailing whitespace. In place, by index: `' /**/'.repeat(n)` is n whitespace tokens in a row.
Tokens trim(Tokens t) {
    size_t start = 0;
    size_t end = t.size;
    while (start < end && isWhitespace(t[start])) {
        start++;
    }
    while (end > start && isWhitespace(t[end - 1])) {
        end--;
    }
    return t.slice(start, end);
}

/// `t` is an integer <number-token> (or the numeric part of an integer <dimension-token>). Its digits are read from
/// the source text (litehtml keeps a float), saturated to 32 bits. `sign`: whether the text starts with + or -.
bool integerOf(const css_token& t, int32_t& out, bool& sign) {
    if (t.n.number_type != litehtml::css_number_integer) {
        return false;
    }
    const std::string& text = t.repr;
    size_t i = 0;
    bool negative = false;
    sign = i < text.size() && (text[i] == '+' || text[i] == '-');
    if (sign) {
        negative = text[i] == '-';
        i++;
    }
    int64_t value = 0;
    size_t digits = 0;
    for (; i < text.size() && text[i] >= '0' && text[i] <= '9'; i++, digits++) {
        value = std::min<int64_t>(value * 10 + (text[i] - '0'), int64_t(INT32_MAX) + 1);
    }
    if (digits == 0) {
        return false;
    }
    value = negative ? -value : value;
    out = int32_t(std::max<int64_t>(std::min<int64_t>(value, INT32_MAX), INT32_MIN));
    return true;
}

bool signlessInteger(const css_token& t, int32_t& out) {
    bool sign = false;
    return t.type == litehtml::NUMBER && integerOf(t, out, sign) && !sign;
}

bool signedInteger(const css_token& t, int32_t& out) {
    bool sign = false;
    return t.type == litehtml::NUMBER && integerOf(t, out, sign) && sign;
}

int32_t negate(int32_t v) {
    return v == INT32_MIN ? INT32_MAX : -v;
}

/// CSS Syntax's <an+b> (https://www.w3.org/TR/css-syntax-3/#anb-microsyntax), over tokens: `t` has no leading or
/// trailing whitespace.
bool anPlusB(Tokens t, int32_t& a, int32_t& b) {
    if (t.empty()) {
        return false;
    }
    const css_token& first = t[0];
    size_t i = 1;
    // What follows A: "n", "n-" or "n-<digits>", lowercased.
    std::string unit;
    if (first.type == litehtml::IDENT) {
        std::string ident = asciiLower(first.name());
        if (t.size == 1 && ident == "odd") {
            a = 2;
            b = 1;
            return true;
        }
        if (t.size == 1 && ident == "even") {
            a = 2;
            b = 0;
            return true;
        }
        bool minus = !ident.empty() && ident[0] == '-';
        a = minus ? -1 : 1;
        unit = minus ? ident.substr(1) : ident;
    } else if (isDelim(first, '+') && t.size > 1 && t[1].type == litehtml::IDENT && t[1].name().compare(0, 1, "-") != 0) {
        // '+'? n…: the + directly before the ident, no whitespace between.
        a = 1;
        unit = asciiLower(t[1].name());
        i = 2;
    } else if (first.type == litehtml::NUMBER) {
        bool sign = false;
        a = 0;
        return t.size == 1 && integerOf(first, b, sign);
    } else if (first.type == litehtml::DIMENSION) {
        bool sign = false;
        if (!integerOf(first, a, sign)) {
            return false;
        }
        unit = asciiLower(first.unit());
    } else {
        return false;
    }
    auto skipWhitespace = [&] {
        while (i < t.size && isWhitespace(t[i])) {
            i++;
        }
    };
    if (unit == "n") {
        skipWhitespace();
        if (i == t.size) {
            b = 0;
            return true;
        }
        if (signedInteger(t[i], b)) {
            return i + 1 == t.size;
        }
        if (isDelim(t[i], '+') || isDelim(t[i], '-')) {
            bool minus = isDelim(t[i], '-');
            i++;
            skipWhitespace();
            if (i < t.size && signlessInteger(t[i], b)) {
                b = minus ? negate(b) : b;
                return i + 1 == t.size;
            }
        }
        return false;
    }
    if (unit == "n-") {
        skipWhitespace();
        if (i < t.size && signlessInteger(t[i], b)) {
            b = negate(b);
            return i + 1 == t.size;
        }
        return false;
    }
    // "n-<digits>": B is the digits, negated.
    if (unit.size() > 2 && unit[0] == 'n' && unit[1] == '-' && i == t.size) {
        int64_t value = 0;
        for (size_t k = 2; k < unit.size(); k++) {
            if (unit[k] < '0' || unit[k] > '9') {
                return false;
            }
            value = std::min<int64_t>(value * 10 + (unit[k] - '0'), int64_t(INT32_MAX));
        }
        b = int32_t(-value);
        return true;
    }
    return false;
}

/// Whether a pseudo-class may follow a pseudo-element in its compound: the user-action ones (Selectors 4, 3.6.3).
bool userAction(PseudoClass p) {
    return p == PseudoClass::Hover || p == PseudoClass::Active || p == PseudoClass::Focus || p == PseudoClass::FocusWithin ||
           p == PseudoClass::FocusVisible;
}

/// The grammar, over tokens. Each function returns false for an invalid selector, so a forgiving list (:is, :where)
/// drops an invalid part without unwinding, and a SyntaxError is made once, at the top. A selector over one of ruling
/// 6's caps sets `overLimit`, which no forgiving list drops.
class Parser {
public:
    explicit Parser(JSContext* ctx) : m_ctx(ctx) {}

    /// `nesting`: functional pseudo-classes around this list (0 at the top). Pseudo-elements are invalid inside one.
    bool list(Tokens tokens, bool forgiving, int nesting, SelectorList& out) {
        if (nesting > kMaxNesting) {
            return this->failOverLimit();
        }
        size_t start = 0;
        for (size_t i = 0; i <= tokens.size; i++) {
            if (i < tokens.size && tokens[i].type != litehtml::COMMA) {
                continue;
            }
            ComplexSelector complex;
            if (this->complex(trim(tokens.slice(start, i)), nesting, complex)) {
                out.push_back(std::move(complex));
            } else if (!forgiving || m_overLimit) {
                return false;
            }
            start = i + 1;
        }
        return true;
    }

private:
    bool failOverLimit() {
        m_overLimit = true;
        return false;
    }

    bool complex(Tokens tokens, int nesting, ComplexSelector& out) {
        if (tokens.empty()) {
            return false;
        }
        size_t i = 0;
        while (true) {
            if (++m_compounds > kMaxCompounds) {
                return this->failOverLimit();
            }
            out.compounds.emplace_back();
            bool pseudoElement = false;
            if (!this->compound(tokens, i, nesting, out.compounds.back(), pseudoElement)) {
                return false;
            }
            bool sawSpace = false;
            while (i < tokens.size && isWhitespace(tokens[i])) {
                sawSpace = true;
                i++;
            }
            if (i == tokens.size) {
                return true;
            }
            // A pseudo-element ends its complex selector.
            if (pseudoElement) {
                return false;
            }
            Combinator combinator = Combinator::Descendant;
            if (isDelim(tokens[i], '>')) {
                combinator = Combinator::Child;
            } else if (isDelim(tokens[i], '+')) {
                combinator = Combinator::NextSibling;
            } else if (isDelim(tokens[i], '~')) {
                combinator = Combinator::SubsequentSibling;
            } else if (!sawSpace) {
                return false;
            }
            if (combinator != Combinator::Descendant) {
                i++;
                while (i < tokens.size && isWhitespace(tokens[i])) {
                    i++;
                }
                if (i == tokens.size) {
                    return false;
                }
            }
            out.compounds.back().combinator = combinator;
        }
    }

    bool compound(Tokens t, size_t& i, int nesting, CompoundSelector& out, bool& pseudoElement) {
        // An optional type or universal selector, with an optional namespace prefix.
        if (i < t.size) {
            SimpleSelector::Namespaces ns = SimpleSelector::Namespaces::Any;
            size_t j = i;
            if (j + 1 < t.size && isDelim(t[j + 1], '|') && (isDelim(t[j], '*') || t[j].type == litehtml::IDENT)) {
                if (t[j].type == litehtml::IDENT) {
                    return false; // a named prefix: there is no @namespace
                }
                j += 2;
            } else if (isDelim(t[j], '|')) {
                ns = SimpleSelector::Namespaces::None;
                j += 1;
            }
            if (j < t.size && (t[j].type == litehtml::IDENT || isDelim(t[j], '*'))) {
                SimpleSelector& s = out.simples.emplace_back();
                s.ns = ns;
                if (t[j].type == litehtml::IDENT) {
                    s.kind = SimpleSelector::Kind::Type;
                    s.name = Atom::fromUTF8(m_ctx, t[j].name());
                    s.lowerName = Atom::fromUTF8(m_ctx, asciiLower(t[j].name()));
                } else {
                    s.kind = SimpleSelector::Kind::Universal;
                }
                i = j + 1;
            } else if (j != i) {
                return false; // a prefix with nothing after it
            }
        }
        // Subclass selectors, pseudo-classes and pseudo-elements, with no whitespace between them.
        while (i < t.size) {
            const css_token& tok = t[i];
            if (tok.type == litehtml::HASH) {
                if (tok.hash_type != litehtml::css_hash_id || pseudoElement) {
                    return false;
                }
                SimpleSelector& s = out.simples.emplace_back();
                s.kind = SimpleSelector::Kind::Id;
                s.value = String::fromUTF8(m_ctx, tok.name());
                i++;
            } else if (isDelim(tok, '.')) {
                if (i + 1 >= t.size || t[i + 1].type != litehtml::IDENT || pseudoElement) {
                    return false;
                }
                SimpleSelector& s = out.simples.emplace_back();
                s.kind = SimpleSelector::Kind::Class;
                s.classes.push_back(String::fromUTF8(m_ctx, t[i + 1].name()));
                i += 2;
            } else if (tok.type == litehtml::SQUARE_BLOCK) {
                if (pseudoElement || !this->attribute(trim(Tokens::of(tok.value)), out.simples.emplace_back())) {
                    return false;
                }
                i++;
            } else if (tok.type == litehtml::COLON) {
                i++;
                bool element = i < t.size && t[i].type == litehtml::COLON;
                if (element) {
                    i++;
                }
                if (i >= t.size) {
                    return false;
                }
                SimpleSelector& s = out.simples.emplace_back();
                if (!(element ? this->pseudoElement(t[i], s) : this->pseudoClass(t[i], nesting, s))) {
                    return false;
                }
                if (s.kind == SimpleSelector::Kind::PseudoElement) {
                    // One per compound, and none inside a functional pseudo-class: :not(::before) would match
                    // everything.
                    if (pseudoElement || nesting > 0) {
                        return false;
                    }
                    pseudoElement = true;
                } else if (pseudoElement && !userAction(s.pseudo)) {
                    return false;
                }
                i++;
            } else {
                break;
            }
        }
        return !out.simples.empty();
    }

    bool attribute(Tokens t, SimpleSelector& s) {
        s.kind = SimpleSelector::Kind::Attribute;
        // Without a prefix an attribute selector matches attributes in no namespace; `*|` any; `|` none. A named
        // prefix is invalid (no @namespace).
        s.ns = SimpleSelector::Namespaces::None;
        size_t i = 0;
        if (i + 1 < t.size && isDelim(t[i], '*') && isDelim(t[i + 1], '|')) {
            s.ns = SimpleSelector::Namespaces::Any;
            i += 2;
        } else if (i < t.size && isDelim(t[i], '|')) {
            i += 1;
        }
        if (i >= t.size || t[i].type != litehtml::IDENT) {
            return false;
        }
        if (i + 2 < t.size && isDelim(t[i + 1], '|') && t[i + 2].type == litehtml::IDENT) {
            return false;
        }
        std::string lower = asciiLower(t[i].name());
        s.name = Atom::fromUTF8(m_ctx, t[i].name());
        s.lowerName = Atom::fromUTF8(m_ctx, lower);
        for (std::string_view n : kCaseInsensitiveAttributes) {
            if (n == lower) {
                s.htmlCaseInsensitive = true;
            }
        }
        i++;
        while (i < t.size && isWhitespace(t[i])) {
            i++;
        }
        if (i == t.size) {
            return true;
        }
        // The operator: '=' alone, or one of ~ | ^ $ * directly followed by '='.
        if (isDelim(t[i], '=')) {
            s.op = SimpleSelector::Op::Equals;
            i++;
        } else if (i + 1 < t.size && isDelim(t[i + 1], '=')) {
            switch (t[i].ch) {
            case '~':
                s.op = SimpleSelector::Op::Includes;
                break;
            case '|':
                s.op = SimpleSelector::Op::DashMatch;
                break;
            case '^':
                s.op = SimpleSelector::Op::Prefix;
                break;
            case '$':
                s.op = SimpleSelector::Op::Suffix;
                break;
            case '*':
                s.op = SimpleSelector::Op::Substring;
                break;
            default:
                return false;
            }
            i += 2;
        } else {
            return false;
        }
        while (i < t.size && isWhitespace(t[i])) {
            i++;
        }
        if (i == t.size || (t[i].type != litehtml::IDENT && t[i].type != litehtml::STRING)) {
            return false;
        }
        s.value = String::fromUTF8(m_ctx, t[i].str());
        i++;
        while (i < t.size && isWhitespace(t[i])) {
            i++;
        }
        if (i < t.size) {
            std::string modifier = t[i].ident();
            if (modifier == "i") {
                s.caseSensitivity = SimpleSelector::Case::Insensitive;
            } else if (modifier == "s") {
                s.caseSensitivity = SimpleSelector::Case::Sensitive;
            } else {
                return false;
            }
            if (i + 1 != t.size) {
                return false;
            }
        }
        if (s.op == SimpleSelector::Op::Substring) {
            Units n{s.value.view()};
            s.failure = failureTable(n, false);
            s.failureFolded = failureTable(n, true);
        }
        return true;
    }

    bool pseudoElement(const css_token& t, SimpleSelector& s) {
        static constexpr std::array<std::string_view, 12> kElements = {
            "before", "after", "first-line", "first-letter", "marker", "placeholder", "selection", "backdrop",
            "file-selector-button", "target-text", "spelling-error", "grammar-error",
        };
        std::string name = t.ident();
        for (std::string_view n : kElements) {
            if (n == name) {
                s.kind = SimpleSelector::Kind::PseudoElement;
                return true;
            }
        }
        return false;
    }

    bool pseudoClass(const css_token& t, int nesting, SimpleSelector& s) {
        s.kind = SimpleSelector::Kind::Pseudo;
        if (t.type == litehtml::IDENT) {
            static constexpr std::pair<std::string_view, PseudoClass> kPlain[] = {
                {"root", PseudoClass::Root}, {"empty", PseudoClass::Empty}, {"first-child", PseudoClass::FirstChild},
                {"last-child", PseudoClass::LastChild}, {"only-child", PseudoClass::OnlyChild},
                {"first-of-type", PseudoClass::FirstOfType}, {"last-of-type", PseudoClass::LastOfType},
                {"only-of-type", PseudoClass::OnlyOfType}, {"scope", PseudoClass::Scope}, {"link", PseudoClass::AnyLink},
                {"any-link", PseudoClass::AnyLink}, {"visited", PseudoClass::Visited}, {"target", PseudoClass::Target},
                {"defined", PseudoClass::Defined}, {"checked", PseudoClass::Checked},
                {"indeterminate", PseudoClass::Indeterminate}, {"default", PseudoClass::Default},
                {"disabled", PseudoClass::Disabled}, {"enabled", PseudoClass::Enabled}, {"required", PseudoClass::Required},
                {"optional", PseudoClass::Optional}, {"read-only", PseudoClass::ReadOnly},
                {"read-write", PseudoClass::ReadWrite}, {"placeholder-shown", PseudoClass::PlaceholderShown},
                {"focus", PseudoClass::Focus}, {"focus-within", PseudoClass::FocusWithin},
                {"focus-visible", PseudoClass::FocusVisible}, {"hover", PseudoClass::Hover}, {"active", PseudoClass::Active},
            };
            std::string name = t.ident();
            // CSS2's pseudo-elements keep their single-colon spelling.
            if (name == "before" || name == "after" || name == "first-line" || name == "first-letter") {
                s.kind = SimpleSelector::Kind::PseudoElement;
                return true;
            }
            for (const auto& [n, p] : kPlain) {
                if (n == name) {
                    s.pseudo = p;
                    return true;
                }
            }
            return false;
        }
        if (t.type != litehtml::CV_FUNCTION) {
            return false;
        }
        std::string name = asciiLower(t.name());
        Tokens args = trim(Tokens::of(t.value));
        if (name == "not" || name == "is" || name == "where") {
            s.pseudo = name == "not" ? PseudoClass::Not : name == "is" ? PseudoClass::Is : PseudoClass::Where;
            // :is() and :where() take a forgiving list; :not() does not, and needs at least one selector.
            bool forgiving = name != "not";
            if (!forgiving && args.empty()) {
                return false;
            }
            return this->list(args, forgiving, nesting + 1, s.list);
        }
        static constexpr std::pair<std::string_view, PseudoClass> kNth[] = {
            {"nth-child", PseudoClass::NthChild}, {"nth-last-child", PseudoClass::NthLastChild},
            {"nth-of-type", PseudoClass::NthOfType}, {"nth-last-of-type", PseudoClass::NthLastOfType},
        };
        for (const auto& [n, p] : kNth) {
            if (n != name) {
                continue;
            }
            s.pseudo = p;
            size_t of = args.size;
            if (p == PseudoClass::NthChild || p == PseudoClass::NthLastChild) {
                for (size_t k = 0; k < args.size; k++) {
                    if (args[k].ident() == "of") {
                        of = k;
                        break;
                    }
                }
            }
            if (!anPlusB(trim(args.slice(0, of)), s.a, s.b)) {
                return false;
            }
            if (of < args.size) {
                Tokens rest = trim(args.slice(of + 1, args.size));
                if (rest.empty()) {
                    return false;
                }
                return this->list(rest, false, nesting + 1, s.list);
            }
            return true;
        }
        return false;
    }

    JSContext* m_ctx;
    int m_compounds = 0;
    bool m_overLimit = false;
};

// ---- Matching ----

/// WebKit's match results: a failed ancestor search ends the whole match instead of backtracking.
enum class Result : uint8_t { Matches, FailsLocally, FailsAllSiblings, FailsCompletely };

bool equalAt(Units h, uint32_t at, Units n, bool ci) {
    for (uint32_t k = 0; k < n.size(); k++) {
        if (fold(h[at + k], ci) != fold(n[k], ci)) {
            return false;
        }
    }
    return true;
}

/// Knuth-Morris-Pratt with a failure table made at parse time: linear in both lengths whatever they hold.
bool contains(Units h, Units n, bool ci, const std::vector<uint32_t>& failure) {
    if (n.size() > h.size()) {
        return false;
    }
    for (uint32_t i = 0, k = 0; i < h.size(); i++) {
        while (k > 0 && fold(h[i], ci) != fold(n[k], ci)) {
            k = failure[k - 1];
        }
        if (fold(h[i], ci) == fold(n[k], ci)) {
            k++;
        }
        if (k == n.size()) {
            return true;
        }
    }
    return false;
}

class Matcher {
public:
    Matcher(JSContext* ctx, Node* scope) : m_ctx(ctx), m_state(DOMState::of(ctx)), m_scope(scope) {}

    bool any(const SelectorList& list, Element& element) {
        for (const ComplexSelector& complex : list) {
            if (this->from(complex, complex.compounds.size() - 1, element) == Result::Matches) {
                return true;
            }
        }
        return false;
    }

private:
    Element* previousElement(Element& e) {
        for (Node* n = e.previousSiblingNode(); n; n = n->previousSiblingNode()) {
            if (n->isElement()) {
                return static_cast<Element*>(n);
            }
        }
        return nullptr;
    }

    Element* nextElement(Element& e) {
        for (Node* n = e.nextSiblingNode(); n; n = n->nextSiblingNode()) {
            if (n->isElement()) {
                return static_cast<Element*>(n);
            }
        }
        return nullptr;
    }

    /// Compound `i` and everything left of it against `e`. A frame per compound (ruling 6 caps them at 1,024); the
    /// compound test returns before the recursion, so a frame holds only the walk.
    Result from(const ComplexSelector& c, size_t i, Element& e) {
        if (!this->compound(c.compounds[i], e)) {
            return Result::FailsLocally;
        }
        if (i == 0) {
            return Result::Matches;
        }
        switch (c.compounds[i - 1].combinator) {
        case Combinator::Descendant:
            for (Element* a = e.parentElementNode(); a; a = a->parentElementNode()) {
                Result r = this->from(c, i - 1, *a);
                if (r == Result::Matches || r == Result::FailsCompletely) {
                    return r;
                }
            }
            return Result::FailsCompletely;
        case Combinator::Child: {
            Element* p = e.parentElementNode();
            if (!p) {
                return Result::FailsCompletely;
            }
            Result r = this->from(c, i - 1, *p);
            return r == Result::Matches || r == Result::FailsCompletely ? r : Result::FailsAllSiblings;
        }
        case Combinator::NextSibling: {
            Element* s = this->previousElement(e);
            return s ? this->from(c, i - 1, *s) : Result::FailsAllSiblings;
        }
        case Combinator::SubsequentSibling:
            for (Element* s = this->previousElement(e); s; s = this->previousElement(*s)) {
                Result r = this->from(c, i - 1, *s);
                if (r != Result::FailsLocally) {
                    return r;
                }
            }
            return Result::FailsAllSiblings;
        case Combinator::None:
            break;
        }
        return Result::FailsCompletely;
    }

    /// Not inlined into from(): its locals (attribute values, ids) would otherwise sit in every recursion frame.
    [[gnu::noinline]] bool compound(const CompoundSelector& compound, Element& e) {
        for (const SimpleSelector& s : compound.simples) {
            if (!this->simple(s, e)) {
                return false;
            }
        }
        return true;
    }

    static bool htmlInHTMLDocument(Element& e) { return e.isHTMLElement() && e.nodeDocument().isHTMLDocument(); }
    static bool quirks(Element& e) { return e.nodeDocument().mode() == DocumentMode::Quirks; }

    bool simple(const SimpleSelector& s, Element& e) {
        using Kind = SimpleSelector::Kind;
        switch (s.kind) {
        case Kind::Universal:
            return s.ns == SimpleSelector::Namespaces::Any || e.ns() == Namespace::None;
        case Kind::Type:
            if (s.ns == SimpleSelector::Namespaces::None && e.ns() != Namespace::None) {
                return false;
            }
            return e.localNameAtom() == (htmlInHTMLDocument(e) ? s.lowerName.get() : s.name.get());
        case Kind::Id: {
            std::optional<String> id = e.attributeValue(m_ctx, m_state.name(Name::id));
            if (!id) {
                return false;
            }
            Units h{id->view()};
            Units n{s.value.view()};
            if (h.size() != n.size()) {
                return false;
            }
            return equalAt(h, 0, n, quirks(e));
        }
        case Kind::Class:
            return elementHasClasses(m_ctx, e, s.classes, quirks(e));
        case Kind::Attribute:
            return this->attribute(s, e);
        case Kind::Pseudo:
            return this->pseudo(s, e);
        case Kind::PseudoElement:
            return false;
        }
        return false;
    }

    bool attribute(const SimpleSelector& s, Element& e) {
        bool html = htmlInHTMLDocument(e);
        JSAtom name = html ? s.lowerName.get() : s.name.get();
        for (size_t i = 0; i < e.attributeCount(); i++) {
            const Attribute& a = e.attributeAt(i);
            if (a.localName.atom != name || (s.ns == SimpleSelector::Namespaces::None && a.ns != Namespace::None)) {
                continue;
            }
            if (s.op == SimpleSelector::Op::Exists) {
                return true;
            }
            bool ci = s.caseSensitivity == SimpleSelector::Case::Insensitive ||
                      (s.caseSensitivity == SimpleSelector::Case::Default && s.htmlCaseInsensitive && html && a.ns == Namespace::None);
            String value = String::adopt(m_ctx, JS_DupValue(m_ctx, a.value.value));
            if (this->valueMatches(s, value, ci)) {
                return true;
            }
        }
        return false;
    }

    bool valueMatches(const SimpleSelector& s, const String& value, bool ci) {
        Units h{value.view()};
        Units n{s.value.view()};
        using Op = SimpleSelector::Op;
        switch (s.op) {
        case Op::Exists:
            return true;
        case Op::Equals:
            if (h.size() != n.size()) {
                return false;
            }
            return equalAt(h, 0, n, ci);
        case Op::Includes: {
            if (n.size() == 0) {
                return false;
            }
            for (uint32_t k = 0; k < n.size(); k++) {
                if (isASCIIWhitespace(n[k])) {
                    return false;
                }
            }
            uint32_t start = 0;
            while (start < h.size()) {
                while (start < h.size() && isASCIIWhitespace(h[start])) {
                    start++;
                }
                uint32_t end = start;
                while (end < h.size() && !isASCIIWhitespace(h[end])) {
                    end++;
                }
                if (end - start == n.size() && equalAt(h, start, n, ci)) {
                    return true;
                }
                start = end;
            }
            return false;
        }
        case Op::DashMatch:
            if (h.size() < n.size() || (h.size() > n.size() && h[n.size()] != u'-')) {
                return false;
            }
            return equalAt(h, 0, n, ci);
        case Op::Prefix:
            if (n.size() == 0 || h.size() < n.size()) {
                return false;
            }
            return equalAt(h, 0, n, ci);
        case Op::Suffix:
            if (n.size() == 0 || h.size() < n.size()) {
                return false;
            }
            return equalAt(h, h.size() - n.size(), n, ci);
        case Op::Substring:
            if (n.size() == 0 || h.size() < n.size()) {
                return false;
            }
            return contains(h, n, ci, ci ? s.failureFolded : s.failure);
        }
        return false;
    }

    /// The 1-based position of `e` among its element siblings that `counts` accepts, from the start or the end.
    template <class Accept>
    int64_t position(Element& e, bool fromEnd, Accept counts) {
        int64_t index = 1;
        for (Element* s = fromEnd ? this->nextElement(e) : this->previousElement(e); s;
             s = fromEnd ? this->nextElement(*s) : this->previousElement(*s)) {
            if (counts(*s)) {
                index++;
            }
        }
        return index;
    }

    /// Whether some n >= 0 has a·n + b = index.
    static bool nth(int64_t a, int64_t b, int64_t index) {
        if (a == 0) {
            return index == b;
        }
        int64_t diff = index - b;
        return diff % a == 0 && diff / a >= 0;
    }

    static bool sameType(Element& x, Element& y) { return x.ns() == y.ns() && x.localNameAtom() == y.localNameAtom(); }

    bool isLink(Element& e) {
        return (e.hasHTMLName(m_state.name(Name::a)) || e.hasHTMLName(m_state.name(Name::area))) && e.hasAttributeAtom(m_ctx, m_state.name(Name::href));
    }

    bool isFormControl(Element& e) {
        for (Name n : {Name::button, Name::input, Name::select, Name::textarea, Name::optgroup, Name::option, Name::fieldset}) {
            if (e.hasHTMLName(m_state.name(n))) {
                return true;
            }
        }
        return false;
    }

    /// :read-write: a textarea, or an input whose type takes readonly, with neither readonly nor disabled.
    bool readWrite(Element& e) {
        bool textarea = e.hasHTMLName(m_state.name(Name::textarea));
        if (!textarea && !e.hasHTMLName(m_state.name(Name::input))) {
            return false;
        }
        if (e.hasAttributeAtom(m_ctx, m_state.name(Name::readonly)) || m_state.elementState()->disabled(m_ctx, e)) {
            return false;
        }
        if (textarea) {
            return true;
        }
        std::optional<String> type = e.attributeValue(m_ctx, m_state.name(Name::type));
        if (!type) {
            return true;
        }
        for (const char* t : {"hidden", "range", "color", "checkbox", "radio", "file", "submit", "image", "reset", "button"}) {
            if (type->equalsIgnoringASCIICase(t)) {
                return false;
            }
        }
        return true;
    }

    bool pseudo(const SimpleSelector& s, Element& e) {
        ElementState& state = *m_state.elementState();
        switch (s.pseudo) {
        case PseudoClass::Root:
            return e.parent() && e.parent()->type() == NodeType::Document;
        case PseudoClass::Empty:
            for (size_t i = 0; i < e.childCount(); i++) {
                Node* c = e.childAt(i);
                if (c->isElement()) {
                    return false;
                }
                if ((c->type() == NodeType::Text || c->type() == NodeType::CDATASection) && static_cast<CharacterData*>(c)->length(m_ctx) > 0) {
                    return false;
                }
            }
            return true;
        case PseudoClass::FirstChild:
            return !this->previousElement(e);
        case PseudoClass::LastChild:
            return !this->nextElement(e);
        case PseudoClass::OnlyChild:
            return !this->previousElement(e) && !this->nextElement(e);
        case PseudoClass::FirstOfType:
            return this->position(e, false, [&](Element& s2) { return sameType(s2, e); }) == 1;
        case PseudoClass::LastOfType:
            return this->position(e, true, [&](Element& s2) { return sameType(s2, e); }) == 1;
        case PseudoClass::OnlyOfType:
            return this->position(e, false, [&](Element& s2) { return sameType(s2, e); }) == 1 &&
                   this->position(e, true, [&](Element& s2) { return sameType(s2, e); }) == 1;
        case PseudoClass::NthChild:
        case PseudoClass::NthLastChild: {
            if (!s.list.empty() && !this->any(s.list, e)) {
                return false;
            }
            bool fromEnd = s.pseudo == PseudoClass::NthLastChild;
            int64_t index = this->position(e, fromEnd, [&](Element& s2) { return s.list.empty() || this->any(s.list, s2); });
            return nth(s.a, s.b, index);
        }
        case PseudoClass::NthOfType:
        case PseudoClass::NthLastOfType: {
            bool fromEnd = s.pseudo == PseudoClass::NthLastOfType;
            return nth(s.a, s.b, this->position(e, fromEnd, [&](Element& s2) { return sameType(s2, e); }));
        }
        case PseudoClass::Not:
            return !this->any(s.list, e);
        case PseudoClass::Is:
        case PseudoClass::Where:
            return this->any(s.list, e);
        case PseudoClass::Scope:
            if (m_scope && m_scope->isElement()) {
                return &e == m_scope;
            }
            return e.parent() && e.parent()->type() == NodeType::Document;
        case PseudoClass::AnyLink:
            return this->isLink(e);
        case PseudoClass::Visited:
        case PseudoClass::Target:
            return false;
        case PseudoClass::Defined:
            return true;
        case PseudoClass::Checked:
            return state.checked(m_ctx, e);
        case PseudoClass::Indeterminate:
            return state.indeterminate(m_ctx, e);
        case PseudoClass::Default:
            return state.isDefault(m_ctx, e);
        case PseudoClass::Disabled:
            return state.disabled(m_ctx, e);
        case PseudoClass::Enabled:
            return this->isFormControl(e) && !state.disabled(m_ctx, e);
        case PseudoClass::Required:
        case PseudoClass::Optional: {
            bool control = e.hasHTMLName(m_state.name(Name::input)) || e.hasHTMLName(m_state.name(Name::select)) || e.hasHTMLName(m_state.name(Name::textarea));
            if (!control) {
                return false;
            }
            bool required = e.hasAttributeAtom(m_ctx, m_state.name(Name::required));
            return s.pseudo == PseudoClass::Required ? required : !required;
        }
        case PseudoClass::ReadWrite:
            return this->readWrite(e);
        case PseudoClass::ReadOnly:
            return !this->readWrite(e);
        case PseudoClass::PlaceholderShown:
            return state.placeholderShown(m_ctx, e);
        case PseudoClass::Focus:
            return state.focused(m_ctx, e);
        case PseudoClass::FocusWithin:
            return state.focusWithin(m_ctx, e);
        case PseudoClass::FocusVisible:
            return state.focusVisible(m_ctx, e);
        case PseudoClass::Hover:
            return state.hovered(m_ctx, e);
        case PseudoClass::Active:
            return state.active(m_ctx, e);
        }
        return false;
    }

    JSContext* m_ctx;
    DOMState& m_state;
    Node* m_scope;
};

} // namespace

SelectorList parseSelectors(JSContext* ctx, const String& text) {
    // Over the length cap: refused on the length alone, before any conversion or allocation (css::componentValues).
    std::optional<css_token_vector> tokens = css::componentValues(ctx, text);
    if (!tokens) {
        syntaxError(text);
    }
    Parser parser(ctx);
    SelectorList list;
    if (!parser.list(trim(Tokens::of(*tokens)), false, 0, list) || list.empty()) {
        syntaxError(text);
    }
    return list;
}

bool matchesSelectors(JSContext* ctx, const SelectorList& list, Element& element, Node* scope) {
    Matcher matcher(ctx, scope);
    return matcher.any(list, element);
}

} // namespace wr
