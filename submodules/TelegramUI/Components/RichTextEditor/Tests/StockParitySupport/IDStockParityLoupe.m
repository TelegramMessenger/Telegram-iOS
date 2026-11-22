// PORTED from /Users/isaac/Documents/InputDec/Tests/IDBlockTouchSelectionParityTests.m:1-88
// @ fdad9ca519f5f27a07362e00dc6cefdcb73ca369. Bodies verbatim; the only changes are that the
// upstream file-statics gain external linkage, `IDSendTestLoupeGesture` returns the cancel flag
// instead of `NSCAssert`ing on it, and two one-line `objc_msgSend` accessors upstream inlines at
// its call sites are named here.

#import "IDStockParityLoupe.h"

#import <objc/message.h>

typedef CGPoint (^IDLoupePointProvider)(void);

BOOL IDSendTestLoupeGesture(id assistant,
                            UIGestureRecognizerState state,
                            CGPoint location,
                            CGPoint translation,
                            CGPoint velocity) {
    IDLoupePointProvider locationProvider = ^CGPoint { return location; };
    IDLoupePointProvider translationProvider = ^CGPoint { return translation; };
    IDLoupePointProvider velocityProvider = ^CGPoint { return velocity; };
    BOOL shouldCancel = NO;
    SEL selector = NSSelectorFromString(
        @"loupeGestureWithState:location:translation:velocity:modifierFlags:shouldCancel:");
    if (![assistant respondsToSelector:selector]) {
        return NO;
    }
    ((void (*)(id, SEL, NSInteger, id, id, id, NSInteger, BOOL *))objc_msgSend)(
        assistant,
        selector,
        state,
        locationProvider,
        translationProvider,
        velocityProvider,
        0,
        &shouldCancel);
    return !shouldCancel;
}

id IDInteractionAssistantOfInput(id input) {
    SEL selector = NSSelectorFromString(@"interactionAssistant");
    if (![input respondsToSelector:selector]) {
        return nil;
    }
    return ((id (*)(id, SEL))objc_msgSend)(input, selector);
}

UIView *IDCaretViewOfAssistant(id assistant) {
    SEL selector = NSSelectorFromString(@"_caretView");
    if (![assistant respondsToSelector:selector]) {
        return nil;
    }
    id view = ((id (*)(id, SEL))objc_msgSend)(assistant, selector);
    return [view isKindOfClass:UIView.class] ? view : nil;
}

UIImage *IDCaptureWindowScene(UIWindowScene *scene) {
    CGSize size = scene.screen.bounds.size;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        for (UIWindow *window in scene.windows) {
            if (window.hidden || window.alpha <= 0.0) continue;
            CGContextSaveGState(context.CGContext);
            CGContextTranslateCTM(context.CGContext, window.frame.origin.x, window.frame.origin.y);
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
            CGContextRestoreGState(context.CGContext);
        }
    }];
}

void IDWaitForLoupePresentation(void) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.4];
    while (deadline.timeIntervalSinceNow > 0.0) {
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:deadline];
    }
}

static UIView *IDVisibleSubviewOfClass(UIView *root, Class viewClass) {
    if ([root isKindOfClass:viewClass] && !root.hidden && root.alpha > 0.0 && root.window != nil) {
        return root;
    }
    for (UIView *subview in root.subviews) {
        UIView *match = IDVisibleSubviewOfClass(subview, viewClass);
        if (match != nil) return match;
    }
    return nil;
}

static UIView *IDVisibleLoupeViewInScene(UIWindowScene *scene) {
    Class loupeClass = NSClassFromString(@"_UITextMagnifiedGlassLoupeView");
    if (loupeClass == Nil) return nil;
    for (UIWindow *window in scene.windows.reverseObjectEnumerator) {
        UIView *loupe = IDVisibleSubviewOfClass(window, loupeClass);
        if (loupe != nil) return loupe;
    }
    return nil;
}

UIView *IDWaitForLoupeInScene(UIWindowScene *scene, BOOL visible) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    UIView *loupe = nil;
    do {
        loupe = IDVisibleLoupeViewInScene(scene);
        if ((loupe != nil) == visible) return loupe;
        NSDate *step = [NSDate dateWithTimeIntervalSinceNow:0.05];
        [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:step];
    } while (deadline.timeIntervalSinceNow > 0.0);
    return IDVisibleLoupeViewInScene(scene);
}

CGRect IDScreenRectForView(UIView *view) {
    return [view convertRect:view.bounds toView:nil];
}
