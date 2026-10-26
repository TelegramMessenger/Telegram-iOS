// The native-path sweep (VENDOR.md local edit 2): every builtin function, called with large receivers and arguments
// (tests/native_sweep.js lists them), measured in wall time per unit of work against the reference loop. A call that
// is slow per unit, or that never reaches its budget, is a native path the work counter does not charge: with no clock
// behind the budget, that is an unbounded freeze. Run optimized, on a quiet machine:
//   ./build-input/bazel-9.2.0-darwin-arm64 test -c opt //third-party/quickjs-ng:QuickJSNativeSweep --test_output=all
// Each method's probes run in a child process of their own, so a call that hangs costs its child, not the sweep: it
// is reported, and the sweep goes on from the next probe.
#include "quickjs.h"
#include "qjs_shim.h"

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* Each probe runs to at most this many units: enough to measure its rate, ~50 ms at the reference. */
#define PROBE_BUDGET 5000000ull
/* A call still running after this is reported as a hang (an uncharged path never reaches its budget). */
#define ALARM_SECONDS 3
/* Reported: calls of at least MIN_NS whose time per unit is past CEILING_PER_UNIT times the reference. The floor is low:
   a call of a fraction of a millisecond that is barely charged is a freeze in a loop (String.prototype.normalize was
   missed at a 2 ms floor). The confirmation pass is what removes the noise a low floor lets in. */
#define CEILING_PER_UNIT 4.0
#define MIN_NS 2e5

static uint64_t limit;
static int stop(JSRuntime *rt, void *o) { (void)o; return JS_GetWorkUnits(rt) > limit; }
static double now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e9 + t.tv_nsec; }

static char *source;
static size_t source_len;

typedef struct {
    int32_t index;
    uint64_t units;
    double ns;
} Record;

static JSContext *open_driver(void) {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetMaxStackSize(rt, 4 << 20);
    JS_SetMemoryLimit(rt, 512 << 20);
    JSContext *ctx = JS_NewContext(rt);
    limit = UINT64_MAX;
    JS_SetInterruptHandler(rt, stop, NULL);
    JSValue v = qjs_eval(ctx, source, source_len, "native_sweep.js", false);
    if (qjs_is_exception(v)) {
        char *d = qjs_take_exception_description(ctx);
        fprintf(stderr, "native_sweep.js: %s\n", d ? d : "?");
        exit(2);
    }
    qjs_free_value(ctx, v);
    return ctx;
}

/* Calls the driver's global `name` with an index argument; returns its number result (or -1). */
static double call(JSContext *ctx, const char *name, int index, char **text) {
    JSValue fn = qjs_get_global_prop(ctx, name);
    JSValue arg = qjs_new_float64(ctx, index);
    JSValue r = qjs_call(ctx, fn, 1, &arg);
    double out = -1;
    if (qjs_is_exception(r)) {
        free(qjs_take_exception_description(ctx));
    } else if (text && qjs_is_string(r)) {
        const char *s = qjs_to_cstring(ctx, r);
        *text = strdup(s ? s : "");
        qjs_free_cstring(ctx, s);
    } else if (qjs_is_number(r)) {
        out = qjs_to_float64(ctx, r);
    }
    qjs_free_value(ctx, r);
    qjs_free_value(ctx, arg);
    qjs_free_value(ctx, fn);
    return out;
}

/* Child: runs probes [start, end), each `repeat` times, writing a Record per finished call to `fd`. Repeating in one
   child keeps a one-time cost (a lazily built table, the first GC over the cached values) out of the best run. */
static int repeat = 1;
static void run_range(int start, int end, int fd) {
    JSContext *ctx = open_driver();
    JSRuntime *rt = JS_GetRuntime(ctx);
    for (int n = 0; n < (end - start) * repeat; n++) {
        int i = start + n / repeat;
        limit = UINT64_MAX;
        alarm(ALARM_SECONDS);
        call(ctx, "__prepare", i, NULL);
        uint64_t u0 = JS_GetWorkUnits(rt);
        limit = u0 + PROBE_BUDGET;
        double t0 = now_ns();
        call(ctx, "__run", i, NULL);
        Record rec = { i, JS_GetWorkUnits(rt) - u0, now_ns() - t0 };
        alarm(0);
        if (write(fd, &rec, sizeof(rec)) != (ssize_t)sizeof(rec)) _exit(3);
    }
    _exit(0);
}

/* Runs probes [start, end) in children, a fresh one after each hang. Calls `on_record` for every finished call and
   `on_hang` for a call that never finished. */
static void run_probes(int start, int end, void (*on_record)(const Record *), void (*on_hang)(int index, int how)) {
    int next = start;
    while (next < end) {
        int fds[2];
        if (pipe(fds) != 0) { perror("pipe"); exit(2); }
        pid_t pid = fork();
        if (pid == 0) {
            close(fds[0]);
            run_range(next, end, fds[1]);
        }
        close(fds[1]);
        Record rec;
        int last = next - 1;
        while (read(fds[0], &rec, sizeof(rec)) == (ssize_t)sizeof(rec)) {
            last = rec.index;
            on_record(&rec);
        }
        close(fds[0]);
        int status = 0;
        waitpid(pid, &status, 0);
        if (WIFSIGNALED(status) || (WIFEXITED(status) && WEXITSTATUS(status) != 0)) {
            /* The call after the last one reported never finished (an alarm, or a crash): report it, go on after it. */
            on_hang(last + 1, WIFSIGNALED(status) ? WTERMSIG(status) : 1000 + WEXITSTATUS(status));
            next = last + 2;
        } else {
            next = end;
        }
    }
}

/* The cost suite's reference row: an arithmetic loop to 4M units, in ns per unit. */
static double reference_rate(void) {
    JSRuntime *rt = JS_NewRuntime();
    JSContext *ctx = JS_NewContext(rt);
    limit = UINT64_MAX;
    JS_SetInterruptHandler(rt, stop, NULL);
    const char *setup = "let s = 0;", *loop = "for (;;) s = (s + 1) | 0;";
    qjs_free_value(ctx, qjs_eval(ctx, setup, strlen(setup), "setup.js", false));
    uint64_t u0 = JS_GetWorkUnits(rt);
    limit = u0 + 4000000ull;
    double t0 = now_ns();
    JSValue v = qjs_eval(ctx, loop, strlen(loop), "reference.js", false);
    double ns = now_ns() - t0;
    uint64_t units = JS_GetWorkUnits(rt) - u0;
    qjs_free_value(ctx, v);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    return ns / (double)units;
}

static double reference;
static JSContext *names;
static int done, reported;
static double best_per, best_ns;
static uint64_t best_units;
static int hung_how;

static void print_name(int index) {
    char *name = NULL;
    call(names, "__name", index, &name);
    printf("  #%d %s\n", index, name ? name : "?");
    free(name);
    fflush(stdout);
}

static void screen_record(const Record *rec) {
    double per = rec->units ? rec->ns / (double)rec->units : rec->ns;
    if (++done % 20000 == 0) {
        fprintf(stderr, "... %d probes, %d reported\n", done, reported);
    }
    if (rec->ns >= MIN_NS && per > CEILING_PER_UNIT * reference) {
        reported++;
        printf("SLOW %8.1f ns/unit (%5.1fx) %9.1f ms %12llu units", per, per / reference, rec->ns / 1e6, (unsigned long long)rec->units);
        print_name(rec->index);
    }
}

static void screen_hang(int index, int how) {
    reported++;
    printf("HANG (signal/exit %d)", how);
    print_name(index);
}

static void confirm_record(const Record *rec) {
    double per = rec->units ? rec->ns / (double)rec->units : rec->ns;
    if (best_per == 0 || per < best_per) { best_per = per; best_ns = rec->ns; best_units = rec->units; }
}

static void confirm_hang(int index, int how) { (void)index; hung_how = how; }

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s native_sweep.js [k/n | --confirm i,j,...]\n", argv[0]);
        return 2;
    }
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 2; }
    fseek(f, 0, SEEK_END);
    source_len = (size_t)ftell(f);
    fseek(f, 0, SEEK_SET);
    source = malloc(source_len + 1);
    if (fread(source, 1, source_len, f) != source_len) { perror("read"); return 2; }
    source[source_len] = 0;
    fclose(f);

    reference = reference_rate();
    names = open_driver();
    int count = (int)call(names, "__count", 0, NULL);
    int methods = (int)call(names, "__methodCount", 0, NULL);

    if (argc >= 4 && strcmp(argv[2], "--confirm") == 0) {
        /* Each listed probe, three times in one child: the best of three, against the reference. */
        printf("reference %.2f ns/unit; confirming: best of 3 in one child, reported past %.1fx the reference per unit\n", reference, CEILING_PER_UNIT);
        int confirmed = 0;
        for (char *p = argv[3]; *p;) {
            int index = (int)strtol(p, &p, 10);
            if (*p == ',') p++;
            best_per = 0; best_ns = 0; best_units = 0; hung_how = 0;
            repeat = 3;
            run_probes(index, index + 1, confirm_record, confirm_hang);
            if (hung_how) {
                confirmed++;
                printf("HANG (signal/exit %d)", hung_how);
                print_name(index);
            } else if (best_ns >= MIN_NS && best_per > CEILING_PER_UNIT * reference) {
                confirmed++;
                printf("SLOW %8.1f ns/unit (%5.1fx) %9.1f ms %12llu units", best_per, best_per / reference, best_ns / 1e6, (unsigned long long)best_units);
                print_name(index);
            } else {
                printf("ok   %8.1f ns/unit (%5.1fx)", best_per, best_per / reference);
                print_name(index);
            }
        }
        return confirmed ? 1 : 0;
    }

    int shard = 0, shards = 1;
    if (argc >= 3) sscanf(argv[2], "%d/%d", &shard, &shards);
    printf("reference %.2f ns/unit; %d probes over %d methods; shard %d/%d; reported: >= %.0f ms at > %.1fx the reference per unit, or no end in %d s\n",
           reference, count, methods, shard, shards, MIN_NS / 1e6, CEILING_PER_UNIT, ALARM_SECONDS);
    fflush(stdout);
    for (int m = shard; m < methods; m += shards) {
        int start = (int)call(names, "__methodStart", m, NULL);
        int end = (int)call(names, "__methodStart", m + 1, NULL);
        run_probes(start, end, screen_record, screen_hang);
    }
    printf("shard %d/%d: %d calls measured, %d reported\n", shard, shards, done, reported);
    return reported ? 1 : 0;
}
