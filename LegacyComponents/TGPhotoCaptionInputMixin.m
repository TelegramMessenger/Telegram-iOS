#import "TGPhotoCaptionInputMixin.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGObserverProxy.h>

#import "TGSuggestionContext.h"

#import "TGModernConversationMentionsAssociatedPanel.h"
#import "TGModernConversationHashtagsAssociatedPanel.h"
#import "TGModernConversationAlphacodeAssociatedPanel.h"

@interface TGPhotoCaptionInputMixin () <TGMediaPickerCaptionInputPanelDelegate>
{
    TGObserverProxy *_keyboardWillChangeFrameProxy;
    bool _editing;
    
    UIGestureRecognizer *_dismissTapRecognizer;
    
    __weak TGKeyCommandController *_keyCommandController;
}
@end

@implementation TGPhotoCaptionInputMixin

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController
{
    self = [super init];
    if (self != nil)
    {
        _keyCommandController = keyCommandController;
        _keyboardWillChangeFrameProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification];
    }
    return self;
}

- (void)dealloc
{
    [_dismissView removeFromSuperview];
    [_inputPanel removeFromSuperview];
}

- (void)setAllowEntities:(bool)allowEntities
{
    _allowEntities = allowEntities;
    _inputPanel.allowEntities = allowEntities;
}

- (void)createInputPanelIfNeeded
{
    if (_inputPanel != nil)
        return;
    
    UIView *parentView = [self _parentView];
    
    CGSize screenSize = parentView.frame.size;
    _inputPanel = [[TGMediaPickerCaptionInputPanel alloc] initWithKeyCommandController:_keyCommandController frame:CGRectMake(0, 0, screenSize.width, [_inputPanel heightForInputFieldHeight:0])];
    _inputPanel.allowEntities = _allowEntities;
    _inputPanel.bottomMargin = 0;
    _inputPanel.delegate = self;
    
    [parentView addSubview:self.inputPanel];
}

- (void)destroy
{
    [self.inputPanel removeFromSuperview];
}

- (void)createDismissViewIfNeeded
{
    UIView *parentView = [self _parentView];
    
    _dismissView = [[UIView alloc] initWithFrame:parentView.bounds];
    _dismissView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _dismissTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissTap:)];
    _dismissTapRecognizer.enabled = false;
    [_dismissView addGestureRecognizer:_dismissTapRecognizer];
    
    [parentView insertSubview:_dismissView belowSubview:_inputPanel];
}

- (void)setCaption:(NSString *)caption
{
    [self setCaption:caption entities:nil animated:false];
}

- (void)setCaption:(NSString *)caption entities:(NSArray *)entities animated:(bool)animated
{
    _caption = caption;
    [self.inputPanel setCaption:caption entities:entities animated:animated];
}

- (void)setCaptionPanelHidden:(bool)hidden animated:(bool)__unused animated
{
    self.inputPanel.hidden = hidden;
}

- (void)beginEditing
{
    _editing = true;
    
    [self createDismissViewIfNeeded];
    [self createInputPanelIfNeeded];
    
    [self.inputPanel adjustForOrientation:self.interfaceOrientation keyboardHeight:_keyboardHeight duration:0.0 animationCurve:0];
    [self.inputPanel layoutSubviews];
}

- (void)enableDismissal
{
    _dismissTapRecognizer.enabled = true;
}

#pragma mark - 

- (void)handleDismissTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateRecognized)
        return;
    
    [self.inputPanel dismiss];
    [_dismissView removeFromSuperview];
}

#pragma mark - Input Panel Delegate

- (bool)inputPanelShouldBecomeFirstResponder:(TGMediaPickerCaptionInputPanel *)__unused inputPanel
{
    return true;
}

- (void)inputPanelFocused:(TGMediaPickerCaptionInputPanel *)__unused inputPanel
{
    [TGViewController disableAutorotation];
    
    [self beginEditing];
    
    _dismissView.hidden = false;
    
    [self.inputPanel.window makeKeyWindow];
    
    if (self.panelFocused != nil)
        self.panelFocused();
    
    [self enableDismissal];
}

- (void)inputPanelRequestedSetCaption:(TGMediaPickerCaptionInputPanel *)__unused inputPanel text:(NSString *)text entities:(NSArray *)entities
{
    [TGViewController enableAutorotation];
    
    _dismissView.hidden = true;
    
    if (self.finishedWithCaption != nil)
        self.finishedWithCaption(text, entities);
}

- (void)inputPanelMentionEntered:(TGMediaPickerCaptionInputPanel *)__unused inputTextPanel mention:(NSString *)mention startOfLine:(bool)__unused startOfLine
{
    if (mention == nil)
    {
        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationMentionsAssociatedPanel class]])
            [inputTextPanel setAssociatedPanel:nil animated:true];
    }
    else
    {
        TGModernConversationMentionsAssociatedPanel *panel = nil;
        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationMentionsAssociatedPanel class]])
            panel = (TGModernConversationMentionsAssociatedPanel *)[inputTextPanel associatedPanel];
        else
        {
            panel = [[TGModernConversationMentionsAssociatedPanel alloc] initWithStyle:TGModernConversationAssociatedInputPanelDarkStyle];
            
            __weak TGPhotoCaptionInputMixin *weakSelf = self;
            panel.userSelected = ^(TGUser *user)
            {
                __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    if ([[strongSelf->_inputPanel associatedPanel] isKindOfClass:[TGModernConversationMentionsAssociatedPanel class]])
                        [strongSelf->_inputPanel setAssociatedPanel:nil animated:false];
                    
                    if (user.userName.length == 0) {
                        [strongSelf->_inputPanel replaceMention:[[NSString alloc] initWithFormat:@"%@", user.displayFirstName] username:false userId:user.uid];
                    } else {
                        [strongSelf->_inputPanel replaceMention:[[NSString alloc] initWithFormat:@"%@", user.userName] username:true userId:user.uid];
                    }
                }
            };
        }
        
        SSignal *userListSignal = nil;
        if (self.suggestionContext.userListSignal != nil)
            userListSignal = self.suggestionContext.userListSignal(mention);
        
        [panel setUserListSignal:userListSignal];
        
        [inputTextPanel setAssociatedPanel:panel animated:true];
    }
}

- (void)inputPanelHashtagEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel hashtag:(NSString *)hashtag
{
    if (hashtag == nil)
    {
        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationHashtagsAssociatedPanel class]])
            [inputTextPanel setAssociatedPanel:nil animated:true];
    }
    else
    {
        TGModernConversationHashtagsAssociatedPanel *panel = nil;
        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationHashtagsAssociatedPanel class]])
            panel = (TGModernConversationHashtagsAssociatedPanel *)[inputTextPanel associatedPanel];
        else
        {
            panel = [[TGModernConversationHashtagsAssociatedPanel alloc] initWithStyle:TGModernConversationAssociatedInputPanelDarkStyle];
          
            __weak TGPhotoCaptionInputMixin *weakSelf = self;
            panel.hashtagSelected = ^(NSString *hashtag)
            {
                __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    if ([[strongSelf->_inputPanel associatedPanel] isKindOfClass:[TGModernConversationHashtagsAssociatedPanel class]])
                        [strongSelf->_inputPanel setAssociatedPanel:nil animated:false];
                    
                    [strongSelf->_inputPanel replaceHashtag:hashtag];
                }
            };
            [inputTextPanel setAssociatedPanel:panel animated:true];
        }
        
        SSignal *hashtagListSignal = nil;
        if (self.suggestionContext.hashtagListSignal != nil)
            hashtagListSignal = self.suggestionContext.hashtagListSignal(hashtag);
        
        [panel setHashtagListSignal:hashtagListSignal];
    }
}

- (void)inputPanelAlphacodeEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel alphacode:(NSString *)alphacode
{
    if (alphacode == nil)
    {
        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationAlphacodeAssociatedPanel class]])
            [inputTextPanel setAssociatedPanel:nil animated:true];
    }
    else
    {
        TGModernConversationAlphacodeAssociatedPanel *panel = nil;
        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationAlphacodeAssociatedPanel class]])
            panel = ((TGModernConversationAlphacodeAssociatedPanel *)[inputTextPanel associatedPanel]);
        else
        {
            panel = [[TGModernConversationAlphacodeAssociatedPanel alloc] initWithStyle:TGModernConversationAssociatedInputPanelDarkStyle];
            __weak TGPhotoCaptionInputMixin *weakSelf = self;
            panel.alphacodeSelected = ^(TGAlphacodeEntry *entry)
            {
                __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    if ([[strongSelf->_inputPanel associatedPanel] isKindOfClass:[TGModernConversationAlphacodeAssociatedPanel class]])
                    {
                        [strongSelf->_inputPanel setAssociatedPanel:nil animated:false];
                    }
                    
                    NSString *codeText = entry.emoji;
                    
                    [strongSelf appendAlphacode:[codeText stringByAppendingString:@" "]];
                }
            };
            [inputTextPanel setAssociatedPanel:panel animated:true];
        }
        
        SSignal *alphacodeListSignal = nil;
        if (self.suggestionContext.alphacodeSignal != nil)
            alphacodeListSignal = self.suggestionContext.alphacodeSignal(alphacode, inputTextPanel.inputField.textInputMode.primaryLanguage);
        
        [panel setAlphacodeListSignal:alphacodeListSignal];
    }
}

- (void)appendAlphacode:(NSString *)alphacode
{
    NSString *currentText = [_inputPanel inputField].text;
    NSRange selectRange = NSMakeRange(0, 0);
    
    if (currentText.length == 0)
        currentText = alphacode;
    else
    {
        NSInteger caretIndex = [_inputPanel textCaretPosition];
        
        for (NSInteger i = caretIndex - 1; i >= 0; i--)
        {
            if ([currentText characterAtIndex:i] == ':') {
                currentText = [currentText stringByReplacingCharactersInRange:NSMakeRange(i, caretIndex - i) withString:alphacode];
                selectRange = NSMakeRange(i + alphacode.length, 0);
                break;
            }
        }
    }
    
    [[_inputPanel inputField] setAttributedText:[[NSAttributedString alloc] initWithString:currentText] animated:false];
    [[_inputPanel inputField] selectRange:selectRange force:true];
    
    [_inputPanel inputField].internalTextView.enableFirstResponder = true;
}

- (void)inputPanelWillChangeHeight:(TGMediaPickerCaptionInputPanel *)inputPanel height:(CGFloat)__unused height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve
{
    [inputPanel adjustForOrientation:UIInterfaceOrientationPortrait keyboardHeight:_keyboardHeight duration:duration animationCurve:animationCurve];
}

- (void)setContentAreaHeight:(CGFloat)contentAreaHeight
{
    _contentAreaHeight = contentAreaHeight;
    
    CGFloat finalHeight = _contentAreaHeight - _keyboardHeight;
    [_inputPanel setContentAreaHeight:finalHeight];
}

- (UIView *)_parentView
{
    UIView *parentView = nil;
    if (self.panelParentView != nil)
        parentView = self.panelParentView();
    
    return parentView;
}

#pragma mark - Keyboard

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    UIView *parentView = [self _parentView];
    
    NSTimeInterval duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] == nil ? 0.3 : [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    int curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect screenKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [parentView convertRect:screenKeyboardFrame fromView:nil];
    
    CGFloat keyboardHeight = (keyboardFrame.size.height <= FLT_EPSILON || keyboardFrame.size.width <= FLT_EPSILON) ? 0.0f : (parentView.frame.size.height - keyboardFrame.origin.y);
    keyboardHeight = MAX(keyboardHeight, 0.0f);
    
    _keyboardHeight = keyboardHeight;
    
    if (!UIInterfaceOrientationIsPortrait([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]) && !TGIsPad())
        return;
    
    [_inputPanel adjustForOrientation:UIInterfaceOrientationPortrait keyboardHeight:keyboardHeight duration:duration animationCurve:curve];
    
    if (self.keyboardHeightChanged != nil)
        self.keyboardHeightChanged(keyboardHeight, duration, curve);
    
    CGFloat finalHeight = _contentAreaHeight - _keyboardHeight;
    [_inputPanel setContentAreaHeight:finalHeight];
}

- (void)updateLayoutWithFrame:(CGRect)frame edgeInsets:(UIEdgeInsets)edgeInsets
{
    _inputPanel.frame = CGRectMake(edgeInsets.left, _inputPanel.frame.origin.y, frame.size.width, _inputPanel.frame.size.height);
    _inputPanel.bottomMargin = edgeInsets.bottom;
    [_inputPanel adjustForOrientation:UIInterfaceOrientationPortrait keyboardHeight:_keyboardHeight duration:0.0 animationCurve:0];
}

@end
