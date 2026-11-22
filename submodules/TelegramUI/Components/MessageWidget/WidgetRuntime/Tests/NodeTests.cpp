#include "Tests/DOMHarness.h"

#include "Sources/DOM/DOM.h"

using wr_test::DOMEnv;

WR_TEST(testTheDocument) {
    DOMEnv env;
    CHECK_JS(env, "document instanceof Document && document instanceof Node && document instanceof EventTarget");
    CHECK_JS(env, "document.nodeType === 9 && document.nodeName === '#document'");
    CHECK_JS(env, "document.ownerDocument === null && document.parentNode === null");
    CHECK_JS_EQ(env, "document.documentElement.tagName", "HTML");
    CHECK_JS(env, "document.documentElement.parentNode === document && document.documentElement.isConnected");
    CHECK_JS_EQ(env, "document.documentElement.firstChild.localName + ',' + document.documentElement.lastChild.localName", "head,body");
    CHECK_JS(env, "document.documentElement.firstChild.nextSibling === document.documentElement.lastChild");
    CHECK_JS(env, "document.documentElement.lastChild.previousSibling === document.documentElement.firstChild");
    CHECK_JS(env, "document.compatMode === 'CSS1Compat' && document.characterSet === 'UTF-8' && document.contentType === 'text/html'");
    CHECK_JS(env, "document.URL === 'about:srcdoc' && document.documentURI === 'about:srcdoc' && document.baseURI === 'about:srcdoc'");
    CHECK_JS(env, "document.doctype === null");
    CHECK_JS(env, "Node.ELEMENT_NODE === 1 && document.ELEMENT_NODE === 1 && Node.DOCUMENT_POSITION_CONTAINS === 8");
}

WR_TEST(testCreateElementInAnHTMLDocument) {
    DOMEnv env;
    env.eval("var d = document.createElement('DIV')");
    CHECK_JS(env, "d.localName === 'div' && d.tagName === 'DIV' && d.nodeName === 'DIV' && d.prefix === null");
    CHECK_JS(env, "d.namespaceURI === 'http://www.w3.org/1999/xhtml'");
    CHECK_JS(env, "d instanceof HTMLDivElement && d instanceof HTMLElement && d instanceof Element");
    CHECK_JS(env, "d.parentNode === null && d.ownerDocument === document && !d.isConnected && d.getRootNode() === d");
    CHECK_JS(env, "document.createElement('blink') instanceof HTMLUnknownElement");
    // HTML's "element interface": these obsolete names are HTMLUnknownElement; `menuitem` too, since HTML no longer
    // defines an interface for it. The ones after are HTMLElement.
    CHECK_JS(env, "['applet', 'bgsound', 'isindex', 'keygen', 'multicol', 'nextid', 'spacer', 'menuitem'].every(n => document.createElement(n) instanceof HTMLUnknownElement)");
    CHECK_JS(env, "['acronym', 'basefont', 'big', 'center', 'nobr', 'noembed', 'noframes', 'plaintext', 'rb', 'rtc', 'strike', 'tt'].every(n => (e => e instanceof HTMLElement && !(e instanceof HTMLUnknownElement))(document.createElement(n)))");
    CHECK_JS(env, "(e => e instanceof HTMLElement && !(e instanceof HTMLUnknownElement))(document.createElement('my-widget'))");
    CHECK_JS(env, "(e => e instanceof HTMLElement && !(e instanceof HTMLUnknownElement))(document.createElement('button'))");
    CHECK_THROWS(env, "document.createElement('')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElement('a b')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElement('a>')", "InvalidCharacterError");
}

WR_TEST(testCreateElementNS) {
    DOMEnv env;
    env.eval("var r = document.createElementNS('http://www.w3.org/2000/svg', 'svg:rect')");
    CHECK_JS(env, "r.prefix === 'svg' && r.localName === 'rect' && r.tagName === 'svg:rect' && r instanceof SVGElement");
    CHECK_JS(env, "document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject').localName === 'foreignObject'");
    CHECK_JS(env, "(e => e.namespaceURI === 'urn:x' && e.localName === 'Thing' && e instanceof Element && !(e instanceof HTMLElement))(document.createElementNS('urn:x', 'Thing'))");
    CHECK_THROWS(env, "document.createElementNS(null, 'x:y')", "NamespaceError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'xml:y')", "NamespaceError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'xmlns')", "NamespaceError");
    // "valid namespace prefix": at least one character, and no ASCII whitespace, NUL, '/' or '>'.
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'a>b:c')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'a b:c')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'a\\tb:c')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'a/b:c')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', 'a\\u0000b:c')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createElementNS('urn:x', ':c')", "InvalidCharacterError");
    CHECK_JS(env, "document.createElementNS('urn:x', '1a.\\u00e9:c').prefix === '1a.\\u00e9'");
}

// documentElement and doctype are slots the raw child edits keep: a read costs the same whatever else the document
// holds, and they follow the children being removed and inserted.
WR_TEST(testDocumentElementAndDoctypeFollowTheChildren) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::Document& doc = wr::globalDocument(ctx);
    env.eval("var html = document.documentElement;"
             "function readBoth(n) { let r = 0; for (let i = 0; i < n; i++) { r += document.documentElement === html; r += document.doctype === null; } return r; }");
    // The CPU time of 1,000 reads of each, the least of three runs after a warm-up run of the same script.
    auto cost = [&]() {
        CHECK_EQ(env.eval("readBoth(1000)"), std::string("2000"));
        return wr_test::leastCpuMs([&] { env.eval("readBoth(1000)"); });
    };
    const double bare = cost();

    // The html element goes last, after 10,000 comments: a scan for the first element child would visit them all.
    wr::Ref<wr::Element> html = wr::Ref<wr::Element>::retain(ctx, doc.documentElementNode());
    doc.removeChildAt(ctx, html->indexInParent());
    CHECK_JS(env, "document.documentElement === null && document.doctype === null");
    for (int i = 0; i < 10000; i++) {
        wr::Ref<wr::Comment> comment = doc.createComment(ctx, wr::String::fromUTF8(ctx, "c"));
        doc.insertChildAt(ctx, doc.childCount(), *comment);
    }
    CHECK_JS(env, "document.documentElement === null && document.doctype === null");
    doc.insertChildAt(ctx, doc.childCount(), *html);
    CHECK_JS(env, "document.documentElement === html && document.lastChild === html");
    const double crowded = cost();
    // About the same; a read that visited the comments would visit 2,000 x 10,000 of them.
    if (crowded > 3 * bare + 2) {
        std::printf("  CPU time of 2,000 reads: %.3f ms bare, %.3f ms among 10,000 comments\n", bare, crowded);
    }
    CHECK(crowded <= 3 * bare + 2);

    wr::Ref<wr::DocumentType> doctype = wr::create<wr::DocumentType>(ctx, wr::idl::kDocumentType, ctx, doc, wr::String::fromUTF8(ctx, "html"), wr::String(), wr::String());
    doc.insertChildAt(ctx, 0, *doctype);
    CHECK_JS(env, "document.doctype === document.firstChild && document.doctype.name === 'html' && document.documentElement === html");
    doc.removeChildAt(ctx, 1); // a comment: neither slot moves
    CHECK_JS(env, "document.doctype === document.firstChild && document.documentElement === html");
    doc.removeChildAt(ctx, doctype->indexInParent());
    CHECK_JS(env, "document.doctype === null && document.documentElement === html");
    doc.insertChildAt(ctx, 0, *doctype);
    CHECK_JS(env, "document.doctype === document.firstChild");

    doc.removeChildAt(ctx, html->indexInParent());
    CHECK_JS(env, "document.documentElement === null && document.doctype !== null");
    wr::Atom name = wr::Atom::fromUTF8(ctx, "html");
    wr::Ref<wr::Element> other = wr::createElementNode(ctx, doc, wr::Namespace::HTML, name.get(), JS_ATOM_NULL, JS_ATOM_NULL);
    doc.insertChildAt(ctx, doc.childCount(), *other);
    CHECK_JS(env, "document.documentElement !== html && document.documentElement === document.lastChild && document.documentElement.localName === 'html'");
}

WR_TEST(testAnXMLDocumentKeepsCase) {
    DOMEnv env;
    CHECK_JS(env, "(d => d.contentType === 'application/xml' && d.createElement('DIV').localName === 'DIV' && d.createElement('DIV').namespaceURI === null)(new Document())");
}

WR_TEST(testCharacterDataAndFragments) {
    DOMEnv env;
    CHECK_JS(env, "(t => t.data === 'a' && t.length === 1 && t.nodeName === '#text' && t.nodeType === 3)(document.createTextNode('a'))");
    CHECK_JS(env, "(c => c.data === 'x' && c.nodeName === '#comment' && c.nodeType === 8)(document.createComment('x'))");
    CHECK_JS(env, "new Text().data === '' && new Text('q').ownerDocument === document");
    CHECK_JS(env, "new Comment('z').data === 'z'");
    CHECK_JS(env, "(f => f.nodeType === 11 && f.nodeName === '#document-fragment')(new DocumentFragment())");
    CHECK_JS(env, "(t => (t.data = null, t.data === ''))(new Text('x'))");
    CHECK_JS(env, "new Text('\\ud83d\\ude00').length === 2");
}

WR_TEST(testNodesAreCollectedAndKeepExpandos) {
    DOMEnv env;
    env.eval("gc()");
    size_t baseline = env.runtime().liveObjects();
    env.eval("for (let i = 0; i < 1000; i++) { const d = document.createElement('div'); d.self = d; }");
    env.eval("gc()");
    CHECK(env.runtime().liveObjects() <= baseline + 1);
    env.eval("document.documentElement.lastChild.mark = 42; gc(); gc()");
    CHECK_JS(env, "document.documentElement.lastChild.mark === 42");
}
