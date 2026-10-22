// Calibration of the DOM's work rates (M1a plan, Global Constraints "Work"): every native operation, run to a fixed
// budget, spends at most kCeilingPerUnit times the reference loop's wall time per unit and stops within
// kCeilingOverrun times what the budget is worth at the reference rate. An attack that fails has a loop that charges
// too little: the fix is its charge (more units, or a charge where there was none), never the ceilings. Run optimized:
//   ./build-input/bazel-9.2.0-darwin-arm64 test -c opt
//   //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeWorkCostTests --test_output=all
// (WR_ATTACK=<substring> in the environment runs only the attacks whose names contain it, when run by hand.)
//
// The host this runs on is usually loaded (other builds), and a thread can land on an efficiency core. So the thread
// asks for user-interactive QoS, and each attack is measured in three passes, each running the reference loop
// immediately before the attack in fresh runtimes and comparing the two as ratios: per unit (attack ns/unit over the
// reference's) and overrun (attack ns over the budget's worth at that pass's reference rate). An attack passes when
// one of its passes passes both; the table prints its best pass.
#include <pthread.h>
#include <signal.h>
#include <unistd.h>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Sources/Support/Work.h"
#include "Tests/DOMHarness.h"
#include "Tests/HostHarness.h"

namespace {

constexpr uint64_t kBudget = 4000000;
constexpr double kCeilingPerUnit = 2.0;
constexpr double kCeilingOverrun = 2.5;
/// A run that has not reached its budget by then is an uncharged path: it fails the program rather than hanging it.
constexpr unsigned kAlarmSeconds = 20;

const char* g_current = "";

void onAlarm(int) {
    char line[256];
    int n = std::snprintf(line, sizeof(line), "FAIL: %s did not reach its budget in %u s (an uncharged path)\n", g_current, kAlarmSeconds);
    (void)!write(1, line, n > 0 ? size_t(n) : 0);
    _exit(1);
}

/// The loop's iteration count, read without running script: the runtime stopped for good when the budget ran out.
uint64_t iterationsOf(JSContext* ctx) {
    JSValue global = JS_GetGlobalObject(ctx);
    JSValue n = JS_GetPropertyStr(ctx, global, "__n");
    double d = 0;
    if (!JS_IsException(n)) {
        JS_ToFloat64(ctx, &d, n);
    }
    JS_FreeValue(ctx, n);
    JS_FreeValue(ctx, global);
    return uint64_t(d);
}

/// `body` runs in `for (;;) { __n++; body }` after `setup` ran unbudgeted. `minUnitsPerIteration` guards a case a cap
/// or an early return could make trivially cheap: an iteration must spend at least that many units.
struct Attack {
    const char* name;
    const char* setup;
    const char* body;
    uint64_t minUnitsPerIteration = 0;
    /// Run in a host environment (the Window, Intl) instead of the DOM alone.
    bool host = false;
};

#define DEEP_CHAIN(n) "var d = document.body; for (let i = 0; i < " #n "; i++) d = d.appendChild(document.createElement('div'));"
#define WIDE_TREE "var root = document.body.appendChild(document.createElement('div')); for (let i = 0; i < 5000; i++) root.appendChild(document.createElement('p')).textContent = 'text';"
#define WIDE_EMPTY "var root = document.body.appendChild(document.createElement('div')); for (let i = 0; i < 5000; i++) root.appendChild(document.createElement('p'));"
// 5,000 <p>s whose id and name are one shared 64 Ki-unit string; `miss` has its length and differs in its last unit,
// so every comparison reads the whole of it.
#define WIDE_LONG_IDS "var root = document.body.appendChild(document.createElement('div')), L = 'x'.repeat(1 << 16), miss = 'y'.padStart(1 << 16, 'x'); for (let i = 0; i < 5000; i++) { const p = root.appendChild(document.createElement('p')); p.id = L; p.setAttribute('name', L); }"
// `outer` holds n templates, each in the contents of the one above; `inner` is the innermost contents.
#define NESTED_TEMPLATES(n) "var outer = document.createElement('template'), cur = outer; for (let i = 0; i < " #n "; i++) { const t = document.createElement('template'); cur.content.appendChild(t); cur = t; } var inner = cur.content;"

const Attack kReference = {"reference: arithmetic loop", "var s = 0;", "s = (s + 1) | 0;"};

const Attack kAttacks[] = {
    kReference,
    {"binding getter", "var e = document.createElement('p'), x;", "x = e.localName;"},
    {"append and remove a leaf", "var c = document.createElement('i');", "document.body.appendChild(c); c.remove();"},
    {"contains on a deep chain", DEEP_CHAIN(20000), "document.documentElement.contains(d);"},
    {"getRootNode on a deep chain", DEEP_CHAIN(20000), "d.getRootNode();"},
    {"compareDocumentPosition on a deep chain", DEEP_CHAIN(20000), "d.compareDocumentPosition(document.body);"},
    {"querySelectorAll by class", "for (let i = 0; i < 10000; i++) document.body.appendChild(document.createElement('p')).className = 'a';", "document.querySelectorAll('.a');"},
    // A class collection over many classes, recomputed after each change on an empty root: reading the class list is
    // charged kNodeVisit per class before the walk, so the recompute cannot freeze uncharged (the per-recompute copy
    // was the defect). The version bump makes it recompute each iteration.
    {"getElementsByClassName recompute, 500,000 classes", "var e = document.body.appendChild(document.createElement('div')); var c = e.getElementsByClassName(Array.from({length: 500000}, (_, i) => 'k' + i).join(' ')); c.length;", "e.id = e.id === 'a' ? 'b' : 'a'; c.length;", 500000 * wr::work::kNodeVisit},
    {"failing descendant selector", DEEP_CHAIN(2000), "document.querySelectorAll('x div');"},
    {"attribute substring selector", "document.body.setAttribute('v', 'ab'.repeat(1 << 20));", "document.querySelector('[v*=\"abc\"]');"},
    {"nth-child over wide siblings", WIDE_TREE, "root.querySelectorAll(':nth-child(2n+1)');"},
    // The brief's '.a'.repeat(20000) is over the 16,384-unit selector cap (a SyntaxError on the length alone).
    {"selector parse, long selector", "var sel = '.a'.repeat(8192);", "document.querySelector(sel);", 16384 * wr::work::kParseByte},
    {"innerHTML serialize", WIDE_TREE " var x;", "x = root.innerHTML;"},
    {"innerHTML parse", "var root = document.body.appendChild(document.createElement('div')), m = '<p class=a>text</p>'.repeat(5000);", "root.innerHTML = m;"},
    {"textContent of a tree", WIDE_TREE " var x;", "x = root.textContent;"},
    {"cloneNode(true)", WIDE_TREE, "root.cloneNode(true);"},
    {"live collection after a change", WIDE_TREE " var list = root.getElementsByTagName('p'), x;", "root.appendChild(root.firstChild); x = list.length;"},
    {"getAttribute among many attributes", "var e = document.createElement('p'); for (let i = 0; i < 20000; i++) e.setAttribute('a' + i, 'v'); var x;", "x = e.getAttribute('a19999');"},
    {"classList.contains with many classes", "var e = document.createElement('p'); e.className = 'c '.repeat(1 << 16) + 'z'; var x;", "x = e.classList.contains('y');"},
    {"getElementById in a wide tree", WIDE_TREE " var x;", "x = document.getElementById('missing');"},
    {"normalize", WIDE_TREE, "root.append('a', 'b'); root.normalize();"},

    // Selectors (Task 17): every simple of a compound evaluated, and the componentizer's copying.
    {"qSA :defined x2048 over 5,000 <p>", WIDE_TREE " var sel = ':defined'.repeat(2048);", "root.querySelectorAll(sel);", 5000 * 2048},
    // Empty <p>s: with WIDE_TREE's text the first :empty fails and the rest are never evaluated.
    {"qSA :empty x2730 over 5,000 empty <p>", WIDE_EMPTY " var sel = ':empty'.repeat(2730);", "root.querySelectorAll(sel);", 5000 * 2730},
    {"qSA :read-only x1638 over 5,000 <p>", WIDE_TREE " var sel = ':read-only'.repeat(1638);", "root.querySelectorAll(sel);", 5000 * 1638},
    {"parse: 64-deep ( nest to the cap", "var sel = '('.repeat(64) + '*'.repeat(16384 - 128) + ')'.repeat(64);", "try { document.querySelector(sel); } catch (e) {}", 64 * 16256},
    {"parse: 64-deep [ nest to the cap", "var sel = '['.repeat(64) + '*'.repeat(16384 - 128) + ']'.repeat(64);", "try { document.querySelector(sel); } catch (e) {}", 64 * 16256},
    {"parse: 63-deep nest around :is(p,...)", "var sel = '('.repeat(63) + ':is(' + 'p,'.repeat(8126) + 'p)' + ')'.repeat(63);", "try { document.querySelector(sel); } catch (e) {}", 63 * 16252},
    {"parse: flat [a] x5461", "var sel = '[a]'.repeat(5461);", "document.querySelector(sel);", 16383 * wr::work::kParseByte},
    {"parse: flat [a=b i] x2340", "var sel = '[a=b i]'.repeat(2340);", "document.querySelector(sel);", 16380 * wr::work::kParseByte},
    {"parse: flat [a*=b] x2730", "var sel = '[a*=b]'.repeat(2730);", "document.querySelector(sel);", 16380 * wr::work::kParseByte},

    // String scans (Tasks 11 and 12), charged at kScanEightUnits.
    {"classList.contains, 4 MiB className", "var e = document.createElement('p'); e.className = 'a'.repeat(1 << 22); var t = 'b'.padStart(1 << 22, 'a'), x;", "x = e.classList.contains(t);", (1 << 22) / 8},
    {"classList.contains, 4 MiB of distinct classes", "var e = document.createElement('p'); e.className = Array.from({length: 1 << 19}, (_, i) => 'c' + i).join(' '); var x;", "x = e.classList.contains('y');"},
    {"classList.add, 4 MiB className", "var e = document.createElement('p'); e.className = 'a'.repeat(1 << 22);", "e.classList.add('y');", (1 << 22) / 8},
    {"classList.toggle, 4 MiB className", "var e = document.createElement('p'); e.className = 'a'.repeat(1 << 22);", "e.classList.toggle('y');", (1 << 22) / 8},
    {"getAttribute, long prefixed name", "var e = document.createElement('p'); e.setAttributeNS('urn:x', 'p:' + 'a'.repeat(1 << 20), 'v'); var q = ['p:', 'a'.repeat((1 << 20) - 1), 'b'].join(''), x;", "x = e.getAttribute(q);", (1 << 20) / 8},
    {"getAttribute, long name without a colon", "var e = document.createElement('p'); e.setAttribute('a'.repeat(1 << 20), 'v'); var q = 'b'.padStart(1 << 20, 'a'), x;", "x = e.getAttribute(q);", (1 << 20) / 8},
    {"setAttribute, long upper-case name", "var e = document.createElement('p'), q = 'A'.repeat(1 << 20);", "e.setAttribute(q, 'v');", (1 << 20) / 8},
    {"setAttributeNS, long qualified name", "var e = document.createElement('p'), q = ['p:', 'a'.repeat(1 << 20)].join('');", "e.setAttributeNS('urn:x', q, 'v');", (1 << 20) / 8},
    {"createElement, long name", "var q = 'A'.repeat(1 << 20);", "document.createElement(q);", (1 << 20) / 8},
    {"createElementNS, long qualified name", "var q = ['p:', 'a'.repeat(1 << 20)].join('');", "document.createElementNS('urn:x', q);", (1 << 20) / 8},
    {"dataset get, long name", "var e = document.createElement('p'), k = 'aB'.repeat(1 << 18); e.dataset[k] = 'v'; var x;", "x = e.dataset[k];", (1 << 19) / 8},
    {"dataset set, long name", "var e = document.createElement('p'), k = 'aB'.repeat(1 << 18);", "e.dataset[k] = 'v';", (1 << 19) / 8},
    {"dataset names, long attribute names", "var e = document.createElement('p'); for (let i = 0; i < 64; i++) e.setAttribute('data-' + String(i).padStart(1 << 16, 'a'), 'v'); var x;", "x = Object.keys(e.dataset);", 64 * (1 << 16) / 8},
    {"getElementById, long id in a wide tree", WIDE_LONG_IDS " var x;", "x = document.getElementById(miss);", 5000 * (1 << 16) / 8},
    {"getElementsByName, long name in a wide tree", WIDE_LONG_IDS " var x;", "x = document.getElementsByName(miss).length;", 5000 * (1 << 16) / 8},
    {"namedItem, long id in a wide tree", WIDE_LONG_IDS " var kids = root.children, x;", "x = kids.namedItem(miss);", 5000 * (1 << 16) / 8},
    {"[v=...] over long equal-prefix values", "var root = document.body.appendChild(document.createElement('div')), L = 'x'.repeat(16378); for (let i = 0; i < 5000; i++) root.appendChild(document.createElement('p')).setAttribute('v', L); var sel = '[v=\"' + 'y'.padStart(16378, 'x') + '\"]';", "root.querySelectorAll(sel);", 5000 * 16378 / 8},
    {"isEqualNode, long equal-prefix attribute values", "var a = document.createElement('p'), b = document.createElement('p'); a.setAttribute('v', 'x'.repeat(1 << 22)); b.setAttribute('v', 'y'.padStart(1 << 22, 'x')); var x;", "x = a.isEqualNode(b);", (1 << 22) / 8},
    {"isEqualNode, long equal-prefix text", "var a = document.createTextNode('x'.repeat(1 << 22)), b = document.createTextNode('y'.padStart(1 << 22, 'x')); var x;", "x = a.isEqualNode(b);", (1 << 22) / 8},
    // A refused name is quoted in the error's message, converted to UTF-8 whole (three bytes a unit here).
    {"createElement, long invalid name (message)", "var q = ' '.padStart((1 << 20) + 1, '\\u4e00');", "try { document.createElement(q); } catch (e) {}", (1 << 20) / 8},
    {"createElementNS, long invalid prefix (message)", "var q = '>:a'.padStart((1 << 20) + 3, '\\u4e00');", "try { document.createElementNS('urn:x', q); } catch (e) {}", (1 << 20) / 8},
    {"createAttribute, long invalid name (message)", "var q = ' '.padStart((1 << 20) + 1, '\\u4e00');", "try { document.createAttribute(q); } catch (e) {}", (1 << 20) / 8},
    {"setAttribute, long invalid name (message)", "var e = document.createElement('p'), q = ' '.padStart((1 << 20) + 1, '\\u4e00');", "try { e.setAttribute(q, 'v'); } catch (e) {}", (1 << 20) / 8},
    {"setAttributeNS, long invalid prefix (message)", "var e = document.createElement('p'), q = '>:a'.padStart((1 << 20) + 3, '\\u4e00');", "try { e.setAttributeNS('urn:x', q, 'v'); } catch (e) {}", (1 << 20) / 8},
    {"dataset set, long invalid name (message)", "var e = document.createElement('p'), k = '-a'.padStart((1 << 20) + 2, '\\u4e00');", "try { e.dataset[k] = 'v'; } catch (e) {}", (1 << 20) / 8},
    {"dataset set, long invalid attribute name (message)", "var e = document.createElement('p'), k = '>'.padStart((1 << 20) + 1, '\\u4e00');", "try { e.dataset[k] = 'v'; } catch (e) {}", (1 << 20) / 8},

    // The serializer (Task 16).
    {"innerHTML of 20,000 attributes", "var w = document.createElement('div'), e = w.appendChild(document.createElement('p')); for (let i = 0; i < 20000; i++) e.setAttribute('a' + i, ''); var x;", "x = w.innerHTML;", 20000 * wr::work::kNodeVisit},
    {"innerHTML of text to escape", "var w = document.createElement('div'); w.textContent = '&<>\\u00a0'.repeat(1 << 18); var x;", "x = w.innerHTML;"},
    {"innerHTML of an attribute value to escape", "var w = document.createElement('div'); w.appendChild(document.createElement('p')).setAttribute('v', '&\"<>\\u00a0'.repeat(1 << 18)); var x;", "x = w.innerHTML;"},
    {"outerHTML of 20,000 nested templates", NESTED_TEMPLATES(20000) " var x;", "x = outer.outerHTML;", 20000 * wr::work::kNodeVisit},

    // The fragment parser (Task 15), on gumbo's pathological input classes (third-party/gumbo/VENDOR.md).
    {"innerHTML = <li> x32768", "var w = document.createElement('div'), m = '<li>'.repeat(1 << 15);", "w.innerHTML = m;"},
    {"innerHTML = <ul><li> x16384 (nested)", "var w = document.createElement('div'), m = '<ul><li>'.repeat(1 << 14);", "w.innerHTML = m;"},
    // 512 closed, distinct <b>s fill the list of active formatting elements while the stack sits one below gumbo's
    // depth limit: every "x" reconstructs, walking back over all of them.
    {"innerHTML = 512 formatting elements at the depth limit", "var w = document.createElement('div'), m = '<div>'.repeat(508); for (let i = 0; i < 512; i++) m += '<b a=' + i + '></div><div>'; m += '<div>x</div>'.repeat(20000);", "w.innerHTML = m;"},
    {"innerHTML = <table> + a<!----> x32768", "var w = document.createElement('div'), m = '<table>' + 'a<!---->'.repeat(1 << 15);", "w.innerHTML = m;"},
    {"innerHTML = <div> x20000 (past 256 deep)", "var w = document.createElement('div'), m = '<div>'.repeat(20000);", "w.innerHTML = m;"},
    // The markup is converted to UTF-8 (three bytes a unit here) before gumbo reads it. 1 Mi units is the largest a
    // script may parse (MarkupMembers.cpp caps it at 1,048,576); past it the setter throws NotSupportedError.
    {"innerHTML = 1 Mi CJK units", "var w = document.createElement('div'), m = '\\u4e00'.repeat(1 << 20);", "w.innerHTML = m;", (1 << 20) * wr::work::kParseByte},
    // The context element's local name is looked up among gumbo's tags (fix round 1: it was converted whole, uncharged).
    {"innerHTML = '' on a 1 Mi-unit-named element", "var e = document.createElement('a' + '\\u4e00'.repeat(1 << 20));", "e.innerHTML = '';"},
    {"outerHTML set under a 1 Mi-unit-named parent", "var p = document.createElement('a' + '\\u4e00'.repeat(1 << 20)); p.appendChild(document.createElement('i'));", "p.lastChild.outerHTML = '<i></i>';"},
    {"innerHTML = CRLF-heavy SVG", "var w = document.createElement('div'), m = '<svg\\r\\n viewBox=\"0 0 1 1\">\\r\\n<linearGradient\\r\\n id=g>\\r\\n<stop\\r\\n offset=0/>\\r\\n</linearGradient\\r\\n>\\r\\n</svg\\r\\n>\\r\\n'.repeat(2000);", "w.innerHTML = m;"},

    // The pre-insert check walks the host-including ancestors of the innermost contents (Task 15). The node inserted
    // has a child: a leaf is never a host-including ancestor of anything, and the walk returns at once.
    {"insert into the innermost of 20,000 nested templates", NESTED_TEMPLATES(20000) " var c = document.createElement('div'); c.appendChild(document.createElement('i'));", "inner.appendChild(c); c.remove();", 40000 * wr::work::kNodeVisit},

    // Indexed reads (Task 7's ruling: no fork change 6 unless calibration shows they matter).
    {"children[i] over 5,000 children", WIDE_TREE " var kids = root.children, x;", "for (let i = 0; i < 5000; i++) x = kids[i];"},
    {"childNodes[i] over 5,000 children", WIDE_TREE " var kids = root.childNodes, x;", "for (let i = 0; i < 5000; i++) x = kids[i];"},
    {"Object.keys(childNodes) over 5,000 children", WIDE_TREE " var kids = root.childNodes, x;", "x = Object.keys(kids);"},
    {"Object.keys(attributes) over 20,000 attributes", "var e = document.createElement('p'); for (let i = 0; i < 20000; i++) e.setAttribute('a' + i, 'v'); var m = e.attributes, x;", "x = Object.keys(m);"},

    // ECMA-402 TransformCase over ICU (v0.1.1 plan, Task 10): a language with its own case rules, charged per eight
    // units for the copy and again for the mapping (work::kCaseMapEightUnits).
    {"toLocaleUpperCase('tr'), 1 Mi units", "var s = 'i'.repeat(1 << 20), x;", "x = s.toLocaleUpperCase('tr');", (1 << 20) / 8 * (1 + wr::work::kCaseMapEightUnits), true},
    {"toLocaleLowerCase('tr'), 1 Mi units", "var s = '\\u0130'.repeat(1 << 20), x;", "x = s.toLocaleLowerCase('tr');", (1 << 20) / 8 * (1 + wr::work::kCaseMapEightUnits), true},
};

struct Run {
    bool setupOK = false;
    bool stopped = false;
    uint64_t spent = 0;
    uint64_t iterations = 0;
    double ns = 0;
    std::string result;
};

template <class Env>
Run runIn(const Attack& attack) {
    Run r;
    Env env;
    JSRuntime* rt = env.runtime().jsRuntime();
    alarm(kAlarmSeconds);
    std::string setup = env.eval(std::string(attack.setup) + " var __n = 0;");
    r.setupOK = setup.rfind("THROW", 0) != 0;
    if (!r.setupOK) {
        r.result = "setup: " + setup;
        alarm(0);
        return r;
    }
    std::string loop = std::string("for (;;) { __n++; ") + attack.body + " }";
    uint64_t start = JS_GetWorkUnits(rt);
    env.runtime().setWorkLimit(start + kBudget);
    auto t0 = std::chrono::steady_clock::now();
    bool aborted = false;
    try {
        r.result = env.eval(loop);
    } catch (const wr::Aborted&) {
        // A call into JS that latched the runtime ends in Aborted (evaluateToString included).
        aborted = true;
        r.result = "ABORTED";
    }
    // A HostEnv answers a stopped script with the text instead.
    aborted = aborted || r.result == "ABORTED";
    r.ns = std::chrono::duration<double, std::nano>(std::chrono::steady_clock::now() - t0).count();
    alarm(0);
    r.spent = JS_GetWorkUnits(rt) - start;
    // Only the budget stops the loop: any other outcome would end it having measured nothing.
    r.stopped = aborted && env.runtime().stopReason() == wr::StopReason::Budget;
    r.iterations = iterationsOf(env.ctx());
    return r;
}

Run run(const Attack& attack) {
    return attack.host ? runIn<wr_test::HostEnv>(attack) : runIn<wr_test::DOMEnv>(attack);
}

struct Pass {
    Run attack;
    double referencePerUnit = 0;
    double perUnit = 0;
    double ratio = 0;
    double overrun = 0;
    bool ok = false;
    /// How close to the ceilings: the larger of the two ratios, each over its ceiling (at most 1 passes).
    double score = 0;
};

Pass measure(const Attack& attack) {
    Pass p;
    g_current = kReference.name;
    Run reference = run(kReference);
    g_current = attack.name;
    p.attack = run(attack);
    p.referencePerUnit = reference.ns / double(reference.spent ? reference.spent : 1);
    p.perUnit = p.attack.ns / double(p.attack.spent ? p.attack.spent : 1);
    p.ratio = p.perUnit / p.referencePerUnit;
    p.overrun = p.attack.ns / (p.referencePerUnit * double(kBudget));
    p.score = std::max(p.ratio / kCeilingPerUnit, p.overrun / kCeilingOverrun);
    uint64_t perIteration = p.attack.spent / std::max<uint64_t>(p.attack.iterations, 1);
    bool enoughPerIteration = p.attack.iterations <= 1 || perIteration >= attack.minUnitsPerIteration;
    p.ok = reference.stopped && p.attack.setupOK && p.attack.stopped && p.attack.spent >= kBudget && enoughPerIteration &&
           p.ratio <= kCeilingPerUnit && p.overrun <= kCeilingOverrun;
    return p;
}

void printLoad(const char* when) {
    double load[3] = {0, 0, 0};
    getloadavg(load, 3);
    std::printf("load averages %s: %.2f %.2f %.2f\n", when, load[0], load[1], load[2]);
}

} // namespace

WR_TEST(testEveryNativeOperationIsChargedEnough) {
    // Line-buffered: the alarm ends the process with _exit, which would drop a block-buffered table.
    std::setvbuf(stdout, nullptr, _IOLBF, 0);
    signal(SIGALRM, onAlarm);
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    const char* only = std::getenv("WR_ATTACK");
    printLoad("before");
    std::printf("%-54s %10s %8s %9s %8s %8s %7s %8s  %s\n", "attack", "units", "ms", "units/it", "ns/unit", "ref ns", "x ref", "x budget", "x ref, passes 1/2/3");
    for (const Attack& attack : kAttacks) {
        if (only && *only && !std::strstr(attack.name, only)) {
            continue;
        }
        Pass best;
        double ratios[3];
        for (int pass = 0; pass < 3; pass++) {
            Pass p = measure(attack);
            ratios[pass] = p.ratio;
            if (pass == 0 || p.score < best.score || (p.ok && !best.ok)) {
                best = p;
            }
        }
        const Run& a = best.attack;
        uint64_t perIteration = a.spent / std::max<uint64_t>(a.iterations, 1);
        std::printf("%-54s %10llu %8.2f %9llu %8.2f %8.2f %7.2f %8.2f  %.2f/%.2f/%.2f %s\n", attack.name, (unsigned long long)a.spent, a.ns / 1e6,
                    (unsigned long long)perIteration, best.perUnit, best.referencePerUnit, best.ratio, best.overrun, ratios[0], ratios[1], ratios[2],
                    best.ok ? "" : "FAIL");
        if (!best.ok) {
            std::printf("  %s: %s, %llu iterations (at least %llu units each expected)\n", attack.name, a.result.c_str(), (unsigned long long)a.iterations,
                        (unsigned long long)attack.minUnitsPerIteration);
        }
        CHECK(best.ok);
    }
    printLoad("after");
}
