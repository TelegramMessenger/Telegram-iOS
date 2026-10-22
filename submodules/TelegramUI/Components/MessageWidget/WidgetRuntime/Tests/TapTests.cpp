// Taps (M1d plan, Task 2): the host's pointer phases, hit-tested on the runtime's own layout and dispatched as Pointer
// Events, Touch Events and the compatibility mouse events, with the 8 px slop and the click rules.
#include <string>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr_test::RenderEnv;

namespace {

// Two adjacent 50 × 40 boxes at (20, 20) and (70, 20), and a log of every pointer, touch and mouse event at them.
const char* const kBoxes =
    "<!doctype html><html><head><style>body{margin:0;padding:0} #a,#b{position:absolute;top:20px;width:50px;height:40px}"
    "#a{left:20px} #b{left:70px}</style></head><body><div id=a></div><div id=b></div><script>"
    "window.log = [];"
    "for (const t of ['pointerdown','pointerup','pointercancel','touchstart','touchend','touchcancel','mousedown',"
    "'mouseup','click']) {"
    "  for (const id of ['a','b']) document.getElementById(id).addEventListener(t, e => log.push(t + ':' + id +"
    "    (e.isTrusted ? '' : '!')));"
    "}"
    "</script></body></html>";

void tap(RenderEnv& env, double x, double y, bool primary = true) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, x, y, 7, primary);
    host.pointer(env.ctx(), PointerPhase::Up, x, y, 7, primary);
    env.env().drain();
}

std::string log(RenderEnv& env) {
    return env.env().eval("log.join(' ')");
}

} // namespace

WR_TEST(testTapDispatchesInOrder) {
    RenderEnv env(kBoxes);
    tap(env, 40, 40);
    // Pointer and touch events at down and up; the compatibility mouse events and the click after touchend, as touch
    // browsers fire them.
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a mousedown:a mouseup:a click:a"));
    CHECK_EQ(env.env().eval("let c; document.getElementById('a').onclick = e => c = [e.clientX, e.clientY, "
                            "e.pageX, e.button, e.detail, e.view === window].join(); 1"),
             std::string("1"));
    tap(env, 41, 42);
    CHECK_EQ(env.env().eval("c"), std::string("41,42,41,0,1,true"));
    CHECK_EQ(env.env().eval("let p; document.getElementById('a').onpointerdown = e => p = [e.pointerId, e.pointerType, "
                            "e.isPrimary, e instanceof MouseEvent].join(); 1"),
             std::string("1"));
    tap(env, 40, 40);
    CHECK_EQ(env.env().eval("p"), std::string("7,touch,true,true"));
    CHECK_EQ(env.env().eval("let t; document.getElementById('a').ontouchstart = e => t = [e.touches.length, "
                            "e.changedTouches.item(0).identifier, e.changedTouches[0].target.id].join(); 1"),
             std::string("1"));
    tap(env, 40, 40);
    CHECK_EQ(env.env().eval("t"), std::string("1,7,a"));
}

/// Pointer Events' setPointerCapture (profile 1's input.drag): an element takes a press's pointer events from the next
/// one on, gotpointercapture before it and lostpointercapture after the pointerup; touch events stay with the touch's
/// target. Four of the user's games (2026-10-22, Fixtures 11-14) call it on every button press.
WR_TEST(testSetPointerCaptureTakesThePress) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("const a = document.getElementById('a'), b = document.getElementById('b'); window.cap = [];"
                            "for (const t of ['gotpointercapture', 'lostpointercapture', 'pointermove', 'pointerup', "
                            "'touchmove', 'touchend']) for (const el of [a, b]) el.addEventListener(t, e => "
                            "cap.push(t + ':' + el.id));"
                            "a.addEventListener('pointerdown', e => { b.setPointerCapture(e.pointerId); "
                            "cap.push('has:' + b.hasPointerCapture(e.pointerId) + a.hasPointerCapture(e.pointerId)); }); 1"),
             std::string("1"));
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 7, true);
    host.pointer(env.ctx(), PointerPhase::Move, 45, 40, 7, true);
    host.pointer(env.ctx(), PointerPhase::Up, 45, 40, 7, true);
    env.env().drain();
    CHECK_EQ(env.env().eval("cap.join(' ')"),
             std::string("has:truefalse gotpointercapture:b pointermove:b touchmove:a pointerup:b lostpointercapture:b "
                         "touchend:a"));
    CHECK_EQ(env.env().eval("b.hasPointerCapture(7)"), std::string("false"));
}

/// A button that captures its own press, as the games' do, still clicks; a released capture leaves the press with its
/// target.
WR_TEST(testACapturedPressStillClicksAndReleaseRestoresTheTarget) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("const a = document.getElementById('a'), b = document.getElementById('b');"
                            "a.onpointerdown = e => a.setPointerCapture(e.pointerId); 1"),
             std::string("1"));
    tap(env, 40, 40);
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a mousedown:a mouseup:a click:a"));
    CHECK_EQ(env.env().eval("log.length = 0; a.onpointerdown = e => { b.setPointerCapture(e.pointerId); "
                            "b.releasePointerCapture(e.pointerId); window.held = b.hasPointerCapture(e.pointerId); }; 1"),
             std::string("1"));
    tap(env, 40, 40);
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a mousedown:a mouseup:a click:a"));
    CHECK_EQ(env.env().eval("held"), std::string("false"));
}

/// No active pointer with that id is a NotFoundError, for set and release alike; a disconnected element is an
/// InvalidStateError.
WR_TEST(testPointerCaptureErrors) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("const a = document.getElementById('a'); const name = f => { try { f(); return 'ok'; } "
                            "catch (e) { return e.name; } };"
                            "[name(() => a.setPointerCapture(7)), name(() => a.releasePointerCapture(7)), "
                            "a.hasPointerCapture(7)].join()"),
             std::string("NotFoundError,NotFoundError,false"));
    CHECK_EQ(env.env().eval("a.onpointerdown = e => { window.errors = [name(() => a.setPointerCapture(e.pointerId + 1)), "
                            "name(() => document.createElement('div').setPointerCapture(e.pointerId))].join(); }; 1"),
             std::string("1"));
    tap(env, 40, 40);
    CHECK_EQ(env.env().eval("errors"), std::string("NotFoundError,InvalidStateError"));
}

WR_TEST(testMoveOverTheSlopCancelsTheClick) {
    RenderEnv env(kBoxes);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 38, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 38, 40, 1, true);
    env.env().drain();
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a"));
    CHECK_EQ(env.env().eval("log.length = 0"), std::string("0"));
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 37, 46, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 37, 46, 1, true);
    env.env().drain();
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a mousedown:a mouseup:a click:a"));
}

WR_TEST(testUpOverAnotherTargetDoesNotClick) {
    RenderEnv env(kBoxes);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 68, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 72, 40, 1, true);
    env.env().drain();
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a"));
}

WR_TEST(testDisabledButtonDoesNotClick) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} button{position:absolute;left:0;top:0;"
                  "width:100px;height:40px}</style></head><body><button disabled><span>x</span></button><script>"
                  "window.clicks = 0; document.querySelector('button').addEventListener('click', () => clicks++);"
                  "document.body.addEventListener('click', () => clicks++);</script></body></html>");
    tap(env, 50, 20);
    CHECK_EQ(env.env().eval("clicks"), std::string("0"));
}

WR_TEST(testNonPrimaryDoesNotClick) {
    RenderEnv env(kBoxes);
    tap(env, 40, 40, false);
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a"));
}

WR_TEST(testMovesOnlyWhenListened) {
    RenderEnv env(kBoxes);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 50, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 40, 1, true);
    CHECK_EQ(env.env().drain(), 2);
    CHECK_EQ(env.env().eval("window.moves = []; document.body.addEventListener('pointermove', e => "
                            "moves.push(e.target.id + ':' + e.clientX)); 1"),
             std::string("1"));
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 31, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 80, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 80, 40, 1, true);
    // The move under the slop is dropped; the one past it goes to the down target, wherever the pointer is.
    CHECK_EQ(env.env().drain(), 3);
    CHECK_EQ(env.env().eval("moves.join()"), std::string("a:80"));
}

WR_TEST(testPreventDefaultOnTouchstartCancelsMouseEvents) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("document.getElementById('a').addEventListener('touchstart', e => e.preventDefault()); 1"),
             std::string("1"));
    tap(env, 40, 40);
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointerup:a touchend:a"));
}

WR_TEST(testCancelEndsTheTap) {
    RenderEnv env(kBoxes);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Cancel, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 30, 40, 1, true);
    env.env().drain();
    CHECK_EQ(log(env), std::string("pointerdown:a touchstart:a pointercancel:a touchcancel:a"));
}

WR_TEST(testCreateEventKnowsTheUIEvents) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("[document.createEvent('MouseEvent') instanceof MouseEvent, "
                            "document.createEvent('mouseevents') instanceof MouseEvent, "
                            "document.createEvent('TouchEvent') instanceof TouchEvent, "
                            "document.createEvent('UIEvents') instanceof UIEvent, "
                            "document.createEvent('FocusEvent') instanceof FocusEvent].join()"),
             std::string("true,true,true,true,true"));
    CHECK_EQ(env.env().eval("new PointerEvent('x', {pointerId: 3, clientX: 5}).pointerId + ':' + "
                            "new PointerEvent('x', {clientX: 5}).clientX + ':' + new MouseEvent('click').isTrusted"),
             std::string("3:5:false"));
    CHECK_EQ(env.env().eval("new Touch({identifier: 2, target: document.body, clientX: 9}).clientX"), std::string("9"));
}

/// Fidelity plan, Task 4 (input.drag): a move's movementX/movementY is its delta from the last position delivered, the
/// down point for the first (moves inside the slop are not delivered, and the first delivered one carries them), so the
/// moves of a drag add up to its distance; down and up carry 0. Script can set them through MouseEventInit.
WR_TEST(testMovementAddsUpToTheDrag) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0} #k{width:300px;height:40px}</style></head><body>"
                  "<div id=k></div><script>window.log = []; const k = document.getElementById('k');"
                  "for (const type of ['pointerdown', 'pointermove', 'pointerup'])"
                  "  k.addEventListener(type, e => log.push(type + ':' + e.movementX + ',' + e.movementY));"
                  "</script></body></html>");
    auto& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 10, 10, 7, true);
    host.pointer(env.ctx(), PointerPhase::Move, 13, 11, 7, true);   // inside the slop: not delivered
    host.pointer(env.ctx(), PointerPhase::Move, 30, 12, 7, true);
    host.pointer(env.ctx(), PointerPhase::Move, 170, 14, 7, true);
    host.pointer(env.ctx(), PointerPhase::Up, 170, 14, 7, true);
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join(' ')"),
             std::string("pointerdown:0,0 pointermove:20,2 pointermove:140,2 pointerup:0,0"));
    CHECK_EQ(env.env().eval("const m = new MouseEvent('x', {movementX: 3, movementY: -4}); [m.movementX, m.movementY].join()"),
             std::string("3,-4"));
}
