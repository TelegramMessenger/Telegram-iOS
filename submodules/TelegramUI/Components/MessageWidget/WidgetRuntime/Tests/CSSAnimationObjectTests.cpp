// CSS animations' objects (V5f plan, Task 3): AnimationEvent and TransitionEvent, CSSAnimation and CSSTransition as
// Animations no script can construct, and the onanimation*/ontransition* handlers.
#include <cstdio>
#include <string>

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

} // namespace

WR_TEST(testTheEventConstructors) {
    HostEnv env;
    checkEval(env,
              "const a = new AnimationEvent('animationend', {animationName: 'slide', elapsedTime: 1.5, bubbles: true});"
              " [a.type, a.animationName, a.elapsedTime, a.pseudoElement, a.bubbles, a.isTrusted, a instanceof Event].join()",
              "animationend,slide,1.5,,true,false,true");
    checkEval(env, "const d = new AnimationEvent('x'); [d.animationName, d.elapsedTime, d.pseudoElement].join('|')", "|0|");
    checkEval(env,
              "const t = new TransitionEvent('transitionend', {propertyName: 'opacity', elapsedTime: 0.15, pseudoElement: '::before'});"
              " [t.propertyName, t.elapsedTime, t.pseudoElement].join()",
              "opacity,0.15,::before");
    checkEval(env, "const u = new TransitionEvent('x'); [u.propertyName, u.elapsedTime].join('|')", "|0");
}

WR_TEST(testTheAnimationsAreNotConstructible) {
    HostEnv env;
    checkEval(env, "try { new CSSAnimation(); 'made' } catch (e) { e.name }", "TypeError");
    checkEval(env, "try { new CSSTransition(); 'made' } catch (e) { e.name }", "TypeError");
    checkEval(env,
              "[Object.getPrototypeOf(CSSAnimation.prototype) === Animation.prototype,"
              " Object.getPrototypeOf(CSSTransition.prototype) === Animation.prototype,"
              " 'animationName' in CSSAnimation.prototype, 'transitionProperty' in CSSTransition.prototype].join()",
              "true,true,true,true");
}

WR_TEST(testTheHandlers) {
    HostEnv env;
    const char* const names = "['onanimationstart', 'onanimationiteration', 'onanimationend', 'onanimationcancel', 'ontransitionrun',"
                              " 'ontransitionstart', 'ontransitionend', 'ontransitioncancel']";
    checkEval(env, std::string(names) + ".every(n => n in HTMLElement.prototype && n in document && n in window)", "true");
    checkEval(env,
              "window.log = []; document.body.onanimationend = e => log.push(e.animationName);"
              " document.body.ontransitionend = e => log.push(e.propertyName);"
              " document.body.dispatchEvent(new AnimationEvent('animationend', {animationName: 'a'}));"
              " document.body.dispatchEvent(new TransitionEvent('transitionend', {propertyName: 'p'})); log.join()",
              "a,p");
}
