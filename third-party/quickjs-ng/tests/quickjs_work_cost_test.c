// Cost coverage of the work counter (VENDOR.md local edit 2): every attack, run to a fixed budget, must spend at most
// CEILING_NS of wall time per unit. Run optimized: ./build-input/bazel-9.2.0-darwin-arm64 test -c opt
// //third-party/quickjs-ng:QuickJSWorkCostTests --test_output=all
#include "quickjs.h"
#include "qjs_shim.h"

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define BUDGET 4000000ull
/* Calibration (VENDOR.md local edit 2): every attack within these of the reference row. */
#define CEILING_PER_UNIT 2.0
#define CEILING_OVERRUN 2.5

static uint64_t limit;
static int stop(JSRuntime *rt, void *o) { (void)o; return JS_GetWorkUnits(rt) > limit; }
static double now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e9 + t.tv_nsec; }

static const char *attacks[][3] = {
    { "reference: arithmetic loop", "let s = 0;", "for (;;) s = (s + 1) | 0;" },
    { "calls", "function f(x) { return x + 1; } let s = 0;", "for (;;) s = f(s);" },
    { "repeat 4 MB", "var x;", "for (;;) x = 'a'.repeat(1 << 22);" },
    { "padStart 4 MB", "var x;", "for (;;) x = ''.padStart(1 << 22, 'ab');" },
    { "concat", "var s = 'a'.repeat(1 << 20); var x;", "for (;;) x = s + s;" },
    { "join", "var a = new Array(1 << 18).fill('ab'); var x;", "for (;;) x = a.join(',');" },
    { "split", "var s = 'a'.repeat(1 << 20); var x;", "for (;;) x = s.split('');" },
    { "spread", "var a = new Array(1 << 18).fill(1); var x;", "for (;;) x = [...a];" },
    { "stringify", "var a = []; for (var i = 0; i < 200000; i++) a.push(i); var x;", "for (;;) x = JSON.stringify(a);" },
    { "parse", "var j = '[' + '1,'.repeat(1 << 20) + '1]';", "for (;;) JSON.parse(j);" },
    { "indexOf pathological", "var h = 'a'.repeat(1 << 21) + 'b';", "for (;;) h.indexOf('a'.repeat(64) + 'c');" },
    { "string equality", "var h = 'a'.repeat(1 << 22), k = 'a'.repeat(1 << 22);", "for (;;) h === k + '';" },
    { "localeCompare", "var h = 'a'.repeat(1 << 21);", "for (;;) h.localeCompare(h);" },
    { "array indexOf", "var a = new Array(1 << 20).fill(1);", "for (;;) a.indexOf(2);" },
    { "array fill", "var a = new Array(1 << 20).fill(1);", "for (;;) a.fill(0);" },
    { "sort strings", "var a = []; for (var i = 0; i < 50000; i++) a.push(String(i));", "for (;;) a.slice().sort();" },
    { "sort comparator", "var a = []; for (var i = 0; i < 50000; i++) a.push(i);", "for (;;) a.slice().sort((x, y) => y - x);" },
    { "typed fill", "var t = new Uint8Array(1 << 22);", "for (;;) t.fill(1);" },
    { "typed indexOf", "var t = new Uint8Array(1 << 22);", "for (;;) t.indexOf(2);" },
    { "typed sort", "var t = new Float64Array(1 << 18);", "for (;;) t.sort();" },
    { "typed set", "var t = new Uint8Array(1 << 22), u = new Uint8Array(1 << 22);", "for (;;) t.set(u);" },
    { "bigint mul", "var b = 7n ** 20000n;", "for (;;) b * b;" },
    { "regex backtracking", "", "for (;;) /(a+)+$/.test('a'.repeat(30) + 'b');" },
    { "Function source", "var src = 'x;'.repeat(1 << 20);", "for (;;) new Function(src);" },
    { "long property keys", "var k = 'k'.repeat(1 << 20), o = {};", "for (;;) o[k + ''] = 1;" },
    { "deep recursion", "function r(n) { return n ? r(n - 1) + 1 : 0; }", "for (;;) try { r(1e6); } catch (e) {}" },
    { "gc pressure", "var keep = []; for (var i = 0; i < 300000; i++) keep.push({ i: i });", "for (;;) ({ a: [1, 2, 3] });" },
    { "proxy traps", "var p = new Proxy({}, { get: (t, k) => k }); var x;", "for (;;) x = p.foo;" },
    /* Final review (2026-10-15): natives the first list missed. */
    { "trim", "var s = ' '.repeat(1 << 22);", "for (;;) s.trim();" },
    { "isWellFormed", "var s = '\\u0100'.repeat(1 << 21);", "for (;;) s.isWellFormed();" },
    { "Number of spaces", "var s = ' '.repeat(1 << 22);", "for (;;) Number(s);" },
    { "parseFloat of spaces", "var s = ' '.repeat(1 << 22);", "for (;;) parseFloat(s);" },
    { "Map long key", "var m = new Map(), k = 'a'.repeat(1 << 22);", "for (;;) m.has(k);" },
    { "Map rope key", "var m = new Map(), a = 'ab'; for (var i = 0; i < 21; i++) a = a + a;", "for (;;) m.has(a);" },
    { "prototype chain get", "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (;;) o.missing;" },
    { "prototype chain in", "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (;;) 'x' in o;" },
    { "prototype chain instanceof", "function C() {} var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (;;) o instanceof C;" },
    { "short regex exec", "var s = 'a'.repeat(4500), r = /b/g;", "for (;;) { r.lastIndex = 0; r.exec(s); }" },
    { "short regex test", "var s = 'a'.repeat(4000);", "for (;;) /b/.test(s);" },
    { "bigint div", "var a = 7n ** 40000n, b = 3n ** 20000n;", "for (;;) a / b;" },
    { "bigint mod", "var a = 7n ** 40000n, b = 3n ** 20000n;", "for (;;) a % b;" },
    { "bigint toString", "var a = 7n ** 40000n;", "for (;;) a.toString();" },
    { "BigInt from string", "var s = '7'.repeat(30000);", "for (;;) BigInt(s);" },
    { "generic join", "var o = {length: 2 ** 40};", "for (;;) Array.prototype.join.call(o, '');" },
    { "generic shift", "var o = {length: 2 ** 40};", "for (;;) Array.prototype.shift.call(o);" },
    { "generic slice", "var o = {length: 2 ** 31};", "for (;;) Array.prototype.slice.call(o);" },
    { "generic sort", "var o = {length: 2 ** 40};", "for (;;) Array.prototype.sort.call(o);" },
    { "spreadable concat", "var o = {length: 2 ** 40, [Symbol.isConcatSpreadable]: true};", "for (;;) [].concat(o);" },
    { "sparse flat", "var a = []; a[2 ** 31] = 1;", "for (;;) a.flat();" },
    { "sparse stringify", "var a = []; a.length = 2 ** 31;", "for (;;) JSON.stringify(a);" },
    { "typed from array-like", "", "for (;;) Uint8Array.from({length: 1 << 22});" },
    { "regex class compile", "var src = '[' + Array.from({length: 80000}, (_, i) => String.fromCharCode(0x4e00 + 2 * i)).join('') + ']';", "for (;;) new RegExp(src);" },
    /* The native-path sweep (QuickJSNativeSweep, 2026-10-15): what it found, confirmed best of three. */
    /* 1M elements: under the budget, so the one up-front charge lets the loop start (4M would stop it before). */
    { "generic fill of typed, long string", "var t = new Uint8Array(1 << 20), s = 'a'.repeat(1 << 20);", "for (;;) Array.prototype.fill.call(t, s);" },
    { "replaceAll empty pattern", "var s = 'a'.repeat(1 << 20);", "for (;;) s.replaceAll('', s);" },
    { "sumPrecise typed", "var t = new Uint8Array(1 << 22);", "for (;;) Math.sumPrecise(t);" },
    { "Set isSupersetOf", "var a = new Set(), b = new Set(); for (var i = 0; i < 65536; i++) { a.add(i); b.add(i); }", "for (;;) a.isSupersetOf(b);" },
    { "Set isSubsetOf", "var a = new Set(), b = new Set(); for (var i = 0; i < 65536; i++) { a.add(i); b.add(i); }", "for (;;) a.isSubsetOf(b);" },
    { "Set difference", "var a = new Set(), b = new Set(); for (var i = 0; i < 65536; i++) { a.add(i); b.add(i); }", "for (;;) a.difference(b);" },
    { "holey reverse", "var a = []; a.length = 1 << 20;", "for (;;) a.reverse();" },
    { "typed set from strings", "var t = new Float64Array(1 << 18), a = new Array(1 << 18).fill('ab');", "for (;;) t.set(a);" },
    { "typed set from holey", "var t = new Uint8Array(1 << 20), a = []; a.length = 1 << 20;", "for (;;) t.set(a);" },
    { "localeCompare lone surrogates", "var s = '\\ud800'.repeat(1 << 19);", "for (;;) s.localeCompare('0');" },
    /* Missed by the sweep's first floor (a call under 2 ms is not reported): each call is fast, a loop of them is not. */
    { "normalize lone surrogates", "var s = '\\ud800'.repeat(1 << 19);", "for (;;) s.normalize();" },
    { "normalize NFD", "var s = '\\u00e9'.repeat(1 << 19);", "for (;;) s.normalize('NFD');" },
    /* The sweep at a 0.2 ms floor: a search whose match is the whole needle charged nothing for comparing it. */
    { "indexOf of an equal string", "var s = 'a'.repeat(1 << 20), t = 'a'.repeat(1 << 20);", "for (;;) s.indexOf(t);" },
    { "startsWith an equal string", "var s = 'a'.repeat(1 << 20), t = 'a'.repeat(1 << 20);", "for (;;) s.startsWith(t);" },
    { "split by an equal string", "var s = 'a'.repeat(1 << 20), t = 'a'.repeat(1 << 20);", "for (;;) s.split(t);" },
};

/* Runs `setup` with no budget, then `attack` to BUDGET units: the units spent and the wall time, in ns. */
static uint64_t run(const char *setup, const char *attack, double *ns) {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetMaxStackSize(rt, 2 << 20);
    JS_SetMemoryLimit(rt, 256 << 20);
    JSContext *ctx = JS_NewContext(rt);
    limit = UINT64_MAX;
    JS_SetInterruptHandler(rt, stop, NULL);
    JSValue v = qjs_eval(ctx, setup, strlen(setup), "setup.js", false);
    qjs_free_value(ctx, v);
    uint64_t start = JS_GetWorkUnits(rt);
    limit = start + BUDGET;
    double t0 = now_ns();
    v = qjs_eval(ctx, attack, strlen(attack), "attack.js", false);
    *ns = now_ns() - t0;
    uint64_t units = JS_GetWorkUnits(rt) - start;
    qjs_free_value(ctx, v);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    return units;
}

/* A hang is a failure, not a test timeout: each attack has ALARM_SECONDS to reach its budget. */
#define ALARM_SECONDS 20
static const char *current = "";
static void on_alarm(int sig) {
    (void)sig;
    char line[256];
    int n = snprintf(line, sizeof(line), "FAIL: %s did not reach its budget in %d s (an uncharged path)\n", current, ALARM_SECONDS);
    write(1, line, n > 0 ? (size_t)n : 0);
    _exit(1);
}

int main(void) {
    /* Line-buffered: the alarm ends the process with _exit, which would drop a block-buffered table. */
    setvbuf(stdout, NULL, _IOLBF, 0);
    signal(SIGALRM, on_alarm);
    int failures = 0;
    double reference = 0.0;
    printf("%-26s %12s %10s %10s %10s\n", "attack", "units", "ms", "ns/unit", "× budget");
    for (size_t i = 0; i < sizeof(attacks) / sizeof(attacks[0]); i++) {
        double ns = 0.0;
        current = attacks[i][0];
        alarm(ALARM_SECONDS);
        uint64_t units = run(attacks[i][1], attacks[i][2], &ns);
        alarm(0);
        double per = ns / (double)units;
        if (i == 0) reference = per;
        /* The wall time against what the budget is worth at the reference rate: an operation that keeps working
           past its budget without a check shows here, whatever its units say. */
        double overrun = ns / ((double)BUDGET * reference);
        printf("%-26s %12llu %10.1f %10.2f %10.2f\n", attacks[i][0], (unsigned long long)units, ns / 1e6, per, overrun);
        if (per > CEILING_PER_UNIT * reference) { printf("  FAIL: %.1f× the reference per unit\n", per / reference); failures++; }
        if (overrun > CEILING_OVERRUN) { printf("  FAIL: ran %.1f× what the budget is worth\n", overrun); failures++; }
    }
    printf("reference %.2f ns/unit = %.0f units/ms\n", reference, 1e6 / reference);
    return failures ? 1 : 0;
}
