// TELEGRAM-AUTHORED (not ported). Small process-level probes that Swift cannot express.
//
// `+[UITextInputMode currentInputMode]` is the classifier's first gate in
// `IDSpellingReadinessProbe`, and it is marked unavailable to Swift ("APIs deprecated as of iOS 7
// and earlier are unavailable in Swift"). Upstream never needed a shim because its whole probe is
// Objective-C. A Swift suite that wants to measure the gate SEPARATELY from the probe's verdict
// needs this, and measuring it separately is the point: a mode mismatch and a missing marker are
// different findings that the probe's single status enum collapses if you only read the status.

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

/// `UITextInputMode.currentInputMode.primaryLanguage`, or nil when there is no current mode.
FOUNDATION_EXPORT NSString *_Nullable IDCurrentInputModePrimaryLanguage(void);

/// Whether the process has a `UITextInputMode.currentInputMode` at all — distinct from having one
/// whose primary language is nil.
FOUNDATION_EXPORT BOOL IDHasCurrentInputMode(void);

/// The names of the private text-input classes the spelling lifecycle hooks swizzle, paired with
/// whether `NSClassFromString` resolves them in this process. A hook that cannot be installed is
/// reported by the trace as `hooksUnavailable`, which is indistinguishable from "the pipeline never
/// ran" unless you can see this.
FOUNDATION_EXPORT NSDictionary<NSString *, NSNumber *> *IDPrivateTextInputClassAvailability(void);

NS_ASSUME_NONNULL_END

// ---------------------------------------------------------------------------------------------
// Continuous spell checking + a text-driven annotation sampler.
//
// `-setContinuousSpellCheckingEnabled:` is private on `UITextView`; upstream reaches it through an
// Objective-C category declaration, which Swift cannot write for a private selector it must also
// call. These two are that category, named.
//
// `IDObserveStockAnnotationRangesForText` exists because the ONE oracle that survives in this
// process is the temporary-rendering-attribute one, and an oracle is only an oracle if it
// DISCRIMINATES. A suite must be able to run the identical procedure over a misspelled string and a
// correctly-spelled one and get different answers; otherwise "annotation observed" could be
// reporting some unrelated rendering attribute and every spelling test built on it would be
// vacuous.
// ---------------------------------------------------------------------------------------------

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void IDSetContinuousSpellCheckingEnabled(id view, BOOL enabled);
FOUNDATION_EXPORT BOOL IDIsContinuousSpellCheckingEnabled(id view);

/// Configures `editor` exactly as `IDObserveStockSpellingReadiness` does, types `text` into it one
/// insertion, pumps the run loop for `timeout`, and returns the temporary-rendering-attribute
/// ranges (`{location,length}` dictionaries) that differ from persistent attributes.
///
/// The editor must already be installed in a visible window. It is LEFT AS FIRST RESPONDER, so a
/// caller can drive a further edit (a correction) and sample again — the checker does not run for a
/// view that has resigned.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDObserveStockAnnotationRangesForText(UITextView *editor,
                                      NSString *text,
                                      NSTimeInterval timeout);

/// Pumps the main run loop for `timeout`, forces layout, and samples again.
///
/// **The layout pass is load-bearing and easy to omit.** TextKit 2 rendering attributes are only
/// populated once layout has run for the bounds; sampling without it reads an empty set, and a test
/// then reports "no oracle" for an instrument reason. Upstream's own probe does exactly these calls
/// before every sample.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDStockPumpAndSampleAnnotationRanges(UITextView *editor, NSTimeInterval timeout);

NS_ASSUME_NONNULL_END
