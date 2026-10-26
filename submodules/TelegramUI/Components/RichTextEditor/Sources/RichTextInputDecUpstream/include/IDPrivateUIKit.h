#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface IDPrivateUIKit : NSObject

@property(class, nonatomic, readonly, getter=isCompatible) BOOL compatible;
@property(class, nonatomic, copy, readonly) NSString *compatibilityReport;

+ (void)requireCompatibleRuntime;
+ (void)requireObject:(nullable id)object stage:(NSString *)stage;
+ (void)requireObject:(nullable id)object
    respondsToSelector:(SEL)selector
                 stage:(NSString *)stage;
+ (nullable id)newLayoutControllerWithTextView:(UIView *)textView
                                 textContainer:(NSTextContainer *)textContainer;
+ (nullable id)newInputControllerWithLayoutController:(id)layoutController
                                              delegate:(id)delegate;
+ (nullable id)newInteractionAssistantWithView:(UIView *)view;
+ (void)requireInteractionHost:(id)host stage:(NSString *)stage;
+ (void)requireInteractionAssistant:(nullable id)assistant stage:(NSString *)stage;
+ (void)installKeyboardInputSupportOnClass:(Class)viewClass;
+ (void)installTextPasteSupportOnClass:(Class)viewClass;
+ (void)installTextAutoscrollingSupportOnClass:(Class)viewClass;
+ (BOOL)adoptResolvedTextAutoscrollingProtocol:(Protocol *)protocol
                                       onClass:(Class)viewClass;

@end

FOUNDATION_EXPORT void IDPrivateInteractionSelectionChanged(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionActivateSelection(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionDeactivateSelection(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionSetSelectionVisible(id _Nullable assistant, BOOL visible);
FOUNDATION_EXPORT void IDPrivateInteractionSetNeedsSelectionDisplayUpdate(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionSetGestureRecognizers(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionClearGestureRecognizers(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionClearGestureRecognizersNonforced(
    id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionResignedFirstResponder(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionDetach(id _Nullable assistant, BOOL force);
FOUNDATION_EXPORT void IDPrivateInteractionBeginFloatingCursor(id _Nullable assistant, CGPoint point);
FOUNDATION_EXPORT void IDPrivateInteractionUpdateFloatingCursor(id _Nullable assistant, CGPoint point, BOOL animated);
FOUNDATION_EXPORT void IDPrivateInteractionEndFloatingCursor(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionSelectWord(id _Nullable assistant);
FOUNDATION_EXPORT void IDPrivateInteractionSelectAll(id _Nullable assistant, id _Nullable sender);
FOUNDATION_EXPORT void IDPrivateInteractionAutoscrollWillNotStart(id _Nullable assistant);
FOUNDATION_EXPORT id IDPrivateDefaultTextInputTraits(void);
FOUNDATION_EXPORT id IDPrivateInputTextInputTraits(id inputController);
FOUNDATION_EXPORT void IDPrivateSynchronizeTextInputTraits(
    id inputController,
    id<UITextInputTraits> source);
FOUNDATION_EXPORT id _Nullable IDPrivateNewTextAutoscroll(void);
FOUNDATION_EXPORT BOOL IDPrivateTextAutoscrollStart(id autoscroll,
                                                    id target,
                                                    UIScrollView *scrollContainer,
                                                    CGPoint point,
                                                    NSUInteger directions,
                                                    NSTimeInterval repeatInterval);
FOUNDATION_EXPORT void IDPrivateTextAutoscrollInvalidate(id _Nullable autoscroll);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateTestingFloatingCursorLifecycleSnapshot(UIView *textInput);
FOUNDATION_EXPORT NSUInteger
IDPrivateFloatingContainerCreationCountForUITesting(UIView *textInput);
FOUNDATION_EXPORT void IDPrivateResetRecognizerBaselineForUITesting(UIView *textInput);
FOUNDATION_EXPORT void IDInstallAutocorrectionTraceForUITesting(void);
FOUNDATION_EXPORT void IDRecordAutocorrectionTraceForUITesting(NSString *event);
FOUNDATION_EXPORT NSArray<NSString *> *IDCopyAutocorrectionTraceForUITesting(void);
FOUNDATION_EXPORT void IDResetAutocorrectionTraceForUITesting(void);
FOUNDATION_EXPORT BOOL IDPrivateDismissInlineTextCompletionForUITesting(void);
FOUNDATION_EXPORT UIView *IDPrivateNewStockOracleTextView(Class baseClass, CGRect frame);
FOUNDATION_EXPORT void IDPrivateInstallStockCursorTraceForUITesting(UIView *editor);
FOUNDATION_EXPORT NSDictionary<NSString *, id> * _Nullable
IDPrivateCopyStockCursorTraceForUITesting(UIView *editor);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateCopyStockFloatingLifecycleStateForUITesting(UIView *editor);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateCopyFloatingLifecycleStateForUITesting(UIView *editor);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
    UIView *editor,
    id layoutController);
FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDPrivateCopyStockVisibleSelectionHandlesForUITesting(UIView *root);
FOUNDATION_EXPORT void IDPrivateTestingRequestResponderLoss(UIView *view);
FOUNDATION_EXPORT void IDPrivateTestingRequestKeyboardDismissal(UIView *view);
FOUNDATION_EXPORT void IDPrivateTestingRequestEditableOff(UIView *view);
FOUNDATION_EXPORT void IDPrivateTestingRequestSelectableOff(UIView *view);
FOUNDATION_EXPORT void IDPrivateTestingRequestWindowDetach(UIView *view);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateCopyKeyboardInputDelegateOwnershipForUITesting(
    UIView *editor, UIView *handoff);

@interface IDPrivateFloatingLifecycleWeakReferences : NSObject
- (instancetype)initWithEditor:(UIView *)editor;
- (instancetype)initWithEditor:(UIView *)editor
               layoutController:(id)layoutController;
- (void)refreshWithEditor:(UIView *)editor;
- (void)refreshWithEditor:(UIView *)editor
          layoutController:(id)layoutController;
- (NSDictionary<NSString *, NSNumber *> *)copyRetentionState;
- (NSDictionary<NSString *, id> *)copyAtomicFloatingSnapshot;
- (NSDictionary<NSString *, id> * _Nullable)copyTerminalSnapshot;
- (void)markReleaseAttemptAfterTerminalEvent:(NSString *)event
                                       count:(NSUInteger)count
                               terminalEpoch:(CFTimeInterval)terminalEpoch
                             liftTargetEpoch:(CFTimeInterval)liftTargetEpoch;
- (void)markTerminalObservationForEvent:(NSString *)event
                                  count:(NSUInteger)count
                          terminalEpoch:(CFTimeInterval)terminalEpoch
                        liftTargetEpoch:(CFTimeInterval)liftTargetEpoch;
- (void)markActionObservationAtEpoch:(CFTimeInterval)actionEpoch
                     liftDelay:(NSTimeInterval)liftDelay;
- (void)recordImmediateReleaseSnapshot;
- (void)beginHeldSnapshotPollingForTerminalEvent:(NSString *)event;
- (void)scheduleReleaseSnapshots;
- (NSDictionary<NSString *, id> * _Nullable)copyReleaseSnapshotForPhase:(NSString *)phase;
@end
typedef void (^IDPrivateFloatingLifecycleTerminalObserver)(
    NSString *event, NSUInteger count, CFTimeInterval terminalEpoch);
FOUNDATION_EXPORT void IDPrivateSetFloatingLifecycleTerminalObserverForUITesting(
    UIScrollView *scrollContainer, NSString *event,
    IDPrivateFloatingLifecycleTerminalObserver _Nullable observer);
FOUNDATION_EXPORT void IDPrivateSetFloatingLifecycleActionObserverForUITesting(
    UIScrollView *scrollContainer, NSString *event,
    IDPrivateFloatingLifecycleTerminalObserver _Nullable observer);
FOUNDATION_EXPORT void IDPrivateRecordTextAutoscrollStartForUITesting(
    UIScrollView *scrollContainer, CGPoint assistantPoint, CGPoint hostPoint,
    CGRect visible, CGRect safe, NSUInteger directions, NSString *engine);
FOUNDATION_EXPORT void IDPrivateRecordTextAutoscrollCancelForUITesting(
    UIScrollView *scrollContainer);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateCopyTextAutoscrollTraceForUITesting(UIScrollView *scrollContainer);
FOUNDATION_EXPORT void IDPrivateRecordFloatingLifecycleEventForUITesting(
    UIScrollView *scrollContainer, NSString *event);
FOUNDATION_EXPORT CGRect IDPrivateTextAutoscrollSafeRect(UIScrollView *scrollContainer,
                                                         UIEdgeInsets textInsets,
                                                         CGFloat edgeInset);
FOUNDATION_EXPORT NSUInteger IDPrivateTextAutoscrollDirections(
    UIScrollView *scrollContainer, UIEdgeInsets textInsets,
    CGPoint point, CGFloat edgeInset);
FOUNDATION_EXPORT UITextPosition *IDPrivateTestingCursorPositionAtPoint(
    UIView *textInput, id _Nullable layoutController, CGPoint point,
    id _Nullable * _Nullable textContainer);
FOUNDATION_EXPORT id _Nullable IDPrivateTestingInternalTextLayoutController(UIView *textInput);
FOUNDATION_EXPORT id _Nullable IDPrivateTestingCustomRenderController(UIView *textInput);
FOUNDATION_EXPORT CGPoint IDPrivateTestingConvertPointFromRenderSpace(
    UIView *textInput, CGPoint point);
FOUNDATION_EXPORT CGPoint IDPrivateTestingTextContainerOrigin(UIView *containerView);
FOUNDATION_EXPORT void IDPrivateTestingWithTextContainerInsetAdjustment(
    UIScrollView *scrollContainer, UIEdgeInsets adjustment,
    void (NS_NOESCAPE ^body)(void));
FOUNDATION_EXPORT CGRect IDPrivateTestingTextAutoscrollSafeRectWithGeometry(
    CGRect visible, UIEdgeInsets textInsets, UIEdgeInsets insetAdjustment,
    CGFloat horizontalAdjustment, UIEdgeInsets effectiveContentInset,
    CGFloat edgeInset);
FOUNDATION_EXPORT id IDPrivateTestingNewUIKitAutoscroll(void);
FOUNDATION_EXPORT BOOL IDPrivateTestingStartUIKitAutoscroll(
    id autoscroll, id target,
    UIScrollView * _Nullable scrollContainer, CGPoint point,
    NSUInteger directions, NSTimeInterval repeatInterval);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *
IDPrivateTestingCopyUIKitAutoscrollSnapshot(id autoscroll);
FOUNDATION_EXPORT void
IDPrivateTestingSetUIKitAutoscrollDisabled(id autoscroll, BOOL disabled);
FOUNDATION_EXPORT void
IDPrivateTestingFireUIKitAutoscroll(id autoscroll);
FOUNDATION_EXPORT void
IDPrivateTestingInvalidateUIKitAutoscroll(id _Nullable autoscroll);
typedef NS_ENUM(NSUInteger, IDPrivateTestingIncompatibleAutoscrollIvar) {
    IDPrivateTestingIncompatibleAutoscrollIvarTextContainerInsetAdjustment,
    IDPrivateTestingIncompatibleAutoscrollIvarHorizontalGeometryAdjustment,
};
FOUNDATION_EXPORT UIScrollView *IDPrivateTestingNewTextAutoscrollHostWithIncompatibleIvar(
    IDPrivateTestingIncompatibleAutoscrollIvar incompatibleIvar);
FOUNDATION_EXPORT NSArray<NSValue *> *IDPrivateVisibleSelectionHandleRects(UIView *root);
FOUNDATION_EXPORT void IDPrivateKeyboardInputChangedSelection(id _Nullable delegate,
                                                              id _Nullable input);
FOUNDATION_EXPORT NSUndoManager * _Nullable IDPrivateInputUndoManager(id _Nullable controller);
FOUNDATION_EXPORT void IDPrivateInputCut(id _Nullable controller, id _Nullable sender);
FOUNDATION_EXPORT void IDPrivateInputCopy(id _Nullable controller, id _Nullable sender);
FOUNDATION_EXPORT void IDPrivateInputPaste(id _Nullable controller, id _Nullable sender);
FOUNDATION_EXPORT BOOL IDPrivateInputShouldHandlePaste(id _Nullable controller,
                                                       id _Nullable sender);
FOUNDATION_EXPORT UITextStorageDirection IDPrivateInputSelectionAffinity(id _Nullable controller);
FOUNDATION_EXPORT NSDictionary<NSAttributedStringKey, id> *
IDPrivateInputTypingAttributes(id controller);
FOUNDATION_EXPORT void IDPrivateInputSetTypingAttributes(
    id controller,
    NSDictionary<NSAttributedStringKey, id> *attributes);
FOUNDATION_EXPORT void IDPrivateInputAllowTypingAttributeNames(
    id controller,
    NSSet<NSAttributedStringKey> *attributeNames);
FOUNDATION_EXPORT void IDPrivateInputInvalidateTypingAttributes(id controller);
FOUNDATION_EXPORT void IDPrivateInputPerformWhileSuppressingDelegateNotifications(
    id _Nullable controller, void (NS_NOESCAPE ^body)(void));
FOUNDATION_EXPORT void IDPrivateInputPreflightBackwardDeleteRanges(id _Nullable controller);
FOUNDATION_EXPORT void IDPrivateInputDetachFromLayoutManager(id _Nullable controller);
FOUNDATION_EXPORT NSRange IDPrivateInputBackwardDeleteRange(id _Nullable controller);
FOUNDATION_EXPORT BOOL IDPrivateTextViewShouldDelete(id textView, id _Nullable input);
FOUNDATION_EXPORT NSUInteger IDPrivateTextKit2RangeCount(id _Nullable range);
FOUNDATION_EXPORT NSArray *IDPrivateLayoutSelectionRects(id _Nullable layoutController,
                                                         id _Nullable range,
                                                         UIView *fromView);
FOUNDATION_EXPORT void IDPrivateTextContainerSetTextView(NSTextContainer *textContainer,
                                                          UIView * _Nullable textView);
FOUNDATION_EXPORT UIView * _Nullable IDPrivateTextContainerTextView(NSTextContainer *textContainer);
FOUNDATION_EXPORT void IDPrivateRequireTextContainerHost(id host, NSString *stage);

FOUNDATION_EXPORT BOOL IDPrivateRespondsToSelector(id target, SEL selector);
FOUNDATION_EXPORT id _Nullable IDPrivateObject0(id target, SEL selector);
FOUNDATION_EXPORT id _Nullable IDPrivateObject1(id target, SEL selector, id _Nullable value);
FOUNDATION_EXPORT id _Nullable IDPrivateObject2(id target,
                                                SEL selector,
                                                id _Nullable first,
                                                id _Nullable second);
FOUNDATION_EXPORT id _Nullable IDPrivateObjectObjectInteger(id target,
                                                            SEL selector,
                                                            id value,
                                                            NSInteger integer);
FOUNDATION_EXPORT id _Nullable IDPrivateObjectObjectIntegerInteger(id target,
                                                                   SEL selector,
                                                                   id value,
                                                                   NSInteger firstInteger,
                                                                   NSInteger secondInteger);
FOUNDATION_EXPORT id _Nullable IDPrivateObjectPoint(id target, SEL selector, CGPoint point);
FOUNDATION_EXPORT id _Nullable IDPrivateObjectPointObject(id target,
                                                          SEL selector,
                                                          CGPoint point,
                                                          id value);
FOUNDATION_EXPORT NSInteger IDPrivateInteger2(id target, SEL selector, id first, id second);
FOUNDATION_EXPORT NSInteger IDPrivateIntegerObjectInteger(id target,
                                                          SEL selector,
                                                          id value,
                                                          NSInteger integer);
FOUNDATION_EXPORT CGRect IDPrivateRectObject(id target, SEL selector, id value);
FOUNDATION_EXPORT void IDPrivateVoid0(id target, SEL selector);
FOUNDATION_EXPORT void IDPrivateVoid1(id target, SEL selector, id _Nullable value);
FOUNDATION_EXPORT void IDPrivateVoid2(id target,
                                      SEL selector,
                                      id _Nullable first,
                                      id _Nullable second);
FOUNDATION_EXPORT void IDPrivateVoidObjectRange(id target,
                                                SEL selector,
                                                id _Nullable value,
                                                NSRange range);
FOUNDATION_EXPORT void IDPrivateVoidIntegerObject(id target,
                                                  SEL selector,
                                                  NSInteger integer,
                                                  id value);

NS_ASSUME_NONNULL_END

#endif
