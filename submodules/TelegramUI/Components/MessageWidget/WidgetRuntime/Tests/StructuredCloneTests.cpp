// structuredClone (V5a plan, Task 4; HTML §2.7 "Safe passing of structured data", serialize then deserialize in one
// realm): plain data copied deeply with its references, the cloneable types with their internal slots, everything else a
// DataCloneError, and a depth cap instead of a native stack overflow.
#include <string>

#include "Tests/HostHarness.h"

using wr_test::HostEnv;

namespace {

const char* const kErr = "window.err = f => { try { f(); return 'ok' } catch (e) { return (e instanceof DOMException ? 'DOMException:' : '') + e.name } }; 1";

} // namespace

WR_TEST(testPlainDataIsCopiedDeeply) {
    HostEnv env;
    CHECK_EQ(env.eval("const s = { a: { b: [1, 2] } }, c = structuredClone(s);"
                      "[c.a.b[1] === 2, c.a !== s.a, structuredClone(undefined) === undefined, Object.is(structuredClone(-0), -0),"
                      " structuredClone(10n) === 10n, structuredClone(null) === null, structuredClone('x')].join()"),
             std::string("true,true,true,true,true,true,x"));
    CHECK_EQ(env.eval("const sp = structuredClone([, 1]); [sp.length, 0 in sp, sp[1]].join()"), std::string("2,false,1"));
}

/// Review Focus 3: a cycle and a shared reference come back as one object.
WR_TEST(testReferencesAndCycles) {
    HostEnv env;
    CHECK_EQ(env.eval("const o = { n: 1 }; o.self = o; const c = structuredClone(o);"
                      "const s = {}; const d = structuredClone({ x: s, y: s });"
                      "[c.self === c, c !== o, d.x === d.y, d.x !== s].join()"),
             std::string("true,true,true,true"));
}

WR_TEST(testTheCloneableTypes) {
    HostEnv env;
    CHECK_EQ(env.eval("const d = structuredClone(new Date(86400000)); [d instanceof Date, d.getTime()].join()"), std::string("true,86400000"));
    CHECK_EQ(env.eval("const r = /a.b/gi; r.lastIndex = 3; const rc = structuredClone(r); [rc instanceof RegExp, rc.source, rc.flags, rc.lastIndex, rc !== r].join()"),
             std::string("true,a.b,gi,0,true"));
    CHECK_EQ(env.eval("const k = { k: 1 }; const m = structuredClone(new Map([[k, { v: [2] }]])); const [[mk, mv]] = [...m];"
                      "[m instanceof Map, m.size, mk.k, mk !== k, mv.v[0]].join()"),
             std::string("true,1,1,true,2"));
    CHECK_EQ(env.eval("const st = structuredClone(new Set([1, 'a'])); [st instanceof Set, [...st].join('+')].join()"), std::string("true,1+a"));
    CHECK_EQ(env.eval("const b = new Uint8Array([1, 2, 3]).buffer; const bc = structuredClone(b);"
                      "[bc instanceof ArrayBuffer, bc !== b, [...new Uint8Array(bc)].join(' ')].join()"),
             std::string("true,true,1 2 3"));
    CHECK_EQ(env.eval("const f = structuredClone(new Float64Array([1.5, 2.5])); const v = structuredClone(new Uint8Array([9, 8, 7, 6]).subarray(1, 3));"
                      "[f instanceof Float64Array, f[1], v.byteOffset, v.length, v[0], v.buffer.byteLength].join()"),
             std::string("true,2.5,1,2,8,4"));
    CHECK_EQ(env.eval("const two = new Uint8Array(4); const pair = structuredClone([two, new Uint16Array(two.buffer)]); pair[0].buffer === pair[1].buffer"),
             std::string("true"));
    CHECK_EQ(env.eval("[structuredClone(new Number(1)) instanceof Number, structuredClone(new String('s')).valueOf(),"
                      " typeof structuredClone(new Boolean(false)), structuredClone(new Boolean(false)).valueOf()].join()"),
             std::string("true,s,object,false"));
    CHECK_EQ(env.eval("const e = structuredClone(new TypeError('m')); [e instanceof TypeError, e.name, e.message, structuredClone(new Error('x')) instanceof Error].join()"),
             std::string("true,TypeError,m,true"));
}

WR_TEST(testPropertySemantics) {
    HostEnv env;
    CHECK_EQ(env.eval("const src = { get g() { return 7 } }; Object.defineProperty(src, 'hidden', { value: 1, enumerable: false });"
                      "src[Symbol('s')] = 2; class A { constructor() { this.a = 1 } } const c = structuredClone(src), ca = structuredClone(new A());"
                      "[c.g, Object.getOwnPropertyDescriptor(c, 'g').value, 'hidden' in c, Object.getOwnPropertySymbols(c).length,"
                      " Object.getPrototypeOf(ca) === Object.prototype, ca.a].join()"),
             std::string("7,7,false,0,true,1"));
}

WR_TEST(testWhatCannotBeCloned) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("[() => 1, Symbol(), document.body, Promise.resolve(), new WeakMap(), new DataView(new ArrayBuffer(1)),"
                      " new Proxy({}, {}), { f() {} }].map(v => err(() => structuredClone(v))).join()"),
             std::string("DOMException:DataCloneError,DOMException:DataCloneError,DOMException:DataCloneError,DOMException:DataCloneError,"
                         "DOMException:DataCloneError,DOMException:DataCloneError,DOMException:DataCloneError,DOMException:DataCloneError"));
    CHECK_EQ(env.eval("[err(() => structuredClone(1, { transfer: [new ArrayBuffer(1)] })), err(() => structuredClone(1, { transfer: [] })),"
                      " err(() => structuredClone(1, {}))].join()"),
             std::string("DOMException:DataCloneError,ok,ok"));
    // A getter's own exception passes through.
    CHECK_EQ(env.eval("err(() => structuredClone({ get x() { throw new RangeError('g') } }))"), std::string("RangeError"));
}

/// Review Focus 3: nesting past the cap is a DataCloneError, not a native stack overflow.
WR_TEST(testDepthIsCapped) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const nest = n => { let a = []; for (let i = 1; i < n; i++) a = [a]; return a };"
                      "[err(() => structuredClone(nest(1000))), err(() => structuredClone(nest(1001)))].join()"),
             std::string("ok,DOMException:DataCloneError"));
}

/// The final review's C3: a Map or a Set is walked by the cloner, through the functions the runtime took at startup, not
/// by the engine's serializer, whose walk held no reference to the record it was on (a value's getter that cleared the
/// map freed that record under it). HTML copies the entries first, so the clone has them as they were.
WR_TEST(testAMapMutatedDuringTheCloneIsClonedAsItWas) {
    HostEnv env;
    CHECK_EQ(env.eval("const m = new Map(), a = []; Object.defineProperty(a, 0, { get() { m.clear(); return 1 }, enumerable: true });"
                      "m.set('k', a).set('l', 2); const c = structuredClone({ m }).m; [m.size, c.size, c.get('k')[0], c.get('l')].join()"),
             std::string("0,2,1,2"));
    CHECK_EQ(env.eval("const s = new Set(), b = []; Object.defineProperty(b, 0, { get() { s.clear(); s.add('late'); return 1 }, enumerable: true });"
                      "s.add(b).add('x'); [...structuredClone(s)].map(v => Array.isArray(v) ? v[0] : v).join()"),
             std::string("1,x"));
}

/// With the walk, a Map's and a Set's keys and values clone like any other value: an object they share with the rest of
/// the graph stays one object, and an Error or an accessor inside one clones (the serializer refused both).
WR_TEST(testMapAndSetEntriesCloneLikeAnyValue) {
    HostEnv env;
    CHECK_EQ(env.eval("const o = {}; const g = structuredClone({ o, m: new Map([[o, o]]), s: new Set([o]) });"
                      "const [[mk, mv]] = [...g.m]; [mk === g.o, mv === g.o, [...g.s][0] === g.o].join()"),
             std::string("true,true,true"));
    CHECK_EQ(env.eval("const em = structuredClone(new Map([['e', new RangeError('r')], ['g', { get x() { return 3 } }]]));"
                      "[em.get('e') instanceof RangeError, em.get('e').message, em.get('g').x].join()"),
             std::string("true,r,3"));
    CHECK_EQ(env.eval("const cyc = new Map(); cyc.set('self', cyc); const cc = structuredClone(cyc); [cc.get('self') === cc, cc !== cyc].join()"),
             std::string("true,true"));
    // The clone is made with the realm's own Map and Set, whatever a script replaced.
    CHECK_EQ(env.eval("const srcMap = new Map([[1, 2]]), srcSet = new Set([3]);"
                      "Map.prototype.entries = Map.prototype.set = Set.prototype.values = Set.prototype.add = () => { throw 1 };"
                      "const mm = structuredClone(srcMap), ss = structuredClone(srcSet);"
                      "[mm instanceof Map, mm.get(1), ss.has(3), ss.size].join()"),
             std::string("true,2,true,1"));
}

/// The final review: a cloned Error keeps its whole message (it was cut at 255 bytes, and at a NUL, by the engine's
/// format buffer), and an accessor `message` is not cloned (HTML reads a data property only).
WR_TEST(testAClonedErrorKeepsItsWholeMessage) {
    HostEnv env;
    CHECK_EQ(env.eval("const long = '\\u00e9'.repeat(1000); const ce = structuredClone(new TypeError(long));"
                      "[ce instanceof TypeError, ce.message === long, structuredClone(new Error('a\\0b')).message.length].join()"),
             std::string("true,true,3"));
    CHECK_EQ(env.eval("const acc = new Error('x'); Object.defineProperty(acc, 'message', { get() { return 'g' } });"
                      "const ca = structuredClone(acc); [Object.hasOwn(ca, 'message'), ca.message === ''].join()"),
             std::string("false,true"));
}

/// The fix-wave's m1: a detached ArrayBuffer is a DataCloneError (HTML), with no exception left pending.
WR_TEST(testADetachedBufferIsADataCloneError) {
    HostEnv env;
    env.eval(kErr);
    CHECK_EQ(env.eval("const d = new ArrayBuffer(2); d.transfer(); err(() => structuredClone(d))"), std::string("DOMException:DataCloneError"));
}
