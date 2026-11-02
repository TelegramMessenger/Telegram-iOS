// Script elements (M1b Task 13): HTML's "prepare the script element" and "execute the script element", the host's
// loader, and the triggers for scripts that script inserts, fills or gives a src, at mutation depth 0 (Ruling 6).
#include <cstdio>
#include <string>

#include "Generated/Bindings.h"
#include "Sources/DOM/DOM.h"
#include "Tests/HostHarness.h"
#include "Tests/JSHarness.h"
#include "Tests/wr_test.h"

// The statements in `code` evaluated as one script, and its completion value checked: CHECK_JS_EQ takes an expression
// (it evaluates String(expr)), and a check whose statements must run in the same script (before the microtask
// checkpoint that follows it) cannot be split into an eval and a CHECK_JS_EQ.
#define CHECK_EVAL_EQ(env, code, expected) \
    do { \
        std::string _r = (env).eval(code); \
        if (_r != std::string(expected)) { \
            wr_test::failures()++; \
            std::printf("  %s:%d: CHECK_EVAL_EQ(%s) -> %s, expected %s\n", __FILE__, __LINE__, (code), _r.c_str(), std::string(expected).c_str()); \
        } \
    } while (0)

namespace {

bool hasDiagnostic(wr_test::HostEnv& env, const std::string& kind, const std::string& part) {
    for (const auto& d : env.host().diagnostics) {
        if (d.first == kind && d.second.find(part) != std::string::npos) {
            return true;
        }
    }
    return false;
}

wr::HTMLScriptElement* globalScript(wr_test::HostEnv& env, const char* name) {
    JSContext* ctx = env.ctx();
    wr::Value global = wr::Value::adopt(ctx, JS_GetGlobalObject(ctx));
    wr::Value v = wr::Value::adopt(ctx, JS_GetPropertyStr(ctx, global.get(), name));
    return static_cast<wr::HTMLScriptElement*>(wr::payloadImplementing(ctx, v.get(), wr::idl::kHTMLScriptElement));
}

} // namespace

WR_TEST(testInlineScriptInsertedByScriptRunsAtInsertion) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); s.textContent = \"log.push('ran')\";"
                "log.push('before'); document.body.appendChild(s); log.push('after'); log.join()",
                "before,ran,after");
}

WR_TEST(testScriptsInAnInsertedFragmentRunInTreeOrder) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var f = document.createDocumentFragment();"
                "var a = document.createElement('script'); a.textContent = \"log.push('a')\";"
                "var d = document.createElement('div'); var b = document.createElement('script'); b.textContent = \"log.push('b')\";"
                "d.appendChild(b); f.appendChild(a); f.appendChild(d); log.push('x'); document.body.appendChild(f); log.join()",
                "x,a,b");
}

WR_TEST(testADisconnectedScriptWaitsUntilItIsConnected) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env, "var log = []; var s = document.createElement('script'); s.textContent = \"log.push('ran')\"; log.join()", "");
    CHECK_EVAL_EQ(env, "document.body.appendChild(s); log.join()", "ran");
}

WR_TEST(testAScriptRunsOnce) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); s.textContent = 'log.push(1)';"
                "document.body.appendChild(s); document.body.removeChild(s); document.body.appendChild(s);"
                "document.body.appendChild(s.cloneNode(true)); log.join()",
                "1");
}

WR_TEST(testFragmentParsedScriptsStayInert) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; document.body.innerHTML = '<script>log.push(1)<\\/script>';"
                "document.body.appendChild(document.body.firstChild.cloneNode(true));"
                "document.body.insertAdjacentHTML('beforeend', '<script>log.push(2)<\\/script>'); log.join()",
                "");
}

WR_TEST(testAnEmptyConnectedScriptRunsWhenItGetsText) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); document.body.appendChild(s);"
                "s.appendChild(document.createTextNode(\"log.push('late')\")); log.join()",
                "late");
}

WR_TEST(testMicrotasksQueuedByAnInsertedScriptWaitForTheOutermostScript) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script');"
                "s.textContent = \"queueMicrotask(() => log.push('micro')); log.push('inner')\";"
                "document.body.appendChild(s); log.push('outer'); log.join()",
                "inner,outer");
    CHECK_JS_EQ(env, "log.join()", "inner,outer,micro");
}

WR_TEST(testAScriptInsertedDuringArgumentConversionWaitsForTheCall) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); s.textContent = \"log.push('ran')\";"
                "document.body.addEventListener('x', function () {}, { get capture() { document.body.appendChild(s); log.push('getter'); return false; } });"
                "log.push('after'); log.join()",
                "getter,ran,after");
}

WR_TEST(testMutationScopeDefersPreparationToTheOutermostExit) {
    wr_test::HostEnv env;
    JSContext* ctx = env.ctx();
    env.eval("var log = []; var s = document.createElement('script'); s.textContent = \"log.push('ran')\"");
    wr::HTMLScriptElement* script = globalScript(env, "s");
    CHECK(script != nullptr);
    wr::Document& document = wr::globalDocument(ctx);
    {
        wr::MutationScope outer(ctx);
        {
            wr::MutationScope inner(ctx);
            wr::insertNode(ctx, *script, *document.body(ctx), nullptr);
            inner.leave();
        }
        CHECK(!script->alreadyStarted());
        outer.leave();
    }
    CHECK(script->alreadyStarted());
    CHECK_JS_EQ(env, "log.join()", "ran");
}

WR_TEST(testSrcOnAConnectedScriptLoadsItAsATaskThenFiresLoad) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    loader.sources["lib.js"] = "log.push('lib:' + (document.currentScript === s))";
    env.host().loader = &loader;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); document.body.appendChild(s);"
                "s.addEventListener('load', e => log.push('load:' + e.isTrusted)); s.src = 'lib.js'; log.push('set'); log.join()",
                "set");
    CHECK_EQ(loader.requests.size(), size_t(1));
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "set,lib:true,load:true");
    CHECK_EVAL_EQ(env, "s.src = 'other.js'; log.join()", "set,lib:true,load:true");
    CHECK_EQ(loader.requests.size(), size_t(1));
}

WR_TEST(testExternalScriptsWithoutAsyncRunInInsertionOrder) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    loader.sources["1.js"] = "log.push(1)";
    loader.sources["2.js"] = "log.push(2)";
    env.host().loader = &loader;
    env.eval("var log = []; for (const n of [1, 2]) { var s = document.createElement('script'); s.async = false; s.src = n + '.js'; document.body.appendChild(s); }");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "1,2");
}

WR_TEST(testARefusedExternalScriptFiresErrorAsATaskAndIsDiagnosed) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    env.host().loader = &loader;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); s.src = 'https://cdn.example/x.js';"
                "s.addEventListener('error', e => log.push('error:' + e.isTrusted)); s.addEventListener('load', () => log.push('load'));"
                "document.body.appendChild(s); log.join()",
                "");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "error:true");
    CHECK_EQ(loader.requests.size(), size_t(1));
    CHECK_EQ(loader.requests[0], std::string("https://cdn.example/x.js"));
    CHECK(hasDiagnostic(env, "script-skipped", "x.js"));
}

WR_TEST(testWithNoLoaderEveryExternalScriptIsRefused) {
    wr_test::HostEnv env;
    env.eval("var log = []; var s = document.createElement('script'); s.src = 'lib.js'; s.addEventListener('error', () => log.push('error')); document.body.appendChild(s)");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "error");
}

WR_TEST(testAnEmptySrcFiresErrorWithoutLoading) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    env.host().loader = &loader;
    CHECK_EVAL_EQ(env,
                "var log = []; var s = document.createElement('script'); s.setAttribute('src', '');"
                "s.addEventListener('error', () => log.push('error')); document.body.appendChild(s); log.join()",
                "");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "error");
    CHECK_EQ(loader.requests.size(), size_t(0));
}

WR_TEST(testScriptTypesFollowHTML) {
    wr_test::HostEnv env;
    env.eval("var log = [];"
             "function add(type, language, name) { var s = document.createElement('script');"
             "  if (type !== null) s.setAttribute('type', type); if (language !== null) s.setAttribute('language', language);"
             "  s.textContent = \"log.push('\" + name + \"')\"; document.body.appendChild(s); }"
             "add(null, null, 'none'); add('', null, 'empty'); add('text/javascript1.5', null, 'js15');"
             "add(' TEXT/JAVASCRIPT ', null, 'upper'); add(null, 'javascript', 'language'); add('application/x-javascript', null, 'xjs');"
             "add('text/javascript; charset=utf-8', null, 'params'); add('   ', null, 'blank'); add('text/plain', null, 'plain');"
             "add('application/json', null, 'json'); add('module', null, 'module')");
    CHECK_JS_EQ(env, "log.join()", "none,empty,js15,upper,language,xjs");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "none,empty,js15,upper,language,xjs,module");
    CHECK(hasDiagnostic(env, "script-skipped", "text/plain"));
    CHECK(hasDiagnostic(env, "script-skipped", "charset=utf-8"));
    CHECK(!hasDiagnostic(env, "script-skipped", "json"));
}

WR_TEST(testNoModuleSkipsClassicScriptsOnly) {
    wr_test::HostEnv env;
    env.eval("var log = []; var a = document.createElement('script'); a.noModule = true; a.textContent = \"log.push('classic')\";"
             "document.body.appendChild(a); var b = document.createElement('script'); b.type = 'module'; b.noModule = true;"
             "b.textContent = \"log.push('module')\"; document.body.appendChild(b)");
    CHECK_JS_EQ(env, "log.join()", "");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "module");
}

WR_TEST(testModuleScriptsRunWithoutAModuleLoader) {
    wr_test::HostEnv env;
    env.eval("var log = [], errors = [], rejections = 0;"
             "window.addEventListener('error', e => errors.push(e.message)); window.addEventListener('unhandledrejection', () => rejections++);"
             "function module(text) { var s = document.createElement('script'); s.type = 'module'; s.textContent = text; document.body.appendChild(s); }"
             "module(\"log.push('this:' + (this === undefined) + ':' + document.currentScript)\");"
             "module(\"import 'x'; window.imported = true\"); module(\"throw new TypeError('boom')\")");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "this:true:null");
    CHECK_JS_EQ(env, "String(window.imported)", "undefined");
    CHECK_JS_EQ(env, "errors.length", "2");
    CHECK_JS(env, "errors[0].indexOf('could not load module') >= 0");
    CHECK_JS(env, "errors[1].indexOf('boom') >= 0");
    CHECK_JS_EQ(env, "rejections", "0");
}

WR_TEST(testCurrentScriptIsSetAndRestored) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; var outer = document.createElement('script');"
                "outer.textContent = \"log.push(document.currentScript === outer); var inner = document.createElement('script');"
                "inner.textContent = 'log.push(document.currentScript === inner)'; document.body.appendChild(inner);"
                "log.push(document.currentScript === outer)\";"
                "document.body.appendChild(outer); log.push(String(document.currentScript)); log.join()",
                "true,true,true,null");
}

WR_TEST(testLegacyEventAndForAttributes) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = []; function add(forValue, event, name) { var s = document.createElement('script');"
                "  s.setAttribute('for', forValue); s.setAttribute('event', event); s.textContent = \"log.push('\" + name + \"')\";"
                "  document.body.appendChild(s); }"
                "add('window', 'onload', 'a'); add(' WINDOW ', 'onload()', 'b'); add('window', 'onclick', 'c'); add('document', 'onload', 'd');"
                "log.join()",
                "a,b");
    // htmlFor reflects the content attribute "for" ([Reflect="for"]).
    CHECK_EVAL_EQ(env, "var t = document.createElement('script'); t.htmlFor = 'window'; [t.getAttribute('for'), t.htmlFor].join()", "window,window");
}

WR_TEST(testAsyncReflectsForceAsync) {
    wr_test::HostEnv env("<!doctype html><html><head><script id=p>0</script></head><body></body></html>");
    CHECK_EVAL_EQ(env, "var s = document.createElement('script'); [s.async, s.hasAttribute('async')].join()", "true,false");
    CHECK_EVAL_EQ(env, "s.async = false; [s.async, s.hasAttribute('async')].join()", "false,false");
    CHECK_EVAL_EQ(env, "s.async = true; [s.async, s.hasAttribute('async')].join()", "true,true");
    CHECK_EVAL_EQ(env, "var t = document.createElement('script'); t.setAttribute('async', ''); t.removeAttribute('async'); t.async", "false");
    CHECK_JS_EQ(env, "document.getElementById('p').async", "false");
}

WR_TEST(testTextIsTheTextChildrenOnly) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var s = document.createElement('script'); s.appendChild(document.createTextNode('a'));"
                "var b = document.createElement('b'); b.textContent = 'X'; s.appendChild(b); s.appendChild(document.createTextNode('c'));"
                "[s.text, s.textContent].join()",
                "ac,aXc");
    CHECK_EVAL_EQ(env, "s.text = 'q'; [s.childNodes.length, s.text].join()", "1,q");
}

WR_TEST(testSupportsClassicAndModule) {
    wr_test::HostEnv env;
    CHECK_JS_EQ(env,
                "['classic', 'module', 'importmap', 'speculationrules', 'Classic'].map(t => HTMLScriptElement.supports(t)).join()",
                "true,true,false,false,false");
}

WR_TEST(testAThrowingScriptIsReportedAndTheNextOneRuns) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                "var log = [], errors = []; window.addEventListener('error', e => errors.push(e.message));"
                "for (const text of [\"throw new Error('first')\", \"log.push('second')\"]) {"
                "  var s = document.createElement('script'); s.textContent = text; document.body.appendChild(s); }"
                "[log.join(), errors.length, errors[0].indexOf('first') >= 0].join()",
                "second,1,true");
}

WR_TEST(testImportMapsAreSkippedWithADiagnostic) {
    wr_test::HostEnv env;
    env.eval("var s = document.createElement('script'); s.type = 'importmap'; s.textContent = '{}'; document.body.appendChild(s)");
    CHECK(hasDiagnostic(env, "script-skipped", "import maps"));
}

WR_TEST(testAHangingInsertedScriptStopsTheRuntime) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    wr_test::stopAfter(env.runtime());
    std::string result = env.eval("var s = document.createElement('script'); s.textContent = 'for (;;) {}'; document.body.appendChild(s); 'done'");
    CHECK_EQ(result, std::string("ABORTED"));
    CHECK(env.runtime().stopReason() == wr::StopReason::Cpu);
}

// Ruling R3: compiling an inline handler is a script entry with its own ScriptBoundary. A body that closes the factory
// early runs its code in the factory's evaluation, reached here from the onclick getter's binding call: a script it
// inserts runs at the insertion (native depth 0), not when the getter returns.
WR_TEST(testAnEarlyClosingHandlerBodyInsertsScriptsAtDepthZero) {
    wr_test::HostEnv env;
    env.eval("var log = []; var s = document.createElement('script'); s.textContent = \"log.push('ran')\";"
             "var d = document.createElement('div');"
             "d.setAttribute('onclick', \"} }.onclick; }, document.body.appendChild(s), log.push('eval'), function () { return { onclick: function (event) {\")");
    CHECK_EVAL_EQ(env, "var f = d.onclick; [typeof f, log.join()].join()", "function,ran,eval");
}

// The attribute change steps are the null namespace's: a namespaced attribute named src or async is another attribute.
WR_TEST(testANamespacedSrcOrAsyncIsAnotherAttribute) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    loader.sources["lib.js"] = "log.push('lib')";
    env.host().loader = &loader;
    env.eval("var log = []; var s = document.createElement('script'); document.body.appendChild(s);"
             "s.setAttributeNS('urn:x', 'x:src', 'lib.js'); var t = document.createElement('script'); t.setAttributeNS('urn:x', 'x:async', '')");
    env.drain();
    CHECK_EQ(loader.requests.size(), size_t(0));
    CHECK_JS_EQ(env, "[log.join(), t.async].join()", ",true");
}

// HTML's step 13: scripting is disabled outside the window's document. A script collected from an insertion into it
// but moved into another document before its turn is connected there, and does not run. A running script that adopts
// its own element away stays the currentScript of the document it started in until it ends, and is restored there.
WR_TEST(testAScriptMovedIntoAnotherDocumentDoesNotRun) {
    wr_test::HostEnv env;
    CHECK_EVAL_EQ(env,
                  "var log = []; var other = new Document(); var a = document.createElement('script'); var b = document.createElement('script');"
                  "a.textContent = 'other.appendChild(b)'; b.textContent = \"log.push('b')\";"
                  "var f = document.createDocumentFragment(); f.appendChild(a); f.appendChild(b); document.body.appendChild(f);"
                  "[log.join(), b.isConnected, b.ownerDocument === other].join()",
                  ",true,true");
    CHECK_EVAL_EQ(env,
                  "var c = document.createElement('script'); c.textContent = 'new Document().appendChild(document.currentScript); gc(); log.push(String(document.currentScript))';"
                  "document.body.appendChild(c); gc(); [log.join(), String(document.currentScript)].join()",
                  "[object HTMLScriptElement],null");
}

// Fix round 1, I1: there is no module loader, so every import fails, an earlier module script's name included. QuickJS
// would otherwise find it among the modules it keeps (a module script's module stays loaded for the context's life,
// named by its URL: the loader's for an external one, the document's for an inline one).
WR_TEST(testAnImportOfAnEarlierModuleScriptFails) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    loader.sources["lib.mjs"] = "window.libRuns = (window.libRuns || 0) + 1; export const v = 1;";
    env.host().loader = &loader;
    env.eval("var errors = []; window.addEventListener('error', e => errors.push(e.message));"
             "function module(src, text) { var s = document.createElement('script'); s.type = 'module';"
             "  if (src) s.src = src; else s.textContent = text; document.body.appendChild(s); }"
             "module('lib.mjs')");
    env.drain();
    CHECK_JS_EQ(env, "window.libRuns", "1");
    env.eval("module(null, \"import { v } from 'lib.mjs'; window.imported = v\");"
             "import('lib.mjs').then(m => { window.dynamic = m.v }, e => { window.dynamicError = e.message })");
    env.drain();
    CHECK_JS_EQ(env, "[String(window.imported), String(window.dynamic), window.libRuns].join()", "undefined,undefined,1");
    CHECK_JS_EQ(env, "errors.length", "1");
    CHECK_JS(env, "errors[0].indexOf(\"could not load module 'lib.mjs'\") >= 0");
    CHECK_JS(env, "window.dynamicError === \"could not load module 'lib.mjs'\"");
}

// An inline module script is named by the document's URL, as every inline one is: a later one cannot import it.
WR_TEST(testAnInlineModuleCannotImportTheDocumentURL) {
    wr_test::HostEnv env;
    env.eval("var errors = []; window.addEventListener('error', e => errors.push(e.message));"
             "function module(text) { var s = document.createElement('script'); s.type = 'module'; s.textContent = text; document.body.appendChild(s); }"
             "module('export const w = 2; window.first = true');"
             "module(\"import { w } from '\" + document.URL + \"'; window.w = w\")");
    env.drain();
    CHECK_JS_EQ(env, "[window.first, String(window.w), errors.length].join()", "true,undefined,1");
    CHECK_JS(env, "errors[0].indexOf(\"could not load module '\" + document.URL + \"'\") >= 0");
}

namespace {

/// `count` module scripts, each through Runtime::runScript (the JS_Eval every module script element ends in) with a URL
/// of its own: each leaves its module in QuickJS's list of loaded modules.
void runModuleScripts(wr_test::HostEnv& env, int count) {
    for (int i = 0; i < count; i++) {
        env.runtime().runScript("", ("m" + std::to_string(i) + ".mjs").c_str(), true);
    }
}

} // namespace

// Fix round 2, J2: every import reaches the runtime's module normalize hook, which refuses it before QuickJS looks the
// name up among the loaded modules. In js_host_resolve_imported_module (third-party/quickjs-ng/quickjs/quickjs.c) the
// hook is called at :31207, a refusal returns at :31210 (`if (!cname) return NULL;`), and the lookup,
// js_find_loaded_module, is at :31220. After 2,000 module scripts, 100 import() calls and 50 module scripts with
// a static import are 150 refusals: 150 imports that did not walk the list. Without the hook none is counted.
WR_TEST(testEveryImportIsRefusedBeforeTheLoadedModuleLookup) {
    wr_test::HostEnv env;
    runModuleScripts(env, 2000);
    uint64_t before = env.runtime().refusedImports();
    env.eval("for (let i = 0; i < 100; i++) import('m' + i + '.mjs').catch(() => {})");
    for (int i = 0; i < 50; i++) {
        std::string source = "import 'm" + std::to_string(i) + ".mjs'";
        CHECK(!env.runtime().runScript(source, ("s" + std::to_string(i) + ".mjs").c_str(), true));
    }
    CHECK_EQ(env.runtime().refusedImports() - before, uint64_t(150));
}

// Fix round 1, M1: HTML's tree builder sets force async false for every script it makes, the fragment parser's
// included. The document parser's "prepare" at </script> then sets it true again for a script in template contents
// without an async attribute (step 4, before step 7 returns: not connected).
WR_TEST(testParsedScriptsForceAsyncFollowsHTML) {
    wr_test::HostEnv env("<!doctype html><html><head></head><body><template id=t><script>1</script><script async>2</script></template></body></html>");
    CHECK_JS_EQ(env, "[...document.getElementById('t').content.children].map(s => s.async).join()", "true,true");
    CHECK_EVAL_EQ(env, "var a = document.getElementById('t').content.lastChild; a.removeAttribute('async'); a.async", "false");
    CHECK_EVAL_EQ(env, "var d = document.createElement('div'); d.innerHTML = '<script>1<\\/script>'; d.firstChild.async", "false");
}

// Fix round 1, M2: the src attribute change steps run only when src is set ("value is not null"): removing it from a
// connected script that has not started prepares nothing (here a parsed one the boot has not run: its inline text
// would run as a script-inserted script, and it would lose its parser document).
WR_TEST(testRemovingSrcPreparesNothing) {
    wr_test::HostEnv env("<!doctype html><html><head><script id=p src=lib.js>log.push('inline')</script></head><body></body></html>");
    CHECK_EVAL_EQ(env, "var log = []; var p = document.getElementById('p'); p.removeAttribute('src'); [log.join(), p.async].join()", ",false");
}

// Fix round 1, M3: a type too long or not ASCII is no type HTML knows, and the diagnostic says so in words.
WR_TEST(testAnUnreadableScriptTypeIsDiagnosedInWords) {
    wr_test::HostEnv env;
    env.eval("for (const type of ['x'.repeat(100), 'text/javascr\\u00efpt']) { var s = document.createElement('script');"
             "  s.type = type; s.textContent = '1'; document.body.appendChild(s); }");
    int readable = 0;
    for (const auto& d : env.host().diagnostics) {
        CHECK(d.second.find('\x01') == std::string::npos);
        readable += d.first == "script-skipped" && d.second.find("too long or non-ASCII") != std::string::npos;
    }
    CHECK_EQ(readable, 2);
}

// Fix round 1, M4 (coverage). Ruling R4's accepted divergence: a module whose evaluation is still pending when its
// script returns (top-level await) and rejects later is an unhandled rejection, not a reported exception.
WR_TEST(testAModuleThatRejectsLaterIsAnUnhandledRejection) {
    wr_test::HostEnv env;
    env.eval("var rejections = [], errors = [];"
             "window.addEventListener('unhandledrejection', e => rejections.push(e.reason.message)); window.addEventListener('error', e => errors.push(e.message));"
             "var s = document.createElement('script'); s.type = 'module'; s.textContent = \"await null; throw new Error('late')\"; document.body.appendChild(s)");
    env.drain();
    CHECK_JS_EQ(env, "[rejections.join(), errors.length].join()", "late,0");
}

// An external script's own exception is reported, and load still fires at the element (HTML "execute the script
// element", step 8, after the run whatever it threw).
WR_TEST(testLoadFiresAfterAnExternalScriptThrows) {
    wr_test::HostEnv env;
    wr_test::MapScriptLoader loader;
    loader.sources["boom.js"] = "throw new Error('boom')";
    env.host().loader = &loader;
    env.eval("var log = []; window.addEventListener('error', e => log.push('error:' + (e.message.indexOf('boom') >= 0)));"
             "var s = document.createElement('script'); s.src = 'boom.js'; s.addEventListener('load', () => log.push('load')); document.body.appendChild(s)");
    env.drain();
    CHECK_JS_EQ(env, "log.join()", "error:true,load");
}

// A stop unwinding through "execute the script element" puts currentScript back (read natively: no script runs after a
// stop).
WR_TEST(testAStopInsideAScriptRestoresCurrentScript) {
    wr_test::ScopedProductSlices slices;
    wr_test::HostEnv env;
    wr_test::stopAfter(env.runtime());
    std::string result = env.eval("var s = document.createElement('script'); s.textContent = 'for (;;) {}'; document.body.appendChild(s); 'done'");
    CHECK_EQ(result, std::string("ABORTED"));
    CHECK(wr::globalDocument(env.ctx()).currentScriptElement() == nullptr);
}
