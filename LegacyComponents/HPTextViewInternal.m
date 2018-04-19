#import "HPTextViewInternal.h"

#import "LegacyComponentsInternal.h"
#import "TGHacks.h"
#import "FreedomUIKit.h"

#import "HPGrowingTextView.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <MobileCoreServices/MobileCoreServices.h>

#import "TGKeyCommandController.h"

@interface HPTextViewInternal () {
    __weak TGKeyCommandController *_keyCommandController;
}

@end

@implementation HPTextViewInternal

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        _keyCommandController = keyCommandController;
    }
    return self;
}

+ (void)addTextViewMethods
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        InjectInstanceMethodFromAnotherClass([HPTextViewInternal class], [HPTextViewInternal class], @selector(textViewAdjustScrollRange:animated:), NSSelectorFromString(TGEncodeText(@"`tdspmmSbohfUpWjtjcmf;bojnbufe;", -1)));
    });
}

- (void)setText:(NSString *)text
{
    BOOL originalValue = self.scrollEnabled;
    //If one of GrowingTextView's superviews is a scrollView, and self.scrollEnabled == NO,
    //setting the text programatically will cause UIKit to search upwards until it finds a scrollView with scrollEnabled==yes
    //then scroll it erratically. Setting scrollEnabled temporarily to YES prevents this.
    [self setScrollEnabled:YES];
    [super setText:text];
    [self setScrollEnabled:originalValue];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    BOOL originalValue = self.scrollEnabled;
    //If one of GrowingTextView's superviews is a scrollView, and self.scrollEnabled == NO,
    //setting the text programatically will cause UIKit to search upwards until it finds a scrollView with scrollEnabled==yes
    //then scroll it erratically. Setting scrollEnabled temporarily to YES prevents this.
    [self setScrollEnabled:YES];
    [super setAttributedText:attributedText];
    [self setScrollEnabled:originalValue];
}

- (void)setScrollable:(BOOL)isScrollable
{
    [super setScrollEnabled:isScrollable];
}

- (void)textViewAdjustScrollRange:(NSRange)range animated:(BOOL)animated
{
    static SEL selector = NULL;
    static void (*impl)(id, SEL, NSRange, BOOL) = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        Method method = class_getInstanceMethod([UITextView class], selector);
        if (method != NULL)
            impl = (void (*)(id, SEL, NSRange, BOOL))method_getImplementation(method);
    });
    
    animated = false;
    
    if (impl != NULL)
        impl(self, selector, range, animated);
}

- (void)scrollRectToVisible:(CGRect)__unused rect animated:(BOOL)__unused animated
{
    
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated
{
    if (_freezeContentOffset)
        return;
    
    [super setContentOffset:contentOffset animated:_disableContentOffsetAnimation ? false : animated];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
}

-(void)setContentOffset:(CGPoint)s
{
    if (_freezeContentOffset)
        return;
    	
	[super setContentOffset:s];
}

- (void)textViewEnsureSelectionVisible
{
    if (iosMajorVersion() >= 9) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGRect caretFrame = [self caretRectForPosition:self.selectedTextRange.end];
            if (caretFrame.origin.x < CGFLOAT_MAX && caretFrame.origin.y < CGFLOAT_MAX && !CGRectIsInfinite(caretFrame))
            {
                UIEdgeInsets implicitInset = UIEdgeInsetsMake(8, 0, 8, 0);
                
                caretFrame.origin.y -= implicitInset.top;
                caretFrame.size.height += implicitInset.top + implicitInset.bottom;
                caretFrame.origin.y = CGFloor(caretFrame.origin.y * 2.0f) / 2.0f;
                caretFrame.size.height = CGFloor(caretFrame.size.height * 2.0f) / 2.0f;
                
                CGFloat frameHeight = self.frame.size.height;
                CGPoint contentOffset = self.contentOffset;
                
                if (caretFrame.origin.y < contentOffset.y)
                    contentOffset.y = caretFrame.origin.y;
                if (caretFrame.origin.y + caretFrame.size.height > contentOffset.y + frameHeight)
                    contentOffset.y = caretFrame.origin.y + caretFrame.size.height - frameHeight;
                contentOffset.y = MAX(0, contentOffset.y);
                
                if (!CGPointEqualToPoint(contentOffset, self.contentOffset))
                    self.contentOffset = contentOffset;
            }
        });
    } else {
        CGRect caretFrame = [self caretRectForPosition:self.selectedTextRange.end];
        if (caretFrame.origin.x < CGFLOAT_MAX && caretFrame.origin.y < CGFLOAT_MAX && !CGRectIsInfinite(caretFrame))
        {
            UIEdgeInsets implicitInset = UIEdgeInsetsMake(8, 0, 8, 0);
            
            caretFrame.origin.y -= implicitInset.top;
            caretFrame.size.height += implicitInset.top + implicitInset.bottom;
            caretFrame.origin.y = CGFloor(caretFrame.origin.y * 2.0f) / 2.0f;
            caretFrame.size.height = CGFloor(caretFrame.size.height * 2.0f) / 2.0f;
            
            CGFloat frameHeight = self.frame.size.height;
            CGPoint contentOffset = self.contentOffset;
            
            if (caretFrame.origin.y < contentOffset.y)
                contentOffset.y = caretFrame.origin.y;
            if (caretFrame.origin.y + caretFrame.size.height > contentOffset.y + frameHeight)
                contentOffset.y = caretFrame.origin.y + caretFrame.size.height - frameHeight;
            contentOffset.y = MAX(0, contentOffset.y);
            
            if (!CGPointEqualToPoint(contentOffset, self.contentOffset))
                self.contentOffset = contentOffset;
        }
    }
}

- (void)setContentSize:(CGSize)contentSize
{
    [super setContentSize:contentSize];
 
    [self textViewEnsureSelectionVisible];
}

- (BOOL)canBecomeFirstResponder
{
    if (!_enableFirstResponder)
        return false;
    return true;
}

- (BOOL)becomeFirstResponder
{
    if (!_enableFirstResponder)
        return false;
    
    __block BOOL result = false;
    freedomUIKitTest4(^
    {
        if ([self.delegate respondsToSelector:@selector(textViewShouldBeginEditing:)] && ![self.delegate textViewShouldBeginEditing:self])
            result = false;
        else
            result = [super becomeFirstResponder];
    });
    
    if (result)
    {
        id delegate = _responderStateDelegate.object;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(HPTextViewInternalDelegate)])
        {
            [(id<HPTextViewInternalDelegate>)delegate hpTextViewChangedResponderState:true];
        }
    }
    return result;
}

- (BOOL)resignFirstResponder
{
    __block BOOL result = false;
    freedomUIKitTest4(^
    {
        result = [super resignFirstResponder];
    });
    
    if (result)
    {
        id delegate = _responderStateDelegate.object;
        if (delegate != nil && [delegate conformsToProtocol:@protocol(HPTextViewInternalDelegate)])
        {
            [(id<HPTextViewInternalDelegate>)delegate hpTextViewChangedResponderState:false];
        }
    }
    return result;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(paste:))
        return true;
    
    if (action == @selector(toggleUnderline:)) {
        return false;
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
    
    return [super canPerformAction:action withSender:sender];
}

- (id)targetForAction:(SEL)action withSender:(id)__unused sender
{
    if (action == @selector(processKeyCommand:)) {
        TGKeyCommandController *keyCommandController = _keyCommandController;
        return [keyCommandController targetForAction:action withSender:sender];
    }
    
    return [super targetForAction:action withSender:sender];
}

- (void)paste:(id)sender
{
    UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
    
    NSData *gifData = [pasteBoard dataForPasteboardType:@"com.compuserve.gif"];
    if (gifData != nil)
    {
        id delegate = self.delegate;
        if ([delegate isKindOfClass:[HPGrowingTextView class]])
        {
            HPGrowingTextView *textView = delegate;
            NSObject<HPGrowingTextViewDelegate> *textViewDelegate = (NSObject<HPGrowingTextViewDelegate> *)textView.delegate;
            if ([textViewDelegate respondsToSelector:@selector(growingTextView:didPasteData:)])
                [textViewDelegate growingTextView:textView didPasteData:gifData];
        }
    }
    else
    {
        NSMutableArray *images = [NSMutableArray arrayWithCapacity:1];
        NSString *text = nil;
        
        for (NSDictionary *item in pasteBoard.items) {
            if (item[(__bridge NSString *)kUTTypeJPEG] != nil) {
                [images addObject:item[(__bridge NSString *)kUTTypeJPEG]];
            } else if (item[(__bridge NSString *)kUTTypePNG] != nil) {
                [images addObject:item[(__bridge NSString *)kUTTypePNG]];
            } else if (item[(__bridge NSString *)kUTTypeGIF] != nil) {
                [images addObject:item[(__bridge NSString *)kUTTypeGIF]];
            } else if (item[(__bridge NSString *)kUTTypeURL] != nil) {
                id url = item[(__bridge NSString *)kUTTypeURL];
                if ([url respondsToSelector:@selector(characterAtIndex:)]) {
                    text = url;
                } else if ([url isKindOfClass:[NSURL class]]) {
                    text = ((NSURL *)url).absoluteString;
                }
            }
        }
        
        if (images.count != 0)
        {
            id delegate = self.delegate;
            if ([delegate isKindOfClass:[HPGrowingTextView class]])
            {
                HPGrowingTextView *textView = delegate;
                NSObject<HPGrowingTextViewDelegate> *textViewDelegate = (NSObject<HPGrowingTextViewDelegate> *)textView.delegate;
                if ([textViewDelegate respondsToSelector:@selector(growingTextView:didPasteImages:andText:)])
                    [textViewDelegate growingTextView:textView didPasteImages:images andText:text];
            }
        }
        else
        {
            _isPasting = true;
            bool previousAllowsEditingTextAttributes = self.allowsEditingTextAttributes;
            self.allowsEditingTextAttributes = false;
            [super paste:sender];
            self.allowsEditingTextAttributes = previousAllowsEditingTextAttributes;
            _isPasting = false;
        }
    }
}

@end
