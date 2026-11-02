// SDK v1's removed and inert APIs (V2a plan, Task 1; widget-sandbox v0.1.0 docs/sdk-v1.md §2.10 and
// auto/15-js-runtime-c): every network global throws NetworkDisabledError, the dialogs and the clipboard reach nothing,
// the device and platform APIs a widget has no business with are absent or refuse. Nothing here reaches the host.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testTheNetworkConstructorsThrowNetworkDisabledError) {
    HostEnv env;
    CHECK_EQ(env.eval("['XMLHttpRequest', 'WebSocket', 'EventSource', 'RTCPeerConnection', 'Worker', 'SharedWorker',"
                      " 'BroadcastChannel'].map(n => { try { new window[n]('https://example.org/'); return n + ':constructed'; }"
                      " catch (e) { return e.name + ':' + (e instanceof DOMException); } }).join()"),
             std::string("NetworkDisabledError:true,NetworkDisabledError:true,NetworkDisabledError:true,"
                         "NetworkDisabledError:true,NetworkDisabledError:true,NetworkDisabledError:true,"
                         "NetworkDisabledError:true"));
    CHECK_EQ(env.eval("[() => navigator.sendBeacon('https://example.org/', 'x'), () => importScripts('https://example.org/x.js')]"
                      ".map(f => { try { f(); return 'ran'; } catch (e) { return e.name; } }).join()"),
             std::string("NetworkDisabledError,NetworkDisabledError"));
    CHECK(env.host().bridgeCalls.empty());
}

WR_TEST(testFetchRejectsWithNetworkDisabledError) {
    HostEnv env;
    env.eval("window.r = 'pending'; fetch('https://example.org/').then(() => r = 'resolved', e => r = e.name); 1");
    env.drain();
    CHECK_EQ(env.eval("r"), std::string("NetworkDisabledError"));
    CHECK(env.host().bridgeCalls.empty());
}

WR_TEST(testTheDialogsAreInert) {
    HostEnv env;
    CHECK_EQ(env.eval("[alert('x') === undefined, confirm('x') === false, prompt('x') === null].join()"), std::string("true,true,true"));
    CHECK(env.host().bridgeCalls.empty());
}

WR_TEST(testClipboardAndShareReject) {
    HostEnv env;
    env.eval("window.r = []; const c = navigator.clipboard;"
             "for (const p of [c.writeText('x'), c.readText(), c.write([]), c.read(), navigator.share({ text: 'x' })])"
             "  p.then(() => r.push('resolved'), e => r.push(e.name));"
             "r.push('canShare:' + navigator.canShare({ text: 'x' })); 1");
    env.drain();
    CHECK_EQ(env.eval("r.join()"), std::string("canShare:false,NotAllowedError,NotAllowedError,NotAllowedError,NotAllowedError,NotAllowedError"));
    CHECK(env.host().bridgeCalls.empty());
}

WR_TEST(testDeviceAndPlatformApisAreAbsentOrRefuse) {
    HostEnv env;
    CHECK_EQ(env.eval("[navigator.geolocation === undefined, navigator.mediaDevices === undefined, navigator.vibrate(10) === false,"
                      " typeof document.startViewTransition === 'undefined',"
                      " (() => { try { document.createElement('div').attachShadow({ mode: 'open' }); return false; } catch (e) { return true; } })()]"
                      ".join()"),
             std::string("true,true,true,true,true"));
    env.eval("window.f = 'pending'; document.documentElement.requestFullscreen().then(() => f = 'resolved', e => f = e.name); 1");
    env.drain();
    CHECK_EQ(env.eval("f"), std::string("NotAllowedError"));
    // Assigning location does not navigate.
    CHECK_EQ(env.eval("(h => { location.href = 'https://example.org/'; return location.href === h; })(location.href)"), std::string("true"));
    CHECK(env.host().bridgeCalls.empty());
    // window.open returns null (its routing, with activation, is Task 5's).
    CHECK_EQ(env.eval("window.open('https://example.org/')"), std::string("null"));
}
