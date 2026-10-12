#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextLayoutCanvasView.h"

#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextCanvasAttachmentCoordinator.h"
#import "IDTextCanvasAttachmentLifecycle.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

#include <math.h>

@interface IDTextCustomRenderingHostingView : IDTextRenderingSurfaceView

@property(nonatomic, strong, nullable) id hostedSurface;
@property(nonatomic, strong, nullable) CALayer *hostedLayer;
- (void)updateWithSurface:(id)hostedSurface;
- (void)teardown;

@end

@implementation IDTextCustomRenderingHostingView

- (void)updateWithSurface:(id)hostedSurface {
    CALayer *hostedLayer = IDPrivateCanvasCustomSurfaceLayer(hostedSurface);
    if (_hostedSurface == hostedSurface && _hostedLayer == hostedLayer) {
        [self id_updateHostedLayerGeometry];
        return;
    }
    if (_hostedLayer.superlayer == self.layer) {
        [_hostedLayer removeFromSuperlayer];
    }
    _hostedSurface = hostedSurface;
    _hostedLayer = hostedLayer;
    hostedLayer.anchorPoint = CGPointZero;
    hostedLayer.position = self.bounds.origin;
    [self id_updateHostedLayerGeometry];
    [self.layer addSublayer:hostedLayer];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self id_updateHostedLayerGeometry];
}

- (void)setNeedsDisplay {
    [self.hostedLayer setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    return hitView == self ? nil : hitView;
}

- (void)teardown {
    if (self.hostedLayer.superlayer == self.layer) {
        [self.hostedLayer removeFromSuperlayer];
    }
    self.hostedLayer = nil;
    self.hostedSurface = nil;
    [super teardown];
}

- (void)id_updateHostedLayerGeometry {
    self.hostedLayer.bounds = self.bounds;
    self.hostedLayer.anchorPoint = CGPointZero;
    self.hostedLayer.position = self.bounds.origin;
}

@end

static CGFloat IDTextCanvasDisplayScale(UIView *view) {
    CGFloat scale = view.traitCollection.displayScale;
    return scale > 0 && isfinite(scale) ? scale : 1.0;
}

static BOOL IDTextCanvasContentSizeForUsageBounds(
    CGRect usageBounds,
    CGSize *contentSizeOut
) {
    if (contentSizeOut == NULL ||
        !isfinite(usageBounds.origin.x) ||
        !isfinite(usageBounds.origin.y) ||
        !isfinite(usageBounds.size.width) ||
        !isfinite(usageBounds.size.height)) {
        return NO;
    }
    CGFloat maxX = CGRectGetMaxX(usageBounds);
    CGFloat maxY = CGRectGetMaxY(usageBounds);
    if (!isfinite(maxX) || !isfinite(maxY)) {
        return NO;
    }
    *contentSizeOut = CGSizeMake(MAX(maxX, 0), MAX(maxY, 0));
    return YES;
}

@class IDTextLayoutCanvasView;

@interface IDTextParagraphAnchoredAttachmentSurface : UIView

@property(nonatomic, weak, nullable) IDTextLayoutCanvasView *canvas;
@property(nonatomic, weak, nullable) id attachment;
@property(nonatomic, weak, nullable) NSTextLayoutFragment *layoutFragment;
@property(nonatomic, strong, nullable) id attachmentViewProvider;
- (instancetype)initWithCanvas:(IDTextLayoutCanvasView *)canvas attachment:(id)attachment;
- (void)teardown;

@end

@implementation IDTextParagraphAnchoredAttachmentSurface

- (void)setLayoutFragment:(NSTextLayoutFragment *)layoutFragment {
    if (_layoutFragment == layoutFragment) {
        return;
    }
    _layoutFragment = layoutFragment;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (UIViewAutoresizing)autoresizingMask {
    return UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (instancetype)initWithCanvas:(IDTextLayoutCanvasView *)canvas attachment:(id)attachment {
    self = [super initWithFrame:canvas.bounds];
    if (self != nil) {
        _canvas = canvas;
        _attachment = attachment;
        self.opaque = NO;
        self.clipsToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;
        IDPrivateCanvasSetHostsLayoutEngine(self, YES);
    }
    return self;
}

- (void)layoutSubviews {
    IDTextLayoutCanvasView *canvas = self.canvas;
    NSTextLayoutFragment *fragment = self.layoutFragment;
    id attachment = self.attachment;
    if (canvas == nil || fragment == nil || attachment == nil) {
        self.attachmentViewProvider = nil;
        [super layoutSubviews];
        return;
    }
    self.frame = [canvas id_frameForParagraphAnchoredAttachment:attachment
                                             layoutFragment:fragment];
    [super layoutSubviews];
    if (self.attachmentViewProvider == nil) {
        self.attachmentViewProvider =
            IDPrivateCanvasParagraphAnchoredProvider(fragment, attachment);
    }
    UIView *providerView =
        IDPrivateCanvasAttachmentProviderView(self.attachmentViewProvider);
    if (providerView != nil && providerView.superview != self) {
        [self addSubview:providerView];
    }
    providerView.frame = self.bounds;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.layoutFragment == nil || self.attachment == nil || context == NULL) {
        return;
    }
    if (IDPrivateCanvasAttachmentProviderView(self.attachmentViewProvider) != nil) {
        return;
    }
    IDPrivateCanvasDrawParagraphAnchoredAttachment(self.layoutFragment,
                                                   self.attachment,
                                                   self.bounds,
                                                   context);
}

- (void)teardown {
    [IDPrivateCanvasAttachmentProviderView(self.attachmentViewProvider) removeFromSuperview];
    self.attachmentViewProvider = nil;
    self.layoutFragment = nil;
    self.attachment = nil;
}

@end

@interface IDTextLayoutCanvasView ()

@property(nonatomic, strong, readwrite) NSTextLayoutManager *textLayoutManager;
@property(nonatomic, strong, readwrite) NSTextContainer *textContainer;
@property(nonatomic, strong, readwrite) NSTextViewportLayoutController *textViewportLayoutController;

@end


// `IDTextLayoutCanvasView+PrivateCallbacks.m`: adds the callbacks UIKit sends under private names.
FOUNDATION_EXTERN void IDTextLayoutCanvasViewInstallPrivateCallbacks(Class cls);

@implementation IDTextLayoutCanvasView

+ (void)initialize {
    IDTextLayoutCanvasViewInstallPrivateCallbacks(self);
}

@synthesize layoutFragmentViewsNeedDisplay = _layoutFragmentViewsNeedDisplay;

- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)layoutManager
                            textContainer:(NSTextContainer *)textContainer {
    self = [super initWithFrame:CGRectZero];
    if (self == nil) {
        return nil;
    }

    _textLayoutManager = layoutManager;
    _textContainer = textContainer;
    _textViewportLayoutController = layoutManager.textViewportLayoutController;
    _textViewportLayoutController.delegate =
        (id<NSTextViewportLayoutControllerDelegate>)self;
    _fragmentSurfaces = [NSMapTable weakToStrongObjectsMapTable];
    _unusedFragmentKeys = [NSHashTable weakObjectsHashTable];
    _attachmentCoordinator = [IDTextCanvasAttachmentCoordinator new];
    _externalSurfaces = [NSMutableSet set];
    _unusedExternalSurfaces = [NSMutableSet set];
    _anchoredAttachmentSurfaces = [NSMapTable strongToStrongObjectsMapTable];
    _nativeSurfaceViewClass = IDTextRenderingSurfaceView.class;
    _viewportOverride = CGRectNull;
    _cachedContentSize = CGSizeMake(NAN, NAN);
    self.contentMode = UIViewContentModeRedraw;
    self.opaque = NO;
    return self;
}

- (void)setContext:(id)context {
    _context = context;
    self.attachmentCoordinator.lifecycleSink =
        [context conformsToProtocol:@protocol(IDTextCanvasAttachmentLifecycleSink)]
            ? context
            : nil;
}

- (CGPoint)id_textContainerOrigin {
    return IDPrivateCanvasContextTextContainerOrigin(self.context);
}

- (id)id_textLayoutController {
    return self.textLayoutManager.delegate;
}

- (id)id_layoutManager {
    return nil;
}

- (id)id_customRenderController {
    return IDPrivateCanvasCustomRenderController(self.context);
}

- (UIColor *)id_textColor {
    return IDPrivateCanvasTextColor(self.context);
}

- (BOOL)id_isEditable {
    return IDPrivateCanvasContextIsEditable(self.context);
}

- (BOOL)id_isEditing {
    return IDPrivateCanvasContextIsEditing(self.context);
}

- (void)id_textKit2CanvasDidLayout {
    IDPrivateCanvasNotifyContextDidLayout(self.context);
}

- (void)id_updateInteractionGeometry {
    IDPrivateCanvasUpdateContextInteractionGeometry(self.context);
}

- (void)setFrame:(CGRect)frame {
    BOOL changed = !CGRectEqualToRect(self.frame, frame);
    [super setFrame:frame];
    if (changed) {
        [self setNeedsLayout];
    }
}

- (void)setBounds:(CGRect)bounds {
    BOOL changed = !CGRectEqualToRect(self.bounds, bounds);
    [super setBounds:bounds];
    if (changed) {
        [self setNeedsLayout];
    }
}

- (void)setNeedsDisplay {
    [super setNeedsDisplay];
    self.layoutFragmentViewsNeedDisplay = YES;
    [self setNeedsLayout];
}

- (void)setLayoutFragmentViewsNeedDisplay:(BOOL)needsDisplay {
    _layoutFragmentViewsNeedDisplay = needsDisplay;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    return hitView == self ? nil : hitView;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self performViewportLayout];
    if (self.id_hoverEffectContainerLayer != nil) {
        self.id_hoverEffectContainerLayer.frame = self.layer.bounds;
        self.id_hoverEffectContainerLayer.hidden = IDPrivateCanvasContextIsEditing(self.context);
    }
    if (self.id_selectionContainerView.superview == self) {
        self.id_selectionContainerView.frame = self.bounds;
    }
}

- (void)setId_selectionContainerView:(UIView *)selectionContainerView {
    if (_id_selectionContainerView == selectionContainerView) {
        return;
    }
    [_id_selectionContainerView removeFromSuperview];
    _id_selectionContainerView = selectionContainerView;
    if (selectionContainerView != nil) {
        [self addSubview:selectionContainerView];
    }
    [self setNeedsLayout];
}

- (void)performViewportLayout {
    if (self.performingViewportLayout || CGRectIsEmpty(self.bounds)) {
        return;
    }
    self.performingViewportLayout = YES;
    @try {
        [self id_viewportWillLayout];
        if (self.viewportLayoutTestHook != nil) {
            self.viewportLayoutTestHook();
        }
        [self.textViewportLayoutController layoutViewport];
        [self id_viewportDidLayout];
        self.completedViewportLayoutCount += 1;
    } @finally {
        self.performingViewportLayout = NO;
    }
}

- (void)viewportBoundsDidChange {
    [self setNeedsLayout];
}

- (CGRect)viewportBounds {
    if (!CGRectIsNull(self.viewportOverride)) {
        return self.viewportOverride;
    }
    UIView *host = self.superview;
    if (host == nil) {
        return self.bounds;
    }
    CGRect visibleBounds = [self convertRect:host.bounds fromView:host];
    CGRect viewport = CGRectIntersection(self.bounds, visibleBounds);
    return CGRectIsNull(viewport) ? CGRectZero : viewport;
}

- (NSUInteger)visibleSurfaceCount {
    return self.fragmentSurfaces.count + self.externalSurfaces.count;
}

- (NSArray<NSTextLayoutFragment *> *)visibleFragments {
    return self.fragmentSurfaces.keyEnumerator.allObjects;
}

- (NSArray<UIView *> *)visibleSurfaces {
    return self.fragmentSurfaces.objectEnumerator.allObjects;
}

- (UIView *)surfaceForFragment:(NSTextLayoutFragment *)fragment {
    return [self.fragmentSurfaces objectForKey:fragment];
}

- (void)setNativeSurfaceViewClass:(Class)nativeSurfaceViewClass {
    if (![nativeSurfaceViewClass isSubclassOfClass:IDTextRenderingSurfaceView.class]) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"nativeSurfaceViewClass must subclass IDTextRenderingSurfaceView"
                                     userInfo:nil];
    }
    _nativeSurfaceViewClass = nativeSurfaceViewClass;
}

- (void)id_notifyCustomRendererPreLayout {
    id renderer = IDPrivateCanvasCustomRenderController(self.context);
    self.currentCustomRenderController = renderer;
    if (self.lastCustomRenderController != renderer) {
        self.lastCustomRenderController = renderer;
        for (NSTextLayoutFragment *fragment in self.fragmentSurfaces.keyEnumerator.allObjects) {
            UIView *surface = [self.fragmentSurfaces objectForKey:fragment];
            if ([surface respondsToSelector:@selector(teardown)]) {
                [(id)surface teardown];
            }
            [surface removeFromSuperview];
            [self.fragmentSurfaces removeObjectForKey:fragment];
        }
        [self.unusedFragmentKeys removeAllObjects];
    }
    if (renderer == nil) {
        return;
    }
    IDPrivateCanvasPrepareCustomRenderer(renderer, IDTextCanvasDisplayScale(self));
    IDPrivateCanvasCustomRendererBeginLayout(renderer);
    IDPrivateCanvasCustomRendererPreLayoutNotify(renderer);
}

- (void)id_notifyCustomRendererPostLayout {
    id renderer = self.currentCustomRenderController;
    if (renderer == nil) {
        return;
    }
    __weak IDTextLayoutCanvasView *weakSelf = self;
    IDPrivateCanvasCustomRendererEndLayout(
        renderer,
        ^(NSTextLayoutFragment *fragment, id customSurface) {
            UIView *surface = [weakSelf.fragmentSurfaces objectForKey:fragment];
            IDTextCustomRenderingHostingView *hostingView =
                (IDTextCustomRenderingHostingView *)
                    IDPrivateCanvasRequireCustomEndConsumerHost(
                        surface,
                        IDTextCustomRenderingHostingView.class);
            [hostingView updateWithSurface:customSurface];
        });
    if (self.layoutFragmentViewsNeedDisplay) {
        IDPrivateCanvasSetNeedsDisplay(renderer);
        self.layoutFragmentViewsNeedDisplay = NO;
    }
    IDPrivateCanvasCustomRendererPostLayoutNotify(renderer);
    self.currentCustomRenderController = nil;
}

- (void)id_viewportWillLayout {
    [self.attachmentCoordinator beginViewportLayout];
    [self.unusedFragmentKeys removeAllObjects];
    for (NSTextLayoutFragment *fragment in self.fragmentSurfaces.keyEnumerator.allObjects) {
        [self.unusedFragmentKeys addObject:fragment];
    }
    [self.unusedExternalSurfaces setSet:self.externalSurfaces];
    if (self.id_textEmphasisBackgroundView != nil) {
        [self.unusedExternalSurfaces removeObject:self.id_textEmphasisBackgroundView];
    }
    [self id_notifyCustomRendererPreLayout];
}

- (UIView *)id_renderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)fragment {
    UIView *surface = [self.fragmentSurfaces objectForKey:fragment];
    if (surface != nil) {
        [surface setNeedsDisplay];
        return surface;
    }

    CGRect clipRect = IDPrivateCanvasContextClipRectForFadedEdges(self.context);
    if (self.currentCustomRenderController != nil) {
        surface = [[IDTextCustomRenderingHostingView alloc]
            initWithLayoutFragment:fragment
                    containerOrigin:CGPointZero
                     containerSize:self.textContainer.size
                          clipRect:clipRect];
    } else {
        Class surfaceClass = self.nativeSurfaceViewClass;
        surface = [[surfaceClass alloc] initWithLayoutFragment:fragment
                                              containerOrigin:CGPointZero
                                               containerSize:self.textContainer.size
                                                    clipRect:clipRect];
    }
    [self.fragmentSurfaces setObject:surface forKey:fragment];
    return surface;
}

- (void)id_configureRenderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)fragment {
    UIView *surface = [self.fragmentSurfaces objectForKey:fragment];
    if (surface == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"configureRenderingSurfaceForTextLayoutFragment: "
                                              "requires a keyed surface from "
                                              "renderingSurfaceForTextLayoutFragment:"
                                     userInfo:nil];
    }

    IDTextRenderingSurfaceView *fragmentSurface = (IDTextRenderingSurfaceView *)surface;
    if (self.id_textEmphasisBackgroundView.superview == self) {
        [self insertSubview:surface belowSubview:self.id_textEmphasisBackgroundView];
    } else if (self.id_selectionContainerView.superview == self) {
        [self insertSubview:surface belowSubview:self.id_selectionContainerView];
    } else {
        [self insertSubview:surface atIndex:0];
    }

    [fragmentSurface performChanges:^{
        [fragmentSurface setContainerOrigin:CGPointZero];
        [fragmentSurface setContainerSize:self.textContainer.size];
        [fragmentSurface setClipRect:
            IDPrivateCanvasContextClipRectForFadedEdges(self.context)];
    }];
    [self.unusedFragmentKeys removeObject:fragment];

    if (self.currentCustomRenderController != nil) {
        IDPrivateCanvasCustomRendererDidLayoutFragment(self.currentCustomRenderController,
                                                       fragment);
    }

    [surface layoutIfNeeded];
    [fragmentSurface enumerateTextAttachmentViewsUsingBlock:^(UIView *view,
                                                              CGRect fragmentFrame) {
        [self.attachmentCoordinator recordAttachmentView:view fragmentFrame:fragmentFrame];
    }];
}

- (void)id_viewportDidLayout {
    BOOL usedCustomRenderer = self.currentCustomRenderController != nil;
    [self id_removeUnusedElementViews];
    if (usedCustomRenderer) {
        [self id_notifyCustomRendererPostLayout];
    } else if (self.layoutFragmentViewsNeedDisplay) {
        for (UIView *surface in self.fragmentSurfaces.objectEnumerator.allObjects) {
            [surface setNeedsDisplay];
        }
        self.layoutFragmentViewsNeedDisplay = NO;
    }
    [self id_updateContentSizeIfNeeded];
    [self.attachmentCoordinator finishViewportLayout];
    IDPrivateCanvasNotifyContextDidLayout(self.context);
    if (usedCustomRenderer) {
        IDPrivateCanvasUpdateContextInteractionGeometry(self.context);
    }
}

- (void)id_removeUnusedElementViews {
    for (NSTextLayoutFragment *fragment in self.unusedFragmentKeys.allObjects) {
        UIView *surface = [self.fragmentSurfaces objectForKey:fragment];
        if ([surface respondsToSelector:@selector(teardown)]) {
            [(id)surface teardown];
        }
        [surface removeFromSuperview];
        [self.fragmentSurfaces removeObjectForKey:fragment];
    }
    [self.unusedFragmentKeys removeAllObjects];
    for (UIView *surface in self.unusedExternalSurfaces.copy) {
        if ([surface respondsToSelector:@selector(teardown)]) {
            [(id)surface teardown];
        }
        [surface removeFromSuperview];
        [self.externalSurfaces removeObject:surface];
        for (id attachment in self.anchoredAttachmentSurfaces.keyEnumerator.allObjects) {
            if ([self.anchoredAttachmentSurfaces objectForKey:attachment] == surface) {
                [self.anchoredAttachmentSurfaces removeObjectForKey:attachment];
            }
        }
    }
    [self.unusedExternalSurfaces removeAllObjects];
}

- (void)id_updateContentSizeIfNeeded {
    CGSize contentSize = CGSizeZero;
    if (!IDTextCanvasContentSizeForUsageBounds(
            self.textLayoutManager.usageBoundsForTextContainer,
            &contentSize)) {
        return;
    }
    if (CGSizeEqualToSize(self.cachedContentSize, contentSize)) {
        return;
    }
    self.cachedContentSize = contentSize;
    if (self.contentSizeDidChange != nil) {
        self.contentSizeDidChange(contentSize);
    }
}

- (void)id_flushElementViews {
    [self.attachmentCoordinator flush];
    [self.unusedFragmentKeys removeAllObjects];
    for (NSTextLayoutFragment *fragment in self.fragmentSurfaces.keyEnumerator.allObjects) {
        [self.unusedFragmentKeys addObject:fragment];
    }
    [self.unusedExternalSurfaces setSet:self.externalSurfaces];
    [self id_removeUnusedElementViews];
    for (UIView *surface in self.externalSurfaces.copy) {
        [surface removeFromSuperview];
    }
    [self.externalSurfaces removeAllObjects];
    [self.anchoredAttachmentSurfaces removeAllObjects];
    self.id_uniqueWritingToolsAnimatedLayoutInfo = nil;
    [self.unusedFragmentKeys removeAllObjects];
    [self.unusedExternalSurfaces removeAllObjects];
}

- (BOOL)id_addRenderingSurface:(UIView *)surface
                         group:(NSInteger)group
                     placement:(NSInteger)placement {
    if (surface == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"External rendering-surface nonnull stage failed"
                                     userInfo:nil];
    }
    if (group != 0 && group != 1) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"External rendering-surface group stage supports only 0 and 1"
                                     userInfo:nil];
    }
    if (placement != 0 && placement != 1) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"External rendering-surface placement stage supports only 0 and 1"
                                     userInfo:nil];
    }
    UIView *selection = self.id_selectionContainerView.superview == self
        ? self.id_selectionContainerView
        : nil;
    if (group == 1) {
        if (placement == 0 && selection != nil) {
            [self insertSubview:surface belowSubview:selection];
        } else {
            [self insertSubview:surface atIndex:0];
        }
    } else if (placement == 0) {
        [self addSubview:surface];
    } else if (selection != nil) {
        [self insertSubview:surface aboveSubview:selection];
    } else {
        [self addSubview:surface];
    }
    if (surface.translatesAutoresizingMaskIntoConstraints) {
        if (CGRectIsEmpty(surface.frame)) {
            surface.frame = self.bounds;
            surface.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                UIViewAutoresizingFlexibleHeight;
        }
        IDPrivateCanvasSetHostsLayoutEngine(surface, YES);
    }
    [self.externalSurfaces addObject:surface];
    [self.unusedExternalSurfaces removeObject:surface];
    return YES;
}

- (UIView *)id_renderingSurfaceForTextParagraphAnchoredAttachment:(id)attachment
                                         associatedLayoutFragment:(NSTextLayoutFragment *)fragment {
    if (attachment == nil || fragment == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Paragraph-anchored surface creation requires attachment and fragment"
                                     userInfo:nil];
    }
    IDTextParagraphAnchoredAttachmentSurface *surface =
        (IDTextParagraphAnchoredAttachmentSurface *)
            [self.anchoredAttachmentSurfaces objectForKey:attachment];
    if (surface == nil) {
        surface = [[IDTextParagraphAnchoredAttachmentSurface alloc]
            initWithCanvas:self
                 attachment:attachment];
        [self.anchoredAttachmentSurfaces setObject:surface forKey:attachment];
    }
    surface.layoutFragment = fragment;
    [self id_addRenderingSurface:surface group:0 placement:1];
    return surface;
}

- (CGRect)id_frameForParagraphAnchoredAttachment:(id)attachment
                                  layoutFragment:(NSTextLayoutFragment *)fragment {
    CGRect bounds = IDPrivateCanvasParagraphAnchoredBounds(fragment, attachment);
    UIView *surface = [self.fragmentSurfaces objectForKey:fragment];
    CGRect frame;
    if (surface != nil) {
        frame = [self convertRect:bounds fromView:surface];
    } else {
        CGPoint textContainerOrigin =
            IDPrivateCanvasContextTextContainerOrigin(self.context);
        frame = CGRectOffset(bounds,
                             CGRectGetMinX(fragment.layoutFragmentFrame) +
                                 textContainerOrigin.x,
                             CGRectGetMinY(fragment.layoutFragmentFrame) +
                                 textContainerOrigin.y);
    }
    if (!isfinite(frame.origin.x) || !isfinite(frame.origin.y) ||
        !isfinite(frame.size.width) || !isfinite(frame.size.height)) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Paragraph-anchored attachment frame stage requires finite geometry"
                                     userInfo:nil];
    }
    CGFloat width = MAX(CGRectGetWidth(self.bounds), 0);
    CGFloat minimumX = MIN(MAX(CGRectGetMinX(frame), 0), width);
    CGFloat maximumX = MIN(MAX(CGRectGetMaxX(frame), minimumX), width);
    frame.origin.x = minimumX;
    frame.size.width = maximumX - minimumX;
    return frame;
}

- (void)id_setTextEmphasisBackgroundView:(UIView *)backgroundView
                            withTextView:(UIView *)textView {
    if (self.id_textEmphasisBackgroundView != backgroundView) {
        if (textView == nil) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:@"Text emphasis setup requires a text view"
                                         userInfo:nil];
        }
        UIView *oldBackgroundView = self.id_textEmphasisBackgroundView;
        [oldBackgroundView removeFromSuperview];
        if (oldBackgroundView != nil) {
            [self.externalSurfaces removeObject:oldBackgroundView];
            [self.unusedExternalSurfaces removeObject:oldBackgroundView];
        }
        self.id_textEmphasisBackgroundView = backgroundView;
        [self setNeedsLayout];
    }
    id textContentManager = self.textLayoutManager.textContentManager;
    if (backgroundView == nil &&
        !IDPrivateCanvasSupportsAnchoredTextAttachments(textContentManager)) {
        IDPrivateCanvasClearPlatformSurfaceUpdaterIfAvailable(
            self.textViewportLayoutController);
        return;
    }
    __weak IDTextLayoutCanvasView *weakSelf = self;
    __weak UIView *weakTextView = textView;
    IDPrivateCanvasInstallPlatformSurfaceUpdaterIfAvailable(
        self.textViewportLayoutController,
        ^(id viewportLayoutController, id textRange, CGRect bounds) {
            IDTextLayoutCanvasView *canvas = weakSelf;
            UIView *retainedTextView = weakTextView;
            if (canvas != nil && retainedTextView != nil && textRange != nil) {
                [canvas id_updateRenderingSurfaceViewsForTextRange:textRange
                                                         inTextView:retainedTextView
                                                             bounds:bounds];
            }
        });
}

- (void)id_updateRenderingSurfaceViewsForTextRange:(id)textRange
                                         inTextView:(UIView *)textView
                                             bounds:(CGRect)bounds {
    __block BOOL hasHighlight = NO;
    if (!IDPrivateCanvasTextRangeIsEmpty(textRange)) {
        NSRange range = IDPrivateCanvasNSRangeForTextKitRange(textView, textRange);
        NSTextStorage *textStorage = IDPrivateCanvasTextStorage(textView);
        if (range.location != NSNotFound && range.location <= textStorage.length &&
            range.length <= textStorage.length - range.location) {
            [textStorage enumerateAttribute:NSTextHighlightStyleAttributeName
                                    inRange:range
                                    options:0
                                 usingBlock:^(id value, NSRange attributeRange, BOOL *stop) {
                if (value != nil) {
                    hasHighlight = YES;
                    *stop = YES;
                }
            }];
        }
    }

    UIView *emphasisView = self.id_textEmphasisBackgroundView;
    if (hasHighlight && emphasisView != nil) {
        [self id_addRenderingSurface:emphasisView group:1 placement:1];
        if (self.id_selectionContainerView.superview == self) {
            [self insertSubview:emphasisView belowSubview:self.id_selectionContainerView];
        } else {
            [self addSubview:emphasisView];
        }
        CGPoint textContainerOrigin =
            IDPrivateCanvasContextTextContainerOrigin(self.context);
        CGRect frame = CGRectOffset(bounds,
                                    textContainerOrigin.x,
                                    textContainerOrigin.y);
        if (!CGRectEqualToRect(emphasisView.frame, frame)) {
            emphasisView.frame = frame;
        }
        emphasisView.hidden = NO;
        IDPrivateCanvasSetEmphasisTextRange(emphasisView, textRange);
        IDPrivateCanvasSetEmphasisOrigin(
            emphasisView,
            CGPointMake(-CGRectGetMinX(bounds), -CGRectGetMinY(bounds)));
    } else if (emphasisView.superview == self && !CGRectIsEmpty(emphasisView.frame)) {
        emphasisView.hidden = YES;
    }

    id textContentManager = self.textLayoutManager.textContentManager;
    if (!IDPrivateCanvasSupportsAnchoredTextAttachments(textContentManager)) {
        return;
    }
    CGRect viewportBounds = self.viewportBounds;
    __weak IDTextLayoutCanvasView *weakSelf = self;
    [self.textLayoutManager enumerateTextLayoutFragmentsFromLocation:nil
                                                             options:0
                                                          usingBlock:^BOOL(
        NSTextLayoutFragment *fragment) {
        IDTextLayoutCanvasView *canvas = weakSelf;
        if (canvas == nil) {
            return NO;
        }
        CGRect fragmentFrame = fragment.layoutFragmentFrame;
        for (id attachment in IDPrivateCanvasAnchoredTextAttachments(fragment)) {
            CGRect attachmentFrame = CGRectOffset(
                IDPrivateCanvasParagraphAnchoredBounds(fragment, attachment),
                CGRectGetMinX(fragmentFrame),
                CGRectGetMinY(fragmentFrame));
            if (CGRectIntersectsRect(attachmentFrame, viewportBounds)) {
                UIView *surface = [canvas
                    id_renderingSurfaceForTextParagraphAnchoredAttachment:attachment
                                                 associatedLayoutFragment:fragment];
                [surface setNeedsLayout];
            }
        }
        id<NSTextLocation> fragmentLocation = fragment.rangeInElement.location;
        id<NSTextLocation> endLocation = [(NSTextRange *)textRange endLocation];
        return [fragmentLocation compare:endLocation] == NSOrderedAscending;
    }];
}

- (void)id_isEditingDidChange {
    if (self.id_hoverEffectContainerLayer != nil) {
        [self setNeedsLayout];
    }
}

- (void)id_observeEnclosingScrollView {
    [self viewportBoundsDidChange];
}

- (void)id_traitsChanged {
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)id_invalidateTextContainerOrigin {
    [self setNeedsLayout];
}

@end

#endif
