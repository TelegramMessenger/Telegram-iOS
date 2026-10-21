// The one facade Swift reaches WidgetRuntime through (M1d plan, Task 7): a widget's runtime, its CoreText host, its
// render tree and its production host, behind Objective-C. Every call catches what C++ throws: after a caught failure
// `failed` is YES and every call is a no-op answering its empty default. Calls are made on the widget's queue, one at a
// time (they may move between the pool's threads); `teardown` may come from any thread and waits for a running call.
// The delegate is called inside a call into the session, on its thread, and must not call back into it: a call it makes
// anyway does nothing and answers its empty default.
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WRStopReason) {
    WRStopReasonNone,
    WRStopReasonBudget,
    WRStopReasonMemory,
    WRStopReasonInternal,
    /// One task's layout queries did more than their budget (sdk-v1 §2, "Layout query limit exceeded").
    WRStopReasonLayoutQuery,
};

typedef NS_ENUM(NSInteger, WRStepResult) {
    WRStepResultRan,
    WRStepResultIdle,
    WRStepResultStopped,
};

typedef NS_ENUM(NSInteger, WRPointerPhase) {
    WRPointerPhaseDown,
    WRPointerPhaseMove,
    WRPointerPhaseUp,
    WRPointerPhaseCancel,
};

@class WRSession;

@protocol WRSessionDelegate <NSObject>
- (void)session:(WRSession *)session diagnostic:(NSString *)kind detail:(NSString *)detail;
- (void)session:(WRSession *)session log:(NSInteger)level text:(NSString *)text;
/// A bridge call: the method, and its arguments as a JSON array of strings. The session applies no policy.
- (void)session:(WRSession *)session bridge:(NSString *)method args:(NSString *)argsJson;
/// The work counter, at least every 10,000 units while a step runs: what feeds main's wait meter.
- (void)session:(WRSession *)session didWork:(uint64_t)totalUnits;
@end

/// A published layer tree: immutable, and readable on any thread. It outlives its session.
@interface WRTree : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) CGSize size;
/// The tree's `rect` (CSS px) painted at `scale`: a premultiplied BGRA image of ceil(size × scale) pixels, at most
/// 4096 a side; nil past that or for an empty rect.
- (nullable CGImageRef)copyImageOfRect:(CGRect)rect scale:(CGFloat)scale CF_RETURNS_RETAINED;
@end

@interface WRSession : NSObject

/// The runtime (64 MiB of memory, a 1 MiB stack), its host and its render tree, laid out at `width` CSS px in the
/// light or dark theme and recorded for drawing at `scale`. nil when it cannot be made.
- (nullable instancetype)initWithWidth:(CGFloat)width
                                  dark:(BOOL)dark
                                 scale:(CGFloat)scale
                              delegate:(id<WRSessionDelegate>)delegate;
- (instancetype)init NS_UNAVAILABLE;

/// The parse (under the 400,000,000-unit ceiling, ours) and then the boot's scripts and lifecycle on one 48,000,000-unit
/// budget, up to the `load` task. NO when the widget failed to start: a C++ failure, a stop before its parsed markup was
/// published, or a second boot. A widget whose scripts stopped it still started. No size check of our own: the server
/// bounds the HTML (widget-sandbox integration.md, "The widget payload").
- (BOOL)bootWithSource:(NSString *)source;
/// The same, on the given parse ceiling and boot budget (tests measure what a widget needs on larger ones).
- (BOOL)bootWithSource:(NSString *)source parseUnits:(uint64_t)parseUnits bootUnits:(uint64_t)bootUnits;

/// One task (timers due by `nowMs` included) or one animation frame, under the limit setWorkLimitAfter: set. `nowMs` is
/// on the session's monotonic clock (CACurrentMediaTime() × 1000).
- (WRStepResult)runNextTaskAt:(double)nowMs;
- (BOOL)wantsAnimationFrame;
- (WRStepResult)runAnimationFrameAt:(double)nowMs;
- (BOOL)hasRunnableTaskAt:(double)nowMs;
/// The earliest timer deadline, nil when there is none.
- (nullable NSNumber *)nextTimerDeadline;
/// The next step may spend `units` more.
- (void)setWorkLimitAfter:(uint64_t)units;

/// A width or theme change rebuilds and flushes now; a theme change also queues the TelegramWidget.onTheme callbacks.
- (void)setWidth:(CGFloat)width;
- (void)setDark:(BOOL)dark;
/// SDK v1 §2.9: the client's UI language as a BCP 47 tag, navigator.language; a malformed one is en-US. Set it before
/// the boot.
- (void)setLocale:(NSString *)locale;
- (void)setVisible:(BOOL)visible;
/// One phase of a tap at `point` (CSS px), queued as a task.
- (void)pointer:(WRPointerPhase)phase at:(CGPoint)point pointerId:(int32_t)pointerId primary:(BOOL)primary;

@property (nonatomic, readonly) WRStopReason stopReason;
@property (nonatomic, readonly) uint64_t workUnits;
/// What the parse spent of `workUnits` (the parsed markup's first build included); the boot's scripts spent the rest.
@property (nonatomic, readonly) uint64_t parseUnits;
/// The loads the render tree refused (it fetches nothing), as of the last call; kept after the runtime goes.
@property (nonatomic, readonly) uint64_t refusedLoads;
/// The content's own width and the document's height, CGSizeZero before the first flush.
@property (nonatomic, readonly) CGSize contentSize;
@property (nonatomic, readonly) BOOL failed;

/// The published tree, the same object until the next publish; nil before the first flush. After a memory stop or
/// teardown, the last one.
- (nullable WRTree *)tree;
/// What changed since the previous call, padded 2 px for glyph overhang and intersected with the tree's extent (the
/// layout width and the document's height, or the content where it is larger); nil when everything did (the first
/// publish, a size change).
- (nullable NSArray<NSValue *> *)changedRects;
/// Drops the runtime. Trees already handed out stay valid.
- (void)teardown;
/// The live document's `<html>` attribute `name` (the conformance runner reads `data-conformance` there): no script
/// runs and nothing is flushed (the name's string, allocated in the widget's heap, is the only work). nil when absent,
/// before the boot, after a failure or teardown.
- (nullable NSString *)documentElementAttribute:(NSString *)name;

/// Tests only: `code` as a global script under the limit setWorkLimitAfter: set, then its microtasks and a flush; its
/// completion value as a string, or nil when there is no runtime or the script stopped it.
- (nullable NSString *)evaluateForTesting:(NSString *)code;
/// Tests only: the border box (CSS px) of the first element `selector` matches, at the current layout; CGRectNull when
/// nothing matches, the selector does not parse, or the element has no box.
- (CGRect)borderBoxForTesting:(NSString *)selector;

@end

NS_ASSUME_NONNULL_END
