#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDUIKitBehaviorReport.h"
#import "IDUIKitCapabilityResolver.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const
    IDUIKitInteractionCapabilityErrorDomain;
FOUNDATION_EXPORT IDUIKitRuntimeCapabilityContract *
    IDUIKitInteractionRuntimeContract(void);

@interface IDUIKitInteractionCapability : NSObject

@property(nonatomic, strong, readonly, nullable) id privateAssistant;
@property(nonatomic, strong, readonly) IDUIKitCapabilityReport *report;
@property(nonatomic, strong, readonly)
    IDUIKitCapabilityReport *floatingCursorReport;

- (nullable instancetype)initWithContract:
    (IDUIKitRuntimeCapabilityContract *)contract
                                resolver:(IDUIKitCapabilityResolver *)resolver
                                    view:(UIView *)view
                                   error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;

- (void)setSelectionActive:(BOOL)active visible:(BOOL)visible;
- (void)id_selectionChanged;
- (void)id_setNeedsSelectionDisplayUpdate;
- (void)setGestureRecognizersEnabled:(BOOL)enabled;
- (void)clearGestureRecognizersForced:(BOOL)forced;
- (void)beginFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point
                           animated:(BOOL)animated;
- (void)endFloatingCursor;
- (void)id_resignedFirstResponder;
- (void)id_selectWord;
- (void)selectAll:(nullable id)sender;
- (void)id_autoscrollWillNotStart;
/// Tells the assistant an autoscroll session has ticked, which is what the stock session's timer
/// does on every tick, whether or not it then scrolls anything (the assistant's `autoscrolled` bit).
/// The text interaction reads that bit when a loupe ends: while it is clear, a loupe that began within
/// 40pt of the caret is treated as having dragged the caret by its offset and puts the caret back
/// where it started, so a long press beside the caret appears to do nothing. The engine runs its own
/// autoscroll sessions (`IDVerticalAutoscroll`), so it reports their ticks here. An UNINVENTORIED
/// private send, guarded by the method's shape: it is absent from the vendored contract manifest,
/// which is pinned and whose generator is not in this repo (composer harness, 2026-09-24,
/// `HarnessLongPressCaretUITests`).
- (void)autoscrollDidTick;
- (void)detach;

@end

NS_ASSUME_NONNULL_END

#endif
