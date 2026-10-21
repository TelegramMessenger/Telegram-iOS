// The native-path sweep (quickjs_native_sweep_test.c): every builtin function, called with large receivers and
// arguments, so that one whose wall time per unit of work is far above the reference loop's (a native path the work
// counter does not charge, VENDOR.md local edit 2) shows up without anyone having to guess it. The harness reads
// __count(), then for each probe __prepare(i) (untimed: builds the receiver and arguments) and __run() (timed).

(function () {
var BIG = 1 << 20;

// Each value is built on first use and kept for the rest of the child process, which runs one method's probes.
var factories = {
    'str 1M': () => 'a'.repeat(BIG),
    'spaces 1M': () => ' '.repeat(BIG),
    'u0100 512K': () => 'Ā'.repeat(BIG >> 1),
    'lone surrogates 512K': () => '\ud800'.repeat(BIG >> 1),
    'digits 64K': () => '7'.repeat(BIG >> 4),
    'rope 2M': () => { var s = 'ab'; for (var i = 0; i < 20; i++) s = s + s; return s; },
    'array 128K strings': () => new Array(1 << 17).fill('ab'),
    'array 128K numbers': () => Array.from({ length: 1 << 17 }, (_, i) => i),
    'array nested': () => Array.from({ length: 1 << 12 }, () => [1, [2, [3, [4]]]]),
    'sparse 2^31': () => { var a = []; a[2 ** 31] = 1; return a; },
    'holey 2^20': () => { var a = []; a.length = 1 << 20; return a; },
    'array-like 2^40': () => ({ length: 2 ** 40 }),
    'array-like 2^31': () => ({ length: 2 ** 31 }),
    'Uint8Array 4M': () => new Uint8Array(1 << 22),
    'Float64Array 256K': () => new Float64Array(1 << 18),
    'ArrayBuffer 4M': () => new ArrayBuffer(1 << 22),
    'DataView 4M': () => new DataView(new ArrayBuffer(1 << 22)),
    'Map 64K': () => new Map(Array.from({ length: 1 << 16 }, (_, i) => [i, i])),
    'Set 64K': () => new Set(Array.from({ length: 1 << 16 }, (_, i) => i)),
    'object 64K keys': () => { var o = {}; for (var i = 0; i < 1 << 16; i++) o['k' + i] = i; return o; },
    'object long key': () => { var o = {}; o['k'.repeat(BIG)] = 1; return o; },
    'proto chain 100K': () => { var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o); return o; },
    'bigint 7^20000': () => 7n ** 20000n,
    'bigint 3^9000': () => 3n ** 9000n,
    'regex /a*b/g': () => /a*b/g,
    'regex class 4K': () => new RegExp('[' + Array.from({ length: 4096 }, (_, i) => String.fromCharCode(0x4e00 + 2 * i)).join('') + ']', 'g'),
    'function': () => function f(a, b) { return a; },
    'comparator': () => (a, b) => (a < b ? -1 : a > b ? 1 : 0),
    'Date': () => new Date(0),
    'Error long message': () => new Error('x'.repeat(BIG)),
    'Symbol': () => Symbol('s'),
    'number 1e6': () => 1e6,
    'number 2^31': () => 2 ** 31,
    'number 2^40': () => 2 ** 40,
    'number -1': () => -1,
    'zero': () => 0,
    'NaN': () => NaN,
    'true': () => true,
    'undefined': () => undefined,
    'null': () => null,
    'empty string': () => '',
    'short string b': () => 'b',
};
var labels = Object.keys(factories);
var cache = {};
function value(label) {
    if (!(label in cache)) cache[label] = factories[label]();
    return cache[label];
}

// Argument lists: none, each value alone, and pairs that drive a native's size parameters.
var argSets = [[]];
for (var l of labels) argSets.push([l]);
for (var pair of [
    ['str 1M', 'short string b'], ['str 1M', 'str 1M'], ['str 1M', 'number 1e6'], ['spaces 1M', 'str 1M'],
    ['zero', 'number 2^40'], ['zero', 'number 1e6'], ['number 1e6', 'str 1M'], ['number 2^31', 'str 1M'],
    ['regex /a*b/g', 'str 1M'], ['str 1M', 'function'], ['array 128K numbers', 'comparator'],
    ['array-like 2^40', 'function'], ['empty string', 'str 1M'], ['u0100 512K', 'u0100 512K'],
    ['bigint 7^20000', 'bigint 3^9000'], ['number 2^40', 'number 2^40'], ['str 1M', 'number 2^31'],
]) argSets.push(pair);

// Every function reachable from the global object: statics, prototype methods (string and symbol keys), getters,
// and the constructors themselves, called and constructed. Iterator and generator prototypes are reached through
// instances.
var methods = [];
function addOwn(owner, ownerName, receivers) {
    for (var key of Reflect.ownKeys(owner)) {
        var d = Object.getOwnPropertyDescriptor(owner, key);
        var name = ownerName + '.' + (typeof key === 'symbol' ? '[' + key.description + ']' : key);
        if (d && typeof d.value === 'function') methods.push({ name: name, fn: d.value, receivers: receivers, construct: false });
        else if (d && typeof d.get === 'function') methods.push({ name: name + ' (get)', fn: d.get, receivers: receivers, construct: false });
    }
}
var seenProtos = new Set();
function addProto(proto, protoName) {
    if (!proto || seenProtos.has(proto)) return;
    seenProtos.add(proto);
    addOwn(proto, protoName, labels);
}
var skip = new Set(['__count', '__prepare', '__run', '__name', '__method', '__methodCount', '__methodStart']);
// The driver's own values are locals of this closure, so only the harness's __ functions are globals of ours.
for (var g of Object.getOwnPropertyNames(globalThis).sort()) {
    if (skip.has(g)) continue;
    var v = globalThis[g];
    if (typeof v === 'function') {
        methods.push({ name: g + '()', fn: v, receivers: ['undefined'], construct: false });
        if (/^[A-Z]/.test(g)) methods.push({ name: 'new ' + g + '()', fn: v, receivers: ['undefined'], construct: true });
        addOwn(v, g, ['undefined']);
        if (v.prototype) addProto(v.prototype, g + '.prototype');
    } else if (v && typeof v === 'object' && g !== 'globalThis') {
        addOwn(v, g, ['undefined']);
    }
}
// The %TypedArray% intrinsic and the iterator prototypes are not globals.
addProto(Object.getPrototypeOf(Uint8Array.prototype), '%TypedArray%.prototype');
addOwn(Object.getPrototypeOf(Uint8Array), '%TypedArray%', ['undefined']);
addProto(Object.getPrototypeOf([][Symbol.iterator]()), '%ArrayIterator%.prototype');
addProto(Object.getPrototypeOf(''[Symbol.iterator]()), '%StringIterator%.prototype');
addProto(Object.getPrototypeOf(new Map()[Symbol.iterator]()), '%MapIterator%.prototype');
addProto(Object.getPrototypeOf(new Set()[Symbol.iterator]()), '%SetIterator%.prototype');
addProto(Object.getPrototypeOf(/a/[Symbol.matchAll]('a')), '%RegExpStringIterator%.prototype');
addProto(Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]())), '%IteratorPrototype%');

// The probes, in a fixed order: for each method, each receiver with each argument list. A method's probes are
// contiguous, so the harness runs each method in a child process of its own.
var probes = [];
methods.forEach(function (m, mi) {
    for (var r of m.receivers) for (var a = 0; a < argSets.length; a++) probes.push([mi, r, a]);
});

// Where each method's probes start, for the harness's shards: __methodStart(methods.length) is the end.
var starts = [];
probes.forEach(function (p, i) { if (starts.length === p[0]) starts.push(i); });
starts.push(probes.length);

var current = null;
globalThis.__methodCount = function () { return methods.length; };
globalThis.__methodStart = function (m) { return starts[m]; };
globalThis.__count = function () { return probes.length; };
globalThis.__method = function (i) { return probes[i][0]; };
globalThis.__name = function (i) {
    var p = probes[i], m = methods[p[0]];
    return m.name + ' this=' + p[1] + ' args=[' + argSets[p[2]].join(', ') + ']';
};
globalThis.__prepare = function (i) {
    var p = probes[i], m = methods[p[0]];
    current = { fn: m.fn, construct: m.construct, self: value(p[1]), args: argSets[p[2]].map(value) };
};
globalThis.__run = function () {
    try {
        if (current.construct) Reflect.construct(current.fn, current.args);
        else Reflect.apply(current.fn, current.self, current.args);
    } catch (e) {
        // Wrong receiver, range errors, out of memory: all cheap and expected. An interrupt is not catchable.
    }
};
})();
