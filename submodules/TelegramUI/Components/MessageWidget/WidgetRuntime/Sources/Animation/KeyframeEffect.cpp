#include "Sources/Animation/KeyframeEffect.h"

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>

#include "Generated/Bindings.h"
#include "Sources/Animation/Animation.h"
#include "Sources/Animation/AnimationState.h"
#include "Sources/DOM/DOM.h"
#include "Sources/Host/Sequences.h"
#include "Sources/Runtime/Runtime.h"
#include "Sources/Support/Errors.h"

namespace wr {

using namespace animation;

namespace animation {

std::optional<std::string> keyframePropertyName(std::string_view key) {
    if (key.empty() || key.size() > kMaxPropertyKeyLength) {
        return std::nullopt;
    }
    auto isLetter = [](char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); };
    if (key.size() > 2 && key[0] == '-' && key[1] == '-') {
        for (char c : key.substr(2)) {
            if (!(isLetter(c) || (c >= '0' && c <= '9') || c == '_' || c == '-')) {
                return std::nullopt;
            }
        }
        return std::string(key);
    }
    if (!std::all_of(key.begin(), key.end(), isLetter)) {
        return std::nullopt;
    }
    if (key == "offset" || key == "easing" || key == "composite") {
        return std::nullopt;
    }
    std::string css;
    if (key == "cssFloat") {
        css = "float";
    } else if (key == "cssOffset") {
        css = "offset";
    } else {
        for (char c : key) {
            if (c >= 'A' && c <= 'Z') {
                css += '-';
                css += char(c - 'A' + 'a');
            } else {
                css += c;
            }
        }
        if (css.rfind("webkit-", 0) == 0 || css.rfind("moz-", 0) == 0 || css.rfind("ms-", 0) == 0) {
            css = "-" + css;
        }
    }
    std::string_view bare = css;
    if (bare.rfind("-webkit-", 0) == 0) {
        bare.remove_prefix(8);
    }
    for (std::string_view family : {"animation", "transition"}) {
        if (bare.rfind(family, 0) == 0 && (bare.size() == family.size() || bare[family.size()] == '-')) {
            return std::nullopt;
        }
    }
    if (css == "will-change" || css == "direction" || css == "unicode-bidi") {
        return std::nullopt;
    }
    return css;
}

std::string keyframePropertyKey(std::string_view css) {
    if (css.rfind("--", 0) == 0) {
        return std::string(css);
    }
    if (css == "float") {
        return "cssFloat";
    }
    if (css == "offset") {
        return "cssOffset";
    }
    std::string_view rest = css;
    if (!rest.empty() && rest[0] == '-') {
        rest.remove_prefix(1);
    }
    std::string key;
    bool upper = false;
    for (char c : rest) {
        if (c == '-') {
            upper = true;
        } else if (upper) {
            key += (c >= 'a' && c <= 'z') ? char(c - 'a' + 'A') : c;
            upper = false;
        } else {
            key += c;
        }
    }
    return key;
}

} // namespace animation

namespace {

std::string clipped(const std::string& text, size_t limit) { return text.size() <= limit ? text : text.substr(0, limit); }

Fill fillFrom(const String& text) {
    const std::string s = text.utf8Prefix(64, nullptr);
    if (s == "none") return Fill::None;
    if (s == "forwards") return Fill::Forwards;
    if (s == "backwards") return Fill::Backwards;
    if (s == "both") return Fill::Both;
    if (s == "auto" && text.length() == 4) return Fill::Auto;
    throw TypeError{"'" + s + "' is not a valid fill mode"};
}

Direction directionFrom(const String& text) {
    const std::string s = text.utf8Prefix(64, nullptr);
    if (s == "normal") return Direction::Normal;
    if (s == "reverse") return Direction::Reverse;
    if (s == "alternate") return Direction::Alternate;
    if (s == "alternate-reverse") return Direction::AlternateReverse;
    throw TypeError{"'" + s + "' is not a valid direction"};
}

std::optional<double> durationFrom(const std::variant<Unrestricted, String>& duration) {
    if (const String* text = std::get_if<String>(&duration)) {
        if (text->equalsASCII("auto")) {
            return std::nullopt;
        }
        throw TypeError{"'" + text->utf8Prefix(100, nullptr) + "' is not a valid duration"};
    }
    const double v = std::get<Unrestricted>(duration).value;
    if (std::isnan(v) || v < 0) {
        throw TypeError{"duration must be a non-negative number"};
    }
    return v;
}

double iterationsFrom(double v) {
    if (std::isnan(v) || v < 0) {
        throw TypeError{"iterations must be a non-negative number"};
    }
    return v;
}

double iterationStartFrom(double v) {
    if (!(v >= 0) || !std::isfinite(v)) {
        throw TypeError{"iterationStart must be a non-negative finite number"};
    }
    return v;
}

std::shared_ptr<const Easing> easingFrom(JSContext* ctx, const String& text) {
    if (text.length() <= kMaxEasingText) {
        if (std::shared_ptr<const Easing> easing = parseEasing(ctx, text.utf8())) {
            return easing;
        }
    }
    throw TypeError{"'" + text.utf8Prefix(100, nullptr) + "' is not a valid value for easing"};
}

std::optional<Composite> compositeFrom(std::string_view s, bool allowAuto) {
    if (s == "replace") return Composite::Replace;
    if (s == "add") return Composite::Add;
    if (s == "accumulate") return Composite::Accumulate;
    if (allowAuto && s == "auto") return std::nullopt;
    throw TypeError{"'" + std::string(s.substr(0, 100)) + "' is not a valid composite operation"};
}

const char* fillName(Fill f) {
    switch (f) {
    case Fill::None: return "none";
    case Fill::Forwards: return "forwards";
    case Fill::Backwards: return "backwards";
    case Fill::Both: return "both";
    case Fill::Auto: return "auto";
    }
    return "auto";
}

const char* directionName(Direction d) {
    switch (d) {
    case Direction::Normal: return "normal";
    case Direction::Reverse: return "reverse";
    case Direction::Alternate: return "alternate";
    case Direction::AlternateReverse: return "alternate-reverse";
    }
    return "normal";
}

const char* compositeName(Composite c) {
    switch (c) {
    case Composite::Replace: return "replace";
    case Composite::Add: return "add";
    case Composite::Accumulate: return "accumulate";
    }
    return "replace";
}

Value newObject(JSContext* ctx) {
    Value out = Value::adopt(ctx, JS_NewObject(ctx));
    if (JS_IsException(out.get())) {
        throw Thrown{};
    }
    return out;
}

/// An own data property (never a setter on Object.prototype).
void define(JSContext* ctx, JSValueConst object, const char* name, JSValue value) {
    if (JS_IsException(value) || JS_DefinePropertyValueStr(ctx, object, name, value, JS_PROP_C_W_E) < 0) {
        throw Thrown{};
    }
}

JSValue newText(JSContext* ctx, std::string_view text) { return JS_NewStringLen(ctx, text.data(), text.size()); }
JSValue nullable(JSContext* ctx, std::optional<double> v) { return v ? JS_NewFloat64(ctx, *v) : JS_NULL; }

EffectTiming timingFrom(JSContext* ctx, const std::variant<Unrestricted, idl::KeyframeEffectOptions>& options) {
    EffectTiming timing;
    if (const Unrestricted* duration = std::get_if<Unrestricted>(&options)) {
        timing.duration = durationFrom(*duration);
        return timing;
    }
    const idl::KeyframeEffectOptions& o = std::get<idl::KeyframeEffectOptions>(options);
    timing.delay = o.delay;
    timing.endDelay = o.endDelay;
    timing.fill = fillFrom(o.fill);
    timing.iterationStart = iterationStartFrom(o.iterationStart);
    timing.iterations = iterationsFrom(o.iterations.value);
    timing.duration = durationFrom(o.duration);
    timing.direction = directionFrom(o.direction);
    if (!o.easing.equalsASCII("linear")) {
        timing.easing = easingFrom(ctx, o.easing);
    }
    return timing;
}

// ── keyframe input (Level 1 §5.3.3 "process a keyframes argument") ──
//
// Every read that can run script (the iterator, the dictionary members, the property names and values, their
// conversion to strings) happens first, into JS-heap storage; only then is the copy validated and processed.

struct RawFrame {
    explicit RawFrame(JSRuntime* rt) : values(JSAllocator<std::pair<SharedText, SharedText>>(rt)) {}
    std::optional<double> offset;
    /// null: absent (linear).
    SharedText easing;
    /// null: absent (auto).
    SharedText composite;
    Vector<std::pair<SharedText, SharedText>> values;
};

Value getProperty(JSContext* ctx, JSValueConst object, const char* name) {
    Value v = Value::adopt(ctx, JS_GetPropertyStr(ctx, object, name));
    if (JS_IsException(v.get())) {
        throw Thrown{};
    }
    return v;
}

/// A property value as text (ToString), at most kMaxKeyframeValueLength UTF-16 units.
SharedText valueText(JSContext* ctx, JSValueConst v) {
    const String s = String::fromJS(ctx, v);
    if (s.length() > kMaxKeyframeValueLength) {
        throw TypeError{"keyframe value is too long"};
    }
    return makeSharedText(JS_GetRuntime(ctx), s.utf8());
}

/// An easing or composite member as text; an easing longer than any valid one is invalid at once.
SharedText memberText(JSContext* ctx, JSValueConst v, bool easing) {
    const String s = String::fromJS(ctx, v);
    if (easing && s.length() > kMaxEasingText) {
        throw TypeError{"'" + s.utf8Prefix(100, nullptr) + "' is not a valid value for easing"};
    }
    if (!easing && s.length() > 16) {
        throw TypeError{"'" + s.utf8Prefix(100, nullptr) + "' is not a valid composite operation"};
    }
    return makeSharedText(JS_GetRuntime(ctx), s.utf8());
}

std::optional<double> offsetFrom(JSContext* ctx, JSValueConst v) {
    if (JS_IsUndefined(v) || JS_IsNull(v)) {
        return std::nullopt;
    }
    double d;
    if (JS_ToFloat64(ctx, &d, v) < 0) {
        throw Thrown{};
    }
    if (!std::isfinite(d)) {
        throw TypeError{"keyframe offset must be a finite number"};
    }
    return d;
}

/// The object's own enumerable string keys that name an animatable property, sorted, as (key, CSS name); at most
/// kMaxKeyframeProperties.
std::vector<std::pair<std::string, std::string>> animatableKeys(JSContext* ctx, JSValueConst object) {
    JSPropertyEnum* names = nullptr;
    uint32_t count = 0;
    if (JS_GetOwnPropertyNames(ctx, &names, &count, object, JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) < 0) {
        throw Thrown{};
    }
    struct Free {
        JSContext* ctx;
        JSPropertyEnum* names;
        uint32_t count;
        ~Free() { JS_FreePropertyEnum(ctx, names, count); }
    } release{ctx, names, count};
    std::vector<std::pair<std::string, std::string>> keys;
    for (uint32_t i = 0; i < count; i++) {
        JSValue text = JS_AtomToString(ctx, names[i].atom);
        if (JS_IsException(text)) {
            throw Thrown{};
        }
        const String key = String::adopt(ctx, text);
        if (key.length() > kMaxPropertyKeyLength) {
            continue;
        }
        const std::string utf8 = key.utf8();
        if (std::optional<std::string> css = keyframePropertyName(utf8)) {
            keys.emplace_back(utf8, std::move(*css));
        }
    }
    std::sort(keys.begin(), keys.end());
    if (keys.size() > kMaxKeyframeProperties) {
        keys.resize(kMaxKeyframeProperties);
    }
    return keys;
}

/// A member of the property-indexed form that may be a list: its items, or one item.
std::vector<Value> listOrItem(JSContext* ctx, JSValueConst v, const char* what) {
    if (JS_IsUndefined(v)) {
        return {};
    }
    if (JS_IsObject(v)) {
        if (std::optional<std::vector<Value>> items = sequenceValues(ctx, v, what, kMaxKeyframeValues + 1)) {
            if (items->size() > kMaxKeyframeValues) {
                throw RangeError{"too many keyframe values"};
            }
            return std::move(*items);
        }
    }
    return {Value::dup(ctx, v)};
}

Vector<RawFrame> readListForm(JSContext* ctx, std::vector<Value> items) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    if (items.size() > kMaxKeyframes) {
        throw RangeError{"too many keyframes"};
    }
    Vector<RawFrame> frames{JSAllocator<RawFrame>(rt)};
    for (const Value& item : items) {
        RawFrame frame(rt);
        if (!JS_IsUndefined(item.get()) && !JS_IsNull(item.get())) {
            if (!JS_IsObject(item.get())) {
                throw TypeError{"keyframes must be objects"};
            }
            // BaseKeyframe's members, in WebIDL's order.
            const Value composite = getProperty(ctx, item.get(), "composite");
            if (!JS_IsUndefined(composite.get())) {
                frame.composite = memberText(ctx, composite.get(), false);
                compositeFrom(*frame.composite, true);
            }
            const Value easing = getProperty(ctx, item.get(), "easing");
            if (!JS_IsUndefined(easing.get())) {
                frame.easing = memberText(ctx, easing.get(), true);
            }
            frame.offset = offsetFrom(ctx, getProperty(ctx, item.get(), "offset").get());
            for (const auto& [key, css] : animatableKeys(ctx, item.get())) {
                const Value v = getProperty(ctx, item.get(), key.c_str());
                // A list value in a keyframe sequence is ignored, as browsers do (WPT
                // processing-a-keyframes-argument-001); the reference threw.
                if (JS_IsArray(v.get())) {
                    continue;
                }
                frame.values.emplace_back(makeSharedText(rt, css), valueText(ctx, v.get()));
            }
        }
        frames.push_back(std::move(frame));
    }
    return frames;
}

Vector<RawFrame> readIndexedForm(JSContext* ctx, JSValueConst object) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    // BasePropertyIndexedKeyframe's members, in WebIDL's order.
    std::vector<SharedText> composites;
    for (const Value& v : listOrItem(ctx, getProperty(ctx, object, "composite").get(), "composite")) {
        composites.push_back(memberText(ctx, v.get(), false));
        compositeFrom(*composites.back(), true);
    }
    std::vector<SharedText> easings;
    for (const Value& v : listOrItem(ctx, getProperty(ctx, object, "easing").get(), "easing")) {
        easings.push_back(memberText(ctx, v.get(), true));
    }
    std::vector<std::optional<double>> offsets;
    const Value offsetMember = getProperty(ctx, object, "offset");
    for (const Value& v : listOrItem(ctx, offsetMember.get(), "offset")) {
        offsets.push_back(offsetFrom(ctx, v.get()));
    }

    struct Entry {
        double offset;
        uint64_t order;
        SharedText css;
        SharedText value;
    };
    Vector<Entry> entries{JSAllocator<Entry>(rt)};
    uint64_t order = 0;
    for (const auto& [key, css] : animatableKeys(ctx, object)) {
        const Value v = getProperty(ctx, object, key.c_str());
        std::vector<Value> values = listOrItem(ctx, v.get(), "keyframe values");
        const SharedText name = makeSharedText(rt, css);
        const size_t n = values.size();
        for (size_t i = 0; i < n; i++) {
            entries.push_back(Entry{n == 1 ? 1.0 : double(i) / double(n - 1), order++, name, valueText(ctx, values[i].get())});
        }
    }
    // Frames with the same computed offset merge across properties, in property order (sorted in place: the entries
    // are script-made, so nothing beside them goes on the system heap).
    std::sort(entries.begin(), entries.end(), [](const Entry& a, const Entry& b) {
        return a.offset != b.offset ? a.offset < b.offset : a.order < b.order;
    });
    Vector<RawFrame> frames{JSAllocator<RawFrame>(rt)};
    for (size_t i = 0; i < entries.size();) {
        RawFrame frame(rt);
        const double offset = entries[i].offset;
        size_t j = i;
        for (; j < entries.size() && entries[j].offset == offset; j++) {
            frame.values.emplace_back(entries[j].css, entries[j].value);
        }
        frames.push_back(std::move(frame));
        i = j;
    }
    if (frames.empty() && (!composites.empty() || !easings.empty() || !offsets.empty())) {
        // Members without a property make one empty frame, as a list of one would.
        frames.push_back(RawFrame(rt));
    }
    for (size_t i = 0; i < frames.size() && i < offsets.size(); i++) {
        if (offsets[i]) {
            frames[i].offset = offsets[i];
        }
    }
    for (size_t i = 0; i < frames.size(); i++) {
        if (!easings.empty()) {
            frames[i].easing = easings[i % easings.size()];
        }
        if (!composites.empty()) {
            frames[i].composite = composites[i % composites.size()];
        }
    }
    return frames;
}

/// The keyframes `input` describes (null or undefined: none), validated: offsets in [0, 1] and loosely sorted, easings
/// and composites valid, computed offsets filled in.
Vector<Keyframe> processKeyframes(JSContext* ctx, JSValueConst input) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    Vector<RawFrame> raw{JSAllocator<RawFrame>(rt)};
    if (!JS_IsUndefined(input) && !JS_IsNull(input)) {
        if (!JS_IsObject(input)) {
            throw TypeError{"keyframes must be an object or an array"};
        }
        if (std::optional<std::vector<Value>> items = sequenceValues(ctx, input, "keyframes", kMaxKeyframes + 1)) {
            raw = readListForm(ctx, std::move(*items));
        } else {
            raw = readIndexedForm(ctx, input);
        }
    }
    Vector<Keyframe> frames{JSAllocator<Keyframe>(rt)};
    std::optional<double> previous;
    for (RawFrame& r : raw) {
        if (r.offset) {
            if (*r.offset < 0 || *r.offset > 1) {
                throw TypeError{"keyframe offsets must be between 0 and 1"};
            }
            if (previous && *r.offset < *previous) {
                throw TypeError{"keyframe offsets must be loosely sorted"};
            }
            previous = r.offset;
        }
        Keyframe frame(rt);
        frame.offset = r.offset;
        if (r.easing) {
            frame.easing = parseEasing(ctx, *r.easing);
            if (!frame.easing) {
                throw TypeError{"'" + clipped(std::string(r.easing->data(), r.easing->size()), 100) + "' is not a valid value for easing"};
            }
        }
        if (r.composite) {
            frame.composite = compositeFrom(*r.composite, true);
        }
        frame.values = std::move(r.values);
        frames.push_back(std::move(frame));
    }
    // Computed offsets: a lone frame at 1; else the first defaults to 0 and the last to 1, and the frames between two
    // known offsets are spread evenly.
    const size_t n = frames.size();
    for (Keyframe& f : frames) {
        f.computedOffset = f.offset.value_or(NAN);
    }
    if (n > 1 && !frames[0].offset) {
        frames[0].computedOffset = 0;
    }
    if (n > 0 && !frames[n - 1].offset) {
        frames[n - 1].computedOffset = 1;
    }
    for (size_t i = 0; i < n;) {
        if (!std::isnan(frames[i].computedOffset)) {
            i++;
            continue;
        }
        const size_t start = i - 1;
        size_t end = i;
        while (std::isnan(frames[end].computedOffset)) {
            end++;
        }
        const double from = frames[start].computedOffset, to = frames[end].computedOffset;
        for (size_t k = start + 1; k < end; k++) {
            frames[k].computedOffset = from + (to - from) * double(k - start) / double(end - start);
        }
        i = end;
    }
    return frames;
}

const char* const kPseudoElements[] = {"::before", "::after", "::marker", "::first-line", "::first-letter",
                                       "::placeholder", "::selection", "::backdrop"};

} // namespace

// ── AnimationEffect ──

void AnimationEffect::trace(JSRuntime* rt, JS_MarkFunc* mark) const { m_animationObject.mark(rt, mark); }

void AnimationEffect::dispose(JSRuntime* rt) {
    m_timing.easing.reset();
    // The animation may be gone already (a garbage cycle): only the reference is released.
    m_animation = nullptr;
    m_animationObject.clear(rt);
}

void AnimationEffect::setAnimation(JSContext* ctx, Animation* animation) {
    m_animationObject.set(JS_GetRuntime(ctx), animation ? animation->newRef(ctx) : JS_UNDEFINED);
    m_animation = animation;
}

std::optional<double> AnimationEffect::localTime() const { return m_animation ? m_animation->currentTime() : std::nullopt; }

bool AnimationEffect::playingForwards() const { return !m_animation || m_animation->playbackRate(nullptr) >= 0; }

Value AnimationEffect::getTiming(JSContext* ctx) {
    Value out = newObject(ctx);
    define(ctx, out.get(), "delay", JS_NewFloat64(ctx, m_timing.delay));
    define(ctx, out.get(), "direction", JS_NewString(ctx, directionName(m_timing.direction)));
    define(ctx, out.get(), "duration", m_timing.duration ? JS_NewFloat64(ctx, *m_timing.duration) : JS_NewString(ctx, "auto"));
    define(ctx, out.get(), "easing", newText(ctx, m_timing.easing ? std::string_view(m_timing.easing->canonical) : "linear"));
    define(ctx, out.get(), "endDelay", JS_NewFloat64(ctx, m_timing.endDelay));
    define(ctx, out.get(), "fill", JS_NewString(ctx, fillName(m_timing.fill)));
    define(ctx, out.get(), "iterationStart", JS_NewFloat64(ctx, m_timing.iterationStart));
    define(ctx, out.get(), "iterations", JS_NewFloat64(ctx, m_timing.iterations));
    return out;
}

Value AnimationEffect::getComputedTiming(JSContext* ctx) {
    const ComputedTiming computed = computeTiming(m_timing, localTime(), playingForwards());
    Value out = newObject(ctx);
    define(ctx, out.get(), "delay", JS_NewFloat64(ctx, m_timing.delay));
    define(ctx, out.get(), "direction", JS_NewString(ctx, directionName(m_timing.direction)));
    define(ctx, out.get(), "duration", JS_NewFloat64(ctx, iterationDuration(m_timing)));
    define(ctx, out.get(), "easing", newText(ctx, m_timing.easing ? std::string_view(m_timing.easing->canonical) : "linear"));
    define(ctx, out.get(), "endDelay", JS_NewFloat64(ctx, m_timing.endDelay));
    define(ctx, out.get(), "fill", JS_NewString(ctx, fillName(m_timing.fill == Fill::Auto ? Fill::None : m_timing.fill)));
    define(ctx, out.get(), "iterationStart", JS_NewFloat64(ctx, m_timing.iterationStart));
    define(ctx, out.get(), "iterations", JS_NewFloat64(ctx, m_timing.iterations));
    define(ctx, out.get(), "activeDuration", JS_NewFloat64(ctx, computed.activeDuration));
    define(ctx, out.get(), "currentIteration", nullable(ctx, computed.currentIteration));
    define(ctx, out.get(), "endTime", JS_NewFloat64(ctx, computed.endTime));
    define(ctx, out.get(), "localTime", nullable(ctx, computed.localTime));
    define(ctx, out.get(), "progress", nullable(ctx, computed.progress));
    return out;
}

void AnimationEffect::updateTiming(JSContext* ctx, const idl::OptionalEffectTiming& input) {
    EffectTiming timing = m_timing;
    if (input.delay) timing.delay = *input.delay;
    if (input.endDelay) timing.endDelay = *input.endDelay;
    if (input.fill) timing.fill = fillFrom(*input.fill);
    if (input.iterationStart) timing.iterationStart = iterationStartFrom(*input.iterationStart);
    if (input.iterations) timing.iterations = iterationsFrom(input.iterations->value);
    if (input.duration) timing.duration = durationFrom(*input.duration);
    if (input.direction) timing.direction = directionFrom(*input.direction);
    if (input.easing) timing.easing = input.easing->equalsASCII("linear") ? nullptr : easingFrom(ctx, *input.easing);
    m_timing = std::move(timing);
    if (m_animation) {
        m_animation->effectChanged(ctx);
    }
}

// ── KeyframeEffect ──

Ref<KeyframeEffect> KeyframeEffect::construct(JSContext* ctx, Value target, std::optional<Value> keyframes,
                                              std::variant<Unrestricted, idl::KeyframeEffectOptions> options) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    if (!keyframes) {
        if (KeyframeEffect* source = unwrap<KeyframeEffect>(ctx, target.get(), idl::kKeyframeEffect)) {
            Ref<KeyframeEffect> copy = create<KeyframeEffect>(ctx, idl::kKeyframeEffect, rt, source->m_timing);
            copy->m_keyframes = source->m_keyframes;
            copy->m_composite = source->m_composite;
            copy->m_accumulate = source->m_accumulate;
            copy->m_pseudoElement = source->m_pseudoElement;
            if (Element* element = source->targetElement()) {
                copy->m_target.set(rt, element->newRef(ctx));
            }
            return copy;
        }
    }
    const OrNull<Element> element = convert<OrNull<Element>>(ctx, target.get(), ArgInfo{"KeyframeEffect", "constructor", 0});
    if (!keyframes) {
        throw TypeError{"Failed to construct 'KeyframeEffect': 2 arguments required, but only 1 present."};
    }
    EffectTiming timing = timingFrom(ctx, options);
    std::optional<Composite> composite;
    bool accumulate = false;
    std::optional<String> pseudoElement;
    if (const idl::KeyframeEffectOptions* o = std::get_if<idl::KeyframeEffectOptions>(&options)) {
        composite = compositeFrom(o->composite.utf8Prefix(16, nullptr), false);
        accumulate = o->iterationComposite.equalsASCII("accumulate");
        pseudoElement = o->pseudoElement;
    }
    // `object?`: null and undefined are no keyframes; anything else that is not an object is a TypeError.
    if (!JS_IsUndefined(keyframes->get()) && !JS_IsNull(keyframes->get()) && !JS_IsObject(keyframes->get())) {
        throw TypeError{"keyframes must be an object or an array"};
    }
    Vector<Keyframe> frames = processKeyframes(ctx, keyframes->get());
    Ref<KeyframeEffect> effect = create<KeyframeEffect>(ctx, idl::kKeyframeEffect, rt, std::move(timing));
    effect->m_keyframes = std::move(frames);
    effect->m_composite = composite.value_or(Composite::Replace);
    effect->m_accumulate = accumulate;
    if (element.ptr) {
        effect->m_target.set(rt, element.ptr->newRef(ctx));
    }
    if (pseudoElement) {
        effect->setPseudoElement(ctx, std::move(pseudoElement));
    }
    return effect;
}

Ref<KeyframeEffect> KeyframeEffect::makeForCSS(JSContext* ctx, Element& target, Vector<Keyframe> frames, EffectTiming timing) {
    JSRuntime* rt = JS_GetRuntime(ctx);
    Ref<KeyframeEffect> effect = create<KeyframeEffect>(ctx, idl::kKeyframeEffect, rt, std::move(timing));
    effect->m_keyframes = std::move(frames);
    effect->m_target.set(rt, target.newRef(ctx));
    return effect;
}

void KeyframeEffect::setForCSS(JSContext* ctx, Vector<Keyframe> frames, EffectTiming timing) {
    m_keyframes = std::move(frames);
    m_timing = std::move(timing);
    this->changed(ctx);
}

void KeyframeEffect::trace(JSRuntime* rt, JS_MarkFunc* mark) const {
    m_target.mark(rt, mark);
    AnimationEffect::trace(rt, mark);
}

void KeyframeEffect::dispose(JSRuntime* rt) {
    m_target.clear(rt);
    m_keyframes.clear();
    m_keyframes.shrink_to_fit();
    m_pseudoElement.reset();
    AnimationEffect::dispose(rt);
}

Element* KeyframeEffect::targetElement() const {
    return JS_IsUndefined(m_target.value) ? nullptr : static_cast<Element*>(payloadOfKnown(m_target.value));
}

Element* KeyframeEffect::target(JSContext*) const { return targetElement(); }

void KeyframeEffect::setTarget(JSContext* ctx, OrNull<Element> target) {
    if (target.ptr == this->targetElement()) {
        return;
    }
    // The old target loses these values at the next flush.
    AnimationState::of(ctx).noteTarget(this->targetElement());
    m_target.set(JS_GetRuntime(ctx), target.ptr ? target.ptr->newRef(ctx) : JS_UNDEFINED);
    this->changed(ctx);
}

void KeyframeEffect::changed(JSContext* ctx) {
    AnimationState::of(ctx).noteTarget(this->targetElement());
    if (m_animation) {
        m_animation->effectChanged(ctx);
    }
}

std::optional<String> KeyframeEffect::pseudoElement(JSContext* ctx) const {
    if (!m_pseudoElement) {
        return std::nullopt;
    }
    return String::fromUTF8(ctx, *m_pseudoElement);
}

void KeyframeEffect::setPseudoElement(JSContext* ctx, std::optional<String> value) {
    if (!value) {
        m_pseudoElement.reset();
        this->changed(ctx);
        return;
    }
    std::string text = value->utf8Prefix(32, nullptr);
    for (char& c : text) {
        c = char(std::tolower(static_cast<unsigned char>(c)));
    }
    // The legacy one-colon forms of the CSS 2 pseudo-elements are pseudo-element selectors too.
    if (text == ":before" || text == ":after" || text == ":first-line" || text == ":first-letter") {
        text = ":" + text;
    }
    const bool valid = value->length() <= 32 &&
                       std::any_of(std::begin(kPseudoElements), std::end(kPseudoElements), [&](const char* p) { return text == p; });
    if (!valid) {
        throw DOMError{"SyntaxError", "'" + value->utf8Prefix(100, nullptr) + "' is not a valid pseudo-element selector"};
    }
    m_pseudoElement = makeSharedText(JS_GetRuntime(ctx), text);
    AnimationState::of(ctx).noteUnsupportedPseudoElement();
    this->changed(ctx);
}

String KeyframeEffect::composite(JSContext* ctx) const { return String::fromUTF8(ctx, compositeName(m_composite)); }

void KeyframeEffect::setComposite(JSContext* ctx, String composite) {
    m_composite = compositeFrom(composite.utf8Prefix(16, nullptr), false).value_or(Composite::Replace);
    this->changed(ctx);
}

String KeyframeEffect::iterationComposite(JSContext* ctx) const {
    return String::fromUTF8(ctx, m_accumulate ? "accumulate" : "replace");
}

void KeyframeEffect::setIterationComposite(JSContext* ctx, String iterationComposite) {
    m_accumulate = iterationComposite.equalsASCII("accumulate");
    this->changed(ctx);
}

std::vector<Object> KeyframeEffect::getKeyframes(JSContext* ctx) {
    std::vector<Object> out;
    out.reserve(m_keyframes.size());
    for (const Keyframe& frame : m_keyframes) {
        Value object = newObject(ctx);
        define(ctx, object.get(), "composite", JS_NewString(ctx, frame.composite ? compositeName(*frame.composite) : "auto"));
        define(ctx, object.get(), "computedOffset", JS_NewFloat64(ctx, frame.computedOffset));
        define(ctx, object.get(), "easing", newText(ctx, frame.easing ? std::string_view(frame.easing->canonical) : "linear"));
        define(ctx, object.get(), "offset", nullable(ctx, frame.offset));
        for (const auto& [css, value] : frame.values) {
            const std::string key = keyframePropertyKey(*css);
            define(ctx, object.get(), key.c_str(), newText(ctx, *value));
        }
        out.emplace_back(std::move(object));
    }
    return out;
}

void KeyframeEffect::setKeyframes(JSContext* ctx, std::optional<Object> keyframes) {
    m_keyframes = processKeyframes(ctx, keyframes ? keyframes->get() : JS_NULL);
    if (m_animation) {
        m_animation->effectChanged(ctx);
    }
}

} // namespace wr
