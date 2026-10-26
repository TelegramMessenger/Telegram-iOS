// Animation playback (V5e plan, Task 3; Web Animations Level 1 §4.4): pending play and pause, the update step at each
// frame, ready and finished, finish and cancel events, playback rate and reverse, timelines, and when frames are
// wanted. The host clock starts at 0 and env.frame(ms) advances it, so the document timeline reads the frame's time.
#include <cstdio>
#include <string>

#include "Sources/Host/EventLoop.h"
#include "Tests/HostHarness.h"

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

bool wantsFrame(HostEnv& env) { return wr::EventLoop::of(env.ctx()).wantsAnimationFrame(); }

} // namespace

WR_TEST(testTheConformanceValues) {
    HostEnv env;
    checkEval(env,
              "window.a1 = document.body.animate([{transform: 'translateX(0)'}, {transform: 'translateX(40px)'}],"
              " {duration: 1000, fill: 'both'}); a1.pause(); a1.currentTime = 500;"
              " [a1.playState, a1.currentTime, a1.effect.getComputedTiming().progress, document.body.getAnimations().length,"
              "  typeof document.timeline.currentTime, a1 instanceof Animation].join()",
              "paused,500,0.5,1,number,true");
    checkEval(env,
              "const p1 = document.createElement('div'); document.body.append(p1);"
              " const x = p1.animate([{opacity: 1}, {opacity: 0}], {duration: 10000}); x.cancel();"
              " p1.getAnimations().length + ' ' + document.body.getAnimations().length",
              "0 1");
    env.frame(16);
    checkEval(env, "[a1.playState, a1.currentTime, document.timeline.currentTime].join()", "paused,500,16");
}

WR_TEST(testPendingPlay) {
    HostEnv env;
    checkEval(env,
              "window.a = document.body.animate({opacity: [0, 1]}, 1000); window.readyWith = null;"
              " a.ready.then(x => readyWith = x === a);"
              " JSON.stringify([a.pending, a.playState, a.currentTime, a.startTime])",
              "[true,\"running\",0,null]");
    env.frame(16);
    checkEval(env, "[a.startTime, document.timeline.currentTime, a.pending, readyWith, a.currentTime].join()", "16,16,false,true,0");
    env.frame(100);
    checkEval(env, "a.currentTime", "100");
}

WR_TEST(testFinished) {
    HostEnv env;
    env.eval("window.log = []; window.f = document.body.animate({opacity: [0, 1]}, 100);"
             " f.onfinish = e => log.push('onfinish ' + e.currentTime + ' ' + (e instanceof AnimationPlaybackEvent));"
             " f.addEventListener('finish', () => log.push('listener'));"
             " f.finished.then(x => log.push('finished ' + (x === f))); 1");
    env.frame(16);
    env.frame(50);
    checkEval(env, "log.join() + ' ' + f.playState", " running");
    env.frame(50);
    checkEval(env, "log.join() + ' ' + f.playState", "finished true,onfinish 100 true,listener finished");
    checkEval(env,
              "window.g = document.body.animate({opacity: [0, 1]}, 1000); window.state = 'none';"
              " g.finished.then(() => state = 'resolved'); 1",
              "1");
    env.frame(16);
    checkEval(env, "g.finish(); state + ' ' + g.playState + ' ' + g.currentTime", "none finished 1000");
    checkEval(env, "state", "resolved");
}

WR_TEST(testPause) {
    HostEnv env;
    env.eval("window.p = document.body.animate({opacity: [0, 1]}, 1000); 1");
    env.frame(16);
    env.frame(100);
    checkEval(env, "p.pause(); [p.pending, p.playState].join()", "true,paused");
    env.frame(16);
    checkEval(env, "[p.pending, p.playState, p.currentTime].join()", "false,paused,116");
    env.frame(100);
    checkEval(env, "p.currentTime", "116");
    checkEval(env, "p.play(); p.pending", "true");
    env.frame(16);
    env.frame(50);
    checkEval(env, "p.currentTime", "166");
    checkEval(env,
              "window.q = document.body.animate({opacity: [0, 1]}, 1000); window.qReady = false;"
              " q.pause(); q.ready.then(() => qReady = true); q.currentTime = 250;"
              " [q.pending, q.playState, q.currentTime].join()",
              "false,paused,250");
    checkEval(env, "qReady", "true");
}

WR_TEST(testCancel) {
    HostEnv env;
    env.eval("window.r = []; window.c = document.body.animate({opacity: [0, 1]}, 1000); window.oldReady = c.ready;"
             " oldReady.catch(e => r.push('ready ' + e.name + ' ' + (e instanceof DOMException)));"
             " c.finished.catch(e => r.push('finished ' + e.name));"
             " c.oncancel = e => r.push('cancel ' + e.currentTime + ' ' + typeof e.timelineTime); 1");
    checkEval(env, "c.cancel(); [c.playState, c.ready !== oldReady, c.pending].join()", "idle,true,false");
    checkEval(env, "r.join()", "ready AbortError true,finished AbortError");
    env.frame(16);
    checkEval(env, "r.join()", "ready AbortError true,finished AbortError,cancel null number");
    // A cancel with nobody listening reports no unhandled rejection.
    env.eval("document.body.animate({opacity: [0, 1]}, 1000).cancel(); 1");
    env.frame(16);
    env.frame(16);
    bool unhandled = false;
    for (const auto& [kind, detail] : env.host().diagnostics) {
        unhandled = unhandled || kind.rfind("unhandled-rejection", 0) == 0;
    }
    CHECK(!unhandled);
}

WR_TEST(testRateAndReverse) {
    HostEnv env;
    env.eval("window.u = document.body.animate({opacity: [0, 1]}, 1000); 1");
    env.frame(16);
    env.frame(100);
    checkEval(env, "u.updatePlaybackRate(2); [u.playbackRate, u.pending].join()", "1,true");
    env.frame(16);
    checkEval(env, "[u.playbackRate, u.currentTime].join()", "2,116");
    env.frame(10);
    checkEval(env, "u.currentTime", "136");

    env.eval("window.v = document.body.animate({opacity: [0, 1]}, 1000); 1");
    env.frame(16);
    env.frame(300);
    checkEval(env, "v.reverse(); v.pending", "true");
    env.frame(16);
    // 16 ms passed while the play task was pending.
    checkEval(env, "[v.playbackRate, v.currentTime].join()", "-1,316");
    env.frame(400);
    checkEval(env, "[v.playState, v.currentTime].join()", "finished,0");

    checkEval(env, "const w = new Animation(new KeyframeEffect(document.body, null, 1000)); w.playbackRate = -1; w.play(); w.currentTime",
              "1000");
}

WR_TEST(testTimelines) {
    HostEnv env;
    env.eval(kErr);
    env.eval("window.t = new DocumentTimeline({originTime: 100}); 1");
    env.frame(16);
    checkEval(env, "t.currentTime + ' ' + (t instanceof AnimationTimeline)", "-84 true");
    env.eval("window.n = new Animation(new KeyframeEffect(document.body, null, 1000), null); n.play(); 1");
    env.frame(16);
    env.frame(16);
    checkEval(env, "[n.pending, n.timeline].join()", "true,");
    checkEval(env, "new Animation(new KeyframeEffect(document.body, null, 1000)).timeline === document.timeline", "true");
    checkEval(env, "document.timeline === document.timeline", "true");
    checkEval(env, "err(() => new AnimationTimeline())", "TypeError");
    env.eval("window.o = new Animation(new KeyframeEffect(document.body, null, 1000), t); o.play(); 1");
    env.frame(16);
    checkEval(env, "[o.pending, o.startTime].join()", "false,-36");
}

/// The animation state is made on first use: made after frames already ran, the document time is the latest step's,
/// not 0.
WR_TEST(testTheDocumentTimeWhenFirstUsedLate) {
    HostEnv env;
    env.frame(50);
    env.frame(50);
    checkEval(env, "document.timeline.currentTime", "100");
}

WR_TEST(testConstructedEvent) {
    HostEnv env;
    checkEval(env, "const e = new AnimationPlaybackEvent('finish', {currentTime: 5}); JSON.stringify([e.type, e.currentTime, e.timelineTime])",
              "[\"finish\",5,null]");
}

WR_TEST(testFramesStop) {
    HostEnv env;
    CHECK(!wantsFrame(env));
    env.eval("window.s = document.body.animate({opacity: [0, 1]}, 100); 1");
    CHECK(wantsFrame(env));
    env.frame(16);
    CHECK(wantsFrame(env));
    env.frame(200);
    CHECK_JS_EQ(env, "s.playState", "finished");
    env.frame(16);
    CHECK(!wantsFrame(env));

    env.eval("window.ff = document.body.animate({opacity: [0, 1]}, {duration: 100, fill: 'forwards'}); 1");
    env.frame(16);
    env.frame(200);
    env.frame(16);
    CHECK(!wantsFrame(env));

    env.eval("window.pp = document.body.animate({opacity: [0, 1]}, 1000); 1");
    env.frame(16);
    env.eval("pp.pause(); 1");
    env.frame(16);
    env.frame(16);
    CHECK(!wantsFrame(env));

    env.eval("window.cc = document.body.animate({opacity: [0, 1]}, 1000); 1");
    env.frame(16);
    env.eval("cc.cancel(); 1");
    env.frame(16);
    env.frame(16);
    CHECK(!wantsFrame(env));

    env.eval("window.nn = new Animation(new KeyframeEffect(document.body, null, 1000), null); nn.play(); 1");
    env.frame(16);
    env.frame(16);
    CHECK(!wantsFrame(env));

    env.eval("window.ii = document.body.animate({opacity: [0, 1]}, {duration: 100, iterations: Infinity}); 1");
    for (int i = 0; i < 20; i++) {
        env.frame(100);
        CHECK(wantsFrame(env));
    }
    env.eval("ii.cancel(); 1");
    env.frame(16);
    env.frame(16);
    CHECK(!wantsFrame(env));
}

WR_TEST(testInvalidStates) {
    HostEnv env;
    env.eval(kErr);
    env.eval("window.i = document.body.animate({opacity: [0, 1]}, 1000); 1");
    env.frame(16);
    checkEval(env,
              "[err(() => i.currentTime = null),"
              " err(() => new Animation(new KeyframeEffect(document.body, null, 1000), null).reverse()),"
              " err(() => document.body.animate(null, {duration: 1000, iterations: Infinity}).finish()),"
              " err(() => i.playbackRate = NaN),"
              " err(() => { const m = new Animation(new KeyframeEffect(document.body, null, {duration: 1000, iterations: Infinity}));"
              "   m.playbackRate = -1; m.play(); }),"
              " err(() => new Animation({}))].join()",
              "TypeError,DOMException:InvalidStateError,DOMException:InvalidStateError,TypeError,DOMException:InvalidStateError,TypeError");
}

/// WPT setting-the-timeline-of-an-animation.html: setting the timeline keeps the start time (Level 1: a resolved start
/// time only makes the hold time unresolved), so a running or finished animation runs on, and an aborted pause keeps
/// its start time across clearing and re-setting the timeline.
WR_TEST(testSettingTheTimelineKeepsTheStartTime) {
    HostEnv env;
    checkEval(env,
              "const a = new Animation(new KeyframeEffect(document.body, null, 100000), document.timeline);"
              " const s = document.timeline.currentTime - 50000; a.startTime = s; a.timeline = null;"
              " const f = new Animation(new KeyframeEffect(document.body, null, 100000), document.timeline);"
              " const t = document.timeline.currentTime - 200000; f.startTime = t; const before = f.playState; f.timeline = null;"
              " [a.playState, a.startTime === s, before, f.playState, f.startTime === t].join()",
              "running,true,finished,running,true");
    env.eval("window.b = new Animation(new KeyframeEffect(document.body, null, 100000), document.timeline);"
             " window.s2 = document.timeline.currentTime - 50000; b.startTime = s2; b.pause(); b.play();"
             " b.timeline = null; b.timeline = document.timeline; 1");
    env.frame(16);
    checkEval(env, "[b.pending, b.startTime === s2].join()", "false,true");
}

/// WPT seamlessly-updating-the-playback-rate-of-an-animation.html: with an unresolved current time the new rate applies
/// at once (no play, so an infinite end never throws).
WR_TEST(testUpdatingTheRateWithAnUnresolvedCurrentTime) {
    HostEnv env;
    env.eval("window.c = document.body.animate(null, 100000); 1");
    env.frame(16);
    checkEval(env,
              "c.timeline = null; c.startTime = 0; c.effect.updateTiming({endDelay: 1e38}); c.updatePlaybackRate(-1);"
              " [c.currentTime, c.playState, c.playbackRate, c.pending].join()",
              ",running,-1,false");
}

/// WPT reversing-an-animation.html and updating-the-finished-state.html: a rate of 0 reverses to +0 (not -0), and a
/// reversed animation seeked to 0 reads +0.
WR_TEST(testZeroIsPositive) {
    HostEnv env;
    env.eval("window.d = document.body.animate({}, 100000); d.playbackRate = 0; d.currentTime = 50000; d.reverse();"
             " window.e = document.body.animate(null, 100000); e.playbackRate = -1; e.play(); 1");
    env.frame(16);
    checkEval(env, "e.currentTime = 0; [Object.is(d.playbackRate, 0), d.currentTime, Object.is(e.currentTime, 0)].join()",
              "true,50000,true");
    env.frame(16);
    checkEval(env, "Object.is(e.currentTime, 0)", "true");
}
