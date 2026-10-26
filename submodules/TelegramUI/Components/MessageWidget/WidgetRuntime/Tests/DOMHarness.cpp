#include "Tests/DOMHarness.h"

#include "Sources/DOM/DOM.h"

namespace wr_test {

static JSValue runGC(JSContext* ctx, JSValueConst, int, JSValueConst*) {
    JS_RunGC(JS_GetRuntime(ctx));
    return JS_UNDEFINED;
}

namespace {

// `doc` stays valid after installDOM took the reference: the DOM state and the global `document` hold the document
// alive.
void buildSkeleton(JSEnv& env) {
    JSContext* ctx = env.ctx();
    wr::Ref<wr::Document> document = wr::Document::createHTML(ctx);
    wr::Document* doc = document.get();
    wr::installDOM(ctx, std::move(document));
    // No Window here: the DOM-only harness gives the global a plain `document`, as M1a had.
    env.runtime().setFixedGlobal("document", JS_DupValue(ctx, doc->object()));
    wr::Atom html = wr::Atom::fromUTF8(ctx, "html");
    wr::Atom head = wr::Atom::fromUTF8(ctx, "head");
    wr::Atom body = wr::Atom::fromUTF8(ctx, "body");
    wr::Ref<wr::Element> htmlElement = wr::createElementNode(ctx, *doc, wr::Namespace::HTML, html.get(), JS_ATOM_NULL, JS_ATOM_NULL);
    wr::Ref<wr::Element> headElement = wr::createElementNode(ctx, *doc, wr::Namespace::HTML, head.get(), JS_ATOM_NULL, JS_ATOM_NULL);
    wr::Ref<wr::Element> bodyElement = wr::createElementNode(ctx, *doc, wr::Namespace::HTML, body.get(), JS_ATOM_NULL, JS_ATOM_NULL);
    doc->insertChildAt(ctx, 0, *htmlElement);
    htmlElement->insertChildAt(ctx, 0, *headElement);
    htmlElement->insertChildAt(ctx, 1, *bodyElement);
    env.runtime().setGlobal("gc", JS_NewCFunction(ctx, runGC, "gc", 0));
}

// installDOM first: the element factory reads the DOM state's interned names.
void buildParsed(JSEnv& env, std::string_view html) {
    JSContext* ctx = env.ctx();
    wr::Ref<wr::Document> document = wr::Document::createHTML(ctx);
    wr::Document* doc = document.get();
    wr::installDOM(ctx, std::move(document));
    // No Window here: the DOM-only harness gives the global a plain `document`, as M1a had.
    env.runtime().setFixedGlobal("document", JS_DupValue(ctx, doc->object()));
    wr::parseDocumentInto(ctx, *doc, html);
    env.runtime().setGlobal("gc", JS_NewCFunction(ctx, runGC, "gc", 0));
}

} // namespace

// The skeleton is built by hand: a parsed empty string has no doctype and would put every test using it in quirks mode.
DOMEnv::DOMEnv() : JSEnv(wr::idl::kTable) { buildSkeleton(*this); }
DOMEnv::DOMEnv(wr::Host& host) : JSEnv(wr::idl::kTable, &host) { buildSkeleton(*this); }
DOMEnv::DOMEnv(std::string_view html) : JSEnv(wr::idl::kTable) { buildParsed(*this, html); }
DOMEnv::DOMEnv(std::string_view html, wr::Host& host) : JSEnv(wr::idl::kTable, &host) { buildParsed(*this, html); }

} // namespace wr_test
