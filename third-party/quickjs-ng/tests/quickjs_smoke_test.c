// Host smoke test for the vendored quickjs-ng + qjs_shim: evaluation, exceptions,
// bytecode round trip, and that the stack limit turns deep recursion into a catchable
// RangeError instead of a crash.
#include "quickjs.h"
#include "qjs_shim.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); failures++; } } while (0)

static JSValue eval(JSContext *ctx, const char *code) {
    return qjs_eval(ctx, code, strlen(code), "t.js", false);
}

static int interrupt_polls = 0;
static int count_polls(JSRuntime *rt, void *opaque) {
    (void)rt;
    (void)opaque;
    interrupt_polls++;
    return 0;
}

int main(void) {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetMaxStackSize(rt, 2 << 20);
    JSContext *ctx = JS_NewContext(rt);

    JSValue v = eval(ctx, "1 + 2");
    CHECK(qjs_is_number(v) && qjs_to_float64(ctx, v) == 3.0);
    qjs_free_value(ctx, v);

    v = eval(ctx, "throw new TypeError('boom')");
    CHECK(qjs_is_exception(v));
    char *desc = qjs_take_exception_description(ctx);
    CHECK(desc && strstr(desc, "boom"));
    free(desc);

    const char *src = "globalThis.answer = 6 * 7;";
    size_t len = 0;
    uint8_t *blob = qjs_compile_bytecode(ctx, src, strlen(src), "b.js", &len);
    CHECK(blob && len > 0);
    JSValue r = qjs_eval_bytecode(ctx, blob, len, src, strlen(src));
    CHECK(!qjs_is_exception(r));
    qjs_free_value(ctx, r);
    qjs_free_bytecode(ctx, blob);
    v = eval(ctx, "answer");
    CHECK(qjs_is_number(v) && qjs_to_float64(ctx, v) == 42.0);
    qjs_free_value(ctx, v);

    v = eval(ctx, "function f(n) { return f(n + 1) + 1; } f(0)");
    CHECK(qjs_is_exception(v));
    desc = qjs_take_exception_description(ctx);
    CHECK(desc && strstr(desc, "RangeError"));
    free(desc);

    // The interrupt handler is polled every JS_INTERRUPT_COUNTER_INIT operations: upstream's 10,000 (VENDOR.md change
    // 1, reverted), so a loop of 100,000 short iterations polls about ten times; at the fork's old 100, thousands.
    JS_SetInterruptHandler(rt, count_polls, NULL);
    v = eval(ctx, "for (var i = 0; i < 100000; i++) {}");
    CHECK(!qjs_is_exception(v));
    qjs_free_value(ctx, v);
    JS_SetInterruptHandler(rt, NULL, NULL);
    if (interrupt_polls < 5 || interrupt_polls >= 100) printf("  interrupt polls: %d\n", interrupt_polls);
    CHECK(interrupt_polls >= 5 && interrupt_polls < 100);

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("quickjs smoke: OK\n");
    return 0;
}
