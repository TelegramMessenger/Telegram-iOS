#import <TargetConditionals.h>
#if TARGET_OS_IOS

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void IDPrivateRegisterTextLayoutCanvas(id layoutController,
                                                          NSTextContainer *textContainer,
                                                          UIView *canvas);
FOUNDATION_EXPORT UIView * _Nullable IDPrivateRegisteredTextLayoutCanvas(
    id layoutController,
    NSTextContainer *textContainer);
FOUNDATION_EXPORT void IDPrivateSetContinuousSpellCheckingEnabled(id inputController,
                                                                   BOOL enabled);
FOUNDATION_EXPORT BOOL IDPrivateContinuousSpellCheckingEnabled(id inputController);
FOUNDATION_EXPORT id _Nullable IDPrivateCanvasCustomRenderController(id context);
FOUNDATION_EXPORT UIColor *IDPrivateCanvasTextColor(id _Nullable context);
FOUNDATION_EXPORT CGPoint IDPrivateCanvasContextTextContainerOrigin(id _Nullable context);
FOUNDATION_EXPORT CGRect IDPrivateCanvasContextClipRectForFadedEdges(id _Nullable context);
FOUNDATION_EXPORT BOOL IDPrivateCanvasTextRangeIsEmpty(id textRange);
FOUNDATION_EXPORT NSRange IDPrivateCanvasNSRangeForTextKitRange(UIView *textView,
                                                                id textRange);
FOUNDATION_EXPORT NSTextStorage *IDPrivateCanvasTextStorage(UIView *textView);
FOUNDATION_EXPORT void IDPrivateCanvasSetEmphasisTextRange(UIView *emphasisView,
                                                            id textRange);
FOUNDATION_EXPORT void IDPrivateCanvasSetEmphasisOrigin(UIView *emphasisView,
                                                         CGPoint origin);
typedef void (^IDPrivateCanvasSurfaceConsumer)(NSTextLayoutFragment *layoutFragment,
                                               id surface);
FOUNDATION_EXPORT void IDPrivateCanvasPrepareCustomRenderer(id customRenderController,
                                                            CGFloat contentsScale);
FOUNDATION_EXPORT void IDPrivateCanvasCustomRendererBeginLayout(id customRenderController);
FOUNDATION_EXPORT void IDPrivateCanvasCustomRendererPreLayoutNotify(id customRenderController);
FOUNDATION_EXPORT void IDPrivateCanvasCustomRendererDidLayoutFragment(
    id customRenderController,
    NSTextLayoutFragment *layoutFragment);
FOUNDATION_EXPORT void IDPrivateCanvasCustomRendererEndLayout(
    id customRenderController,
    IDPrivateCanvasSurfaceConsumer consumer);
FOUNDATION_EXPORT UIView *IDPrivateCanvasRequireCustomEndConsumerHost(
    UIView * _Nullable surface,
    Class expectedHostClass);
FOUNDATION_EXPORT void IDPrivateCanvasCustomRendererPostLayoutNotify(id customRenderController);
FOUNDATION_EXPORT CALayer *IDPrivateCanvasCustomSurfaceLayer(id surface);
FOUNDATION_EXPORT void IDPrivateCanvasSetNeedsDisplay(id customRenderController);
FOUNDATION_EXPORT BOOL IDPrivateCanvasCanInvalidateTemporaryAttributes(
    id customRenderController);
FOUNDATION_EXPORT NSArray *IDPrivateTextKit2Ranges(id rangeAdapter);
FOUNDATION_EXPORT void IDPrivateCanvasInvalidateTemporaryAttributes(
    id customRenderController,
    id textKit2Range);
FOUNDATION_EXPORT void IDPrivateCanvasSetHostsLayoutEngine(UIView * _Nullable view,
                                                            BOOL hostsLayoutEngine);
FOUNDATION_EXPORT CGRect IDPrivateCanvasParagraphAnchoredBounds(
    NSTextLayoutFragment *fragment,
    id attachment);
FOUNDATION_EXPORT id _Nullable IDPrivateCanvasParagraphAnchoredProvider(
    NSTextLayoutFragment *fragment,
    id attachment);
FOUNDATION_EXPORT UIView * _Nullable IDPrivateCanvasAttachmentProviderView(id provider);
FOUNDATION_EXPORT void IDPrivateCanvasDrawParagraphAnchoredAttachment(
    NSTextLayoutFragment *fragment,
    id attachment,
    CGRect bounds,
    CGContextRef context);
typedef void (^IDPrivateCanvasPlatformSurfaceUpdater)(
    id viewportLayoutController,
    id _Nullable textRange,
    CGRect bounds);
FOUNDATION_EXPORT BOOL IDPrivateCanvasInstallPlatformSurfaceUpdaterIfAvailable(
    NSTextViewportLayoutController *controller,
    IDPrivateCanvasPlatformSurfaceUpdater updater);
FOUNDATION_EXPORT BOOL IDPrivateCanvasClearPlatformSurfaceUpdaterIfAvailable(
    NSTextViewportLayoutController *controller);
FOUNDATION_EXPORT void IDPrivateCanvasNotifyContextDidLayout(id _Nullable context);
FOUNDATION_EXPORT void IDPrivateCanvasUpdateContextInteractionGeometry(id _Nullable context);
FOUNDATION_EXPORT BOOL IDPrivateCanvasContextIsEditing(id _Nullable context);
FOUNDATION_EXPORT BOOL IDPrivateCanvasContextIsEditable(id _Nullable context);
FOUNDATION_EXPORT BOOL IDPrivateCanvasSupportsAnchoredTextAttachments(
    id _Nullable textContentManager);
FOUNDATION_EXPORT NSArray *IDPrivateCanvasAnchoredTextAttachments(
    NSTextLayoutFragment *fragment);

NS_ASSUME_NONNULL_END

#endif
