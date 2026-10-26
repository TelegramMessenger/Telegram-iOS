// Host tests for quickjs-ng's work counter (VENDOR.md local edit 2).
#include "quickjs.h"
#include "qjs_shim.h"

#include <malloc/malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); failures++; } } while (0)

/* The process's heap in use, all zones: a leak shows as growth across a runtime's whole life. */
static size_t heap_in_use(void) {
    malloc_statistics_t stats;
    malloc_zone_statistics(NULL, &stats);
    return stats.size_in_use;
}

static uint64_t limit = UINT64_MAX;
static int stop_past_limit(JSRuntime *rt, void *opaque) {
    (void)opaque;
    return JS_GetWorkUnits(rt) > limit;
}

/* Runs `code` in a fresh runtime with the budget `budget`; returns the units spent and whether it was interrupted. */
static uint64_t run(const char *code, uint64_t budget, int *interrupted) {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetMaxStackSize(rt, 2 << 20);
    JSContext *ctx = JS_NewContext(rt);
    uint64_t start = JS_GetWorkUnits(rt);
    limit = budget == UINT64_MAX ? UINT64_MAX : start + budget;
    JS_SetInterruptHandler(rt, stop_past_limit, NULL);
    JSValue v = qjs_eval(ctx, code, strlen(code), "t.js", false);
    *interrupted = qjs_is_exception(v);
    if (*interrupted) {
        char *d = qjs_take_exception_description(ctx);
        *interrupted = d && strstr(d, "interrupted") != NULL;
        free(d);
    }
    qjs_free_value(ctx, v);
    uint64_t spent = JS_GetWorkUnits(rt) - start;
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    return spent;
}


/* Runs `setup` with no budget, then `op` with `budget` units in the same runtime: whether `op` was interrupted, and
   the units it spent. A scanning builtin that charges its work is stopped partway through; one that does not runs to
   its end. */
static uint64_t run_op(const char *setup, const char *op, uint64_t budget, int *interrupted) {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetMaxStackSize(rt, 2 << 20);
    JSContext *ctx = JS_NewContext(rt);
    limit = UINT64_MAX;
    JS_SetInterruptHandler(rt, stop_past_limit, NULL);
    JSValue v = qjs_eval(ctx, setup, strlen(setup), "setup.js", false);
    if (qjs_is_exception(v)) {
        char *d = qjs_take_exception_description(ctx);
        printf("setup failed: %s\n", d ? d : "?");
        free(d);
    }
    qjs_free_value(ctx, v);
    uint64_t start = JS_GetWorkUnits(rt);
    limit = start + budget;
    v = qjs_eval(ctx, op, strlen(op), "op.js", false);
    *interrupted = 0;
    if (qjs_is_exception(v)) {
        char *d = qjs_take_exception_description(ctx);
        *interrupted = d && strstr(d, "interrupted") != NULL;
        free(d);
    }
    qjs_free_value(ctx, v);
    uint64_t spent = JS_GetWorkUnits(rt) - start;
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    return spent;
}

int main(void) {
    int interrupted = 0;

    // Deterministic: the same script spends the same units in two fresh runtimes.
    const char *loop = "let s = 0; for (let i = 0; i < 100000; i++) s += i; s";
    uint64_t a = run(loop, UINT64_MAX, &interrupted);
    uint64_t b = run(loop, UINT64_MAX, &interrupted);
    CHECK(a == b);
    CHECK(a >= 100000);

    // Allocation is charged: 4 MB of `repeat` costs at least its bytes' units.
    uint64_t bytes = run("'a'.repeat(1 << 22).length", UINT64_MAX, &interrupted);
    CHECK(bytes >= ((uint64_t)1 << 22) >> JS_WORK_ALLOC_SHIFT);

    // Regex steps are charged, and catastrophic backtracking is stopped at the budget.
    uint64_t regex = run("/(a+)+$/.test('a'.repeat(26) + 'b')", 200000, &interrupted);
    CHECK(interrupted);
    CHECK(regex >= 200000);

    // An infinite loop is stopped at its budget, deterministically.
    uint64_t s1 = run("for (;;) {}", 50000, &interrupted);
    CHECK(interrupted);
    uint64_t s2 = run("for (;;) {}", 50000, &interrupted);
    CHECK(s1 == s2);


    // Every scanning builtin charges its work and is stopped when that work passes the budget: one call each, with a
    // budget well under the work it does (local edit 2, Task 2's table). Equality and atoms cannot raise where they
    // charge, so the next poll decides: those run in a short loop.
    static const struct { const char *setup, *op; uint64_t budget; } scans[] = {
        { "var h = 'a'.repeat(1 << 21) + 'b', n = 'a'.repeat(64) + 'c';", "h.indexOf(n)", 1000000 },
        { "var h = 'a'.repeat(1 << 21) + 'b', n = 'a'.repeat(64) + 'c';", "h.includes(n)", 1000000 },
        { "var h = 'a'.repeat(1 << 21) + 'b', n = 'a'.repeat(64) + 'c';", "h.lastIndexOf(n)", 1000000 },
        { "var h = 'a'.repeat(1 << 21) + 'b', n = 'a'.repeat(64) + 'c';", "h.split(n)", 1000000 },
        { "var h = 'a'.repeat(1 << 21) + 'b', n = 'a'.repeat(64) + 'c';", "h.replaceAll(n, 'x')", 1000000 },
        { "var h = 'a'.repeat(1 << 22), k = 'a'.repeat(1 << 22);", "for (var i = 0; i < 3; i++) h === k", 100000 },
        { "var h = 'a'.repeat(1 << 22), k = 'a'.repeat(1 << 22) + 'b';", "h < k", 100000 },
        { "var h = 'a'.repeat(1 << 21), k = 'a'.repeat(1 << 21);", "h.localeCompare(k)", 50000 },
        { "var k = 'k'.repeat(1 << 20), o = {};", "for (var i = 0; i < 3; i++) o[k] = 1", 20000 },
        { "var a = new Array(1 << 20).fill(1);", "a.indexOf(2)", 20000 },
        { "var a = new Array(1 << 20).fill(1);", "a.lastIndexOf(2)", 20000 },
        { "var a = new Array(1 << 20).fill(1);", "a.includes(2)", 20000 },
        { "var a = new Array(1 << 20).fill(1);", "a.fill(0)", 20000 },
        { "var a = new Array(1 << 20).fill(1);", "a.copyWithin(0, 1)", 20000 },
        { "var a = new Array(1 << 20).fill(1);", "a.reverse()", 20000 },
        { "var a = []; for (var i = 0; i < 50000; i++) a.push(String(i));", "a.sort()", 200000 },
        { "var t = new Uint8Array(1 << 22);", "t.fill(1)", 100000 },
        { "var t = new Uint8Array(1 << 22), u = new Uint8Array(1 << 22);", "t.set(u)", 100000 },
        { "var t = new Uint8Array(1 << 22);", "t.reverse()", 100000 },
        { "var t = new Uint8Array(1 << 22);", "t.indexOf(2)", 100000 },
        { "var t = new Uint8Array(1 << 22);", "t.includes(2)", 100000 },
        { "var t = new Float64Array(1 << 18); for (var i = 0; i < t.length; i++) t[i] = (i * 7919) % 1000;", "t.sort()", 100000 },
        { "var b = new ArrayBuffer(1 << 22);", "b.slice(0)", 30000 },
        { "var b = 7n ** 20000n;", "b * b", 100000 },
        { "var j = '[' + '1,'.repeat(1 << 20) + '1]';", "JSON.parse(j)", 50000 },
        { "var src = 'x;'.repeat(1 << 20);", "new Function(src)", 50000 },
        // Final review C1: natives that scan their input without allocating. Hashing a Map key and converting a string
        // for Number() charge where no exception can be raised, so those run in a short loop.
        { "var s = ' '.repeat(1 << 22);", "s.trim()", 100000 },
        { "var s = ' '.repeat(1 << 22);", "s.trimStart()", 100000 },
        { "var s = ' '.repeat(1 << 22);", "s.trimEnd()", 100000 },
        { "var s = '\\u0100'.repeat(1 << 21);", "s.isWellFormed()", 100000 },
        { "var s = ' '.repeat(1 << 22);", "for (var i = 0; i < 3; i++) Number(s)", 100000 },
        { "var s = ' '.repeat(1 << 22);", "for (var i = 0; i < 3; i++) parseFloat(s)", 100000 },
        { "var s = ' '.repeat(1 << 22);", "for (var i = 0; i < 3; i++) parseInt(s)", 100000 },
        { "var m = new Map(), k = 'a'.repeat(1 << 22);", "for (var i = 0; i < 3; i++) m.has(k)", 100000 },
        { "var m = new Map(), k = 'a'.repeat(1 << 22);", "for (var i = 0; i < 3; i++) m.set(k, 1)", 100000 },
        { "var m = new Map(), k = 'a'.repeat(1 << 22);", "for (var i = 0; i < 3; i++) m.delete(k)", 100000 },
        { "var m = new Map([['a'.repeat(1 << 22), 1]]), k = 'a'.repeat(1 << 22);", "for (var i = 0; i < 3; i++) m.get(k)", 100000 },
        { "var t = new Set(), k = 'a'.repeat(1 << 22);", "for (var i = 0; i < 3; i++) t.add(k)", 100000 },
        { "var m = new Map(), a = 'ab'; for (var i = 0; i < 21; i++) a = a + a;", "for (var i = 0; i < 3; i++) m.has(a)", 100000 },
        { "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (var i = 0; i < 3; i++) o.missing", 100000 },
        { "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (var i = 0; i < 3; i++) o['mis' + 'sing']", 100000 },
        { "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (var i = 0; i < 3; i++) 'x' in o", 100000 },
        { "function C() {} var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (var i = 0; i < 3; i++) o instanceof C", 100000 },
        { "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (var i = 0; i < 3; i++) o['m' + i] = 1", 100000 },
        { "var o = {}; for (var i = 0; i < 100000; i++) o = Object.create(o);", "for (var i = 0; i < 3; i++) Object.setPrototypeOf({}, o)", 100000 },
        // Final review C2: regex execs shorter than libregexp's step period.
        { "var s = 'a'.repeat(4500), r = /b/g;", "for (var i = 0; i < 100; i++) { r.lastIndex = 0; r.exec(s); }", 100000 },
        { "var s = 'a'.repeat(4000);", "for (var i = 0; i < 100; i++) /b/.test(s)", 100000 },
        // Final review C4: BigInt division and string conversion.
        { "var a = 7n ** 40000n, b = 3n ** 20000n;", "a / b", 50000 },
        { "var a = 7n ** 40000n, b = 3n ** 20000n;", "a % b", 50000 },
        { "var a = 7n ** 40000n;", "a.toString()", 50000 },
        { "var s = '7'.repeat(30000);", "BigInt(s)", 50000 },
        // Final review C5: generic and sparse array-likes, one call each.
        { "var o = {length: 1 << 22};", "Array.prototype.join.call(o, '')", 100000 },
        { "var o = {length: 1 << 22};", "Array.prototype.shift.call(o)", 100000 },
        { "var o = {length: 1 << 22};", "Array.prototype.unshift.call(o, 1)", 100000 },
        { "var o = {length: 1 << 22};", "Array.prototype.splice.call(o, 0, 1)", 100000 },
        { "var o = {length: 1 << 22};", "Array.prototype.slice.call(o)", 100000 },
        { "var o = {length: 1 << 22};", "Array.prototype.sort.call(o)", 100000 },
        { "var o = {length: 1 << 22, [Symbol.isConcatSpreadable]: true};", "[].concat(o)", 100000 },
        { "var a = []; a[1 << 22] = 1;", "a.flat()", 100000 },
        { "", "Uint8Array.from({length: 1 << 22})", 100000 },
        { "var src = '[' + Array.from({length: 20000}, (_, i) => String.fromCharCode(0x4e00 + 2 * i)).join('') + ']';", "new RegExp(src)", 100000 },
    };
    for (size_t i = 0; i < sizeof(scans) / sizeof(scans[0]); i++) {
        uint64_t spent = run_op(scans[i].setup, scans[i].op, scans[i].budget, &interrupted);
        if (!interrupted) printf("not stopped (%llu units): %s\n", (unsigned long long)spent, scans[i].op);
        CHECK(interrupted);
    }

    // Final review I1: a call stopped inside a long-string comparison or a BigInt power frees its operands. Each case
    // runs `runs` times, so the leak it would make (`leak` bytes a run) stands well above the allocator's noise.
    static const struct { const char *setup, *op; int runs; } leaks[] = {
        { "var a = 'x'.repeat(3e7), b = a + 'y';", "a < b", 1 },
        { "var a = BigInt('0x' + 'f'.repeat(75000));", "a ** 3n", 64 },
    };
    for (size_t i = 0; i < sizeof(leaks) / sizeof(leaks[0]); i++) {
        run_op(leaks[i].setup, leaks[i].op, 10000, &interrupted);
        size_t before = heap_in_use();
        for (int r = 0; r < leaks[i].runs; r++) {
            run_op(leaks[i].setup, leaks[i].op, 10000, &interrupted);
            CHECK(interrupted);
        }
        size_t after = heap_in_use();
        if (after > before + (1 << 20)) printf("leaked %zu bytes: %s\n", after - before, leaks[i].op);
        CHECK(after <= before + (1 << 20));
    }

    printf(failures ? "FAILED (%d)\n" : "OK\n", failures);
    return failures ? 1 : 0;
}
