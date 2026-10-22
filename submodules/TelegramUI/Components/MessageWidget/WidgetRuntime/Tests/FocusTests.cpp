// Profile 1 has no focus (V4 plan, Task 8; RB §8.1): a tap moves no focus, focus() and blur() do nothing and fire
// nothing, :focus and :focus-within never match, and document.activeElement is always the body. :hover and :active
// still match and render.
#include <string>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Sources/Render/LayerTree.h"
#include "Sources/Render/RenderTree.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr_test::RenderEnv;

namespace {

const char* const kTwo =
    "<!doctype html><html><head><style>body{margin:0;padding:0} #b,#d{position:absolute;top:10px;width:80px;"
    "height:30px;display:block} #b{left:10px} #d{left:100px}</style></head><body><div id=w><button id=b>b</button>"
    "</div><div id=d>d</div><script>window.log = []; for (const e of document.querySelectorAll('[id]')) window[e.id] = e;"
    "for (const k of ['focus','blur','focusin','focusout']) for (const id of ['b','d','w'])"
    "  document.getElementById(id).addEventListener(k, e => log.push(k + ':' + id + ':' +"
    "    (e.relatedTarget ? e.relatedTarget.id : '-')));"
    "</script></body></html>";

void down(RenderEnv& env, double x, double y) {
    wr::HostState::of(env.ctx()).pointer(env.ctx(), PointerPhase::Down, x, y, 1, true);
    env.env().drain();
}

void up(RenderEnv& env, double x, double y) {
    wr::HostState::of(env.ctx()).pointer(env.ctx(), PointerPhase::Up, x, y, 1, true);
    env.env().drain();
}

} // namespace

WR_TEST(testATapMovesNoFocus) {
    RenderEnv env(kTwo);
    down(env, 40, 25);
    up(env, 40, 25);
    CHECK_EQ(env.env().eval("document.activeElement === document.body"), std::string("true"));
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string(""));
}

WR_TEST(testFocusAndBlurDoNothing) {
    RenderEnv env(kTwo);
    CHECK_EQ(env.env().eval("b.focus(); [document.activeElement === document.body, log.length].join()"),
             std::string("true,0"));
    CHECK_EQ(env.env().eval("b.blur(); d.focus(); d.blur(); [document.activeElement === document.body, log.length].join()"),
             std::string("true,0"));
    CHECK_EQ(env.env().eval("document.querySelector(':focus') === null && document.querySelector(':focus-within') === null"),
             std::string("true"));
    // tabIndex still reflects the attribute.
    CHECK_EQ(env.env().eval("d.tabIndex = 0; [d.tabIndex, d.getAttribute('tabindex')].join()"), std::string("0,0"));
}

WR_TEST(testHoverActiveRender) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} button{position:absolute;left:10px;"
                  "top:10px;width:80px;height:30px;display:block;border:0;background:#eee;color:#000}"
                  "button:hover{background:#00f} button:active{color:#f00}"
                  "</style></head><body><button>b</button></body></html>");
    const std::string before = env.render().layerTree()->dump();
    down(env, 40, 25);
    const std::string pressed = env.render().layerTree()->dump();
    CHECK(pressed != before);
    CHECK_EQ(env.env().eval("document.querySelector('button:active') !== null"), std::string("true"));
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layoutDump(), layout);
    CHECK_EQ(pressed, rebuilt);
    up(env, 40, 25);
    const std::string released = env.render().layerTree()->dump();
    CHECK(released != pressed);
    CHECK(released != before);
    // The hover stays after the up, as touch browsers keep it; the press is over.
    CHECK_EQ(env.env().eval("[!!document.querySelector('button:hover'), !!document.querySelector('button:active')].join()"),
             std::string("true,false"));
    auto [layout2, input2, rebuilt2] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layoutDump(), layout2);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt2);
}

// :focus-within is out of profile 1 (sel.focus, V4 plan, Task 3b), and nothing takes focus (Task 8).
WR_TEST(testFocusWithinNeverMatches) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} #w{width:100px;height:50px}"
                  "#w:focus-within{background:#f00}</style></head><body><div id=w><button id=i>i</button></div><script>"
                  "window.i = document.getElementById('i');</script></body></html>");
    const std::string before = env.render().layerTree()->dump();
    CHECK_EQ(env.env().eval("i.focus(); document.activeElement === document.body"), std::string("true"));
    env.flush();
    CHECK_EQ(env.render().layerTree()->dump(), before);
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
}
