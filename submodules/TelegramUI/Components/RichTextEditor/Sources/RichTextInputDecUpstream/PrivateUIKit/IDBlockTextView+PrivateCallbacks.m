#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDBlockStackCanvasView.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDPrivateUIKit.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDRichTextLayoutControllerInternal.h"


@implementation IDBlockStackCanvasView (PrivateTextContainerHost)

- (CGPoint)textContainerOrigin {
    UIView *outerHost = self.superview;
    return outerHost == nil
        ? CGPointZero
        : [self convertPoint:CGPointZero toView:outerHost];
}

@end

@implementation IDBlockTextView (PrivateCallbacks)

- (NSTextStorage *)textStorage {
    return self.id_textStorageAdapter;
}

- (UIView *)textInputView {
    return self.id_blockStack;
}

- (CGPoint)textContainerOrigin {
    // The container's origin within `-textInputView` (the block stack), which is where the stack lays
    // its blocks: `contentInsets`. It used to be derived from the stack's offset in this view, which
    // gave the same number only because the stack was POSITIONED at the inset.
    return CGPointMake(self.textContainerInset.left, self.textContainerInset.top);
}

- (id)textLayoutController {
    return self.id_richLayoutController;
}

- (id)_inputController {
    return self.id_behaviorInput.privateController;
}

- (id)_textInputTraits {
    return self.id_behaviorInput == nil
        ? IDPrivateDefaultTextInputTraits()
        : self.id_behaviorInput.textInputTraits;
}

- (id)textInputTraits {
    return [self _textInputTraits];
}

- (BOOL)respondsToSelector:(SEL)selector {
    Class traitsClass = NSClassFromString(@"UITextInputTraits");
    return [super respondsToSelector:selector] ||
        [traitsClass instancesRespondToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = [super methodSignatureForSelector:selector];
    if (signature != nil) {
        return signature;
    }
    return [[self _textInputTraits] methodSignatureForSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    Class traitsClass = NSClassFromString(@"UITextInputTraits");
    if ([traitsClass instancesRespondToSelector:selector]) {
        return [self _textInputTraits];
    }
    return [super forwardingTargetForSelector:selector];
}

- (NSArray<Class> *)_implicitPasteConfigurationClasses {
    return self.isEditable
        ? @[NSString.class, NSAttributedString.class]
        : @[];
}

- (NSAttributedString *)_attributedStringForInsertionOfAttributedString:
    (NSAttributedString *)attributedString {
    return IDPrivateObject1(
        self.id_inputController,
        NSSelectorFromString(
            @"_attributedStringForInsertionOfAttributedString:"),
        attributedString);
}

@end

#endif
