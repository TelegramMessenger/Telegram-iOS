// Taps (M1d plan, Task 2): the host's pointer phases, hit-tested on the runtime's own layout and dispatched as Pointer
// Events, Touch Events and the compatibility mouse events, with the gesture policy's 10 px slop and the click rules.
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
    // Past the double tap's 300 ms: a tap of its own (detail 1).
    env.env().advance(1000);
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
    host.pointer(env.ctx(), PointerPhase::Move, 41, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 41, 40, 1, true);
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
    // The primary's first move past the slop still reaches the gesture arbiter (a drag, no hold), and dispatches nothing.
    CHECK_EQ(env.env().drain(), 3);
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

namespace {

// What the primary press at (x, y) claims (sdk-v1 §5.5): its axes and its holds, as "x", "y", "h" together, or "-".
std::string claimAt(RenderEnv& env, double x, double y, bool primary = true) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, x, y, 7, primary);
    env.env().drain();
    const wr::GestureClaim claim = host.gestureClaim();
    host.pointer(env.ctx(), PointerPhase::Up, x, y, 7, primary);
    env.env().drain();
    std::string axes = std::string(claim.x ? "x" : "") + (claim.y ? "y" : "") + (claim.hold ? "h" : "");
    return axes.empty() ? "-" : axes;
}

} // namespace

/// sdk-v1 §5.5, protocol.md "Touch gestures inside a scrolling host": a press claims horizontal drags when the computed
/// touch-action of its target or an ancestor forbids horizontal panning, or when the widget cancels its pointerdown or
/// touchstart; `none` claims holds too (widget-sandbox v0.1.2, G1). Vertical drags are never claimed (v0.1.3, G2), so a
/// value that allows horizontal panning (pan-x, pan-left) claims nothing.
WR_TEST(testThePressClaimsTheAxesItsTouchActionForbids) {
    RenderEnv env(
        "<!doctype html><html><head><style>body{margin:0;padding:0} div{position:absolute;"
        "top:0;width:40px;height:40px}</style></head><body>"
        "<div id=free style='left:0'></div>"
        "<div id=none style='left:50px;touch-action:none'></div>"
        "<div id=pany style='left:100px;touch-action:pan-y'><div id=inner style='left:0;touch-action:auto'></div></div>"
        "<div id=panx style='left:150px;touch-action:PAN-LEFT'></div>"
        "<div id=both style='left:200px;touch-action:pan-x pan-y'></div>"
        "<div id=pinch style='left:250px;touch-action:pinch-zoom'></div>"
        "<div id=manip style='left:300px;touch-action:manipulation'></div>"
        "<div id=down style='left:350px'></div>"
        "<div id=start style='left:400px'></div>"
        "<script>document.getElementById('down').addEventListener('pointerdown', e => e.preventDefault());"
        "document.getElementById('start').addEventListener('touchstart', e => e.preventDefault());</script>"
        "</body></html>");
    CHECK_EQ(claimAt(env, 20, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 70, 20), std::string("xh"));
    CHECK_EQ(claimAt(env, 120, 20), std::string("x"));
    CHECK_EQ(claimAt(env, 170, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 220, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 270, 20), std::string("x"));
    CHECK_EQ(claimAt(env, 320, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 370, 20), std::string("x"));
    CHECK_EQ(claimAt(env, 420, 20), std::string("x"));
    // A press on nothing claims nothing; a press that is not the primary pointer's claims as the primary's does
    // (multitouch design §5.1: every finger's press answers).
    CHECK_EQ(claimAt(env, 600, 300), std::string("-"));
    CHECK_EQ(claimAt(env, 70, 20, false), claimAt(env, 70, 20));
}

/// widget-sandbox v0.1.2 (G1, gesture_policy's claimOf): touch-action: none on the target or an ancestor, the widget's
/// <html> included, claims holds as well as horizontal drags; a canceled pointerdown claims horizontal drags and never a
/// hold (v0.1.3, G2: never vertical ones).
WR_TEST(testTouchActionNoneClaimsHolds) {
    RenderEnv env(
        "<!doctype html><html><head><style>body{margin:0;padding:0} div{position:absolute;top:0;width:40px;"
        "height:40px}</style></head><body>"
        "<div id=wrap style='left:50px;touch-action:none'><div id=inner style='left:0;touch-action:auto'></div></div>"
        "<div id=down style='left:100px'></div>"
        "<div id=both style='left:150px;touch-action:none'></div>"
        "<script>for (const id of ['down', 'both']) document.getElementById(id).addEventListener('pointerdown', e => "
        "e.preventDefault());</script></body></html>");
    CHECK_EQ(claimAt(env, 70, 20), std::string("xh"));
    CHECK_EQ(claimAt(env, 120, 20), std::string("x"));
    CHECK_EQ(claimAt(env, 170, 20), std::string("xh"));
    RenderEnv root("<!doctype html><html style='touch-action:none'><head><style>body{margin:0}</style></head><body>"
                   "<div style='height:100px'></div></body></html>");
    CHECK_EQ(claimAt(root, 50, 50), std::string("xh"));
}

/// widget-sandbox v0.1.2: a press that starts in the widget's leading 20 px (the left edge) takes no claim, whatever its
/// touch-action: the back gesture starts there.
WR_TEST(testTheLeadingStripTakesNoClaim) {
    RenderEnv env("<!doctype html><html><head><style>body{margin:0;padding:0} #n{position:absolute;left:0;top:0;"
                  "width:100px;height:40px;touch-action:none}</style></head><body><div id=n></div></body></html>");
    CHECK_EQ(claimAt(env, 10, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 19.5, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 20, 20), std::string("xh"));
    CHECK_EQ(claimAt(env, 60, 20), std::string("xh"));
}

/// widget-sandbox v0.1.2's slop (gesture_policy TOUCH_SLOP_PX): a press is still a tap until it moves more than 10 px
/// from its down, as a distance: a move inside is not delivered and the tap clicks, one past it is a drag.
WR_TEST(testTheSlopIsTenPixels) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("window.moves = 0; document.getElementById('a').addEventListener('pointermove', () => moves++); 1"),
             std::string("1"));
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 39, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 39, 40, 1, true);
    env.env().drain();
    CHECK_EQ(env.env().eval("[moves, log.includes('click:a')].join()"), std::string("0,true"));
    CHECK_EQ(env.env().eval("log = []; 1"), std::string("1"));
    host.pointer(env.ctx(), PointerPhase::Down, 30, 40, 1, true);
    host.pointer(env.ctx(), PointerPhase::Move, 38, 48, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, 38, 48, 1, true);
    env.env().drain();
    CHECK_EQ(env.env().eval("[moves, log.includes('click:a')].join()"), std::string("1,false"));
}

/// touch-action is read as the press starts, as browsers fix it at touchstart: a handler that changes it changes the
/// next press, not this one.
WR_TEST(testTheClaimIsTheTouchActionBeforeTheHandlers) {
    RenderEnv env(
        "<!doctype html><html><head><style>body{margin:0;padding:0} #a{position:absolute;left:0;top:0;width:40px;"
        "height:40px}</style></head><body><div id=a></div><script>"
        "document.getElementById('a').addEventListener('pointerdown', e => { e.target.style.touchAction = 'none'; });"
        "</script></body></html>");
    CHECK_EQ(claimAt(env, 20, 20), std::string("-"));
    CHECK_EQ(claimAt(env, 20, 20), std::string("xh"));
}

namespace {

// Whether the primary press at (x, y) takes taps, as "taps" or "-".
std::string takesTapsAt(RenderEnv& env, double x, double y) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, x, y, 7, true);
    env.env().drain();
    const bool takes = host.pressTakesTaps();
    host.pointer(env.ctx(), PointerPhase::Up, x, y, 7, true);
    env.env().drain();
    return takes ? "taps" : "-";
}

} // namespace

/// The client's double tap (sdk-v1 §5.5, decided like message buttons): a press on something the widget handles takes
/// the tap at once and the bubble does not wait for a double tap there; anywhere else a double tap is the bubble's
/// quick reaction. Something to handle: a listener for a press's events on the event's path, an element with activation
/// behaviour outside a disabled control, or a drag claim.
WR_TEST(testAPressTakesTapsWhereTheWidgetHandlesThem) {
    RenderEnv env(
        "<!doctype html><html><head><style>body{margin:0;padding:0} .b{position:absolute;top:0;width:40px;height:40px;"
        "display:block;margin:0;padding:0;border:0}</style></head><body>"
        "<div class=b id=plain style='left:0'></div>"
        "<button class=b style='left:50px'></button>"
        "<a class=b href='https://example.org' style='left:100px'></a>"
        "<div class=b id=listen style='left:150px'><span class=b style='left:0'></span></div>"
        "<div class=b onclick='1' style='left:200px'></div>"
        "<button class=b disabled style='left:250px'></button>"
        "<div class=b style='left:300px;touch-action:none'></div>"
        "<div class=b id=move style='left:350px'></div>"
        "<div class=b id=down style='left:400px'></div>"
        "<script>document.getElementById('listen').addEventListener('click', () => {});"
        "document.getElementById('move').addEventListener('pointermove', () => {});"
        "document.getElementById('down').addEventListener('pointerdown', () => {});</script>"
        "</body></html>");
    CHECK_EQ(takesTapsAt(env, 20, 20), std::string("-"));
    CHECK_EQ(takesTapsAt(env, 70, 20), std::string("taps"));
    CHECK_EQ(takesTapsAt(env, 120, 20), std::string("taps"));
    CHECK_EQ(takesTapsAt(env, 170, 20), std::string("taps"));
    CHECK_EQ(takesTapsAt(env, 220, 20), std::string("taps"));
    CHECK_EQ(takesTapsAt(env, 270, 20), std::string("-"));
    CHECK_EQ(takesTapsAt(env, 320, 20), std::string("taps"));
    CHECK_EQ(takesTapsAt(env, 370, 20), std::string("-"));
    CHECK_EQ(takesTapsAt(env, 420, 20), std::string("taps"));
    CHECK_EQ(takesTapsAt(env, 600, 300), std::string("-"));
    // A listener on the document (event delegation) handles every press.
    CHECK_EQ(env.env().eval("document.addEventListener('pointerup', () => {}); 1"), std::string("1"));
    CHECK_EQ(takesTapsAt(env, 20, 20), std::string("taps"));
}

namespace {

// Two adjacent 50 × 40 boxes at (20, 20) and (70, 20), each logging its pointer events as type:id:pointerId:P (the
// primary pointer) or :S, and its click as click:id.
const char* const kPointers =
    "<!doctype html><html><head><style>body{margin:0;padding:0} #a,#b{position:absolute;top:20px;width:50px;height:40px}"
    "#a{left:20px} #b{left:70px}</style></head><body><div id=a></div><div id=b></div><script>"
    "window.log = []; window.a = document.getElementById('a'); window.b = document.getElementById('b');"
    "for (const t of ['pointerdown','pointermove','pointerup','pointercancel','click']) {"
    "  for (const id of ['a','b']) document.getElementById(id).addEventListener(t, e => log.push(t + ':' + id +"
    "    (e.pointerId === undefined ? '' : ':' + e.pointerId + ':' + (e.isPrimary ? 'P' : 'S'))));"
    "}"
    "</script></body></html>";

void at(RenderEnv& env, PointerPhase phase, double x, double y, int32_t pointerId, bool primary) {
    wr::HostState::of(env.ctx()).pointer(env.ctx(), phase, x, y, pointerId, primary);
    env.env().drain();
}

} // namespace

/// Multitouch (design §5.1): each finger is its own pointer, pressing its own target; lifting one disturbs no other.
WR_TEST(testTwoPointersPressTwoTargets) {
    RenderEnv env(kPointers);
    at(env, PointerPhase::Down, 40, 40, 1, true);
    at(env, PointerPhase::Down, 90, 40, 2, false);
    at(env, PointerPhase::Up, 90, 40, 2, false);
    at(env, PointerPhase::Up, 40, 40, 1, true);
    CHECK_EQ(log(env), std::string("pointerdown:a:1:P pointerdown:b:2:S pointerup:b:2:S pointerup:a:1:P click:a"));
}

/// A capture holds for its own pointer: another finger's events stay at that finger's target.
WR_TEST(testACaptureHoldsForItsPointerOnly) {
    RenderEnv env(kPointers);
    CHECK_EQ(env.env().eval("a.onpointerdown = e => a.setPointerCapture(e.pointerId);"
                            "b.onpointerdown = e => { window.held = a.hasPointerCapture(e.pointerId); }; 1"),
             std::string("1"));
    at(env, PointerPhase::Down, 40, 40, 1, true);
    at(env, PointerPhase::Down, 90, 40, 2, false);
    at(env, PointerPhase::Move, 90, 40, 1, true);
    at(env, PointerPhase::Move, 110, 40, 2, false);
    at(env, PointerPhase::Up, 90, 40, 1, true);
    at(env, PointerPhase::Up, 110, 40, 2, false);
    CHECK_EQ(env.env().eval("String(held)"), std::string("false"));
    CHECK_EQ(env.env().eval("log.filter(e => !e.startsWith('pointerdown')).join(' ')"),
             std::string("pointermove:a:1:P pointermove:b:2:S pointerup:a:1:P pointerup:b:2:S"));
}

/// Only the primary pointer clicks, as touch browsers fire the click for the primary touch alone.
WR_TEST(testOnlyThePrimaryClicks) {
    RenderEnv env(kPointers);
    at(env, PointerPhase::Down, 40, 40, 1, true);
    at(env, PointerPhase::Down, 90, 40, 2, false);
    at(env, PointerPhase::Up, 90, 40, 2, false);
    at(env, PointerPhase::Up, 40, 40, 1, true);
    CHECK_EQ(env.env().eval("log.filter(e => e.startsWith('click')).join(' ')"), std::string("click:a"));
}

/// At most kMaxPointers fingers: a sixth is dropped whole, and its up ends no one else's press.
WR_TEST(testASixthPointerIsDropped) {
    RenderEnv env(kPointers);
    for (int32_t id = 1; id <= 6; id++) {
        at(env, PointerPhase::Down, 40, 40, id, id == 1);
    }
    CHECK_EQ(env.env().eval("String(log.filter(e => e.startsWith('pointerdown')).length)"), std::string("5"));
    at(env, PointerPhase::Up, 40, 40, 6, false);
    CHECK_EQ(env.env().eval("String(log.filter(e => e.startsWith('pointerup')).length)"), std::string("0"));
    for (int32_t id = 1; id <= 5; id++) {
        at(env, PointerPhase::Up, 40, 40, id, id == 1);
    }
    CHECK_EQ(env.env().eval("String(log.filter(e => e.startsWith('pointerup')).length)"), std::string("5"));
}

/// Every held element looks pressed until its own finger lifts (a second finger on it holds it too); hover follows the
/// primary pointer.
WR_TEST(testEveryHeldElementIsActive) {
    RenderEnv env(kPointers);
    const auto state = [&] {
        return env.env().eval("['#a:active', '#b:active', '#a:hover', '#b:hover'].map(s => !!document.querySelector(s)).join()");
    };
    at(env, PointerPhase::Down, 40, 40, 1, true);
    at(env, PointerPhase::Down, 90, 40, 2, false);
    CHECK_EQ(state(), std::string("true,true,true,false"));
    at(env, PointerPhase::Up, 90, 40, 2, false);
    CHECK_EQ(state(), std::string("true,false,true,false"));
    at(env, PointerPhase::Down, 40, 40, 2, false);
    at(env, PointerPhase::Up, 40, 40, 1, true);
    CHECK_EQ(state(), std::string("true,false,true,false"));
    at(env, PointerPhase::Up, 40, 40, 2, false);
    CHECK_EQ(state(), std::string("false,false,true,false"));
}

/// A press's :active is its own, not its element's: a press whose element left the document and came back ends without
/// taking the element's :active from a later press on it.
WR_TEST(testAPressEndsOnlyItsOwnActive) {
    RenderEnv env(kPointers);
    const auto active = [&] { return env.env().eval("String(!!document.querySelector('#a:active'))"); };
    at(env, PointerPhase::Down, 40, 40, 1, true);
    CHECK_EQ(env.env().eval("(() => { const next = a.nextSibling; a.remove(); document.body.insertBefore(a, next); return 1; })()"),
             std::string("1"));
    CHECK_EQ(active(), std::string("false"));
    at(env, PointerPhase::Down, 40, 40, 2, false);
    CHECK_EQ(active(), std::string("true"));
    at(env, PointerPhase::Up, 40, 40, 1, true);
    CHECK_EQ(active(), std::string("true"));
    at(env, PointerPhase::Up, 40, 40, 2, false);
    CHECK_EQ(active(), std::string("false"));
}

/// Each finger's press is a press of its own (sdk-v1 §2.5): each may open a link once.
WR_TEST(testEachPressActivatesOnce) {
    RenderEnv env(kPointers);
    CHECK_EQ(env.env().eval("for (const id of ['a', 'b']) document.getElementById(id).addEventListener('pointerup', () => "
                            "TelegramWidget.openLink('https://example.org/' + id)); 1"),
             std::string("1"));
    at(env, PointerPhase::Down, 40, 40, 1, true);
    at(env, PointerPhase::Down, 90, 40, 2, false);
    at(env, PointerPhase::Up, 90, 40, 2, false);
    at(env, PointerPhase::Up, 40, 40, 1, true);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(2));
}

namespace {

void mousePress(RenderEnv& env, double x, double y, double toX, int16_t button) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, x, y, 3, true, twidget::PointerKind::Mouse, button);
    if (toX != x) {
        host.pointer(env.ctx(), PointerPhase::Move, toX, y, 3, true, twidget::PointerKind::Mouse, button);
    }
    host.pointer(env.ctx(), PointerPhase::Up, toX, y, 3, true, twidget::PointerKind::Mouse, button);
    env.env().drain();
}

} // namespace

/// An iPad pointer is a mouse (widget-sandbox v0.1.2): its press is pointer events with pointerType mouse and the mouse
/// events in a mouse's own order, no touch events, and its click comes on the up over the down's target, moved or not.
WR_TEST(testAMousePressIsAMouse) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("window.p = []; document.getElementById('a').addEventListener('pointerdown', e => "
                            "p.push([e.pointerType, e.button, e.buttons, e.isPrimary].join())); 1"),
             std::string("1"));
    mousePress(env, 40, 40, 60, 0);
    CHECK_EQ(log(env), std::string("pointerdown:a mousedown:a pointerup:a mouseup:a click:a"));
    CHECK_EQ(env.env().eval("p.join(' ')"), std::string("mouse,0,1,true"));
}

/// The secondary button's press is the mouse's too, with button 2 and buttons 2, and makes no click. Where no hold is
/// claimed it is the message's menu (the policy's bubble verdict at the down), so the widget's press ends there with the
/// verdict's cancel: pointercancel, and nothing more of it.
WR_TEST(testASecondaryMouseButtonClicksNot) {
    RenderEnv env(kBoxes);
    CHECK_EQ(env.env().eval("window.p = []; document.getElementById('a').addEventListener('pointerdown', e => "
                            "p.push([e.pointerType, e.button, e.buttons].join())); 1"),
             std::string("1"));
    mousePress(env, 40, 40, 40, 2);
    CHECK_EQ(log(env), std::string("pointerdown:a mousedown:a pointercancel:a"));
    CHECK_EQ(env.env().eval("p.join(' ')"), std::string("mouse,2,2"));
}

namespace {

// Two adjacent 50 × 40 boxes (#a at x 30, #b at x 80) and a touch-action: none one (#n at x 140), and a log of their
// clicks (with detail), dblclicks and contextmenus.
const char* const kGestures =
    "<!doctype html><html><head><style>body{margin:0;padding:0} div{position:absolute;top:0;width:50px;height:40px}"
    "#a{left:30px} #b{left:80px} #n{left:140px;touch-action:none}</style></head><body><div id=a></div><div id=b></div>"
    "<div id=n></div><script>window.log = [];"
    "for (const t of ['click', 'dblclick', 'contextmenu'])"
    "  for (const id of ['a', 'b', 'n']) document.getElementById(id).addEventListener(t, e => log.push(t + ':' + id +"
    "    (t === 'contextmenu' ? '' : ':' + e.detail)));"
    "</script></body></html>";

void tapAt(RenderEnv& env, double x, double y) {
    tap(env, x, y);
}

std::string drained(RenderEnv& env) {
    const std::string value = env.env().eval("log.join(' ')");
    env.env().eval("log = []; 1");
    return value;
}

} // namespace

/// widget-sandbox v0.1.2 (G1, the gesture policy's arbiter): a double tap over the widget is the widget's on every
/// element, touch-action auto as none: both clicks (the second with detail 2), then dblclick.
WR_TEST(testADoubleTapIsADblclickOnEveryElement) {
    RenderEnv env(kGestures);
    tapAt(env, 50, 20);
    env.env().advance(100);
    tapAt(env, 50, 20);
    CHECK_EQ(drained(env), std::string("click:a:1 click:a:2 dblclick:a:2"));
    env.env().advance(1000);
    tapAt(env, 160, 20);
    env.env().advance(100);
    tapAt(env, 162, 22);
    CHECK_EQ(drained(env), std::string("click:n:1 click:n:2 dblclick:n:2"));
}

/// A double tap's second down comes at most 300 ms after the first up and lands at most 40 px from the first down; it
/// may be on another element (the dblclick goes to the second tap's).
WR_TEST(testADoubleTapIsCloseAndQuick) {
    RenderEnv env(kGestures);
    tapAt(env, 50, 20);
    env.env().advance(350);
    tapAt(env, 50, 20);
    CHECK_EQ(drained(env), std::string("click:a:1 click:a:1"));
    env.env().advance(1000);
    tapAt(env, 40, 20);
    env.env().advance(100);
    tapAt(env, 95, 20);
    CHECK_EQ(drained(env), std::string("click:a:1 click:b:1"));
    env.env().advance(1000);
    tapAt(env, 65, 20);
    env.env().advance(100);
    tapAt(env, 95, 20);
    CHECK_EQ(drained(env), std::string("click:a:1 click:b:2 dblclick:b:2"));
}

/// Only a tap starts a double tap: a drag past the slop, then a quick tap, is a tap alone.
WR_TEST(testOnlyATapStartsADoubleTap) {
    RenderEnv env(kGestures);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 40, 20, 7, true);
    host.pointer(env.ctx(), PointerPhase::Move, 60, 20, 7, true);
    host.pointer(env.ctx(), PointerPhase::Up, 60, 20, 7, true);
    env.env().drain();
    env.env().advance(100);
    tapAt(env, 60, 20);
    CHECK_EQ(drained(env), std::string("click:a:1"));
}

/// A hold on touch-action: none is the widget's: within the slop at 500 ms it gets contextmenu (a drift inside the slop
/// keeps it a hold), and its up makes no click.
WR_TEST(testAHoldOnNoneGetsContextmenu) {
    RenderEnv env(kGestures);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 160, 20, 7, true);
    host.pointer(env.ctx(), PointerPhase::Move, 165, 20, 7, true);
    env.env().drain();
    env.env().advance(499);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string(""));
    env.env().advance(1);
    CHECK_EQ(env.env().eval("log.join(' ')"), std::string("contextmenu:n"));
    env.env().advance(200);
    host.pointer(env.ctx(), PointerPhase::Up, 165, 20, 7, true);
    env.env().drain();
    CHECK_EQ(drained(env), std::string("contextmenu:n"));
}

/// A hold on auto is the bubble's (its menu cancels the press on the client): the widget gets no contextmenu, and a
/// held press that the host lets end makes no click.
WR_TEST(testAHoldOnAutoClicksNot) {
    RenderEnv env(kGestures);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 50, 20, 7, true);
    env.env().drain();
    env.env().advance(600);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 20, 7, true);
    env.env().drain();
    CHECK_EQ(drained(env), std::string(""));
    tapAt(env, 50, 20);
    CHECK_EQ(drained(env), std::string("click:a:1"));
}

/// The arbiter is the primary pointer's: a second finger holding touch-action: none gets no contextmenu.
WR_TEST(testASecondFingersHoldGetsNoContextmenu) {
    RenderEnv env(kGestures);
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 50, 20, 7, true);
    host.pointer(env.ctx(), PointerPhase::Down, 160, 20, 8, false);
    env.env().drain();
    env.env().advance(600);
    host.pointer(env.ctx(), PointerPhase::Up, 160, 20, 8, false);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 20, 7, true);
    env.env().drain();
    CHECK_EQ(drained(env), std::string(""));
}

/// The host retracts a press it started for the bubble's question when a pointer's touch presses there instead (the hover
/// hint missed): the widget's press ends as a cancel, but the double click it came between goes on. A cancel proper
/// still ends it (the policy: no double tap continues a cancelled press).
WR_TEST(testARetractedPressKeepsADoubleClick) {
    RenderEnv env(kGestures);
    wr::HostState& host = wr::HostState::of(env.ctx());
    mousePress(env, 50, 20, 50, 0);
    env.env().advance(100);
    host.pointer(env.ctx(), PointerPhase::Down, 50, 20, 4, true);
    host.pointer(env.ctx(), PointerPhase::Retract, 50, 20, 4, true);
    env.env().drain();
    mousePress(env, 50, 20, 50, 0);
    CHECK_EQ(drained(env), std::string("click:a:1 click:a:2 dblclick:a:2"));
    env.env().advance(1000);
    mousePress(env, 50, 20, 50, 0);
    env.env().advance(100);
    host.pointer(env.ctx(), PointerPhase::Down, 50, 20, 5, true);
    host.pointer(env.ctx(), PointerPhase::Cancel, 50, 20, 5, true);
    env.env().drain();
    mousePress(env, 50, 20, 50, 0);
    CHECK_EQ(drained(env), std::string("click:a:1 click:a:1"));
}

/// A mouse's secondary click on touch-action: none is the widget's contextmenu, right away; elsewhere it is the
/// bubble's menu and the widget gets none.
WR_TEST(testAMouseRightClickOnNoneIsAContextmenu) {
    RenderEnv env(kGestures);
    mousePress(env, 160, 20, 160, 2);
    CHECK_EQ(drained(env), std::string("contextmenu:n"));
    env.env().advance(1000);
    mousePress(env, 50, 20, 50, 2);
    CHECK_EQ(drained(env), std::string(""));
}
