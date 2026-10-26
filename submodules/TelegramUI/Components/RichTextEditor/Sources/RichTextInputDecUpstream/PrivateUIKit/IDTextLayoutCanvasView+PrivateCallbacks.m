#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextLayoutCanvasView.h"

#import "IDTextCanvasInvalidation.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "TGPrivateMethodAliases.h"
#import "TGPrivateRuntimeNames.h"

@interface IDTextLayoutCanvasView (PrivateCallbacks) <NSTextViewportLayoutControllerDelegate>

- (BOOL)textViewportLayoutController:(NSTextViewportLayoutController *)controller
                 addRenderingSurface:(UIView *)surface
                               group:(NSInteger)group
                           placement:(NSInteger)placement;

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





- (BOOL)isEditing {
    return [self id_isEditing];
}



- (CALayer *)hoverEffectContainerLayer {
    return self.id_hoverEffectContainerLayer;
}

- (id)tgpn_uniqueWritingToolsAnimatedLayoutInfo {
    return self.id_uniqueWritingToolsAnimatedLayoutInfo;
}

- (void)tgpn_setUniqueWritingToolsAnimatedLayoutInfo:(id)info {
    self.id_uniqueWritingToolsAnimatedLayoutInfo = info;
}

- (void)setNeedsDisplayInRect:(CGRect)rect {
    for (UIView *surface in
         IDTextSurfacesIntersectingCanvasRect(self.fragmentSurfaces, rect)) {
        [surface setNeedsDisplay];
    }
}

- (void)tgpn_invalidateTemporaryAttributesInRange:(id)range {
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

// The canvas view's callbacks that UIKit and TextKit send under PRIVATE names, compiled under
// neutral names and added under the private ones (`TGPrivateMethodAliases.h`). Called from
// `+[IDTextLayoutCanvasView initialize]`.
void IDTextLayoutCanvasViewInstallPrivateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_setTextEmphasisBackgroundView_withTextView_, @selector(id_setTextEmphasisBackgroundView:withTextView:) },
        { TGPN__updateRenderingSurfaceViewsForTextRange_inTextView_bounds_, @selector(id_updateRenderingSurfaceViewsForTextRange:inTextView:bounds:) },
        { TGPN_invalidateTextContainerOrigin, @selector(id_invalidateTextContainerOrigin) },
        { TGPN_textContainerOrigin, @selector(id_textContainerOrigin) },
        { TGPN__textKit2CanvasDidLayout, @selector(id_textKit2CanvasDidLayout) },
        { TGPN__updateInteractionGeometry, @selector(id_updateInteractionGeometry) },
        { TGPN_uniqueWritingToolsAnimatedLayoutInfo, @selector(tgpn_uniqueWritingToolsAnimatedLayoutInfo) },
        { TGPN_setUniqueWritingToolsAnimatedLayoutInfo_, @selector(tgpn_setUniqueWritingToolsAnimatedLayoutInfo:) },
        { TGPN_invalidateTemporaryAttributesInRange_, @selector(tgpn_invalidateTemporaryAttributesInRange:) },
        // The selection container is a property of ours whose accessors share UIKit's private names.
        { TGPN_selectionContainerView, @selector(id_selectionContainerView) },
        { TGPN_setSelectionContainerView_, @selector(setId_selectionContainerView:) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

#endif
