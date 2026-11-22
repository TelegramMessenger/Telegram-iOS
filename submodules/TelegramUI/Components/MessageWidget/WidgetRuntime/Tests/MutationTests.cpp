#include <pthread.h>

#include <algorithm>

#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"

using wr_test::DOMEnv;

// Children as a string of local names / #text data, for compact checks.
static const char* kShape = "function shape(n) { const out = []; for (let c = n.firstChild; c; c = c.nextSibling) out.push(c.nodeType === 1 ? c.localName : c.nodeType === 3 ? '\"' + c.data + '\"' : '#' + c.nodeType); return out.join(','); }";

WR_TEST(testAppendInsertRemove) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var b = document.documentElement.lastChild, x = document.createElement('x'), y = document.createElement('y'), z = document.createElement('z')");
    CHECK_JS(env, "b.appendChild(x) === x && x.parentNode === b && x.isConnected");
    CHECK_JS(env, "(b.insertBefore(y, x), shape(b) === 'y,x')");
    CHECK_JS(env, "(b.insertBefore(z, null), shape(b) === 'y,x,z')");
    CHECK_JS(env, "(b.insertBefore(x, x), shape(b) === 'y,x,z')");
    CHECK_JS(env, "(b.appendChild(y), shape(b) === 'x,z,y')");
    CHECK_JS(env, "b.removeChild(z) === z && z.parentNode === null && shape(b) === 'x,y'");
    CHECK_JS(env, "(b.replaceChild(z, x), shape(b) === 'z,y' && x.parentNode === null)");
    CHECK_THROWS(env, "y.appendChild(b)", "HierarchyRequestError");
    CHECK_THROWS(env, "b.appendChild(b)", "HierarchyRequestError");
    CHECK_THROWS(env, "b.removeChild(x)", "NotFoundError");
    CHECK_THROWS(env, "b.insertBefore(x, document.createElement('q'))", "NotFoundError");
    CHECK_THROWS(env, "document.appendChild(document.createTextNode('t'))", "HierarchyRequestError");
    CHECK_THROWS(env, "document.appendChild(document.createElement('second'))", "HierarchyRequestError");
    CHECK_THROWS(env, "document.createTextNode('t').appendChild(x)", "HierarchyRequestError");
    CHECK_THROWS(env, "b.appendChild(document)", "HierarchyRequestError");
    // The standard's order: a reference child that is not a child is reported before a node that cannot be inserted
    // (step 3 before steps 4 and 5), in both insertBefore and replaceChild.
    CHECK_THROWS(env, "b.insertBefore(document, document.createElement('q'))", "HierarchyRequestError");
    CHECK_THROWS(env, "document.insertBefore(document.createTextNode('t'), document.createElement('q'))", "NotFoundError");
    CHECK_THROWS(env, "document.replaceChild(document.createTextNode('t'), document.createElement('q'))", "NotFoundError");
    CHECK_JS(env, "shape(b) === 'z,y' && document.documentElement.lastChild === b");
}

WR_TEST(testFragmentsInsertTheirChildren) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var f = new DocumentFragment(); f.append('a', document.createElement('i'), 'b'); var p = document.createElement('p'); p.appendChild(f)");
    CHECK_JS(env, "shape(p) === '\"a\",i,\"b\"' && f.firstChild === null");
    CHECK_THROWS(env, "(() => { const g = new DocumentFragment(); g.append(document.createElement('a'), document.createElement('b')); document.replaceChild(g, document.documentElement); })()", "HierarchyRequestError");
}

// A document's element and doctype children are read from its slots (Document::documentElementNode, doctypeNode),
// not scanned: every rule of pre-insertion and replacement validity that names them, over a document with comments.
WR_TEST(testDocumentChildRules) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    // No script API makes a doctype in M1a (DOMImplementation is not in the profile).
    wr::Ref<wr::DocumentType> doctype = wr::create<wr::DocumentType>(ctx, wr::idl::kDocumentType, ctx, wr::globalDocument(ctx), wr::String::fromUTF8(ctx, "html"), wr::String(), wr::String());
    env.runtime().setGlobal("dt", doctype.release());
    env.eval("var d = new Document(), c = d.createComment('c')");
    // One at a time: append(c, dt) would gather them into a fragment, which cannot hold a doctype.
    CHECK_THROWS(env, "d.append(c, dt)", "HierarchyRequestError");
    CHECK_JS(env, "(d.append(c), d.append(dt), d.doctype === dt && d.lastChild === dt && d.documentElement === null && dt.ownerDocument === d)");
    CHECK_THROWS(env, "d.insertBefore(d.createElement('e'), c)", "HierarchyRequestError"); // a doctype follows c
    CHECK_THROWS(env, "d.insertBefore(d.createElement('e'), dt)", "HierarchyRequestError"); // before the doctype
    CHECK_THROWS(env, "d.appendChild(dt.cloneNode())", "HierarchyRequestError"); // a second doctype
    CHECK_THROWS(env, "d.appendChild(dt)", "HierarchyRequestError"); // the doctype itself counts
    CHECK_JS(env, "(e => (d.appendChild(e), d.documentElement === e))(d.createElement('e'))");
    CHECK_THROWS(env, "d.appendChild(d.createElement('f'))", "HierarchyRequestError"); // a second element
    CHECK_THROWS(env, "(g => (g.append(d.createElement('g')), d.appendChild(g)))(d.createDocumentFragment())", "HierarchyRequestError");
    // Replacing the element child, or the doctype child, is allowed: the one being replaced does not count.
    CHECK_JS(env, "(f => (d.replaceChild(f, d.documentElement), d.documentElement === f))(d.createElement('f'))");
    CHECK_JS(env, "(g => (g.append(d.createElement('g')), d.replaceChild(g, d.documentElement), d.documentElement.localName === 'g'))(d.createDocumentFragment())");
    CHECK_JS(env, "(t => (d.replaceChild(t, dt), d.doctype === t && dt.parentNode === null))(dt.cloneNode())");
    CHECK_THROWS(env, "d.replaceChild(d.createElement('h'), c)", "HierarchyRequestError"); // an element child that is not c
    CHECK_THROWS(env, "d.replaceChild(dt, c)", "HierarchyRequestError"); // a doctype child that is not c
    CHECK_JS(env, "(d.removeChild(d.doctype), d.doctype === null)");
    CHECK_THROWS(env, "d.insertBefore(dt, null)", "HierarchyRequestError"); // after the element
    CHECK_JS(env, "(d.insertBefore(dt, d.documentElement), d.doctype === dt && dt.nextSibling === d.documentElement)");
    CHECK_THROWS(env, "(d.removeChild(dt), d.append(d.createComment('z')), d.insertBefore(dt, d.lastChild))", "HierarchyRequestError"); // an element precedes z
    CHECK_THROWS(env, "d.replaceChild(dt, d.lastChild)", "HierarchyRequestError"); // an element precedes z
    CHECK_JS(env, "(d.removeChild(d.documentElement), d.insertBefore(dt, c), d.documentElement === null && d.firstChild === dt)");
    CHECK_THROWS(env, "(g => (g.append(d.createElement('g')), d.insertBefore(g, dt)))(d.createDocumentFragment())", "HierarchyRequestError");
    CHECK_JS(env, "(g => (g.append(d.createElement('g')), d.insertBefore(g, c), d.documentElement.localName === 'g' && d.documentElement.previousSibling === dt))(d.createDocumentFragment())");
}

WR_TEST(testParentNodeChildNodeAndElementSiblings) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var p = document.createElement('p'), i = document.createElement('i'), u = document.createElement('u')");
    CHECK_JS(env, "(p.append('a', i, 'b'), shape(p) === '\"a\",i,\"b\"')");
    CHECK_JS(env, "(p.prepend(u), shape(p) === 'u,\"a\",i,\"b\"')");
    CHECK_JS(env, "p.firstElementChild === u && p.lastElementChild === i && p.childElementCount === 2");
    CHECK_JS(env, "i.previousElementSibling === u && u.nextElementSibling === i && i.nextElementSibling === null");
    CHECK_JS(env, "(i.before('x', 'y'), shape(p) === 'u,\"a\",\"x\",\"y\",i,\"b\"')");
    CHECK_JS(env, "(i.after(u), shape(p) === '\"a\",\"x\",\"y\",i,u,\"b\"')");
    CHECK_JS(env, "(i.before(i, u), shape(p) === '\"a\",\"x\",\"y\",i,u,\"b\"')");
    CHECK_JS(env, "(u.replaceWith('r', u), shape(p) === '\"a\",\"x\",\"y\",i,\"r\",u,\"b\"')");
    CHECK_JS(env, "(i.remove(), i.parentNode === null && shape(p) === '\"a\",\"x\",\"y\",\"r\",u,\"b\"')");
    CHECK_JS(env, "(p.replaceChildren(i), shape(p) === 'i')");
    CHECK_JS(env, "(p.replaceChildren(), shape(p) === '')");
    CHECK_JS(env, "(document.createElement('lone').remove(), true)");
    CHECK_JS(env, "Element.prototype[Symbol.unscopables].append === true && Element.prototype[Symbol.unscopables].remove === true");
}

// The viable sibling walks of before/after/replaceWith step over the listed siblings, all of them and only them,
// whatever their number and in any order of the arguments.
WR_TEST(testViableSiblingsSkipEveryListedNode) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var p = document.createElement('p'); var k = []; for (let i = 0; i < 5; i++) k.push(document.createElement('k' + i)); var m = document.createElement('m');");
    CHECK_JS(env, "(p.append(...k, m), shape(p) === 'k0,k1,k2,k3,k4,m')");
    CHECK_JS(env, "(m.before(k[3], k[1], k[4]), shape(p) === 'k0,k2,k3,k1,k4,m')");
    CHECK_JS(env, "(m.before(k[4], 'x', k[4], k[1]), shape(p) === 'k0,k2,k3,\"x\",k4,k1,m')");
    CHECK_JS(env, "(k[0].after(k[2], k[3]), shape(p) === 'k0,k2,k3,\"x\",k4,k1,m')");
    CHECK_JS(env, "(k[0].after(k[4], k[3], k[2]), shape(p) === 'k0,k4,k3,k2,\"x\",k1,m')");
    CHECK_JS(env, "(k[0].replaceWith(k[4], k[3], k[2], k[0]), shape(p) === 'k4,k3,k2,k0,\"x\",k1,m')");
    CHECK_JS(env, "(m.after(...k, m), shape(p) === '\"x\",k0,k1,k2,k3,k4,m')");
    // Every sibling listed: the walk steps over all of them, in both directions.
    env.eval("var q = document.createElement('q'); var n = []; for (let i = 0; i < 2000; i++) n.push(document.createElement('n')); q.append(...n); var o = q.appendChild(document.createElement('o'));");
    CHECK_JS(env, "(o.before(...n), q.lastChild === o && q.firstChild === n[0] && o.previousSibling === n[1999] && q.childElementCount === 2001)");
    CHECK_JS(env, "(n[0].after(...n.slice(1)), q.lastChild === o && q.firstChild === n[0] && n[0].nextSibling === n[1] && q.childElementCount === 2001)");
    CHECK_JS(env, "(n[0].replaceWith(...n), q.lastChild === o && q.firstChild === n[0] && o.previousSibling === n[1999] && q.childElementCount === 2001)");
}

WR_TEST(testTextContentAndNodeValue) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var p = document.createElement('p'); p.append('a', document.createElement('i'), 'b'); p.firstElementChild.append('c', document.createComment('no'))");
    CHECK_JS_EQ(env, "p.textContent", "acb");
    CHECK_JS(env, "p.nodeValue === null && document.textContent === null && p.firstChild.nodeValue === 'a'");
    CHECK_JS(env, "(p.textContent = 'z', shape(p) === '\"z\"')");
    CHECK_JS(env, "(p.textContent = '', shape(p) === '')");
    CHECK_JS(env, "(p.textContent = null, shape(p) === '')");
    CHECK_JS(env, "(t => (t.nodeValue = 'q', t.data === 'q'))(new Text('w'))");
    CHECK_JS(env, "(c => (c.textContent = 'k', c.data === 'k'))(new Comment('w'))");
    CHECK_JS(env, "(f => (f.append('a', 'b'), f.textContent === 'ab'))(new DocumentFragment())");
    CHECK_JS(env, "(f => (f.append('\\u00e9', '\\ud83d\\ude00', 'z'), f.textContent === '\\u00e9\\ud83d\\ude00z'))(new DocumentFragment())");
}

WR_TEST(testNormalize) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var p = document.createElement('p'); p.append('a', '', 'b', document.createElement('i'), '', 'c', 'd'); p.firstElementChild.append('x', 'y')");
    CHECK_JS(env, "(p.normalize(), shape(p) === '\"ab\",i,\"cd\"' && shape(p.firstElementChild) === '\"xy\"')");
}

WR_TEST(testCloneAndIsEqualNode) {
    DOMEnv env;
    env.eval(kShape);
    env.eval("var p = document.createElement('p'); p.append('a', document.createElement('i'), new Comment('c')); document.documentElement.lastChild.append(p)");
    CHECK_JS(env, "(c => c !== p && c.parentNode === null && shape(c) === '' && c.localName === 'p')(p.cloneNode())");
    CHECK_JS(env, "(c => shape(c) === shape(p) && c.firstChild !== p.firstChild && c.ownerDocument === document)(p.cloneNode(true))");
    CHECK_JS(env, "p.isEqualNode(p.cloneNode(true)) && !p.isEqualNode(p.cloneNode()) && !p.isEqualNode(null)");
    CHECK_JS(env, "!new Text('a').isEqualNode(new Text('b')) && new Text('a').isEqualNode(new Text('a'))");
    CHECK_JS(env, "(t => t.cloneNode() instanceof Text && t.cloneNode().data === 'z')(new Text('z'))");
    CHECK_JS(env, "(c => c instanceof Document && c !== document && c.documentElement.localName === 'html' && c.documentElement.ownerDocument === c)(document.cloneNode(true))");
    // A difference anywhere in the subtree, not only among the children.
    CHECK_JS(env, "(c => (c.firstElementChild.append('deep'), !p.isEqualNode(c) && !c.isEqualNode(p)))(p.cloneNode(true))");
    CHECK_JS(env, "(c => (c.lastChild.data = 'd', !p.isEqualNode(c)))(p.cloneNode(true))");
    CHECK_JS(env, "p.cloneNode().isEqualNode(document.createElement('p')) && !p.cloneNode().isEqualNode(document.createElementNS('urn:x', 'p'))");
}

namespace {

void* runBody(void* body) {
    (*static_cast<void (**)()>(body))();
    return nullptr;
}

/// Runs `body` on a thread with a 512 KiB stack and waits for it. (A widget runs on a pool thread with 2 MiB, QuickJS
/// taking up to 1 MiB of it.)
void runOnSmallStack(void (*body)()) {
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setstacksize(&attributes, 512 * 1024);
    pthread_t thread;
    int status = pthread_create(&thread, &attributes, runBody, &body);
    pthread_attr_destroy(&attributes);
    CHECK_EQ(status, 0);
    if (status == 0) {
        pthread_join(thread, nullptr);
    }
}

} // namespace

// Clone and equality walk the tree without recursing: a 30,000-deep chain is copied and compared on a 512 KiB stack,
// where a native frame per level (at least 64 bytes each) would need several times that.
WR_TEST(testDeepTreesCloneAndCompare) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    runOnSmallStack([] {
        DOMEnv env;
        env.eval("var root = document.createElement('div'); var cur = root; for (let i = 0; i < 30000; i++) { cur = cur.appendChild(document.createElement('div')); } cur.append('leaf')");
        CHECK_JS(env, "(c => { let n = c, depth = 0; while (n.firstChild.nodeType === 1) { n = n.firstChild; depth++; } return depth === 30000 && n.textContent === 'leaf' && root.isEqualNode(c) && c.isEqualNode(root); })(root.cloneNode(true))");
        env.eval("gc()");
        CHECK_JS(env, "(c => { let n = c; while (n.firstChild.nodeType === 1) n = n.firstChild; n.firstChild.data = 'other'; return !root.isEqualNode(c); })(root.cloneNode(true))");
        CHECK_JS(env, "(f => (f.append(root), f.textContent === 'leaf' && f.cloneNode(true).textContent === 'leaf'))(new DocumentFragment())");
    });
}

// A template's contents are a second child list, which a deep clone copies too (HTML's cloning steps): copying them
// joins the same loop. Script nests templates as deep as it likes, so a clone that recursed per template would
// overflow the stack: 20,000 templates, each in the contents of the one before, on 512 KiB.
WR_TEST(testDeeplyNestedTemplatesClone) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    runOnSmallStack([] {
        DOMEnv env;
        env.eval("var outer = document.createElement('template'); var cur = outer; for (let i = 0; i < 20000; i++) { cur = cur.content.appendChild(document.createElement('template')); } cur.content.append('leaf')");
        CHECK_JS(env, "(c => { let n = c, depth = 0; while (n.content.firstChild.nodeType === 1) { n = n.content.firstChild; depth++; } return depth === 20000 && n.content.textContent === 'leaf' && n.content !== cur.content && n.ownerDocument === cur.ownerDocument; })(outer.cloneNode(true))");
    });
}

// A template's contents have a host, the template: "host-including inclusive ancestor" goes on from a fragment to its
// host, so neither a template nor anything holding it can go into its own contents (WPT
// html/semantics/scripting-1/the-template-element/template-element/template-content-hierarcy.html). Every other
// ancestor walk stays host-free: the contents are a tree of their own.
WR_TEST(testTemplateContentsAreHostedByTheirTemplate) {
    DOMEnv env;
    env.eval("var t = document.createElement('template'); document.body.append(t)");
    CHECK_THROWS(env, "t.content.appendChild(t)", "HierarchyRequestError");
    CHECK_JS(env, "t.content.firstChild === null && t.parentNode === document.body");
    CHECK_THROWS(env, "t.content.appendChild(document.body)", "HierarchyRequestError");
    CHECK_JS(env, "document.body !== null && document.body.lastChild === t && t.content.firstChild === null");
    env.eval("var outer = document.createElement('template'); var inner = outer.content.appendChild(document.createElement('template'))");
    CHECK_THROWS(env, "inner.content.appendChild(outer)", "HierarchyRequestError");
    CHECK_JS(env, "inner.content.firstChild === null && outer.content.firstChild === inner && outer.parentNode === null");
    env.eval("var x = t.content.appendChild(document.createElement('x'))");
    CHECK_THROWS(env, "t.content.replaceChild(t, x)", "HierarchyRequestError");
    CHECK_THROWS(env, "t.content.replaceChild(document.body, x)", "HierarchyRequestError");
    CHECK_THROWS(env, "x.appendChild(t)", "HierarchyRequestError");
    CHECK_JS(env, "t.content.firstChild === x && t.content.childNodes.length === 1 && x.firstChild === null && t.parentNode === document.body");
    CHECK_JS(env, "x.getRootNode() === t.content && !x.isConnected && !t.contains(x) && !t.content.contains(t)");
    CHECK_JS(env, "(n => t.content.appendChild(n) === n && t.content.lastChild === n)(document.createElement('template'))");
}

WR_TEST(testCompareDocumentPositionAndContains) {
    DOMEnv env;
    env.eval("var b = document.documentElement.lastChild, x = document.createElement('x'), y = document.createElement('y'), d = document.createElement('d'); b.append(x, y); x.append(d)");
    CHECK_JS(env, "x.compareDocumentPosition(x) === 0");
    CHECK_JS(env, "x.compareDocumentPosition(y) === Node.DOCUMENT_POSITION_FOLLOWING");
    CHECK_JS(env, "y.compareDocumentPosition(x) === Node.DOCUMENT_POSITION_PRECEDING");
    CHECK_JS(env, "d.compareDocumentPosition(x) === (Node.DOCUMENT_POSITION_CONTAINS | Node.DOCUMENT_POSITION_PRECEDING)");
    CHECK_JS(env, "x.compareDocumentPosition(d) === (Node.DOCUMENT_POSITION_CONTAINED_BY | Node.DOCUMENT_POSITION_FOLLOWING)");
    CHECK_JS(env, "d.compareDocumentPosition(y) === Node.DOCUMENT_POSITION_FOLLOWING && y.compareDocumentPosition(d) === Node.DOCUMENT_POSITION_PRECEDING");
    CHECK_JS(env, "(r => (r & Node.DOCUMENT_POSITION_DISCONNECTED) && (r & Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC))(x.compareDocumentPosition(document.createElement('q')))");
    CHECK_JS(env, "(q => x.compareDocumentPosition(q) === x.compareDocumentPosition(q))(document.createElement('q'))");
    CHECK_JS(env, "b.contains(d) && b.contains(b) && !d.contains(b) && !b.contains(null)");
}

// Removing every child of a node is one detach (Node::removeAllChildren), not a removal per child from the front,
// which moved and renumbered every later sibling (~n^2/2 visits: 2 x 10^8 for 20,000 children): linear in the
// children, whichever path empties the node (replace all, through textContent and replaceChildren, and a fragment
// giving up its children on insert): twice the children take about twice the CPU time (a removal per child from the
// front, four times).

namespace {

/// The least thread CPU time of three runs of emptying a node of `children` children by `how`, each in a fresh document.
double cpuToRemoveAll(int children, const char* how) {
    double least = 1e300;
    for (int run = 0; run < 3; run++) {
        DOMEnv env;
        const std::string n = std::to_string(children);
        env.eval("var p = document.createElement('p'), q = document.createElement('q'), f = new DocumentFragment();"
                 "for (let i = 0; i < " + n + "; i++) { p.appendChild(document.createElement('i')); f.appendChild(document.createElement('i')); }");
        const double start = wr_test::threadCpuMs();
        const std::string result = env.eval(std::string("(") + how + ", p.firstChild === null && f.firstChild === null)");
        least = std::min(least, wr_test::threadCpuMs() - start);
        if (result != "true" && result != "false") {
            std::printf("  %s: %s\n", how, result.c_str());
        }
    }
    return least;
}

} // namespace

WR_TEST(testRemovingAllChildrenIsLinear) {
    // Past the strict caps (widget-sandbox v0.3.0), which stop the widget: the old caps, which compat keeps.
    wr_test::ScopedLimits compat(wr::Limits::compat());
    for (const char* how : {"p.textContent = ''", "p.replaceChildren()", "q.appendChild(f)"}) {
        const double once = cpuToRemoveAll(20000, how);
        const double twice = cpuToRemoveAll(40000, how);
        if (twice > 3 * once + 1) {
            std::printf("  %s: %.3f CPU ms for 20,000 children, %.3f for 40,000\n", how, once, twice);
        }
        CHECK(twice <= 3 * once + 1);
    }
}

namespace {

/// Logs removals and insertions of Text nodes by their data.
class TextRecorder : public wr::MutationListener {
public:
    explicit TextRecorder(JSContext* ctx) : m_ctx(ctx) {}
    std::string log;
    void childrenChanged(wr::Node&) override { log += "C "; }
    void nodeInserted(wr::Node& node) override { log += "I:" + this->data(node) + " "; }
    void nodeRemoved(wr::Node& node, wr::Node& parent) override {
        log += "R:" + this->data(node) + (node.parent() == nullptr && parent.childCount() == 0 ? "" : "!") + " ";
    }

private:
    std::string data(wr::Node& node) { return node.isCharacterData() ? static_cast<wr::CharacterData&>(node).dataString(m_ctx).utf8() : "?"; }
    JSContext* m_ctx;
};

} // namespace

// The one detach still reports each removal as removing it one at a time did, in tree order. Each is reported once
// all of them are out: the listener sees the node detached and the parent empty.
WR_TEST(testRemovingAllChildrenReportsEachInTreeOrder) {
    DOMEnv env;
    wr::Document& document = wr::globalDocument(env.ctx());
    env.eval("var p = document.createElement('p'); p.append('a', 'b', 'c'); var f = new DocumentFragment(); f.append('d', 'e');");
    TextRecorder recorder(env.ctx());
    document.mutationListeners().push_back(&recorder);
    env.eval("p.textContent = 'z'");
    CHECK_EQ(recorder.log, std::string("R:a C R:b C R:c C I:z C "));
    recorder.log.clear();
    env.eval("p.replaceChildren(f)");
    // p's child first (replace all), then the fragment's (insert).
    CHECK_EQ(recorder.log, std::string("R:z C R:d C R:e C I:d I:e C "));
    document.mutationListeners().clear();
    CHECK_JS(env, "p.textContent === 'de' && f.firstChild === null && p.firstChild.parentNode === p && p.lastChild.previousSibling === p.firstChild");
    // A document's element and doctype slots follow the detach.
    CHECK_JS(env, "(d => (d.append(d.createComment('c')), d.append(d.createElement('e')), d.replaceChildren(), d.documentElement === null && d.firstChild === null && (d.append(d.createElement('n')), d.documentElement.localName === 'n')))(new Document())");
}

WR_TEST(testCharacterDataMethods) {
    DOMEnv env;
    env.eval("var t = new Text('hello')");
    CHECK_JS_EQ(env, "t.substringData(1, 3)", "ell");
    CHECK_JS_EQ(env, "t.substringData(3, 99)", "lo");
    CHECK_THROWS(env, "t.substringData(6, 1)", "IndexSizeError");
    CHECK_JS_EQ(env, "(t.appendData('!'), t.data)", "hello!");
    CHECK_JS_EQ(env, "(t.insertData(0, '>'), t.data)", ">hello!");
    CHECK_JS_EQ(env, "(t.deleteData(1, 2), t.data)", ">llo!");
    CHECK_JS_EQ(env, "(t.replaceData(1, 3, 'L'), t.data)", ">L!");
    CHECK_JS_EQ(env, "(t.replaceData(1, 99, 'Lo!'), t.data)", ">Lo!");
    CHECK_THROWS(env, "t.insertData(99, 'x')", "IndexSizeError");
    CHECK_JS_EQ(env, "(s => s.substringData(1, 2))(new Text('a\\ud83d\\ude00b'))", "\xF0\x9F\x98\x80");
    env.eval("var p = document.createElement('p'); var a = new Text('abcd'); p.append(a, 'tail')");
    CHECK_JS(env, "(n => n.data === 'cd' && a.data === 'ab' && a.nextSibling === n && n.nextSibling.data === 'tail')(a.splitText(2))");
    CHECK_JS_EQ(env, "a.wholeText", "abcdtail");
    CHECK_THROWS(env, "a.splitText(9)", "IndexSizeError");
}

WR_TEST(testImportAndAdopt) {
    DOMEnv env;
    env.eval("var other = new Document(); var e = other.createElement('E'); e.append(other.createTextNode('t'))");
    CHECK_JS(env, "(c => c.ownerDocument === document && c.firstChild.ownerDocument === document && e.ownerDocument === other)(document.importNode(e, true))");
    CHECK_JS(env, "(document.adoptNode(e), e.ownerDocument === document && e.firstChild.ownerDocument === document)");
    CHECK_JS(env, "(p => { const c = document.createElement('c'); p.append(c); document.adoptNode(c); return c.parentNode === null; })(document.createElement('p'))");
    CHECK_THROWS(env, "document.adoptNode(other)", "NotSupportedError");
    CHECK_THROWS(env, "document.importNode(other)", "NotSupportedError");
    // Inserting moves a node into the parent's document.
    CHECK_JS(env, "(n => (document.documentElement.lastChild.append(n), n.ownerDocument === document && n.firstChild.ownerDocument === document))((() => { const n = other.createElement('n'); n.append('t'); return n; })())");
}

namespace {

/// What running `code` leaves behind once a full GC has collected everything it dropped (as BindingTests.cpp's
/// leftoverAfter). `code` runs once first, so what a first use builds and keeps (interfaces, atoms, shapes) is not
/// counted. Counters, not JS_FreeRuntime's assert: they hold where NDEBUG removes it, and they see a held string.
struct Leftover {
    int64_t objects;
    int64_t allocations;
    int64_t bytes;
    int64_t platformObjects;
};

Leftover leftoverAfter(DOMEnv& env, const char* code) {
    JSRuntime* rt = env.runtime().jsRuntime();
    env.eval(code);
    JS_RunGC(rt);
    JSMemoryUsage before;
    JS_ComputeMemoryUsage(rt, &before);
    size_t live = env.runtime().liveObjects();
    env.eval(code);
    JS_RunGC(rt);
    JSMemoryUsage after;
    JS_ComputeMemoryUsage(rt, &after);
    return {after.obj_count - before.obj_count, after.malloc_count - before.malloc_count, after.malloc_size - before.malloc_size,
            int64_t(env.runtime().liveObjects()) - int64_t(live)};
}

void checkNothingLeft(const Leftover& left, const char* what) {
    if (left.objects != 0 || left.allocations != 0 || left.bytes != 0 || left.platformObjects != 0) {
        wr_test::failures()++;
        std::printf("  %s left %lld objects, %lld allocations, %lld bytes, %lld platform objects\n", what, (long long)left.objects,
                    (long long)left.allocations, (long long)left.bytes, (long long)left.platformObjects);
    }
}

} // namespace

WR_TEST(testDetachedSubtreeIsCollected) {
    DOMEnv env;
    // A chain of 100 elements, each with a text node and an expando pointing back at the root (a cycle through script
    // properties), connected, then removed and dropped. The text data is built at run time: a source literal is an
    // interned atom, which a leaked reference would keep without an allocation the counters could see.
    checkNothingLeft(leftoverAfter(env, "(() => { const root = document.createElement('div'); let cur = root; for (let i = 0; i < 100; i++) { const c = document.createElement('div'); c.back = root; cur.append(c, 'text ' + i); cur = c; } document.documentElement.lastChild.append(root); root.remove(); })()"),
                     "a removed subtree");
    // The same through the other removals: replaceChildren, textContent, replaceChild and a moved fragment.
    checkNothingLeft(leftoverAfter(env, "(() => { const b = document.documentElement.lastChild; const d = document.createElement('div'); d.append('a'.repeat(2), document.createElement('i')); b.append(d); d.replaceChildren('b'.repeat(2)); d.textContent = 'c'.repeat(2); const f = new DocumentFragment(); f.append('d'.repeat(2), d.cloneNode(true)); b.replaceChild(f, d); b.textContent = ''; })()"),
                     "replaced children");
    // A node the script still holds keeps its whole tree: its parent is still its parent.
    env.eval("(() => { const d = document.createElement('div'); d.append(document.createElement('span')); document.documentElement.lastChild.append(d); globalThis.keep = d.firstChild; d.remove(); })(); gc()");
    CHECK_JS(env, "keep.parentNode.localName === 'div' && keep.parentNode.parentNode === null");
}

WR_TEST(testExpandoSurvivesGC) {
    DOMEnv env;
    env.eval("(() => { const s = document.createElement('section'); s.state = {count: 3}; document.documentElement.lastChild.append(s); })(); gc(); gc()");
    CHECK_JS(env, "document.documentElement.lastChild.lastChild.state.count === 3");
}

WR_TEST(testNativeAlgorithmsIgnoreTamperedPrototypes) {
    DOMEnv env;
    env.eval("var b = document.documentElement.lastChild; var insertBefore = Node.prototype.insertBefore; delete Node.prototype.insertBefore; delete Node.prototype.appendChild; Node.prototype.removeChild = () => { throw new Error('no'); }");
    CHECK_JS(env, "(b.append(document.createElement('i')), b.lastChild.localName === 'i')");
    CHECK_JS(env, "(b.lastChild.remove(), b.lastChild === null)");
    CHECK_JS(env, "(Object.setPrototypeOf(b, null), insertBefore.call(b, document.createElement('u'), null).localName === 'u')");
}

namespace {

class Recorder : public wr::MutationListener {
public:
    std::string log;
    void childrenChanged(wr::Node&) override { log += "C"; }
    void nodeInserted(wr::Node&) override { log += "I"; }
    void nodeRemoved(wr::Node&, wr::Node&) override { log += "R"; }
    void characterDataChanged(wr::Node&) override { log += "D"; }
};

/// Unregisters itself and registers `next` on its first call: the walk over the listeners must survive both.
class SelfRemover : public wr::MutationListener {
public:
    SelfRemover(wr::Document& document, wr::MutationListener* next) : m_document(document), m_next(next) {}
    void childrenChanged(wr::Node&) override {
        auto& listeners = m_document.mutationListeners();
        listeners.erase(std::find(listeners.begin(), listeners.end(), this));
        for (int i = 0; i < 64; i++) {
            listeners.push_back(m_next); // grows the list past its capacity: a range-for's iterators would dangle
        }
    }

private:
    wr::Document& m_document;
    wr::MutationListener* m_next;
};

} // namespace

WR_TEST(testMutationListenersHearEveryChange) {
    DOMEnv env;
    Recorder recorder;
    wr::Document& document = wr::globalDocument(env.ctx());
    document.mutationListeners().push_back(&recorder);
    uint64_t version = document.version();
    env.eval("var b = document.documentElement.lastChild; var t = new Text('a'); b.append(t); t.data = 'b'; t.remove()");
    CHECK_EQ(recorder.log, std::string("ICDRC"));
    CHECK(document.version() > version);
    document.mutationListeners().clear();

    Recorder later;
    SelfRemover remover(document, &later);
    document.mutationListeners().push_back(&remover);
    env.eval("b.append('x')");
    CHECK(later.log.size() > 0);
    document.mutationListeners().clear();
}
