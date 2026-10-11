#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextLayoutCanvasView.h"

#import "IDTextCanvasInvalidation.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"

@interface IDTextLayoutCanvasView (PrivateCallbacks) <NSTextViewportLayoutControllerDelegate>

- (BOOL)textViewportLayoutController:(NSTextViewportLayoutController *)controller
                 addRenderingSurface:(UIView *)surface
                               group:(NSInteger)group
                           placement:(NSInteger)placement;
- (void)setTextEmphasisBackgroundView:(UIView *)backgroundView
                         withTextView:(UIView *)textView;
- (void)_updateRenderingSurfaceViewsForTextRange:(id)textRange
                                      inTextView:(UIView *)textView
                                          bounds:(CGRect)bounds;

@end

@implementation IDTextLayoutCanvasView (PrivateCallbacks)

- (CGRect)viewportBoundsForTextViewportLayoutController:
    (NSTextViewportLayoutController *)textViewportLayoutController {
    return self.viewportBounds;
}

- (void)textViewportLayoutController:(NSTextViewportLayoutController *)textViewportLayoutController
    configureRenderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)textLayoutFragment {
    [self id_configureRenderingSurfaceForTextLayoutFragment:textLayoutFragment];
    self.layoutFragmentViewsNeedDisplay = YES;
}

- (UIView *)textViewportLayoutController:(NSTextViewportLayoutController *)textViewportLayoutController
    renderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)textLayoutFragment {
    return [self id_renderingSurfaceForTextLayoutFragment:textLayoutFragment];
}

- (void)textViewportLayoutControllerWillLayout:
    (NSTextViewportLayoutController *)textViewportLayoutController {
    if (self.performingViewportLayout || self.handlingExternalViewportLayout) {
        return;
    }
    self.handlingExternalViewportLayout = YES;
    [self id_viewportWillLayout];
}

- (void)textViewportLayoutControllerDidLayout:
    (NSTextViewportLayoutController *)textViewportLayoutController {
    if (!self.handlingExternalViewportLayout || self.performingViewportLayout) {
        return;
    }
    @try {
        [self id_viewportDidLayout];
        self.completedViewportLayoutCount += 1;
    } @finally {
        self.handlingExternalViewportLayout = NO;
    }
}

- (BOOL)textViewportLayoutController:(NSTextViewportLayoutController *)controller
                 addRenderingSurface:(UIView *)surface
                               group:(NSInteger)group
                           placement:(NSInteger)placement {
    return [self id_addRenderingSurface:surface group:group placement:placement];
}

- (void)setTextEmphasisBackgroundView:(UIView *)backgroundView
                         withTextView:(UIView *)textView {
    [self id_setTextEmphasisBackgroundView:backgroundView withTextView:textView];
}

- (void)_updateRenderingSurfaceViewsForTextRange:(id)textRange
                                      inTextView:(UIView *)textView
                                          bounds:(CGRect)bounds {
    [self id_updateRenderingSurfaceViewsForTextRange:textRange
                                           inTextView:textView
                                               bounds:bounds];
}

- (void)invalidateTextContainerOrigin {
    [self id_invalidateTextContainerOrigin];
}

- (CGPoint)textContainerOrigin {
    return [self id_textContainerOrigin];
}

- (BOOL)isEditing {
    return [self id_isEditing];
}

- (void)_textKit2CanvasDidLayout {
    [self id_textKit2CanvasDidLayout];
}

- (void)_updateInteractionGeometry {
    [self id_updateInteractionGeometry];
}

- (CALayer *)hoverEffectContainerLayer {
    return self.id_hoverEffectContainerLayer;
}

- (id)uniqueWritingToolsAnimatedLayoutInfo {
    return self.id_uniqueWritingToolsAnimatedLayoutInfo;
}

- (void)setUniqueWritingToolsAnimatedLayoutInfo:(id)info {
    self.id_uniqueWritingToolsAnimatedLayoutInfo = info;
}

- (void)setNeedsDisplayInRect:(CGRect)rect {
    for (UIView *surface in
         IDTextSurfacesIntersectingCanvasRect(self.fragmentSurfaces, rect)) {
        [surface setNeedsDisplay];
    }
}

- (void)invalidateTemporaryAttributesInRange:(id)range {
    id renderer = IDPrivateCanvasCustomRenderController(self.context);
    if (renderer == nil) {
        return;
    }
    if (!IDPrivateCanvasCanInvalidateTemporaryAttributes(renderer)) {
        IDPrivateCanvasSetNeedsDisplay(renderer);
        return;
    }
    for (id textKit2Range in IDPrivateTextKit2Ranges(range)) {
        IDPrivateCanvasInvalidateTemporaryAttributes(renderer, textKit2Range);
    }
}

@end

#endif
