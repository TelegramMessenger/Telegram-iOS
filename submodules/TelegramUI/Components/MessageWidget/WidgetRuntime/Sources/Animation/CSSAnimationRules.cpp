#include "Sources/Animation/CSSAnimationRules.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <limits>

#include "Sources/Animation/CSSText.h"
#include "Sources/Animation/KeyframeEffect.h"
#include "Sources/Support/Work.h"

namespace wr::animation {

namespace {

bool endsWithIgnoringCase(std::string_view text, std::string_view suffix) {
    return text.size() >= suffix.size() && equalsIgnoringCase(text.substr(text.size() - suffix.size()), suffix);
}

/// A CSS property name as a keyframe may declare it: a custom property, or an ASCII identifier of letters, digits and
/// hyphens (twidget's is_property_name).
bool isPropertyName(std::string_view name) {
    if (name.size() > kMaxPropertyKeyLength || name.empty()) {
        return false;
    }
    if (name.size() > 2 && name[0] == '-' && name[1] == '-') {
        return std::none_of(name.begin(), name.end(), [](char c) { return std::isspace(static_cast<unsigned char>(c)); });
    }
    const unsigned char first = static_cast<unsigned char>(name[0]);
    if (!std::isalpha(first) && first != '-') {
        return false;
    }
    return std::all_of(name.begin(), name.end(), [](char c) {
        return std::isalnum(static_cast<unsigned char>(c)) || c == '-';
    });
}

/// A declaration block's declarations (twidget's parse_declarations): names lowercased except custom properties, a
/// trailing `!important` dropped, a later declaration of a name replacing the earlier one at the end.
std::vector<std::pair<std::string, std::string>> declarations(std::string_view text) {
    std::vector<std::pair<std::string, std::string>> out;
    for (const std::string& part : splitTopLevel(text, ';')) {
        const size_t colon = part.find(':');
        if (colon == std::string::npos) {
            continue;
        }
        std::string name = trimmed(std::string_view(part).substr(0, colon));
        std::string value = trimmed(std::string_view(part).substr(colon + 1));
        if (name.empty() || value.empty()) {
            continue;
        }
        if (endsWithIgnoringCase(value, "!important")) {
            value = trimmed(std::string_view(value).substr(0, value.size() - 10));
        }
        if (name.compare(0, 2, "--") != 0) {
            name = lowered(name);
        }
        if (!isPropertyName(name)) {
            continue;
        }
        out.erase(std::remove_if(out.begin(), out.end(), [&](const auto& d) { return d.first == name; }), out.end());
        out.emplace_back(std::move(name), std::move(value));
    }
    return out;
}

/// The items of a comma-separated list, trimmed, at most kMaxCSSListEntries.
std::vector<std::string> listItems(const std::string& text) {
    std::vector<std::string> items;
    if (text.empty()) {
        return items;
    }
    for (const std::string& item : splitTopLevel(text, ',')) {
        if (items.size() == kMaxCSSListEntries) {
            break;
        }
        items.push_back(trimmed(item));
    }
    return items;
}

/// The whitespace-separated tokens of a list item, outside parentheses and quotes.
std::vector<std::string> tokens(const std::string& item) {
    std::vector<std::string> out;
    std::string normalised = item;
    for (char& c : normalised) {
        if (c == '\t' || c == '\n' || c == '\r' || c == '\f') {
            c = ' ';
        }
    }
    for (std::string& token : splitTopLevel(normalised, ' ')) {
        if (!token.empty()) {
            out.push_back(std::move(token));
        }
    }
    return out;
}

bool isEasing(JSContext* ctx, std::string_view text) { return parseEasing(ctx, text) != nullptr; }

} // namespace

namespace {

/// Whether a `background` value is one colour and nothing else: one top-level token (a function's arguments aside),
/// not an image, a gradient, a variable or a keyword that is no colour.
bool isPlainColour(std::string_view value) {
    while (!value.empty() && std::isspace(static_cast<unsigned char>(value.front()))) {
        value.remove_prefix(1);
    }
    while (!value.empty() && std::isspace(static_cast<unsigned char>(value.back()))) {
        value.remove_suffix(1);
    }
    if (value.empty()) {
        return false;
    }
    std::string lower(value);
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    if (lower.find("url(") != std::string::npos || lower.find("gradient(") != std::string::npos ||
        lower.find("var(") != std::string::npos || lower.find("image") != std::string::npos) {
        return false;
    }
    for (std::string_view keyword : {"none", "inherit", "initial", "unset", "revert", "revert-layer"}) {
        if (lower == keyword) {
            return false;
        }
    }
    int depth = 0;
    for (char c : lower) {
        if (c == '(') {
            depth++;
        } else if (c == ')') {
            depth--;
        } else if (depth == 0 && (std::isspace(static_cast<unsigned char>(c)) || c == ',' || c == '/')) {
            return false;
        }
    }
    return true;
}

} // namespace

std::string watchedValue(const DeclaredLookup& declared, std::string_view property) {
    if (property == "background-color") {
        std::string value = declared("background-color");
        if (value.empty()) {
            std::string shorthand = declared("background");
            if (isPlainColour(shorthand)) {
                return shorthand;
            }
        }
        return value;
    }
    std::string value = declared(property);
    if (property == "background" && isPlainColour(value)) {
        return {};
    }
    return value;
}

bool transitionCovers(std::string_view entry, std::string_view property) {
    return entry == property || entry == "all" || (entry == "background" && property == "background-color");
}

std::optional<double> parseTimeMs(std::string_view raw) {
    const std::string text = lowered(trimmed(raw));
    if (text.size() > 2 && endsWithIgnoringCase(text, "ms")) {
        return parseNumber(std::string_view(text).substr(0, text.size() - 2));
    }
    if (text.size() > 1 && text.back() == 's') {
        if (std::optional<double> seconds = parseNumber(std::string_view(text).substr(0, text.size() - 1))) {
            return *seconds * 1000;
        }
    }
    return std::nullopt;
}

void parseKeyframesRules(JSContext* ctx, std::string_view sheet, CSSKeyframesRules& into) {
    charge(ctx, uint64_t(sheet.size()) * work::kCssByte);
    JSRuntime* rt = JS_GetRuntime(ctx);
    constexpr std::string_view kKeyword = "keyframes";
    size_t pos = 0;
    for (;;) {
        size_t at = std::string_view::npos;
        for (size_t i = pos; i + kKeyword.size() <= sheet.size(); i++) {
            if (equalsIgnoringCase(sheet.substr(i, kKeyword.size()), kKeyword)) {
                at = i;
                break;
            }
        }
        if (at == std::string_view::npos) {
            return;
        }
        const std::string_view before = sheet.substr(0, at);
        const size_t open = sheet.find('{', at + kKeyword.size());
        const bool rule = (before.size() >= 1 && before.back() == '@') || endsWithIgnoringCase(before, "@-webkit-");
        if (!rule || open == std::string_view::npos) {
            pos = at + kKeyword.size();
            continue;
        }
        std::string name = trimmed(sheet.substr(at + kKeyword.size(), open - at - kKeyword.size()));
        while (!name.empty() && (name.front() == '"' || name.front() == '\'')) {
            name.erase(name.begin());
        }
        while (!name.empty() && (name.back() == '"' || name.back() == '\'')) {
            name.pop_back();
        }
        int depth = 0;
        size_t close = std::string_view::npos;
        for (size_t i = open; i < sheet.size(); i++) {
            if (sheet[i] == '{') {
                depth++;
            } else if (sheet[i] == '}' && --depth == 0) {
                close = i;
                break;
            }
        }
        if (close == std::string_view::npos) {
            return;
        }
        const std::string_view body = sheet.substr(open + 1, close - open - 1);
        auto frames = std::allocate_shared<CSSKeyframesRule>(JSAllocator<CSSKeyframesRule>(rt), JSAllocator<CSSKeyframe>(rt));
        size_t p = 0;
        for (;;) {
            const size_t frameOpen = body.find('{', p);
            if (frameOpen == std::string_view::npos) {
                break;
            }
            const size_t frameClose = body.find('}', frameOpen);
            if (frameClose == std::string_view::npos) {
                break;
            }
            CSSKeyframe frame(rt);
            for (auto& [property, value] : declarations(body.substr(frameOpen + 1, frameClose - frameOpen - 1))) {
                if (property == "animation-timing-function") {
                    frame.easing = parseEasing(ctx, value);
                } else if (value.size() <= kMaxKeyframeValueLength && frame.values.size() < kMaxKeyframeProperties) {
                    frame.values.emplace_back(makeSharedText(rt, property), makeSharedText(rt, value));
                }
            }
            for (const std::string& raw : splitTopLevel(body.substr(p, frameOpen - p), ',')) {
                const std::string selector = lowered(trimmed(raw));
                std::optional<double> offset;
                if (selector == "from") {
                    offset = 0;
                } else if (selector == "to") {
                    offset = 1;
                } else if (selector.size() > 1 && selector.back() == '%') {
                    if (std::optional<double> percent = parseNumber(std::string_view(selector).substr(0, selector.size() - 1))) {
                        offset = *percent / 100;
                    }
                }
                // A selector outside 0%…100% is invalid (CSS Animations 1 §3).
                if (offset && *offset >= 0 && *offset <= 1 && frames->size() < kMaxKeyframes) {
                    CSSKeyframe copy(rt);
                    copy.offset = *offset;
                    copy.easing = frame.easing;
                    copy.values = frame.values;
                    frames->push_back(std::move(copy));
                }
            }
            p = frameClose + 1;
        }
        std::stable_sort(frames->begin(), frames->end(), [](const CSSKeyframe& a, const CSSKeyframe& b) { return a.offset < b.offset; });
        into[name] = std::move(frames);
        pos = close + 1;
    }
}

Vector<Keyframe> keyframesFor(JSContext* ctx, const CSSKeyframesRule& rule, const std::shared_ptr<const Easing>& animationEasing) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    Vector<Keyframe> frames{JSAllocator<Keyframe>(rt)};
    frames.reserve(rule.size());
    for (const CSSKeyframe& source : rule) {
        charge(ctx, uint64_t(source.values.size() + 1) * work::kNodeVisit);
        Keyframe frame(rt);
        frame.offset = source.offset;
        frame.computedOffset = source.offset;
        frame.easing = source.easing ? source.easing : animationEasing;
        frame.values = source.values;
        frames.push_back(std::move(frame));
    }
    return frames;
}

EffectTiming animationTiming(const CSSAnimationSpec& spec) {
    EffectTiming timing;
    timing.delay = spec.delayMs;
    timing.duration = std::max(spec.durationMs, 0.0);
    timing.iterations = spec.iterations >= 0 ? spec.iterations : 1;
    if (spec.direction == "reverse") {
        timing.direction = Direction::Reverse;
    } else if (spec.direction == "alternate") {
        timing.direction = Direction::Alternate;
    } else if (spec.direction == "alternate-reverse") {
        timing.direction = Direction::AlternateReverse;
    }
    if (spec.fill == "forwards") {
        timing.fill = Fill::Forwards;
    } else if (spec.fill == "backwards") {
        timing.fill = Fill::Backwards;
    } else if (spec.fill == "both") {
        timing.fill = Fill::Both;
    } else {
        timing.fill = Fill::None;
    }
    return timing;
}

std::shared_ptr<const Easing> specEasing(JSContext* ctx, std::string_view text) {
    if (std::shared_ptr<const Easing> easing = parseEasing(ctx, text)) {
        return easing;
    }
    return parseEasing(ctx, "ease");
}

std::vector<CSSAnimationSpec> animationSpecs(JSContext* ctx, const DeclaredLookup& declared) {
    std::vector<CSSAnimationSpec> specs;
    const std::string shorthand = declared("animation");
    chargeScan(ctx, shorthand.size());
    for (const std::string& item : listItems(shorthand)) {
        CSSAnimationSpec spec;
        spec.name = "none";
        bool sawDuration = false;
        for (const std::string& token : tokens(item)) {
            const std::string t = lowered(token);
            if (std::optional<double> time = parseTimeMs(t)) {
                if (sawDuration) {
                    spec.delayMs = *time;
                } else {
                    spec.durationMs = *time;
                    sawDuration = true;
                }
            } else if (isEasing(ctx, t)) {
                spec.easing = t;
            } else if (t == "infinite") {
                spec.iterations = std::numeric_limits<double>::infinity();
            } else if (std::optional<double> n = parseNumber(t)) {
                spec.iterations = *n;
            } else if (t == "normal" || t == "reverse" || t == "alternate" || t == "alternate-reverse") {
                spec.direction = t;
            } else if (t == "forwards" || t == "backwards" || t == "both") {
                spec.fill = t;
            } else if (t == "paused" || t == "running") {
                spec.paused = t == "paused";
            } else {
                spec.name = token;
            }
        }
        specs.push_back(std::move(spec));
    }
    auto longhand = [&](const char* property, auto apply) {
        const std::string text = declared(property);
        chargeScan(ctx, text.size());
        const std::vector<std::string> items = listItems(text);
        if (items.empty()) {
            return;
        }
        if (specs.empty()) {
            specs.resize(items.size());
            for (CSSAnimationSpec& s : specs) {
                s.name = "none";
            }
        }
        for (size_t i = 0; i < specs.size(); i++) {
            apply(specs[i], items[i % items.size()]);
        }
    };
    longhand("animation-name", [](CSSAnimationSpec& s, const std::string& v) { s.name = v; });
    longhand("animation-duration", [](CSSAnimationSpec& s, const std::string& v) { s.durationMs = parseTimeMs(v).value_or(0); });
    longhand("animation-timing-function", [](CSSAnimationSpec& s, const std::string& v) { s.easing = lowered(v); });
    longhand("animation-delay", [](CSSAnimationSpec& s, const std::string& v) { s.delayMs = parseTimeMs(v).value_or(0); });
    longhand("animation-iteration-count", [](CSSAnimationSpec& s, const std::string& v) {
        s.iterations = equalsIgnoringCase(v, "infinite") ? std::numeric_limits<double>::infinity() : parseNumber(v).value_or(1);
    });
    longhand("animation-direction", [](CSSAnimationSpec& s, const std::string& v) { s.direction = lowered(v); });
    longhand("animation-fill-mode", [](CSSAnimationSpec& s, const std::string& v) { s.fill = lowered(v); });
    longhand("animation-play-state", [](CSSAnimationSpec& s, const std::string& v) { s.paused = equalsIgnoringCase(v, "paused"); });
    specs.erase(std::remove_if(specs.begin(), specs.end(),
                               [](const CSSAnimationSpec& s) { return s.name.empty() || equalsIgnoringCase(s.name, "none"); }),
                specs.end());
    return specs;
}

std::vector<CSSTransitionSpec> transitionSpecs(JSContext* ctx, const DeclaredLookup& declared) {
    std::vector<CSSTransitionSpec> specs;
    const std::string shorthand = declared("transition");
    chargeScan(ctx, shorthand.size());
    for (const std::string& item : listItems(shorthand)) {
        CSSTransitionSpec spec;
        spec.property = "all";
        bool sawDuration = false;
        for (const std::string& token : tokens(item)) {
            if (std::optional<double> time = parseTimeMs(token)) {
                if (sawDuration) {
                    spec.delayMs = *time;
                } else {
                    spec.durationMs = *time;
                    sawDuration = true;
                }
            } else if (isEasing(ctx, lowered(token))) {
                spec.easing = lowered(token);
            } else {
                spec.property = lowered(token);
            }
        }
        specs.push_back(std::move(spec));
    }
    auto items = [&](const char* property) {
        const std::string text = declared(property);
        chargeScan(ctx, text.size());
        return listItems(text);
    };
    const std::vector<std::string> properties = items("transition-property");
    const std::vector<std::string> durations = items("transition-duration");
    if (!properties.empty()) {
        const std::vector<std::string> easings = items("transition-timing-function");
        const std::vector<std::string> delays = items("transition-delay");
        std::vector<CSSTransitionSpec> next;
        for (size_t i = 0; i < properties.size(); i++) {
            CSSTransitionSpec base = i < specs.size() ? specs[i] : CSSTransitionSpec{properties[i], 0, "ease", 0};
            CSSTransitionSpec s;
            s.property = lowered(properties[i]);
            s.durationMs = durations.empty() ? base.durationMs : parseTimeMs(durations[i % durations.size()]).value_or(0);
            s.easing = easings.empty() ? base.easing : lowered(easings[i % easings.size()]);
            s.delayMs = delays.empty() ? base.delayMs : parseTimeMs(delays[i % delays.size()]).value_or(0);
            next.push_back(std::move(s));
        }
        specs = std::move(next);
    } else if (!durations.empty()) {
        for (size_t i = 0; i < specs.size(); i++) {
            specs[i].durationMs = parseTimeMs(durations[i % durations.size()]).value_or(0);
        }
    }
    // CSS Transitions 1: a transition starts only when its combined duration is positive.
    specs.erase(std::remove_if(specs.begin(), specs.end(),
                               [](const CSSTransitionSpec& s) {
                                   return std::max(s.durationMs, 0.0) + s.delayMs <= 0 || s.property == "none";
                               }),
                specs.end());
    return specs;
}

} // namespace wr::animation
