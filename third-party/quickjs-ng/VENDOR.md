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

1. **The interrupt poll every 100 operations** (2026-10-14, the message-widgets final review's R1). **Reverted
   2026-10-30** (the CPU-clock limits plan, Task 2): the widget's limits are widget-sandbox's, on the thread CPU clock,
   read in the interrupt handler at QuickJS's stock 10,000 polls, as upstream's clients read it; `BUILD` no longer
   sets the define. The `#ifndef` guard stays (harmless). The record below is history; `:QuickJSSmokeTests` now pins
   the stock rate (a 100,000-iteration loop asks the handler 5 to 99 times).
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

2. **The work counter** (2026-10-15). **Removed 2026-10-30** (the CPU-clock limits plan, Task 7; the user: "exact
   upstream parity here"). The widget's limits are widget-sandbox's, on the thread CPU clock, read in the interrupt
   handler at QuickJS's stock 10,000 polls (`wr::Runtime`), as upstream's clients read them. The counter
   (`JS_GetWorkUnits`, `JS_ChargeWork`, the `JS_WORK_*` rates, the charges in the interpreter, the allocator and the
   builtins, libregexp's `lre_charge_steps` and `lre_charge_work`) is gone with its suites (`:QuickJSWorkTests`,
   `:QuickJSWorkCostTests`, `:QuickJSNativeSweep`); `quickjs.c`, `libregexp.c` and `libregexp.h` are upstream's but
   for the changes below. What it took away: a builtin that does not poll (a `trim` of 4 MB, BigInt division, a
   generic `join` of `{length: 2**40}`) runs to its end, as in upstream, and the slice's stop lands at the next poll
   after it. `git show 2eb055b3ba:third-party/quickjs-ng/VENDOR.md` has the record, its calibration and the
   native-path sweep's findings.
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
   - Why: in the native runtime's test mode a whole widget run (time, randomness) must repeat exactly. The
     runtime gives `Date` the host's clock and seeds `Math.random` from its options (`wr::Runtime::create`).
   - Pinned by `tests/quickjs_host_test.c`, `test_wall_clock_and_random_seed`.
8. **An uncatchable error through a Promise executor** (2026-10-17, the native runtime's stop latch, M1b plan Global
   Constraints "Stops are final"; Task 5 fix round 1, ruling R2).
   - What: `js_promise_constructor` returns the exception, still pending, when the executor ends with an uncatchable
     error, instead of rejecting the new promise with it. That is what `js_async_function_resume` and
     `promise_reaction_job` already do. A catchable exception still rejects, as the standard says.
   - Why: the host stops a widget with QuickJS's uncatchable "interrupted" (its interrupt handler). The
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
     - After the hook, every context's next interrupt poll asks the handler at once (`js_request_poll`), not up to
       `JS_INTERRUPT_COUNTER_INIT` operations later, so a stop the hook latched lands at the next poll site. Only when a
       hook is set.
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
      interrupt's throw from a poll or a regex step check), make every context's next poll ask the handler at once
      (`js_request_poll`). `JS_ThrowInterrupted` requests it before it builds its error, because building an error can call
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
    - Why: the host stops a widget for good (its CPU limits, its memory, a count cap, an internal failure) and from then
      on nothing may run on. QuickJS's own interrupt error is uncatchable, but only as an object: when a refusal at the memory limit
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
      after it, at most one poll asks the handler, and nothing leaks
      (`JS_FreeRuntime`'s object-list assertion). Each site was mutated in turn (the flag a no-op, each test back to the
      value alone, each disposal check and the forced poll removed): every mutation fails the suite. The native
      runtime's `RuntimeHookTests` (`testAStopIsNotCaughtWhenItsErrorCannotBeBuilt`, `testACpuStopIsNotCaught`,
      `testOutOfMemoryCannotBeCaught`, `testDisposalEndsAtTheStop`) and `TimerTests`
      (`testATimerThatCouldNotBeScheduledIsNotKept`) pin it end to end.
11. **The walks of a context's loaded modules are charged** (2026-10-17). **Removed 2026-10-30** with change 2, whose
    counter it charged (`JSContext.loaded_module_count`, `js_charge_loaded_modules`): `import.meta`'s walk of the
    loaded modules is upstream's again, and its time is the slice's like any other. The native runtime's module
    normalize hook still refuses every import before `js_find_loaded_module` (`wr::Runtime::refuseModule`).
12. **No dumps without an explicit opt-in** (2026-10-17, the M1b final review's I1; M1b plan Global Constraints
    "Work").
    - What: upstream's `#ifndef NDEBUG` / `#define ENABLE_DUMPS` (`quickjs/quickjs.c:84`, upstream's line) now reads
      `#ifdef TELEGRAM_QJS_ENABLE_DUMPS`. That guard is the whole source change (`git grep -n "fork change 12"
      third-party/quickjs-ng/quickjs`). Nothing in the tree defines it; `-DTELEGRAM_QJS_ENABLE_DUMPS` in a local
      `quickjs_copts` turns the dumps back on for debugging, with the cost below.
    - Why: `ENABLE_DUMPS` does not only compile the dump code in. It adds a list link to every string
      (`JSString.link`) and a list of them to the runtime (`JSRuntime.string_list`), so every string and atom
      allocation is larger. The memory limit and the GC thresholds count them (and so did the work counter, change 2,
      while it was there), so a build without `NDEBUG` (Bazel's default configuration, the app's debug builds) reached
      the memory limit and ran the collector at other points than `-c opt`, and took other in-place concatenation
      decisions (`JS_ConcatString2` compares the block's usable size with `sizeof(*p1)`). A widget would have been
      stopped at different points in the app's debug and release builds. Measured with the native runtime's WPT runner
      (`:WidgetRuntimeWPTTests`, which printed every page's units then): before the change, all 331 pages' units differed between the default build and `-c opt` (the default build's median page
      35,668 units, 3.8%, more); after it, all 331 are equal, and equal under `-c dbg` too (all three of Bazel's
      compilation modes, measured on the M1b final fix's tree).
    - Left alone: `assert` still follows `NDEBUG`. `-DNDEBUG` is not added to `quickjs_copts`: it would also remove
      `JS_FreeRuntime`'s `assert(list_empty(&rt->gc_obj_list))`, which the host suites rely on to catch a leak.
    - The string layout is runtime state, not part of the bytecode format: the `.qbc` files are unaffected.
    - Pinned by `tests/quickjs_host_test.c`, `test_dumps_never_follow_ndebug`: in the suite's default build (no
      `NDEBUG`) `JS_SetDumpFlags(rt, ~0)` keeps nothing and `JS_GetDumpFlags` answers 0, which is what both do with the
      dumps compiled out. Before the change it answered the 24 bits of the flags field (the RED run).
