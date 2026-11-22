#include <cstdio>
#include <string>

#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"

using wr_test::DOMEnv;

WR_TEST(testChildNodes) {
    DOMEnv env;
    env.eval("var p = document.createElement('p'); var list = p.childNodes");
    CHECK_JS(env, "list === p.childNodes && list instanceof NodeList && list.length === 0");
    CHECK_JS(env, "(p.append('a', document.createElement('i')), list.length === 2 && list[1].localName === 'i' && list.item(0).data === 'a')");
    CHECK_JS(env, "list[2] === undefined && list.item(2) === null");
    CHECK_JS(env, "[...list].length === 2 && Array.from(list)[0] === p.firstChild");
    CHECK_JS(env, "(() => { let n = 0; list.forEach(() => n++); return n === 2; })()");
    CHECK_JS(env, "(p.firstChild.remove(), list.length === 1)");
    CHECK_JS(env, "Object.keys(list).join() === '0'");
}

WR_TEST(testChildrenAndGetElementsBy) {
    DOMEnv env;
    env.eval("var b = document.documentElement.lastChild; b.append(document.createElement('div'), 'x', document.createElement('span')); b.firstChild.className = 'a b'; b.lastChild.className = 'a'; b.firstChild.id = 'first'; b.lastChild.setAttribute('name', 'n')");
    CHECK_JS(env, "b.children === b.children && b.children instanceof HTMLCollection && b.children.length === 2");
    CHECK_JS(env, "b.children[0].localName === 'div' && b.children.item(1).localName === 'span' && b.children.item(2) === null");
    CHECK_JS(env, "b.children.namedItem('first') === b.firstChild && b.children.namedItem('n') === b.lastChild && b.children.namedItem('zz') === null");
    CHECK_JS(env, "document.getElementsByTagName('*').length === 5");
    CHECK_JS(env, "document.getElementsByTagName('DIV').length === 1 && b.getElementsByTagName('span').length === 1");
    CHECK_JS(env, "document.getElementsByClassName('a').length === 2 && document.getElementsByClassName('a b').length === 1 && document.getElementsByClassName('').length === 0");
    CHECK_JS(env, "document.getElementsByTagNameNS('http://www.w3.org/1999/xhtml', 'div').length === 1 && document.getElementsByTagNameNS('*', '*').length === 5");
    CHECK_JS(env, "document.getElementById('first') === b.firstChild && document.getElementById('nope') === null");
    CHECK_JS(env, "(f => (f.append(document.createElement('q')), f.firstChild.id = 'inside', f.getElementById('inside') === f.firstChild))(new DocumentFragment())");
    CHECK_JS(env, "document.getElementsByName('n').length === 1 && document.getElementsByName('n')[0] === b.lastChild");
    env.eval("var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); svg.append(document.createElementNS('http://www.w3.org/2000/svg', 'foreignObject')); b.append(svg)");
    CHECK_JS(env, "document.getElementsByTagName('foreignObject').length === 1 && document.getElementsByTagName('foreignobject').length === 0");
}

WR_TEST(testLiveCollectionsFollowMutations) {
    DOMEnv env;
    env.eval("var b = document.documentElement.lastChild; var kids = b.childNodes, els = b.children, as = document.getElementsByClassName('a'), divs = document.getElementsByTagName('div')");
    CHECK_JS(env, "kids.length === 0 && els.length === 0 && as.length === 0 && divs.length === 0");
    env.eval("var d = document.createElement('div'); b.append(d, 'text')");
    CHECK_JS(env, "kids.length === 2 && els.length === 1 && divs.length === 1 && as.length === 0");
    env.eval("d.className = 'a'");
    CHECK_JS(env, "as.length === 1 && as[0] === d");
    env.eval("d.classList.remove('a')");
    CHECK_JS(env, "as.length === 0");
    env.eval("d.remove()");
    CHECK_JS(env, "kids.length === 1 && els.length === 0 && divs.length === 0");
}

WR_TEST(testRemovingDuringIterationIsSafe) {
    DOMEnv env;
    env.eval("var p = document.createElement('p'); for (let i = 0; i < 50; i++) p.append(document.createElement('i'), 'x')");
    CHECK_JS(env, "(() => { for (const c of [...p.childNodes]) c.remove(); return p.childNodes.length === 0; })()");
    env.eval("for (let i = 0; i < 50; i++) p.append(document.createElement('i'))");
    CHECK_JS(env, "(() => { const kids = p.childNodes; while (kids.length) { kids[0].remove(); gc(); } return true; })()");
    env.eval("for (let i = 0; i < 50; i++) p.append(document.createElement('i'))");
    CHECK_JS(env, "(() => { for (const c of p.childNodes) { c.remove(); gc(); } return p.childNodes.length === 25; })()");
    env.eval("for (let i = 0; i < 20; i++) p.append(document.createElement('i'))");
    CHECK_JS(env, "(() => { const c = p.children; for (let i = c.length - 1; i >= 0; i--) { c[i].remove(); gc(); } return c.length === 0; })()");
}

// WebIDL's iteration methods: an interface that supports indexed properties (an indexed getter and an integer
// `length`) gets @@iterator, %Array.prototype.values% itself; only a declared value iterator (`iterable<T>`) adds
// entries, keys, values and forEach. HTMLCollection and NamedNodeMap declare none, NodeList and DOMTokenList do.
WR_TEST(testIndexedInterfacesAreIterable) {
    DOMEnv env;
    CHECK_JS(env, "HTMLCollection.prototype[Symbol.iterator] === Array.prototype.values && NamedNodeMap.prototype[Symbol.iterator] === Array.prototype.values");
    CHECK_JS(env, "NodeList.prototype[Symbol.iterator] === Array.prototype.values && DOMTokenList.prototype[Symbol.iterator] === Array.prototype.values");
    CHECK_JS(env, "(d => d.writable && !d.enumerable && d.configurable)(Object.getOwnPropertyDescriptor(HTMLCollection.prototype, Symbol.iterator))");
    env.eval("var b = document.documentElement.lastChild; b.append(document.createElement('div'), 'x', document.createElement('span')); b.firstChild.setAttribute('a', '1'); b.firstChild.setAttribute('b', '2')");
    CHECK_JS(env, "[...b.children].map(e => e.localName).join() === 'div,span' && Array.from(b.children)[1] === b.lastChild");
    CHECK_JS(env, "(() => { const names = []; for (const e of document.getElementsByTagName('*')) names.push(e.localName); return names.join() === 'html,head,body,div,span'; })()");
    CHECK_JS(env, "[...b.firstChild.attributes].map(a => a.name + '=' + a.value).join() === 'a=1,b=2'");
    // A live collection iterated while it changes: the iterator reads length and the index each step.
    CHECK_JS(env, "(() => { let n = 0; for (const e of b.children) { e.remove(); n++; } return n === 1 && b.children.length === 1; })()");
    // No iteration methods past @@iterator without a declared iterable (and none at all without indexed properties).
    CHECK_JS(env, "HTMLCollection.prototype.forEach === undefined && HTMLCollection.prototype.entries === undefined && HTMLCollection.prototype.keys === undefined && HTMLCollection.prototype.values === undefined");
    CHECK_JS(env, "NamedNodeMap.prototype.forEach === undefined && NamedNodeMap.prototype.values === undefined && DOMStringMap.prototype[Symbol.iterator] === undefined");
    CHECK_JS(env, "NodeList.prototype.forEach === Array.prototype.forEach && NodeList.prototype.entries === Array.prototype.entries && NodeList.prototype.keys === Array.prototype.keys && NodeList.prototype.values === Array.prototype.values");
}

// The rest goes beyond the brief: the cache's key under adoption, the version every writer bumps, the matching rules
// the brief's tests do not reach, work, and what the collections hold and release.

namespace {

/// The node in global `name`, or nullptr. Borrowed: the global holds it.
wr::Node* globalNode(DOMEnv& env, const char* name) {
    JSContext* ctx = env.ctx();
    JSValue globalObject = JS_GetGlobalObject(ctx);
    JSValue value = JS_GetPropertyStr(ctx, globalObject, name);
    wr::Node* node = wr::nodeOf(ctx, value);
    JS_FreeValue(ctx, value);
    JS_FreeValue(ctx, globalObject);
    return node;
}

wr::Document* documentOf(DOMEnv& env, const char* name) {
    wr::Node* node = globalNode(env, name);
    return node && node->type() == wr::NodeType::Document ? static_cast<wr::Document*>(node) : nullptr;
}

} // namespace

// A collection whose root went to another document, changed there and came back recomputes: the cache is keyed on the
// root's document and its version, and adopting into a document bumps that document. Without the bump the key matched
// on the way back and the cache served an element removed (and collected) meanwhile. The length is checked first:
// a stale answer then fails without reading the freed element.
WR_TEST(testCollectionsFollowTheirRootAcrossDocuments) {
    DOMEnv env;
    env.eval("var r = document.createElement('div'); r.append(document.createElement('i'), document.createElement('i')); r.firstChild.className = 'k'; r.lastChild.className = 'k';"
             "var is = r.getElementsByTagName('i'), ks = r.getElementsByClassName('k'), kids = r.children, other = new Document()");
    CHECK_JS(env, "is.length === 2 && ks.length === 2 && kids.length === 2");
    env.eval("other.adoptNode(r); r.firstChild.remove(); gc(); document.adoptNode(r); gc()");
    CHECK_JS(env, "is.length === 1 && is[0] === r.firstChild && ks.length === 1 && ks[0] === r.firstChild && kids.length === 1 && kids[0] === r.firstChild");
    // Read while away, then mutated back home: each move and each change recomputes.
    env.eval("other.adoptNode(r)");
    CHECK_JS(env, "is.length === 1 && is[0].ownerDocument === other");
    env.eval("document.adoptNode(r); r.append(document.createElement('i'))");
    CHECK_JS(env, "is.length === 2 && is[1] === r.lastChild && kids.length === 2");
}

// The cache holds the document it was computed in, so no other document can take its address while it is cached: a
// document's version counts from where it started, and every operation moves it a fixed amount, so a new document at
// the same address could be driven to the recorded number before the root moves in. The test drops the cached document,
// makes documents until one lands at its address (none can while it is held), drives the last one to the recorded
// version from C++ and moves the root into it.
WR_TEST(testACachedDocumentCannotBeImpersonated) {
    DOMEnv env;
    env.eval("var a = new Document(); var r = a.createElement('div'); r.append(a.createElement('i')); var is = r.getElementsByTagName('i'); is.length");
    wr::Document* a = documentOf(env, "a");
    CHECK(a != nullptr);
    uint64_t version = a ? a->version() : 0;
    env.eval("new Document().adoptNode(r); r.firstChild.remove(); a = null; gc()");
    bool reused = false;
    for (int i = 0; i < 1000 && !reused; i++) {
        env.eval("var c = new Document()");
        reused = documentOf(env, "c") == a;
    }
    env.eval("c.adoptNode(r)");
    wr::Document* c = documentOf(env, "c");
    while (c && c->version() < version) {
        c->noteMutation();
    }
    std::printf("  a new document at the cached one's address: %s\n", reused ? "yes" : "no");
    CHECK_JS(env, "is.length === 0 && is[0] === undefined");
}

// The three child-list writers are the only ones, and each bumps the node document's version itself: cloning and the
// harness call them directly, without the algorithms around them. So do a document's mode (class names compare
// ASCII case-insensitively in quirks mode) and adopting into a document.
WR_TEST(testEveryWriterBumpsTheVersion) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::Document& document = wr::globalDocument(ctx);
    wr::Atom name = wr::Atom::fromUTF8(ctx, "i");
    wr::Ref<wr::Element> parent = wr::createElementNode(ctx, document, wr::Namespace::HTML, name.get(), JS_ATOM_NULL, JS_ATOM_NULL);
    wr::Ref<wr::Element> child = wr::createElementNode(ctx, document, wr::Namespace::HTML, name.get(), JS_ATOM_NULL, JS_ATOM_NULL);
    uint64_t version = document.version();
    parent->insertChildAt(ctx, 0, *child);
    CHECK(document.version() > version);
    version = document.version();
    parent->removeChildAt(ctx, 0);
    CHECK(document.version() > version);
    parent->insertChildAt(ctx, 0, *child);
    version = document.version();
    parent->removeAllChildren(ctx);
    CHECK(document.version() > version);
    version = document.version();
    document.setMode(wr::DocumentMode::Quirks);
    CHECK(document.version() > version);
    version = document.version();
    document.setMode(wr::DocumentMode::Quirks);
    CHECK_EQ(document.version(), version);
    document.setMode(wr::DocumentMode::NoQuirks);
    env.eval("var other = new Document(); var moving = document.createElement('m')");
    wr::Document* other = documentOf(env, "other");
    version = other->version();
    env.eval("other.adoptNode(moving)");
    CHECK(other->version() > version);
    // Moving into the same document is no change.
    version = other->version();
    env.eval("other.adoptNode(moving)");
    CHECK_EQ(other->version(), version);
}

WR_TEST(testGetElementById) {
    DOMEnv env;
    env.eval("var b = document.documentElement.lastChild; var x = document.createElement('div'), y = document.createElement('span'), z = document.createElement('i'); x.id = y.id = z.id = 'dup'; x.append(y); b.append(x, z)");
    // The first in tree order: x before its own descendant y and before its later sibling z.
    CHECK_JS(env, "document.getElementById('dup') === x && b.firstChild.getElementById === undefined");
    CHECK_JS(env, "(x.remove(), document.getElementById('dup') === z)");
    // An element whose id is empty has no ID (DOM: "unset element's ID"), and an id in a namespace is not one.
    env.eval("var e = document.createElement('p'); e.id = ''; b.append(e); var n = document.createElement('q'); n.setAttributeNS('urn:x', 'id', 'ns'); b.append(n)");
    CHECK_JS(env, "document.getElementById('') === null && document.getElementById('ns') === null");
    // Detached elements are not in the document; the match is exact.
    CHECK_JS(env, "document.getElementById('DUP') === null && (x.id = 'away', document.getElementById('away') === null)");
}

WR_TEST(testMatchingRules) {
    DOMEnv env;
    env.eval("var b = document.documentElement.lastChild; var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); var g = document.createElementNS('http://www.w3.org/2000/svg', 's:G'); svg.append(g);"
             "var x = document.createElementNS('urn:x', 'x:Item'), y = document.createElementNS('urn:y', 'Item'), none = document.createElementNS(null, 'Item'); b.append(svg, x, y, none)");
    // getElementsByTagName: the qualified name, lowercased for HTML elements only.
    CHECK_JS(env, "document.getElementsByTagName('s:G').length === 1 && document.getElementsByTagName('s:g').length === 0 && document.getElementsByTagName('G').length === 0");
    CHECK_JS(env, "document.getElementsByTagName('x:Item')[0] === x && document.getElementsByTagName('Item').length === 2 && document.getElementsByTagName('BODY')[0] === b");
    // getElementsByTagNameNS: namespace and local name, either '*'; '' and null are no namespace.
    CHECK_JS(env, "document.getElementsByTagNameNS('urn:x', 'Item')[0] === x && document.getElementsByTagNameNS('urn:x', 'item').length === 0 && document.getElementsByTagNameNS('*', 'Item').length === 3");
    CHECK_JS(env, "document.getElementsByTagNameNS(null, 'Item')[0] === none && document.getElementsByTagNameNS('', '*')[0] === none && document.getElementsByTagNameNS('urn:y', '*')[0] === y");
    CHECK_JS(env, "document.getElementsByTagNameNS('http://www.w3.org/2000/svg', '*').length === 2 && document.getElementsByTagNameNS('urn:z', '*').length === 0");
    // getElementsByClassName: every class, in any order and repeated; ASCII whitespace separates them.
    env.eval("var c = document.createElement('div'); c.className = ' one\\ttwo\\nthree '; b.append(c)");
    CHECK_JS(env, "document.getElementsByClassName('three one').length === 1 && document.getElementsByClassName('one one').length === 1 && document.getElementsByClassName('\\fone ').length === 1");
    CHECK_JS(env, "document.getElementsByClassName('one four').length === 0 && document.getElementsByClassName('One').length === 0 && document.getElementsByClassName(' ').length === 0");
    // getElementsByName: HTML elements only; namedItem: id, or name on an HTML element; '' matches nothing.
    env.eval("svg.setAttribute('name', 'shared'); c.setAttribute('name', 'shared')");
    CHECK_JS(env, "document.getElementsByName('shared').length === 1 && document.getElementsByName('shared')[0] === c && document.getElementsByName('SHARED').length === 0");
    CHECK_JS(env, "b.children.namedItem('shared') === c && (svg.id = 'shared', b.children.namedItem('shared') === svg) && b.children.namedItem('') === null");
    // No named properties in M1a (ruling 3): a name is an ordinary property lookup.
    CHECK_JS(env, "b.children.shared === undefined && !('shared' in b.children) && Object.keys(b.children).join() === '0,1,2,3,4'");
    // A collection rooted at an element looks at its descendants only, not the element itself.
    CHECK_JS(env, "svg.getElementsByTagName('svg').length === 0 && svg.getElementsByTagName('*').length === 1");
}

WR_TEST(testClassNamesInQuirksMode) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    wr::Document& document = wr::globalDocument(ctx);
    env.eval("var b = document.documentElement.lastChild; var d = document.createElement('div'); d.className = 'Foo bar\\u212A'; b.append(d); var foo = document.getElementsByClassName('foo')");
    CHECK_JS(env, "foo.length === 0 && document.getElementsByClassName('Foo').length === 1");
    document.setMode(wr::DocumentMode::Quirks);
    // ASCII case only: U+212A KELVIN SIGN is not a K. A collection made before the switch follows it.
    CHECK_JS(env, "foo.length === 1 && document.getElementsByClassName('FOO BAR\\u212A').length === 1 && document.getElementsByClassName('bark').length === 0");
    // elementHasClasses, as the class selector (Task 17) calls it.
    auto* d = static_cast<wr::Element*>(globalNode(env, "d"));
    auto list = [&](std::initializer_list<const char*> names) {
        std::vector<wr::String> out;
        for (const char* n : names) {
            out.push_back(wr::String::fromUTF8(ctx, n));
        }
        return out;
    };
    CHECK(wr::elementHasClasses(ctx, *d, list({"foo"}), true));
    CHECK(!wr::elementHasClasses(ctx, *d, list({"foo"}), false));
    CHECK(wr::elementHasClasses(ctx, *d, list({"bar\u212A", "Foo"}), false));
    CHECK(!wr::elementHasClasses(ctx, *d, list({"Foo", "baz"}), false));
    CHECK(wr::elementHasClasses(ctx, *d, list({}), false));
    env.eval("var e = document.createElement('p')");
    auto* e = static_cast<wr::Element*>(globalNode(env, "e"));
    CHECK(!wr::elementHasClasses(ctx, *e, list({"foo"}), false));
    CHECK(wr::elementHasClasses(ctx, *e, list({}), false));
}

// getElementsByClassName's ordered set parser (orderedSetTokens) is worst-case O(n log n) and order-preserving: a
// stable merge sort of the tokens, then each later duplicate dropped. A hash set with libc++'s unseeded string hash
// was quadratic under crafted collisions.
WR_TEST(testClassOrderedSetIsSorted) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    auto joined = [&](const wr::String& s) {
        std::string out;
        for (const wr::TokenRange& t : wr::orderedSetTokens(ctx, s)) {
            out += (out.empty() ? "" : ",") + s.substring(ctx, t.start, t.end).utf8();
        }
        return out;
    };
    auto str = [&](const char* s) { return wr::String::fromUTF8(ctx, s); };
    // First occurrence order, each token once, exact code units (no case folding).
    CHECK(joined(str("b a b  c\ta a\n")) == "b,a,c");
    CHECK(joined(str("a A a")) == "a,A");
    CHECK(joined(str("")).empty() && joined(str(" \t ")).empty() && joined(str("x")) == "x");
    CHECK(joined(str("ab a abc ab b a")) == "ab,a,abc,b");

    // Many distinct classes sharing a 32-unit prefix (every comparison reads past it), each twice and in an unsorted
    // order: 200,000 tokens, 100,000 kept.
    env.eval("var names = Array.from({length: 100000}, (_, i) => 'p'.repeat(32) + ((i * 7919) % 100000)); var value = names.concat(names).join(' ');");
    JSValue global = JS_GetGlobalObject(ctx);
    wr::String value = wr::String::adopt(ctx, JS_GetPropertyStr(ctx, global, "value"));
    JS_FreeValue(ctx, global);
    wr::Vector<wr::TokenRange> kept = wr::orderedSetTokens(ctx, value);
    CHECK(kept.size() == 100000);
    CHECK_JS(env, "names[0] === 'p'.repeat(32) + '0' && names[1] === 'p'.repeat(32) + '7919'");
    CHECK(kept.size() == 100000 && value.substring(ctx, kept[1].start, kept[1].end).utf8() == std::string(32, 'p') + "7919" &&
          value.substring(ctx, kept[99999].start, kept[99999].end).utf8() == std::string(32, 'p') + std::to_string((99999u * 7919u) % 100000u));
    // The collection over them works and keeps them deduplicated.
    env.eval("var c = document.body.appendChild(document.createElement('div')); c.className = names[5] + ' ' + names[77] + ' zz'; var many = document.body.getElementsByClassName(value);");
    CHECK_JS(env, "many.length === 0 && document.body.getElementsByClassName(names[77] + ' ' + names[5] + ' ' + names[77]).length === 1");
}

namespace {

/// What running `code` leaves behind once a full GC has collected everything it dropped (as ElementTests.cpp's
/// leftoverAfter): counters, not JS_FreeRuntime's assert.
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

// A live collection holds its root (counted, traced) and the root holds its [SameObject] lists: the cycles, expandos
// through them and the collections' filters (strings and atoms made at run time: a source literal is an interned atom,
// which a leaked reference would keep without an allocation) all go when dropped. So does a cache whose document the
// root has left.
WR_TEST(testCollectionsAreCollected) {
    DOMEnv env;
    checkNothingLeft(leftoverAfter(env, "(() => { const d = document.createElement('div'); d.append(document.createElement('i'), 'x'.repeat(2)); d.firstChild.className = 'a'.repeat(2); d.firstChild.id = 'i'.repeat(2);"
                                        "d.childNodes.back = d; d.children.back = d; d.childNodes[0]; d.children[0]; d.children.namedItem('i'.repeat(2));"
                                        "const t = d.getElementsByTagName('i'.repeat(1)); t.length; t.back = d; t.self = t; d.keep = t;"
                                        "d.getElementsByClassName('a'.repeat(2) + ' ' + 'b'.repeat(2)).length; d.getElementsByTagNameNS('urn:' + 'x'.repeat(2), 'i'.repeat(2)).length;"
                                        "d.getElementsByTagNameNS('urn:' + 'y'.repeat(2), '*').length; document.getElementsByName('n'.repeat(2)).length;"
                                        "document.documentElement.lastChild.append(d); d.getElementsByTagName('*').length; d.remove(); })()"),
                     "collections over a removed element");
    checkNothingLeft(leftoverAfter(env, "(() => { const a = new Document(); const r = a.createElement('div'); r.append(a.createElement('i')); const c = r.getElementsByTagName('i'); c.length; c.r = r;"
                                        "const k = r.children; k.length; new Document().adoptNode(r); })()"),
                     "a cache over a document its root left");
    // What a script keeps keeps the tree: a collection its root, a child list its node.
    env.eval("(() => { const d = document.createElement('div'); d.append(document.createElement('i'), 't'.repeat(2)); globalThis.keepTags = d.getElementsByTagName('i'); globalThis.keepKids = d.childNodes; keepTags.length; })(); gc()");
    CHECK_JS(env, "keepTags.length === 1 && keepTags[0].parentNode.localName === 'div' && keepKids[1].data === 'tt' && keepKids[1].parentNode.childNodes === keepKids");
}

// A static list (querySelectorAll's, Task 17) holds its nodes: they outlive every other reference, and go with it.
WR_TEST(testAStaticListHoldsItsNodes) {
    DOMEnv env;
    JSContext* ctx = env.ctx();
    JSRuntime* rt = env.runtime().jsRuntime();
    wr::Document& document = wr::globalDocument(ctx);
    JS_RunGC(rt);
    size_t live = env.runtime().liveObjects();
    {
        wr::Atom name = wr::Atom::fromUTF8(ctx, "i");
        wr::Ref<wr::Element> element = wr::createElementNode(ctx, document, wr::Namespace::HTML, name.get(), JS_ATOM_NULL, JS_ATOM_NULL);
        wr::Ref<wr::Text> text = document.createTextNode(ctx, wr::String::fromUTF8(ctx, "kept"));
        wr::Ref<wr::StaticNodeList> list = wr::StaticNodeList::make(ctx, {element.get(), text.get()});
        env.runtime().setGlobal("staticList", list.release());
    }
    JS_RunGC(rt);
    CHECK_JS(env, "staticList instanceof NodeList && staticList.length === 2 && staticList[0].localName === 'i' && staticList.item(1).data === 'kept' && staticList[2] === undefined");
    CHECK_JS(env, "[...staticList].length === 2 && (document.documentElement.lastChild.append(staticList[0]), staticList.length === 2)");
    env.eval("staticList[0].remove(); staticList = null");
    JS_RunGC(rt);
    CHECK_EQ(env.runtime().liveObjects(), live);
}
