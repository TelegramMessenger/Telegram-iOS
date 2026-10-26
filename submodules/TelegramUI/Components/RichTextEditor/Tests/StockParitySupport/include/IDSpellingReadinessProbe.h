// PORTED from /Users/isaac/Documents/InputDec/Tests/IDSpellingReadinessProbe.h
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369 (1212 lines across .h/.m upstream).
//
// Carried over VERBATIM except for the THREE declarations under the single `TELEGRAM ADDITION`
// pragma at the end of this file. Derived, not remembered:
//   awk '/^#pragma mark - TELEGRAM ADDITION/{f=1} f&&/^FOUNDATION_EXPORT/{c++} END{print c}'  -> 3
//   grep -c '^#pragma mark - TELEGRAM ADDITION'                                               -> 1
// Only ONE of the three is a new function (`IDObserveSpellingLifecycleWithStimulus`, which exists
// because upstream's lifecycle entry point takes a `UITextView *` and reads
// `editor.textLayoutManager`, and Telegram's host is not a `UITextView`). The other two —
// `IDStockTemporaryRenderingRanges` and `IDRunMainRunLoopForInterval` — are upstream's own
// file-statics given external linkage, unchanged in body. Every upstream symbol keeps its upstream
// name and semantics. See ../PROVENANCE.md.
//
// (This block was pasted TWICE in the first version of this file, and the preamble said "two"
// while the file held three of them, twice. Both are fixed; the commands above are here so the
// next reader re-derives instead of trusting the sentence.)
//
// NOTE FOR READERS, measured 2026-08-26: upstream ships NO real implementation of
// `IDSpellingInputModeDriving`. The only conformer in the whole upstream tree is a fake inside
// `IDSpellingReadinessProbeTests.m` (`grep -rn IDSpellingInputModeDriving Tests/ UITests/` returns
// the protocol declaration, the lease's own uses, and that one fake). So `IDSpellingInputModeLease`
// is a fully-tested state machine with no production driver behind it — it does not, by itself,
// make a keyboard speak en-US.

#import <UIKit/UIKit.h>

@class XCTestCase;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, IDSpellingReadinessStatus) {
    IDSpellingReadinessStatusReady,
    IDSpellingReadinessStatusInputModeMismatch,
    IDSpellingReadinessStatusContinuousCheckingDisabled,
    IDSpellingReadinessStatusTemporaryAnnotationUnavailable,
    IDSpellingReadinessStatusMarkerRenderingUnavailable,
};

FOUNDATION_EXPORT NSErrorDomain const IDSpellingInputModeLeaseErrorDomain;

typedef NS_ERROR_ENUM(IDSpellingInputModeLeaseErrorDomain,
                      IDSpellingInputModeLeaseErrorCode) {
    IDSpellingInputModeLeaseErrorInputNotReady = 1,
    IDSpellingInputModeLeaseErrorPriorModeUnavailable,
    IDSpellingInputModeLeaseErrorEnglishUSModeUnavailable,
    IDSpellingInputModeLeaseErrorActivationFailed,
    IDSpellingInputModeLeaseErrorActivationTimedOut,
    IDSpellingInputModeLeaseErrorAlreadyLeased,
    IDSpellingInputModeLeaseErrorRestorationFailed,
    IDSpellingInputModeLeaseErrorKeyboardPipelineTimedOut,
};

@protocol IDSpellingInputModeDriving <NSObject>
- (BOOL)isVisibleFirstResponder:(id)input;
- (BOOL)isKeyboardPipelineReadyForInput:(id)input;
- (nullable id)currentInputModeForInput:(id)input;
- (nullable id)currentControllerInputMode;
- (nullable id)englishUSInputMode;
- (nullable NSString *)identifierForMode:(id)mode;
- (NSUInteger)modeChangeGeneration;
- (BOOL)forceInputMode:(id)mode error:(NSError **)error;
- (void)reloadInputViewsForInput:(id)input;
- (nullable NSString *)primaryLanguageForInput:(id)input;
@end

@interface IDSpellingInputModeLease : NSObject

@property(nonatomic, readonly, getter=isActive) BOOL active;
@property(nonatomic, readonly, getter=isInvalidated) BOOL invalidated;

+ (nullable instancetype)leaseForInput:(id)input
                                driver:(id<IDSpellingInputModeDriving>)driver
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error;
- (BOOL)invalidateWithError:(NSError **)error;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT IDSpellingReadinessStatus
IDClassifySpellingReadiness(BOOL continuousCheckingEnabled,
                            BOOL temporaryAnnotationObserved,
                            NSUInteger markerPixelCount);
FOUNDATION_EXPORT IDSpellingReadinessStatus
IDClassifySpellingReadinessForPrimaryLanguages(
    NSString *currentPrimaryLanguage,
    NSString *inputPrimaryLanguage,
    BOOL continuousCheckingEnabled,
    BOOL temporaryAnnotationObserved,
    NSUInteger markerPixelCount);
FOUNDATION_EXPORT NSString *
IDSpellingReadinessStatusString(IDSpellingReadinessStatus status);

@interface IDSpellingReadinessObservation : NSObject

@property(nonatomic, readonly) IDSpellingReadinessStatus status;
@property(nonatomic, readonly) BOOL continuousCheckingEnabled;
@property(nonatomic, readonly) BOOL temporaryAnnotationObserved;
@property(nonatomic, readonly) NSUInteger markerPixelCount;
@property(nonatomic, readonly) NSTimeInterval elapsedSeconds;
@property(nonatomic, copy, readonly) NSString *currentPrimaryLanguage;
@property(nonatomic, copy, readonly) NSString *inputPrimaryLanguage;
@property(nonatomic, copy, readonly) NSString *word;
@property(nonatomic, readonly) NSRange wordRange;
@property(nonatomic, readonly) CGRect firstRect;
@property(nonatomic, readonly) CGRect markerROI;
@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *dictionaryRepresentation;

- (instancetype)initWithStatus:(IDSpellingReadinessStatus)status
      continuousCheckingEnabled:(BOOL)continuousCheckingEnabled
    temporaryAnnotationObserved:(BOOL)temporaryAnnotationObserved
               markerPixelCount:(NSUInteger)markerPixelCount
                 elapsedSeconds:(NSTimeInterval)elapsedSeconds
         currentPrimaryLanguage:(NSString *)currentPrimaryLanguage
           inputPrimaryLanguage:(NSString *)inputPrimaryLanguage
                           word:(NSString *)word
                      wordRange:(NSRange)wordRange
                      firstRect:(CGRect)firstRect
                      markerROI:(CGRect)markerROI NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT IDSpellingReadinessObservation *
IDObserveStockSpellingReadiness(UITextView *editor, NSTimeInterval timeout);
FOUNDATION_EXPORT BOOL IDAssertEnglishCheckerAvailable(XCTestCase *testCase);
FOUNDATION_EXPORT void IDAttachSpellingObservation(
    XCTestCase *testCase,
    NSString *role,
    NSDictionary<NSString *, id> *observation,
    UIImage * _Nullable image);

typedef NS_ENUM(NSInteger, IDSpellingLifecycleStimulus) {
    IDSpellingLifecycleStimulusOneShot,
    IDSpellingLifecycleStimulusStaged,
};

@interface IDSpellingLifecycleTrace : NSObject

@property(nonatomic, copy, readonly) NSDictionary<NSString *, id> *dictionaryRepresentation;

- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT IDSpellingLifecycleTrace *
IDObserveStockSpellingLifecycle(UITextView *editor,
                                IDSpellingLifecycleStimulus stimulus,
                                NSTimeInterval timeout);

#pragma mark - TELEGRAM ADDITION (not upstream)

/// Host-agnostic form of `IDObserveStockSpellingLifecycle`.
///
/// **Why this exists.** Upstream's lifecycle trace takes a `UITextView *` and reads
/// `editor.textLayoutManager` to sample temporary rendering attributes. Telegram's host is a
/// `DocumentCanvasView`, not a `UITextView`, and has no `NSTextLayoutManager` spanning the document,
/// so the upstream entry point cannot be pointed at it.
///
/// The *hooks*, however, are class-level swizzles on the private `UITextInputController` and
/// `UITextCheckingController` — they are installed on the class, not on a view, so they observe the
/// checking pipeline no matter which input drives it. This entry point exposes exactly that: the
/// caller supplies the stimulus and (optionally) an annotation sampler, and gets back the same
/// dictionary schema upstream's function produces, including `firstMissingTransition`.
///
/// `annotationSampler` may be nil, in which case `annotationRanges` is empty and
/// `firstMissingTransition` can at best reach `@"annotationUnavailable"` — which is the honest
/// answer for a host whose annotations this function cannot see.
FOUNDATION_EXPORT IDSpellingLifecycleTrace *
IDObserveSpellingLifecycleWithStimulus(
    NSString *stimulusName,
    NSTimeInterval timeout,
    void (^stimulus)(void),
    NSArray<NSDictionary<NSString *, NSNumber *> *> *_Nullable (^_Nullable annotationSampler)(void));

/// The temporary-rendering-attribute ranges of a stock `UITextView` — i.e. the ranges whose
/// TextKit 2 *rendering* attributes differ from the persistent attributes at the same offset.
///
/// Exposed because it is the ONLY non-pixel oracle upstream's probe has for "the system text checker
/// annotated this word", and Task P2 needs to report on it separately from the pixel count. Upstream
/// keeps it file-static (`IDTemporaryRenderingRanges`); the body is unchanged.
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDStockTemporaryRenderingRanges(UITextView *editor);

/// Spins the main run loop for `interval`. Upstream keeps this file-static
/// (`IDRunMainRunLoopForInterval`); exposed so the ported suites drive both arms with the SAME
/// pumping discipline rather than each inventing one.
FOUNDATION_EXPORT void IDRunMainRunLoopForInterval(NSTimeInterval interval);

NS_ASSUME_NONNULL_END
