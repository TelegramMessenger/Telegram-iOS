// Activation behaviour and default actions (M1d plan, Task 3): what a click does to a checkbox, a radio, a label, a
// summary, a submit button and a link, as HTML runs them after the click's dispatch.
#include <string>
#include <utility>
#include <vector>

#include "Sources/Events/Taps.h"
#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"
#include "Tests/RenderHarness.h"

using wr::PointerPhase;
using wr_test::RenderEnv;

namespace {

// Every element absolutely placed at a known box, so a tap hits it: `#t` at (10, 10) 100 × 30.
std::string page(const std::string& body, const std::string& script = "") {
    return "<!doctype html><html><head><style>body{margin:0;padding:0} #t{position:absolute;left:10px;top:10px;"
           "width:100px;height:30px;display:block}</style></head><body>" +
           body +
           // The window's named properties wait for M2: the ids become globals here.
           "<script>window.log = []; for (const e of document.querySelectorAll('[id]')) window[e.id] = e;" + script +
           "</script></body></html>";
}

// Profile 1 drops every form control from the render (V4 plan, Task 4), so a control has no box to tap: its activation,
// the DOM's own, runs from click().
void clickT(RenderEnv& env) {
    env.env().eval("t.click(); 1");
    env.env().drain();
}

void tapAt(RenderEnv& env, double x = 50, double y = 25) {
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, x, y, 1, true);
    host.pointer(env.ctx(), PointerPhase::Up, x, y, 1, true);
    env.env().drain();
}

} // namespace

WR_TEST(testCheckboxTogglesAndRevertsWhenCancelled) {
    RenderEnv env(page("<input id=t type=checkbox>",
                       "const t = document.getElementById('t');"
                       "for (const k of ['input','change']) t.addEventListener(k, () => log.push(k));"));
    clickT(env);
    CHECK_EQ(env.env().eval("t.checked + ':' + log.join()"), std::string("true:input,change"));
    clickT(env);
    CHECK_EQ(env.env().eval("t.checked"), std::string("false"));
    CHECK_EQ(env.env().eval("log.length = 0; t.onclick = () => false; 1"), std::string("1"));
    clickT(env);
    CHECK_EQ(env.env().eval("t.checked + ':' + log.join()"), std::string("false:"));
    // A listener sees the new state during the click (the toggle comes before the listeners).
    CHECK_EQ(env.env().eval("t.onclick = () => log.push('saw ' + t.checked); 1"), std::string("1"));
    clickT(env);
    CHECK_EQ(env.env().eval("log.join()"), std::string("saw true,input,change"));
}

WR_TEST(testRadioChecksOneOfItsGroup) {
    RenderEnv env(page("<input id=t type=radio name=g><input id=u type=radio name=g checked>"
                       "<input id=v type=radio name=other checked>"));
    clickT(env);
    CHECK_EQ(env.env().eval("[t.checked, u.checked, v.checked].join()"), std::string("true,false,true"));
}

WR_TEST(testLabelClicksItsControl) {
    RenderEnv env(page("<label id=t>check <input id=c type=checkbox style=\"position:absolute;left:200px\"></label>"
                       "<label for=d style=\"position:absolute;left:10px;top:60px;width:100px;height:30px;"
                       "display:block\">d</label><input id=d type=checkbox style=\"position:absolute;left:300px\">"));
    tapAt(env);
    CHECK_EQ(env.env().eval("c.checked"), std::string("true"));
    tapAt(env, 50, 75);
    CHECK_EQ(env.env().eval("d.checked"), std::string("true"));
}

WR_TEST(testSummaryTogglesDetails) {
    RenderEnv env(page("<details id=dd><summary id=t>s</summary>body</details>",
                       "dd.addEventListener('toggle', () => log.push('toggle:' + dd.open));"));
    tapAt(env);
    CHECK_EQ(env.env().eval("dd.open + ':' + log.join()"), std::string("true:toggle:true"));
    tapAt(env);
    CHECK_EQ(env.env().eval("dd.open"), std::string("false"));
}

WR_TEST(testSubmitIsCancelled) {
    RenderEnv env(page("<form id=f><button id=t>go</button></form>",
                       "window.ev = null; f.addEventListener('submit', e => { ev = e; log.push('submit'); });"));
    tapAt(env);
    CHECK_EQ(env.env().eval("log.join() + ':' + ev.defaultPrevented"), std::string("submit:true"));
    // type=button submits nothing.
    CHECK_EQ(env.env().eval("log.length = 0; t.type = 'button'; t.getAttribute('type')"), std::string("button"));
    tapAt(env);
    CHECK_EQ(env.env().eval("log.length"), std::string("0"));
}

WR_TEST(testLinkTapCallsOpenLink) {
    RenderEnv env(page("<a id=t href=\"https://t.me/x\"><span>go</span></a>"
                       "<a href=\"#top\" style=\"position:absolute;left:10px;top:60px;width:100px;height:30px;display:block\">f</a>"
                       "<a href=\"javascript:void 0\" style=\"position:absolute;left:10px;top:110px;width:100px;"
                       "height:30px;display:block\">j</a>"));
    tapAt(env);
    tapAt(env, 50, 75);
    tapAt(env, 50, 125);
    // SDK v1 §2.5: a Telegram host goes to openTelegramLink (LinksTests has the routes).
    const std::vector<std::pair<std::string, std::string>> expected = {{"openTelegramLink", "[\"https://t.me/x\"]"}};
    CHECK(env.env().host().bridgeCalls == expected);
    // A canceled click opens nothing.
    CHECK_EQ(env.env().eval("t.onclick = e => e.preventDefault(); 1"), std::string("1"));
    tapAt(env);
    CHECK_EQ(env.env().host().bridgeCalls.size(), size_t(1));
}

WR_TEST(testClickMethodRunsActivation) {
    RenderEnv env(page("<input id=t type=checkbox><input id=dis type=checkbox disabled>"));
    CHECK_EQ(env.env().eval("t.click(); dis.click(); [t.checked, dis.checked].join()"), std::string("true,false"));
    CHECK_EQ(env.env().eval("let trusted; t.onclick = e => trusted = e.isTrusted; t.click(); trusted"),
             std::string("false"));
}

WR_TEST(testLabelWrappingATextControlDoesNotRecurse) {
    // A label's activation clicks its control; a click at (or inside) the control itself does nothing more. A text
    // input, a select and a textarea have no activation of their own, so without that rule the control's click comes
    // back to the label for ever (a native recursion no script limit stops).
    RenderEnv env(page("<label id=t>Name <input id=x style=\"position:absolute;left:200px;top:10px;width:50px;"
                       "height:20px\"></label><label for=s style=\"position:absolute;left:10px;top:60px;width:100px;"
                       "height:30px;display:block\">s</label><select id=s style=\"position:absolute;left:300px\"></select>"
                       "<label style=\"position:absolute;left:10px;top:110px;width:100px;height:30px;display:block\">"
                       "a<textarea id=ta style=\"position:absolute;left:300px;top:200px\"></textarea></label>",
                       "window.clicks = {x: 0, s: 0, ta: 0};"
                       "for (const id of ['x', 's', 'ta']) document.getElementById(id).addEventListener('click', "
                       "() => clicks[id]++);"));
    // The labels are tapped (each renders as a span with a box); the controls have none under profile 1.
    tapAt(env);
    tapAt(env, 220, 20);
    tapAt(env, 50, 75);
    tapAt(env, 50, 125);
    CHECK_EQ(env.env().eval("[clicks.x, clicks.s, clicks.ta].join()"), std::string("1,1,1"));
    CHECK_EQ(env.env().eval("x.click(); s.click(); clicks.x + ':' + clicks.s"), std::string("2:2"));
}

namespace {

/// The copyText calls that reached the bridge, by their text.
std::string copies(RenderEnv& env) {
    std::string out;
    for (const auto& [method, args] : env.env().host().bridgeCalls) {
        if (method == "copyText") {
            out += (out.empty() ? "" : ",") + args;
        }
    }
    return out;
}

const char* const kCopyBoth = "t.addEventListener('pointerdown', e => TelegramWidget.copyText('down-' + e.pointerType));"
                              "t.addEventListener('click', () => TelegramWidget.copyText('click'));";

} // namespace

/// widget-sandbox v0.3.0, the finger rule: a finger's or a pen's pointerdown is no gesture (its press may still become
/// the chat's scroll), so it cannot spend the press; its release can, and the click gets it.
WR_TEST(testAFingersPointerdownIsNoGesture) {
    for (const twidget::PointerKind kind : {twidget::PointerKind::Touch, twidget::PointerKind::Pen}) {
        RenderEnv env(page("<div id=t></div>", kCopyBoth));
        wr::HostState& host = wr::HostState::of(env.ctx());
        host.pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true, kind);
        host.pointer(env.ctx(), PointerPhase::Up, 50, 25, 1, true, kind);
        env.env().drain();
        CHECK_EQ(copies(env), std::string("[\"click\"]"));
    }
}

/// A mouse's pointerdown is a gesture, as in browsers: it spends the press, and its click has none left.
WR_TEST(testAMousesPointerdownIsAGesture) {
    RenderEnv env(page("<div id=t></div>", kCopyBoth));
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true, twidget::PointerKind::Mouse);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 25, 1, true, twidget::PointerKind::Mouse);
    env.env().drain();
    CHECK_EQ(copies(env), std::string("[\"down-mouse\"]"));
}

/// A contextmenu is no gesture, for a finger's hold the widget claims (touch-action: none) or a mouse's secondary click:
/// upstream's host numbers gestures only for click, dblclick, mousedown, mouseup, pointerdown and pointerup
/// (user-activation.ts `TYPES`), and a bridge call carries only the gesture of the event it is made in (worker.ts). The
/// release that ends the hold is one.
WR_TEST(testAContextMenuIsNoGesture) {
    RenderEnv env(page("<div id=t style=\"touch-action:none\"></div>",
                       "t.addEventListener('contextmenu', e => { log.push('menu'); e.preventDefault(); TelegramWidget.copyText('menu'); });"
                       "t.addEventListener('pointerup', () => TelegramWidget.copyText('up'));"));
    wr::HostState& host = wr::HostState::of(env.ctx());
    host.pointer(env.ctx(), PointerPhase::Down, 50, 25, 1, true);
    env.env().drain();
    env.env().advance(600);
    host.pointer(env.ctx(), PointerPhase::Up, 50, 25, 1, true);
    env.env().drain();
    CHECK_EQ(env.env().eval("log.join()"), std::string("menu"));
    CHECK_EQ(copies(env), std::string("[\"up\"]"));
    RenderEnv mouse(page("<div id=t style=\"touch-action:none\"></div>",
                         "t.addEventListener('contextmenu', e => { log.push('menu'); e.preventDefault(); TelegramWidget.copyText('menu'); });"));
    wr::HostState& mouseHost = wr::HostState::of(mouse.ctx());
    mouseHost.pointer(mouse.ctx(), PointerPhase::Down, 50, 25, 1, true, twidget::PointerKind::Mouse, 2);
    mouse.env().drain();
    mouseHost.pointer(mouse.ctx(), PointerPhase::Up, 50, 25, 1, true, twidget::PointerKind::Mouse, 2);
    mouse.env().drain();
    CHECK_EQ(mouse.env().eval("log.join()"), std::string("menu"));
    CHECK_EQ(copies(mouse), std::string(""));
}
