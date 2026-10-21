// AbortController and AbortSignal (V5a plan, Task 8; DOM §3.1–3.2): signal abort (the reason, one abort event),
// AbortSignal.abort and AbortSignal.timeout through the event loop.
#include <string>

#include "Sources/Host/HostState.h"
#include "Tests/HostHarness.h"

using wr_test::HostEnv;

WR_TEST(testAbort) {
    HostEnv env;
    CHECK_EQ(env.eval("window.c = new AbortController(); window.log = []; const s = c.signal; s.onabort = e => log.push('on:' + e.type + ':' + e.isTrusted);"
                      "s.addEventListener('abort', () => log.push('listener')); [s.aborted, s.reason === undefined, c.signal === s].join()"),
             std::string("false,true,true"));
    CHECK_EQ(env.eval("c.abort(); c.abort(); [c.signal.aborted, c.signal.reason instanceof DOMException, c.signal.reason.name, log.join()].join('|')"),
             std::string("true|true|AbortError|on:abort:true,listener"));
    CHECK_EQ(env.eval("const d = new AbortController(); d.abort('why'); [d.signal.reason, (() => { try { d.signal.throwIfAborted(); return 'no' } catch (e) { return e } })(),"
                      " (() => { try { new AbortController().signal.throwIfAborted(); return 'ok' } catch (e) { return 'threw' } })()].join()"),
             std::string("why,why,ok"));
}

WR_TEST(testStatics) {
    HostEnv env;
    CHECK_EQ(env.eval("[AbortSignal.abort().aborted, AbortSignal.abort().reason.name, AbortSignal.abort(1).reason, AbortSignal.abort() instanceof EventTarget,"
                      " (() => { try { new AbortSignal(); return 'made' } catch (e) { return e.name } })()].join()"),
             std::string("true,AbortError,1,true,TypeError"));
}

WR_TEST(testTimeout) {
    HostEnv env;
    env.eval("window.t = AbortSignal.timeout(50); window.events = 0; t.onabort = () => events++; 1");
    env.advance(49);
    CHECK_EQ(env.eval("t.aborted + ':' + events"), std::string("false:0"));
    env.advance(1);
    CHECK_EQ(env.eval("[t.aborted, events, t.reason instanceof DOMException, t.reason.name].join()"), std::string("true,1,true,TimeoutError"));
}

/// Review Focus 5: a hidden widget's timeout still fires through the loop.
WR_TEST(testTimeoutWhileHidden) {
    HostEnv env;
    wr::HostState::of(env.ctx()).setVisible(env.ctx(), false);
    env.drain();
    env.eval("window.t = AbortSignal.timeout(10); 1");
    env.advance(1000);
    CHECK_EQ(env.eval("t.aborted"), std::string("true"));
}
