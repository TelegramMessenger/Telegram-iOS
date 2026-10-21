// The focus model and the user-action pseudo-classes (M1d plan, Task 3): a tap focuses what it hits, focus() and blur()
// move focus with HTML's events, and :hover, :active, :focus and :focus-within match and render.
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

WR_TEST(testTapMovesFocus) {
    RenderEnv env(kTwo);
    CHECK_EQ(env.env().eval("document.activeElement === document.body"), std::string("true"));
    down(env, 40, 25);
    up(env, 40, 25);
    CHECK_EQ(env.env().eval("document.activeElement.id"), std::string("b"));
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("focus:b:- focusin:b:- focusin:w:-"));
    CHECK_EQ(env.env().eval("log.length = 0"), std::string("0"));
    // A tap on what cannot take focus blurs to the body.
    down(env, 130, 25);
    up(env, 130, 25);
    CHECK_EQ(env.env().eval("document.activeElement === document.body"), std::string("true"));
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("blur:b:- focusout:b:- focusout:w:-"));
}

WR_TEST(testFocusAndBlurMethods) {
    RenderEnv env(kTwo);
    CHECK_EQ(env.env().eval("b.focus(); d.focus(); document.activeElement.id"), std::string("b"));
    CHECK_EQ(env.env().eval("d.tabIndex = 0; d.focus(); document.activeElement.id + ':' + b.tabIndex + ':' + "
                            "document.createElement('div').tabIndex"),
             std::string("d:0:-1"));
    CHECK_EQ(env.env().eval("log.slice(-5).join(' ')"),
             std::string("blur:b:d focusout:b:d focusout:w:d focus:d:b focusin:d:b"));
    CHECK_EQ(env.env().eval("d.blur(); document.activeElement === document.body"), std::string("true"));
    CHECK_EQ(env.env().eval("document.querySelector(':focus') === null"), std::string("true"));
    CHECK_EQ(env.env().eval("b.focus(); [document.querySelector(':focus').id, "
                            "document.querySelectorAll(':focus-within').length].join()"),
             std::string("b,4"));
}

WR_TEST(testHoverActiveFocusRender) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} button{position:absolute;left:10px;"
                  "top:10px;width:80px;height:30px;display:block;border:0;background:#eee;color:#000}"
                  "button:hover{background:#00f} button:active{color:#f00} button:focus{outline:1px solid #0f0}"
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

// V4 plan, Task 3b: :focus-within is out of profile 1 (sel.focus), so its rule leaves the sheet and focus renders nothing.
WR_TEST(testFocusWithinRendersNothing) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} #w{width:100px;height:50px}"
                  "#w:focus-within{background:#f00}</style></head><body><div id=w><input id=i></div><script>"
                  "window.i = document.getElementById('i');</script></body></html>");
    const std::string before = env.render().layerTree()->dump();
    CHECK_EQ(env.env().eval("i.focus(); document.activeElement.id"), std::string("i"));
    env.flush();
    CHECK_EQ(env.render().layerTree()->dump(), before);
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
}

WR_TEST(testRemovingTheFocusedElementUpdatesTheRender) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} #w{width:100px;height:50px}"
                  "#w:focus-within{background:#f00}</style></head><body><div id=w><input id=i></div><script>"
                  "window.i = document.getElementById('i'); window.w = document.getElementById('w');</script></body></html>");
    CHECK_EQ(env.env().eval("i.focus(); document.activeElement.id"), std::string("i"));
    env.flush();
    CHECK_EQ(env.env().eval("i.remove(); document.activeElement === document.body"), std::string("true"));
    env.flush();
    auto [layout, input, rebuilt] = wr_test::rebuildDump(env);
    CHECK_EQ(env.render().layerTree()->dump(), rebuilt);
    // HTML's focus fixup: the removed element lost focus for good; putting it back does not refocus it.
    CHECK_EQ(env.env().eval("w.append(i); document.activeElement === document.body"), std::string("true"));
}
