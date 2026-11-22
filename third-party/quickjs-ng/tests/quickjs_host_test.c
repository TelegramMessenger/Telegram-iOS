// Fork changes 3-12 (VENDOR.md): host auto-init properties, class prototypes on first use, string access, a host-class global object, host time and randomness, an uncatchable error through a Promise executor, a host hook at the memory limit, the host's stop, the loaded-module walks charged, no dumps without an explicit opt-in.
#include "quickjs.h"

#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures = 0;
#define CHECK(c) do { if (!(c)) { failures++; printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); } } while (0)

static int eval_int(JSContext *ctx, const char *code)
{
    JSValue v = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    int32_t r = -999;
    if (JS_IsException(v)) {
        JSValue e = JS_GetException(ctx);
        const char *s = JS_ToCString(ctx, e);
        printf("  exception in `%s`: %s\n", code, s ? s : "?");
        JS_FreeCString(ctx, s);
        JS_FreeValue(ctx, e);
    } else {
        JS_ToInt32(ctx, &r, v);
    }
    JS_FreeValue(ctx, v);
    return r;
}

static int autoinit_calls = 0;

static JSValue host_autoinit(JSContext *ctx, JSValueConst obj, JSAtom prop, void *opaque)
{
    autoinit_calls++;
    JSValue v = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, v, "tag", JS_NewInt32(ctx, (int32_t)(uintptr_t)opaque));
    return v;
}

static void define_lazy(JSContext *ctx, const char *name, int tag)
{
    JSValue g = JS_GetGlobalObject(ctx);
    JSAtom a = JS_NewAtom(ctx, name);
    CHECK(JS_DefineHostAutoInitProperty(ctx, g, a, (void *)(uintptr_t)tag, JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE) == 1);
    JS_FreeAtom(ctx, a);
    JS_FreeValue(ctx, g);
}

static void test_host_autoinit(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JS_SetHostAutoInitFunc(rt, host_autoinit);
    JSContext *ctx = JS_NewContext(rt);
    define_lazy(ctx, "Lazy", 7);
    define_lazy(ctx, "Gone", 8);
    define_lazy(ctx, "Over", 9);
    define_lazy(ctx, "Described", 10);
    CHECK(autoinit_calls == 0);

    // Presence and enumeration do not build anything: interface objects are not enumerable (WebIDL).
    CHECK(eval_int(ctx, "('Lazy' in globalThis) ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "Object.keys(globalThis).includes('Lazy') ? 1 : 0") == 0);
    CHECK(eval_int(ctx, "Object.getOwnPropertyNames(globalThis).includes('Lazy') ? 1 : 0") == 1);
    CHECK(autoinit_calls == 0);

    // The first read builds it, once; afterwards it is a plain data property.
    CHECK(eval_int(ctx, "Lazy.tag") == 7);
    CHECK(eval_int(ctx, "Lazy === Lazy ? Lazy.tag : 0") == 7);
    CHECK(autoinit_calls == 1);
    CHECK(eval_int(ctx, "var d = Object.getOwnPropertyDescriptor(globalThis, 'Lazy');"
                        "(d.writable && d.configurable && !d.enumerable && ('value' in d) && !('get' in d)) ? 1 : 0") == 1);

    // Deleting before the first read never builds it.
    CHECK(eval_int(ctx, "delete globalThis.Gone; ('Gone' in globalThis) ? 1 : 0") == 0);
    CHECK(autoinit_calls == 1);

    // Assigning over it leaves the assigned value (whether or not QuickJS built it first).
    CHECK(eval_int(ctx, "globalThis.Over = 5; Over") == 5);

    // Describing it builds it.
    int before = autoinit_calls;
    CHECK(eval_int(ctx, "Object.getOwnPropertyDescriptor(globalThis, 'Described').value.tag") == 10);
    CHECK(autoinit_calls == before + 1);

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

static JSClassID class_base, class_derived;
static int proto_init_calls = 0;

static JSValue proto_init(JSContext *ctx, JSClassID class_id)
{
    proto_init_calls++;
    if (class_id == class_derived) {
        JSValue parent = JS_GetClassProto(ctx, class_base);
        if (JS_IsException(parent))
            return JS_EXCEPTION;
        JSValue proto = JS_NewObjectProto(ctx, parent);
        JS_FreeValue(ctx, parent);
        JS_SetPropertyStr(ctx, proto, "kind", JS_NewInt32(ctx, 2));
        return proto;
    }
    JSValue proto = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, proto, "kind", JS_NewInt32(ctx, 1));
    return proto;
}

static JSValue proto_init_throws(JSContext *ctx, JSClassID class_id)
{
    return JS_ThrowTypeError(ctx, "no prototype");
}

static void test_class_proto_on_first_use(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JS_NewClassID(rt, &class_base);
    JS_NewClassID(rt, &class_derived);
    JSClassDef base_def = { .class_name = "Base" };
    JSClassDef derived_def = { .class_name = "Derived" };
    JS_NewClass(rt, class_base, &base_def);
    JS_NewClass(rt, class_derived, &derived_def);
    JS_SetClassProtoInitFunc(rt, proto_init);
    JSContext *ctx = JS_NewContext(rt);
    proto_init_calls = 0;

    // The first object of a class builds its prototype, and the parent's on the way.
    JSValue a = JS_NewObjectClass(ctx, class_derived);
    CHECK(!JS_IsException(a));
    CHECK(proto_init_calls == 2);
    JSValue b = JS_NewObjectClass(ctx, class_derived);
    CHECK(proto_init_calls == 2);
    JSValue pa = JS_GetPrototype(ctx, a), pb = JS_GetPrototype(ctx, b);
    CHECK(JS_VALUE_GET_PTR(pa) == JS_VALUE_GET_PTR(pb));
    JSValue proto = JS_GetClassProto(ctx, class_derived);
    CHECK(JS_VALUE_GET_PTR(proto) == JS_VALUE_GET_PTR(pa));
    JSValue kind = JS_GetPropertyStr(ctx, a, "kind");
    int32_t k = 0;
    JS_ToInt32(ctx, &k, kind);
    CHECK(k == 2);
    JS_FreeValue(ctx, kind);
    JS_FreeValue(ctx, proto);
    JS_FreeValue(ctx, pa);
    JS_FreeValue(ctx, pb);
    JS_FreeValue(ctx, a);
    JS_FreeValue(ctx, b);

    // A prototype the host set itself is used as is.
    JSClassID class_set = 0;
    JS_NewClassID(rt, &class_set);
    JSClassDef set_def = { .class_name = "Set" };
    JS_NewClass(rt, class_set, &set_def);
    JS_SetClassProto(ctx, class_set, JS_NewObject(ctx));
    int calls = proto_init_calls;
    JSValue c = JS_NewObjectClass(ctx, class_set);
    CHECK(proto_init_calls == calls);
    JS_FreeValue(ctx, c);

    // A failing init function makes the creation fail, and the slot stays empty for a later try.
    JSClassID class_bad = 0;
    JS_NewClassID(rt, &class_bad);
    JSClassDef bad_def = { .class_name = "Bad" };
    JS_NewClass(rt, class_bad, &bad_def);
    JS_SetClassProtoInitFunc(rt, proto_init_throws);
    JSValue d = JS_NewObjectClass(ctx, class_bad);
    CHECK(JS_IsException(d));
    JS_FreeValue(ctx, JS_GetException(ctx));
    JSValue p = JS_GetClassProto(ctx, class_bad);
    CHECK(JS_IsException(p));
    JS_FreeValue(ctx, JS_GetException(ctx));

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

static void test_string_access(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);

    JSValue ascii = JS_NewString(ctx, "hello");
    JSStringView view = { NULL, NULL, 0 };
    CHECK(JS_GetStringLength(ascii) == 5);
    CHECK(JS_GetStringView(ascii, &view) && view.latin1 && !view.utf16 && view.length == 5 && memcmp(view.latin1, "hello", 5) == 0);

    /* A lone surrogate survives the UTF-16 boundary. */
    const uint16_t units[] = { 'a', 0xD800, 'b' };
    JSValue wide = JS_NewStringUTF16(ctx, units, 3);
    CHECK(JS_GetStringLength(wide) == 3);
    CHECK(JS_GetStringView(wide, &view) && view.utf16 && view.utf16[1] == 0xD800);

    JSValue sub = JS_SubString(ctx, wide, 1, 3);
    CHECK(JS_GetStringLength(sub) == 2);
    CHECK(JS_GetStringView(sub, &view) && view.utf16 && view.utf16[0] == 0xD800 && view.utf16[1] == 'b');
    JSValue clamped = JS_SubString(ctx, ascii, 3, 99);
    CHECK(JS_GetStringLength(clamped) == 2);
    CHECK(JS_GetStringView(clamped, &view) && view.latin1 && memcmp(view.latin1, "lo", 2) == 0);
    JSValue empty = JS_SubString(ctx, ascii, 4, 2);
    CHECK(JS_GetStringLength(empty) == 0);

    /* A rope (built by +) has a length, no view, and flattens. */
    /* Distinguishable characters: char i is '0' + i % 10, so a wrong window reads wrong digits. */
    const char *src = "var s = ''; for (var i = 0; i < 600; i++) s += String.fromCharCode(48 + i % 10); s + s";
    JSValue rope = JS_Eval(ctx, src, strlen(src), "<test>", JS_EVAL_TYPE_GLOBAL);
    CHECK(JS_VALUE_GET_TAG(rope) == JS_TAG_STRING_ROPE);
    CHECK(JS_GetStringLength(rope) == 1200);
    CHECK(!JS_GetStringView(rope, &view));
    JSValue flat = JS_FlattenString(ctx, rope);
    CHECK(JS_GetStringView(flat, &view) && view.latin1 && view.length == 1200);
    CHECK(view.latin1[0] == '0' && view.latin1[1199] == '9' && view.latin1[603] == '3');
    JSValue ropeSub = JS_SubString(ctx, rope, 595, 605);
    CHECK(JS_GetStringLength(ropeSub) == 10);
    CHECK(JS_GetStringView(ropeSub, &view) && view.latin1 && memcmp(view.latin1, "5678901234", 10) == 0);

    /* 8-bit substring over 1024 bytes: above JS_STRING_SLICE_LEN_MAX, so it is a slice of its parent. */
    JSValue slice = JS_SubString(ctx, flat, 103, 1153);
    CHECK(JS_GetStringLength(slice) == 1050);
    CHECK(JS_GetStringView(slice, &view) && view.latin1 && view.length == 1050);
    CHECK(view.latin1[0] == '3' && view.latin1[1] == '4' && view.latin1[1049] == '2');
    /* A slice of a slice resolves against the original parent. */
    JSValue slice2 = JS_SubString(ctx, slice, 10, 1040);
    CHECK(JS_GetStringView(slice2, &view) && view.length == 1030 && view.latin1[0] == '3' && view.latin1[1029] == '2');

    /* 16-bit substring over 512 units (1024 bytes): also a slice. */
    uint16_t big[1300];
    for (int i = 0; i < 1300; i++)
        big[i] = 0x100 + (i % 10);
    JSValue bigWide = JS_NewStringUTF16(ctx, big, 1300);
    JSValue wideSlice = JS_SubString(ctx, bigWide, 101, 801);
    CHECK(JS_GetStringLength(wideSlice) == 700);
    CHECK(JS_GetStringView(wideSlice, &view) && view.utf16 && view.length == 700);
    CHECK(view.utf16[0] == 0x101 && view.utf16[1] == 0x102 && view.utf16[699] == 0x100 + 800 % 10);

    JSValue joined = JS_ConcatStrings2(ctx, ascii, sub);
    CHECK(JS_GetStringLength(joined) == 7);
    CHECK(JS_GetStringLength(ascii) == 5); /* not consumed or modified */
    CHECK(JS_GetStringView(ascii, &view) && memcmp(view.latin1, "hello", 5) == 0);

    CHECK(JS_GetStringLength(JS_NewInt32(ctx, 1)) == 0);
    JSValue notString = JS_FlattenString(ctx, JS_NewInt32(ctx, 1));
    CHECK(JS_IsException(notString));
    JS_FreeValue(ctx, JS_GetException(ctx));

    JS_FreeValue(ctx, wideSlice);
    JS_FreeValue(ctx, bigWide);
    JS_FreeValue(ctx, slice2);
    JS_FreeValue(ctx, slice);
    JS_FreeValue(ctx, ropeSub);
    JS_FreeValue(ctx, joined);
    JS_FreeValue(ctx, flat);
    JS_FreeValue(ctx, rope);
    JS_FreeValue(ctx, empty);
    JS_FreeValue(ctx, clamped);
    JS_FreeValue(ctx, sub);
    JS_FreeValue(ctx, wide);
    JS_FreeValue(ctx, ascii);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

static JSClassID class_global;
static int global_marks = 0;
static int global_finalized = 0;
static void *global_finalized_opaque = NULL;

static void global_mark(JSRuntime *rt, JSValueConst val, JS_MarkFunc *mark_func)
{
    global_marks++;
}

static void global_finalizer(JSRuntime *rt, JSValueConst val)
{
    global_finalized++;
    global_finalized_opaque = JS_GetOpaque(val, class_global);
}

static void test_global_object_class(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JS_NewClassID(rt, &class_global);
    JSClassDef def = { .class_name = "HostGlobal", .finalizer = global_finalizer, .gc_mark = global_mark };
    CHECK(JS_NewClass(rt, class_global, &def) == 0);
    JS_SetGlobalObjectClass(rt, class_global);
    JSContext *ctx = JS_NewContext(rt);
    JSValue global = JS_GetGlobalObject(ctx);

    /* The global is an instance of the host class, so it can carry a payload. */
    CHECK(JS_GetClassID(global) == class_global);
    static int marker = 42;
    CHECK(JS_SetOpaque(global, &marker) == 0);
    CHECK(JS_GetOpaque(global, class_global) == &marker);

    /* The intrinsics were installed on it as on a plain global: the class changes nothing scripts see. */
    CHECK(eval_int(ctx, "typeof Object === 'function' && typeof Array === 'function' && typeof JSON.stringify === 'function' ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "Math.max(2, 7)") == 7);
    CHECK(eval_int(ctx, "globalThis === this ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "var declared = 5; globalThis.declared") == 5);
    CHECK(eval_int(ctx, "function fn() { return 3; } globalThis.fn()") == 3);
    CHECK(eval_int(ctx, "undeclared = 9; globalThis.undeclared") == 9);
    CHECK(eval_int(ctx, "(() => { try { notDefinedAnywhere; return 0; } catch (e) { return e instanceof ReferenceError ? 1 : 0; } })()") == 1);
    CHECK(eval_int(ctx, "Object.getPrototypeOf(globalThis) === Object.prototype ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "typeof queueMicrotask === 'function' && typeof performance === 'object' ? 1 : 0") == 1);

    /* Its prototype can be replaced, as the host does with Window.prototype. */
    JSValue proto = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, proto, "fromProto", JS_NewInt32(ctx, 11));
    CHECK(JS_SetPrototype(ctx, global, proto) >= 0);
    CHECK(eval_int(ctx, "fromProto") == 11);
    JS_FreeValue(ctx, proto);

    /* The class hooks run: the collector marks through it, and freeing the context finalizes it with its payload. */
    int marks = global_marks;
    JS_RunGC(rt);
    CHECK(global_marks > marks);
    JS_FreeValue(ctx, global);
    JS_FreeContext(ctx);
    JS_RunGC(rt); /* the intrinsics' C functions hold context references, so only a GC finalizes the global */
    CHECK(global_finalized == 1);
    CHECK(global_finalized_opaque == &marker);

    /* 0 restores a plain global for contexts created afterwards. */
    JS_SetGlobalObjectClass(rt, 0);
    JSContext *plain = JS_NewContext(rt);
    JSValue plainGlobal = JS_GetGlobalObject(plain);
    CHECK(JS_GetClassID(plainGlobal) != class_global);
    CHECK(JS_SetOpaque(plainGlobal, &marker) == -1);
    CHECK(eval_int(plain, "Math.max(1, 4)") == 4);
    JS_FreeValue(plain, plainGlobal);
    JS_FreeContext(plain);
    CHECK(global_finalized == 1);
    JS_FreeRuntime(rt);
}

static void eval_str(JSContext *ctx, const char *code, char *out, size_t size)
{
    JSValue v = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    if (JS_IsException(v)) {
        JS_FreeValue(ctx, JS_GetException(ctx));
        snprintf(out, size, "<exception>");
        return;
    }
    const char *s = JS_ToCString(ctx, v);
    snprintf(out, size, "%s", s ? s : "<null>");
    JS_FreeCString(ctx, s);
    JS_FreeValue(ctx, v);
}

static double fake_wall_ms = 0;
static int fake_wall_calls = 0;

static double fake_wall_clock(void *opaque)
{
    CHECK(opaque == &fake_wall_calls);
    fake_wall_calls++;
    return fake_wall_ms;
}

static void test_wall_clock_and_random_seed(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JS_SetWallClockFunc(rt, fake_wall_clock, &fake_wall_calls);
    JSContext *ctx = JS_NewContext(rt);

    /* Date reads the host's clock: Date.now(), new Date() and Date() alike. */
    fake_wall_ms = 1767225600000.0; /* 2026-01-01T00:00:00Z */
    CHECK(eval_int(ctx, "Date.now() === 1767225600000 ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "new Date().getTime() === 1767225600000 ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "new Date().toISOString() === '2026-01-01T00:00:00.000Z' ? 1 : 0") == 1);
    CHECK(eval_int(ctx, "Date() === new Date(1767225600000).toString() ? 1 : 0") == 1);
    CHECK(fake_wall_calls >= 4);
    /* It moves when the host's clock moves, and a fraction is floored: a time value is whole milliseconds. */
    fake_wall_ms += 1500.75;
    CHECK(eval_int(ctx, "Date.now() - 1767225600000") == 1500);
    /* A clock that is not a time value reads as 0, never as garbage. */
    fake_wall_ms = NAN;
    CHECK(eval_int(ctx, "Date.now() === 0 ? 1 : 0") == 1);
    fake_wall_ms = 1e300;
    CHECK(eval_int(ctx, "Date.now() === 0 ? 1 : 0") == 1);
    /* NULL restores the system clock. */
    JS_SetWallClockFunc(rt, NULL, NULL);
    int before = fake_wall_calls;
    CHECK(eval_int(ctx, "Date.now() > 1700000000000 ? 1 : 0") == 1);
    CHECK(fake_wall_calls == before);

    /* Equal seeds give equal Math.random sequences, different seeds differ, and 0 is taken as 1. */
    JSContext *a = JS_NewContext(rt);
    JSContext *b = JS_NewContext(rt);
    char sa[256], sb[256];
    const char *draw = "[Math.random(), Math.random(), Math.random()].join()";
    JS_SetRandomSeed(a, 12345);
    JS_SetRandomSeed(b, 12345);
    eval_str(a, draw, sa, sizeof sa);
    eval_str(b, draw, sb, sizeof sb);
    CHECK(strcmp(sa, sb) == 0);
    JS_SetRandomSeed(a, 12345);
    JS_SetRandomSeed(b, 54321);
    eval_str(a, draw, sa, sizeof sa);
    eval_str(b, draw, sb, sizeof sb);
    CHECK(strcmp(sa, sb) != 0);
    JS_SetRandomSeed(a, 0);
    JS_SetRandomSeed(b, 1);
    eval_str(a, draw, sa, sizeof sa);
    eval_str(b, draw, sb, sizeof sb);
    CHECK(strcmp(sa, sb) == 0);
    /* Reseeding restarts the sequence. */
    JS_SetRandomSeed(a, 7);
    eval_str(a, draw, sa, sizeof sa);
    JS_SetRandomSeed(a, 7);
    eval_str(a, draw, sb, sizeof sb);
    CHECK(strcmp(sa, sb) == 0);

    JS_FreeContext(a);
    JS_FreeContext(b);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* Fork change 8: a handler that latches, as the native runtime's does (wr::Runtime::interrupt): once it said stop, it
   says stop for good. It says stop at its `limit`th call (one every JS_INTERRUPT_COUNTER_INIT polls, 10,000). */
static struct {
    uint64_t calls;
    uint64_t limit;
    int latched;
} stop_latch;

static void arm_stop_latch(uint64_t calls)
{
    stop_latch.latched = 0;
    stop_latch.calls = 0;
    stop_latch.limit = calls;
}

static int latching_interrupt(JSRuntime *rt, void *opaque)
{
    if (stop_latch.latched)
        return 1;
    if (++stop_latch.calls >= stop_latch.limit) {
        stop_latch.latched = 1;
        return 1;
    }
    return 0;
}

static void test_uncatchable_executor(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);

    /* The host's stop inside an executor is not the executor's exception to reject with: it propagates, and nothing
       after the constructor runs. stackTraceLimit 0: otherwise the backtrace's allocation re-arms the poll and stops
       the script by accident. */
    arm_stop_latch(20);
    JS_SetInterruptHandler(rt, latching_interrupt, NULL);
    const char *code = "Error.stackTraceLimit = 0; new Promise(() => { for (;;) {} }); globalThis.after = true";
    JSValue v = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    CHECK(stop_latch.latched);
    CHECK(JS_IsException(v));
    JSValue e = JS_GetException(ctx);
    CHECK(JS_IsUncatchableError(e));
    JS_FreeValue(ctx, e);
    JS_FreeValue(ctx, v);
    JS_SetInterruptHandler(rt, NULL, NULL);
    CHECK(eval_int(ctx, "globalThis.after === undefined ? 1 : 0") == 1);

    /* A catchable exception still rejects the promise, as the standard says. */
    CHECK(eval_int(ctx, "new Promise(() => { throw 5 }).catch(x => globalThis.reason = x); 1") == 1);
    JSContext *job_ctx;
    while (JS_ExecutePendingJob(rt, &job_ctx) > 0) {
    }
    CHECK(eval_int(ctx, "globalThis.reason") == 5);

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* Fork change 9: the host's hook for an allocation refused at the memory limit. */
static struct {
    JSRuntime *rt;
    int calls;
} limit_hook;

static void memory_limit_hook(JSRuntime *rt, void *opaque)
{
    CHECK(opaque == &limit_hook);
    CHECK(rt == limit_hook.rt);
    limit_hook.calls++;
}

/* A backing allocator that refuses every block over 1 MiB on its own, under no memory limit. */
static void *refusing_calloc(void *opaque, size_t count, size_t size)
{
    return count * size > (1 << 20) ? NULL : calloc(count, size);
}

static void *refusing_malloc(void *opaque, size_t size)
{
    return size > (1 << 20) ? NULL : malloc(size);
}

static void refusing_free(void *opaque, void *ptr)
{
    free(ptr);
}

static void *refusing_realloc(void *opaque, void *ptr, size_t size)
{
    return size > (1 << 20) ? NULL : realloc(ptr, size);
}

static void test_memory_limit_func(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    limit_hook.rt = rt;
    limit_hook.calls = 0;
    JS_SetMemoryLimitFunc(rt, memory_limit_hook, &limit_hook);
    JS_SetMemoryLimit(rt, 8 << 20);

    /* Allocations under the limit, growing and shrinking ones included, do not call it. */
    void *p = js_malloc_rt(rt, 100);
    void *q = js_calloc_rt(rt, 10, 100);
    CHECK(p && q);
    p = js_realloc_rt(rt, p, 4096);
    CHECK(p);
    p = js_realloc_rt(rt, p, 16);
    CHECK(p);
    CHECK(eval_int(ctx, "'x'.repeat(1 << 20).length") == 1 << 20);
    CHECK(limit_hook.calls == 0);

    /* Each allocation refused at the limit calls it once, before the allocator returns NULL: malloc, calloc and a
       growing realloc, whose block stays valid. */
    CHECK(js_malloc_rt(rt, 16 << 20) == NULL);
    CHECK(limit_hook.calls == 1);
    CHECK(js_calloc_rt(rt, 1, 16 << 20) == NULL);
    CHECK(limit_hook.calls == 2);
    CHECK(js_realloc_rt(rt, p, 16 << 20) == NULL);
    CHECK(limit_hook.calls == 3);
    js_free_rt(rt, p);
    js_free_rt(rt, q);
    /* A NULL that is not the limit's, calloc's size overflow, does not. */
    CHECK(js_calloc_rt(rt, SIZE_MAX / 2, 4) == NULL);
    CHECK(limit_hook.calls == 3);

    /* A script that passes the limit: the refusal calls it, and the script still sees QuickJS's out-of-memory error. */
    char s[64];
    eval_str(ctx, "try { 'x'.repeat(16 << 20); 'allocated' } catch (e) { e.message }", s, sizeof s);
    CHECK(strcmp(s, "out of memory") == 0);
    CHECK(limit_hook.calls == 4);

    /* NULL removes it: a refusal still returns NULL, and nothing is called. */
    JS_SetMemoryLimitFunc(rt, NULL, NULL);
    CHECK(js_malloc_rt(rt, 16 << 20) == NULL);
    eval_str(ctx, "try { 'x'.repeat(16 << 20); 'allocated' } catch (e) { e.message }", s, sizeof s);
    CHECK(strcmp(s, "out of memory") == 0);
    CHECK(limit_hook.calls == 4);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);

    /* The backing allocator's own NULL, with no memory limit, does not call it either. */
    static const JSMallocFunctions refusing = { refusing_calloc, refusing_malloc, refusing_free, refusing_realloc, NULL };
    rt = JS_NewRuntime2(&refusing, NULL);
    limit_hook.rt = rt;
    JS_SetMemoryLimitFunc(rt, memory_limit_hook, &limit_hook);
    CHECK(js_malloc_rt(rt, 2 << 20) == NULL);
    CHECK(js_calloc_rt(rt, 1, 2 << 20) == NULL);
    CHECK(limit_hook.calls == 4);
    JS_FreeRuntime(rt);
}

static int counted_polls = 0;

static int counting_interrupt(JSRuntime *rt, void *opaque)
{
    counted_polls++;
    return 0;
}

/* Calls `f` until the interrupt handler is asked: its poll counter then starts over from JS_INTERRUPT_COUNTER_INIT
   (10,000). A call of `f` allocates nothing, so it moves the counter by its own poll only. */
static void call_until_polled(JSContext *ctx, JSValueConst f)
{
    int before = counted_polls;
    for (int i = 0; i < 100000 && counted_polls == before; i++)
        JS_FreeValue(ctx, JS_Call(ctx, f, JS_UNDEFINED, 0, NULL));
    CHECK(counted_polls == before + 1);
}

/* Fork change 9: a refusal the hook sees makes every context's next interrupt poll ask the handler, not up to
   JS_INTERRUPT_COUNTER_INIT operations later. With no hook the refusal moves no poll. */
static void test_memory_limit_poll(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    const char *code = "(function () { return 0 })";
    JSValue f = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    CHECK(JS_IsFunction(ctx, f));
    JS_SetMemoryLimit(rt, 8 << 20);
    JS_SetInterruptHandler(rt, counting_interrupt, NULL);
    limit_hook.rt = rt;
    limit_hook.calls = 0;
    JS_SetMemoryLimitFunc(rt, memory_limit_hook, &limit_hook);

    call_until_polled(ctx, f);
    int polls = counted_polls;
    JS_FreeValue(ctx, JS_Call(ctx, f, JS_UNDEFINED, 0, NULL));
    CHECK(counted_polls == polls);
    CHECK(js_malloc_rt(rt, 16 << 20) == NULL);
    CHECK(limit_hook.calls == 1);
    /* The very next poll, the call's, asks the handler. */
    JS_FreeValue(ctx, JS_Call(ctx, f, JS_UNDEFINED, 0, NULL));
    CHECK(counted_polls == polls + 1);

    JS_SetMemoryLimitFunc(rt, NULL, NULL);
    call_until_polled(ctx, f);
    polls = counted_polls;
    CHECK(js_malloc_rt(rt, 16 << 20) == NULL);
    JS_FreeValue(ctx, JS_Call(ctx, f, JS_UNDEFINED, 0, NULL));
    CHECK(counted_polls == polls);

    JS_SetInterruptHandler(rt, NULL, NULL);
    JS_FreeValue(ctx, f);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* Fork change 10: the host's stop. */

/* Whether `code` ended with an exception (which is freed). */
static int eval_throws(JSContext *ctx, const char *code)
{
    JSValue v = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    int threw = JS_IsException(v);
    if (threw)
        JS_FreeValue(ctx, JS_GetException(ctx));
    JS_FreeValue(ctx, v);
    return threw;
}

/* Runs the pending jobs; how many ended with an exception (each freed). */
static int run_jobs(JSRuntime *rt)
{
    JSContext *job_ctx;
    int r, exceptions = 0;
    while ((r = JS_ExecutePendingJob(rt, &job_ctx)) != 0) {
        if (r < 0) {
            exceptions++;
            JS_FreeValue(job_ctx, JS_GetException(job_ctx));
        }
    }
    return exceptions;
}

/* The host's interrupt, once the loop inside the try has run 200,000 polls: it skips the catch and the finally. */
static void interrupt_inside_try(JSRuntime *rt, JSContext *ctx)
{
    arm_stop_latch(20);
    JS_SetInterruptHandler(rt, latching_interrupt, NULL);
    CHECK(eval_throws(ctx, "try { for (;;) {} } catch (e) { r++ } finally { r++ }"));
    CHECK(stop_latch.latched);
    JS_SetInterruptHandler(rt, NULL, NULL);
}

/* latching_interrupt, and the host's stop with it. */
static int stopping_interrupt(JSRuntime *rt, void *opaque)
{
    if (!stop_latch.latched && ++stop_latch.calls >= stop_latch.limit) {
        stop_latch.latched = 1;
        JS_SetStopped(rt);
    }
    return stop_latch.latched;
}

static int always_interrupt(JSRuntime *rt, void *opaque)
{
    return 1;
}

/* globalThis.stopWithNoMemory(): stops the runtime, leaves no memory for any allocation, and makes the next poll ask
   the handler (a refusal the hook sees, change 9), which says stop: that poll's error can only be bare null. */
static JSValue stop_with_no_memory(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSMemoryUsage usage;
    JS_SetStopped(rt);
    JS_ComputeMemoryUsage(rt, &usage);
    JS_SetMemoryLimit(rt, (size_t)usage.malloc_size);
    JS_SetInterruptHandler(rt, always_interrupt, NULL);
    limit_hook.rt = rt;
    JS_SetMemoryLimitFunc(rt, memory_limit_hook, &limit_hook);
    CHECK(js_malloc_rt(rt, 1) == NULL);
    return JS_UNDEFINED;
}

/* Each script adds 1 to `r` for every catch and finally that runs. */
static const char *const caught_throws[] = {
    "try { throw null } catch (e) { r++ }",
    "try { throw {} } catch (e) { r++ }",
    "try { throw 1 } finally { r++ }",
    "try { try { throw null } finally { r++ } } catch (e) { r++ }",
};

static void test_stopped(void)
{
    /* Unset, upstream's rules: what a script throws is caught and its finally runs; the interrupt's error skips both. */
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    CHECK(eval_int(ctx, "var r = 0; 1") == 1);
    CHECK(!eval_throws(ctx, caught_throws[0]) && !eval_throws(ctx, caught_throws[1]));
    CHECK(eval_throws(ctx, caught_throws[2]) && !eval_throws(ctx, caught_throws[3]));
    CHECK(eval_int(ctx, "r") == 5);
    interrupt_inside_try(rt, ctx);
    CHECK(eval_int(ctx, "r") == 5);
    /* A promise reaction's null rejects, and an async function's catch runs after its await. */
    CHECK(!eval_throws(ctx, "Promise.resolve().then(() => { throw null }).catch(() => { r++ });"
                            "(async () => { await 0; try { throw null } catch (e) { r++ } })()"));
    CHECK(run_jobs(rt) == 0);
    CHECK(eval_int(ctx, "r") == 7);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);

    /* Set: no catch or finally runs, whatever is thrown, the interrupt's error included. */
    rt = JS_NewRuntime();
    ctx = JS_NewContext(rt);
    CHECK(eval_int(ctx, "var r = 0; 1") == 1);
    JS_SetStopped(rt);
    for (size_t i = 0; i < sizeof caught_throws / sizeof caught_throws[0]; i++)
        CHECK(eval_throws(ctx, caught_throws[i]));
    interrupt_inside_try(rt, ctx);
    /* Nor in an async function, a promise reaction or a Promise executor (change 8's site): each exception propagates,
       out of its job or the script. */
    CHECK(eval_throws(ctx, "(async () => { try { throw null } catch (e) { r++ } })()"));
    CHECK(!eval_throws(ctx, "(async () => { await 0; try { throw null } catch (e) { r++ } })()"));
    CHECK(!eval_throws(ctx, "Promise.resolve().then(() => { throw null }).catch(() => { r++ })"));
    CHECK(run_jobs(rt) == 2);
    CHECK(run_jobs(rt) == 0);
    CHECK(eval_throws(ctx, "new Promise(() => { throw null }).catch(() => { r++ }); r++"));
    CHECK(run_jobs(rt) == 0);
    CHECK(eval_int(ctx, "r") == 0);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);

    /* The stop latched while an exception unwinds, in the return() of the for-of it leaves: the catch the unwinding was
       heading for does not run, although the exception was catchable when it was thrown (and is the one still
       pending: JS_IteratorClose drops return()'s). */
    rt = JS_NewRuntime();
    ctx = JS_NewContext(rt);
    CHECK(eval_int(ctx, "var r = 0; 1") == 1);
    arm_stop_latch(20);
    JS_SetInterruptHandler(rt, stopping_interrupt, NULL);
    CHECK(eval_throws(ctx, "try { for (const x of { [Symbol.iterator]() { return { next() { return { done: false } },"
                           " return() { for (;;) {} } } } }) throw 1 } catch (e) { r++ }"));
    CHECK(stop_latch.latched);
    JS_SetInterruptHandler(rt, NULL, NULL);
    CHECK(eval_int(ctx, "r") == 0);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);

    /* An async function that returns after the stop, when the poll of its resolve call throws bare null: upstream
       aborts the process there (an exception from resolving that is not uncatchable is a BUG); stopped, it propagates. */
    rt = JS_NewRuntime();
    ctx = JS_NewContext(rt);
    JSValue g = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, g, "stopWithNoMemory", JS_NewCFunction(ctx, stop_with_no_memory, "stopWithNoMemory", 0));
    JS_FreeValue(ctx, g);
    limit_hook.calls = 0;
    CHECK(eval_throws(ctx, "(async () => { stopWithNoMemory(); return 1 })()"));
    CHECK(limit_hook.calls >= 2);
    JS_SetInterruptHandler(rt, NULL, NULL);
    JS_SetMemoryLimitFunc(rt, NULL, NULL);
    JS_SetMemoryLimit(rt, 0);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* The host's handler once it has stopped the runtime: says stop, and counts. */
static int counting_stop_interrupt(JSRuntime *rt, void *opaque)
{
    counted_polls++;
    return 1;
}

/* Calls `f` with no arguments; whether it threw (the exception is freed). */
static int call_throws(JSContext *ctx, JSValueConst f)
{
    JSValue r = JS_Call(ctx, f, JS_UNDEFINED, 0, NULL);
    int threw = JS_IsException(r);
    if (threw)
        JS_FreeValue(ctx, JS_GetException(ctx));
    JS_FreeValue(ctx, r);
    return threw;
}

/* On a stopped runtime the poll site after the stop, and after each stop's throw, asks the handler again, whatever
   absorbed that exception (here the test itself). Error.stackTraceLimit 0 and the first stop's error kept alive make the next interrupt error small
   (its shape is cached), so its allocation alone does not cross the work check that would force that poll. */
static void test_stopped_next_poll(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    const char *code = "Error.stackTraceLimit = 0; [function () { for (;;) {} }, function () { return 0 }]";
    JSValue fns = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    JSValue loop = JS_GetPropertyUint32(ctx, fns, 0);
    JSValue f = JS_GetPropertyUint32(ctx, fns, 1);
    /* The stop itself, set outside any poll (as a host's native or memory hook does), makes the next poll site ask. */
    JS_SetInterruptHandler(rt, counting_interrupt, NULL);
    call_until_polled(ctx, f);
    JS_SetStopped(rt);
    JS_SetInterruptHandler(rt, counting_stop_interrupt, NULL);
    int stopped_at = counted_polls;
    CHECK(call_throws(ctx, f));
    CHECK(counted_polls == stopped_at + 1);

    JSValue r = JS_Call(ctx, loop, JS_UNDEFINED, 0, NULL);
    CHECK(JS_IsException(r));
    JSValue kept = JS_GetException(ctx);
    for (int i = 0; i < 3; i++) {
        int polls = counted_polls;
        CHECK(call_throws(ctx, loop));
        CHECK(counted_polls == polls + 1);
        /* The next poll site, a call that allocates nothing, asks the handler at once and throws. */
        CHECK(call_throws(ctx, f));
        CHECK(counted_polls == polls + 2);
    }

    JS_SetInterruptHandler(rt, NULL, NULL);
    JS_FreeValue(ctx, kept);
    JS_FreeValue(ctx, f);
    JS_FreeValue(ctx, loop);
    JS_FreeValue(ctx, fns);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* The global `name` as an int32, read without running script (-1 when it is not a number). */
static int32_t global_int(JSContext *ctx, const char *name)
{
    JSValue g = JS_GetGlobalObject(ctx);
    JSValue v = JS_GetPropertyStr(ctx, g, name);
    int32_t n = -1;
    if (JS_IsNumber(v))
        JS_ToInt32(ctx, &n, v);
    JS_FreeValue(ctx, v);
    JS_FreeValue(ctx, g);
    return n;
}

/* The interrupt's own error is built through Error.prepareStackTrace, which is JS. On a stopped runtime the poll is
   forced before that build, so the hook's first poll throws and it runs no iteration, at every stop's throw. */
static void test_stopped_prepare_stack_trace(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    const char *code = "var it = 0; Error.prepareStackTrace = () => { for (;;) it++ }; (function () { for (;;) {} })";
    JSValue loop = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_TYPE_GLOBAL);
    CHECK(JS_IsFunction(ctx, loop));
    arm_stop_latch(10);
    JS_SetInterruptHandler(rt, stopping_interrupt, NULL);
    for (int i = 0; i < 4; i++) {
        CHECK(call_throws(ctx, loop));
        CHECK(stop_latch.latched);
        CHECK(global_int(ctx, "it") == 0);
    }
    if (global_int(ctx, "it") != 0)
        printf("  Error.prepareStackTrace ran %d iterations after the stop\n", global_int(ctx, "it"));
    JS_SetInterruptHandler(rt, NULL, NULL);
    JS_FreeValue(ctx, loop);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* globalThis.dispose(), a disposer: counts its calls, and on call `stop_at` stops the runtime and throws, as a host's
   native does when it latches a stop. A call after that is counted too: none should come. */
static struct {
    int calls;
    int stop_at;
    int stopped;
    int after_stop;
    int polls_after_stop;
} disposer;

static JSValue counting_disposer(JSContext *ctx, JSValueConst this_val, int argc, JSValueConst *argv)
{
    disposer.calls++;
    if (disposer.stopped) {
        disposer.after_stop++;
        return JS_UNDEFINED;
    }
    if (disposer.calls == disposer.stop_at) {
        disposer.stopped = 1;
        JS_SetStopped(JS_GetRuntime(ctx));
        return JS_ThrowInternalError(ctx, "stopped");
    }
    return JS_UNDEFINED;
}

/* The host's handler: says stop once the disposer has stopped the runtime. */
static int disposer_interrupt(JSRuntime *rt, void *opaque)
{
    if (disposer.stopped)
        disposer.polls_after_stop++;
    return disposer.stopped;
}

/* Runs `code` (built while the runtime runs) and then `dispose_code` with the disposer set to stop the runtime on its
   `stop_at`th call: no disposer runs after it, and the disposal ends at the next poll at most. */
static void dispose_after_stop(const char *setup, const char *dispose_code, int stop_at)
{
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    JSValue g = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, g, "dispose", JS_NewCFunction(ctx, counting_disposer, "dispose", 0));
    JS_FreeValue(ctx, g);
    memset(&disposer, 0, sizeof disposer);
    disposer.stop_at = -1;
    CHECK(!eval_throws(ctx, setup));
    disposer.calls = 0;
    disposer.stop_at = stop_at;
    JS_SetInterruptHandler(rt, disposer_interrupt, NULL);
    CHECK(eval_throws(ctx, dispose_code));
    CHECK(disposer.stopped);
    CHECK(disposer.calls == stop_at);
    CHECK(disposer.after_stop == 0);
    CHECK(disposer.polls_after_stop <= 1);
    if (disposer.after_stop || disposer.polls_after_stop > 1)
        printf("  `%.40s`: %d disposers and %d handler calls after the stop\n", dispose_code, disposer.after_stop,
               disposer.polls_after_stop);
    JS_SetInterruptHandler(rt, NULL, NULL);
    /* The resources not disposed are released with their stack (an object leak asserts in JS_FreeRuntime). */
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
}

/* Fork change 10, disposal: on a stopped runtime the first disposer to throw ends the disposal, in a DisposableStack
   (js_dispose_resources, also through `using`) and in a scope's `using` declarations (OP_using_dispose). */
static void test_stopped_disposal(void)
{
    const char *stack = "var s = new DisposableStack(); for (let i = 0; i < 100000; i++) s.defer(dispose)";
    dispose_after_stop(stack, "s.dispose()", 1000);
    dispose_after_stop(stack, "{ using t = s; }", 1000);
    /* 1,000 declarations in one scope. */
    static char scope[16384];
    size_t n = (size_t)snprintf(scope, sizeof scope, "{ using a0 = d");
    for (int i = 1; i < 1000; i++)
        n += (size_t)snprintf(scope + n, sizeof scope - n, ", a%d = d", i);
    snprintf(scope + n, sizeof scope - n, "; }");
    dispose_after_stop("var d = { [Symbol.dispose]: dispose }", scope, 100);
}

/* Fork change 12: the dumps are compiled in only on an explicit -DTELEGRAM_QJS_ENABLE_DUMPS, never because NDEBUG is
   unset. With them every string carries a list link and the runtime a string list, so the memory limit's trip point
   and the GC thresholds moved with the build configuration. Without them both calls are no-ops
   (JS_SetDumpFlags keeps nothing, JS_GetDumpFlags answers 0), in this suite's default build as under -c opt. */
static void test_dumps_never_follow_ndebug(void)
{
    JSRuntime *rt = JS_NewRuntime();
    JS_SetDumpFlags(rt, ~(uint64_t)0);
    CHECK(JS_GetDumpFlags(rt) == 0);
    /* Had the dumps been compiled in, the flags would dump every leak and GC step at JS_FreeRuntime: off again. */
    JS_SetDumpFlags(rt, 0);
    JS_FreeRuntime(rt);
}

int main(void)
{
    test_host_autoinit();
    test_class_proto_on_first_use();
    test_string_access();
    test_global_object_class();
    test_wall_clock_and_random_seed();
    test_uncatchable_executor();
    test_memory_limit_func();
    test_memory_limit_poll();
    test_stopped();
    test_stopped_next_poll();
    test_stopped_prepare_stack_trace();
    test_stopped_disposal();
    test_dumps_never_follow_ndebug();
    if (failures) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("quickjs host: OK\n");
    return 0;
}
