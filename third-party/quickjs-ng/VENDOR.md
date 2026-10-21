# quickjs-ng (our fork)

**This is our fork of quickjs-ng (the user, 2026-10-16), not a pristine vendor copy.** Engine-level features
the message-widget runtime needs go here directly, each recorded below as a numbered change with what it does, why,
and the test that pins it. It started from quickjs-ng v0.17.0 plus a 40-line C shim (`shim/qjs_shim.c`,
`include/qjs_shim.h`), copied from widget-sandbox `packages/ios/Sources/CQuickJS` at commit 862eec8.
`git diff 55b3934a98 -- third-party/quickjs-ng/quickjs third-party/quickjs-ng/include` shows every change. Since M1d
the app ships no precompiled bytecode (the widget-sandbox `.qbc` bundles were deleted with the old runtime), so the
bytecode format is free to change; the `.qbc` notes in the changes below are history.

Built `-O2` in every configuration, debug included: message widgets run QuickJS with a 2 MB stack
limit, and a debug quickjs-ng spends ~10 KB of C stack per JS call (the old runtime's validator,
css-tree, recursed deeply; a widget's own script can too).

## Changes

Re-apply these after upgrading; `git diff 55b3934a98 -- third-party/quickjs-ng/quickjs` shows them.

1. **The interrupt poll every 100 operations** (2026-10-14, the message-widgets final review's R1).
   - What changed:
     - `quickjs/quickjs.c:556` (upstream's line) now sits inside `#ifndef JS_INTERRUPT_COUNTER_INIT … #endif`.
       That guard is the whole source change.
     - `BUILD`'s `quickjs_copts` sets `-DJS_INTERRUPT_COUNTER_INIT=100`. Upstream's value is 10,000.
     - The counter is runtime state, not part of the bytecode format, so the `.qbc` files are unaffected.
   - Why: QuickJS calls the interrupt handler only when a per-context counter, decremented per call entry
     and per backward jump, runs out. A message widget's 500 ms per-task deadline is read there (and before
     every host call, the old runtime's `QuickJSContext.admitsHostCall`). A loop of costly native builtins makes no host call
     and spends megabytes per operation:

     | loop | at upstream's 10,000 | at 100 |
     |---|---|---|
     | `for(;;) x = 'a'.repeat(1 << 22)` | stopped at 38.8 s | 0.62 s |
     | `for(;;) x = JSON.stringify(a)`, 200,000 numbers | stopped at 21.9 s | 0.58 s |

     (`LimitsTests`, the whole pipeline, a fresh iOS 26.5 simulator in a standalone process. The review's C
     driver measured 40.9 and 41.6 s at 10,000.)
   - Cost, through the real engine and its Swift interrupt closure (`ProcessInfo.systemUptime` per poll),
     medians of 7 runs, 10,000 vs 100, two rounds each:
     - pure-JS arithmetic, 10^7 iterations: 184-186 vs 189 ms (+2-3%);
     - 3×10^6 function calls: 75-79 vs 80 ms;
     - 10^6 string concatenations: 44 vs 45-46 ms;
     - boots of fixtures `01`-`05`: 26-31 ms either way, within noise; `09-chartjs-budget` 33-37 vs 31-35 ms.
   - Pinned by:
     - `tests/quickjs_smoke_test.c` (`:QuickJSSmokeTests`): a 100,000-iteration loop polls the handler at
       least 1,000 times (20 at 10,000, the RED run);
     - `MessageWidgetTests`' `LimitsTests.testRepeatLoopIsStoppedAtTheBudget` and
       `testStringifyLoopIsStoppedAtTheBudget`, in both executor modes.

2. **The work counter** (2026-10-15).
   Every limit on a widget's JavaScript is a count of work, never elapsed time; this is the count.
   - What changed (`git grep -n "local edit 2" third-party/quickjs-ng` lists every site):
     - `include/quickjs.h`: `JS_GetWorkUnits`, `JS_ChargeWork` and the rate macros `JS_WORK_ALLOC_SHIFT`,
       `JS_WORK_SCAN_SHIFT`, `JS_WORK_REGEX_UNITS`, `JS_WORK_CHECK_PERIOD` (each `#ifndef`-guarded).
     - `quickjs.c`: three `JSRuntime` fields (`work_units`, `work_alloc_bytes`, `work_next_check`); the two
       functions, after `JS_ThrowInterrupted`; `__js_poll_interrupts` charges `JS_INTERRUPT_COUNTER_INIT` per
       handler call (one unit per poll); `js_calloc_rt`, `js_malloc_rt` and `js_realloc_rt` charge the bytes they
       are asked for (there, not in the pluggable `JSMallocFunctions`, which allocations up to
       `JS_ARENA_MAX_SMALL_SIZE` never reach); `lre_check_timeout` charges `JS_WORK_REGEX_UNITS` per call (one
       every 10,000 regex steps).
     - Work that the interpreter does not see is charged where it happens, in elements visited
       (`JS_WORK_SCAN_SHIFT`): string search (`string_indexof`, which now takes the context, and the
       `indexOf`/`lastIndexOf`/`includes`/`startsWith`/`endsWith` loops, charged per character compared, so they
       stop partway), array `includes`/`indexOf`/`lastIndexOf` fast paths (per element), and up front for
       `fill`, `copyWithin`, `reverse`, typed-array `fill`/`set`/`reverse`/`indexOf`/`sort` (len·log2 len),
       `ArrayBuffer.slice`, BigInt multiplication (limb product), `JSON.parse` (input), `localeCompare`, relational
       string comparison, the sort comparator (one per comparison plus the strings compared) and every
       evaluation of source (`__JS_EvalInternal`). Where no exception can be raised — `===`/`==` on strings
       (`js_strict_eq2`), atoms made from strings (`JS_NewAtomStr`) and allocation — the charge makes every
       context's next poll ask the handler (`js_request_work_check`), counting the polls made so far
       (`JSContext.work_poll_reset`), so a forced poll does not double-count.
     - Added by the final review (2026-10-15), each a path that let one line of script run for hours once no clock
       backstopped the budget: `trim`/`trimStart`/`trimEnd` and `isWellFormed` (by length, up front);
       `JS_ToCStringLen2` (by length, deferred: an ASCII string comes back uncopied, so `Number()`/`parseInt`/
       `parseFloat` skipped 4 MB of spaces for free); `map_hash_key` (by the key's length, ropes included, deferred:
       every lookup, insertion, rehash and set operation); prototype walks (`js_charge_hop`: a unit per object past
       the first `JS_WORK_FREE_HOPS` = 16, deferred, in `JS_GetPropertyInternal`, `JS_HasProperty`,
       `JS_SetPropertyInternal2`, `JS_OrdinaryIsInstanceOf`, `JS_SetPrototypeInternal`'s cycle check and the three
       interpreter inline lookups); BigInt division and remainder (limb product) and decimal conversion both ways
       (limbs squared), up front; generic element loops (`JS_WORK_ELEMENT_UNITS` = 4 per index: `join`,
       `JS_CopySubArray` behind `shift`/`unshift`/`splice`, `slice` and `splice`'s deletions, `sort`'s collection,
       spreadable `concat`, `flat`, `Array.from` and `TypedArray.from` of an array-like, typed-array construction from
       one, `String.raw`, `JSON.stringify` of an array and of a replacer array).
     - libregexp gained two user callbacks (`libregexp.h`): `lre_charge_steps` — an exec charges, when it returns, the
       steps it made since its last `lre_check_timeout`, which comes only every `LRE_STEP_PERIOD` (10,000) steps, so a
       short exec had been free (`r.exec` on 4,500 characters ran 302× the reference) — and `lre_charge_work`, which
       charges a character class's merges as they happen (each atom merges into every range so far: 80,000 ranges took
       5.7 s in one call) and fails the compile with `LRE_INTERRUPTED_MESSAGE`, which `js_compile_regexp` turns into the
       uncatchable interrupt rather than a `SyntaxError`.
     - Added by the native-path sweep (2026-10-15, below): `Array.prototype.fill` on a generic receiver is charged and
       checked per element, not once up front (a typed array converts the value on every set, a 1 MB string each time:
       12 s past its budget); `replace`/`replaceAll` charge each match what it builds and stop on a failed append (an
       empty pattern matches at every position: a 1 MB replacement over a 1 MB string never returned); every step of an
       iterator driven from C (`JS_IteratorNext2`: `Array.from`, `new Map`/`Set`, `Object.fromEntries`, the iterator
       helpers, `Promise.all`, `Math.sumPrecise` — 36 ms of a 4M typed array for 59 units) is an element; each step of a
       Set method's loop is `JS_WORK_SET_ELEMENT_UNITS` = 24 (an iterator step, a lookup and a call of a set-like's
       `has` from C, ~200 ns); generic `reverse` charges two elements per pair and typed-array `set` from an array-like
       one per element, each checked in the loop (the up-front scan charge stays the fast paths'); `localeCompare`
       charges three units per character and `normalize` two (lone surrogates, normalized one at a time, ran 3-4x the
       reference); and a string search charges the compare that matched, not only the ones that failed (`indexOf`,
       `includes`, `startsWith`, `split` of a 1 MB string by an equal one charged 5 units for 0.7 ms).
     - Two leaks the interrupt made reachable are fixed: `js_relational_slow` freed neither operand when its charge
       stopped it (a page-sized string leaked per kill), and `js_bigint_pow` dropped its partial result when a charged
       multiply failed.
     - The counter is runtime state, not part of the bytecode format: the `.qbc` files are unaffected.
   - Calibration (`tests/quickjs_work_cost_test.c`, `:QuickJSWorkCostTests`, run with `-c opt`; each attack has 20 s
     to reach its budget, so an uncharged path fails rather than hangs the suite): every attack runs
     its setup unbudgeted, then to 4,000,000 units; it fails past 2× the reference row's time per unit, or past 2.5×
     the time the budget is worth at the reference rate (an operation that works on past its budget without a check).
     The rates that pass: `JS_WORK_ALLOC_SHIFT` 2 (a builder like `repeat` writes about 2.6 ns per output byte),
     `JS_WORK_SCAN_SHIFT` 3, `JS_WORK_REGEX_UNITS` 6000, a unit per token in both parsers and per `split` piece, one
     per element for `Array.prototype.fill` (it sets through the generic property path; charged and checked per element),
     four per proxy trap. On
     Apple M5 Max, optimized, 2026-10-15 (rows from "trim" on added by the final review):

     attack                            units         ms    ns/unit  × budget
     reference: arithmetic loop      4000155       37.5       9.38       1.00
     calls                           4000150       28.8       7.20       0.77
     repeat 4 MB                     4195080       32.1       7.66       0.86
     padStart 4 MB                   4195101       21.6       5.14       0.57
     concat                          4000139        6.0       1.51       0.16
     join                            4000202        4.4       1.11       0.12
     split                           4000190        4.8       1.20       0.13
     spread                          7466665        5.3       0.71       0.14
     stringify                       4360922        6.9       1.59       0.18
     parse                           5197116        5.4       1.04       0.14
     indexOf pathological            4000198       22.5       5.63       0.60
     string equality                 4194963        0.7       0.16       0.02
     localeCompare                   8913595       10.2       1.15       0.27
     array indexOf                   4000156       15.7       3.91       0.42
     array fill                      4194945        7.9       1.88       0.21
     sort strings                    4002001        6.1       1.52       0.16
     sort comparator                 4491852       10.4       2.31       0.28
     typed fill                      4195001        0.2       0.05       0.01
     typed indexOf                   4195008        0.5       0.11       0.01
     typed sort                      4358807        2.8       0.64       0.07
     typed set                       4195042        0.4       0.09       0.01
     bigint mul                      4270743       21.5       5.04       0.57
     regex backtracking              4005127       33.8       8.44       0.90
     Function source                 4000399        4.7       1.18       0.13
     long property keys              4064066        1.0       0.24       0.03
     deep recursion                  4000380       44.4      11.10       1.18
     gc pressure                     4000237        2.9       0.72       0.08
     proxy traps                     4000188       17.3       4.33       0.46
     trim                            4194968       20.5       4.89       0.55
     isWellFormed                    4194983       14.6       3.49       0.39
     Number of spaces                4194912       20.5       4.88       0.55
     parseFloat of spaces            4194912       19.2       4.58       0.51
     Map long key                    4195016       31.3       7.45       0.83
     Map rope key                    4195021       31.3       7.46       0.83
     prototype chain get             4100035       18.4       4.50       0.49
     prototype chain in              4100075       25.9       6.32       0.69
     prototype chain instanceof      4000225       16.6       4.15       0.44
     short regex exec                4001229       13.5       3.38       0.36
     short regex test                4004025       13.4       3.34       0.36
     bigint div                      4434523       29.6       6.66       0.79
     bigint mod                      4420771       29.6       6.68       0.79
     bigint toString                 4663355       45.9       9.84       1.22
     BigInt from string              5063746        7.4       1.47       0.20
     generic join                    4000169        6.9       1.72       0.18
     generic shift                   4000247       17.7       4.43       0.47
     generic slice                   4000199       13.6       3.40       0.36
     generic sort                    4000176       13.4       3.35       0.36
     spreadable concat               4000149       14.5       3.61       0.39
     sparse flat                     4000209       23.5       5.87       0.63
     sparse stringify                4197176       11.1       2.63       0.29
     typed from array-like           4000216        5.8       1.46       0.16
     regex class compile             4000359        1.9       0.47       0.05
     reference 9.38 ns/unit = 106620 units/ms
   - The hosts set their budgets against that reference (a sandbox widget's boot 48,000,000 ≈ 480 ms and each later
     task 28,000,000, with the parse of its markup not charged but under a 400,000,000 ceiling; a bundled library's
     first install 4,000,000: the root
     `CLAUDE.md`, "Message widgets") and charge their own work, which this suite cannot reach: a base per host
     call, the argument bytes, a query's bytes, the documents the renderer builds. Their calibration is the same rule
     (at most 2× the reference row's time per unit), run in the iOS test bundles against this same loop. The counter
     carries no reference rate of its own: the hosts' DEBUG tripwires measure this loop in the build they run in.
   - **The native-path sweep** (`tests/quickjs_native_sweep_test.c` + `tests/native_sweep.js`, `:QuickJSNativeSweep`,
     manual, optimized: `./build-input/bazel-9.2.0-darwin-arm64 test -c opt //third-party/quickjs-ng:QuickJSNativeSweep
     --test_output=all`, or the binary with `k/n` for a shard and `--confirm i,j,…`). Instead of guessing which
     natives escape the counter, it calls every function reachable from the global object (statics, prototype methods
     with string and symbol keys, getters, iterator prototypes, the constructors called and constructed: 659 methods)
     with every receiver and argument list from a set of large values (1 MB strings, lone surrogates, a 2 MB rope,
     128K-element and holey and sparse arrays, 2^40-length array-likes, 4M typed arrays, 64K Maps and Sets, a 100K
     prototype chain, big BigInts, a 4K-range regex class): 1,040,760 calls, each to a 5M-unit budget, each method in a
     forked child with a 3 s alarm, so a call that never returns is reported and the sweep goes on. A call of at least
     0.2 ms past 4x the reference per unit, or a hang, is reported; reports are rerun three times in one child (one-time
     costs, GC pauses and scheduling noise drop out) before they count. Its runs on 2026-10-15 confirmed 16 natives,
     all fixed above with a cost-suite row each (`normalize` was found beside `localeCompare`, by reading); the first
     run's 2 ms floor missed the sub-millisecond ones (the matched compare). After the fixes it confirms nothing: 599
     calls flagged in screening, all cleared by the reruns. Rerun it after a QuickJS upgrade or a new native, and on a
     quiet machine: it measures wall time.
   - Pinned by `tests/quickjs_work_test.c` (`:QuickJSWorkTests`): the same script spends the same units twice,
     allocation and regex steps are charged, a loop or catastrophic regex is stopped at its budget, and each
     charged builtin, called once with a budget under its work, is stopped (26 cases).

3. **Host auto-init properties** (2026-10-16, the native runtime's interface objects, `docs/message-widgets-native-runtime.md`).
   - What: `JS_DefineHostAutoInitProperty` defines a property in QuickJS's own auto-init state with a fifth kind,
     `JS_AUTOINIT_ID_HOST`, whose value the runtime's `JSHostAutoInitFunc` makes on first read.
     Contract: the function must not define or remove any property of `obj` and must not read the property being
     made (that re-enters the build and corrupts memory; no runtime guard, to leave upstream's path alone for the four
     existing kinds). Reading other properties of `obj` is safe. The auto-init tag
     in `JSProperty.u.init.realm_and_id` grew from two bits to three (the four upstream kinds used all of two).
   - Why: a widget gets ~80 DOM interface objects on its global without building any until used; scripts see
     ordinary data properties (`getOwnPropertyDescriptor`, `in`, enumeration), unlike an accessor.
   - Pinned by `tests/quickjs_host_test.c` (`:QuickJSHostTests`), `test_host_autoinit`.

4. **Class prototypes on first use** (2026-10-16, spec section 6.2).
   - What: `JS_SetClassProtoInitFunc`. `JS_NewObjectClass` and `JS_GetClassProto` (through `js_class_proto`) ask the
     runtime's function for a host class's prototype the first time the context's slot is still null; the result
     is kept in `ctx->class_proto[id]`. Built-in classes (`< JS_CLASS_INIT_COUNT`) are untouched.
     Contract: the function must not ask for the prototype of the class it is making (re-entry, no guard); the
     parent's is the intended pattern.
   - Why: a DOM wrapper of a class whose interface no script has touched yet gets its prototype (and the parent
     chain) built then, so creating a context builds no DOM prototypes at all.
   - Pinned by `tests/quickjs_host_test.c`, `test_class_proto_on_first_use`.

5. **String access for the DOM** (2026-10-16, spec sections 4 and 6).
   - What: `JS_GetStringLength`, `JS_FlattenString`, `JS_GetStringView` (the latin1 or UTF-16 characters of a flat
     string, no copy), `JS_SubString` (UTF-16 offsets, clamped), `JS_ConcatStrings2` (non-consuming).
   - Why: the DOM keeps text, attribute values and names as QuickJS strings (so they count toward the widget's
     memory and cost nothing to hand back to script) and needs UTF-16 offsets (`substringData`, `splitText`) and
     allocation-free reads (selector matching, serialization) that the public API did not offer.
   - Pinned by `tests/quickjs_host_test.c`, `test_string_access`.
6. **A host-class global object** (2026-10-17, the native runtime's `Window`, M1b plan Ruling 1).
   - What: `JS_SetGlobalObjectClass(rt, class_id)`. `JS_AddIntrinsicBasicObjects` makes `ctx->global_obj` an object
     of that class (a host class registered with `JS_NewClass`) instead of `JS_CLASS_OBJECT`. Its `[[Prototype]]` is
     still `Object.prototype`. The intrinsics install on it unchanged: every installer only defines properties on
     `ctx->global_obj`, and none reads its class. 0, the default, keeps upstream's plain object. A built-in or
     unregistered class aborts.
   - Why: WebIDL's global object is a platform object (`Window`). `JS_SetOpaque` refuses built-in classes, so a plain
     global could not carry the Window payload, and every brand check on `window`, or on an undefined `this`, would
     fail.
   - Pinned by `tests/quickjs_host_test.c`, `test_global_object_class`. It checks that the global's class, opaque,
     `gc_mark` and finalizer work, that the intrinsics work on such a global, and that 0 restores a plain one.
7. **Host time and randomness** (2026-10-17, the native runtime's deterministic mode, spec section 8, M1b plan
   Ruling 2).
   - What:
     - `JS_SetWallClockFunc(rt, func, opaque)`: `date_now()` (`Date.now()`, `new Date()`, `Date()`) reads the host's
       function instead of `js__gettimeofday_us()`. The value is floored, and one that is not finite or is outside
       the time value range reads as 0. `NULL` restores the system clock.
     - `JS_SetRandomSeed(ctx, seed)`: restarts `Math.random`'s xorshift state (0 is taken as 1).
     - `ctx->hash_seed`, which is derived from the state at context creation, is left alone. Changing it would break
       every existing Map and Set, and XOR with a constant keeps every bucket collision, so nothing observable
       depends on it.
   - Why: in the native runtime's test mode a whole widget run (time, randomness, budgets) must repeat exactly. The
     runtime gives `Date` the host's clock and seeds `Math.random` from its options (`wr::Runtime::create`).
   - Pinned by `tests/quickjs_host_test.c`, `test_wall_clock_and_random_seed`.
8. **An uncatchable error through a Promise executor** (2026-10-17, the native runtime's stop latch, M1b plan Global
   Constraints "Stops are final"; Task 5 fix round 1, ruling R2).
   - What: `js_promise_constructor` returns the exception, still pending, when the executor ends with an uncatchable
     error, instead of rejecting the new promise with it. That is what `js_async_function_resume` and
     `promise_reaction_job` already do. A catchable exception still rejects, as the standard says.
   - Why: the host stops a widget with QuickJS's uncatchable "interrupted" (local edit 2's interrupt handler). The
     constructor caught it like any exception, so `new Promise(() => { for (;;) {} }); after()` ran `after()` after
     the stop, and `JS_Eval` returned success on a stopped runtime.
   - Left alone: other places that turn an exception from user code into a rejection keep upstream's behaviour. They
     are the thenable job, the async generator's resume and `completed_return`, the resolve function's `then` read,
     `Promise.try`, the `all`/`allSettled`/`any`/`race` iteration, the async-from-sync iterator, `AsyncDisposableStack`
     disposal and dynamic `import()`. Once the host has stopped the runtime, change 10 bounds such a frame: it runs on
     at most to the next poll site, which throws again. The runtime also checks its latch after every call into JS
     returns (`wr::Runtime::leaveScript`, `runScript`).
   - Pinned by `tests/quickjs_host_test.c`, `test_uncatchable_executor`. A latching handler stops
     `new Promise(() => { for (;;) {} })`. The test checks that `JS_Eval` returns an uncatchable exception, that the
     statement after it never ran, and that a catchable throw from an executor still rejects.
9. **A host hook at the memory limit** (2026-10-17, the native runtime's stop latch, M1b plan Global Constraints "Stops
   are final"; inserted Task 12a).
   - What: `JS_SetMemoryLimitFunc(rt, func, opaque)`. `js_malloc_rt`, `js_calloc_rt` and `js_realloc_rt` call
     `func(rt, opaque)` each time their `malloc_limit` check refuses an allocation, just before they return NULL
     (`js_memory_limit_refused`). Those three checks are where the limit is enforced, and every allocation it counts
     goes through one of them (`js_malloc` and its kin, the arena behind them, libregexp's `lre_realloc`, a host's
     `js_malloc_rt`). A NULL for another reason does not call it: the backing allocator's own failure, `js_calloc_rt`'s
     size overflow.
     - A shrinking realloc is refused too, and calls the hook, when the usage is already past the limit: the check
       compares requests with the limit, while the usage it counts is each block's usable size plus `MALLOC_OVERHEAD`,
       so the usage can pass the limit by a block's slack. That is a refusal at the limit like any other, so it is not
       gated on `size > old_size`.
     - After the hook, every context's next interrupt poll asks the handler at once (`js_request_work_check`, local
       edit 2's forced poll, with its unit accounting), not up to `JS_INTERRUPT_COUNTER_INIT` operations later, so a stop
       the hook latched lands at the next poll site. Only when a hook is set.
     - Contract: there is no context. It runs inside the allocation, from the middle of any engine operation (a GC, a
       parse, building an error), so it must not allocate, run JS, throw or call into QuickJS.
     - Unset (the default; NULL removes it) the allocator is upstream's: the field is read only on the refusal path.
   - Why: at the limit QuickJS throws an ordinary, catchable `InternalError: out of memory`, or bare `null` when it
     cannot even build that error (`JS_ThrowError2`), and a promise turns either into a rejection. So a script could
     catch running out of memory and go on, and the bare `null` could not be told from a script's own `throw null`.
     The native runtime's hook latches its Memory stop (`wr::Runtime::memoryLimitRefused`); its interrupt handler then
     says stop at the next poll, whatever was thrown. Bare `null` stays an ordinary exception: the latch, not the value,
     says the widget ran out of memory.
   - The residual this left, closed by change 10: the next poll's stop is an error object too (`JS_ThrowInterrupted`),
     and bare `null` when the refusal left too little memory to build it, so a `try` around the polling code caught
     every poll. Measured (Task 12a, the 160 KB-array loop at 64 limits around 32 MiB): at one limit,
     `for (let i = 0; i < 1000000; i++) { try { for (;;) {} } catch (e) {} }` caught all 1,000,000 polls after the latch
     and ran to its end (126M units past a 50M-unit budget); an outer `for (;;)` never ended.
   - Pinned by `tests/quickjs_host_test.c`, `test_memory_limit_func`: each refusal at the limit (malloc, calloc, a
     growing realloc, a script's `repeat`) calls the hook exactly once with its runtime and opaque, an allocation
     under the limit (growing and shrinking included) never does, nor calloc's overflow or a backing allocator's own
     NULL, and with the hook removed a refusal still returns NULL and the script still reads `out of memory`.
     `test_memory_limit_poll`: after a refusal the hook saw, the very next poll (a call's) asks the handler; with no
     hook a refusal moves no poll. The native runtime's `RuntimeHookTests` pin the stop
     (`testOutOfMemoryStopsAtEveryLimit`, `testOutOfMemoryCannotBeCaught`, `testOutOfMemoryInAPromiseStops`,
     `testAScriptsOwnThrowNullIsCatchable`).
10. **The host's stop: nothing is catchable once it is set** (2026-10-17, the native runtime's stop latch, M1b plan
    Global Constraints "Stops are final"; Task 12a fix rounds 1 to 3).
    - What: `JS_SetStopped(rt)` sets a per-runtime flag (`JSRuntime.stopped`) that nothing clears. While it is set, the
      one internal test of whether the pending exception escapes every catch, `js_is_uncatchable_exception(rt)`
      (`rt->stopped || JS_IsUncatchableError(rt->current_exception)`), answers yes for any exception, whatever was
      thrown. It allocates nothing, runs no JS and cannot fail, so a host can call it from its interrupt handler and its
      memory-limit hook (change 9). The flag is runtime state, not part of the bytecode format: the `.qbc` files are
      unaffected.
    - Every place that decides whether a pending exception can be caught goes through that test
      (`git grep -n "fork change 10" third-party/quickjs-ng/quickjs` lists them):
      - the interpreter's `exception:` unwinding in `JS_CallInternal`: catch, finally (both are catch offsets) and the
        close of a for-of iterator the exception leaves; sync generators and async functions run their bodies through
        it, and a generator's `throw()` enters it;
      - inside that unwinding, right after `JS_IteratorClose`: the iterator's `return()` runs JS and can latch the stop
        after the test above said catchable, and `JS_IteratorClose` keeps the exception it was closing with (dropping
        `return()`'s, the interrupt included), so the loop stops looking for a catch once the flag is set. It tests the
        flag alone: the exception still pending is the one the test above decided on;
      - `js_async_function_resume`: the body's exception (propagated rather than rejected with), and an exception from
        calling its resolve or reject function, which upstream answers with `abort()` unless it is uncatchable. That
        happens on a stopped runtime when the call's poll cannot build the interrupt's error and throws `null`;
      - `promise_reaction_job`;
      - `js_promise_constructor`, change 8's site;
      - the two disposal loops, which call every remaining disposer and collect their exceptions into a
        SuppressedError (or keep the bare exception when that cannot be built) without asking: `js_dispose_resources`
        (`DisposableStack.prototype.dispose`, and through it a `using` of a stack) and `OP_using_dispose` (a scope's
        `using` declarations, one opcode per declaration). On a stopped runtime the first disposer to throw ends the
        disposal with its exception pending. The resources a stack did not reach stay counted in it
        (`resource_count`), so `js_disposable_stack_clear` releases them with the stack; a scope's variables and its
        error state go with the frame. These test the flag alone, like the iterator close: unset, the loops are
        upstream's. Before this a stack of 100,000 `defer`s disposed after a stop at its 1,000th disposer ran 19.5M
        units past the stop (each remaining disposer throwing at its call's poll and being collected), and a scope of
        1,000 declarations 99K.
      `JS_IsUncatchableError` itself is public and takes only a value, so it cannot see a runtime's flag; it still
      answers for the value alone. Nothing in the engine asks it about the pending exception any more, and the native
      runtime's classifier reads its own latch before it (`wr::Runtime::classifyFatal`).
    - Every poll site throws once stopped: `JS_SetStopped` itself, and on a stopped runtime `JS_ThrowInterrupted` (the
      interrupt's throw from a poll, a charge, a regex step check or a regex compile), make every context's next poll
      ask the handler at once (`js_request_work_check`, local edit 2's forced poll with its accounting: each such poll
      counts one unit). `JS_ThrowInterrupted` requests it before it builds its error, because building an error can call
      `Error.prepareStackTrace`, which is JS: that call's first poll throws too. The host's handler says stop at every
      poll, so from the stop on every poll site throws, the interrupt error's own `prepareStackTrace` call included,
      whatever absorbed the previous throw, and whether the stop was set from a poll or outside one (a host's native,
      the memory hook). Before this the next poll came at once only when the interrupt error's own allocation crossed
      the 100-unit work check, a margin of about 12 units; with `Error.stackTraceLimit = 0` and an earlier stop's error
      kept alive (its shape cached) it did not, and the next poll was up to `JS_INTERRUPT_COUNTER_INIT` operations away.
      With the poll requested after the build (fix round 2), a looping `prepareStackTrace` still ran 99 iterations at
      every stop's throw after the first.
    - Left alone, each bounded by the rule above (it absorbs at most the one exception thrown inside it; the next poll
      site, which it reaches before calling any more JS or which is its next call's entry, throws):
      - the places that turn a single exception into a value as upstream does for its own uncatchable error: change 8's
        list (the thenable job, the async generator's `completed_return`, the resolve function's `then` read,
        `Promise.try`, the async-from-sync iterator, dynamic `import()`, module evaluation, whose exception becomes the
        module's), `js_async_iterator_proto_dispose` (`AsyncIterator.prototype[Symbol.asyncDispose]`: the `return` read
        and its call each turn an exception into a rejected promise, like `Promise.try`), `JS_IteratorClose` called from
        C (it keeps the exception it closes with), `build_backtrace`'s `Error.prepareStackTrace` call (one per error
        built; its exception is dropped; on a stopped runtime its first poll throws, also for the interrupt's own error,
        whose poll is requested before the build), and a typed array element's conversion under
        `Reflect.defineProperty` (`JS_SetPropertyValue`, whose exception becomes `false`);
      - `Promise.all`/`allSettled`/`any`/`race`: the iteration rejects and returns at its first exception;
      - the async generator's request loop (`js_async_generator_resume_next`): a body's exception completes the generator,
        and a completed generator settles one more request and returns. The exceptions of its resolving calls are
        ignored (`js_async_generator_resolve_or_reject`), but the loop goes on only to resume the body again, whose first
        poll throws;
      - `AsyncDisposableStack.prototype.disposeAsync`: its first disposer's exception becomes a rejection, and the
        `then` it chains for each further resource is a call whose exception returns at once. The further disposers
        run one per job (`js_async_dispose_step`), whose exception `promise_reaction_job` propagates (above).
    - Audited, for a loop that makes repeated JS calls and goes on after their exceptions (every `JS_GetException` in
      `quickjs.c`, 36 sites, and every `JS_Call`/`JS_Invoke`/`JS_CallFree` whose result is not checked at once): only the
      two disposal loops have that shape; the rest are listed above, or stop at the first exception (the Set methods,
      `Map.prototype.forEach`, `Array.from`, `JSON.stringify`'s `toJSON` and replacer, `instanceof`'s
      `Symbol.hasInstance`), or are single calls of C resolving functions whose exception is ignored (module loading and
      evaluation, dynamic `import()`, an async generator's `next` on a wrong receiver), or only clear an exception
      without JS (the call site objects of `Error.prepareStackTrace`, `build_backtrace`'s save of the pending
      exception).
    - Measured (Task 12a fix rounds 1 and 2, a scratch probe: `for (let i = 0; i < 200000; i++)` around each of
      `Promise.try`, an async generator body, a thenable's `then` getter, `Promise.all`'s iteration, two looping
      disposers and a for-of's looping `return()`, with memory to spare and with none): every loop ended within 2 polls
      of the stop, after at most one more iteration.
    - Why: the host stops a widget for good (its budget, its memory, an internal failure) and from then on nothing may
      run on. QuickJS's own interrupt error is uncatchable, but only as an object: when a refusal at the memory limit
      leaves too little to build it, QuickJS throws bare `null`, which a script's `try` caught at every poll (change 9's
      residual; the same with a budget stop that finds memory full). An out-of-memory error, caught once, let a script
      decide what to do after the stop. With the flag, the stop decides, not the value. A script's own `throw null`
      before any stop is unchanged: nothing reads `null` as a stop.
    - Unset (the default, and every runtime that never calls it) the five tests are upstream's
      `JS_IsUncatchableError(rt->current_exception)`, and the iterator-close and disposal checks and the forced poll in
      `JS_ThrowInterrupted` never apply: upstream behaviour.
    - Pinned by `tests/quickjs_host_test.c`, `test_stopped`: unset, a thrown `null`, a plain object and a number are
      caught and their finally runs, a promise reaction's `null` rejects and an async function's catch runs after its
      await; set, none of the four scripts' catch or finally runs, nor around the interrupt's error, and an async
      function (before and after its await), a reaction and an executor each propagate a `null`; a stop latched in the
      `return()` of a for-of an exception is leaving skips the catch it was heading for; an async function that returns
      after the stop, when its resolve call's poll can only throw `null`, propagates instead of aborting the process.
      `test_stopped_next_poll`: right after `JS_SetStopped`, and after each stop the C caller absorbed
      (`Error.stackTraceLimit = 0`, the first stop's error kept alive), the next poll site, a call that allocates
      nothing, asks the handler and throws. `test_stopped_prepare_stack_trace`: with a looping `Error.prepareStackTrace`,
      no stop's throw runs an iteration of it. `test_stopped_disposal`:
      a native disposer that stops the runtime on its 1,000th (100th) call and throws, in a stack of 100,000 `defer`s
      disposed by `dispose()` and by `{ using t = s; }`, and in a scope of 1,000 `using` declarations: no disposer runs
      after it, at most one poll asks the handler, under 1,000 units are spent past the stop, and nothing leaks
      (`JS_FreeRuntime`'s object-list assertion). Each site was mutated in turn (the flag a no-op, each test back to the
      value alone, each disposal check and the forced poll removed): every mutation fails the suite. The native
      runtime's `RuntimeHookTests` (`testAStopIsNotCaughtWhenItsErrorCannotBeBuilt`, `testABudgetStopIsNotCaught`,
      `testOutOfMemoryCannotBeCaught`, `testDisposalEndsAtTheStop`) and `TimerTests`
      (`testATimerThatCouldNotBeScheduledIsNotKept`) pin it end to end.
11. **The walks of a context's loaded modules are charged** (2026-10-17, the native runtime's module scripts, M1b plan
    Global Constraints "Work"; Task 13 fix round 2, ruling J1).
    - What: `JSContext.loaded_module_count` counts the modules in `ctx->loaded_modules`. It goes up where a module joins
      the list (`js_new_module_def`) and down where one leaves it (`js_free_module_def`, the one `list_del` of a
      module's link). `js_free_modules` goes through it, and so do the failures that unlink a module: a parse, a
      function creation or a resolution that fails (`__JS_EvalInternal`'s `fail1`) and a failed `JS_ReadModule`. A
      module whose body throws stays listed, with its `eval_exception` set. Every walk of the list that script reaches
      is charged `count × JS_WORK_ELEMENT_UNITS` (4: local edit 2's generic element visit) before it starts, through
      `JS_ChargeWork` (`js_charge_loaded_modules`):
      - `js_find_loaded_module_by_name`, which `import.meta` runs on every evaluation (`js_import_meta`, upstream's
        "XXX: inefficient" lookup by name). A refused charge returns NULL with the interrupt pending, and `js_import_meta`
        propagates it (`JS_HasException`) instead of throwing its catchable "import.meta not supported in this context";
      - `js_find_loaded_module`, an import's lookup (static `import` through `js_resolve_module`, `import()` through
        `JS_LoadModuleInternal`). Module bytecode a host reads (`JS_ReadObject`, through `JS_ReadModule`) reaches the
        same lookup when the host resolves its imports (`JS_ResolveModule`): a host route, not a script one, charged
        alike. Its one caller, `js_host_resolve_imported_module`, already propagates a NULL with an exception pending
        (`JS_HasException`, the path upstream uses for `js_module_attributes_equal`'s failure);
      - `js_free_modules` when it frees the unresolved modules after a failed resolution (`JS_FREE_MODULE_NOT_RESOLVED`:
        `import()` with a module loader, and the host's `JS_ResolveModule`). It is void, so it charges deferred
        (`js_charge_loaded_modules_deferred`, `js_charge_work_deferred`: the next poll decides). The context's teardown
        (`JS_FREE_MODULE_ALL`, from `JS_FreeContext`) is not charged.
    - The list's walks audited (`list_for_each…(&ctx->loaded_modules)`, five sites):
      - `js_find_loaded_module_by_name` and `js_find_loaded_module`: reachable from script; charged (above);
      - `js_free_modules`: reachable from script only through `import()` with a module loader that returns a module
        whose resolution then fails; charged when it frees unresolved modules (above);
      - `JS_MarkContext`, the collector's mark of every module: reachable from script only as garbage collection, which
        the fork charges nowhere per object (each module was paid for as allocated bytes, local edit 2); unchanged;
      - `JS_ComputeMemoryUsage`: a host API, not reachable from script; unchanged.
    - Why: a module stays in the list for the context's life once it is evaluated, so the list grows by one per module
      script (the native runtime runs each through `JS_Eval`). `import.meta` walked it from the head, uncharged, at
      every evaluation, so the same budget bought one more list step per module per iteration. Measured (Task 13 fix
      round 1): `for (;;) import.meta` under 400,000 units took 3 ms after 16 module scripts and 3.25 s after 2,000; with
      20,000 and 4,000,000 units it ran past 10 minutes. The native runtime's module normalize hook (`wr::Runtime::
      refuseModule`, Task 13 fix round 1) refuses every import before `js_find_loaded_module`, but nothing stands before
      `import.meta`'s walk.
    - Deterministic: the charge is a count, not a time. The walks themselves and every lookup's result are upstream's;
      only the charge (and, at a refusal, the interrupt in place of the lookup's outcome) is new. A runtime that never
      sets an interrupt handler sees only the work counter move.
    - Pinned by `tests/quickjs_host_test.c`, `test_loaded_module_walks`:
      - under one budget an `import.meta` loop's iteration costs 4 units more per module loaded (7,936 more after 2,000
        modules than after 16, within 5%);
      - 2,000 modules refused at their `import` (freed again) are not charged for: the loop runs exactly as many
        iterations as with none;
      - a charge refused inside `import.meta` throws the uncatchable interrupt: the `catch` around it does not run. A
        charge refused inside a static import's lookup throws the interrupt too, not the catchable
        "could not load module".
      Each site was mutated in turn (the decrement, the increment, the two charges, `js_import_meta`'s propagation):
      every mutation fails the test. `js_free_modules`' deferred charge is not separately pinned: its only script route
      needs a module loader. The native runtime's `testImportMetaIsChargedPerLoadedModule` (`ScriptTests`) pins it end
      to end.
12. **No dumps without an explicit opt-in** (2026-10-17, the M1b final review's I1; M1b plan Global Constraints
    "Work").
    - What: upstream's `#ifndef NDEBUG` / `#define ENABLE_DUMPS` (`quickjs/quickjs.c:84`, upstream's line) now reads
      `#ifdef TELEGRAM_QJS_ENABLE_DUMPS`. That guard is the whole source change (`git grep -n "fork change 12"
      third-party/quickjs-ng/quickjs`). Nothing in the tree defines it; `-DTELEGRAM_QJS_ENABLE_DUMPS` in a local
      `quickjs_copts` turns the dumps back on for debugging, with the cost below.
    - Why: `ENABLE_DUMPS` does not only compile the dump code in. It adds a list link to every string
      (`JSString.link`) and a list of them to the runtime (`JSRuntime.string_list`), so every string and atom
      allocation is larger. The work counter charges allocated bytes (local edit 2), and the memory limit and the GC
      thresholds count them, so a build without `NDEBUG` (Bazel's default configuration, the app's debug builds) spent
      more units on the same script than `-c opt`, reached the memory limit and ran the collector at other points, and
      took other in-place concatenation decisions (`JS_ConcatString2` compares the block's usable size with
      `sizeof(*p1)`). A widget would have been stopped at different points in the app's debug and release builds.
      Measured with the native runtime's WPT runner (`:WidgetRuntimeWPTTests`, which prints every page's units): before
      the change, all 331 pages' units differed between the default build and `-c opt` (the default build's median page
      35,668 units, 3.8%, more); after it, all 331 are equal, and equal under `-c dbg` too (all three of Bazel's
      compilation modes, measured on the M1b final fix's tree).
    - Left alone: `assert` still follows `NDEBUG`. `-DNDEBUG` is not added to `quickjs_copts`: it would also remove
      `JS_FreeRuntime`'s `assert(list_empty(&rt->gc_obj_list))`, which the host suites rely on to catch a leak.
    - The string layout is runtime state, not part of the bytecode format: the `.qbc` files are unaffected.
    - Pinned by `tests/quickjs_host_test.c`, `test_dumps_never_follow_ndebug`: in the suite's default build (no
      `NDEBUG`) `JS_SetDumpFlags(rt, ~0)` keeps nothing and `JS_GetDumpFlags` answers 0, which is what both do with the
      dumps compiled out. Before the change it answered the 24 bits of the flags field (the RED run). End to end, the
      WPT runner's per-page units compared between the two configurations (above) are the check; nothing runs that
      comparison automatically.
