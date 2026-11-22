#include <pthread.h>

#include <algorithm>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"

using wr_test::DOMEnv;

static void addDiv(DOMEnv& env) {
    env.eval("var div = document.body.appendChild(document.createElement('div'))");
}

WR_TEST(testInnerHTMLRoundTrips) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.innerHTML = '<p class=\"a\" id=x>t<b>u</b></p><!--c--><br><img src=y>'");
    CHECK_JS_EQ(env, "div.innerHTML", "<p class=\"a\" id=\"x\">t<b>u</b></p><!--c--><br><img src=\"y\">");
    CHECK_JS(env, "div.childNodes.length === 4 && div.firstChild.localName === 'p' && div.lastChild.localName === 'img'");
}

// Review Focus 4: escaping per the spec, and hostile strings survive.
WR_TEST(testSerializationEscapes) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.textContent = 'a&b<c>d\"e\\u00a0f'");
    CHECK_JS_EQ(env, "div.innerHTML", "a&amp;b&lt;c&gt;d\"e&nbsp;f");
    env.eval("div.textContent = ''; div.setAttribute('t', 'a&b<c>d\"e\\u00a0f')");
    CHECK_JS_EQ(env, "div.outerHTML", "<div t=\"a&amp;b&lt;c&gt;d&quot;e&nbsp;f\"></div>");
    CHECK_JS(env, "(s => { s.textContent = 'a<b>&'; return s.outerHTML === '<script>a<b>&</script>'; })(document.createElement('script'))");
    CHECK_JS(env, "(s => { s.textContent = 'x<y'; return s.outerHTML === '<style>x<y</style>'; })(document.createElement('style'))");
    CHECK_JS(env, "(s => { s.textContent = 'x<y'; return s.outerHTML === '<svg:style>x&lt;y</svg:style>'; })(document.createElementNS('urn:x', 'svg:style'))");
    env.eval("div.removeAttribute('t'); div.textContent = '\\ud800\\u0000x'");
    CHECK_JS(env, "div.innerHTML === '\\ud800\\u0000x'");
    env.eval("div.setAttribute('big', 'x'.repeat(4 << 20))");
    CHECK_JS(env, "div.outerHTML.length > (4 << 20)");
}

WR_TEST(testForeignAndNamespacedNames) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.innerHTML = '<svg viewBox=\"0 0 1 1\"><foreignObject></foreignObject><use xlink:href=\"#a\"></use></svg><math><mi xml:lang=\"en\"></mi></math>'");
    CHECK_JS_EQ(env, "div.innerHTML", "<svg viewBox=\"0 0 1 1\"><foreignObject></foreignObject><use xlink:href=\"#a\"></use></svg><math><mi xml:lang=\"en\"></mi></math>");
    CHECK_JS_EQ(env, "(e => { e.setAttributeNS('urn:y', 'z:w', '1'); return e.outerHTML; })(document.createElementNS('urn:x', 'p:q'))", "<p:q z:w=\"1\"></p:q>");
    CHECK_JS_EQ(env, "(e => { e.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns', 'urn:x'); e.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:k', 'urn:k'); return e.outerHTML; })(document.createElementNS('http://www.w3.org/2000/svg', 'g'))", "<g xmlns=\"urn:x\" xmlns:k=\"urn:k\"></g>");
}

WR_TEST(testTemplateSerialization) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.innerHTML = '<template><p>x</p></template>'; var t = div.firstChild");
    CHECK_JS(env, "t.childNodes.length === 0 && t.content.firstChild.localName === 'p'");
    CHECK_JS_EQ(env, "div.innerHTML", "<template><p>x</p></template>");
    env.eval("t.innerHTML = '<i>y</i>'");
    CHECK_JS(env, "t.childNodes.length === 0 && t.content.childNodes.length === 1 && t.content.firstChild.localName === 'i'");
    CHECK_JS_EQ(env, "t.innerHTML", "<i>y</i>");
}

WR_TEST(testInnerHTMLSetterReplacesChildren) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.innerHTML = '<p>old</p>'; var old = div.firstChild; div.innerHTML = '<script>1</script>x'");
    CHECK_JS(env, "old.parentNode === null && div.childNodes.length === 2 && div.firstChild.localName === 'script'");
    env.eval("div.innerHTML = null");
    CHECK_JS(env, "div.childNodes.length === 0 && div.innerHTML === ''");
    // The fragment is parsed with the element as context: rows parse as rows in a table.
    env.eval("var table = document.createElement('table'); table.innerHTML = '<tr><td>1</td></tr>'");
    CHECK_JS_EQ(env, "table.innerHTML", "<tbody><tr><td>1</td></tr></tbody>");
}

WR_TEST(testOuterHTML) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.innerHTML = '<p>a</p><p>b</p>'; div.firstChild.outerHTML = '<i>1</i><i>2</i>'");
    CHECK_JS_EQ(env, "div.innerHTML", "<i>1</i><i>2</i><p>b</p>");
    CHECK_JS(env, "(p => { p.outerHTML = '<b></b>'; return p.localName === 'p' && p.parentNode === null; })(document.createElement('p'))");
    CHECK_THROWS(env, "document.documentElement.outerHTML = ''", "NoModificationAllowedError");
    // A fragment parent parses in a <body> context.
    CHECK_JS(env, "(f => { const e = f.appendChild(document.createElement('e')); e.outerHTML = '<p>x</p>'; return f.firstChild.localName === 'p' && f.childNodes.length === 1; })(document.createDocumentFragment())");
}

WR_TEST(testInsertAdjacent) {
    DOMEnv env;
    addDiv(env);
    env.eval("div.innerHTML = '<p>m</p>'; var p = div.firstChild");
    env.eval("p.insertAdjacentHTML('beforebegin', '<a>1</a>'); p.insertAdjacentHTML('AfterBegin', '<a>2</a>'); p.insertAdjacentHTML('beforeend', '<a>3</a>'); p.insertAdjacentHTML('afterend', '<a>4</a>')");
    CHECK_JS_EQ(env, "div.innerHTML", "<a>1</a><p><a>2</a>m<a>3</a></p><a>4</a>");
    env.eval("p.insertAdjacentText('afterbegin', '<t>')");
    CHECK_JS(env, "p.firstChild.nodeType === Node.TEXT_NODE && p.firstChild.data === '<t>'");
    CHECK_JS(env, "(e => p.insertAdjacentElement('beforebegin', e) === e && e.nextSibling === p)(document.createElement('e'))");
    CHECK_JS(env, "document.createElement('x').insertAdjacentElement('afterend', document.createElement('y')) === null");
    CHECK_THROWS(env, "p.insertAdjacentHTML('middle', 'x')", "SyntaxError");
    CHECK_THROWS(env, "p.insertAdjacentElement('middle', document.createElement('z'))", "SyntaxError");
    CHECK_THROWS(env, "document.createElement('x').insertAdjacentHTML('beforebegin', 'y')", "NoModificationAllowedError");
    CHECK_THROWS(env, "document.documentElement.insertAdjacentHTML('afterend', 'y')", "NoModificationAllowedError");
    // <html> as the context parses in a <body> context.
    env.eval("document.documentElement.insertAdjacentHTML('beforeend', '<p>z</p>')");
    CHECK_JS(env, "document.documentElement.lastChild.localName === 'p'");
}

static void* serializeDeepTree(void* result) {
    DOMEnv env;
    env.eval("var deepest = document.body; for (let i = 0; i < 100000; i++) deepest = deepest.appendChild(document.createElement('div'));");
    *static_cast<std::string*>(result) = env.eval("String(document.body.innerHTML.length)");
    return nullptr;
}

// A tree 100,000 deep (built by script, so no parser cap applies) serializes on a 512 KiB stack.
WR_TEST(testDeepTreeSerializesWithoutRecursion) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    std::string length;
    CHECK(pthread_create(&thread, &attributes, serializeDeepTree, &length) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
    CHECK(length == std::to_string(100000 * 11));
}

// Not in the brief: the cases below pin what the brief's code did not do.

// HTML's fragment serialization step 1: a void element serializes nothing inside, not even children script gave it.
// A template serializes its contents and never its own children, and reading it makes no contents it does not have.
WR_TEST(testVoidElementsAndTemplateChildren) {
    DOMEnv env;
    addDiv(env);
    env.eval("var br = div.appendChild(document.createElement('br')); br.appendChild(document.createElement('i')); br.appendChild(document.createTextNode('x'))");
    CHECK_JS_EQ(env, "br.innerHTML", "");
    CHECK_JS_EQ(env, "br.outerHTML", "<br>");
    CHECK_JS_EQ(env, "div.innerHTML", "<br>");
    // Void only in the HTML namespace.
    CHECK_JS_EQ(env, "(e => { e.appendChild(document.createTextNode('x')); return e.outerHTML; })(document.createElementNS('http://www.w3.org/2000/svg', 'br'))", "<br>x</br>");
    env.eval("var bare = document.createElement('template'); bare.appendChild(document.createElement('b')); var bareMarkup = bare.innerHTML + '|' + bare.outerHTML");
    CHECK_JS_EQ(env, "bareMarkup", "|<template></template>");
    {
        JSContext* ctx = env.ctx();
        JSValue global = JS_GetGlobalObject(ctx);
        JSValue bare = JS_GetPropertyStr(ctx, global, "bare");
        wr::Node* node = wr::nodeOf(ctx, bare);
        CHECK(node && !node->hostsContents());
        JS_FreeValue(ctx, bare);
        JS_FreeValue(ctx, global);
    }
    // Text right inside the contents has a fragment for its parent: escaped, whatever the template's name.
    env.eval("bare.content.appendChild(document.createTextNode('<&>'))");
    CHECK_JS_EQ(env, "bare.outerHTML", "<template>&lt;&amp;&gt;</template>");
    CHECK_JS_EQ(env, "bare.innerHTML", "&lt;&amp;&gt;");
}

static void* serializeNestedTemplates(void* result) {
    DOMEnv env;
    env.eval("var outer = document.createElement('template'); var cur = outer; for (let i = 0; i < 20000; i++) { cur = cur.content.appendChild(document.createElement('template')); } cur.content.append('leaf')");
    *static_cast<std::string*>(result) = env.eval("String(outer.outerHTML.length) + ',' + String(outer.innerHTML.length)");
    return nullptr;
}

// Template contents are a second child list; going into them joins the same loop, so templates nested in each other's
// contents 20,000 deep serialize on a 512 KiB stack too.
WR_TEST(testNestedTemplatesSerializeWithoutRecursion) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    std::string lengths;
    CHECK(pthread_create(&thread, &attributes, serializeNestedTemplates, &lengths) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
    CHECK(lengths == std::to_string(20001 * 21 + 4) + "," + std::to_string(20000 * 21 + 4));
}

// Controller ruling: M1a has no XML parser, so parsing markup for an element of an XML document (`new Document()`) is
// a NotSupportedError where a browser would run the XML fragment parser. The getters serialize such nodes with the
// HTML serializer. The checks HTML makes before it parses keep their order.
WR_TEST(testMarkupInAnXMLDocumentIsNotSupported) {
    DOMEnv env;
    env.eval("var xd = new Document(); var xe = xd.appendChild(xd.createElement('root')); var xc = xe.appendChild(xd.createElement('c')); xc.setAttribute('a', '<&>'); xc.appendChild(xd.createTextNode('t<'))");
    CHECK_THROWS(env, "xe.innerHTML = '<p>'", "NotSupportedError");
    CHECK_THROWS(env, "xc.outerHTML = '<p>'", "NotSupportedError");
    CHECK_THROWS(env, "xc.insertAdjacentHTML('beforeend', '<p>')", "NotSupportedError");
    CHECK_THROWS(env, "xc.insertAdjacentHTML('afterend', '<p>')", "NotSupportedError");
    // A fragment parent's <body> context is made in the same XML document.
    CHECK_THROWS(env, "(f => { f.appendChild(xd.createElement('e')).outerHTML = '<p>'; })(xd.createDocumentFragment())", "NotSupportedError");
    CHECK_JS(env, "xe.childNodes.length === 1 && xe.firstChild === xc && xc.childNodes.length === 1");
    CHECK_JS(env, "(e => { e.outerHTML = '<p>'; return e.parentNode === null; })(xd.createElement('lone'))");
    CHECK_THROWS(env, "xe.outerHTML = ''", "NoModificationAllowedError");
    CHECK_THROWS(env, "xc.insertAdjacentHTML('middle', 'x')", "SyntaxError");
    CHECK_THROWS(env, "xd.createElement('lone').insertAdjacentHTML('afterend', 'x')", "NoModificationAllowedError");
    CHECK_JS_EQ(env, "xe.innerHTML", "<c a=\"&lt;&amp;&gt;\">t&lt;</c>");
    CHECK_JS_EQ(env, "xe.outerHTML", "<root><c a=\"&lt;&amp;&gt;\">t&lt;</c></root>");
    // Inserting text needs no parser.
    CHECK_JS(env, "(xc.insertAdjacentText('beforeend', '<'), xc.lastChild.data === '<')");
}

namespace {

/// The least CPU time of five runs of `code`, in milliseconds.
double timed(DOMEnv& env, const std::string& code) {
    return wr_test::leastCpuMs([&] { env.eval(code); }, 5);
}

} // namespace

// The fragment parser looks its context element's local name up among gumbo's tags (Task 18, fix round 1). Only an
// ASCII name no longer than gumbo's longest tag name can be one, so a 4 Mi-unit name is not converted to UTF-8 (12 MB on
// every innerHTML, outerHTML and insertAdjacentHTML set). The CPU times show it, by three orders of magnitude.
WR_TEST(testAFragmentContextsLongNameIsNotConverted) {
    DOMEnv env;
    env.eval("var long = document.createElement('a' + '\\u4e00'.repeat(1 << 22)), short = document.createElement('a');"
             "long.appendChild(document.createElement('i')); short.appendChild(document.createElement('i'));");
    const char* sets[] = {
        "E.innerHTML = ''",
        "E.lastChild.outerHTML = '<i></i>'",
        "E.insertAdjacentHTML('beforeend', '')",
        "E.lastChild.insertAdjacentHTML('afterend', '')",
    };
    for (const char* set : sets) {
        std::string code(set);
        std::string onLong = "long" + code.substr(1), onShort = "short" + code.substr(1);
        if (code.rfind("E.innerHTML", 0) == 0) {
            onLong += "; long.appendChild(document.createElement('i'))";
            onShort += "; short.appendChild(document.createElement('i'))";
        }
        const double l = timed(env, onLong), s = timed(env, onShort);
        const bool fast = l <= 20 * s + 1;
        if (!fast) {
            std::printf("  %s: long name %.3f ms, short %.3f ms\n", set, l, s);
        }
        CHECK(fast);
    }
    CHECK_JS(env, "long.childNodes.length === 1 && long.firstChild.localName === 'i' && short.childNodes.length === 1");
    // A real tag name is still looked up, in either case: a table context makes rows, a div context drops them.
    env.eval("function rows(e) { e.innerHTML = '<tr><td>x'; return e.firstChild.nodeName; }");
    CHECK_JS_EQ(env, "rows(document.createElement('table'))", "TBODY");
    CHECK_JS_EQ(env, "rows(document.createElementNS('http://www.w3.org/1999/xhtml', 'TABLE'))", "TBODY");
    CHECK_JS_EQ(env, "rows(document.createElement('div'))", "#text");
    CHECK_JS_EQ(env, "rows(document.createElement('table' + '\\u4e00'))", "#text");
}
