#import "IDTextViewInternal.h"
#import "IDPrivateUIKit.h"

@implementation IDTextView (PrivateInteractionCallbacks)

- (id)interactionAssistant {
    return self.id_interactionAssistant;
}

- (id)customRenderController {
    return nil;
}

- (CGPoint)_convertPointFromRenderSpace:(CGPoint)point {
    return point;
}

- (UIView *)_textInputViewForAddingGestureRecognizers {
    return self;
}

- (UIView *)selectionContainerView {
    if (self.id_selectionContainerView == nil) {
        UIView *selectionContainer =
            [[UIView alloc] initWithFrame:[self id_selectionContainerFrame]];
        selectionContainer.userInteractionEnabled = NO;
        selectionContainer.backgroundColor = UIColor.clearColor;
        selectionContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                              UIViewAutoresizingFlexibleHeight;
        self.id_selectionContainerView = selectionContainer;
        [self addSubview:selectionContainer];
    }
    return self.id_selectionContainerView;
}

- (UIView *)_existingSelectionContainerView {
    return self.id_selectionContainerView;
}

- (void)_placeSelectionContainerView {
    if (self.id_selectionContainerView != nil) {
        [self bringSubviewToFront:self.id_selectionContainerView];
    }
}

- (BOOL)_isInteractiveTextSelectionDisabled {
    return !self.isSelectable;
}

- (void)_updateSelectionGestures {
    [self id_updateSelectionGestures];
}

- (void)_textKit2CanvasDidLayout {
    [self id_canvasDidLayout];
}

- (void)_updateInteractionGeometry {
    [self id_updateInteractionGeometry];
}

- (BOOL)isEditing {
    return self.isFirstResponder && self.isEditable;
}

- (void)setNeedsDisplayInRect:(CGRect)rect {
    [super setNeedsDisplayInRect:rect];
    CGRect canvasRect = [self.id_canvasView convertRect:rect fromView:self];
    [self.id_canvasView setNeedsDisplayInRect:canvasRect];
}

@end
