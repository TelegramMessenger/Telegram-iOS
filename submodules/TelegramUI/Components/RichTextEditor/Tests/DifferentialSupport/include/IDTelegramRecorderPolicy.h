// NOT VENDORED. Written for Telegram, Task 9c.
//
// **The declined-comparison-field list, published as DATA rather than left as an omission.**
//
// The vendored comparator (`IDCompareTextInputSnapshotPair`, `IDTextInputDifferentialRunner.m`)
// decides equality with `leftValue == rightValue || [leftValue isEqual:rightValue]`. **`nil == nil`
// is TRUE.** So a field absent from BOTH snapshots is reported as *agreement on something nobody
// measured* — a green result carrying no information, which is the one failure mode a corpus oracle
// must not have. And a field absent from only ONE side is not safe either: the comparator `return`s
// on the FIRST inequality, scanning snapshot indices outermost, so a single permanently-differing
// field at snapshot 0 masks every later snapshot and every later field of that scenario.
//
// The rule Task 9c was given — "a field that cannot be sampled must be ABSENT from the snapshot,
// never defaulted to a plausible value" — prevents a false *value*. It does not prevent a false
// *agreement*. Both are needed, so this header carries the second half:
//
//   * `IDTelegramDeclinedComparisonFields()` — what a Telegram host cannot sample, with
//     `IDTelegramDeclinedComparisonFieldReasons()` giving each one a stated reason (gate item 12
//     requires the named form).
//   * `IDTelegramComparableFields()` — the same list subtracted from a scenario's own
//     `comparisonFields`, in order. **Task 9d must hand THIS to the runner**, not
//     `scenario.comparisonFields` verbatim.
//
// The list is not a hand-maintained constant that can drift away from the recorder: the recorder
// computes its declines from CAPABILITY at every capture (does the input answer all ten trait
// getters? is the observed storage a live one or a projection?) and publishes them in the snapshot
// under `IDTelegramSnapshotDeclinesKey`, and
// `TelegramDifferentialRecorderTests.test_thePublishedDeclinedListIsExactlyWhatTheRecorderDeclines…`
// asserts the two agree — empty for a stock host, exactly this list for a Telegram one.
//
// ## What is NOT in here, deliberately
//
// A field that CAN be sampled but is expected to DIFFER is not a decline — it is a named entry in
// Task 9d's `TelegramDifferentialExpectations`. `caretRect`, `selectionRects` and
// `typingInlineTraits` at a caret are all in that second category: the recorder measures them
// faithfully and lets the difference be reported. Declining a field we can measure would hide a
// real behavioural divergence, which is the opposite of this phase's job.
#import "IDTextInputScenario.h"

NS_ASSUME_NONNULL_BEGIN

/// Snapshot key under which the recorder publishes the fields it declined at THIS capture, mapped to
/// the reason. Never a comparison field of any scenario (measured over all 68), so publishing it
/// cannot affect a comparison — it exists so a decline is visible in the artifact rather than
/// inferred from an absence.
FOUNDATION_EXPORT NSString *const IDTelegramSnapshotDeclinesKey;

/// The comparison fields a Telegram host cannot sample, sorted. Two, measured 2026-08-24:
/// `storageMutationTrace` and `traits`.
FOUNDATION_EXPORT NSArray<NSString *> *IDTelegramDeclinedComparisonFields(void);

/// Each declined field mapped to why it is declined. Same key set as the array above.
FOUNDATION_EXPORT NSDictionary<NSString *, NSString *> *
IDTelegramDeclinedComparisonFieldReasons(void);

/// `scenarioComparisonFields` with every declined field removed, order preserved. This is what a
/// differential run must compare on: a declined field is then *visibly not compared* rather than
/// invisibly equal.
FOUNDATION_EXPORT NSArray<NSString *> *
IDTelegramComparableFields(NSArray<NSString *> *scenarioComparisonFields);

NS_ASSUME_NONNULL_END
