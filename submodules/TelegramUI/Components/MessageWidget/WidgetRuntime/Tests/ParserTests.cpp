#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <pthread.h>
#include <string>
#include <utility>
#include <vector>

#include "Sources/DOM/DOM.h"
#include "Sources/DOM/ParserInternal.h"
#include "Tests/DOMHarness.h"

using wr_test::DOMEnv;

static const char* kShape = "function shape(n) { const out = []; for (let c = n.firstChild; c; c = c.nextSibling) out.push(c.nodeType === 1 ? c.localName + (c.firstChild ? '(' + shape(c) + ')' : '') : c.nodeType === 3 ? '\"' + c.data + '\"' : c.nodeType === 8 ? '#' + c.data : '?'); return out.join(','); }";

static std::string repeat(const std::string& unit, size_t bytes) {
    std::string out;
    while (out.size() < bytes) {
        out += unit;
    }
    return out;
}

WR_TEST(testParsesADocument) {
    DOMEnv env("<!DOCTYPE html><html lang=en><head><title> T </title></head><body><!--c--><p class=x>a &amp; b</p><script>var s=1</script></body></html>");
    env.eval(kShape);
    CHECK_JS(env, "document.doctype.name === 'html' && document.compatMode === 'CSS1Compat'");
    CHECK_JS(env, "document.documentElement.getAttribute('lang') === 'en' && document.title === 'T'");
    CHECK_JS_EQ(env, "shape(document.body)", "#c,p(\"a & b\"),script(\"var s=1\")");
    CHECK_JS(env, "document.body.lastChild instanceof HTMLScriptElement");
}

WR_TEST(testImpliedElementsAndQuirks) {
    DOMEnv env("<p>one<p>two<table><tr><td>cell</table>");
    env.eval(kShape);
    CHECK_JS(env, "document.compatMode === 'BackCompat' && document.doctype === null");
    CHECK_JS_EQ(env, "shape(document.documentElement)", "head,body(p(\"one\"),p(\"two\",table(tbody(tr(td(\"cell\"))))))");
}

WR_TEST(testMisnestedFormattingFollowsTheAdoptionAgency) {
    DOMEnv env("<b>1<i>2<p>3</b>4");
    env.eval(kShape);
    CHECK_JS_EQ(env, "shape(document.body)", "b(\"1\",i(\"2\")),i(p(b(\"3\"),\"4\"))");
}

WR_TEST(testForeignContent) {
    DOMEnv env("<svg viewBox='0 0 1 1'><foreignObject><div>x</div></foreignObject><use xlink:href='#a'/></svg>");
    CHECK_JS(env, "(s => s.namespaceURI === 'http://www.w3.org/2000/svg' && s.getAttribute('viewBox') === '0 0 1 1')(document.body.firstChild)");
    CHECK_JS(env, "document.body.firstChild.firstChild.localName === 'foreignObject' && document.body.firstChild.firstChild.firstChild.namespaceURI === 'http://www.w3.org/1999/xhtml'");
    CHECK_JS(env, "(a => a.prefix === 'xlink' && a.localName === 'href' && a.namespaceURI === 'http://www.w3.org/1999/xlink')(document.body.firstChild.lastChild.attributes[0])");
}

// Markup with CRLF line ends and attributes on the next line names its elements as with LF (gumbo fork change 11):
// SVG case adjustment, custom element names and the foreign end-tag match all read the name from the source text. A
// raw NUL in such a name becomes U+FFFD, as the tokenizer's tag name has it.
WR_TEST(testNamesFromCRLFAndNULMarkup) {
    DOMEnv crlf("<button><svg\r\n width=16><path\r\n d='M0'/></svg>Send</button>");
    DOMEnv lf("<button><svg\n width=16><path\n d='M0'/></svg>Send</button>");
    crlf.eval(kShape);
    lf.eval(kShape);
    CHECK_JS_EQ(lf, "shape(document.body)", "button(svg(path),\"Send\")");
    CHECK_JS_EQ(crlf, "shape(document.body)", "button(svg(path),\"Send\")");
    CHECK_JS(crlf, "(s => s.namespaceURI === 'http://www.w3.org/2000/svg' && s.getAttribute('width') === '16' && s.firstChild.namespaceURI === s.namespaceURI && s.firstChild.getAttribute('d') === 'M0')(document.body.firstChild.firstChild)");
    {
        DOMEnv env("<svg><linearGradient\r\n id=g></linearGradient></svg>");
        CHECK_JS_EQ(env, "document.body.firstChild.firstChild.localName", "linearGradient");
    }
    {
        DOMEnv env("<my-el\r\n a=1></my-el>");
        CHECK_JS(env, "(e => e.localName === 'my-el' && e.getAttribute('a') === '1' && !(e instanceof HTMLUnknownElement))(document.body.firstChild)");
    }
    {
        DOMEnv env("<svg\r\n><g/></svg>after");
        CHECK_JS(env, "document.body.childNodes.length === 2 && document.body.lastChild.data === 'after' && document.body.firstChild.childNodes.length === 1");
    }
    // End tags too: a line break before an end tag's `>` does not keep a foreign element open.
    for (const char* markup : {"<svg><g></g\n>x</svg>after", "<svg><g></g\r\n>x</svg>after"}) {
        DOMEnv env(markup);
        DOMEnv reference("<svg><g></g>x</svg>after");
        env.eval(kShape);
        reference.eval(kShape);
        CHECK_JS_EQ(reference, "shape(document.body)", "svg(g,\"x\"),\"after\"");
        CHECK_JS_EQ(env, "shape(document.body)", "svg(g,\"x\"),\"after\"");
    }
    {
        const char nul[] = "<x\0y a=1>t</x\0y>";
        DOMEnv env(std::string_view(nul, sizeof(nul) - 1));
        CHECK_JS(env, "document.body.firstChild.localName === 'x\\uFFFDy' && document.body.firstChild.textContent === 't'");
    }
}

WR_TEST(testTemplateContents) {
    DOMEnv env("<template><p>inside</p></template>");
    env.eval("var t = document.head.firstChild");
    CHECK_JS(env, "t instanceof HTMLTemplateElement && t.firstChild === null");
    CHECK_JS(env, "t.content instanceof DocumentFragment && t.content.firstChild.localName === 'p'");
    CHECK_JS(env, "t.content.ownerDocument !== document && t.content.firstChild.ownerDocument === t.content.ownerDocument");
    CHECK_JS(env, "(c => c.content.firstChild.localName === 'p' && c.content !== t.content)(t.cloneNode(true))");
    CHECK_JS(env, "(c => c.content.firstChild === null)(t.cloneNode(false))");
    // A template inside a cloned subtree gets its contents too, not only a cloned template itself.
    CHECK_JS(env, "(h => h.firstChild.content.firstChild.localName === 'p' && h.firstChild.content !== t.content)(document.head.cloneNode(true))");
}

WR_TEST(testScriptFlags) {
    DOMEnv env("<script>1</script>");
    JSContext* ctx = env.ctx();
    wr::Document& document = wr::globalDocument(ctx);
    auto* head = document.documentElementNode()->firstChildNode();
    auto* script = static_cast<wr::HTMLScriptElement*>(head->firstChildNode());
    CHECK(script->parserInserted() && !script->alreadyStarted());
    wr::Ref<wr::DocumentFragment> fragment = wr::parseFragment(ctx, *document.documentElementNode(), "<script>2</script>");
    auto* inert = static_cast<wr::HTMLScriptElement*>(fragment->firstChildNode()->firstChildNode());
    CHECK(!inert->parserInserted() && inert->alreadyStarted());
}

// A script the document parse puts in template contents is not parser-inserted: HTML's "prepare the script element"
// finds it disconnected and returns, leaving it to run if the contents are inserted later. One the fragment parser
// makes is already started wherever it goes.
WR_TEST(testScriptsInTemplateContents) {
    DOMEnv env("<template><script>1</script></template><div></div>");
    JSContext* ctx = env.ctx();
    wr::Document& document = wr::globalDocument(ctx);
    auto* head = document.documentElementNode()->firstChildNode();
    auto* t = static_cast<wr::HTMLTemplateElement*>(head->firstChildNode());
    auto* script = static_cast<wr::HTMLScriptElement*>(t->content(ctx)->firstChildNode());
    CHECK(!script->parserInserted() && !script->alreadyStarted());
    auto* div = static_cast<wr::Element*>(document.documentElementNode()->lastChildNode()->firstChildNode());
    wr::Ref<wr::DocumentFragment> fragment = wr::parseFragment(ctx, *div, "<template><script>2</script></template>");
    auto* inner = static_cast<wr::HTMLTemplateElement*>(fragment->firstChildNode());
    auto* inert = static_cast<wr::HTMLScriptElement*>(inner->content(ctx)->firstChildNode());
    CHECK(!inert->parserInserted() && inert->alreadyStarted());
}

// HTML's cloning steps for script: the copy gets the element's "already started" (so a clone of an inert script stays
// inert, alone or inside a cloned parent), and never "parser-inserted".
WR_TEST(testScriptCloningKeepsAlreadyStarted) {
    DOMEnv env("<script>1</script><body><div></div>");
    JSContext* ctx = env.ctx();
    wr::Document& document = wr::globalDocument(ctx);
    auto* head = document.documentElementNode()->firstChildNode();
    auto* parsed = static_cast<wr::HTMLScriptElement*>(head->firstChildNode());
    wr::Ref<wr::Node> parsedClone = parsed->cloneNode(ctx, true);
    auto* parsedCopy = static_cast<wr::HTMLScriptElement*>(parsedClone.get());
    CHECK(parsed->parserInserted() && !parsedCopy->parserInserted() && !parsedCopy->alreadyStarted());
    auto* div = static_cast<wr::Element*>(document.documentElementNode()->lastChildNode()->firstChildNode());
    wr::Ref<wr::DocumentFragment> fragment = wr::parseFragment(ctx, *div, "<p><script>2</script></p>");
    auto* inert = static_cast<wr::HTMLScriptElement*>(fragment->firstChildNode()->firstChildNode());
    wr::Ref<wr::Node> inertClone = inert->cloneNode(ctx, true);
    auto* inertCopy = static_cast<wr::HTMLScriptElement*>(inertClone.get());
    CHECK(inertCopy->alreadyStarted() && !inertCopy->parserInserted());
    wr::Ref<wr::Node> parentClone = fragment->firstChildNode()->cloneNode(ctx, true);
    auto* nestedCopy = static_cast<wr::HTMLScriptElement*>(parentClone->firstChildNode());
    CHECK(nestedCopy->alreadyStarted() && !nestedCopy->parserInserted());
    wr::Ref<wr::Node> shallowClone = inert->cloneNode(ctx, false);
    CHECK(static_cast<wr::HTMLScriptElement*>(shallowClone.get())->alreadyStarted());
}

// HTML's "insert a character" appends to a Text node right before the insertion point. gumbo makes a node per flush of
// its text buffer, so foster-parented text before a table arrives as two; the DOM has one.
WR_TEST(testAdjacentTextIsOneNode) {
    {
        DOMEnv env("<table>A<td>B</td>C</table>");
        CHECK_JS(env, "document.body.childNodes.length === 2 && document.body.firstChild.data === 'AC' && document.body.lastChild.localName === 'table'");
    }
    {
        DOMEnv env("<p>a<b>b</b>c</p><p> x </p>");
        env.eval(kShape);
        CHECK_JS_EQ(env, "shape(document.body)", "p(\"a\",b(\"b\"),\"c\"),p(\" x \")");
    }
    {
        DOMEnv env("<div></div>");
        JSContext* ctx = env.ctx();
        auto* body = wr::globalDocument(ctx).documentElementNode()->lastChildNode();
        wr::Ref<wr::DocumentFragment> fragment = wr::parseFragment(ctx, *static_cast<wr::Element*>(body), "<table>D<td>E</td>F</table>");
        CHECK(fragment->childCount() == 2 && fragment->firstChildNode()->type() == wr::NodeType::Text &&
              static_cast<wr::Text*>(fragment->firstChildNode())->dataString(ctx).equalsASCII("DF"));
    }
}

WR_TEST(testFragmentContexts) {
    DOMEnv env("<table></table><div></div>");
    JSContext* ctx = env.ctx();
    wr::Document& document = wr::globalDocument(ctx);
    auto* body = static_cast<wr::Element*>(document.documentElementNode()->lastChildNode());
    auto* table = static_cast<wr::Element*>(body->firstChildNode());
    auto* div = static_cast<wr::Element*>(body->lastChildNode());
    wr::Ref<wr::DocumentFragment> rows = wr::parseFragment(ctx, *table, "<tr><td>x</td></tr>");
    CHECK(rows->childCount() == 1 && static_cast<wr::Element*>(rows->firstChildNode())->localName(ctx).equalsASCII("tbody"));
    wr::Ref<wr::DocumentFragment> plain = wr::parseFragment(ctx, *div, "a<b>c</b>");
    CHECK(plain->childCount() == 2 && plain->firstChildNode()->type() == wr::NodeType::Text);
}

WR_TEST(testCaps) {
    {
        DOMEnv env(repeat("<div>", 300 * 5) + "bottom");
        // html (1), body (2), then divs to the builder's 256: 254 levels below body.
        CHECK_JS(env, "(() => { let d = 0, n = document.body; while (n.firstElementChild) { n = n.firstElementChild; d++; } return d === 254; })()");
    }
    {
        std::string attributes = "<p";
        for (int i = 0; i < 300; i++) {
            attributes += " a" + std::to_string(i) + "=v";
        }
        DOMEnv env(attributes + ">");
        CHECK_JS(env, "(p => p.attributes.length === 256 && p.attributes[255].name === 'a255')(document.body.firstChild)");
    }
}

WR_TEST(testNodeLimitIsReported) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    std::string html;
    for (int i = 0; html.size() < 16 * 1024; i++) {
        html += "<div><b a=" + std::to_string(i) + "></div>";
    }
    DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::Ref<wr::Document> stopped = wr::Document::createHTML(ctx);
    CHECK(wr::parseDocumentInto(ctx, *stopped, html).stoppedAtNodeLimit);
    wr::Ref<wr::Document> whole = wr::Document::createHTML(ctx);
    CHECK(!wr::parseDocumentInto(ctx, *whole, repeat("<p>x</p>", 16 * 1024)).stoppedAtNodeLimit);
}

// gumbo fork change 12: a parse that keeps more than ParseLimits::maxTotalAttributes attributes stops, reported as
// ParseOutcome::stoppedAtAttributeLimit. Attributes are not nodes, so the node count stays tiny while the attribute
// count runs away.
WR_TEST(testAttributeLimitIsReported) {
    std::string html;
    for (int p = 0; p < 1000; p++) {
        html += "<p";
        for (int a = 0; a < 256; a++) {
            html += " a" + std::to_string(a) + "=v";
        }
        html += ">";
    }
    DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::Ref<wr::Document> stopped = wr::Document::createHTML(ctx);
    wr::ParseOutcome outcome = wr::parseDocumentInto(ctx, *stopped, html);
    CHECK(outcome.stoppedAtAttributeLimit && !outcome.stoppedAtNodeLimit);
    wr::Ref<wr::Document> whole = wr::Document::createHTML(ctx);
    CHECK(!wr::parseDocumentInto(ctx, *whole, repeat("<p a=1 b=2>x</p>", 16 * 1024)).stoppedAtAttributeLimit);
}

// gumbo fork change 13: reconstruction deep-copies a formatting element's attribute values, so one long-valued <b>
// left in the active formatting list is copied once per "<p>x</p>". The attribute count grows by one per repeat; the
// bytes by the value's length. ParseLimits::maxTotalAttributeBytes (8 MiB) stops the parse, reported through
// stoppedAtAttributeLimit, for the boot document as for a fragment.
WR_TEST(testAttributeByteLimitIsReported) {
    std::string html = "<div><b a=\"" + std::string(8 * 1024, 'v') + "\"></div>";
    for (int i = 0; i < 1200; i++) {
        html += "<p>x</p>";
    }
    DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::Ref<wr::Document> stopped = wr::Document::createHTML(ctx);
    wr::ParseOutcome outcome = wr::parseDocumentInto(ctx, *stopped, html);
    CHECK(outcome.stoppedAtAttributeLimit && !outcome.stoppedAtNodeLimit);
    wr::Ref<wr::Document> whole = wr::Document::createHTML(ctx);
    CHECK(!wr::parseDocumentInto(ctx, *whole, "<div><b a=\"" + std::string(8 * 1024, 'v') + "\"></div>" + repeat("<p>x</p>", 800)).stoppedAtAttributeLimit);
}

// Fix 1(b): script-parsed markup longer than 1,048,576 UTF-16 units throws a NotSupportedError (a documented
// divergence; browsers have no limit). It covers innerHTML, outerHTML and insertAdjacentHTML, is checked in O(1) on
// the string's length before any conversion, and the boot document (parseDocumentInto) is unaffected.
WR_TEST(testScriptMarkupLengthCap) {
    DOMEnv env;
    // Exactly at the cap parses; one unit over throws.
    env.eval("var d = document.createElement('div');");
    CHECK_THROWS(env, "d.innerHTML = 'x'.repeat((1 << 20) + 1)", "NotSupportedError");
    env.eval("d.innerHTML = 'x'.repeat(1 << 20)");
    CHECK_JS(env, "d.childNodes.length === 1 && d.firstChild.data.length === (1 << 20)");
    // The refusal is O(1): with both strings already built, refusing an over-cap string takes far less CPU time than
    // parsing an at-cap one (no utf8(), no parse).
    env.eval("var big = 'y'.repeat((1 << 20) + 1); var atCap = 'z'.repeat(1 << 20);");
    const double overCap = wr_test::leastCpuMs([&] { env.eval("(() => { try { d.innerHTML = big; } catch (e) {} })()"); });
    const double atCapCost = wr_test::leastCpuMs([&] { env.eval("d.innerHTML = atCap"); });
    if (overCap * 20 >= atCapCost) {
        std::printf("  over the cap %.3f ms, at it %.3f ms\n", overCap, atCapCost);
    }
    CHECK(overCap * 20 < atCapCost);
    // outerHTML (under a parent) and insertAdjacentHTML are covered too.
    env.eval("document.body.appendChild(d); var c = d.appendChild(document.createElement('i'));");
    CHECK_THROWS(env, "c.outerHTML = 'z'.repeat((1 << 20) + 1)", "NotSupportedError");
    CHECK_THROWS(env, "d.insertAdjacentHTML('beforeend', 'w'.repeat((1 << 20) + 1))", "NotSupportedError");
}

namespace {

/// A gumbo allocator that records the peak system heap gumbo holds at once. It prefixes each block with its size (16
/// bytes, keeping 16-alignment) so the deallocator can subtract it. It measures requested bytes, which is what the
/// bound counts; the system allocator's size classes add to both alike. This is the transient heap outside the
/// widget's memory limit: the DOM the Builder makes goes through js_malloc instead.
struct HeapCounter {
    size_t live = 0;
    size_t peak = 0;
};

constexpr size_t kHeapHeader = 16;

void* countingAlloc(void* userdata, size_t size) {
    auto* c = static_cast<HeapCounter*>(userdata);
    void* base = std::malloc(size + kHeapHeader);
    if (!base) {
        return nullptr;
    }
    *static_cast<size_t*>(base) = size;
    c->live += size;
    c->peak = std::max(c->peak, c->live);
    return static_cast<char*>(base) + kHeapHeader;
}

void countingFree(void* userdata, void* ptr) {
    if (!ptr) {
        return;
    }
    auto* c = static_cast<HeapCounter*>(userdata);
    void* base = static_cast<char*>(ptr) - kHeapHeader;
    c->live -= *static_cast<size_t*>(base);
    std::free(base);
}

struct HeapRun {
    size_t peak = 0;
    bool stoppedAtNodeLimit = false;
    bool stoppedAtAttributeLimit = false;
    /// What the tree holds when the parse stops.
    size_t nodes = 0;
    size_t attributes = 0;
    size_t attributeBytes = 0;
};

void countTree(const GumboNode* root, HeapRun& run) {
    std::vector<const GumboNode*> stack = {root};
    while (!stack.empty()) {
        const GumboNode* node = stack.back();
        stack.pop_back();
        run.nodes++;
        const GumboVector* children = nullptr;
        if (node->type == GUMBO_NODE_DOCUMENT) {
            children = &node->v.document.children;
        } else if (node->type == GUMBO_NODE_ELEMENT || node->type == GUMBO_NODE_TEMPLATE) {
            children = &node->v.element.children;
            const GumboVector& attributes = node->v.element.attributes;
            run.attributes += attributes.length;
            for (unsigned int i = 0; i < attributes.length; i++) {
                const auto* a = static_cast<const GumboAttribute*>(attributes.data[i]);
                run.attributeBytes += std::strlen(a->name) + 1 + std::strlen(a->value) + 1;
            }
        }
        if (children) {
            for (unsigned int i = 0; i < children->length; i++) {
                stack.push_back(static_cast<const GumboNode*>(children->data[i]));
            }
        }
    }
}

/// Parses `html` with `options` (the real optionsFor values) and the counting allocator: as a document, or as a
/// fragment in a <body> context, which is what parseFragment passes for a body element.
HeapRun heapParsing(const std::string& html, GumboOptions options, bool fragment) {
    HeapCounter counter;
    options.allocator = countingAlloc;
    options.deallocator = countingFree;
    options.userdata = &counter;
    if (fragment) {
        options.fragment_context = GUMBO_TAG_BODY;
        options.fragment_namespace = GUMBO_NAMESPACE_HTML;
    }
    GumboOutput* output = gumbo_parse_with_options(&options, html.data(), html.size());
    HeapRun run;
    run.stoppedAtNodeLimit = output->stopped_at_node_limit;
    run.stoppedAtAttributeLimit = output->stopped_at_attribute_limit;
    countTree(output->document, run);
    gumbo_destroy_output(&options, output);
    run.peak = counter.peak;
    return run;
}

/// `html`'s length in UTF-16 units (what the script cap counts).
size_t utf16Units(const std::string& html) {
    size_t units = 0;
    for (unsigned char c : html) {
        if ((c & 0xC0) != 0x80) {
            units += c >= 0xF0 ? 2 : 1;
        }
    }
    return units;
}

std::string repeatTimes(const std::string& unit, size_t n) {
    std::string out;
    out.reserve(unit.size() * n);
    for (size_t i = 0; i < n; i++) {
        out += unit;
    }
    return out;
}

/// The final review's reconstruction amplifier: one long-valued <b> left in the active formatting list, copied again
/// by each of `n` reconstructions.
std::string cloneAmplifier(size_t valueBytes, size_t n, const std::string& repeatUnit) {
    return "<div><b a=\"" + std::string(valueBytes, 'v') + "\"></div>" + repeatTimes(repeatUnit, n);
}

/// `count` never-closed <b>, each with `perB` distinct attributes, inside a <div>; "</div>x" pops them and the 'x'
/// reconstructs them all in one token (round 1's attribute-count overshoot).
std::string countOvershoot(int count, int perB) {
    std::string out = "<div>";
    for (int i = 0; i < count; i++) {
        out += "<b x" + std::to_string(i);
        for (int a = 0; a < perB - 1; a++) {
            out += " a" + std::to_string(a) + "=v";
        }
        out += ">";
    }
    return out + "</div>x";
}

/// `count` formatting entries of `perTag` attributes (an <a>, then <b>s) popped by "</div>", then a table with pending
/// text and an <a>: that one token's handling flushes the text (reconstructing every entry), runs the adoption agency
/// for the <a> (popping those clones) and reconstructs them again — two reconstructions in one main-loop iteration.
std::string flushOvershoot(int count, int perTag) {
    std::string attrs;
    for (int a = 0; a < perTag - 1; a++) {
        attrs += " a" + std::to_string(a);
    }
    std::string out = "<div><a z" + attrs + ">";
    for (int i = 1; i < count; i++) {
        out += "<b x" + std::to_string(i) + attrs + ">";
    }
    return out + "</div><table>x<a>";
}

} // namespace

// Fix 1(c), restated in fix round 2: the transient gumbo heap stays under transientHeapBound (Parser.cpp), which is
// derived from the limits (nodes, attributes, attribute bytes, depth, formatting list) plus per-decoded-byte terms,
// including each limit's one-token overshoot. Every shape runs with the real optionsFor(ParseLimits{}) values, as a
// document and as a <body> fragment, at or just under its cap, and its peak is checked against the bound for its own
// decoded size (3 bytes per UTF-16 unit) — and so against the stated bound at the script cap.
WR_TEST(testTransientHeapIsBounded) {
    const wr::ParseLimits limits;
    const GumboOptions options = wr::optionsFor(limits);
    const size_t scriptCapBound = wr::transientHeapBound(limits, size_t(wr::kMaxScriptMarkupUnits) * wr::kMaxDecodedBytesPerUnit);
    const size_t bootCapBound = wr::transientHeapBound(limits, size_t(256 * 1024) * 3);
    std::printf("  stated bound: %zu B at the script cap (%.1f MiB), %zu B at the boot cap (%.1f MiB); GumboNode %zu B, GumboAttribute %zu B\n",
                scriptCapBound, double(scriptCapBound) / (1 << 20), bootCapBound, double(bootCapBound) / (1 << 20), sizeof(GumboNode),
                sizeof(GumboAttribute));
    // The number Parser.cpp states (64-bit targets). A change to a limit or to the derivation must restate it.
    CHECK(scriptCapBound == 119144832);

    std::vector<std::pair<std::string, std::string>> shapes;
    // Attribute count: "<p" + 256 attributes + ">" until the count cap stops it.
    {
        std::string s;
        for (int p = 0; p < 600; p++) {
            s += "<p";
            for (int a = 0; a < 256; a++) {
                s += " a" + std::to_string(a) + "=v";
            }
            s += ">";
        }
        shapes.emplace_back("attribute-heavy", s);
    }
    // Nodes: a text node and a comment per repeat, until the node cap.
    shapes.emplace_back("node-heavy", repeatTimes("x<!---->", 131072));
    // Text: the script cap of CJK, 3 MiB of UTF-8 in one text node.
    shapes.emplace_back("text-heavy (CJK)", repeatTimes("\xe4\xb8\x80", wr::kMaxScriptMarkupUnits));
    // The final review's reconstruction amplifiers, including the 256 KB boot-sized document.
    shapes.emplace_back("clone L=64 KiB x4000 (113 KB)", cloneAmplifier(65536, 4000, "<div>x</div>"));
    shapes.emplace_back("clone L=600,000 x200 (602 KB)", cloneAmplifier(600000, 200, "<div>x</div>"));
    shapes.emplace_back("clone L=16 KiB x30000 (boot 256 KB)", cloneAmplifier(16384, 30000, "<p>x</p>"));
    // The adoption agency's amplifier: one <a> token clones a near-cap value 8 times.
    shapes.emplace_back("adoption 8x of a CJK value", "<a href=\"" + repeatTimes("\xe4\xb8\x80", wr::kMaxScriptMarkupUnits - 64) + "\">" +
                                                           repeatTimes("<div>", 8) + "<a>");
    // Formatting: 508 real nested divs, then distinct <b a=i> up to the 512-entry formatting limit, then characters
    // that reconstruct them (bounded by the node cap).
    {
        std::string s = repeatTimes("<div>", 508);
        for (int i = 0; i < 512; i++) {
            s += "<b a=" + std::to_string(i) + "></div><div>";
        }
        shapes.emplace_back("formatting-heavy", s + repeatTimes("<div>x</div>", 60000));
    }
    // Round 1's attribute-count overshoot, alone and with the node count near its cap.
    shapes.emplace_back("count overshoot", countOvershoot(508, 189));
    shapes.emplace_back("count overshoot + nodes", repeatTimes("x<!---->", 49000) + countOvershoot(508, 189));
    // A table-text flush and a reconstruction in one token: just under the attribute cap before it, about twice that
    // after; alone and with the node count near its cap.
    shapes.emplace_back("flush + <a> double reconstruction", flushOvershoot(390, 256));
    shapes.emplace_back("flush double reconstruction + nodes", repeatTimes("x<!---->", 48000) + flushOvershoot(390, 256));
    // Combined, under the script cap: nodes near their cap, attribute bytes near theirs (64 KiB copied 116 times),
    // then a count overshoot whose final token pushes counts and bytes past both.
    shapes.emplace_back("combined", repeatTimes("x<!---->", 48000) + cloneAmplifier(65536, 115, "<p>x</p>") + countOvershoot(400, 189));

    for (const auto& [name, html] : shapes) {
        size_t units = utf16Units(html);
        CHECK(units <= wr::kMaxScriptMarkupUnits);
        wr::TransientHeapTerms terms = wr::transientHeapTerms(limits, units * wr::kMaxDecodedBytesPerUnit);
        size_t bound = terms.bytes;
        for (bool fragment : {false, true}) {
            HeapRun run = heapParsing(html, options, fragment);
            std::printf("  %-36s %-8s %7zu KB in  %7.2f MB peak  bound %7.2f MB  %6zu nodes %6zu attrs %8zu attr B  stopped:%s%s\n",
                        name.c_str(), fragment ? "fragment" : "document", html.size() / 1024, double(run.peak) / 1e6, double(bound) / 1e6, run.nodes,
                        run.attributes, run.attributeBytes, run.stoppedAtNodeLimit ? " nodes" : "", run.stoppedAtAttributeLimit ? " attributes" : "");
            CHECK(run.peak <= bound && bound <= scriptCapBound);
            // Each term of the derivation holds on its own: what the tree keeps when the parse stops.
            CHECK(run.nodes <= terms.nodes && run.attributes <= terms.attributes && run.attributeBytes <= terms.attributeBytes);
        }
    }
    // The boot-sized amplifier is a 256 KB document, inside the boot parse's source cap.
    CHECK(cloneAmplifier(16384, 30000, "<p>x</p>").size() <= 256 * 1024);

    // The control: without the attribute byte cap, a modest amplifier (80 KB) breaks its bound, so the cap is what
    // holds these shapes under it.
    GumboOptions noByteCap = options;
    noByteCap.max_total_attribute_bytes = -1;
    std::string amplifier = cloneAmplifier(16384, 8000, "<p>x</p>");
    HeapRun uncapped = heapParsing(amplifier, noByteCap, false);
    std::printf("  control: no byte cap, %zu KB in, %.2f MB peak (bound %.2f MB)\n", amplifier.size() / 1024, double(uncapped.peak) / 1e6,
                double(wr::transientHeapBound(limits, utf16Units(amplifier) * wr::kMaxDecodedBytesPerUnit)) / 1e6);
    CHECK(uncapped.peak > wr::transientHeapBound(limits, utf16Units(amplifier) * wr::kMaxDecodedBytesPerUnit));
}

// Fix 3: on the parse path a lone surrogate becomes exactly one U+FFFD, not its 3-byte WTF-8 sequence (which gumbo
// would reject byte by byte, giving three U+FFFD). A valid surrogate pair stays intact. Covers text, attribute values
// and insertAdjacentHTML.
WR_TEST(testLoneSurrogatesBecomeOneReplacement) {
    DOMEnv env;
    env.eval("var d = document.body.appendChild(document.createElement('div'));");
    // A lone high surrogate in text: a, U+FFFD, b.
    env.eval("d.innerHTML = 'a\\ud800b';");
    CHECK_JS(env, "d.firstChild.data.length === 3 && d.firstChild.data.charCodeAt(0) === 0x61 && d.firstChild.data.charCodeAt(1) === 0xfffd && d.firstChild.data.charCodeAt(2) === 0x62");
    // A lone low surrogate too.
    env.eval("d.innerHTML = 'a\\udc00b';");
    CHECK_JS(env, "d.firstChild.data.length === 3 && d.firstChild.data.charCodeAt(1) === 0xfffd");
    // A valid pair (U+1F600) survives as its two units.
    env.eval("d.innerHTML = '\\ud83d\\ude00';");
    CHECK_JS(env, "d.firstChild.data === '\\ud83d\\ude00' && d.firstChild.data.length === 2");
    // An attribute value.
    env.eval("d.innerHTML = '<p t=\"a\\ud800b\"></p>';");
    CHECK_JS(env, "(v => v.length === 3 && v.charCodeAt(1) === 0xfffd)(d.firstChild.getAttribute('t'))");
    // insertAdjacentHTML.
    env.eval("var e = document.createElement('div'); e.insertAdjacentHTML('beforeend', 'x\\ud800y');");
    CHECK_JS(env, "e.firstChild.data.length === 3 && e.firstChild.data.charCodeAt(1) === 0xfffd");
}

/// Whether running `action` a second time, after a warm-up run, leaves nothing once a full GC has collected what it
/// dropped: counters, not JS_FreeRuntime's assert.
template <class F>
static bool nothingLeftAfter(DOMEnv& env, F&& action) {
    JSRuntime* rt = env.runtime().jsRuntime();
    action();
    JS_RunGC(rt);
    JSMemoryUsage before;
    JS_ComputeMemoryUsage(rt, &before);
    size_t live = env.runtime().liveObjects();
    action();
    JS_RunGC(rt);
    JSMemoryUsage after;
    JS_ComputeMemoryUsage(rt, &after);
    return after.obj_count == before.obj_count && after.malloc_count == before.malloc_count && after.malloc_size == before.malloc_size &&
           env.runtime().liveObjects() == live;
}

// A parsed document, its template contents (in a second document, the template contents owner, which the first holds
// and traces), a deep clone of them and a parsed fragment leave nothing once dropped. Those are all cycles, which the
// collector frees whatever a payload releases, but only when every reference in them is traced: a template and its
// contents (which hold each other, as contents and host) pin that. A document that is in no cycle is freed by its
// count alone, so the last case pins that it releases its template contents owner.
WR_TEST(testParsedTreesAreCollected) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    CHECK(nothingLeftAfter(env, [&] {
        wr::Ref<wr::Document> document = wr::Document::createHTML(ctx);
        wr::parseDocumentInto(ctx, *document, "<!DOCTYPE html><template><p>a<template><b c=d>b</b></template></p></template><svg><use xlink:href=#x /></svg><script>1</script>");
        auto* head = static_cast<wr::Element*>(document->documentElementNode()->firstChildNode());
        wr::Ref<wr::Node> copy = wr::cloneNodeInto(ctx, *head, *document, true);
        wr::Ref<wr::DocumentFragment> fragment = wr::parseFragment(ctx, *head, "<template><i>c</i></template>x");
    }));
    CHECK(nothingLeftAfter(env, [&] { env.eval("(() => { const t = document.createElement('template'); t.content.append('x'.repeat(2)); })()"); }));
    CHECK(nothingLeftAfter(env, [&] {
        env.eval("(() => { const d = new Document(); d.createElementNS('http://www.w3.org/1999/xhtml', 'template').content.append('y'.repeat(2)); })()");
    }));
    CHECK(nothingLeftAfter(env, [&] {
        wr::Ref<wr::Document> lone = wr::Document::createHTML(ctx);
        lone->templateContentsOwner(ctx);
    }));
}

static double secondsToParse(const std::string& html) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    double best = 1e9;
    for (int run = 0; run < 3; run++) {
        {
            wr::Ref<wr::Document> document = wr::Document::createHTML(ctx);
            auto start = std::chrono::steady_clock::now();
            wr::parseDocumentInto(ctx, *document, html);
            best = std::min(best, std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count());
        }
        // A tree is a cycle (node to document and back), freed only by the collector: run it, or three
        // 100,000-node documents meet the test runtime's 64 MB limit.
        JS_RunGC(JS_GetRuntime(ctx));
    }
    return best;
}

// Review Focus 1, at the DOM: gumbo is linear (Task 14), and building the DOM from its tree must add nothing
// worse. 4x the input in at most 8x the time, and 256 KiB in at most 10x what plain paragraphs take.
WR_TEST(testPathologicalMarkupParsesLinearly) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    const double plain = secondsToParse(repeat("<p>text</p>", 256 * 1024));
    const std::vector<std::string (*)(size_t)> classes = {
        [](size_t n) { return repeat("<div>", n); },
        [](size_t n) { return repeat("<b><i>x", n); },
        [](size_t n) { return "<table>" + repeat("<tr><td>1<td>2", n); },
        // Foster-parented text between comments the table keeps: one run of gumbo text nodes, which the builder
        // joins into one Text.
        [](size_t n) { return "<table>" + repeat("a<!---->", n); },
        [](size_t n) {
            std::string s;
            for (int i = 0; s.size() < n; i++) {
                s += "<div><b a=" + std::to_string(i) + "></div>";
            }
            return s;
        },
        [](size_t n) {
            std::string s;
            while (s.size() < n) {
                s += "<i";
                for (int a = 0; a < 256; a++) {
                    s += " a" + std::to_string(a);
                }
                s += ">x</i>";
            }
            return s;
        },
    };
    for (auto make : classes) {
        double small = secondsToParse(make(64 * 1024));
        double large = secondsToParse(make(256 * 1024));
        CHECK(large <= 8 * small + 0.01 && large <= 10 * plain + 0.01);
    }
}

static void* parseDeepMarkup(void*) {
    secondsToParse(repeat("<span>", 100000 * 6));
    return nullptr;
}

// Nothing in parsing recurses with the input: 600 KB of nested <span> on a 512 KiB stack (pool threads have 2 MB).
WR_TEST(testDeepMarkupOnASmallStack) {
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    CHECK(pthread_create(&thread, &attributes, parseDeepMarkup, nullptr) == 0);
    pthread_join(thread, nullptr);
    pthread_attr_destroy(&attributes);
}
