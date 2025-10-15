#import <ChatInputTextViewImpl/ChatInputTextViewImpl.h>

@implementation ChatInputTextViewImplTargetForAction

- (instancetype)initWithTarget:(id _Nullable)target {
    self = [super init];
    if (self != nil) {
        _target = target;
    }
    return self;
}

@end

@interface ChatInputTextViewImpl () <UIGestureRecognizerDelegate> {
    UIGestureRecognizer *_tapRecognizer;
}

@end

@implementation ChatInputTextViewImpl

- (instancetype _Nonnull)initWithFrame:(CGRect)frame textContainer:(NSTextContainer * _Nullable)textContainer disableTiling:(bool)disableTiling {
    self = [super initWithFrame:frame textContainer:textContainer];
    if (self != nil) {
        if (disableTiling) {
            SEL selector = NSSelectorFromString(@"_disableTiledViews");
            if (selector && [self respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [self performSelector:selector];
#pragma clang diagnostic pop
            }
        }
        
        if (@available(iOS 17.0, *)) {
        } else {
            _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(workaroundTapGesture:)];
            _tapRecognizer.cancelsTouchesInView = false;
            _tapRecognizer.delaysTouchesBegan = false;
            _tapRecognizer.delaysTouchesEnded = false;
            _tapRecognizer.delegate = self;
            [self addGestureRecognizer:_tapRecognizer];
        }
    }
    return self;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    return false;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return true;
}

- (void)workaroundTapGesture:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        static Class promptClass = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            promptClass = NSClassFromString([[NSString alloc] initWithFormat:@"%@AutocorrectInlinePrompt", @"UI"]);
        });
        UIView *result = [self hitTest:[recognizer locationInView:self] withEvent:nil];
        if (result != nil && [result class] == promptClass) {
            if (_dropAutocorrectioniOS16) {
                _dropAutocorrectioniOS16();
            }
        }
    }
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (_targetForAction) {
        ChatInputTextViewImplTargetForAction *result = _targetForAction(action);
        if (result) {
            return result.target != nil;
        }
    }
    
    if (_shouldRespondToAction) {
        if (!_shouldRespondToAction(action)) {
            return false;
        }
    }
    
    if (action == @selector(paste:)) {
        NSArray *items = [UIMenuController sharedMenuController].menuItems;
        if (((UIMenuItem *)items.firstObject).action == @selector(toggleBoldface:)) {
            return false;
        }
        return true;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    static SEL promptForReplaceSelector;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        promptForReplaceSelector = NSSelectorFromString(@"_promptForReplace:");
    });
    if (action == promptForReplaceSelector) {
        return false;
    }
#pragma clang diagnostic pop
    
    if (action == @selector(toggleUnderline:)) {
        return false;
    }
    
    return [super canPerformAction:action withSender:sender];
}

- (id)targetForAction:(SEL)action withSender:(id)__unused sender {
    if (_targetForAction) {
        ChatInputTextViewImplTargetForAction *result = _targetForAction(action);
        if (result) {
            return result.target;
        }
    }
    
    return [super targetForAction:action withSender:sender];
}

- (void)copy:(id)sender {
    if (_shouldCopy == nil || _shouldCopy()) {
        [super copy:sender];
    }
}

- (void)paste:(id)sender {
    if (_shouldPaste == nil || _shouldPaste()) {
        [super paste:sender];
    }
}

- (NSArray *)keyCommands {
    UIKeyCommand *plainReturn = [UIKeyCommand keyCommandWithInput:@"\r" modifierFlags:kNilOptions action:@selector(handlePlainReturn:)];
    return @[
        plainReturn
    ];
}

- (void)handlePlainReturn:(id)__unused sender {
    if (_shouldReturn) {
        _shouldReturn();
    }
}

- (void)deleteBackward {
    bool notify = self.text.length == 0;
    [super deleteBackward];
    if (notify) {
        if (_backspaceWhileEmpty) {
            _backspaceWhileEmpty();
        }
    }
}

@end
