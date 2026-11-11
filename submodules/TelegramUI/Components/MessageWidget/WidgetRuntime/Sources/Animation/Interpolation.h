// Value interpolation and the keyframe-effect sampler (V5e plan, Task 1), ported from twidget's `interpolate`,
// `web_add`, `web_scaled` and `web_value` (PROVENANCE.md). Values are CSS text; what these make is dropped within the
// call that asked, so it lives on the system heap.
#pragma once

#include <cstdint>
#include <optional>
#include <span>
#include <string>
#include <string_view>

#include "quickjs.h"

namespace wr::animation {

struct Easing;

enum class Composite : uint8_t { Replace, Add, Accumulate };

/// One keyframe as the sampler sees it for one property.
struct PropertyFrame {
    double offset;
    /// The easing to the next frame; null is linear.
    const Easing* easing;
    /// nullopt: the effect's composite operation.
    std::optional<Composite> composite;
    /// nullopt: the underlying value (an implicit frame).
    std::optional<std::string_view> value;
};

/// `a` at 0, `b` at 1: colours as rgba(), `none` transforms as their identities, one-argument transform forms as two,
/// a shorter transform list padded with the identities of the longer one's extra functions; numbers mix when their
/// units match or one is 0, two translation lists compose by weight, anything else flips at 0.5. An endpoint, and a
/// non-finite `t`, returns the value as given.
std::string interpolate(JSContext* ctx, std::string_view a, std::string_view b, double t);
/// `value` composited onto `underlying` (Web Animations' add, or accumulate): a transform list appends (accumulate
/// combines one of the same shape), anything else adds number by number (colour channels clamped), else `value`.
std::string compositeValue(JSContext* ctx, std::string_view property, std::string_view underlying, std::string_view value, bool accumulate);
/// Every number in `value` times `factor`; a scale() argument as (v - 1) x factor + 1.
std::string scaledValue(JSContext* ctx, std::string_view value, double factor);
/// The value of one property of a keyframe effect at `iterationProgress` (Web Animations §5.3.4): `frames` are the
/// effect's frames that set the property, by offset; implicit frames at 0 and 1 take `underlying`; the interval is
/// the last frame with `offset <= progress && offset < 1` and the next, eased with `before = false`.
/// `accumulateIterations`: iterationComposite accumulate, building on `currentIteration` times the last frame.
/// No frames: `underlying`.
std::string effectValue(JSContext* ctx, std::span<const PropertyFrame> frames, std::string_view property, double iterationProgress,
                        double currentIteration, Composite effectComposite, bool accumulateIterations, std::string_view underlying);

} // namespace wr::animation
