// CSSOM View's matchMedia and MediaQueryList (V3b plan, Task 1): a query is evaluated by litehtml's media query parser
// against the container's media features, exactly as @media is, so the two always agree; a change of the features (the
// host's theme) reports a `change` to every list whose answer flipped, after the task that changed them.
#include <string>

#include <litehtml/string_id.h>

#include "Sources/Host/HostState.h"
#include "Sources/Runtime/Runtime.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr_test::RenderEnv;

namespace {

// Each probe is rgb(0, 0, 2) exactly when its @media applies.
const char* const kProbes =
    "<!doctype html><html><head><style>"
    "div { color: rgb(0, 0, 1) }"
    "@media (min-width: 200px) { #w { color: rgb(0, 0, 2) } }"
    "@media (max-width: 100px) { #n { color: rgb(0, 0, 2) } }"
    "@media (prefers-color-scheme: dark) { #d { color: rgb(0, 0, 2) } }"
    "@media (prefers-reduced-motion: reduce) { #r { color: rgb(0, 0, 2) } }"
    "@media (hover: hover) { #h { color: rgb(0, 0, 2) } }"
    "@media (pointer: fine) { #p { color: rgb(0, 0, 2) } }"
    "@media print { #pr { color: rgb(0, 0, 2) } }"
    "</style></head><body><div id=w></div><div id=n></div><div id=d></div><div id=r></div><div id=h></div>"
    "<div id=p></div><div id=pr></div>"
    "<script>for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
    "window.agree = (el, q) => (getComputedStyle(el).color === 'rgb(0, 0, 2)') === matchMedia(q).matches;</script>"
    "</body></html>";

const char* const kEmpty = "<!doctype html><html><head></head><body></body></html>";

void switchTheme(RenderEnv& env, wr::Theme theme) {
    wr::HostState::of(env.ctx()).themeChanged(env.ctx(), theme);
    env.env().drain();
}

} // namespace

WR_TEST(testAWidthQueryMatchesTheLayoutWidth) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 1px)').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('(max-width: 100px)').matches"), std::string("false"));
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 300px) and (max-width: 300px)').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('screen').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('') .matches"), std::string("true"));
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 1px)') instanceof MediaQueryList && "
                            "matchMedia('(min-width: 1px)') instanceof EventTarget"),
             std::string("true"));
    // A new object per call.
    CHECK_EQ(env.env().eval("matchMedia('screen') !== matchMedia('screen')"), std::string("true"));
}

/// The host's reduce-motion setting (the system's Reduce Motion): @media and matchMedia follow it, and a list whose answer
/// flipped reports a change after the task that set it.
WR_TEST(testReducedMotionFollowsTheHost) {
    RenderEnv env(kProbes);
    CHECK_EQ(env.env().eval("window.events = []; window.q = matchMedia('(prefers-reduced-motion: reduce)');"
                            " q.addEventListener('change', e => events.push(e.matches)); q.matches + ',' + getComputedStyle(r).color"),
             std::string("false,rgb(0, 0, 1)"));
    wr::HostState::of(env.ctx()).setReducedMotion(env.ctx(), true);
    env.env().drain();
    CHECK_EQ(env.env().eval("[q.matches, getComputedStyle(r).color, agree(r, '(prefers-reduced-motion: reduce)'), events.join()].join('|')"),
             std::string("true|rgb(0, 0, 2)|true|true"));
}

WR_TEST(testMediaIsTheQuery) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("matchMedia('(min-width: 1px)').media.replace(/\\s/g, '')"), std::string("(min-width:1px)"));
    CHECK_EQ(env.env().eval("matchMedia('  screen  ').media"), std::string("screen"));
}

WR_TEST(testMatchMediaAgreesWithAtMedia) {
    RenderEnv env(kProbes);
    CHECK_EQ(env.env().eval("[agree(w, '(min-width: 200px)'), agree(n, '(max-width: 100px)'),"
                            " agree(d, '(prefers-color-scheme: dark)'), agree(r, '(prefers-reduced-motion: reduce)'),"
                            " agree(h, '(hover: hover)'), agree(p, '(pointer: fine)'), agree(pr, 'print')].join()"),
             std::string("true,true,true,true,true,true,true"));
    // Profile 1 drops hover and pointer; print never applies.
    CHECK_EQ(env.env().eval("[matchMedia('(hover: hover)').matches, matchMedia('(pointer: coarse)').matches,"
                            " matchMedia('(pointer: fine)').matches, matchMedia('print').matches].join()"),
             std::string("false,false,false,false"));
}

WR_TEST(testPrefersColorSchemeFollowsTheTheme) {
    RenderEnv env(kProbes);
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: dark)').matches"), std::string("false"));
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: light)').matches"), std::string("true"));
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: dark)').matches"), std::string("true"));
    CHECK_EQ(env.env().eval("agree(d, '(prefers-color-scheme: dark)')"), std::string("true"));
}

WR_TEST(testAChangeEventFiresWhenTheThemeFlips) {
    RenderEnv env(kEmpty);
    env.env().eval("window.log = [];"
                   "window.m = matchMedia('(prefers-color-scheme: dark)');"
                   "m.addEventListener('change', e => log.push('l:' + e.matches + ':' + e.media.replace(/\\s/g, '') +"
                   "  ':' + (e instanceof MediaQueryListEvent)));"
                   "m.onchange = e => log.push('h:' + e.matches);"
                   "m.addListener(e => log.push('a:' + e.matches));"
                   "window.w = matchMedia('(min-width: 1px)');"
                   "w.onchange = () => log.push('width');");
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("log.join()"), std::string("l:true:(prefers-color-scheme:dark):true,h:true,a:true"));
    switchTheme(env, wr::Theme::Light);
    CHECK_EQ(env.env().eval("log.slice(3).join()"), std::string("l:false:(prefers-color-scheme:dark):true,h:false,a:false"));
    // The same theme again: nothing flipped, nothing fires.
    switchTheme(env, wr::Theme::Light);
    CHECK_EQ(env.env().eval("log.length"), std::string("6"));
}

WR_TEST(testAListWithAListenerOutlivesItsWrapper) {
    RenderEnv env(kEmpty);
    env.env().eval("window.log = []; matchMedia('(prefers-color-scheme: dark)').onchange = e => log.push(e.matches); 1");
    JS_RunGC(env.env().runtime().jsRuntime());
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("log.join()"), std::string("true"));
}

WR_TEST(testRemoveListenerStopsTheEvents) {
    RenderEnv env(kEmpty);
    env.env().eval("window.log = []; window.m = matchMedia('(prefers-color-scheme: dark)');"
                   "window.f = e => log.push('a'); m.addListener(f); m.removeListener(f);"
                   "window.g = e => log.push('g'); m.addEventListener('change', g); m.removeEventListener('change', g);"
                   "m.addEventListener('change', e => log.push('kept'));");
    switchTheme(env, wr::Theme::Dark);
    CHECK_EQ(env.env().eval("log.join()"), std::string("kept"));
}

WR_TEST(testAnUnknownMediaKeywordDoesNotGrowTheIdTable) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("matchMedia('(prefers-color-scheme: never-a-scheme-7)').matches"), std::string("false"));
    litehtml::string_id id;
    CHECK(!litehtml::_find_id("never-a-scheme-7", id));
}

/// The final review's C2: a query past kMaxMediaQueryBytes is refused before it is copied or parsed (litehtml's
/// tokenizer allocates outside the memory limit): it never matches and reads back as "not all".
WR_TEST(testAnOverlongQueryIsRefused) {
    RenderEnv env(kEmpty);
    env.env().eval("window.q = '(min-width: 1px)' + ' and (min-width: 1px)'.repeat(2000); 1");
    CHECK_EQ(env.env().eval("(m => m.matches + ':' + m.media)(matchMedia(q))"), std::string("false:not all"));
}

/// V4 plan, Task 3b: matchMedia and @media share the profile's walker; an out-of-profile query is false whatever the
/// features say.
WR_TEST(testMatchMediaFollowsTheProfile) {
    RenderEnv env(kEmpty);
    for (const char* query : {"(hover: hover)", "(pointer: fine)", "print", "(max-height: 9999px)", "(color)"}) {
        CHECK_EQ(env.env().eval(std::string("String(matchMedia('") + query + "').matches)"), std::string("false"));
    }
    for (const char* query : {"(max-width: 9999px)", "(prefers-reduced-motion: no-preference)"}) {
        CHECK_EQ(env.env().eval(std::string("String(matchMedia('") + query + "').matches)"), std::string("true"));
    }
}

/// RB §8.3: the host answers a query of at most 1,024 units; a longer one is false (V4 plan, Task 8).
WR_TEST(testAQueryOver1024UnitsIsFalse) {
    RenderEnv env(kEmpty);
    CHECK_EQ(env.env().eval("String(matchMedia('(min-width: 1px)'.padEnd(1024)).matches)"), std::string("true"));
    CHECK_EQ(env.env().eval("String(matchMedia('(min-width: 1px)'.padEnd(1025)).matches)"), std::string("false"));
}
