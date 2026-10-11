#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextViewInternal.h"

#import "IDPrivateUIKit.h"
#import "IDUIKitBehaviorKernel.h"
#import "IDUIKitInteractionCapability.h"

@implementation IDBlockTextView (Interaction)

- (void)id_installInteractionAssistant {
    NSAssert(self.id_interactionCapability == nil,
             @"Interaction capability installed twice");
    if (self.id_behaviorBackend ==
        IDUIKitBehaviorBackendMinimalKernel) {
        IDUIKitInteractionCapability *capability =
            self.id_behaviorKernel.interaction;
        if (capability.privateAssistant != nil) {
            self.id_interactionCapability = capability;
            self.id_interactionAssistant =
                capability.privateAssistant;
        }
        return;
    }
    NSError *error = nil;
    IDUIKitInteractionCapability *capability =
        [[IDUIKitInteractionCapability alloc]
            initWithContract:IDUIKitInteractionRuntimeContract()
                    resolver:[IDUIKitCapabilityResolver systemResolver]
                        view:self
                       error:&error];
    if (capability == nil) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Interaction capability construction failed: %@",
                           error.localizedDescription ?: @"unknown error"];
    }
    self.id_interactionCapability = capability;
    self.id_interactionAssistant = capability.privateAssistant;
}

- (void)id_updateSelectionGestures {
    [self.id_interactionCapability
        setGestureRecognizersEnabled:self.isSelectable];
}

- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    [self.id_interactionCapability
        beginFloatingCursorAtPoint:point];
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point {
    [self updateFloatingCursorAtPoint:point animated:NO];
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    [self.id_interactionCapability
        updateFloatingCursorAtPoint:point
                           animated:animated];
}

- (void)endFloatingCursor {
    IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"normalEnd");
    [self.id_interactionCapability endFloatingCursor];
}

@end

#endif
