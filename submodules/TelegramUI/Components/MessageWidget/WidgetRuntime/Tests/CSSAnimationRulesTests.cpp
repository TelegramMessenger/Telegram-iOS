// CSS animations' rules and declarations (V5f plan, Task 1): @keyframes from a sheet, and the animation and transition
// lists of an element's declarations, against the conformance set's own declarations (auto/10, visual/06).
#include <vector>
#include <algorithm>
#include <cstdio>
#include <map>
#include <string>

#include "Sources/Animation/CSSAnimationRules.h"
#include "Tests/HostHarness.h"

using namespace wr::animation;
using wr_test::HostEnv;

namespace {

/// A rule as `offset:easing{name=value;…}` per keyframe, joined by spaces (`-` for the animation's easing).
std::string describe(const CSSKeyframesRules& rules, const std::string& name) {
    auto it = rules.find(name);
    if (it == rules.end()) {
        return "(none)";
    }
    std::string out;
    for (const CSSKeyframe& frame : *it->second) {
        char offset[32];
        std::snprintf(offset, sizeof offset, "%g", frame.offset);
        out += (out.empty() ? "" : " ") + std::string(offset) + ":" + (frame.easing ? frame.easing->text() : "-") + "{";
        bool first = true;
        for (const auto& [property, value] : frame.values) {
            out += (first ? "" : ";") + std::string(*property) + "=" + std::string(*value);
            first = false;
        }
        out += "}";
    }
    return out;
}

DeclaredLookup lookup(std::map<std::string, std::string> values) {
    return [values = std::move(values)](std::string_view property) {
        auto it = values.find(std::string(property));
        return it == values.end() ? std::string() : it->second;
    };
}

std::string describe(const CSSAnimationSpec& s) {
    char buffer[256];
    std::snprintf(buffer, sizeof buffer, "%s %g %s %g %g %s %s %s", s.name.c_str(), s.durationMs, s.easing.c_str(), s.delayMs,
                  s.iterations, s.direction.c_str(), s.fill.c_str(), s.paused ? "paused" : "running");
    return buffer;
}

std::string describe(const CSSTransitionSpec& s) {
    char buffer[256];
    std::snprintf(buffer, sizeof buffer, "%s %g %s %g", s.property.c_str(), s.durationMs, s.easing.c_str(), s.delayMs);
    return buffer;
}

template <class Spec>
std::string describeAll(const std::vector<Spec>& specs) {
    std::string out;
    for (const Spec& s : specs) {
        out += (out.empty() ? "" : " | ") + describe(s);
    }
    return out;
}

void checkText(const std::string& got, const std::string& want) {
    if (got != want) {
        std::printf("    got  %s\n    want %s\n", got.c_str(), want.c_str());
    }
    CHECK(got == want);
}

} // namespace

WR_TEST(testKeyframesFromTheSheet) {
    HostEnv env;
    CSSKeyframesRules rules;
    parseKeyframesRules(env.ctx(),
                        "@keyframes slide{from{transform:translateX(0)}to{transform:translateX(40px)}}\n"
                        "@keyframes grow{from{width:10px}to{width:70px}}\n"
                        ".box { color: red }\n"
                        "@keyframes vpulse{0%,100%{transform:scale(1);opacity:1}50%{transform:scale(1.5);opacity:.4}}\n"
                        "@keyframes timed { 0% { opacity: 0; animation-timing-function: steps(2) } 100% { opacity: 1 } }\n"
                        "@keyframes 'quoted' { to { color: blue } }\n"
                        "@-webkit-keyframes legacy { to { left: 4px } }\n"
                        "@keyframes grow{to{height:3px}}\n"
                        "@media (min-width: 1px) { @keyframes inner { to { top: 1px } } }",
                        rules);
    checkText(describe(rules, "slide"), "0:-{transform=translateX(0)} 1:-{transform=translateX(40px)}");
    // A later rule of a name replaces the earlier one.
    checkText(describe(rules, "grow"), "1:-{height=3px}");
    // A keyframe list makes one keyframe per selector, sorted by offset.
    checkText(describe(rules, "vpulse"),
              "0:-{transform=scale(1);opacity=1} 0.5:-{transform=scale(1.5);opacity=.4} 1:-{transform=scale(1);opacity=1}");
    checkText(describe(rules, "timed"), "0:steps(2){opacity=0} 1:-{opacity=1}");
    checkText(describe(rules, "quoted"), "1:-{color=blue}");
    checkText(describe(rules, "legacy"), "1:-{left=4px}");
    checkText(describe(rules, "inner"), "1:-{top=1px}");
}

/// V4 plan, Task 3b (Review Focus 3): the sheet is read as litehtml parses it, through the profile's verdicts, so a
/// @keyframes inside an at-rule the profile drops (or a false @supports) is no rule, and a commented one never was.
/// Keyframes inside a kept @media apply whether it matches now or not (plan OP5).
WR_TEST(testKeyframesFollowTheKeptAtRules) {
    HostEnv env;
    CSSKeyframesRules rules;
    parseKeyframesRules(env.ctx(),
                        "@layer x{@keyframes a{from{opacity:0}}}\n"
                        "@media print{@keyframes b{from{opacity:0}}}\n"
                        "@supports (display:flow-root){@keyframes c{from{opacity:0}}}\n"
                        "@media (max-width:1px){@keyframes d{from{opacity:0}}}\n"
                        "@supports (display:flex){@keyframes e{from{opacity:0}}}\n"
                        "@keyframes f{from{opacity:0}}\n"
                        "/* @keyframes g{from{opacity:0}} */\n"
                        "@foo{@keyframes h{from{opacity:0}}}",
                        rules);
    std::vector<std::string> sorted;
    for (const auto& [name, frames] : rules) {
        sorted.emplace_back(name);
    }
    std::sort(sorted.begin(), sorted.end());
    std::string names;
    for (const std::string& name : sorted) {
        names += (names.empty() ? "" : ",") + name;
    }
    checkText(names, "d,e,f");
}

WR_TEST(testAnimationShorthands) {
    HostEnv env;
    auto specs = [&](std::string animation) {
        return describeAll(animationSpecs(env.ctx(), lookup({{"animation", animation}})));
    };
    checkText(specs("slide 10s linear -5s paused"), "slide 10000 linear -5000 1 normal none paused");
    checkText(specs("slide 10s linear -13s 2 alternate paused"), "slide 10000 linear -13000 2 alternate none paused");
    checkText(specs("grow 8s steps(4,end) -3s paused"), "grow 8000 steps(4,end) -3000 1 normal none paused");
    checkText(specs("slide .1s linear forwards"), "slide 100 linear 0 1 normal forwards running");
    checkText(specs("short .1s linear 3"), "short 100 linear 0 3 normal none running");
    checkText(specs("vspin 1s linear infinite"), "vspin 1000 linear 0 inf normal none running");
    checkText(specs("vslide 1.6s ease-in-out infinite alternate"), "vslide 1600 ease-in-out 0 inf alternate none running");
    checkText(specs("a 1s, b 200ms ease-out"), "a 1000 ease 0 1 normal none running | b 200 ease-out 0 1 normal none running");
    checkText(specs("none"), "");
}

WR_TEST(testLonghandsCycle) {
    HostEnv env;
    checkText(describeAll(animationSpecs(env.ctx(), lookup({{"animation-name", "a, b, c"}, {"animation-duration", "1s, 2s"}}))),
              "a 1000 ease 0 1 normal none running | b 2000 ease 0 1 normal none running | c 1000 ease 0 1 normal none running");
    checkText(describeAll(animationSpecs(env.ctx(), lookup({{"animation", "a 1s"}, {"animation-play-state", "paused"}}))),
              "a 1000 ease 0 1 normal none paused");
}

WR_TEST(testTransitionLists) {
    HostEnv env;
    auto specs = [&](std::map<std::string, std::string> declared) {
        return describeAll(transitionSpecs(env.ctx(), lookup(std::move(declared))));
    };
    checkText(specs({{"transition", "transform 10000s linear -5000s"}}), "transform 1e+07 linear -5e+06");
    checkText(specs({{"transition", "width 10000s linear -2500s"}}), "width 1e+07 linear -2.5e+06");
    checkText(specs({{"transition", "opacity .15s linear"}}), "opacity 150 linear 0");
    checkText(specs({{"transition", "all .3s"}}), "all 300 ease 0");
    checkText(specs({{"transition-property", "opacity, transform"}, {"transition-duration", "1s"}}),
              "opacity 1000 ease 0 | transform 1000 ease 0");
    // A 0s duration with a positive delay still makes a transition (its combined duration is positive).
    checkText(specs({{"transition", "opacity 0s 1s"}}), "opacity 0 ease 1000");
    checkText(specs({{"transition", "opacity 0s"}}), "");
    checkText(specs({{"transition", "none"}}), "");
}

WR_TEST(testTheCaps) {
    HostEnv env;
    std::string names;
    for (int i = 0; i < 10000; i++) {
        names += (i ? ", a" : "a") + std::to_string(i) + " 1s";
    }
    CHECK_EQ(animationSpecs(env.ctx(), lookup({{"animation", names}})).size(), kMaxCSSListEntries);
    std::string rule = "@keyframes big {";
    for (int i = 0; i <= 10000; i++) {
        rule += std::to_string(i / 100.0) + "%{opacity:1}";
    }
    rule += "}";
    CSSKeyframesRules rules;
    parseKeyframesRules(env.ctx(), rule, rules);
    CHECK(rules.count("big") && rules["big"]->size() == 10000);
}

WR_TEST(testTimes) {
    CHECK(parseTimeMs("1.5s") == 1500.0);
    CHECK(parseTimeMs("200MS") == 200.0);
    CHECK(parseTimeMs("-5s") == -5000.0);
    CHECK(!parseTimeMs("5"));
    CHECK(!parseTimeMs("s"));
}
