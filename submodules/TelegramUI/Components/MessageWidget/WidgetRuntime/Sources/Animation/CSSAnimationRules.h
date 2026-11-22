// CSS animations' and transitions' rules and declarations (V5f plan, Task 1): `@keyframes` from a style sheet's text, and
// the `animation-*` / `transition-*` declarations of an element as lists of specs. Ported from twidget (PROVENANCE.md).
#pragma once

#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

#include "quickjs.h"
#include "Sources/Animation/Easing.h"
#include "Sources/Animation/KeyframeEffect.h"
#include "Sources/Animation/Timing.h"
#include "Sources/Support/Allocator.h"

namespace wr::animation {

/// At most this many entries of an `animation` or `transition` list are read.
inline constexpr size_t kMaxCSSListEntries = 64;

/// The properties a transition can watch: the animatable ones whose declarations litehtml keeps (style.cpp's
/// raw_declaration_names holds them, and others no transition watches: the animation and transition properties
/// themselves, the discrete `pointer-events`, and the copies getComputedStyle reads, twidget edits 30.1, 45 and 51).
/// A transition on any other property never starts (V5f Ruling).
inline constexpr std::string_view kWatchedProperties[] = {
    "transform", "opacity", "color", "background-color", "background", "width", "height", "top", "left", "right",
    "bottom", "box-shadow", "border-color", "max-height", "stroke-dashoffset", "fill", "stroke", "translate", "scale",
    "rotate", "filter", "letter-spacing", "font-size", "margin-top", "margin-left", "flex-grow", "transform-origin",
    "backdrop-filter",
};

/// One keyframe of an `@keyframes` rule. Its text lives in the JS heap.
struct CSSKeyframe {
    explicit CSSKeyframe(JSRuntime* rt) : values(JSAllocator<std::pair<SharedText, SharedText>>(rt)) {}
    double offset = 0;
    /// The keyframe's own `animation-timing-function`; null: the animation's.
    std::shared_ptr<const Easing> easing;
    /// (CSS name, value as written), in declaration order, a later declaration of a name replacing an earlier one.
    Vector<std::pair<SharedText, SharedText>> values;
};

/// The keyframes of one rule, sorted by offset (stable).
using CSSKeyframesRule = Vector<CSSKeyframe>;
/// Rules by name; a later rule of a name replaces an earlier one.
using CSSKeyframesRules = std::unordered_map<std::string, std::shared_ptr<const CSSKeyframesRule>>;

/// Adds every `@keyframes` (and `@-webkit-keyframes`) rule of `sheet` to `into`.
/// The V5e keyframe caps apply: 10,000 keyframes, 512 properties per keyframe, 4,096-byte values (longer ones dropped).
void parseKeyframesRules(JSContext* ctx, std::string_view sheet, CSSKeyframesRules& into);

/// A declared value by CSS property name; empty when nothing declares it.
using DeclaredLookup = std::function<std::string(std::string_view property)>;

/// One entry of an element's `animation` list.
struct CSSAnimationSpec {
    std::string name;
    double durationMs = 0;
    /// `animation-timing-function` as written; an invalid one is `ease`.
    std::string easing = "ease";
    double delayMs = 0;
    double iterations = 1;
    std::string direction = "normal";
    std::string fill = "none";
    bool paused = false;
    bool operator==(const CSSAnimationSpec&) const = default;
};

/// The element's animations: the `animation` shorthand's entries, then each longhand's list over them (cycling, and
/// making the entries when there is no shorthand); entries named `none` or nothing dropped; at most kMaxCSSListEntries.
std::vector<CSSAnimationSpec> animationSpecs(JSContext* ctx, const DeclaredLookup& declared);

/// One entry of an element's `transition` list.
struct CSSTransitionSpec {
    /// A property name, lowercase, or `all`.
    std::string property;
    double durationMs = 0;
    std::string easing = "ease";
    double delayMs = 0;
    bool operator==(const CSSTransitionSpec&) const = default;
};

/// The element's transitions, the shorthand's entries with the longhands over them; an entry whose combined duration
/// (max(duration, 0) + delay) is not positive, or whose property is `none`, dropped; at most kMaxCSSListEntries.
std::vector<CSSTransitionSpec> transitionSpecs(JSContext* ctx, const DeclaredLookup& declared);

/// The keyframes an animation of `rule` runs (V5f plan, Task 4): each keyframe's own easing, else `animationEasing`
/// (CSS Animations 2: animation-timing-function applies between keyframes).
Vector<Keyframe> keyframesFor(JSContext* ctx, const CSSKeyframesRule& rule, const std::shared_ptr<const Easing>& animationEasing);
/// A CSS animation's effect timing: its delay, duration (never negative), iteration count (a negative one is 1),
/// direction and fill, and a linear easing (the timing function is the keyframes').
EffectTiming animationTiming(const CSSAnimationSpec& spec);
/// `spec.easing`, or `ease` when it is not an easing.
std::shared_ptr<const Easing> specEasing(JSContext* ctx, std::string_view text);

/// The value a transition watches for `property` (one of kWatchedProperties): its declaration, except that a
/// `background` shorthand holding nothing but a colour is `background-color`'s (a browser expands it to that longhand)
/// and not `background`'s.
std::string watchedValue(const DeclaredLookup& declared, std::string_view property);
/// Whether a `transition` entry naming `entry` covers the watched `property`: the same name, `all`, or `background`
/// for `background-color`.
bool transitionCovers(std::string_view entry, std::string_view property);

/// A CSS `<time>` (`s` or `ms`, any case) in milliseconds.
std::optional<double> parseTimeMs(std::string_view text);

} // namespace wr::animation
