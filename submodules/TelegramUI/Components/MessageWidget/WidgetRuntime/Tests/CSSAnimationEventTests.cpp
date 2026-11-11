// CSS animations' and transitions' events (V5f plan, Task 6; CSS Animations 2 §4.2, CSS Transitions 2 §5): what auto/10
// listens for, cancellation, the handlers, the order against a script animation's events, and the legacy webkit names.
#include <cstdio>
#include <string>

#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

const char* const kHead =
    "<!doctype html><html><head><style>"
    "@keyframes short{from{opacity:1}to{opacity:.5}}"
    "body{margin:0} #ev-anim{animation:short .2s linear 1} #ev-iter{animation:short .1s linear 3}"
    " #ev-tr{transition:opacity .15s linear;opacity:1;width:4px;height:4px} #ev-tr.go{opacity:.4}"
    "</style></head><body>";

std::string page(const std::string& body) {
    return std::string(kHead) + body +
           "<script>window.$ = id => document.getElementById(id); window.log = [];"
           " window.note = e => log.push(e.type + ':' + (e.animationName ?? e.propertyName) + ':' + Math.round(e.elapsedTime * 1000));"
           "</script></body></html>";
}

void checkEval(RenderEnv& env, std::string_view code, std::string_view want) {
    const std::string got = env.env().eval(code);
    if (got != want) {
        std::printf("  %.*s\n    → %s\n    want %.*s\n", int(code.size()), code.data(), got.c_str(), int(want.size()), want.data());
    }
    CHECK(got == want);
}

void frames(RenderEnv& env, int count, double ms) {
    for (int i = 0; i < count; i++) {
        env.env().frame(ms);
    }
}

} // namespace

/// auto/10's animation events: animationstart; animationend with the name and the active duration; two
/// animationiteration events of a three-iteration animation.
WR_TEST(testTheAnimationEvents) {
    RenderEnv env(page("<div id=ev-anim style='width:4px;height:4px'></div><div id=ev-iter style='width:4px;height:4px'></div>"));
    env.env().eval("for (const t of ['animationstart', 'animationiteration', 'animationend']) { $('ev-anim').addEventListener(t, note);"
                   " $('ev-iter').addEventListener(t, note); } 1");
    frames(env, 30, 16);
    checkEval(env, "log.filter(l => l.includes('animationstart')).join()", "animationstart:short:0,animationstart:short:0");
    checkEval(env, "log.filter(l => l.includes('animationiteration')).join()", "animationiteration:short:100,animationiteration:short:200");
    checkEval(env, "log.filter(l => l.includes('animationend')).join()", "animationend:short:200,animationend:short:300");
}

/// auto/10's transition events: transitionrun, transitionstart and transitionend, each carrying the property.
WR_TEST(testTheTransitionEvents) {
    RenderEnv env(page("<div id=ev-tr></div>"));
    env.env().eval("for (const t of ['transitionrun', 'transitionstart', 'transitionend']) $('ev-tr').addEventListener(t, note); 1");
    env.env().frame(16);
    env.env().eval("$('ev-tr').classList.add('go'); 1");
    frames(env, 20, 16);
    checkEval(env, "log.join()", "transitionrun:opacity:0,transitionstart:opacity:0,transitionend:opacity:150");
}

/// Cancelling a CSS animation (its element leaves the document) or a transition (its property is no longer covered)
/// dispatches animationcancel and transitioncancel.
WR_TEST(testCancelEvents) {
    RenderEnv env(page("<div id=a style='animation:short 1s infinite;width:4px;height:4px'></div><div id=ev-tr></div>"));
    env.env().eval("$('a').addEventListener('animationcancel', note); $('ev-tr').addEventListener('transitioncancel', note); 1");
    frames(env, 3, 16);
    env.env().eval("$('ev-tr').classList.add('go'); 1");
    frames(env, 3, 16);
    env.env().eval("$('a').remove(); $('ev-tr').style.transition = 'none'; document.getAnimations(); 1");
    frames(env, 2, 16);
    checkEval(env, "log.map(l => l.split(':').slice(0, 2).join(':')).sort().join()", "animationcancel:short,transitioncancel:opacity");
}

/// The onanimation*/ontransition* handlers fire, and the legacy webkit names reach listeners when nobody listens to the
/// standard ones (DOM §2.9).
WR_TEST(testHandlersAndLegacyNames) {
    RenderEnv env(page("<div id=ev-anim style='width:4px;height:4px'></div><div id=x style='animation:short .1s;width:4px;height:4px'></div>"));
    env.env().eval("$('ev-anim').onanimationend = note; $('x').addEventListener('webkitAnimationEnd', e => log.push('legacy ' + e.type)); 1");
    frames(env, 20, 16);
    checkEval(env, "log.join()", "legacy webkitAnimationEnd,animationend:short:200");
}

/// Events of one frame sort by their scheduled time, then composite order: a CSS animation's end before a script
/// animation's finish scheduled at the same time.
WR_TEST(testCSSEventsBeforeScriptEventsAtTheSameTime) {
    RenderEnv env(page("<div id=o style='width:4px;height:4px'></div>"));
    env.env().eval("$('o').style.animation = 'short .1s linear'; document.getAnimations();"
                   " const s = $('o').animate({opacity: [1, 0]}, 100); s.onfinish = () => log.push('finish');"
                   " $('o').addEventListener('animationend', () => log.push('animationend')); 1");
    frames(env, 12, 16);
    checkEval(env, "log.join()", "animationend,finish");
}
