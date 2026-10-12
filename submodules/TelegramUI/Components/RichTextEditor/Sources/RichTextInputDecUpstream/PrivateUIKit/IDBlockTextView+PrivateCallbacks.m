#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDBlockStackCanvasView.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDPrivateUIKit.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "TGPrivateMethodAliases.h"


@implementation IDBlockStackCanvasView (PrivateTextContainerHost)

- (CGPoint)tgpn_textContainerOrigin {
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

- (CGPoint)tgpn_textContainerOrigin {
    // The container's origin within `-textInputView` (the block stack), which is where the stack lays
    // its blocks: `contentInsets`. It used to be derived from the stack's offset in this view, which
    // gave the same number only because the stack was POSITIONED at the inset.
    return CGPointMake(self.textContainerInset.left, self.textContainerInset.top);
}

- (id)tgpn_textLayoutController {
    return self.id_richLayoutController;
}

- (id)tgpn__inputController {
    return self.id_behaviorInput.privateController;
}

- (id)tgpn__textInputTraits {
    return self.id_behaviorInput == nil
        ? IDPrivateDefaultTextInputTraits()
        : self.id_behaviorInput.id_textInputTraits;
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
    return [[self tgpn__textInputTraits] methodSignatureForSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    Class traitsClass = NSClassFromString(@"UITextInputTraits");
    if ([traitsClass instancesRespondToSelector:selector]) {
        return [self tgpn__textInputTraits];
    }
    return [super forwardingTargetForSelector:selector];
}

- (NSArray<Class> *)tgpn__implicitPasteConfigurationClasses {
    return self.isEditable
        ? @[NSString.class, NSAttributedString.class]
        : @[];
}

- (NSAttributedString *)tgpn__attributedStringForInsertionOfAttributedString:
    (NSAttributedString *)attributedString {
    return IDPrivateObject1(
        self.id_inputController,
        NSSelectorFromString(
            TGPN__attributedStringForInsertionOfAttributedString_()),
        attributedString);
}

@end

// Every callback UIKit sends the text view under a PRIVATE name is compiled under a neutral `tgpn_`
// name and added under the private one (`TGPrivateMethodAliases.h`). Each category file installs its
// own; this one installs all three. Installed per class, from `+initialize`, so a subclass that
// overrides a `tgpn_` method gets its override under the private name too.
void IDBlockTextViewInstallPrivateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_textContainerOrigin, @selector(tgpn_textContainerOrigin) },
        { TGPN_textLayoutController, @selector(tgpn_textLayoutController) },
        { TGPN__inputController, @selector(tgpn__inputController) },
        { TGPN__textInputTraits, @selector(tgpn__textInputTraits) },
        { TGPN_textInputTraits, @selector(tgpn__textInputTraits) },
        { TGPN__implicitPasteConfigurationClasses, @selector(tgpn__implicitPasteConfigurationClasses) },
        { TGPN__attributedStringForInsertionOfAttributedString_, @selector(tgpn__attributedStringForInsertionOfAttributedString:) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
    IDBlockTextViewInstallPrivateInputDelegateCallbacks(cls);
    IDBlockTextViewInstallPrivateInteractionCallbacks(cls);
}

void IDBlockStackCanvasViewInstallPrivateCallbacks(Class cls) {
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_textContainerOrigin, @selector(tgpn_textContainerOrigin) },
    };
    TGPrivateInstallMethodAliases(cls, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

#endif
