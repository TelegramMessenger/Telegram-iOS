#import "TGPhotoCaptionInputMixin.h"

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGObserverProxy.h>

#import "TGSuggestionContext.h"
#import "TGPhotoPaintStickersContext.h"

#import "TGModernConversationMentionsAssociatedPanel.h"
#import "TGModernConversationHashtagsAssociatedPanel.h"
#import "TGModernConversationAlphacodeAssociatedPanel.h"

@interface TGPhotoCaptionInputMixin ()
{
    TGObserverProxy *_keyboardWillChangeFrameProxy;
    bool _editing;
    
    UIGestureRecognizer *_dismissTapRecognizer;
    
    CGRect _currentFrame;
    UIEdgeInsets _currentEdgeInsets;
}
@end

@implementation TGPhotoCaptionInputMixin

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _keyboardWillChangeFrameProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification];
    }
    return self;
}

- (void)dealloc
{
    [_dismissView removeFromSuperview];
    [_inputPanelView removeFromSuperview];
}

- (void)setAllowEntities:(bool)allowEntities
{
    _allowEntities = allowEntities;
//    _inputPanel.allowEntities = allowEntities;
}

- (void)createInputPanelIfNeeded
{
    if (_inputPanel != nil)
        return;
    
    UIView *parentView = [self _parentView];
    
    id<TGCaptionPanelView> inputPanel = _stickersContext.captionPanelView();
    _inputPanel = inputPanel;
    
    __weak TGPhotoCaptionInputMixin *weakSelf = self;
    _inputPanel.sendPressed = ^(NSAttributedString *string) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        [TGViewController enableAutorotation];
        strongSelf->_dismissView.hidden = true;
    
        strongSelf->_editing = false;
        
        if (strongSelf.finishedWithCaption != nil)
            strongSelf.finishedWithCaption(string);
    };
    _inputPanel.focusUpdated = ^(BOOL focused) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        if (focused) {
            [TGViewController disableAutorotation];
            
            [strongSelf beginEditing];
            
            strongSelf->_dismissView.hidden = false;
                
            if (strongSelf.panelFocused != nil)
                strongSelf.panelFocused();
            
            [strongSelf enableDismissal];
        }
    };
    
    _inputPanel.heightUpdated = ^(BOOL animated) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        [strongSelf updateLayoutWithFrame:strongSelf->_currentFrame edgeInsets:strongSelf->_currentEdgeInsets];
    };
    
    _inputPanelView = inputPanel.view;
    
    _backgroundView = [[UIView alloc] init];
    _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
    [parentView addSubview:_backgroundView];
    [parentView addSubview:_inputPanelView];
}

- (void)destroy
{
    [_inputPanelView removeFromSuperview];
}

- (void)createDismissViewIfNeeded
{
    UIView *parentView = [self _parentView];
    
    _dismissView = [[UIView alloc] initWithFrame:parentView.bounds];
    _dismissView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _dismissTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissTap:)];
    _dismissTapRecognizer.enabled = false;
    [_dismissView addGestureRecognizer:_dismissTapRecognizer];
    
    [parentView insertSubview:_dismissView belowSubview:_backgroundView];
}

- (void)setCaption:(NSAttributedString *)caption
{
    if (_editing)
        return;
    [self setCaption:caption animated:false];
}

- (void)setCaption:(NSAttributedString *)caption animated:(bool)animated
{
    if (_editing)
        return;
    _caption = caption;
    [_inputPanel setCaption:caption];
}

- (void)setCaptionPanelHidden:(bool)hidden animated:(bool)__unused animated
{
    _inputPanelView.hidden = hidden;
}

- (void)beginEditing
{
    _editing = true;
    
    [self createDismissViewIfNeeded];
    [self createInputPanelIfNeeded];
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
    
    _editing = false;
    
    [self.inputPanel dismissInput];
    [_dismissView removeFromSuperview];
    
    if (self.finishedWithCaption != nil)
        self.finishedWithCaption([_inputPanel caption]);
}

#pragma mark - Input Panel Delegate


//- (void)inputPanelMentionEntered:(TGMediaPickerCaptionInputPanel *)__unused inputTextPanel mention:(NSString *)mention startOfLine:(bool)__unused startOfLine
//{
//    if (mention == nil)
//    {
//        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationMentionsAssociatedPanel class]])
//            [inputTextPanel setAssociatedPanel:nil animated:true];
//    }
//    else
//    {
//        TGModernConversationMentionsAssociatedPanel *panel = nil;
//        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationMentionsAssociatedPanel class]])
//            panel = (TGModernConversationMentionsAssociatedPanel *)[inputTextPanel associatedPanel];
//        else
//        {
//            panel = [[TGModernConversationMentionsAssociatedPanel alloc] initWithStyle:TGModernConversationAssociatedInputPanelDarkStyle];
//
//            __weak TGPhotoCaptionInputMixin *weakSelf = self;
//            panel.userSelected = ^(TGUser *user)
//            {
//                __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
//                if (strongSelf != nil)
//                {
//                    if ([[strongSelf->_inputPanel associatedPanel] isKindOfClass:[TGModernConversationMentionsAssociatedPanel class]])
//                        [strongSelf->_inputPanel setAssociatedPanel:nil animated:false];
//
//                    if (user.userName.length == 0) {
//                        [strongSelf->_inputPanel replaceMention:[[NSString alloc] initWithFormat:@"%@", user.displayFirstName] username:false userId:user.uid];
//                    } else {
//                        [strongSelf->_inputPanel replaceMention:[[NSString alloc] initWithFormat:@"%@", user.userName] username:true userId:user.uid];
//                    }
//                }
//            };
//        }
//
//        SSignal *userListSignal = nil;
//        if (self.suggestionContext.userListSignal != nil)
//            userListSignal = self.suggestionContext.userListSignal(mention);
//
//        [panel setUserListSignal:userListSignal];
//
//        [inputTextPanel setAssociatedPanel:panel animated:true];
//    }
//}
//
//- (void)inputPanelHashtagEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel hashtag:(NSString *)hashtag
//{
//    if (hashtag == nil)
//    {
//        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationHashtagsAssociatedPanel class]])
//            [inputTextPanel setAssociatedPanel:nil animated:true];
//    }
//    else
//    {
//        TGModernConversationHashtagsAssociatedPanel *panel = nil;
//        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationHashtagsAssociatedPanel class]])
//            panel = (TGModernConversationHashtagsAssociatedPanel *)[inputTextPanel associatedPanel];
//        else
//        {
//            panel = [[TGModernConversationHashtagsAssociatedPanel alloc] initWithStyle:TGModernConversationAssociatedInputPanelDarkStyle];
//
//            __weak TGPhotoCaptionInputMixin *weakSelf = self;
//            panel.hashtagSelected = ^(NSString *hashtag)
//            {
//                __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
//                if (strongSelf != nil)
//                {
//                    if ([[strongSelf->_inputPanel associatedPanel] isKindOfClass:[TGModernConversationHashtagsAssociatedPanel class]])
//                        [strongSelf->_inputPanel setAssociatedPanel:nil animated:false];
//
//                    [strongSelf->_inputPanel replaceHashtag:hashtag];
//                }
//            };
//            [inputTextPanel setAssociatedPanel:panel animated:true];
//        }
//
//        SSignal *hashtagListSignal = nil;
//        if (self.suggestionContext.hashtagListSignal != nil)
//            hashtagListSignal = self.suggestionContext.hashtagListSignal(hashtag);
//
//        [panel setHashtagListSignal:hashtagListSignal];
//    }
//}
//
//- (void)inputPanelAlphacodeEntered:(TGMediaPickerCaptionInputPanel *)inputTextPanel alphacode:(NSString *)alphacode
//{
//    if (alphacode == nil)
//    {
//        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationAlphacodeAssociatedPanel class]])
//            [inputTextPanel setAssociatedPanel:nil animated:true];
//    }
//    else
//    {
//        TGModernConversationAlphacodeAssociatedPanel *panel = nil;
//        if ([[inputTextPanel associatedPanel] isKindOfClass:[TGModernConversationAlphacodeAssociatedPanel class]])
//            panel = ((TGModernConversationAlphacodeAssociatedPanel *)[inputTextPanel associatedPanel]);
//        else
//        {
//            panel = [[TGModernConversationAlphacodeAssociatedPanel alloc] initWithStyle:TGModernConversationAssociatedInputPanelDarkStyle];
//            __weak TGPhotoCaptionInputMixin *weakSelf = self;
//            panel.alphacodeSelected = ^(TGAlphacodeEntry *entry)
//            {
//                __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
//                if (strongSelf != nil)
//                {
//                    if ([[strongSelf->_inputPanel associatedPanel] isKindOfClass:[TGModernConversationAlphacodeAssociatedPanel class]])
//                    {
//                        [strongSelf->_inputPanel setAssociatedPanel:nil animated:false];
//                    }
//
//                    NSString *codeText = entry.emoji;
//
//                    [strongSelf appendAlphacode:[codeText stringByAppendingString:@" "]];
//                }
//            };
//            [inputTextPanel setAssociatedPanel:panel animated:true];
//        }
//
//        SSignal *alphacodeListSignal = nil;
//        if (self.suggestionContext.alphacodeSignal != nil)
//            alphacodeListSignal = self.suggestionContext.alphacodeSignal(alphacode, inputTextPanel.inputField.textInputMode.primaryLanguage);
//
//        [panel setAlphacodeListSignal:alphacodeListSignal];
//    }
//}
//
//- (void)appendAlphacode:(NSString *)alphacode
//{
//    NSString *currentText = [_inputPanel inputField].text;
//    NSRange selectRange = NSMakeRange(0, 0);
//
//    if (currentText.length == 0)
//        currentText = alphacode;
//    else
//    {
//        NSInteger caretIndex = [_inputPanel textCaretPosition];
//
//        for (NSInteger i = caretIndex - 1; i >= 0; i--)
//        {
//            if ([currentText characterAtIndex:i] == ':') {
//                currentText = [currentText stringByReplacingCharactersInRange:NSMakeRange(i, caretIndex - i) withString:alphacode];
//                selectRange = NSMakeRange(i + alphacode.length, 0);
//                break;
//            }
//        }
//    }
//
//    [[_inputPanel inputField] setAttributedText:[[NSAttributedString alloc] initWithString:currentText] animated:false];
//    [[_inputPanel inputField] selectRange:selectRange force:true];
//
//    [_inputPanel inputField].internalTextView.enableFirstResponder = true;
//}
//
- (void)setContentAreaHeight:(CGFloat)contentAreaHeight
{
    _contentAreaHeight = contentAreaHeight;
    
    CGFloat finalHeight = _contentAreaHeight - _keyboardHeight;
//    [_inputPanel setContentAreaHeight:finalHeight];
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
    
    if (CGRectGetMaxY(keyboardFrame) < [UIScreen mainScreen].bounds.size.height || keyboardHeight < 20.0f) {
        keyboardHeight = 0.0f;
    }
    
    _keyboardHeight = keyboardHeight;
    
    if (!UIInterfaceOrientationIsPortrait([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]) && !TGIsPad())
        return;
    
    CGRect frame = _currentFrame;
    UIEdgeInsets edgeInsets = _currentEdgeInsets;
    CGFloat panelHeight = [_inputPanel updateLayoutSize:frame.size sideInset:0.0];
    [UIView animateWithDuration:duration delay:0.0f options:(curve << 16) animations:^{
        _inputPanelView.frame = CGRectMake(edgeInsets.left, frame.size.height - panelHeight - MAX(edgeInsets.bottom, _keyboardHeight), frame.size.width, panelHeight);
        
        CGFloat backgroundHeight = panelHeight;
        if (_keyboardHeight > 0.0) {
            backgroundHeight += _keyboardHeight - edgeInsets.bottom;
        }
        _backgroundView.frame = CGRectMake(edgeInsets.left, frame.size.height - panelHeight - MAX(edgeInsets.bottom, _keyboardHeight), frame.size.width, backgroundHeight);
    } completion:nil];

    if (self.keyboardHeightChanged != nil)
        self.keyboardHeightChanged(keyboardHeight, duration, curve);
}

- (void)updateLayoutWithFrame:(CGRect)frame edgeInsets:(UIEdgeInsets)edgeInsets
{
    _currentFrame = frame;
    _currentEdgeInsets = edgeInsets;
    
    CGFloat panelHeight = [_inputPanel updateLayoutSize:frame.size sideInset:0.0];
    _inputPanelView.frame = CGRectMake(edgeInsets.left, frame.size.height - panelHeight - MAX(edgeInsets.bottom, _keyboardHeight), frame.size.width, panelHeight);
    
    CGFloat backgroundHeight = panelHeight;
    if (_keyboardHeight > 0.0) {
        backgroundHeight += _keyboardHeight - edgeInsets.bottom;
    }
    _backgroundView.frame = CGRectMake(edgeInsets.left, frame.size.height - panelHeight - MAX(edgeInsets.bottom, _keyboardHeight), frame.size.width, backgroundHeight);
}

@end
