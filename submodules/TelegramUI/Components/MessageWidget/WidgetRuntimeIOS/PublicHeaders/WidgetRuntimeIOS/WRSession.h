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
    WRStopReasonMemory,
    WRStopReasonInternal,
    /// One task's layout queries took more than 100 ms (widget-sandbox's "Layout query limit exceeded"), its reason in
    /// `stopDetail`.
    WRStopReasonLayoutQuery,
    /// A counted cap of the strict policy (widget-sandbox v0.3.0), its reason in `stopDetail`.
    WRStopReasonLimit,
    /// A task ran past its slice on the CPU clock, or past the wall-clock backstop ("CPU limit exceeded"), its reason
    /// in `stopDetail`.
    WRStopReasonCpu,
};

/// The counted caps a session runs under (WidgetRuntime's Limits, widget-sandbox v0.3.0): Strict, every widget the app
/// shows; Compat, the caps from before v0.3.0, past which nothing stops (the stress kit's measuring runs, tests).
typedef NS_ENUM(NSInteger, WRLimitPolicy) {
    WRLimitPolicyStrict,
    WRLimitPolicyCompat,
};

typedef NS_ENUM(NSInteger, WRStepResult) {
    WRStepResultRan,
    WRStepResultIdle,
    WRStepResultStopped,
    /// Nothing ran: what was runnable waits for the CPU windows until `nextTimerDeadline` (widget-sandbox's quota).
    WRStepResultDeferred,
};

typedef NS_ENUM(NSInteger, WRPointerPhase) {
    WRPointerPhaseDown,
    WRPointerPhaseMove,
    WRPointerPhaseUp,
    WRPointerPhaseCancel,
    /// A press the host started before its touch arrived that no touch took up: a cancel to the widget, and a press that
    /// never was to its double tap.
    WRPointerPhaseRetract,
};

/// The drag axes a press takes for the widget (sdk-v1 §5.5).
typedef NS_OPTIONS(NSUInteger, WRGestureAxes) {
    WRGestureAxesHorizontal = 1 << 0,
    /// Never set since widget-sandbox v0.1.3 (G2: vertical drags are the chat's); kept as upstream keeps `y`.
    WRGestureAxesVertical = 1 << 1,
    /// The press's hold (touch-action: none): no message menu, the widget's `contextmenu`.
    WRGestureAxesHold = 1 << 2,
};

/// The edge of the widget's bubble that stays put when its height changes (sdk-v1 §5.6, widget-sandbox v0.1.3).
typedef NS_ENUM(NSInteger, WRResizeAnchor) {
    WRResizeAnchorTop,
    WRResizeAnchorBottom,
};

/// A request the client could not complete (sdk-v1 §2.14): `None` is an answer. `Rejected` (the user declined in the
/// wallet window) and `BadRequest` (the wallet refused it) are a wallet call's (§2.18); a request sees them as FAILED.
typedef NS_ENUM(NSInteger, WRRequestFailure) {
    WRRequestFailureNone = 0,
    WRRequestFailureTimeout,
    WRRequestFailureRateLimited,
    WRRequestFailureFailed,
    WRRequestFailureRejected,
    WRRequestFailureBadRequest,
};

/// The account looking at the widget (sdk-v1 §2.13, Mini Apps' WebAppUser), as the client passes it; the runtime checks
/// each field.
@interface WRWidgetViewer : NSObject
- (instancetype)initWithId:(int64_t)userId firstName:(nullable NSString *)firstName lastName:(nullable NSString *)lastName username:(nullable NSString *)username isPremium:(BOOL)isPremium;
@property (nonatomic, readonly) int64_t userId;
@property (nonatomic, readonly, nullable) NSString *firstName;
@property (nonatomic, readonly, nullable) NSString *lastName;
@property (nonatomic, readonly, nullable) NSString *username;
@property (nonatomic, readonly) BOOL isPremium;
@end

@class WRSession;

@protocol WRSessionDelegate <NSObject>
- (void)session:(WRSession *)session diagnostic:(NSString *)kind detail:(NSString *)detail;
- (void)session:(WRSession *)session log:(NSInteger)level text:(NSString *)text;
/// A bridge call: the method, and its arguments as a JSON array of strings. The session applies no policy.
- (void)session:(WRSession *)session bridge:(NSString *)method args:(NSString *)argsJson;
@optional
/// SDK v1 §3.2: the whole content of a storage area (`local` or `session`) a task changed, as [key, value] pairs in
/// insertion order, at the end of that task. Not after the widget has stopped.
- (void)session:(WRSession *)session storageCommit:(NSString *)area entries:(NSArray<NSArray<NSString *> *> *)entries;
/// widget-sandbox's `intl` capability: a request as its shim sends one, the answer as its glue gives it (the app's
/// delegate hands it to that glue, widget-sandbox's IntlBridge). All of Intl's locale data comes from here; without it
/// every format is "". Charged before it is asked.
- (NSString *)session:(WRSession *)session intl:(NSString *)requestJson;
@end

/// What the tiles of one draw share (twidget edit 64): each filter and backdrop result they show is made once, by the
/// first tile to ask for it, and kept until the store goes. Pass one to every tile of a draw, then let it go.
@interface WREffectStore : NSObject
/// How many results it made.
@property (nonatomic, readonly) NSUInteger made;
@end

/// A published layer tree: immutable, and readable on any thread. It outlives its session.
@interface WRTree : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) CGSize size;
/// The canvas's colour (CSS 2.1 §14.2: the root's background colour, or the body's it propagates) as 0xRRGGBBAA; 0 when
/// neither sets one. The tree paints it over the document only; a host view taller than the document paints it below.
@property (nonatomic, readonly) uint32_t canvasColor;
/// The tree's `rect` (CSS px) painted at `scale`: a premultiplied BGRA image of ceil(size × scale) pixels, at most
/// 4096 a side; nil past that or for an empty rect. The tiles of one draw pass one `effects`.
- (nullable CGImageRef)copyImageOfRect:(CGRect)rect scale:(CGFloat)scale effects:(nullable WREffectStore *)effects CF_RETURNS_RETAINED;
@end

/// One run of a selectable text: a drawn word, or part of one, in a layout box.
typedef struct {
    /// Its first UTF-16 unit in WRSelectableText.text, and how many.
    uint32_t start;
    uint32_t length;
    /// Its layout box, CSS px, before `transform`.
    CGRect box;
    /// Box space → the document (its ancestors' CSS transforms, composed).
    CGAffineTransform transform;
    /// Its Text node (a key stable across layouts) and the UTF-16 offset of `start` in that node's drawn text.
    uint64_t node;
    uint32_t nodeOffset;
    /// Its length + 1 caret offsets start at this index of WRSelectableText.carets.
    uint32_t caretIndex;
} WRSelectableRun;

/// The text a widget lets the reader select (sdk-v1 §2.4, §5.10: its effective user-select is text), as drawn, in
/// document order. Immutable; readable on any thread.
@interface WRSelectableText : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) NSString *text;
/// WRSelectableRun[], in `text` order; separators between runs belong to none.
@property (nonatomic, readonly) NSData *runs;
/// float[]: each run's caret offsets (CSS px from its box's left, one per UTF-16 boundary; descending right to left).
@property (nonatomic, readonly) NSData *carets;
@end

/// widget-sandbox's runtime limits (LIMIT_DEFAULTS), in milliseconds of the widget thread's CPU time: a task's slice
/// (past it the widget stops), the JS quota per window and the main-thread window (past either, deferrable tasks
/// wait), and how long throttling may last before the widget stops (0: never).
@interface WRCpuLimits : NSObject
- (instancetype)initWithCpuLimitMs:(double)cpuLimitMs
                        cpuQuotaMs:(double)cpuQuotaMs
                  cpuQuotaWindowMs:(double)cpuQuotaWindowMs
                    cpuKillAfterMs:(double)cpuKillAfterMs
                 mainThreadQuotaMs:(double)mainThreadQuotaMs;
/// The product's, in every build and under both policies: 500, 300 per 1000, 0, 100.
+ (instancetype)productLimits;
@property (nonatomic, readonly) double cpuLimitMs;
@property (nonatomic, readonly) double cpuQuotaMs;
@property (nonatomic, readonly) double cpuQuotaWindowMs;
@property (nonatomic, readonly) double cpuKillAfterMs;
@property (nonatomic, readonly) double mainThreadQuotaMs;
@end

/// What the stress kit's runner reads of a session (widget-sandbox v0.3.0, packages/stress): statistics, never a decision.
@interface WRSessionStats : NSObject
/// widget-sandbox's operations since the runtime began, and the largest batch (Limits::opsPerBatch's count).
@property (nonatomic, readonly) uint64_t totalOps;
@property (nonatomic, readonly) uint64_t maxBatchOps;
/// Layout queries answered.
@property (nonatomic, readonly) uint64_t layoutQueries;
/// Milliseconds the render flushes took (style, layout, the layer tree).
@property (nonatomic, readonly) double flushMilliseconds;
/// The QuickJS heap in use, bytes.
@property (nonatomic, readonly) uint64_t heapBytes;
/// The document's nodes.
@property (nonatomic, readonly) uint64_t nodes;
/// Steps either CPU window deferred.
@property (nonatomic, readonly) uint64_t throttledSteps;
/// Milliseconds the layout queries took, over every step.
@property (nonatomic, readonly) double queryMilliseconds;
/// The widget's JS time over every step (what the JS quota records), and the most CPU one step took (its JS and the
/// renderer's), milliseconds on the widget thread.
@property (nonatomic, readonly) double jsMilliseconds;
@property (nonatomic, readonly) double largestStepMilliseconds;
@end

@interface WRSession : NSObject

/// The runtime (memory as its policy says, a 1 MiB stack), its host and its render tree, laid out at `width` CSS px in the
/// light or dark theme and recorded for drawing at `scale`. nil when it cannot be made.
- (nullable instancetype)initWithWidth:(CGFloat)width
                                  dark:(BOOL)dark
                                 scale:(CGFloat)scale
                              delegate:(id<WRSessionDelegate>)delegate;
/// The same, with the chat's palette (SDK v1 §2.3: theme key → #rrggbb; unknown keys and other values are dropped),
/// the client's button tokens (§2.4: `bg`, `text`, `radius`, `font`, `padding`, `height` as strings, `pressedOpacity`,
/// `disabledOpacity` as numbers) and its text tokens (§2.4: `fontSize` and `lineHeight` as numbers, `padding` as a
/// string; a missing or refused one is the reference value), each checked against its grammar, in the first build
/// already.
- (nullable instancetype)initWithWidth:(CGFloat)width
                                  dark:(BOOL)dark
                           themeParams:(NSDictionary<NSString *, NSString *> *)themeParams
                          buttonTokens:(NSDictionary<NSString *, id> *)buttonTokens
                            textTokens:(NSDictionary<NSString *, id> *)textTokens
                                 scale:(CGFloat)scale
                              delegate:(id<WRSessionDelegate>)delegate;
/// The same under `policy` (the others are Strict).
- (nullable instancetype)initWithWidth:(CGFloat)width
                                  dark:(BOOL)dark
                           themeParams:(NSDictionary<NSString *, NSString *> *)themeParams
                          buttonTokens:(NSDictionary<NSString *, id> *)buttonTokens
                            textTokens:(NSDictionary<NSString *, id> *)textTokens
                                 scale:(CGFloat)scale
                              delegate:(id<WRSessionDelegate>)delegate
                                policy:(WRLimitPolicy)policy;
/// The same under `cpuLimits` (the others use the product's).
- (nullable instancetype)initWithWidth:(CGFloat)width
                                  dark:(BOOL)dark
                           themeParams:(NSDictionary<NSString *, NSString *> *)themeParams
                          buttonTokens:(NSDictionary<NSString *, id> *)buttonTokens
                            textTokens:(NSDictionary<NSString *, id> *)textTokens
                                 scale:(CGFloat)scale
                              delegate:(id<WRSessionDelegate>)delegate
                                policy:(WRLimitPolicy)policy
                             cpuLimits:(WRCpuLimits *)cpuLimits;
- (instancetype)init NS_UNAVAILABLE;

/// The QuickJS heap limit the session's policy gives it.
@property (nonatomic, readonly) NSUInteger memoryLimitBytes;
/// The stress kit's statistics now; nil without a runtime.
- (nullable WRSessionStats*)stats;

/// The parse, ours (its count limits bound it), and then the boot's scripts and lifecycle, each task on a CPU slice of
/// its own, up to the `load` task. NO when the widget failed to start: a C++ failure, a stop before its parsed markup
/// was published, or a second boot. A widget whose scripts stopped it still started. No size check of our own: the
/// server bounds the HTML (widget-sandbox integration.md, "The widget payload").
- (BOOL)bootWithSource:(NSString *)source;

/// One task (timers due by `nowMs` included) or one animation frame, on the CPU slice its kind gets; Deferred when the
/// CPU windows hold back what is runnable (`nextTimerDeadline` is the retry). `nowMs` is on the session's monotonic clock
/// (CACurrentMediaTime() × 1000).
- (WRStepResult)runNextTaskAt:(double)nowMs;
- (BOOL)wantsAnimationFrame;
- (WRStepResult)runAnimationFrameAt:(double)nowMs;
- (BOOL)hasRunnableTaskAt:(double)nowMs;
/// The earliest timer deadline or deferred work's retry time, nil when there is none.
- (nullable NSNumber *)nextTimerDeadline;
/// The CPU milliseconds of every step so far (each measured on the thread that ran it), our renderer's included: a
/// difference around a drain is the drain's.
@property (nonatomic, readonly) double stepCpuMilliseconds;
/// Of `stepCpuMilliseconds`, the boot lifecycle's own steps (its scripts and its load), wherever they run: the boot
/// task, and past its slice whichever core task drains next. The core exempts them from demotion for their first two
/// slices of CPU in all (`MessageWidgetCore.bootDemotionExemptionSlices`), the boot task's own included.
@property (nonatomic, readonly) double bootCpuMilliseconds;
/// Tests only, between steps: the session's CPU and wall clocks (milliseconds) from now on; the thread's otherwise.
- (void)setCpuClockForTesting:(double (^)(void))cpu wall:(double (^)(void))wall;

/// A width or theme change rebuilds and flushes now; a theme change also queues the TelegramWidget.onTheme callbacks.
- (void)setWidth:(CGFloat)width;
- (void)setDark:(BOOL)dark;
/// The system's Reduce Motion (prefers-reduced-motion): the render tree rebuilds, and a task runs after which the media
/// query lists whose answer flipped report a change. Before the boot it sets the first layout's.
- (void)setReducedMotion:(BOOL)reduced;
/// The scheme, the palette, the button and the text tokens at once: one theme change (one themeChanged) when anything
/// differs, a text-size change alone included.
- (void)setDark:(BOOL)dark
     themeParams:(NSDictionary<NSString *, NSString *> *)themeParams
    buttonTokens:(NSDictionary<NSString *, id> *)buttonTokens
      textTokens:(NSDictionary<NSString *, id> *)textTokens;
/// SDK v1 §3.1: the stored areas, as [key, value] pairs in order, read once at the widget's first touch of each area.
/// Set it before the boot.
- (void)setStoragePreloadLocal:(NSArray<NSArray<NSString *> *> *)local session:(NSArray<NSArray<NSString *> *> *)session;
/// SDK v1 §2.9: the client's UI language as a BCP 47 tag, navigator.language; a malformed one is en-US. Set it before
/// the boot.
- (void)setLocale:(NSString *)locale;
/// SDK v1 §2.13, §2.14 (widget-sandbox v0.2): the message's context, the server's flags as they are, the chat type
/// ("private", "group", "supergroup", "channel", or nil) and the viewer; fixed for the widget's life. Set it before the
/// boot. `wallet` (v0.5.0, §2.18): the client has Gram Wallet for this user.
- (void)setContextCopy:(BOOL)isCopy canQuery:(BOOL)canQuery backgroundQuery:(BOOL)backgroundQuery chatType:(nullable NSString *)chatType viewer:(nullable WRWidgetViewer *)viewer preview:(BOOL)preview wallet:(BOOL)wallet;
/// SDK v1 §2.13: the bot's state, as the server's bytes. Before the boot it is the state the widget starts with; after
/// it, a change: the widget gets chatDataChanged and publicDataChanged for the values that changed, in a task.
- (void)setChatData:(nullable NSData *)chatData publicData:(nullable NSData *)publicData;
/// SDK v1 §2.17 (widget-sandbox v0.4.0): what the client draws over the widget, in CSS px (checked: an inset 0–64, a
/// corner 0–200, else 0). Before the boot it is what the first layout has, with no event; after it, a change lays out
/// now and the widget gets a fresh TelegramWidget.contentSafeAreaInset and contentSafeAreaChanged, in a task. An equal
/// value is nothing.
- (void)setContentSafeAreaTop:(double)top right:(double)right bottom:(double)bottom left:(double)left cornerLeft:(double)cornerLeft cornerRight:(double)cornerRight;
/// SDK v1 §2.14: the client's outcome for the widget's request `requestId` (its `request` or `wallet` bridge call),
/// settled in a task; an answer's result is the server's bytes. An id the widget has no request out for is ignored.
- (void)completeRequest:(int64_t)requestId result:(nullable NSData *)result failure:(WRRequestFailure)failure;
- (void)setVisible:(BOOL)visible;
/// One phase of a tap at `point` (CSS px), queued as a task: a touch's.
- (void)pointer:(WRPointerPhase)phase at:(CGPoint)point pointerId:(int32_t)pointerId primary:(BOOL)primary;
/// The same for a mouse (`mouse`: an iPad pointer) pressing `button` (0 primary, 2 secondary), or a touch.
- (void)pointer:(WRPointerPhase)phase at:(CGPoint)point pointerId:(int32_t)pointerId primary:(BOOL)primary mouse:(BOOL)mouse button:(NSInteger)button;
/// sdk-v1 §5.5: the drags the last primary press takes for the widget (the touch-action of its target and the target's
/// ancestors, or a canceled pointerdown or touchstart), once a step has run its down task; none without a runtime.
@property (nonatomic, readonly) WRGestureAxes gestureClaim;
/// Whether the last primary press landed on something the widget handles (a press listener on its path, a link, a
/// button, a checkbox, a label, a summary, or a drag claim), once a step has run its down task; NO without a runtime.
/// The client takes a tap there at once and waits for a double tap anywhere else (sdk-v1 §5.5).
@property (nonatomic, readonly) BOOL pressTakesTaps;
/// The newest press's down task has not run yet: `gestureClaim` and `pressTakesTaps` still answer the press before it.
@property (nonatomic, readonly) BOOL pressDownPending;
/// The edge the widget asked to stay put when its height changes (`TelegramWidget.setResizeAnchor`), reported with the
/// height; Top until it asks, and without a runtime.
@property (nonatomic, readonly) WRResizeAnchor resizeAnchor;

@property (nonatomic, readonly) WRStopReason stopReason;
/// A Limit, Cpu or LayoutQuery stop's reason, upstream's words ("Ops limit exceeded: 10001 operations in one batch (max
/// 10000)", "CPU limit exceeded: …"); nil for any other stop and while running. Kept after the runtime goes.
@property (nonatomic, readonly, nullable) NSString* stopDetail;
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
/// The selectable text of the current layout (sdk-v1 §5.10): no script runs, nothing is flushed, and nothing the widget
/// can observe changes. nil with no runtime or after a failure; a text with no runs when nothing is selectable. Text
/// wholly at or below `visibleHeight` CSS px is left out. Never stops or fails the session.
- (nullable WRSelectableText *)selectableTextWithVisibleHeight:(CGFloat)visibleHeight;
/// The live document's `<html>` attribute `name` (the conformance runner reads `data-conformance` there): no script
/// runs and nothing is flushed (the name's string, allocated in the widget's heap, is the only work). nil when absent,
/// before the boot, after a failure or teardown.
- (nullable NSString *)documentElementAttribute:(NSString *)name;

/// Tests only: `code` as a global script in one event-kind step (its CPU slice, its times recorded), then its
/// microtasks and a flush; its completion value as a string, or nil when there is no runtime or the script stopped it.
- (nullable NSString *)evaluateForTesting:(NSString *)code;
/// Tests only: the border box (CSS px) of the first element `selector` matches, at the current layout; CGRectNull when
/// nothing matches, the selector does not parse, or the element has no box. Public, as evaluateForTesting: is, because
/// MessageWidget's test support reaches it through MessageWidgetCore across the module boundary.
- (CGRect)borderBoxForTesting:(NSString *)selector;

@end

NS_ASSUME_NONNULL_END
