#import "IDTextViewInternal.h"
#import "IDPrivateUIKit.h"

@implementation IDTextView (Interaction)

- (void)id_installInteractionAssistant {
    NSAssert(self.id_interactionAssistant == nil, @"Interaction assistant installed twice");
    self.id_interactionAssistant = [IDPrivateUIKit newInteractionAssistantWithView:self];
    [IDPrivateUIKit requireObject:self.id_interactionAssistant
                            stage:@"Private interaction assistant creation"];
}

- (void)id_updateSelectionGestures {
    if (self.isSelectable) {
        IDPrivateInteractionSetGestureRecognizers(self.id_interactionAssistant);
    } else {
        IDPrivateInteractionClearGestureRecognizers(self.id_interactionAssistant);
    }
}

- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    IDPrivateInteractionBeginFloatingCursor(self.id_interactionAssistant, point);
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {
    [self updateFloatingCursorAtPoint:point animated:NO];
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    IDPrivateInteractionUpdateFloatingCursor(self.id_interactionAssistant, point, animated);
}

- (void)endFloatingCursor {
    IDPrivateInteractionEndFloatingCursor(self.id_interactionAssistant);
}

@end
