// Boot (M1b Task 14): the parse's scripts each a task in tree order, then HTML's "the end" (Ruling 9).
#include <memory>
#include <optional>
#include <string>
#include <string_view>

#include "Sources/DOM/DOM.h"
#include "Sources/Host/Boot.h"
#include "Sources/Support/Errors.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"
#include "Tests/JSHarness.h"
#include "Tests/wr_test.h"

namespace {

/// A loader that fails on `failing` as prepare's conversion of a host source past QuickJS's string length does (a
/// source of 2^30 units or more: JS_NewStringLen's RangeError, which script could catch): Thrown out of the boot's
/// task, with a catchable error pending. Any other URL it serves from `sources`.
class FailingLoader : public wr_test::MapScriptLoader {
public:
    JSContext* ctx = nullptr;
    std::string failing;
    std::optional<wr::ScriptSource> load(std::string_view url) override {
        if (url == failing) {
            JS_ThrowRangeError(ctx, "invalid string length");
            throw wr::Thrown{};
        }
        return MapScriptLoader::load(url);
    }
};

} // namespace

WR_TEST(testParserScriptsRunInTreeOrderEachAsATask) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>var log = ['s1:' + document.readyState + ':' + (document.getElementById('p') !== null)];"
                         "queueMicrotask(() => log.push('m1'))</script><p id=p></p><script>log.push('s2')</script>");
    CHECK_JS_EQ(env, "typeof log", "undefined");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "s1:loading:true,m1,s2");
}

WR_TEST(testTheEndRunsAsHTMLQueuesIt) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>"
                         "var log = [];"
                         "document.addEventListener('readystatechange', () => log.push('rsc:' + document.readyState));"
                         "document.addEventListener('DOMContentLoaded', e => { log.push('DCL:' + e.bubbles + ':' + document.readyState);"
                         "  queueMicrotask(() => log.push('micro-after-DCL')); });"
                         "window.addEventListener('DOMContentLoaded', () => log.push('DCL@window'));"
                         "window.addEventListener('load', e => log.push('load:' + (e.target === document) + ':' + (e.currentTarget === window) + ':' + document.readyState));"
                         "document.addEventListener('load', () => log.push('load@document'));"
                         "window.addEventListener('pageshow', e => log.push('pageshow:' + (e instanceof PageTransitionEvent) + ':' + e.persisted + ':' + e.cancelable));"
                         "</script><script src=d.js defer></script>");
    wr_test::MapScriptLoader loader;
    loader.sources["d.js"] = "log.push('defer:' + document.readyState)";
    env.host().loader = &loader;
    env.drain();
    // A listener a native dispatch calls is outermost, so the microtask checkpoint runs right after it, before the
    // window's listener.
    CHECK_JS_EQ(env, "log.join()",
                "rsc:interactive,defer:interactive,DCL:true:interactive,micro-after-DCL,DCL@window,rsc:complete,"
                "load:true:true:complete,pageshow:true:false:true");
    CHECK_JS_EQ(env, "document.readyState", "complete");
}

WR_TEST(testDeferredModuleAndAsyncScriptsFollowHTML) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>var log = []</script>"
                         "<script src=a.js async></script><script src=d1.js defer></script>"
                         "<script type=module>log.push('module')</script><script>log.push('inline')</script>"
                         "<script src=d2.js defer></script><script src=sync.js></script>"
                         "<script defer>log.push('inline-defer-ignored')</script>");
    wr_test::MapScriptLoader loader;
    loader.sources["a.js"] = "log.push('async')";
    loader.sources["d1.js"] = "log.push('d1')";
    loader.sources["d2.js"] = "log.push('d2')";
    loader.sources["sync.js"] = "log.push('sync')";
    env.host().loader = &loader;
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "async,inline,sync,inline-defer-ignored,d1,module,d2");
}

WR_TEST(testAParserScriptLoadsSynchronouslyBeforeTheNext) {
    wr_test::HostEnv env(wr_test::BootTag{}, "<!doctype html><script src=lib.js></script><script>log.push(typeof Lib)</script>");
    wr_test::MapScriptLoader loader;
    loader.sources["lib.js"] = "var Lib = {}; var log = ['lib']";
    env.host().loader = &loader;
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "lib,object");
}

WR_TEST(testARefusedParserScriptFiresErrorInItsTask) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>var log = []</script>"
                         "<script src=nope.js onerror=\"log.push('error')\"></script><script>log.push('next')</script>");
    wr_test::MapScriptLoader loader;
    env.host().loader = &loader;
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "error,next");
}

// Review Focus 5.
WR_TEST(testBootScriptsThatMutateLaterScripts) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script id=s1>"
                         "var log = ['s1'];"
                         "document.getElementById('s2').remove();"
                         "var x = document.createElement('script'); x.textContent = \"log.push('x')\"; document.body.appendChild(x);"
                         "log.push('after-x');"
                         "document.body.appendChild(document.getElementById('s3'));"
                         "log.push('after-move');"
                         "</script>"
                         "<script id=s2>log.push('s2')</script><script id=s3>log.push('s3')</script><script id=s4>log.push('s4')</script>");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "s1,x,after-x,s3,after-move,s2,s4");
}

// Final review M3: a parser script that an earlier script removes and then changes the text of is not prepared then
// (HTML's post-connection steps prepare only a connected script), so its boot turn still finds it parser-inserted: a
// module without async joins the scripts run after parsing, after s3, with force async false. Before the fix the
// children changed steps prepared it anyway: steps 2 to 4 cleared its parser document and set force async before step
// 7 returned for a disconnected script, so its boot turn ran it as a script-inserted module, a task before s3.
WR_TEST(testARemovedParserScriptStaysParserInserted) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>"
                         "var log = ['s1']; var s2 = document.getElementById('s2');"
                         "s2.remove(); s2.textContent = \"log.push('s2:' + s2.async)\";"
                         "</script>"
                         "<script id=s2 type=module>log.push('original')</script><script>log.push('s3')</script>");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "s1,s3,s2:false");
}

WR_TEST(testTemplateContentScriptsRunOnlyWhenInserted) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><template id=t><script>log.push('t')</script></template>"
                         "<script>var log = ['main']; document.body.appendChild(document.getElementById('t').content.cloneNode(true)); log.push('after')</script>");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "main,t,after");
}

WR_TEST(testReadyStateAndDefaultView) {
    wr_test::HostEnv env(wr_test::BootTag{}, "<!doctype html><title>x</title>", "https://example.test/w.html");
    CHECK_JS_EQ(env, "document.readyState", "loading");
    CHECK_JS_EQ(env, "document.URL", "https://example.test/w.html");
    CHECK_JS(env, "document.defaultView === window");
    CHECK_JS_EQ(env, "(d => [d.readyState, d.defaultView].join())(new Document())", "complete,");
    CHECK_JS(env, "document.createElement('template').content.ownerDocument.defaultView === null");
    env.drain();
    CHECK_JS_EQ(env, "document.readyState", "complete");
}

WR_TEST(testOnReadyStateChangeIsAnEventHandler) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>var log = []; document.onreadystatechange = () => log.push(document.readyState)</script>");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "interactive,complete");
}

WR_TEST(testBootReportsTheParseLimits) {
    wr::ParseLimits limits;
    limits.maxNodes = 50;
    std::string html = "<!doctype html><script>var n = document.getElementsByTagName('p').length</script>";
    for (int i = 0; i < 200; i++) {
        html += "<p>x</p>";
    }
    wr_test::HostEnv limited(wr_test::BootTag{}, html, "about:srcdoc", 1, limits);
    CHECK(limited.bootOutcome().stoppedAtNodeLimit);
    limited.drain();
    CHECK_JS(limited, "n > 0 && n < 50");
}

WR_TEST(testAHangingBootScriptStopsTheRuntime) {
    wr_test::HostEnv env(wr_test::BootTag{}, "<!doctype html><script>for (;;) {}</script><script>var ran = true</script>");
    JSRuntime* rt = env.runtime().jsRuntime();
    env.runtime().setWorkLimit(JS_GetWorkUnits(rt) + 2000000);
    env.drain();
    CHECK(env.runtime().stopReason() == wr::StopReason::Budget);
    CHECK(env.step() == wr::StepResult::Stopped);
}

WR_TEST(testBootedRunsItsHookBeforeTheParse) {
    std::string seen;
    wr::BootOptions options{"<!doctype html><script>log.push(document.URL)</script>", "https://example.test/b.html", {}};
    std::unique_ptr<wr_test::HostEnv> env = wr_test::HostEnv::booted(options, 1, [&](wr_test::HostEnv& e) {
        // Installed and empty: no element yet, no task run.
        seen = e.eval("String(document.documentElement)");
        e.eval("var log = []");
    });
    CHECK_EQ(seen, std::string("null"));
    CHECK(!env->bootOutcome().stoppedAtNodeLimit);
    env->drain();
    CHECK_JS_EQ(*env, "log.join()", "https://example.test/b.html");
}

// Ruling C1: the initial parse is a step boundary. Each parsed `on*` attribute runs the event handler content
// attribute's change steps, which charge; under a tight limit the budget trips inside the parse, outside any binding
// call, either in those steps (which latch and throw Aborted) or in the builder's own charges (Thrown), and neither may
// reach the host. The poll points are fixed, so a sweep of limits trips at sites of both kinds (measured without the
// boundary: 55 of the 60 limits escaped as Aborted from the change steps, 5 as Thrown).
WR_TEST(testABootWhoseParseHitsTheWorkLimitStops) {
    std::string html = "<!doctype html><body>";
    for (int i = 0; i < 1000; i++) {
        html += "<p onclick=a() ondblclick=a() onmousedown=a() onmouseup=a() onmouseover=a() onmouseout=a() "
                "onmousemove=a() onkeydown=a() onkeyup=a() oninput=a() onchange=a() onfocus=a() onblur=a() "
                "onscroll=a() onsubmit=a() onwheel=a()>x</p>";
    }
    wr::BootOptions options{html, "about:srcdoc", {}};
    // What the boot costs with no limit. The sweep's limits fall in the middle of it: in the paragraphs' attributes,
    // past the first use of their interfaces (which is where every limit of a few thousand units trips).
    uint64_t start = 0;
    std::unique_ptr<wr_test::HostEnv> unlimited = wr_test::HostEnv::booted(options, 1, [&](wr_test::HostEnv& e) {
        start = JS_GetWorkUnits(e.runtime().jsRuntime());
    });
    CHECK(unlimited->runtime().stopReason() == wr::StopReason::None);
    uint64_t cost = JS_GetWorkUnits(unlimited->runtime().jsRuntime()) - start;
    unlimited.reset();
    int boots = 0;
    for (uint64_t limit = cost / 4; limit < cost * 3 / 4; limit += cost / 120 + 1) {
        boots++;
        std::unique_ptr<wr_test::HostEnv> env;
        bool threw = false;
        try {
            env = wr_test::HostEnv::booted(options, 1, [&](wr_test::HostEnv& e) {
                e.runtime().setWorkLimit(JS_GetWorkUnits(e.runtime().jsRuntime()) + limit);
            });
        } catch (...) {
            threw = true;
        }
        CHECK(!threw);
        if (!env) {
            continue;
        }
        CHECK(env->runtime().stopReason() == wr::StopReason::Budget);
        // The parse stopped part-way: the document holds what came before, and nothing runs.
        CHECK(env->step() == wr::StepResult::Stopped);
        CHECK_EQ(env->eval("1"), std::string("STOPPED"));
    }
    // About 60 limits, whatever the rates: the sweep is never vacuous.
    CHECK(boots >= 50);
}

// K1: a boot task whose work throws a catchable error (the loop reports it, and the widget runs on) still queues the
// next one, so the later scripts and "the end" are not lost.
WR_TEST(testABootTaskThatThrowsStillQueuesTheNext) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>var log = [];"
                         "window.addEventListener('error', e => log.push('error:' + (e.error instanceof RangeError)));"
                         "document.addEventListener('DOMContentLoaded', () => log.push('DCL'));"
                         "window.addEventListener('load', () => log.push('load'));"
                         "</script><script src=big.js></script><script>log.push('next')</script><script src=d.js defer></script>");
    FailingLoader loader;
    loader.ctx = env.ctx();
    loader.failing = "big.js";
    loader.sources["d.js"] = "log.push('defer')";
    env.host().loader = &loader;
    env.drain();
    CHECK(env.runtime().stopReason() == wr::StopReason::None);
    CHECK_JS_EQ(env, "log.join()", "error:true,next,defer,DCL,load");
}

// K4: a runtime that stopped before the boot (here in the hook) boots nothing.
WR_TEST(testBootingAStoppedRuntimeDoesNothing) {
    wr::BootOptions options{"<!doctype html><script>var ran = true</script>", "https://example.test/s.html", {}};
    std::unique_ptr<wr_test::HostEnv> env = wr_test::HostEnv::booted(options, 1, [](wr_test::HostEnv& e) {
        e.runtime().setWorkLimit(JS_GetWorkUnits(e.runtime().jsRuntime()) + 1000);
        CHECK_EQ(e.eval("for (;;) {}"), std::string("ABORTED"));
    });
    CHECK(env->runtime().stopReason() == wr::StopReason::Budget);
    wr::Document& document = wr::globalDocument(env->ctx());
    CHECK(document.firstChildNode() == nullptr);
    CHECK(document.URL(env->ctx()).equalsASCII("about:srcdoc"));
    CHECK(env->step() == wr::StepResult::Stopped);
}

// K4: without the host layer there is no window.
WR_TEST(testDefaultViewIsNullWithoutAWindow) {
    wr_test::DOMEnv env;
    CHECK_JS(env, "document.defaultView === null");
    CHECK_JS_EQ(env, "document.readyState", "complete");
}

// K4: load and pageshow are trusted, at the window, with the document as their target (the legacy target override).
WR_TEST(testLoadAndPageshowAreTrustedAndTargetTheDocument) {
    wr_test::HostEnv env(wr_test::BootTag{},
                         "<!doctype html><script>var log = [];"
                         "window.addEventListener('load', e => log.push('load:' + e.isTrusted + ':' + (e.target === document) + ':' + (e.currentTarget === window)));"
                         "window.addEventListener('pageshow', e => log.push('pageshow:' + e.isTrusted + ':' + (e.target === document) + ':' + (e.currentTarget === window) + ':' + e.bubbles));"
                         "</script>");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "load:true:true:true,pageshow:true:true:true:true");
}

// K4: the memory limit refusing an allocation inside the boot latches Memory there; nothing reaches the host.
WR_TEST(testABootThatHitsTheMemoryLimitStops) {
    std::string html = "<!doctype html><body>";
    for (int i = 0; i < 5000; i++) {
        html += "<p title=t>x</p>";
    }
    wr::BootOptions options{html, "about:srcdoc", {}};
    std::unique_ptr<wr_test::HostEnv> env;
    bool threw = false;
    try {
        env = wr_test::HostEnv::booted(options, 1, [](wr_test::HostEnv& e) {
            JSRuntime* rt = e.runtime().jsRuntime();
            JSMemoryUsage usage;
            JS_ComputeMemoryUsage(rt, &usage);
            JS_SetMemoryLimit(rt, size_t(usage.malloc_size) + 256 * 1024);
        });
    } catch (...) {
        threw = true;
    }
    CHECK(!threw);
    if (!env) {
        return;
    }
    CHECK(env->runtime().stopReason() == wr::StopReason::Memory);
    CHECK(env->step() == wr::StepResult::Stopped);
    CHECK_EQ(env->eval("1"), std::string("STOPPED"));
}

// K4: a limit just below the boot's whole cost trips after the parse, in the walk for the parse's scripts: the parse
// finished, and the boot ends there.
WR_TEST(testABootThatHitsTheWorkLimitAfterTheParseStops) {
    std::string html = "<!doctype html><body>";
    for (int i = 0; i < 3000; i++) {
        html += "<p></p>";
    }
    wr::BootOptions options{html, "about:srcdoc", {}};
    uint64_t start = 0;
    std::unique_ptr<wr_test::HostEnv> unlimited = wr_test::HostEnv::booted(options, 1, [&](wr_test::HostEnv& e) {
        start = JS_GetWorkUnits(e.runtime().jsRuntime());
    });
    uint64_t cost = JS_GetWorkUnits(unlimited->runtime().jsRuntime()) - start;
    unlimited.reset();
    // The walk visits the 3,004 nodes at work::kNodeVisit, last but for the first task's queueing, whose deque block
    // (~1,000 allocation units, which never poll) ends the boot. 4,000 units from the end is in the walk's middle.
    std::unique_ptr<wr_test::HostEnv> env;
    bool threw = false;
    try {
        env = wr_test::HostEnv::booted(options, 1, [&](wr_test::HostEnv& e) {
            e.runtime().setWorkLimit(JS_GetWorkUnits(e.runtime().jsRuntime()) + cost - 4000);
        });
    } catch (...) {
        threw = true;
    }
    CHECK(!threw);
    if (!env) {
        return;
    }
    CHECK(env->runtime().stopReason() == wr::StopReason::Budget);
    if (env->runtime().stopReason() != wr::StopReason::Budget) {
        return;   // a running widget at its limit: the DOM reads below would charge outside any boundary
    }
    wr::HTMLElement* body = wr::globalDocument(env->ctx()).body(env->ctx());
    CHECK(body && body->childCount() == 3000);
    CHECK(env->step() == wr::StepResult::Stopped);
}

// K5: the host's URL is converted to a string, charged before: a long one under a tight limit stops the boot before
// the conversion (and the parse).
WR_TEST(testBootChargesTheURLBeforeConvertingIt) {
    std::string url = "https://example.test/" + std::string(8 << 20, 'a');
    wr::BootOptions options{"<p>x</p>", url, {}};
    std::unique_ptr<wr_test::HostEnv> env = wr_test::HostEnv::booted(options, 1, [](wr_test::HostEnv& e) {
        e.runtime().setWorkLimit(JS_GetWorkUnits(e.runtime().jsRuntime()) + 100000);
    });
    CHECK(env->runtime().stopReason() == wr::StopReason::Budget);
    wr::Document& document = wr::globalDocument(env->ctx());
    CHECK(document.URL(env->ctx()).equalsASCII("about:srcdoc"));
    CHECK(document.firstChildNode() == nullptr);
}

// K7: the boot parses into an empty main document only. A host that hands it one with children broke the contract:
// the widget stops (Internal), and nothing is parsed.
WR_TEST(testBootRefusesANonEmptyDocument) {
    wr::BootOptions options{"<!doctype html><script>var ran = true</script>", "https://example.test/k.html", {}};
    std::unique_ptr<wr_test::HostEnv> env = wr_test::HostEnv::booted(options, 1, [](wr_test::HostEnv& e) {
        e.eval("document.appendChild(document.createComment('host'))");
    });
    CHECK(env->runtime().stopReason() == wr::StopReason::Internal);
    wr::Document& document = wr::globalDocument(env->ctx());
    CHECK_EQ(document.childCount(), size_t(1));
    CHECK(document.URL(env->ctx()).equalsASCII("about:srcdoc"));
    CHECK(env->step() == wr::StepResult::Stopped);
}
