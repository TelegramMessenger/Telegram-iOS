#include "Sources/Animation/Interpolation.h"

#include <algorithm>
#include <cmath>
#include <set>
#include <utility>
#include <vector>

#include "Sources/Animation/CSSText.h"
#include "Sources/Animation/Easing.h"

namespace wr::animation {

namespace {

bool isDigit(char c) { return c >= '0' && c <= '9'; }
bool isLetter(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }

struct Token {
    bool number = false;
    double value = 0;
    /// The unit of a number, or the text between numbers.
    std::string text;
};

std::vector<Token> tokenize(std::string_view s) {
    std::vector<Token> tokens;
    std::string pending;
    auto flush = [&] {
        if (!pending.empty()) {
            tokens.push_back(Token{false, 0, std::move(pending)});
        }
        pending.clear();
    };
    size_t i = 0;
    const size_t n = s.size();
    while (i < n) {
        const char c = s[i];
        const bool starts = isDigit(c) || (c == '.' && i + 1 < n && isDigit(s[i + 1])) ||
                            ((c == '-' || c == '+') && i + 1 < n && (isDigit(s[i + 1]) || s[i + 1] == '.'));
        const char previous = i > 0 ? s[i - 1] : 0;
        const bool identPart = i > 0 && (isLetter(previous) || (previous == '-' && i > 1 && isLetter(s[i - 2])));
        if (starts && !(identPart && c != '-') && previous != '#') {
            size_t j = i + 1;
            while (j < n && (isDigit(s[j]) || s[j] == '.' || ((s[j] == 'e' || s[j] == 'E') && j + 1 < n && (isDigit(s[j + 1]) || s[j + 1] == '-')))) {
                if (s[j] == 'e' || s[j] == 'E') {
                    j++;
                }
                j++;
            }
            size_t k = j;
            while (k < n && (isLetter(s[k]) || s[k] == '%')) {
                k++;
            }
            if (auto v = parseNumber(s.substr(i, j - i))) {
                flush();
                tokens.push_back(Token{true, *v, std::string(s.substr(j, k - j))});
                i = k;
                continue;
            }
        }
        pending.push_back(c);
        i++;
    }
    flush();
    return tokens;
}

/// The functions of a transform list: (name lowercased, whole `name(args)` text).
std::vector<std::pair<std::string, std::string>> functions(std::string_view transform, std::string* restOut = nullptr) {
    std::vector<std::pair<std::string, std::string>> out;
    size_t pos = 0;
    for (;;) {
        const size_t paren = transform.find('(', pos);
        if (paren == std::string_view::npos) {
            break;
        }
        const size_t close = transform.find(')', paren);
        if (close == std::string_view::npos) {
            break;
        }
        out.emplace_back(lowered(trimmed(transform.substr(pos, paren - pos))), trimmed(transform.substr(pos, close + 1 - pos)));
        pos = close + 1;
    }
    if (restOut) {
        *restOut = std::string(transform.substr(pos));
    }
    return out;
}

std::vector<std::string> arguments(const std::string& fn) {
    const size_t paren = fn.find('('), close = fn.rfind(')');
    std::vector<std::string> out;
    if (paren == std::string::npos || close == std::string::npos || close < paren) {
        return out;
    }
    for (const std::string& a : splitTopLevel(std::string_view(fn).substr(paren + 1, close - paren - 1), ',')) {
        out.push_back(trimmed(a));
    }
    return out;
}

/// One-argument shorthands rewritten to their two-argument forms, so `translateX(4px)` pairs with `translate(0, 8px)`.
std::optional<std::string> primitive(std::string_view transform) {
    std::string rest;
    const auto list = functions(transform, &rest);
    if (list.empty() || !trimmed(rest).empty()) {
        return std::nullopt;
    }
    std::string out;
    for (const auto& [name, whole] : list) {
        const std::vector<std::string> args = arguments(whole);
        std::string item;
        if (args.size() == 1) {
            const std::string& a = args[0];
            if (name == "translatex" || name == "translate") {
                item = "translate(" + a + ", 0)";
            } else if (name == "translatey") {
                item = "translate(0, " + a + ")";
            } else if (name == "scalex") {
                item = "scale(" + a + ", 1)";
            } else if (name == "scaley") {
                item = "scale(1, " + a + ")";
            } else if (name == "scale") {
                item = "scale(" + a + ", " + a + ")";
            } else if (name == "skewx" || name == "skew") {
                item = "skew(" + a + ", 0)";
            } else if (name == "skewy") {
                item = "skew(0, " + a + ")";
            }
        }
        if (item.empty()) {
            item = name + "(";
            for (size_t i = 0; i < args.size(); i++) {
                item += (i ? ", " : "") + args[i];
            }
            item += ")";
        }
        if (!out.empty()) {
            out += ' ';
        }
        out += item;
    }
    return out;
}

/// The identity of each function in a transform or filter list: `rotate(30deg)` → `rotate(0deg)`.
std::string identity(std::string_view transform) {
    static const std::set<std::string> ones = {"scale", "scalex", "scaley", "scale3d", "brightness", "contrast", "opacity", "saturate"};
    const auto list = functions(transform);
    if (list.empty()) {
        return std::string(transform);
    }
    std::string out;
    for (const auto& [name, whole] : list) {
        const size_t paren = whole.find('('), close = whole.rfind(')');
        const std::string original = whole.substr(0, paren);
        const std::string inner = whole.substr(paren + 1, close - paren - 1);
        std::string args;
        bool first = true;
        for (const std::string& arg : splitTopLevel(inner, ',')) {
            size_t lead = 0;
            while (lead < arg.size() && (arg[lead] == ' ' || arg[lead] == '\t')) {
                lead++;
            }
            std::string value;
            if (ones.count(name)) {
                value = "1";
            } else {
                const std::string t = trimmed(arg);
                size_t u = 0;
                while (u < t.size() && (isDigit(t[u]) || t[u] == '.' || t[u] == '-' || t[u] == '+')) {
                    u++;
                }
                value = "0" + t.substr(u);
            }
            args += (first ? "" : ",") + arg.substr(0, lead) + value;
            first = false;
        }
        out += (out.empty() ? "" : " ") + original + "(" + args + ")";
    }
    return out;
}

/// A shorter transform list padded with the identities of the longer one's extra functions.
std::optional<std::pair<std::string, std::string>> padded(const std::string& a, const std::string& b) {
    const auto x = functions(a), y = functions(b);
    const bool aShort = x.size() < y.size();
    const auto& shorter = aShort ? x : y;
    const auto& longer = aShort ? y : x;
    if (shorter.empty() && longer.empty()) {
        return std::nullopt;
    }
    for (size_t i = 0; i < shorter.size(); i++) {
        if (shorter[i].first != longer[i].first) {
            return std::nullopt;
        }
    }
    std::string extra;
    for (size_t i = shorter.size(); i < longer.size(); i++) {
        extra += (extra.empty() ? "" : " ") + identity(longer[i].second);
    }
    if (aShort) {
        return std::make_pair(a + " " + extra, b);
    }
    return std::make_pair(a, b + " " + extra);
}

bool translationList(std::string_view text) {
    const std::string t = lowered(trimmed(text));
    std::string rest;
    const auto list = functions(t, &rest);
    if (list.empty() || !trimmed(rest).empty()) {
        return false;
    }
    for (const auto& [name, whole] : list) {
        if (name != "translate" && name != "translatex" && name != "translatey") {
            return false;
        }
        const size_t paren = whole.find('(');
        if (whole.find('(', paren + 1) != std::string::npos) {
            return false;
        }
    }
    return true;
}

std::string scaledTokens(std::string_view text, double factor) {
    std::string out;
    for (const Token& t : tokenize(text)) {
        out += t.number ? formatNumber(t.value * factor) + t.text : t.text;
    }
    return out;
}

std::optional<std::pair<std::vector<Token>, std::vector<Token>>> pairTokens(std::string_view a, std::string_view b) {
    std::string from = normalizeColors(a), to = normalizeColors(b);
    if (equalsIgnoringCase(from, "none") && to.find('(') != std::string::npos) {
        from = identity(to);
    } else if (equalsIgnoringCase(to, "none") && from.find('(') != std::string::npos) {
        to = identity(from);
    }
    std::vector<Token> left = tokenize(from), right = tokenize(to);
    if (left.size() != right.size()) {
        const std::optional<std::string> pa = primitive(from), pb = primitive(to);
        if (pa && pb) {
            left = tokenize(*pa);
            right = tokenize(*pb);
            if (left.size() != right.size()) {
                if (auto p = padded(*pa, *pb)) {
                    left = tokenize(p->first);
                    right = tokenize(p->second);
                }
            }
        }
    }
    if (left.size() != right.size()) {
        return std::nullopt;
    }
    return std::make_pair(std::move(left), std::move(right));
}

std::string mix(std::string_view a, std::string_view b, double t) {
    if (t == 0 || !std::isfinite(t)) {
        return std::string(a);
    }
    if (t == 1) {
        return std::string(b);
    }
    auto flip = [&] { return std::string(t < 0.5 ? a : b); };
    const auto pair = pairTokens(a, b);
    if (!pair) {
        return flip();
    }
    std::string out;
    const auto& [left, right] = *pair;
    for (size_t i = 0; i < left.size(); i++) {
        const Token &x = left[i], &y = right[i];
        if (x.number && y.number && (x.text == y.text || x.value == 0 || y.value == 0)) {
            out += formatNumber(x.value + (y.value - x.value) * t);
            out += x.text.empty() ? y.text : x.text;
        } else if (!x.number && !y.number && x.text == y.text) {
            out += x.text;
        } else {
            // Mixed units or different functions: two translation lists still compose by weight.
            if (translationList(a) && translationList(b)) {
                return scaledTokens(trimmed(a), 1 - t) + " " + scaledTokens(trimmed(b), t);
            }
            return flip();
        }
    }
    return out;
}

// ── Web Animations composite (add / accumulate) ──

std::vector<Token> webTokenize(std::string_view s) {
    std::vector<Token> tokens;
    std::string pending;
    size_t i = 0;
    const size_t n = s.size();
    while (i < n) {
        const char c = s[i];
        const char next = i + 1 < n ? s[i + 1] : 0;
        const char previous = i > 0 ? s[i - 1] : 0;
        const bool starts = isDigit(c) || (c == '.' && isDigit(next)) || ((c == '-' || c == '+') && (isDigit(next) || next == '.'));
        const bool inWord = i > 0 && (isLetter(previous) || previous == '#' || (previous == '-' && c != '-'));
        if (starts && !inWord) {
            size_t j = i + 1;
            while (j < n && (isDigit(s[j]) || s[j] == '.' || ((s[j] == 'e' || s[j] == 'E') && j + 1 < n && (isDigit(s[j + 1]) || s[j + 1] == '-')))) {
                j += (s[j] == 'e' || s[j] == 'E') ? 2 : 1;
            }
            size_t k = j;
            while (k < n && (isLetter(s[k]) || s[k] == '%')) {
                k++;
            }
            if (auto v = parseNumber(s.substr(i, j - i))) {
                if (!pending.empty()) {
                    tokens.push_back(Token{false, 0, std::move(pending)});
                }
                pending.clear();
                tokens.push_back(Token{true, *v, std::string(s.substr(j, k - j))});
                i = k;
                continue;
            }
        }
        pending.push_back(c);
        i++;
    }
    if (!pending.empty()) {
        tokens.push_back(Token{false, 0, std::move(pending)});
    }
    return tokens;
}

std::string webRender(const std::vector<Token>& tokens) {
    std::string out;
    for (const Token& t : tokens) {
        out += t.number ? formatNumber(t.value, 6) + t.text : t.text;
    }
    return out;
}

/// The function a text token opens: `"rotate("` → `rotate`, `") scale("` → `scale`.
std::optional<std::string> openedFunction(const std::string& text) {
    const size_t paren = text.rfind('(');
    if (paren == std::string::npos) {
        return std::nullopt;
    }
    const std::string before = text.substr(0, paren);
    const size_t start = before.find_last_of(" ,");
    return lowered(start == std::string::npos ? before : before.substr(start + 1));
}

bool unitScale(const std::string& fn) { return fn == "scale" || fn == "scalex" || fn == "scaley" || fn == "scale3d"; }

std::optional<std::string> webCombine(std::string_view a, std::string_view b, bool scaleAware) {
    const std::vector<Token> left = webTokenize(normalizeColors(a)), right = webTokenize(normalizeColors(b));
    if (left.size() != right.size()) {
        return std::nullopt;
    }
    std::vector<Token> out;
    std::string function;
    int colorChannel = -1;
    for (size_t i = 0; i < left.size(); i++) {
        const Token &x = left[i], &y = right[i];
        if (!x.number && !y.number && equalsIgnoringCase(x.text, y.text)) {
            out.push_back(x);
            if (auto fn = openedFunction(x.text)) {
                function = *fn;
                colorChannel = function == "rgba" ? 0 : -1;
            } else if (colorChannel >= 0) {
                colorChannel++;
            }
        } else if (x.number && y.number && (x.text == y.text || x.value == 0 || y.value == 0)) {
            double value = x.value + y.value;
            if (scaleAware && unitScale(function)) {
                value = x.value + y.value - 1;
            }
            if (colorChannel >= 0) {
                value = colorChannel < 3 ? std::clamp(value, 0.0, 255.0) : std::clamp(value, 0.0, 1.0);
            }
            out.push_back(Token{true, value, x.text.empty() ? y.text : x.text});
        } else {
            return std::nullopt;
        }
    }
    return webRender(out);
}

std::string add(std::string_view property, std::string_view underlying, std::string_view value, bool accumulate) {
    if (property == "transform") {
        const std::string u = trimmed(underlying), v = trimmed(value);
        if (u.empty() || equalsIgnoringCase(u, "none")) {
            return v;
        }
        if (v.empty() || equalsIgnoringCase(v, "none")) {
            return u;
        }
        if (accumulate) {
            if (auto c = webCombine(u, v, true)) {
                return *c;
            }
        }
        return u + " " + v;
    }
    if (auto c = webCombine(underlying, value, false)) {
        return *c;
    }
    return std::string(value);
}

std::string scaled(std::string_view value, double factor) {
    std::string function;
    std::vector<Token> tokens = webTokenize(normalizeColors(value));
    for (Token& t : tokens) {
        if (!t.number) {
            if (auto fn = openedFunction(t.text)) {
                function = *fn;
            }
        } else if (unitScale(function)) {
            t.value = (t.value - 1) * factor + 1;
        } else {
            t.value *= factor;
        }
    }
    return webRender(tokens);
}

} // namespace

std::string interpolate(JSContext* ctx, std::string_view a, std::string_view b, double t) {
    return mix(a, b, t);
}

std::string compositeValue(JSContext* ctx, std::string_view property, std::string_view underlying, std::string_view value, bool accumulate) {
    return add(property, underlying, value, accumulate);
}

std::string scaledValue(JSContext* ctx, std::string_view value, double factor) {
    return scaled(value, factor);
}

std::string effectValue(JSContext* ctx, std::span<const PropertyFrame> input, std::string_view property, double progress,
                        double iteration, Composite effectComposite, bool accumulateIterations, std::string_view underlying) {
    if (input.empty()) {
        return std::string(underlying);
    }
    struct Frame {
        double offset;
        std::optional<std::string_view> value;
        const Easing* easing;
        Composite composite;
    };
    std::vector<Frame> frames;
    frames.reserve(input.size() + 2);
    for (const PropertyFrame& f : input) {
        frames.push_back({f.offset, f.value, f.easing, f.composite.value_or(effectComposite)});
    }
    if (std::none_of(frames.begin(), frames.end(), [](const Frame& f) { return f.offset == 0; })) {
        frames.insert(frames.begin(), Frame{0, std::nullopt, nullptr, Composite::Replace});
    }
    if (std::none_of(frames.begin(), frames.end(), [](const Frame& f) { return f.offset == 1; })) {
        frames.push_back(Frame{1, std::nullopt, nullptr, Composite::Replace});
    }
    std::optional<std::string_view> last;
    for (auto it = frames.rbegin(); it != frames.rend(); ++it) {
        if (it->offset == 1) {
            last = it->value;
            break;
        }
    }
    auto resolve = [&](size_t index) -> std::string {
        const Frame& frame = frames[index];
        if (!frame.value) {
            return std::string(underlying);
        }
        std::string value(*frame.value);
        if (accumulateIterations && iteration > 0 && std::isfinite(iteration) && last) {
            value = add(property, scaled(*last, iteration), value, true);
        }
        if (frame.composite == Composite::Add) {
            return add(property, underlying, value, false);
        }
        if (frame.composite == Composite::Accumulate) {
            return add(property, underlying, value, true);
        }
        return value;
    };
    std::vector<size_t> zeros, ones;
    for (size_t i = 0; i < frames.size(); i++) {
        if (frames[i].offset == 0) {
            zeros.push_back(i);
        }
        if (frames[i].offset == 1) {
            ones.push_back(i);
        }
    }
    if (progress < 0 && zeros.size() > 1) {
        return resolve(zeros.front());
    }
    if (progress >= 1 && ones.size() > 1) {
        return resolve(ones.back());
    }
    size_t start = 0;
    if (progress < 0) {
        start = 0;
    } else if (progress >= 1) {
        start = frames.size() - 2;
    } else {
        for (size_t i = 0; i < frames.size(); i++) {
            if (frames[i].offset <= progress && frames[i].offset < 1) {
                start = i;
            }
        }
    }
    const size_t end = std::min(start + 1, frames.size() - 1);
    if (start == end) {
        return resolve(start);
    }
    const Frame &fa = frames[start], &fb = frames[end];
    const double span = fb.offset - fa.offset;
    const double local = span == 0 ? 0 : (progress - fa.offset) / span;
    const double eased = fa.easing ? fa.easing->web(local, false) : local;
    return mix(resolve(start), resolve(end), eased);
}

} // namespace wr::animation
