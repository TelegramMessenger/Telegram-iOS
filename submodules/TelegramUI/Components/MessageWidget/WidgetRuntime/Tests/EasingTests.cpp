// Easing functions (V5e plan, Task 1; CSS Easing 1 and 2, Web Animations §4.11): the reference's grammar, its canonical
// text, and twidget's evaluation (`web` with the before flag, `css` for CSS animations).
#include <cmath>
#include <cstdio>
#include <string>

#include "Sources/Animation/Easing.h"
#include "Tests/HostHarness.h"

using wr::animation::Easing;
using wr::animation::parseEasing;
using wr_test::HostEnv;

namespace {

bool near(double a, double b, double tolerance = 1e-4) {
    if (std::fabs(a - b) < tolerance) {
        return true;
    }
    std::printf("  got %.9g, want %.9g\n", a, b);
    return false;
}

std::string textOf(HostEnv& env, std::string_view input) {
    auto easing = parseEasing(env.ctx(), input);
    return easing ? easing->text() : std::string("<invalid>");
}

void checkText(HostEnv& env, std::string_view input, std::string_view want) {
    const std::string got = textOf(env, input);
    if (got != want) {
        std::printf("  '%.*s' → '%s', want '%.*s'\n", int(input.size()), input.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

} // namespace

WR_TEST(testKeywordsAndBeziers) {
    HostEnv env;
    auto easeIn = parseEasing(env.ctx(), "ease-in");
    auto ease = parseEasing(env.ctx(), "ease");
    auto linear = parseEasing(env.ctx(), "linear");
    auto custom = parseEasing(env.ctx(), "cubic-bezier(0.25, 0.1, 0.25, 1)");
    auto overshoot = parseEasing(env.ctx(), "cubic-bezier(0.5, -1, 0.5, 2)");
    CHECK(easeIn && ease && linear && custom && overshoot);
    if (!easeIn || !ease || !linear || !custom || !overshoot) {
        return;
    }
    CHECK(near(easeIn->web(0.5, false), 0.3153568));
    CHECK(near(ease->web(0.25, false), 0.4085106));
    CHECK(near(linear->web(0.37, false), 0.37));
    for (double x : {0.1, 0.5, 0.9}) {
        CHECK(near(custom->web(x, false), ease->web(x, false), 1e-9));
    }
    // Outside [0, 1] a bézier continues along its end tangents: slope y1/x1 = -2 below, (y2-1)/(x2-1) = -2 above.
    CHECK(near(overshoot->web(-0.5, false), 1.0));
    CHECK(near(overshoot->web(1.5, false), 0.0));
    CHECK(near(easeIn->css(0.5), 0.3153568));
}

WR_TEST(testSteps) {
    HostEnv env;
    auto twoEnd = parseEasing(env.ctx(), "steps(2, end)");
    auto fourEnd = parseEasing(env.ctx(), "steps(4, end)");
    auto start = parseEasing(env.ctx(), "step-start");
    auto none = parseEasing(env.ctx(), "steps(2, jump-none)");
    auto both = parseEasing(env.ctx(), "steps(3, jump-both)");
    CHECK(twoEnd && fourEnd && start && none && both);
    if (!twoEnd || !fourEnd || !start || !none || !both) {
        return;
    }
    CHECK(near(twoEnd->web(0.6, false), 0.5));
    CHECK(near(fourEnd->web(0.375, false), 0.25));
    CHECK(near(start->web(0, false), 1));
    CHECK(near(start->web(0, true), 0));
    CHECK(near(none->web(0.5, false), 1));
    CHECK(near(both->web(0.5, false), 0.5));
}

WR_TEST(testLinearFunction) {
    HostEnv env;
    auto f = parseEasing(env.ctx(), "linear(0, 0.25 75%, 1)");
    CHECK(f != nullptr);
    if (!f) {
        return;
    }
    CHECK(near(f->web(0.75, false), 0.25));
    CHECK(near(f->web(0.375, false), 0.125));
    CHECK(near(f->web(1, false), 1));
    // Below the first input the first segment extrapolates.
    CHECK(near(f->web(-0.75, false), -0.25));
    // Inputs are made monotonic: 50% after 80% is read as 80%, so 0.9 is between (80%, 0.7) and (100%, 1).
    auto g = parseEasing(env.ctx(), "linear(0, 0.5 80%, 0.7 50%, 1)");
    CHECK(g != nullptr);
    if (g) {
        CHECK(near(g->web(0.9, false), 0.85));
    }
}

WR_TEST(testCanonicalText) {
    HostEnv env;
    checkText(env, "step-start", "steps(1, start)");
    checkText(env, "step-end", "steps(1)");
    checkText(env, "steps(4, end)", "steps(4)");
    checkText(env, "steps(4, jump-end)", "steps(4)");
    checkText(env, "steps(4, start)", "steps(4, start)");
    checkText(env, "steps(3, jump-both)", "steps(3, jump-both)");
    checkText(env, " EASE-IN ", "ease-in");
    checkText(env, "cubic-bezier(.25,.1,.25,1)", "cubic-bezier(0.25, 0.1, 0.25, 1)");
    checkText(env, "cubic-bezier(0, -1.5, 1, 1e1)", "cubic-bezier(0, -1.5, 1, 10)");
    checkText(env, "linear(0, 1)", "linear(0 0%, 1 100%)");
    checkText(env, "linear(0, 0.25 75%, 1)", "linear(0 0%, 0.25 75%, 1 100%)");
    checkText(env, "linear", "linear");
}

WR_TEST(testRejected) {
    HostEnv env;
    for (std::string_view bad : {"cubic-bezier(1.1, 0, 0, 1)", "cubic-bezier(-0.1, 0, 0, 1)", "cubic-bezier(0, 0, 1)",
                                 "cubic-bezier(0px, 0, 1, 1)", "steps(0)", "steps(100001)", "steps(1, jump-none)",
                                 "steps(2.5)", "steps(2, middle)", "steps(2, end, end)", "linear(0)", "linear(0, 0.5 50)",
                                 "bogus", "ease(", "", "null"}) {
        if (parseEasing(env.ctx(), bad)) {
            std::printf("  accepted '%.*s'\n", int(bad.size()), bad.data());
            CHECK(false);
        }
    }
    const std::string tooLong = "linear(" + std::string(4090, ' ') + "0, 1)";
    CHECK(tooLong.size() > 4096);
    CHECK(parseEasing(env.ctx(), tooLong) == nullptr);
    std::string items = "linear(0";
    for (int i = 0; i < 256; i++) {
        items += ", 1";
    }
    items += ")";
    CHECK(parseEasing(env.ctx(), items) == nullptr);  // 257 items
}
