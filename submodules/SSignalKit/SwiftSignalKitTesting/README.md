# SwiftSignalKit2 testing

`SwiftSignalKit2/Source` is a drop-in rewrite of `SwiftSignalKit/Source` with the same public API and the same
observable behavior. This package proves that, side by side, in one process.

## Which library builds what

| Build | Library |
|---|---|
| macOS: every SwiftPM consumer of the `SwiftSignalKit` product (`Telegram`, `TelegramShare`, all `packages/*`, TelegramCore, Postbox and the other telegram-ios packages built for macOS) | `SwiftSignalKit2/Source`, set as the `SwiftSignalKit` target path in `SSignalKit/Package.swift` |
| iOS (Bazel, `SwiftSignalKit/BUILD`) | `SwiftSignalKit/Source`, unchanged |

The module is still called `SwiftSignalKit`, so `import SwiftSignalKit` and `SwiftSignalKit.Timer` are unchanged.
To build macOS with the legacy library for an A/B, change that path back to `SwiftSignalKit/Source`.
Keep both folders: iOS builds the legacy one and this package compiles both side by side.

## Layout

Both libraries are compiled into this package under different module names through symlinks:

| Module | Source |
|---|---|
| `SwiftSignalKitLegacy` | `../SwiftSignalKit/Source` |
| `SwiftSignalKit2` | `../SwiftSignalKit2/Source` |

Shared sources are compiled twice, once with `-D SSK_LEGACY` against the legacy module and once against v2:

| Shared folder | Targets | What it is |
|---|---|---|
| `Behavior/` | `LegacyBehaviorTests`, `V2BehaviorTests` | Explicit semantics of every public type and operator, written against legacy |
| `Stress/` | `LegacyStressTests`, `V2StressTests` | Concurrency invariants (dispose counts, no leaks, delivery order); most useful under TSan |
| `Scenarios/` | `ScenariosLegacy`, `ScenariosV2` | The parity fuzzer, the release-order probe and the benchmark workloads |

Other targets:

| Target | What it is |
|---|---|
| `ParityTests` | Runs the fuzzer seeds and the release-order probe on both libraries and requires byte-identical traces |
| `V2Tests` | v2-only tests: the deadlock, leak and crash fixes fail or hang on legacy; the rest pin v2 invariants (the `runOn` one only means something under TSan) |
| `SignalKitBench` | Interleaved legacy/v2 benchmark and bytes-per-live-subscription measurement |

## Running

From `submodules/SSignalKit/SwiftSignalKitTesting` in telegram-ios
(`submodules/telegram-ios/submodules/SSignalKit/SwiftSignalKitTesting` in telegrammacos):

```sh
swift test                                                          # everything, Debug
swift test -c release -Xswiftc -enable-testing                      # everything, Release
SSK_FUZZ_SEEDS=30000 swift test --filter FuzzParityTests            # extended parity sweep
SSK_DUMP_SEED=1028527 SSK_DUMP_STEPS=80 swift test --filter DumpSeed # side-by-side trace of one seed
SSK_PRINT_PROBE=1 swift test --filter ReleaseOrderTests              # release order per termination path
TSAN_OPTIONS=halt_on_error=0 swift test --sanitize=thread --filter StressTests   # TSan: legacy reports the runOn race, v2 nothing
swift build -c release --product SignalKitBench && .build/release/SignalKitBench --reps 7
```

## The parity fuzzer

`Scenarios/Fuzz.swift` builds random pipelines over controllable sources (hubs that emit, complete, fail or drop
their subscribers on command, `Promise`, `ValuePromise`, `ValuePipe`, synchronous sources) with every synchronous
operator (`combineLatest` with two and three inputs, initial values and arrays; the larger arities are covered by
`Behavior/`), then drives them with random actions: start (all three start variants), dispose, release a handle
without disposing, `MetaDisposable`/`DisposableSet` ownership, re-entrant dispose from callbacks, re-entrant emission
and re-entrant subscription. Every callback, every upstream subscribe/dispose and the deinit of objects captured by
callbacks, operators and `keepAlive` are written to a trace. Legacy and v2 must produce the same trace, including
the order in which objects are released, in both Debug and Release builds.

The order in which a single termination releases its captured objects is decided by the optimizer: legacy itself
releases them in a different order in Debug and in Release (compare `SSK_PRINT_PROBE=1` output of the two
configurations). v2 mirrors legacy's code shape, so `ReleaseOrderTests` and the fuzzer match legacy in both.

## Intentional differences

| Area | Legacy | v2 |
|---|---|---|
| Deinit of a replaced/removed value re-entering the same object (`Atomic.modify`, `Promise.set`, `ValuePromise.set`, `Subscriber` termination, `DisposableSet.removeLast`, `throttled` dropping a queued signal) | released while the lock is held: deadlock | released right after unlocking, at the same point relative to callbacks |
| A `weak` reference to a `Subscriber` during the handle's `dispose()` | the handle holds the subscriber until `dispose()` returns | the subscriber object can go away as soon as its source drops it; its callbacks are still released at the legacy point. Nothing in the macOS build keeps weak references to subscribers |
| A `weak` reference to the disposable returned by `start()` | dies when the caller releases it | lives while the source still holds the subscriber (it is the subscriber's state). Not observable without a weak reference |
| `DisposableDict.set(nil, forKey:)` | disposes the previous entry but keeps it, so later `set(nil)`/`dispose()` dispose it again and it stays retained | removes the entry |
| `DisposableSet.removeLast()` on an empty set | crash | no-op |
| `Multicast.get` | never disposes the upstream subscription | disposes it when its last subscriber leaves |
| `feedbackLoop` | retain cycle: every subscription leaks its subscriber and loop state | cycle broken on dispose and termination |
| `runOn(Queue)` cancellation flag | unsynchronized `var` shared across threads (TSan race) | lock-protected flag |

`Timer.start()` called twice cancels the previous dispatch source explicitly; legacy relies on the source being
deallocated when it is replaced. No observable difference.

`Atomic`, `Bag` and `|>` are `@inlinable` (stored properties `@usableFromInline`), so client modules specialize them.
That changes where the code is compiled, not what it does.

Locks: `os_unfair_lock` is used only where no caller code runs while it is held. `Atomic`, `Lock`, `ValuePromise`
(calls `T.==`) and `DisposableDict` (hashes keys) keep `pthread_mutex_t`, so re-entry deadlocks exactly as in legacy
instead of crashing. Every v2 lock moves replaced or removed references out before unlocking and releases them after,
including unsubscribes from `Promise`, `ValuePromise`, `ValuePipe` and `Multicast`, `DisposableSet.remove`, keys
removed from `DisposableDict`, the previous `Timer` source and values replaced in `combineLatest`.

When a `combineLatest` subscription ends, v2 releases the latest values it still holds in index order. Legacy
releases them in the order of a `[Int: Any]` dictionary, which changes from launch to launch with the hash seed, so
v2's order is one legacy can also produce.

Everything else is identical, including the deliberate legacy quirks (`take(0)` never completes, `MetaDisposable`
does not dispose on deinit, `Signal.get()` never resumes for a signal that completes without a value).

## Measurements (2026-10-03, M5 Pro)

`SignalKitBench`, interleaved, median of 9 (Release) / 5 (Debug) runs, geometric mean over 22 workloads: Release
1.31x, Debug 1.16x before `Atomic`/`Bag` became inlinable (then `Atomic.modify` 3.7x, `Bag` 2.9x in Release).
Notable: `never().start + dispose` 2.1x, concurrent start/dispose from 8 threads 2.2x, `combineLatest([16])` updates
1.8x, `deliverOn(queue)` 2-3x, `MetaDisposable.set` 1.6x. The one slower case is 8 threads pushing values into the
same subscriber chain at once (0.8x): `os_unfair_lock` does not spin under contention the way `pthread_mutex` does.

Memory per live subscription (malloc bytes): `never().start` 279 -> 119, five chained `map`s 3553 -> 1587,
`combineLatest` of three promises 5104 -> 2512, `mapToSignal` 2516 -> 1046.

Real app (Debug, PerfLab `chat-navigation` on a heavy group, 4 interleaved rounds): scroll main thread -3.6 % (every
round), footprint lower in every round, open-chat and idle CPU within noise, no hitches on either side. Heap after
opening and scrolling the chat: SwiftSignalKit objects 1.79 MB -> 1.05 MB with the same number of live subscribers,
15.7k fewer malloc blocks; `leaks` reports the same 4 unrelated leaks (AppKit/AudioUnit) on both builds.
