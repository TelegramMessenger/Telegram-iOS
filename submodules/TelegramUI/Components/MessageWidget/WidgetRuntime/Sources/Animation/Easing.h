// Easing functions (V5e plan, Task 1; CSS Easing 1 and 2): the reference's grammar and canonical text, and twidget's
// evaluation, ported (PROVENANCE.md). An Easing is immutable and lives in the JS heap: keyframes and effects share it.
#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <string_view>
#include <utility>

#include "quickjs.h"
#include "Sources/Support/Allocator.h"

namespace wr::animation {

/// At most this many characters of easing text are parsed; a longer text is invalid.
inline constexpr size_t kMaxEasingText = 4096;

struct Easing {
    enum class Kind : uint8_t { Linear, Bezier, Steps, Points };
    /// A steps() position: start and jump-start are both Start (the canonical text keeps which was written).
    enum class Jump : uint8_t { End, Start, Both, None };

    explicit Easing(JSRuntime* rt) : points(JSAllocator<std::pair<double, double>>(rt)), canonical(JSAllocator<char>(rt)) {}

    Kind kind = Kind::Linear;
    Jump jump = Jump::End;
    double x1 = 0, y1 = 0, x2 = 1, y2 = 1;
    int steps = 1;
    /// linear(): (input, output), inputs non-decreasing, at least two.
    Vector<std::pair<double, double>> points;
    /// What getTiming().easing and getKeyframes() read back.
    JSText canonical;

    /// CSS animations' form (Kind::Steps clamped to [0, 1], a bézier clamped at its ends); kept for V5f.
    double css(double x) const;
    /// Web Animations' form (§4.11): the before flag decides a step at a jump, a bézier outside [0, 1] continues along
    /// its end tangents.
    double web(double x, bool before) const;
    std::string text() const { return std::string(canonical); }
};

/// `text` as an easing function, or null when it is not one. The result is made in the JS heap (a bad_alloc at the
/// memory limit propagates).
std::shared_ptr<const Easing> parseEasing(JSContext* ctx, std::string_view text);
/// `linear`.
std::shared_ptr<const Easing> linearEasing(JSContext* ctx);

} // namespace wr::animation
