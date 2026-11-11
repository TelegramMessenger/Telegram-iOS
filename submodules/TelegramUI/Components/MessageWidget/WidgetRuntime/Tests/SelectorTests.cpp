#include <algorithm>
#include <chrono>
#include <pthread.h>
#include <string>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"

using wr_test::DOMEnv;

static const char* kIds = "function ids(list) { return [...list].map(e => e.id || e.localName).join(); }";

WR_TEST(testSimpleAndCompoundSelectors) {
    DOMEnv env("<!DOCTYPE html><div id=a class='x y'><p id=b class=x></p><span id=c></span></div><svg><foreignObject id=f></foreignObject></svg>");
    env.eval(kIds);
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('.x'))", "a,b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('div.x.y#a'))", "a");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('DIV, Span'))", "a,c");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('#a > *'))", "b,c");
    CHECK_JS(env, "document.querySelector('foreignObject').id === 'f' && document.querySelector('foreignobject') === null");
    CHECK_JS(env, "document.querySelector('*|p').id === 'b' && document.querySelector('|p') === null");
    CHECK_JS(env, "document.querySelector('.missing') === null && document.querySelectorAll('.missing').length === 0");
}

WR_TEST(testAttributeSelectors) {
    DOMEnv env("<!DOCTYPE html><input id=i type=CheckBox data-k='Alpha beta' lang=en-US><a id=l href='#x'></a><svg><use id=u xlink:href='#y'/></svg>");
    env.eval(kIds);
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('[type=checkbox]'))", "i");
    CHECK_JS(env, "document.querySelector('[data-k=alpha]') === null && document.querySelector('[data-k=\"alpha beta\" i]').id === 'i'");
    CHECK_JS(env, "document.querySelector('[type=checkbox s]') === null");
    CHECK_JS(env, "document.querySelector('[data-k~=beta]').id === 'i' && document.querySelector('[data-k~=\"\"]') === null");
    CHECK_JS(env, "document.querySelector('[lang|=en]').id === 'i' && document.querySelector('[lang|=e]') === null");
    CHECK_JS(env, "document.querySelector('[data-k^=Al]').id === 'i' && document.querySelector('[data-k$=ta]').id === 'i' && document.querySelector('[data-k*=\"ha b\"]').id === 'i'");
    CHECK_JS(env, "document.querySelector('[data-k^=\"\"]') === null && document.querySelector('[data-k*=\"\"]') === null");
    CHECK_JS(env, "document.querySelector('[href]').id === 'l' && document.querySelector('[*|href=\"#y\"]').id === 'u'");
    CHECK_JS(env, "document.querySelector('[DATA-K]').id === 'i'");
}

WR_TEST(testCombinatorsAndOrder) {
    DOMEnv env("<!DOCTYPE html><main id=m><section id=s><p id=p1></p><p id=p2></p><b id=b></b><p id=p3></p></section><p id=p4></p></main>");
    env.eval(kIds);
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('main p'))", "p1,p2,p3,p4");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('main > p'))", "p4");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('p + p'))", "p2");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('#p1 ~ p'))", "p2,p3");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('b, #p1, section'))", "s,p1,b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('main section > p ~ b + p'))", "p3");
    CHECK_JS(env, "(l => l instanceof NodeList && (document.querySelector('#b').remove(), l.length === 4))(document.querySelectorAll('p'))");
}

WR_TEST(testStructuralPseudoClasses) {
    DOMEnv env("<!DOCTYPE html><ul id=u><li id=a class=x></li><li id=b></li><!--c--><li id=c class=x></li><span id=d></span><li id=e class=x></li></ul><div id=empty><!--only a comment--></div>");
    env.eval(kIds);
    CHECK_JS(env, "document.querySelector(':root') === document.documentElement");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('#u > :first-child, #u > :last-child'))", "a,e");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('li:nth-child(odd)'))", "a,c,e");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('li:nth-child(2n)'))", "b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('#u > :nth-child(-n+2)'))", "a,b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('#u > :nth-last-child(1)'))", "e");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('li:nth-of-type(4)'))", "e");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('span:only-of-type, li:last-of-type'))", "d,e");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':nth-child(2 of .x)'))", "c");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('div:empty'))", "empty");
}

WR_TEST(testLogicalPseudoClassesAndScope) {
    DOMEnv env("<!DOCTYPE html><div id=r><p id=a class=x></p><div id=n><p id=b></p></div></div>");
    env.eval(kIds);
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('p:not(.x)'))", "b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('p:not(.x, #b)'))", "");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':is(#a, #b)'))", "a,b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':where(#n) p'))", "b");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':is()'))", "");
    CHECK_JS_EQ(env, "ids(document.querySelector('#r').querySelectorAll(':scope > p'))", "a");
    CHECK_JS(env, "document.querySelector(':scope') === document.documentElement");
    CHECK_JS(env, "document.querySelector('#b').matches(':scope') && !document.querySelector('#b').matches(':scope > p')");
}

WR_TEST(testStatePseudoClassesFromAttributes) {
    DOMEnv env("<!DOCTYPE html><input id=c type=checkbox checked><input id=d disabled><input id=r required placeholder=p><textarea id=t readonly></textarea><a id=l href=x></a><a id=n></a><select><option id=o selected></option></select>");
    env.eval(kIds);
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':checked'))", "c,o");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':default'))", "c,o");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('input:disabled'))", "d");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('input:enabled'))", "c,r");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':required'))", "r");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll('input:optional'))", "c,d");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':placeholder-shown'))", "r");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':read-write'))", "r");
    CHECK_JS(env, "document.querySelector('#t').matches(':read-only') && document.querySelector('#d').matches(':read-only')");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':any-link, :link'))", "l");
    CHECK_JS(env, "document.querySelector(':visited, :target, :focus, :hover, :active, :focus-within, :focus-visible, :indeterminate') === null");
    CHECK_JS(env, "document.querySelectorAll(':defined').length === document.getElementsByTagName('*').length");
}

WR_TEST(testInvalidSelectorsThrow) {
    DOMEnv env;
    for (const char* s : {"", " ", "..a", "a >", "> a", "a,,b", "[a=]", "[]", "[ns|a]", "ns|a", ":unknown", "::unknown", ":not()", ":nth-child(n+)", ":nth-child(2 of)", "#1a", "a!", ":has(a)", "a | b"}) {
        CHECK_THROWS(env, (std::string("document.querySelector('") + s + "')").c_str(), "SyntaxError");
    }
    CHECK_THROWS(env, "document.body.matches('a[')", "SyntaxError");
    CHECK_THROWS(env, "document.body.closest(':nth-child(x)')", "SyntaxError");
}

WR_TEST(testPseudoElementsMatchNothing) {
    DOMEnv env("<p>x</p>");
    CHECK_JS(env, "document.querySelector('p::before') === null && document.querySelector('p:after') === null");
    CHECK_JS(env, "!document.querySelector('p').matches('p::first-line') && document.querySelectorAll('::marker').length === 0");
}

WR_TEST(testMatchesAndClosest) {
    DOMEnv env("<!DOCTYPE html><div class=card data-action=open><span><b id=t>x</b></span></div>");
    CHECK_JS(env, "(t => t.matches('div b') && t.webkitMatchesSelector('#t') && !t.matches('span > div'))(document.querySelector('#t'))");
    CHECK_JS(env, "(t => t.closest('[data-action]').className === 'card' && t.closest('b') === t && t.closest('table') === null)(document.querySelector('#t'))");
}

WR_TEST(testQuirksModeClassesAndIdsIgnoreCase) {
    {
        DOMEnv env("<p class=Foo id=Bar>");
        CHECK_JS(env, "document.querySelector('.foo') !== null && document.querySelector('#bar') !== null");
    }
    {
        DOMEnv env("<!DOCTYPE html><p class=Foo id=Bar>");
        CHECK_JS(env, "document.querySelector('.foo') === null && document.querySelector('#bar') === null && document.querySelector('.Foo') !== null");
    }
}

// The three results: a failed ancestor search ends the match. Without FailsCompletely this tries C(30, 15) ways
// to place 15 <div>s among 30 ancestors.
WR_TEST(testDescendantChainsDoNotBacktrack) {
    std::string html = "<!DOCTYPE html>";
    for (int i = 0; i < 30; i++) {
        html += "<div>";
    }
    html += "<span></span>";
    DOMEnv env(html);
    std::string selector = "x";
    for (int i = 0; i < 15; i++) {
        selector += " div";
    }
    selector += " span";
    // Backtracking would try C(30, 15), about 155 million, placements.
    const double ms = wr_test::leastCpuMs([&] { CHECK_JS(env, ("document.querySelector('" + selector + "') === null").c_str()); }, 1);
    if (ms >= 100) {
        std::printf("  the chain took %.3f ms\n", ms);
    }
    CHECK(ms < 100);
}

WR_TEST(testHostileSelectors) {
    DOMEnv env("<p class=a>");
    CHECK_JS(env, "document.querySelector('.a'.repeat(8192)) !== null");
    CHECK_JS(env, "document.querySelector('p' + ' p'.repeat(1000)) === null");
    CHECK_THROWS(env, "document.querySelector('p' + ' p'.repeat(1100))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector(':is('.repeat(40) + 'p' + ')'.repeat(40))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('['.repeat(100000))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('('.repeat(100000))", "SyntaxError");
    CHECK_JS(env, "document.querySelector('[x=\"\\ud800\\u0000\"]') === null");
    CHECK_JS(env, "(p => { p.setAttribute('v', 'ab'.repeat(1 << 20)); return document.querySelector('[v*=\"' + 'ab'.repeat(500) + 'c\"]') === null; })(document.querySelector('p'))");
}

// ---- Beyond the brief: the parser's and matcher's own rules ----

static void* nestBrackets(void*) {
    DOMEnv env("<p>");
    CHECK_THROWS(env, "document.querySelector('[a=\")\"]('.repeat(2000))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('(\\\\)'.repeat(5000))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('(/*)*/'.repeat(2700))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector(':is('.repeat(4000))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('['.repeat(65))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('('.repeat(65) + 'p')", "SyntaxError");
    // Brackets inside a string open nothing.
    CHECK_JS(env, "document.querySelector('[a=\"' + '(['.repeat(1000) + '\"]') === null");
    return nullptr;
}

// The bracket cap counts the blocks litehtml's componentizer would open, not bracket characters: a ")" in a string,
// an escape or a comment closes nothing, so none of them can hide nesting. Counting characters, each of these let the
// componentizer recurse thousands of levels deep inside the length cap, past a 512 KiB stack.
WR_TEST(testBracketCapFollowsTheTokenizer) {
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    CHECK(pthread_create(&thread, &attributes, nestBrackets, nullptr) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
}

WR_TEST(testPseudoElementPositions) {
    DOMEnv env("<p>x</p>");
    // A pseudo-element ends its complex selector, only user-action pseudo-classes follow it, and none is valid inside
    // a functional pseudo-class (:not(::before) would otherwise match every element).
    for (const char* s : {"::before > p", "::before p", "p::before.x", "p::before#a", "p::before[a]", "p::before::after", "p:before:after", ":not(::before)", ":not(:after)", ":nth-child(1 of ::before)", "p::before:first-child"}) {
        CHECK_THROWS(env, (std::string("document.querySelector('") + s + "')").c_str(), "SyntaxError");
    }
    CHECK_JS(env, "document.querySelector('p::before:hover') === null && document.querySelector('p:after:focus') === null");
    // :is() drops what it cannot take.
    CHECK_JS(env, "document.querySelector(':is(::before, p)') === document.querySelector('p') && document.querySelector(':is(::before)') === null");
}

// CSS Syntax's <an+b> grammar, over tokens: whitespace only where it allows it, integers saturated.
WR_TEST(testAnPlusBGrammar) {
    DOMEnv env("<!DOCTYPE html><ul><li id=a></li><li id=b></li><li id=c></li><li id=d></li><li id=e></li></ul>");
    env.eval(kIds);
    const std::pair<const char*, const char*> valid[] = {
        {"2n+1", "a,c,e"}, {"2n + 1", "a,c,e"}, {"2n- 1", "a,c,e"}, {"2n -1", "a,c,e"}, {"2N-1", "a,c,e"},
        {"-n+3", "a,b,c"}, {"-n- -3", ""}, {"+n", "a,b,c,d,e"}, {"N", "a,b,c,d,e"}, {"-n-1", ""}, {"n-2", "a,b,c,d,e"},
        {" ODD ", "a,c,e"}, {"Even", "b,d"}, {"+5", "e"}, {"-2", ""}, {"0n+2", "b"}, {"-n+ 2", "a,b"},
        {"99999999999", ""}, {"99999999999n", ""}, {"99999999999n+1", "a"}, {"-99999999999n+3", "c"},
    };
    for (const auto& [anb, expected] : valid) {
        std::string query = std::string("ids(document.querySelectorAll('li:nth-child(") + anb + ")'))";
        if (std::string(anb) == "-n- -3") {
            CHECK_THROWS(env, (std::string("document.querySelector('li:nth-child(") + anb + ")')").c_str(), "SyntaxError");
            continue;
        }
        CHECK_JS_EQ(env, query.c_str(), expected);
    }
    for (const char* anb : {"2 n", "+ n", "- n", "n+-1", "n - -1", "2.0n", "3.0", "n-1a", "--n", "1 2", "n+", "odd 1", "+-n", "2n+ +1", "1e2", "of"}) {
        CHECK_THROWS(env, (std::string("document.querySelector('li:nth-child(") + anb + ")')").c_str(), "SyntaxError");
    }
}

WR_TEST(testCheckedNeedsACheckableControl) {
    DOMEnv env("<!DOCTYPE html><div id=v checked selected></div><input id=t type=text checked><input id=x checked><input id=k type=CHECKBOX checked><input id=r type=radio checked><option id=o selected></option><option id=p checked></option>");
    env.eval(kIds);
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':checked'))", "k,r,o");
    CHECK_JS_EQ(env, "ids(document.querySelectorAll(':default'))", "k,r,o");
}

// Template contents are a fragment whose host is the template: a combinator walks parents, which stop at the
// fragment, so nothing in the contents has the template (or anything above it) for an ancestor.
WR_TEST(testFragmentsAreTheirOwnRoot) {
    DOMEnv env("<!DOCTYPE html><div id=h><template id=t><section><p id=inner></p></section></template></div>");
    CHECK_JS(env, "(c => c.querySelector('section > p').id === 'inner' && c.querySelector('template p') === null && c.querySelector('#h p') === null)(document.querySelector('#t').content)");
    CHECK_JS(env, "document.querySelector('#inner') === null && document.querySelector('template p') === null");
    CHECK_JS(env, "(c => c.querySelector(':scope > section') === null && c.querySelector(':root') === null && c.firstChild.matches(':scope'))(document.querySelector('#t').content)");
}

/// The best of three runs of 20 queries each (the length cap keeps one parse short).
static double secondsToQuery(DOMEnv& env, const std::string& selectorExpression) {
    env.eval("var sel = " + selectorExpression);
    double best = 1e9;
    for (int run = 0; run < 3; run++) {
        auto start = std::chrono::steady_clock::now();
        env.eval("for (let i = 0; i < 20; i++) { try { document.querySelectorAll(sel) } catch (e) {} }");
        best = std::min(best, std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count());
    }
    return best;
}

// The parser reads token runs in place: whitespace runs (a comment between spaces makes another whitespace token),
// parts a forgiving list drops, and deeply nested lists are each linear. 4x the input in at most 8x the time, the
// larger one just inside the length cap.
WR_TEST(testSelectorParsingIsLinear) {
    DOMEnv env("<!DOCTYPE html><p class=a>");
    const std::vector<std::pair<std::string (*)(int), int>> classes = {
        {[](int n) { return "' /**/'.repeat(" + std::to_string(n) + ") + 'p' + ' /**/'.repeat(" + std::to_string(n) + ") + ' p'"; }, 1600},
        {[](int n) { return "':is(' + 'x!,'.repeat(" + std::to_string(n) + ") + 'p)'"; }, 5400},
        {[](int n) { return "':is('.repeat(31) + 'p,'.repeat(" + std::to_string(n) + ") + 'p' + ')'.repeat(31)"; }, 8000},
        {[](int n) { return "':not(' + '.a,'.repeat(" + std::to_string(n) + ") + '.b)'"; }, 5400},
        {[](int n) { return "'[a=\"' + 'x'.repeat(" + std::to_string(n) + ") + '\" i]'"; }, 16000},
    };
    for (const auto& [make, large] : classes) {
        CHECK(std::stoi(env.eval("(" + make(large) + ").length")) <= 16384);
        double smallTime = secondsToQuery(env, make(large / 4));
        double largeTime = secondsToQuery(env, make(large));
        CHECK(largeTime <= 8 * smallTime + 0.01);
    }
}

static void* matchDeepSelectors(void*) {
    DOMEnv env("<!DOCTYPE html>");
    // 1,100 nested divs (script nests past the parser's 256 levels) and 1,100 sibling divs.
    env.eval("var d = document.body; for (let i = 0; i < 1100; i++) d = d.appendChild(document.createElement('div')); var s = document.createElement('section'); document.body.append(s); for (let i = 0; i < 1100; i++) s.append(document.createElement('div'))");
    // The matcher's deepest recursion: a frame per compound, 1,024 of them.
    CHECK_JS(env, "d.matches('div' + ' div'.repeat(1023))");
    CHECK_JS(env, "s.lastChild.matches('div' + ' + div'.repeat(1023))");
    CHECK_JS(env, "s.lastChild.matches('div' + ' ~ div'.repeat(1023))");
    // 32 nested lists, each a long chain; and 64 brackets deep in the componentizer.
    CHECK_JS(env, "d.matches(':is('.repeat(32) + 'div' + ' div'.repeat(900) + ')'.repeat(32))");
    CHECK_THROWS(env, "document.querySelector('('.repeat(64) + ')'.repeat(64))", "SyntaxError");
    CHECK_THROWS(env, "document.querySelector('[a=' + '['.repeat(63) + ']'.repeat(63) + ']')", "SyntaxError");
    return nullptr;
}

// Ruling 6's caps bound the native recursion: the deepest selectors match on a 512 KiB stack (pool threads have 2 MB,
// of which QuickJS's own limit leaves script at most 1 MB).
WR_TEST(testDeepSelectorsOnASmallStack) {
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    CHECK(pthread_create(&thread, &attributes, matchDeepSelectors, nullptr) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
}

// Ruling 6's length cap (pre-review ruling): at most 16,384 UTF-16 units, checked on the string's length before it
// is converted, so a longer one is a SyntaxError in O(1) that no forgiving list drops. It bounds the parse's
// transient C++ heap (Selectors.cpp, at the cap).
WR_TEST(testSelectorLengthCap) {
    DOMEnv env("<!DOCTYPE html><p></p>");
    env.eval("var p = document.querySelector('p'); p.setAttribute('v', 'x'.repeat(16378)); p.setAttribute('w', '\\u4e00'.repeat(16378))");
    // [v="…"] is 6 units around the value: exactly 16,384 parses and matches, one more is over the cap.
    CHECK_JS(env, "document.querySelector('[v=\"' + 'x'.repeat(16378) + '\"]') === p");
    CHECK_THROWS(env, "document.querySelector('[v=\"' + 'x'.repeat(16379) + '\"]')", "SyntaxError");
    CHECK_THROWS(env, "p.matches('[v=\"' + 'x'.repeat(16379) + '\"]')", "SyntaxError");
    CHECK_THROWS(env, "p.closest('[v=\"' + 'x'.repeat(16379) + '\"]')", "SyntaxError");
    // Units, not UTF-8 bytes: 16,384 units of CJK are 49,140 bytes and still parse.
    CHECK_JS(env, "document.querySelector('[w=\"' + '\\u4e00'.repeat(16378) + '\"]') === p");
    // Inside a forgiving list the whole selector is still over: nothing is dropped.
    CHECK_THROWS(env, "document.querySelector(':is(p, ' + 'x'.repeat(16384) + ')')", "SyntaxError");
    // A 10 MB string throws on its length.
    env.eval("var huge = 'a'.repeat(10 << 20)");
    CHECK_THROWS(env, "document.querySelector(huge)", "SyntaxError");
}

