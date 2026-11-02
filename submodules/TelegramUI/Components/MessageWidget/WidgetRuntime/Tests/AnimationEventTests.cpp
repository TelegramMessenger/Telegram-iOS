// Animation events, replaced animations and lifetime (V5e plan, Task 4; Web Animations Level 1 §4.4.17 and §5.5): the
// order events are dispatched in, the per-frame cap, removing a filling animation another one replaces, and releasing
// the animations nothing can see any more.
#include <cstdio>
#include <string>

#include "Sources/Animation/AnimationState.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

void checkEval(HostEnv& env, std::string_view code, std::string_view want) {
    const std::string got = env.eval(code);
    if (got != want) {
        std::printf("  %.*s\n    → %s\n    want %.*s\n", int(code.size()), code.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

size_t liveCount(HostEnv& env) {
    const wr::animation::AnimationState* state = wr::animation::AnimationState::find(env.ctx());
    return state ? state->liveCount() : 0;
}

} // namespace

/// Events dispatch by the time they were scheduled (c ended at 66, a and b at 116), a tie by creation order, and a
/// handler's microtask runs before the next event; each carries the frame's timeline time.
WR_TEST(testEventOrder) {
    HostEnv env;
    env.eval("window.log = []; const a = document.body.animate({opacity: [0, 1]}, 100);"
             " const b = document.body.animate({opacity: [0, 1]}, 100);"
             " const c = document.body.animate({opacity: [0, 1]}, 50);"
             " a.onfinish = e => { log.push('a ' + e.timelineTime); Promise.resolve().then(() => log.push('a-micro')); };"
             " b.onfinish = e => log.push('b ' + e.timelineTime); c.onfinish = e => log.push('c ' + e.timelineTime); 1");
    env.frame(16);
    env.frame(200);
    checkEval(env, "log.join()", "c 216,a 216,a-micro,b 216");
}

WR_TEST(testReplaced) {
    HostEnv env;
    env.eval("window.log = []; window.first = document.body.animate({opacity: [0, 1]}, {duration: 10, fill: 'forwards'});"
             " window.second = document.body.animate({opacity: [1, 0.5]}, {duration: 10, fill: 'forwards'});"
             " first.onremove = e => log.push('remove ' + e.currentTime + ' ' + (e instanceof AnimationPlaybackEvent)); 1");
    env.frame(16);
    env.frame(50);
    checkEval(env, "[first.replaceState, second.replaceState, document.body.getAnimations().length, log.join()].join()",
              "removed,active,1,remove 10 true");

    env.eval("window.kept = document.body.animate({color: ['red', 'blue']}, {duration: 10, fill: 'forwards'}); kept.persist();"
             " window.over = document.body.animate({color: ['blue', 'red']}, {duration: 10, fill: 'forwards'});"
             " window.other = document.body.animate({transform: ['none', 'none']}, {duration: 10, fill: 'forwards'}); 1");
    env.frame(16);
    env.frame(50);
    checkEval(env, "[kept.replaceState, over.replaceState, other.replaceState].join()", "persisted,active,active");
    // play() leaves a removed animation removed (Level 1: only persist() brings it back).
    checkEval(env, "first.play(); first.replaceState", "removed");
}

WR_TEST(testReleased) {
    HostEnv env;
    env.eval("window.refs = []; (() => { for (let i = 0; i < 1000; i++) refs.push(new WeakRef(document.body.animate({opacity: [0, 1]}, 10))); })(); 1");
    CHECK(liveCount(env) == 1000);
    env.frame(16);
    env.frame(50);
    env.frame(16);
    CHECK_EQ(liveCount(env), size_t(0));
    JS_RunGC(env.runtime().jsRuntime());
    checkEval(env, "refs.filter(r => r.deref() !== undefined).length", "0");

    env.eval("(() => { for (let i = 0; i < 1000; i++) document.body.animate({opacity: [0, 1]}, {duration: 10, fill: 'forwards'}); })(); 1");
    env.frame(16);
    env.frame(50);
    env.frame(16);
    CHECK_EQ(liveCount(env), size_t(1));
    // A paused animation that is not removed is never released, whatever its time.
    env.eval("window.paused = document.body.animate({opacity: [0, 1]}, 10); paused.pause(); 1");
    env.frame(16);
    env.frame(50);
    CHECK_EQ(liveCount(env), size_t(2));
    // An idle animation is released, and comes back when it plays.
    env.eval("window.idle = new Animation(new KeyframeEffect(document.body, {opacity: [0, 1]}, 1000)); 1");
    env.frame(16);
    CHECK_EQ(liveCount(env), size_t(2));
    env.eval("idle.play(); 1");
    CHECK_EQ(liveCount(env), size_t(3));
}

WR_TEST(testTooManyEvents) {
    HostEnv env;
    env.eval("window.count = 0; (() => { for (let i = 0; i < 5000; i++) document.body.animate({opacity: [0, 1]}, 10).onfinish = () => count++; })(); 1");
    env.frame(16);
    env.frame(50);
    checkEval(env, "count", "4096");
}

/// WPT cancel.html and finished.html: finish() resolves `finished` in its finish notification steps, synchronously, so
/// the animation's `then` is read inside finish() and the promise's reactions are queued before any later reaction.
WR_TEST(testFinishResolvesAtOnce) {
    HostEnv env;
    env.eval("window.b = document.body.animate({}, 100000); window.flag = false; b.finished.then(() => flag = true); 1");
    env.frame(16);
    checkEval(env,
              "window.got = false; const c = document.body.animate({}, 1000);"
              " Object.defineProperty(c, 'then', {get() { got = true; return undefined; }}); c.finish(); got",
              "true");
    checkEval(env, "b.ready.then(() => { b.finish(); b.currentTime = 50000; }).then(() => window.seen = flag); 1", "1");
    checkEval(env, "seen", "true");
}

/// WPT onremove.html: events sort by their scheduled event time (Level 1 §4.2.1), and a finish is scheduled when the
/// animation reached its end, before the frame removes it: B's finish is dispatched before A's remove, and both carry
/// the frame's timeline time.
WR_TEST(testAFinishSortsBeforeTheRemoveItCauses) {
    HostEnv env;
    env.eval("window.A = document.body.animate({opacity: 1}, {duration: 1, fill: 'forwards'});"
             " window.B = document.body.animate({opacity: 1}, {duration: 1, fill: 'forwards'});"
             " window.fin = null; B.onfinish = e => fin = e.timelineTime; window.res = '';"
             " A.onremove = e => res = [A.replaceState, e.currentTime, fin !== null, e.timelineTime === fin].join(); 1");
    env.frame(16);
    env.frame(16);
    checkEval(env, "res", "removed,1,true,true");
}

/// WPT cancel.html: finish() resolves `finished` with the animation, reading a widget-defined `then` at once; the
/// thenable job calls it later, and a cancel() in between neither rejects that promise nor stops the job.
WR_TEST(testCancelAfterAThenableFinish) {
    HostEnv env;
    env.eval("window.log = []; window.anim = new Animation(); window.calls = 0;"
             " Object.defineProperty(anim, 'then', { get() { log.push('get'); return function(resolve) { calls++; log.push('then'); resolve('hello'); }; } });"
             " window.fp = anim.finished; fp.then(v => log.push('finished ' + v), e => log.push('rejected ' + e));"
             " anim.finish(); log.push('finish returned'); anim.cancel(); log.push('cancel returned'); 1");
    env.drain();
    checkEval(env, "log.join()", "get,finish returned,cancel returned,then,finished hello");
}

/// Final review C1: a finish whose scheduled time is NaN (a start time of -Infinity, from a playback rate so small that
/// end / rate overflows) sorts as unresolved, first, instead of breaking the sort's ordering. Queued from a microtask of
/// the frame, after the frame's own finishes, so the sort has to move them.
WR_TEST(testANaNScheduledTimeSortsAsUnresolved) {
    HostEnv env;
    env.eval("window.log = []; window.tiny = [];"
             " for (let i = 0; i < 5; i++) { const b = document.body.animate({}, 1000); b.onfinish = () => log.push('n' + i); tiny.push(b); }"
             " for (let i = 0; i < 10; i++) { const a = document.body.animate({}, 10 + i); a.onfinish = () => log.push('f' + i); }"
             " document.body.getAnimations()[5].finished.then(() => tiny.forEach(b => { b.playbackRate = 1e-308; b.finish(); })); 1");
    env.frame(16);
    env.frame(50);
    checkEval(env, "log.join()", "n0,n1,n2,n3,n4,f0,f1,f2,f3,f4,f5,f6,f7,f8,f9");
}

/// Final review M5 (regraded): Level 1 §5.5. A persisted animation covers the ones below it too; an animation of a
/// pseudo-element covers nothing of its element's own; an animation whose target is not in the document is not removed.
WR_TEST(testReplacementFollowsLevel1) {
    HostEnv env;
    env.eval("window.own = document.body.animate({opacity: [0, 1]}, {duration: 10, fill: 'forwards'});"
             " document.body.animate({opacity: [1, 0.5]}, {duration: 10, fill: 'forwards', pseudoElement: '::before'});"
             " window.below = document.body.animate({color: ['red', 'blue']}, {duration: 10, fill: 'forwards'});"
             " window.kept = document.body.animate({color: ['blue', 'red']}, {duration: 10, fill: 'forwards'}); kept.persist();"
             " window.loose = document.createElement('div');"
             " window.l1 = loose.animate({opacity: [0, 1]}, {duration: 10, fill: 'forwards'});"
             " loose.animate({opacity: [1, 0]}, {duration: 10, fill: 'forwards'}); 1");
    env.frame(16);
    env.frame(50);
    checkEval(env, "[own.replaceState, below.replaceState, kept.replaceState, l1.replaceState].join()", "active,removed,persisted,active");
}

/// Fix-wave review I1: a removed animation played again stays removed (it renders nothing) but its timing still runs:
/// it is not released while running, so it finishes, fires `finish` and resolves `finished`.
WR_TEST(testARemovedAnimationPlaysToItsEnd) {
    HostEnv env;
    env.eval("window.log = []; window.first = document.body.animate({opacity: [0, 1]}, {duration: 10, fill: 'forwards'});"
             " document.body.animate({opacity: [1, 0.5]}, {duration: 10, fill: 'forwards'}); 1");
    env.frame(16);
    env.frame(50);
    env.frame(16);
    checkEval(env, "first.replaceState", "removed");
    env.eval("first.onfinish = () => log.push('finish'); first.play(); first.finished.then(() => log.push('resolved')); 1");
    env.frame(16);
    env.frame(16);
    env.frame(50);
    // The finish notification and the `then` reaction both run in the frame's microtask checkpoint, then the events are
    // dispatched.
    checkEval(env, "[first.replaceState, first.playState, log.join()].join(' ')", "removed finished resolved,finish");
    // Once finished it is let go; the animation that covers it stays (it fills).
    CHECK_EQ(liveCount(env), size_t(1));
    // A removed animation that is paused is let go too: it renders nothing and cannot move without script.
    env.eval("first.play(); first.pause(); 1");
    CHECK_EQ(liveCount(env), size_t(2));
    env.frame(16);
    env.frame(16);
    checkEval(env, "first.playState", "paused");
    CHECK_EQ(liveCount(env), size_t(1));
}
