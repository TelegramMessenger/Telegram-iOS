#include "Sources/DOM/DOM.h"
#include "Tests/DOMHarness.h"

using wr_test::DOMEnv;

WR_TEST(testAttributes) {
    DOMEnv env;
    env.eval("var e = document.createElement('div')");
    CHECK_JS(env, "!e.hasAttributes() && e.getAttribute('x') === null && !e.hasAttribute('x')");
    CHECK_JS(env, "(e.setAttribute('Data-X', '1'), e.getAttribute('data-x') === '1' && e.hasAttribute('DATA-X'))");
    CHECK_JS(env, "(e.setAttribute('data-x', '2'), e.getAttribute('data-x') === '2' && e.attributes.length === 1)");
    CHECK_JS(env, "(e.setAttribute('b', ''), e.getAttributeNames().join() === 'data-x,b')");
    CHECK_JS(env, "(e.removeAttribute('b'), e.removeAttribute('missing'), e.getAttributeNames().join() === 'data-x')");
    CHECK_JS(env, "e.toggleAttribute('t') === true && e.hasAttribute('t') && e.getAttribute('t') === ''");
    CHECK_JS(env, "e.toggleAttribute('t') === false && !e.hasAttribute('t')");
    CHECK_JS(env, "e.toggleAttribute('t', false) === false && !e.hasAttribute('t')");
    CHECK_JS(env, "e.toggleAttribute('t', true) === true && e.toggleAttribute('t', true) === true && e.hasAttribute('t')");
    CHECK_JS(env, "(e.id = 'main', e.getAttribute('id') === 'main' && e.id === 'main')");
    CHECK_JS(env, "(e.className = 'a b', e.getAttribute('class') === 'a b')");
    CHECK_JS(env, "(e.slot = 's', e.getAttribute('slot') === 's')");
    CHECK_THROWS(env, "e.setAttribute('', 'x')", "InvalidCharacterError");
    CHECK_THROWS(env, "e.setAttribute('a b', 'x')", "InvalidCharacterError");
    CHECK_THROWS(env, "e.setAttribute('a=b', 'x')", "InvalidCharacterError");
    CHECK_JS(env, "(x => (x.setAttribute('Mixed', 'v'), x.getAttribute('mixed') === null && x.getAttribute('Mixed') === 'v'))(new Document().createElement('X'))");
}

WR_TEST(testAttrNodesAndNamedNodeMap) {
    DOMEnv env;
    env.eval("var e = document.createElement('p'); e.setAttribute('title', 't')");
    CHECK_JS(env, "e.getAttributeNode('title') === e.getAttributeNode('title') && e.attributes[0] === e.getAttributeNode('title')");
    CHECK_JS(env, "(a => a instanceof Attr && a.name === 'title' && a.localName === 'title' && a.value === 't' && a.ownerElement === e && a.specified && a.namespaceURI === null && a.prefix === null)(e.attributes.item(0))");
    CHECK_JS(env, "(e.getAttributeNode('title').value = 'u', e.getAttribute('title') === 'u')");
    CHECK_JS(env, "(a => (e.removeAttributeNode(a), a.ownerElement === null && a.value === 'u' && !e.hasAttribute('title')))(e.getAttributeNode('title'))");
    CHECK_JS(env, "(a => (a.value = 'v', e.setAttributeNode(a) === null && e.getAttribute('lang') === 'v' && a.ownerElement === e))(document.createAttribute('lang'))");
    CHECK_THROWS(env, "document.createElement('q').setAttributeNode(e.getAttributeNode('lang'))", "InUseAttributeError");
    CHECK_THROWS(env, "e.removeAttributeNode(document.createAttribute('zz'))", "NotFoundError");
    CHECK_JS(env, "e.attributes.getNamedItem('lang').value === 'v' && e.attributes.getNamedItem('nope') === null");
    CHECK_JS(env, "(e.attributes.removeNamedItem('lang'), !e.hasAttribute('lang'))");
    CHECK_THROWS(env, "e.attributes.removeNamedItem('lang')", "NotFoundError");
    // NamedNodeMap's named getter binds as a method only (IDL/README.md).
    CHECK_JS(env, "(e.setAttribute('title', 't2'), e.attributes.title === undefined && e.attributes.getNamedItem('title').value === 't2')");
    CHECK_JS(env, "(a => (a.nodeValue = 'nv', a.value === 'nv' && a.textContent === 'nv'))(document.createAttribute('q'))");
    // An Attr is a node, but never a child: it cannot be inserted or take children.
    CHECK_JS(env, "(a => a.nodeType === Node.ATTRIBUTE_NODE && a.nodeName === 'q' && a.parentNode === null && !a.hasChildNodes() && a.ownerDocument === document)(document.createAttribute('q'))");
    CHECK_THROWS(env, "document.createElement('i').appendChild(document.createAttribute('q'))", "HierarchyRequestError");
    CHECK_THROWS(env, "document.createAttribute('q').appendChild(document.createTextNode('t'))", "HierarchyRequestError");
    CHECK_JS(env, "document.createAttribute('Up').localName === 'up' && new Document().createAttribute('Up').localName === 'Up'");
    // Appending or replacing an attribute moves it into the element's document (DOM "append" and "replace").
    CHECK_JS(env, "(o => (a => (e.setAttributeNode(a), a.ownerDocument === document && a.ownerElement === e))(o.createAttribute('od')))(new Document())");
    CHECK_JS(env, "(o => (a => (a.value = 'r', e.setAttributeNode(a).ownerDocument === document && a.ownerDocument === document && e.getAttribute('od') === 'r'))(o.createAttribute('od')))(new Document())");
    CHECK_THROWS(env, "document.createAttribute('a>')", "InvalidCharacterError");
}

WR_TEST(testNamespacedAttributes) {
    DOMEnv env;
    env.eval("var x = 'http://www.w3.org/1999/xlink', u = document.createElementNS('http://www.w3.org/2000/svg', 'use')");
    CHECK_JS(env, "(u.setAttributeNS(x, 'xlink:href', '#a'), u.getAttributeNS(x, 'href') === '#a' && u.getAttribute('xlink:href') === '#a')");
    CHECK_JS(env, "(a => a.prefix === 'xlink' && a.localName === 'href' && a.namespaceURI === x && a.name === 'xlink:href')(u.getAttributeNodeNS(x, 'href'))");
    CHECK_JS(env, "u.hasAttributeNS(x, 'href') && !u.hasAttributeNS(null, 'href')");
    CHECK_JS(env, "(u.removeAttributeNS(x, 'href'), !u.hasAttributeNS(x, 'href'))");
    CHECK_THROWS(env, "u.setAttributeNS(null, 'p:q', 'v')", "NamespaceError");
    // "validate and extract": the prefix is a valid namespace prefix, as createElementNS checks it.
    CHECK_THROWS(env, "u.setAttributeNS('urn:x', 'a>b:c', 'v')", "InvalidCharacterError");
    CHECK_THROWS(env, "u.setAttributeNS('urn:x', ':c', 'v')", "InvalidCharacterError");
    CHECK_THROWS(env, "u.setAttributeNS('urn:x', 'xml:c', 'v')", "NamespaceError");
    CHECK_THROWS(env, "u.setAttributeNS('urn:x', 'xmlns', 'v')", "NamespaceError");
    CHECK_THROWS(env, "u.setAttributeNS('http://www.w3.org/2000/xmlns/', 'x', 'v')", "NamespaceError");
    CHECK_JS(env, "(u.setAttributeNS('http://www.w3.org/2000/xmlns/', 'xmlns:q', 'urn:q'), u.getAttributeNS('http://www.w3.org/2000/xmlns/', 'q') === 'urn:q')");
    // Setting an existing attribute again keeps its prefix (DOM "set an attribute value").
    CHECK_JS(env, "(u.setAttributeNS('urn:x', 'p:k', '1'), u.setAttributeNS('urn:x', 'r:k', '2'), u.getAttribute('p:k') === '2' && u.getAttributeNodeNS('urn:x', 'k').prefix === 'p')");
    // createAttributeNS validates as setAttributeNS does.
    CHECK_JS(env, "(a => a.prefix === 'xlink' && a.localName === 'href' && a.namespaceURI === x && a.ownerElement === null && a.value === '')(document.createAttributeNS(x, 'xlink:href'))");
    CHECK_THROWS(env, "document.createAttributeNS(null, 'p:q')", "NamespaceError");
    CHECK_THROWS(env, "document.createAttributeNS('urn:x', 'a>b:c')", "InvalidCharacterError");
    CHECK_THROWS(env, "document.createAttributeNS('urn:x', 'a=b')", "InvalidCharacterError");
}

// "Replace an attribute" swaps the whole attribute: the entry takes the new Attr's prefix.
WR_TEST(testReplacingAnAttrTakesItsPrefix) {
    DOMEnv env;
    env.eval("var u = document.createElementNS('http://www.w3.org/2000/svg', 'use'); u.setAttributeNS('urn:x', 'a:k', '1'); var old = u.getAttributeNode('a:k'); var n = document.createAttributeNS('urn:x', 'b:k'); n.value = '2'");
    CHECK_JS(env, "u.setAttributeNode(n) === old && old.ownerElement === null && old.value === '1' && old.prefix === 'a'");
    CHECK_JS(env, "u.getAttribute('b:k') === '2' && u.getAttribute('a:k') === null && u.attributes[0] === n && u.attributes.length === 1 && n.ownerElement === u");
    CHECK_JS(env, "u.setAttributeNode(n) === n && u.attributes.length === 1");
    CHECK_JS(env, "u.setAttributeNodeNS(old) === n && u.getAttribute('a:k') === '1' && n.ownerElement === null && n.value === '2'");
}

WR_TEST(testClassList) {
    DOMEnv env;
    env.eval("var e = document.createElement('div'); var c = e.classList");
    CHECK_JS(env, "c === e.classList && c instanceof DOMTokenList && c.length === 0 && c.value === ''");
    CHECK_JS(env, "(c.add('a', 'b', 'a'), e.className === 'a b' && c.length === 2 && c[1] === 'b' && c.item(2) === null)");
    CHECK_JS(env, "c.contains('a') && !c.contains('z')");
    CHECK_JS(env, "(c.remove('a'), e.className === 'b')");
    CHECK_JS(env, "c.toggle('x') === true && c.toggle('x') === false && c.toggle('y', true) === true && c.toggle('y', true) === true");
    CHECK_JS(env, "c.replace('y', 'z') === true && c.replace('nope', 'q') === false && e.className === 'b z'");
    CHECK_JS(env, "(e.className = '  p   q p ', c.length === 2 && [...c].join() === 'p,q' && c.value === '  p   q p ')");
    CHECK_JS(env, "(e.classList = 'one two', e.className === 'one two')");
    CHECK_JS(env, "String(c) === 'one two' && Object.keys(c).join() === '0,1'");
    CHECK_THROWS(env, "c.add('')", "SyntaxError");
    CHECK_THROWS(env, "c.add('a b')", "InvalidCharacterError");
    CHECK_THROWS(env, "c.supports('x')", "TypeError");
    CHECK_JS(env, "(f => (f.classList.remove('nothing'), !f.hasAttribute('class')))(document.createElement('i'))");
    // With the attribute present, an emptied set is written as "" (DOM "update steps").
    CHECK_JS(env, "(f => (f.className = 'a', f.classList.remove('a'), f.hasAttribute('class') && f.getAttribute('class') === '' && f.classList.length === 0))(document.createElement('i'))");
}

// DOMTokenList's replace is the ordered set's: the first instance of either token becomes the new one and every other
// instance goes. Both tokens are checked for emptiness before either is checked for whitespace.
WR_TEST(testTokenListReplaceFollowsTheOrderedSet) {
    DOMEnv env;
    env.eval("var e = document.createElement('div'); var c = e.classList");
    CHECK_JS(env, "(e.className = 'a b c', c.replace('a', 'c') && e.className === 'c b')");
    CHECK_JS(env, "(e.className = 'a b c', c.replace('c', 'a') && e.className === 'a b')");
    CHECK_JS(env, "(e.className = 'a b c', c.replace('b', 'd') && e.className === 'a d c')");
    CHECK_THROWS(env, "c.replace('a b', '')", "SyntaxError");
    CHECK_THROWS(env, "c.replace('a', 'b c')", "InvalidCharacterError");
    // The list's own writes and the attribute's agree whichever way the value changed.
    CHECK_JS(env, "(c.add('n'), e.setAttribute('class', 'x y'), c.length === 2 && c[0] === 'x' && (c.add('z'), e.className === 'x y z') && c[2] === 'z')");
    CHECK_JS(env, "(e.removeAttribute('class'), c.length === 0 && c.value === '' && (c.toggle('w'), e.className === 'w'))");
}

WR_TEST(testDataset) {
    DOMEnv env;
    env.eval("var e = document.createElement('div'); var d = e.dataset");
    CHECK_JS(env, "d === e.dataset && d instanceof DOMStringMap");
    CHECK_JS(env, "(d.fooBar = 'x', e.getAttribute('data-foo-bar') === 'x' && d.fooBar === 'x')");
    CHECK_JS(env, "(e.setAttribute('data-a-b-c', '1'), d.aBC === '1' && 'aBC' in d)");
    CHECK_JS(env, "Object.keys(d).join() === 'fooBar,aBC'");
    CHECK_JS(env, "(delete d.fooBar, !e.hasAttribute('data-foo-bar') && d.fooBar === undefined)");
    CHECK_JS(env, "(d.n = 5, d.n === '5')");
    CHECK_THROWS(env, "d['a-b'] = 'x'", "SyntaxError");
    // An attribute whose name has an ASCII upper alpha after "data-" has no dataset name. setAttribute would lowercase
    // the name in an HTML document; setAttributeNS keeps it.
    CHECK_JS(env, "(e.setAttributeNS(null, 'data-Upper', 'u'), !('upper' in d) && !('Upper' in d) && e.getAttribute('data-Upper') === null)");
    CHECK_JS(env, "(e.setAttribute('data-Upper', 'l'), d.upper === 'l')");
}

// The name-value pairs come from the attributes' qualified names (HTML), and only a supported name is deleted.
WR_TEST(testDatasetNamesAreQualifiedNames) {
    DOMEnv env;
    env.eval("var e = document.createElement('div'); var d = e.dataset");
    CHECK_JS(env, "(e.setAttributeNS('urn:x', 'data-ns', 'n'), d.ns === 'n' && Object.keys(d).join() === 'ns')");
    CHECK_JS(env, "(delete d.ns, !e.hasAttributeNS('urn:x', 'data-ns') && !e.hasAttribute('data-ns') && !e.hasAttributes())");
    CHECK_JS(env, "(e.setAttribute('data-a-b', '1'), d['a-b'] === undefined && !('a-b' in d) && d.aB === '1')");
    CHECK_JS(env, "(delete d['a-b'], e.getAttribute('data-a-b') === '1')");
    CHECK_JS(env, "(e.setAttribute('data-', 'empty'), d[''] === 'empty' && Object.keys(d).join() === 'aB,')");
    CHECK_JS(env, "(e.setAttribute('data-x-', 't'), d['x-'] === 't')");
    CHECK_JS(env, "(d.toString = 'z', e.getAttribute('data-to-string') === 'z' && d.toString === 'z')");
    CHECK_JS(env, "(delete d.toString, typeof d.toString === 'function')");
    CHECK_JS(env, "Object.getOwnPropertyDescriptor(d, 'aB').value === '1' && Object.getOwnPropertyDescriptor(d, 'nope') === undefined");
    CHECK_THROWS(env, "Object.defineProperty(d, 'g', {get() { return 1; }})", "TypeError");
    CHECK_JS(env, "(Object.defineProperty(d, 'v', {value: 'dv'}), e.getAttribute('data-v') === 'dv')");
    CHECK_JS(env, "Reflect.defineProperty(d, 'g', {get() { return 1; }}) === false && !e.hasAttribute('data-g')");
    // Through an object that inherits from the map: reads see the named properties, writes make the receiver's own.
    CHECK_JS(env, "(o => o.aB === '1' && (o.k = 'v', o.hasOwnProperty('k') && !e.hasAttribute('data-k') && d.k === undefined))(Object.create(d))");
    CHECK_JS(env, "(Reflect.set(d, 'r', 'x', {}), !e.hasAttribute('data-r'))");
    CHECK_JS(env, "d[Symbol.iterator] === undefined && String(d) === '[object DOMStringMap]'");
}

WR_TEST(testReflection) {
    DOMEnv env;
    env.eval("var e = document.createElement('div')");
    CHECK_JS(env, "e.title === '' && (e.title = 'T', e.getAttribute('title') === 'T')");
    CHECK_JS(env, "(e.lang = 'en', e.getAttribute('lang') === 'en')");
    CHECK_JS(env, "!e.hidden && (e.hidden = true, e.getAttribute('hidden') === '') && (e.hidden = false, !e.hasAttribute('hidden'))");
    CHECK_JS(env, "(e.accessKey = 'k', e.getAttribute('accesskey') === 'k')");
    CHECK_JS(env, "(e.inert = true, e.hasAttribute('inert'))");
    CHECK_JS(env, "(a => (a.target = '_blank', a.href = '#x', a.getAttribute('target') === '_blank' && a.href === '#x' && String(a) === '#x'))(document.createElement('a'))");
    CHECK_JS(env, "(a => (a.download = 'f', a.rel = 'r', a.hreflang = 'h', a.type = 't', ['download', 'rel', 'hreflang', 'type'].map(n => a.getAttribute(n)).join() === 'f,r,h,t'))(document.createElement('a'))");
    CHECK_JS(env, "(s => (s.src = 'lib.js', s.defer = true, s.noModule = true, s.getAttribute('src') === 'lib.js' && s.hasAttribute('defer') && s.hasAttribute('nomodule')))(document.createElement('script'))");
    CHECK_JS(env, "(s => (s.media = 'print', s.getAttribute('media') === 'print'))(document.createElement('style'))");
    CHECK_JS(env, "(s => (s.autofocus = true, s.hasAttribute('autofocus')))(document.createElementNS('http://www.w3.org/2000/svg', 'rect'))");
    CHECK_JS(env, "document.createElementNS('http://www.w3.org/2000/svg', 'rect').dataset instanceof DOMStringMap");
    // A boolean reflects presence: any value is true, and setting true keeps no old value.
    CHECK_JS(env, "(e.setAttribute('hidden', 'no'), e.hidden === true && (e.hidden = true, e.getAttribute('hidden') === ''))");
}

WR_TEST(testDocumentTitleBodyHead) {
    DOMEnv env;
    CHECK_JS(env, "document.head === document.documentElement.firstChild && document.body === document.documentElement.lastChild");
    CHECK_JS(env, "document.title === ''");
    CHECK_JS(env, "(document.title = '  Hello \\n  world  ', document.head.lastChild.localName === 'title' && document.title === 'Hello world')");
    CHECK_JS(env, "(document.title = 'Again', document.title === 'Again' && document.head.lastChild.localName === 'title' && document.head.lastChild.previousSibling === null)");
    CHECK_JS(env, "(b => (document.body = b, document.body === b && document.documentElement.lastChild === b))(document.createElement('body'))");
    CHECK_THROWS(env, "document.body = document.createElement('div')", "HierarchyRequestError");
    CHECK_THROWS(env, "document.body = null", "HierarchyRequestError");
    // The title element is the first in tree order, wherever it is; its text is its Text children's only.
    CHECK_JS(env, "(t => (t.append('in ', document.createElement('b'), 'body'), t.firstChild.nextSibling.append('no'), document.body.prepend(t), document.title === 'Again'))(document.createElement('title'))");
    CHECK_JS(env, "(document.head.firstChild.remove(), document.title === 'in body')");
    // A frameset is a body too.
    CHECK_JS(env, "(f => (document.body = f, document.body === f && document.body.localName === 'frameset'))(document.createElement('frameset'))");
    // Without an html document element there is no head, no body, and setting the title does nothing.
    CHECK_JS(env, "(d => d.head === null && d.body === null && d.title === '' && (d.title = 'x', d.title === '' && d.firstChild === null))(new Document())");
    CHECK_THROWS(env, "new Document().body = document.createElement('body')", "HierarchyRequestError");
}

WR_TEST(testHostileAttributeValues) {
    DOMEnv env;
    env.eval("var e = document.createElement('div')");
    CHECK_JS(env, "(e.setAttribute('v', 'a\\ud800b\\u0000c'), e.getAttribute('v') === 'a\\ud800b\\u0000c' && e.getAttribute('v').length === 5)");
    CHECK_JS(env, "(e.setAttribute('big', 'x'.repeat(4 * 1024 * 1024)), e.getAttribute('big').length === 4 * 1024 * 1024)");
    CHECK_JS(env, "(e.removeAttribute('big'), !e.hasAttribute('big'))");
    CHECK_THROWS(env, "e.setAttribute('a>b', '')", "InvalidCharacterError");
    CHECK_THROWS(env, "e.setAttribute('a/b', '')", "InvalidCharacterError");
    CHECK_THROWS(env, "e.setAttribute('a\\u0000b', '')", "InvalidCharacterError");
    // Names may hold lone surrogates and digits (atoms of any string).
    CHECK_JS(env, "(e.setAttribute('\\udc00', 's'), e.getAttribute('\\udc00') === 's' && e.getAttributeNames().includes('\\udc00'))");
    CHECK_JS(env, "(e.setAttribute('123', 'n'), e.getAttribute('123') === 'n' && e.attributes.getNamedItem('123').name === '123')");
    // Through Attr, classList and dataset too.
    CHECK_JS(env, "(a => (a.value = 'q\\ud800'.repeat(1024 * 1024), e.setAttributeNode(a), e.getAttribute('w').length === 2 * 1024 * 1024))(document.createAttribute('w'))");
    CHECK_JS(env, "(e.classList.add('\\ud800', '\\u0000'), e.classList.length === 2 && e.className === '\\ud800 \\u0000')");
    CHECK_JS(env, "(e.dataset.s = '\\ud800\\u0000', e.getAttribute('data-s') === '\\ud800\\u0000')");
    CHECK_JS(env, "(e.className = 'y '.repeat(512 * 1024), e.classList.length === 1 && e.classList[0] === 'y')");
}

WR_TEST(testAttributesInPositionsCloningAndAdoption) {
    DOMEnv env;
    env.eval("var e = document.createElement('p'); e.setAttribute('a', '1'); e.setAttribute('b', '2'); var a = e.getAttributeNode('a'), b = e.getAttributeNode('b')");
    CHECK_JS(env, "a.compareDocumentPosition(b) === (Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC | Node.DOCUMENT_POSITION_FOLLOWING)");
    CHECK_JS(env, "b.compareDocumentPosition(a) === (Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC | Node.DOCUMENT_POSITION_PRECEDING)");
    CHECK_JS(env, "e.compareDocumentPosition(a) === (Node.DOCUMENT_POSITION_CONTAINED_BY | Node.DOCUMENT_POSITION_FOLLOWING)");
    CHECK_JS(env, "a.compareDocumentPosition(e) === (Node.DOCUMENT_POSITION_CONTAINS | Node.DOCUMENT_POSITION_PRECEDING)");
    CHECK_JS(env, "(c => c.getAttribute('a') === '1' && c.getAttribute('b') === '2' && c.getAttributeNode('a') !== a)(e.cloneNode())");
    CHECK_JS(env, "(c => (c.setAttribute('a', '1'), c.setAttribute('b', '2'), c.isEqualNode(e)))(document.createElement('p'))");
    CHECK_JS(env, "(c => (c.setAttribute('b', '2'), c.setAttribute('a', '1'), c.isEqualNode(e)))(document.createElement('p'))");
    CHECK_JS(env, "(c => (c.setAttribute('a', 'x'), c.setAttribute('b', '2'), !c.isEqualNode(e)))(document.createElement('p'))");
    CHECK_JS(env, "(o => (o.adoptNode(e), a.ownerDocument === o && e.ownerDocument === o))(new Document())");
    // An attribute and a node of another tree, and two detached attributes: disconnected, in a consistent order.
    CHECK_JS(env, "(q => (r => (r & Node.DOCUMENT_POSITION_DISCONNECTED) && (r & Node.DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC) && a.compareDocumentPosition(q) === r)(a.compareDocumentPosition(q)))(document.createElement('q'))");
    CHECK_JS(env, "(([x, y]) => ((xy, yx) => (xy & Node.DOCUMENT_POSITION_DISCONNECTED) && (xy & 6) !== (yx & 6) && (xy & 6) && (yx & 6))(x.compareDocumentPosition(y), y.compareDocumentPosition(x)))([document.createAttribute('x'), document.createAttribute('y')])");
    // An attribute and its element's descendant: the attribute comes first, as its element does.
    CHECK_JS(env, "(i => (e.append(i), a.compareDocumentPosition(i) === Node.DOCUMENT_POSITION_FOLLOWING && i.compareDocumentPosition(a) === Node.DOCUMENT_POSITION_PRECEDING))(document.createElement('i'))");
    // Cloning an Attr, and comparing Attrs.
    CHECK_JS(env, "(c => c !== a && c.name === 'a' && c.value === '1' && c.ownerElement === null && c.isEqualNode(a) && !c.isEqualNode(b))(a.cloneNode())");
}

// A refused name is quoted in its error's message, at most 160 bytes of it cut at a character boundary and then '…'
// (Task 18): the whole name was converted to UTF-8, uncharged, for a message QuickJS cuts to 255 bytes, which could
// split a character and drop the message's own text.
WR_TEST(testErrorMessagesQuoteAtMost160BytesOfAName) {
    DOMEnv env;
    // `quote(head, n)`: head, then n three-byte units, then '…'. 53 units after no head or a one-byte one fit 160 bytes,
    // 52 after a two-byte one; 39 four-byte pairs after 'a' are 157 bytes.
    env.eval("var cjk = ' '.padStart(100001, '\\u4e00'), e = document.createElement('p');"
             "function quote(head, n) { return head + '\\u4e00'.repeat(n) + '\\u2026'; }"
             "function message(f) { try { f(); } catch (x) { return x.message; } return 'no exception'; }");
    CHECK_JS(env, "message(() => document.createElement(cjk)) === \"The tag name provided ('\" + quote('', 53) + \"') is not a valid name.\"");
    CHECK_JS(env, "message(() => document.createElement('a b')) === \"The tag name provided ('a b') is not a valid name.\"");
    CHECK_JS(env, "message(() => document.createAttribute(cjk)) === \"'\" + quote('', 53) + \"' is not a valid attribute name.\"");
    CHECK_JS(env, "message(() => e.setAttribute(cjk, 'v')) === \"'\" + quote('', 53) + \"' is not a valid attribute name.\"");
    CHECK_JS(env, "message(() => e.setAttributeNS('urn:x', '>' + cjk + ':a', 'v')) === \"The qualified name provided ('\" + quote('>', 53) + \"') has an invalid prefix.\"");
    CHECK_JS(env, "message(() => document.createElementNS('urn:x', '>' + cjk + ':a')) === \"The qualified name provided ('\" + quote('>', 53) + \"') has an invalid prefix.\"");
    CHECK_JS(env, "message(() => document.createElementNS('urn:x', 'p:' + cjk)) === \"The qualified name provided ('\" + quote('p:', 52) + \"') is not valid.\"");
    CHECK_JS(env, "message(() => { e.dataset['-a' + cjk] = 'v'; }) === \"'\" + quote('-a', 52) + \"' is not a valid dataset name.\"");
    CHECK_JS(env, "message(() => document.createElement('a' + '\\u{1F600}'.repeat(60) + ' ')) === \"The tag name provided ('a\" + '\\u{1F600}'.repeat(39) + \"\\u2026') is not a valid name.\"");
}

namespace {

/// What running `code` leaves behind once a full GC has collected everything it dropped (as MutationTests.cpp's
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

// Attr nodes and the element's [SameObject] objects (classList, dataset, attributes) are counted references the
// payloads trace: an element dropped with all of them made, and cycles through each, leaves nothing. Values are built
// at run time: a source literal is an interned atom, which a leaked reference would keep without an allocation.
WR_TEST(testAttributeObjectsAreCollected) {
    DOMEnv env;
    checkNothingLeft(leftoverAfter(env, "(() => { const e = document.createElement('div'); e.setAttribute('a', 'v'.repeat(3)); e.setAttribute('data-x', 'd'.repeat(3));"
                                        "e.className = 'p q ' + 'r'.repeat(2); const a = e.getAttributeNode('a'); a.self = a; a.element = e; e.classList.add('s'.repeat(2)); e.classList.length;"
                                        "e.classList.back = e; e.dataset.x; e.dataset.back = 'z'.repeat(2); e.attributes[0]; e.attributes.self = e.attributes;"
                                        "document.documentElement.lastChild.append(e); e.remove(); })()"),
                     "an element with Attr nodes, classList, dataset and attributes");
    // Attrs removed, replaced and detached, and one made by createAttributeNS.
    checkNothingLeft(leftoverAfter(env, "(() => { const e = document.createElement('div'); e.setAttribute('a', '1'.repeat(2)); const a = e.getAttributeNode('a'); e.removeAttributeNode(a);"
                                        "const n = document.createAttribute('b'); n.value = 'w'.repeat(2); e.setAttributeNode(n); const m = document.createAttribute('b'); e.setAttributeNode(m); m.value = 'k'.repeat(2);"
                                        "document.createAttributeNS('urn:x', 'p:q').value = 'z'.repeat(2); e.cloneNode(); e.removeAttribute('b'); })()"),
                     "removed and replaced Attr nodes");
    // An Attr the script keeps keeps its element; dropping it lets both go.
    env.eval("(() => { const e = document.createElement('div'); e.setAttribute('a', 'kept'); globalThis.keepAttr = e.getAttributeNode('a'); })(); gc()");
    CHECK_JS(env, "keepAttr.ownerElement.localName === 'div' && keepAttr.ownerElement.getAttribute('a') === 'kept' && keepAttr.ownerElement.attributes[0] === keepAttr");
    env.eval("(() => { const e = document.createElement('div'); e.className = 'k'; globalThis.keepList = e.classList; globalThis.keepMap = e.dataset; })(); gc()");
    CHECK_JS(env, "keepList.value === 'k' && (keepMap.y = '1', true)");
}

namespace {

class AttributeRecorder : public wr::MutationListener {
public:
    explicit AttributeRecorder(JSContext* ctx) : m_ctx(ctx) {}
    std::string log;
    void attributeChanged(wr::Element&, JSAtom localName, wr::Namespace) override { log += wr::String::fromAtom(m_ctx, localName).utf8() + " "; }

private:
    JSContext* m_ctx;
};

} // namespace

// Every change to an attribute list is told to the listeners, by local name, and bumps the document's version (live
// collections recompute from it); reads and no-ops are not.
WR_TEST(testAttributeChangesAreReported) {
    DOMEnv env;
    wr::Document& document = wr::globalDocument(env.ctx());
    AttributeRecorder recorder(env.ctx());
    document.mutationListeners().push_back(&recorder);
    env.eval("var e = document.createElement('div')");
    uint64_t version = document.version();
    env.eval("e.setAttribute('a', '1'); e.setAttribute('a', '2'); e.id = 'i'; e.classList.add('c'); e.dataset.fooBar = 'x'; e.hidden = true; e.toggleAttribute('t');"
             "e.getAttributeNode('a').value = '3'; e.removeAttribute('a'); delete e.dataset.fooBar; e.hidden = false; e.toggleAttribute('t')");
    CHECK_EQ(recorder.log, std::string("a a id class data-foo-bar hidden t a a data-foo-bar hidden t "));
    CHECK(document.version() > version);
    recorder.log.clear();
    version = document.version();
    env.eval("e.getAttribute('id'); e.removeAttribute('missing'); e.classList.contains('c'); e.dataset.nope; delete e.dataset.nope; e.hidden = false;"
             "document.createAttributeNS('urn:x', 'p:q'); document.createAttribute('r')");
    CHECK_EQ(recorder.log, std::string(""));
    CHECK_EQ(document.version(), version);
    document.mutationListeners().clear();
}
