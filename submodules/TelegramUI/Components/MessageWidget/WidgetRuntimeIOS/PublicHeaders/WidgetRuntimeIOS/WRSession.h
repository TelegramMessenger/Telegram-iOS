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

@class WRSession;

@protocol WRSessionDelegate <NSObject>
- (void)session:(WRSession *)session diagnostic:(NSString *)kind detail:(NSString *)detail;
- (void)session:(WRSession *)session log:(NSInteger)level text:(NSString *)text;
/// A bridge call: the method, and its arguments as a JSON array of strings. The session applies no policy.
- (void)session:(WRSession *)session bridge:(NSString *)method args:(NSString *)argsJson;
/// The work counter, at least every 10,000 units while a step runs: what feeds main's wait meter.
- (void)session:(WRSession *)session didWork:(uint64_t)totalUnits;
@optional
/// SDK v1 §3.2: the whole content of a storage area (`local` or `session`) a task changed, as [key, value] pairs in
/// insertion order, at the end of that task. Not after the widget has stopped.
- (void)session:(WRSession *)session storageCommit:(NSString *)area entries:(NSArray<NSArray<NSString *> *> *)entries;
/// widget-sandbox's `intl` capability: a request as its shim sends one, the answer as its glue gives it (the app's
/// delegate hands it to that glue, widget-sandbox's IntlBridge). All of Intl's locale data comes from here; without it
/// every format is "". Charged before it is asked.
- (NSString *)session:(WRSession *)session intl:(NSString *)requestJson;
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
/// 4096 a side; nil past that or for an empty rect.
- (nullable CGImageRef)copyImageOfRect:(CGRect)rect scale:(CGFloat)scale CF_RETURNS_RETAINED;
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
/// What the export spent, in work units (its own, never the widget's).
@property (nonatomic, readonly) uint64_t units;
@end

@interface WRSession : NSObject

/// The runtime (64 MiB of memory, a 1 MiB stack), its host and its render tree, laid out at `width` CSS px in the
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
/// The edge the widget asked to stay put when its height changes (`TelegramWidget.setResizeAnchor`), reported with the
/// height; Top until it asks, and without a runtime.
@property (nonatomic, readonly) WRResizeAnchor resizeAnchor;

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
/// The selectable text of the current layout (sdk-v1 §5.10) on its own work budget: no script runs, nothing is
/// flushed, and nothing the widget can observe changes (its work units included). nil past the budget, with no runtime
/// or after a failure; a text with no runs when nothing is selectable. Text wholly at or below `visibleHeight` CSS px
/// is left out. Never stops or fails the session.
- (nullable WRSelectableText *)selectableTextWithBudget:(uint64_t)units visibleHeight:(CGFloat)visibleHeight;
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
