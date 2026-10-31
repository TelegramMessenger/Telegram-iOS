// AnimationEffect and KeyframeEffect (V5e plan, Task 2; Web Animations Level 1 §4.8–4.11 and §5, Level 2's time
// members): timing input and its read-back, the timing model, keyframe processing in both forms, the property-name
// rules, the reference's limits, and script running while keyframes are read.
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <string>

#include "Sources/Animation/Easing.h"
#include "Sources/Animation/Timing.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"

using namespace wr::animation;
using wr_test::HostEnv;

namespace {

const char* const kErr =
    "window.err = f => { try { f(); return 'ok' } catch (e) { return (e instanceof DOMException ? 'DOMException:' : '') + e.name } }; 1";

void checkEval(HostEnv& env, std::string_view code, std::string_view want) {
    const std::string got = env.eval(code);
    if (got != want) {
        std::printf("  %.*s\n    → %s\n    want %.*s\n", int(code.size()), code.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

bool near(std::optional<double> a, double b) {
    if (a && std::fabs(*a - b) < 1e-9) {
        return true;
    }
    std::printf("  got %s, want %g\n", a ? std::to_string(*a).c_str() : "nullopt", b);
    return false;
}

} // namespace

WR_TEST(testTimingDefaults) {
    HostEnv env;
    checkEval(env, "JSON.stringify(new KeyframeEffect(null, null).getTiming())",
              "{\"delay\":0,\"direction\":\"normal\",\"duration\":\"auto\",\"easing\":\"linear\",\"endDelay\":0,"
              "\"fill\":\"auto\",\"iterationStart\":0,\"iterations\":1}");
    checkEval(env, "new KeyframeEffect(null, null, 500).getTiming().duration", "500");
    checkEval(env, "new KeyframeEffect(null, null, {duration: 200, easing: 'step-start', fill: 'both'}).getTiming().easing",
              "steps(1, start)");
    checkEval(env, "typeof AnimationEffect + ' ' + (new KeyframeEffect(null, null) instanceof AnimationEffect)", "function true");
}

WR_TEST(testComputedTimingWithoutAnAnimation) {
    HostEnv env;
    checkEval(env,
              "const t = new KeyframeEffect(null, null, {duration: 200, delay: 10, endDelay: 5}).getComputedTiming();"
              " JSON.stringify([t.activeDuration, t.endTime, t.localTime, t.progress, t.currentIteration, t.duration, t.fill])",
              "[200,215,null,null,null,200,\"none\"]");
    checkEval(env, "new KeyframeEffect(null, null).getComputedTiming().duration", "0");
}

WR_TEST(testComputeTiming) {
    HostEnv env;
    JSContext* ctx = env.ctx();
    EffectTiming both;
    both.duration = 1000;
    both.fill = Fill::Both;
    CHECK(near(computeTiming(both, 500, true).progress, 0.5));

    EffectTiming alternate;
    alternate.duration = 1000;
    alternate.iterations = 2;
    alternate.direction = Direction::Alternate;
    const ComputedTiming mid = computeTiming(alternate, 1500, true);
    CHECK(near(mid.progress, 0.5));
    CHECK(near(mid.currentIteration, 1));
    alternate.fill = Fill::Forwards;
    const ComputedTiming end = computeTiming(alternate, 2000, true);
    CHECK(end.phase == ComputedTiming::Phase::After);
    CHECK(near(end.progress, 0));
    CHECK(near(end.currentIteration, 1));

    EffectTiming steps;
    steps.duration = 1000;
    steps.easing = parseEasing(ctx, "steps(2, end)");
    CHECK(near(computeTiming(steps, 600, true).progress, 0.5));

    EffectTiming delayed;
    delayed.duration = 1000;
    delayed.delay = 100;
    const ComputedTiming before = computeTiming(delayed, 50, true);
    CHECK(before.phase == ComputedTiming::Phase::Before);
    CHECK(!before.progress);

    EffectTiming forever;
    forever.duration = 1000;
    forever.iterations = INFINITY;
    CHECK(computeTiming(forever, 1e9, true).phase == ComputedTiming::Phase::Active);
    CHECK(activeDuration(forever) == INFINITY);

    EffectTiming instant;
    instant.duration = 0;
    instant.iterations = 3;
    instant.fill = Fill::Forwards;
    const ComputedTiming after = computeTiming(instant, 10, true);
    CHECK(near(after.progress, 1));
    CHECK(near(after.currentIteration, 2));

    CHECK(computeTiming(both, std::nullopt, true).phase == ComputedTiming::Phase::None);
}

WR_TEST(testKeyframeForms) {
    HostEnv env;
    const std::string pair = "[{\"composite\":\"auto\",\"computedOffset\":0,\"easing\":\"linear\",\"offset\":null,\"opacity\":\"0\"},"
                             "{\"composite\":\"auto\",\"computedOffset\":1,\"easing\":\"linear\",\"offset\":null,\"opacity\":\"1\"}]";
    checkEval(env, "JSON.stringify(new KeyframeEffect(null, [{opacity: 0}, {opacity: 1}]).getKeyframes())", pair);
    checkEval(env, "JSON.stringify(new KeyframeEffect(null, {opacity: [0, 1]}).getKeyframes())", pair);
    checkEval(env, "JSON.stringify(new KeyframeEffect(null, {opacity: 1}).getKeyframes().map(k => k.computedOffset))", "[1]");
    checkEval(env,
              "JSON.stringify(new KeyframeEffect(null, [{background: '#3a3'}, {background: '#c33', offset: 0.25},"
              " {background: '#3a3'}]).getKeyframes().map(k => [k.offset, k.computedOffset]))",
              "[[null,0],[0.25,0.25],[null,1]]");
    checkEval(env, "new KeyframeEffect(null, {opacity: [0, 1], easing: ['ease-in']}).getKeyframes().map(k => k.easing).join()",
              "ease-in,ease-in");
    checkEval(env, "new KeyframeEffect(null, [{opacity: 0, composite: 'add'}, {opacity: 1}]).getKeyframes().map(k => k.composite).join()",
              "add,auto");
    checkEval(env, "new KeyframeEffect(null, [{opacity: 0}, null, {opacity: 1}]).getKeyframes().map(k => k.computedOffset).join()",
              "0,0.5,1");
}

WR_TEST(testPropertyNames) {
    HostEnv env;
    checkEval(env,
              "const long = 'a'.repeat(129);"
              " const k = new KeyframeEffect(null, [{transform: 'none', cssFloat: 'left', '--x': '1', 'border-radius': '1px',"
              " animationName: 'a', willChange: 'x', direction: 'rtl', [long]: '1'}]).getKeyframes()[0];"
              " Object.keys(k).join()",
              "composite,computedOffset,easing,offset,--x,cssFloat,transform");
    checkEval(env, "new KeyframeEffect(null, [{webkitTransform: 'none'}]).getKeyframes()[0].webkitTransform", "none");
}

WR_TEST(testRejectedInput) {
    HostEnv env;
    env.eval(kErr);
    checkEval(env,
              "[err(() => new KeyframeEffect(null, [{opacity: 0, offset: 0.5}, {opacity: 1, offset: 0.2}])),"
              " err(() => new KeyframeEffect(null, [{opacity: 0, offset: 2}])),"
              " err(() => new KeyframeEffect(null, [{opacity: 0, easing: 'bogus'}])),"
              " err(() => new KeyframeEffect(null, [{opacity: 'x'.repeat(4097)}])),"
              " err(() => new KeyframeEffect(null, Array(10001).fill({opacity: 1}))),"
              " err(() => new KeyframeEffect(null, {opacity: Array(10001).fill(1)})),"
              " err(() => new KeyframeEffect(null, 5)),"
              " err(() => new KeyframeEffect(5, null))].join()",
              "TypeError,TypeError,TypeError,TypeError,RangeError,RangeError,TypeError,TypeError");
    // WPT processing-a-keyframes-argument-001: a list value in a keyframe sequence is ignored (browsers), not stringified
    // and not an error (the reference's TypeError).
    checkEval(env, "Object.keys(new KeyframeEffect(null, [{opacity: [0, 1], left: '1px'}]).getKeyframes()[0]).join()",
              "composite,computedOffset,easing,offset,left");
    checkEval(env,
              "[err(() => new KeyframeEffect(null, null, {duration: -1})), err(() => new KeyframeEffect(null, null, {duration: 'x'})),"
              " err(() => new KeyframeEffect(null, null, {iterations: NaN})), err(() => new KeyframeEffect(null, null, {iterations: -1})),"
              " err(() => new KeyframeEffect(null, null, {fill: 'sideways'})), err(() => new KeyframeEffect(null, null, {iterationStart: -1})),"
              " err(() => new KeyframeEffect(null, null, {easing: 'bogus'})), err(() => new KeyframeEffect(null, null, NaN)),"
              " err(() => new KeyframeEffect(null, null, {composite: 'auto'}))].join()",
              "TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError,TypeError");
    checkEval(env, "new KeyframeEffect(null, null, {delay: '100'}).getTiming().delay", "100");
    checkEval(env, "new KeyframeEffect(null, null, {iterations: Infinity}).getTiming().iterations", "Infinity");
    checkEval(env,
              "const e = new KeyframeEffect(null, null, {duration: 100}); const r = err(() => e.updateTiming({duration: 300, iterations: -1}));"
              " r + ' ' + e.getTiming().duration + ' ' + e.getTiming().iterations",
              "TypeError 100 1");
    checkEval(env, "const f = new KeyframeEffect(null, null); f.updateTiming({duration: 300, easing: 'ease-out'});"
                   " f.getTiming().duration + ' ' + f.getTiming().easing",
              "300 ease-out");
}

WR_TEST(testPseudoElement) {
    HostEnv env;
    env.eval(kErr);
    checkEval(env, "new KeyframeEffect(null, null).pseudoElement", "null");
    checkEval(env, "[err(() => new KeyframeEffect(null, null, {pseudoElement: 'div'})),"
                   " new KeyframeEffect(null, null, {pseudoElement: '::before'}).pseudoElement].join()",
              "DOMException:SyntaxError,::before");
    int unsupported = 0;
    for (const auto& [kind, detail] : env.host().diagnostics) {
        unsupported += kind == "unsupported" && detail == "KeyframeEffect pseudoElement";
    }
    env.eval("new KeyframeEffect(null, null, {pseudoElement: '::after'}); 1");
    int after = 0;
    for (const auto& [kind, detail] : env.host().diagnostics) {
        after += kind == "unsupported" && detail == "KeyframeEffect pseudoElement";
    }
    CHECK_EQ(unsupported, 1);
    CHECK_EQ(after, 1);
}

WR_TEST(testScriptInKeyframes) {
    HostEnv env;
    checkEval(env,
              "const e = new KeyframeEffect(null, [{opacity: 0}, {opacity: 1}]);"
              " let m; try { e.setKeyframes([{get opacity() { throw new Error('boom') }}]) } catch (x) { m = x.message }"
              " m + ' ' + e.getKeyframes().length",
              "boom 2");
    checkEval(env,
              "const g = new KeyframeEffect(null, null);"
              " g.setKeyframes([{get opacity() { g.setKeyframes([{opacity: 0.3}]); return '0.9'; }}]);"
              " g.getKeyframes().length + ' ' + g.getKeyframes()[0].opacity",
              "1 0.9");
}

WR_TEST(testKeyframeMemory) {
    HostEnv env;
    // 10,000 references to one proxy with 512 properties of 4,000 characters each: nothing in the input, 20 GB copied.
    env.eval("const names = []; for (let i = 0; names.length < 512; i++) { let n = '', v = i;"
             " do { n += String.fromCharCode(97 + v % 26); v = Math.floor(v / 26); } while (v); names.push('p' + n); }"
             " const big = 'x'.repeat(4000);"
             " window.frame = new Proxy({}, { ownKeys: () => names,"
             "   getOwnPropertyDescriptor: () => ({ value: big, enumerable: true, configurable: true }),"
             "   get: (target, key) => names.includes(key) ? big : undefined });"
             " window.frames = { [Symbol.iterator]: function* () { for (let i = 0; i < 10000; i++) yield frame; } }; 1");
    JSRuntime* rt = env.runtime().jsRuntime();
    JSMemoryUsage usage;
    JS_ComputeMemoryUsage(rt, &usage);
    JS_SetMemoryLimit(rt, size_t(usage.malloc_size) + (16 << 20));
    checkEval(env, "new KeyframeEffect(null, frames); 1", "ABORTED");
    CHECK(env.runtime().stopReason() == wr::StopReason::Memory);
}

WR_TEST(testCopyConstructor) {
    HostEnv env;
    checkEval(env,
              "const a = new KeyframeEffect(document.body, [{opacity: 0}, {opacity: 1}], {duration: 300, composite: 'add'});"
              " const b = new KeyframeEffect(a); b.updateTiming({duration: 50}); b.setKeyframes([{opacity: 0.5}]);"
              " [b.target === document.body, b.composite, a.getTiming().duration, a.getKeyframes().length,"
              "  b.getKeyframes().length, new KeyframeEffect(a).getTiming().duration].join()",
              "true,add,300,2,1,300");
}

/// WPT's gInvalidEasings (resources/easing-tests.js): each is a TypeError in both keyframe forms and as the effect's.
WR_TEST(testWPTInvalidEasings) {
    HostEnv env;
    checkEval(env,
              "const bad = ['', '7', 'test', 'initial', 'inherit', 'unset', 'unrecognized', 'var(--x)', 'ease-in-out, ease-out',"
              " 'cubic-bezier(1.1, 0, 1, 1)', 'cubic-bezier(0, 0, 1.1, 1)', 'cubic-bezier(-0.1, 0, 1, 1)', 'cubic-bezier(0, 0, -0.1, 1)',"
              " 'cubic-bezier(0.1, 0, 4, 0.4)', 'steps(-1, start)', 'steps(0.1, start)', 'steps(3, nowhere)', 'steps(-3, end)',"
              " 'function (a){return a}', 'function (x){return x}', 'function(x, y){return 0.3}'];"
              " const accepted = [];"
              " for (const e of bad) {"
              "   for (const make of [() => new KeyframeEffect(null, {easing: e}), () => new KeyframeEffect(null, [{easing: e}]),"
              "                       () => new KeyframeEffect(null, null, {easing: e})]) {"
              "     try { make(); accepted.push(JSON.stringify(e)); } catch (x) { if (!(x instanceof TypeError)) accepted.push(x.name); }"
              "   }"
              " }"
              " accepted.join(' ')",
              "");
}

