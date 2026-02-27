#import <LegacyComponents/TGPhotoCaptionInputMixin.h>

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGObserverProxy.h>

#import <LegacyComponents/TGPhotoPaintStickersContext.h>

@interface TGPhotoCaptionInputMixin ()
{
    TGObserverProxy *_keyboardWillChangeFrameProxy;
    bool _editing;
    
    UIGestureRecognizer *_dismissTapRecognizer;
    
    CGRect _currentFrame;
    UIEdgeInsets _currentEdgeInsets;
    
    bool _currentIsCaptionAbove;
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
    
    id<TGCaptionPanelView> inputPanel = nil;
    if (_stickersContext && _stickersContext.captionPanelView != nil) {
        inputPanel = _stickersContext.captionPanelView();
    }
    _inputPanel = inputPanel;
    
    __weak TGPhotoCaptionInputMixin *weakSelf = self;
    _inputPanel.sendPressed = ^(NSAttributedString *string) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        [TGViewController enableAutorotation];
    
        strongSelf->_editing = false;
        
        if (strongSelf.finishedWithCaption != nil)
            strongSelf.finishedWithCaption(string);
    };
    _inputPanel.focusUpdated = ^(BOOL focused) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        if (focused) {
            [TGViewController disableAutorotation];
            
            [strongSelf beginEditing];
                            
            if (strongSelf.panelFocused != nil)
                strongSelf.panelFocused();
            
            [strongSelf enableDismissal];
        }
    };
    
    _inputPanel.heightUpdated = ^(BOOL animated) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        [strongSelf updateLayoutWithFrame:strongSelf->_currentFrame edgeInsets:strongSelf->_currentEdgeInsets animated:animated];
    };
    
    _inputPanel.timerUpdated = ^(NSNumber *value) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        if (strongSelf.timerUpdated != nil) {
            strongSelf.timerUpdated(value);
        }
    };
    
    _inputPanel.captionIsAboveUpdated = ^(bool value) {
        __strong TGPhotoCaptionInputMixin *strongSelf = weakSelf;
        if (strongSelf.captionIsAboveUpdated != nil) {
            strongSelf.captionIsAboveUpdated(value);
            
            strongSelf->_currentIsCaptionAbove = value;
            [strongSelf updateLayoutWithFrame:strongSelf->_currentFrame edgeInsets:strongSelf->_currentEdgeInsets animated:true];
        }
    };
    
    _inputPanelView = inputPanel.view;
    
    _backgroundView = [[UIView alloc] init];
    _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
    //[parentView addSubview:_backgroundView];
    [parentView addSubview:_inputPanelView];
}

- (void)onAnimateOut {
    [_inputPanel onAnimateOut];
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
    _dismissView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    
    _dismissTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissTap:)];
    _dismissTapRecognizer.enabled = false;
    [_dismissView addGestureRecognizer:_dismissTapRecognizer];
    
    [parentView insertSubview:_dismissView belowSubview:_inputPanelView];
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

- (void)setTimeout:(int32_t)timeout isVideo:(bool)isVideo isCaptionAbove:(bool)isCaptionAbove {
    _currentIsCaptionAbove = isCaptionAbove;
    [_inputPanel setTimeout:timeout isVideo:isVideo isCaptionAbove:isCaptionAbove];
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
    
    _dismissView.alpha = 0.0;
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _dismissView.alpha = 1.0f;
    } completion:^(BOOL finished) {
    }];
}

- (void)enableDismissal
{
    _dismissTapRecognizer.enabled = true;
}

#pragma mark - 

- (void)finishEditing {
    if ([self.inputPanel dismissInput]) {
        _editing = false;
                
        if (self.finishedWithCaption != nil)
            self.finishedWithCaption([_inputPanel caption]);
    }
}

- (void)handleDismissTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state != UIGestureRecognizerStateRecognized)
        return;
    
    [self finishEditing];
}

#pragma mark - Input Panel Delegate

- (void)setContentAreaHeight:(CGFloat)contentAreaHeight
{
    _contentAreaHeight = contentAreaHeight;
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
    
    CGFloat fadeAlpha = 1.0;
    if (keyboardHeight < FLT_EPSILON) {
        fadeAlpha = 0.0;
    }
    
    if (ABS(_dismissView.alpha - fadeAlpha) > FLT_EPSILON) {
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _dismissView.alpha = fadeAlpha;
        } completion:^(BOOL finished) {
            
        }];
    }
    
    if (!UIInterfaceOrientationIsPortrait([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]) && !TGIsPad())
        return;
    
    CGRect frame = _currentFrame;
    UIEdgeInsets edgeInsets = _currentEdgeInsets;
    CGFloat panelHeight = [_inputPanel updateLayoutSize:frame.size keyboardHeight:keyboardHeight sideInset:0.0 animated:false];
    
    CGFloat panelY = 0.0;
    if (frame.size.width > frame.size.height && !TGIsPad()) {
        panelY = edgeInsets.top + frame.size.height;
    } else {
        if (_currentIsCaptionAbove) {
            if (_keyboardHeight > 0.0) {
                panelY = _safeAreaInset.top + 8.0;
            } else {
                panelY = _safeAreaInset.top + 8.0 + 40.0;
            }
        } else {
            panelY = edgeInsets.top + frame.size.height - panelHeight - MAX(edgeInsets.bottom, _keyboardHeight);
        }
    }
    
    CGFloat backgroundHeight = panelHeight;
    if (_keyboardHeight > 0.0) {
        backgroundHeight += _keyboardHeight - edgeInsets.bottom;
    }
    
    [UIView animateWithDuration:duration delay:0.0f options:(curve << 16) animations:^{
        _inputPanelView.frame = CGRectMake(edgeInsets.left, panelY, frame.size.width, panelHeight);
        _backgroundView.frame = CGRectMake(edgeInsets.left, panelY, frame.size.width, backgroundHeight);
    } completion:nil];

    if (self.keyboardHeightChanged != nil)
        self.keyboardHeightChanged(keyboardHeight, duration, curve);
}

- (void)updateLayoutWithFrame:(CGRect)frame edgeInsets:(UIEdgeInsets)edgeInsets animated:(bool)animated
{
    _currentFrame = frame;
    _currentEdgeInsets = edgeInsets;
    
    CGFloat panelHeight = [_inputPanel updateLayoutSize:frame.size keyboardHeight:_keyboardHeight sideInset:0.0 animated:animated];
    
    CGFloat panelY = 0.0;
    if (frame.size.width > frame.size.height && !TGIsPad()) {
        panelY = edgeInsets.top + frame.size.height;
    } else {
        if (_currentIsCaptionAbove) {
            if (_keyboardHeight > 0.0) {
                panelY = _safeAreaInset.top + 8.0;
            } else {
                panelY = _safeAreaInset.top + 8.0 + 40.0;
            }
        } else {
            panelY = edgeInsets.top + frame.size.height - panelHeight - MAX(edgeInsets.bottom, _keyboardHeight);
        }
    }
    
    CGFloat backgroundHeight = panelHeight;
    if (_keyboardHeight > 0.0) {
        backgroundHeight += _keyboardHeight - edgeInsets.bottom;
    }
    
    CGRect panelFrame = CGRectMake(edgeInsets.left, panelY, frame.size.width, panelHeight);
    CGRect backgroundFrame = CGRectMake(edgeInsets.left, panelY, frame.size.width, backgroundHeight);
    
    if (animated) {
        [_inputPanel animateView:_inputPanelView frame:panelFrame];
        [_inputPanel animateView:_backgroundView frame:backgroundFrame];
    } else {
        _inputPanelView.frame = panelFrame;
        _backgroundView.frame = backgroundFrame;
    }
}

@end
