// AnimationEffect and KeyframeEffect (V5e plan, Task 2; Web Animations Level 1 §4.8–4.11 and §5, Level 2's time
// members and iterationComposite), with the reference's keyframe limits and property-name rules.
#pragma once

#include <cstddef>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <utility>
#include <variant>
#include <vector>

#include "Sources/Animation/Easing.h"
#include "Sources/Animation/Interpolation.h"
#include "Sources/Animation/Timing.h"
#include "Sources/Support/Allocator.h"
#include "Sources/Support/Bindings.h"

namespace wr {

class Animation;
class Element;

namespace idl {
struct KeyframeEffectOptions;
struct OptionalEffectTiming;
} // namespace idl

namespace animation {

/// The reference's limits (widget-sandbox v0.1.0, `processKeyframes`).
inline constexpr size_t kMaxKeyframes = 10000;
inline constexpr size_t kMaxKeyframeValues = 10000;
inline constexpr size_t kMaxKeyframeProperties = 512;
inline constexpr size_t kMaxKeyframeValueLength = 4096;
inline constexpr size_t kMaxPropertyKeyLength = 128;

/// The CSS name a keyframe property key animates (Global Constraints: `--custom` verbatim, camelCase letters
/// hyphenated, `cssFloat` → `float`, `webkitX` → `-webkit-x`), or nullopt when the key is not one an effect animates.
std::optional<std::string> keyframePropertyName(std::string_view key);
/// The key getKeyframes() writes for a CSS name: keyframePropertyName's inverse.
std::string keyframePropertyKey(std::string_view cssName);

/// One keyframe: what getKeyframes() reads back and the sampler interpolates. Its text lives in the JS heap.
struct Keyframe {
    explicit Keyframe(JSRuntime* rt) : values(JSAllocator<std::pair<SharedText, SharedText>>(rt)) {}
    std::optional<double> offset;
    double computedOffset = 0;
    /// null: linear.
    std::shared_ptr<const Easing> easing;
    /// nullopt: auto (the effect's).
    std::optional<Composite> composite;
    /// (CSS name, value as given), in key order.
    Vector<std::pair<SharedText, SharedText>> values;
};

} // namespace animation

class AnimationEffect : public PlatformObject {
public:
    explicit AnimationEffect(animation::EffectTiming timing) : m_timing(std::move(timing)) {}
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

    /// The timing as specified: `duration` "auto" kept, `easing` as its canonical text.
    Value getTiming(JSContext* ctx);
    /// getTiming's members ("auto" duration as 0, "auto" fill as "none") and the computed ones at the animation's
    /// current time (null members without an animation).
    Value getComputedTiming(JSContext* ctx);
    /// Merges the given members; a member that does not convert leaves the timing as it was.
    void updateTiming(JSContext* ctx, const idl::OptionalEffectTiming& timing);

    const animation::EffectTiming& timing() const { return m_timing; }
    /// The animation the effect is associated with. Held (traced, like the animation's hold on the effect), so a script
    /// that keeps the effect and drops the animation never leaves this dangling.
    Animation* animation() const { return m_animation; }
    void setAnimation(JSContext* ctx, Animation* animation);

protected:
    /// The effect's local time: its animation's current time, nullopt without one.
    std::optional<double> localTime() const;
    /// The animation plays forwards (its playback rate is not negative), or there is none.
    bool playingForwards() const;

    animation::EffectTiming m_timing;
    Held m_animationObject;
    Animation* m_animation = nullptr;
};

class KeyframeEffect final : public AnimationEffect {
public:
    KeyframeEffect(JSRuntime* rt, animation::EffectTiming timing) : AnimationEffect(std::move(timing)), m_keyframes(JSAllocator<animation::Keyframe>(rt)) {}
    /// `new KeyframeEffect(target, keyframes, options)`, or `new KeyframeEffect(source)` when `target` is a
    /// KeyframeEffect and `keyframes` is absent (Level 1's two constructors, resolved here: the generator has no
    /// overloads).
    static Ref<KeyframeEffect> construct(JSContext* ctx, Value target, std::optional<Value> keyframes,
                                         std::variant<Unrestricted, idl::KeyframeEffectOptions> options);
    void trace(JSRuntime* rt, JS_MarkFunc* mark) const override;
    void dispose(JSRuntime* rt) override;

    Element* target(JSContext* ctx) const;
    void setTarget(JSContext* ctx, OrNull<Element> target);
    std::optional<String> pseudoElement(JSContext* ctx) const;
    void setPseudoElement(JSContext* ctx, std::optional<String> pseudoElement);
    String composite(JSContext* ctx) const;
    void setComposite(JSContext* ctx, String composite);
    String iterationComposite(JSContext* ctx) const;
    void setIterationComposite(JSContext* ctx, String iterationComposite);
    std::vector<Object> getKeyframes(JSContext* ctx);
    void setKeyframes(JSContext* ctx, std::optional<Object> keyframes);

    /// A CSS animation's or transition's effect (V5f plan, Tasks 4 and 5): `frames` and `timing` as the style-change
    /// step made them, on `target`.
    static Ref<KeyframeEffect> makeForCSS(JSContext* ctx, Element& target, Vector<animation::Keyframe> frames, animation::EffectTiming timing);
    /// The style changed them: the target is sampled again and the animation updated.
    void setForCSS(JSContext* ctx, Vector<animation::Keyframe> frames, animation::EffectTiming timing);

    Element* targetElement() const;
    const Vector<animation::Keyframe>& keyframes() const { return m_keyframes; }
    animation::Composite compositeOperation() const { return m_composite; }
    bool accumulatesIterations() const { return m_accumulate; }
    /// A pseudo-element target, which renders nothing (Global Constraints).
    bool targetsPseudoElement() const { return m_pseudoElement != nullptr; }
    /// The pseudo-element as stored (`::before`), empty for the element itself; valid while the effect keeps it.
    std::string_view pseudoElementText() const { return m_pseudoElement ? std::string_view(*m_pseudoElement) : std::string_view(); }

private:
    /// What the effect renders changed: its target is sampled again at the next flush and its animation updated.
    void changed(JSContext* ctx);

    Held m_target;
    Vector<animation::Keyframe> m_keyframes;
    animation::Composite m_composite = animation::Composite::Replace;
    bool m_accumulate = false;
    SharedText m_pseudoElement;
};

} // namespace wr
