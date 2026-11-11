// Value interpolation and the keyframe-effect sampler (V5e plan, Task 1; twidget's `interpolate`, `web_add`,
// `web_scaled` and `web_value`): numbers and lengths, colours, transforms, discrete values, add and accumulate, and the
// interval a progress falls in, with implicit frames that take the underlying value.
#include <cstdio>
#include <optional>
#include <string>
#include <vector>

#include "Sources/Animation/Easing.h"
#include "Sources/Animation/Interpolation.h"
#include "Tests/HostHarness.h"

using namespace wr::animation;
using wr_test::HostEnv;

namespace {

void checkMix(HostEnv& env, std::string_view a, std::string_view b, double t, std::string_view want) {
    const std::string got = interpolate(env.ctx(), a, b, t);
    if (got != want) {
        std::printf("  interpolate('%.*s', '%.*s', %g) → '%s', want '%.*s'\n", int(a.size()), a.data(), int(b.size()),
                    b.data(), t, got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

void checkSame(std::string_view what, const std::string& got, std::string_view want) {
    if (got != want) {
        std::printf("  %.*s → '%s', want '%.*s'\n", int(what.size()), what.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

} // namespace

WR_TEST(testNumbersAndLengths) {
    HostEnv env;
    checkMix(env, "0px", "40px", 0.5, "20px");
    checkMix(env, "0", "40px", 0.25, "10px");
    checkMix(env, "1", "0.5", 0.5, "0.75");
    checkMix(env, "10px", "2em", 0.4, "10px");
    checkMix(env, "10px", "2em", 0.5, "2em");
}

WR_TEST(testColours) {
    HostEnv env;
    checkMix(env, "rgb(0, 0, 0)", "#c86432", 0.5, "rgba(100, 50, 25, 1)");
    checkMix(env, "hsl(120, 100%, 50%)", "rgb(0, 0, 0)", 0.2, "rgba(0, 204, 0, 1)");
    checkMix(env, "red", "blue", 0, "red");
    checkMix(env, "rgb(0 0 0 / 50%)", "rgba(0, 0, 0, 1)", 0.5, "rgba(0, 0, 0, 0.75)");
}

WR_TEST(testTransforms) {
    HostEnv env;
    checkMix(env, "none", "translateX(40px)", 0.5, "translateX(20px)");
    checkMix(env, "translateX(10px)", "translate(30px, 10px)", 0.5, "translate(20px, 5px)");
    // scale(2) becomes scale(2, 2) before the shorter list is padded with its identity.
    checkMix(env, "rotate(0deg)", "rotate(90deg) scale(2)", 0.5, "rotate(45deg) scale(1.5, 1.5)");
    checkMix(env, "matrix(1, 0, 0, 1, 0, 0)", "rotate(90deg)", 0.4, "matrix(1, 0, 0, 1, 0, 0)");
}

WR_TEST(testDiscrete) {
    HostEnv env;
    checkMix(env, "block", "none", 0.49, "block");
    checkMix(env, "block", "none", 0.5, "none");
}

WR_TEST(testComposite) {
    HostEnv env;
    checkSame("add transforms", compositeValue(env.ctx(), "transform", "translateX(10px)", "rotate(10deg)", false),
              "translateX(10px) rotate(10deg)");
    checkSame("accumulate opacity", compositeValue(env.ctx(), "opacity", "0.25", "0.5", true), "0.75");
    checkSame("add colours", compositeValue(env.ctx(), "color", "rgb(250, 0, 0)", "rgb(10, 0, 0)", false),
              "rgba(255, 0, 0, 1)");
    checkSame("scaled", scaledValue(env.ctx(), "translateX(10px) scale(2)", 3), "translateX(30px) scale(4)");
}

WR_TEST(testEffectValue) {
    HostEnv env;
    JSContext* ctx = env.ctx();
    auto linear = parseEasing(ctx, "linear");
    CHECK(linear != nullptr);
    if (!linear) {
        return;
    }
    const Easing* l = linear.get();

    std::vector<PropertyFrame> slide = {{0, l, std::nullopt, "translateX(0px)"}, {1, l, std::nullopt, "translateX(40px)"}};
    checkSame("slide at 0.5", effectValue(ctx, slide, "transform", 0.5, 0, Composite::Replace, false, "none"), "translateX(20px)");

    // One frame at offset 1: the implicit frame at 0 takes the underlying value.
    std::vector<PropertyFrame> fade = {{1, l, std::nullopt, "0"}};
    checkSame("fade at 0.5", effectValue(ctx, fade, "opacity", 0.5, 0, Composite::Replace, false, "1"), "0.5");

    std::vector<PropertyFrame> blink = {
        {0, l, std::nullopt, "#3a3"}, {0.25, l, std::nullopt, "#c33"}, {1, l, std::nullopt, "#3a3"}};
    checkSame("offsets at 0.25", effectValue(ctx, blink, "background", 0.25, 0, Composite::Replace, false, ""), "#c33");
    checkSame("offsets at 0.625", effectValue(ctx, blink, "background", 0.625, 0, Composite::Replace, false, ""),
              "rgba(127.5, 110.5, 51, 1)");

    // A frame's own `add` stacks on the underlying value.
    std::vector<PropertyFrame> added = {{0, l, Composite::Add, "0"}, {1, l, Composite::Add, "0.5"}};
    checkSame("add at 0.5", effectValue(ctx, added, "opacity", 0.5, 0, Composite::Replace, false, "0.25"), "0.5");

    // iterationComposite accumulate: iteration 2 starts from twice the last frame's value.
    std::vector<PropertyFrame> step = {{0, l, std::nullopt, "translateX(0px)"}, {1, l, std::nullopt, "translateX(10px)"}};
    checkSame("accumulated at 0.5", effectValue(ctx, step, "transform", 0.5, 2, Composite::Replace, true, "none"),
              "translateX(25px)");
}
