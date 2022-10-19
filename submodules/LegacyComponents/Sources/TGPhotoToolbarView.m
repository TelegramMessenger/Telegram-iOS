#import "TGPhotoToolbarView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGModernButton.h"
#import "TGPhotoEditorButton.h"
#import "TGPhotoEditorInterfaceAssets.h"

#import "TGMediaAssetsController.h"

@interface TGPhotoToolbarView ()
{
    id<LegacyComponentsContext> _context;
    
    UIView *_backgroundView;
    
    UIView *_buttonsWrapperView;
    TGModernButton *_cancelButton;
    TGModernButton *_doneButton;
    
    UILabel *_infoLabel;
    
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
    
    bool _transitionedOut;
}
@end

@implementation TGPhotoToolbarView

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context backButton:(TGPhotoEditorBackButton)backButton doneButton:(TGPhotoEditorDoneButton)doneButton solidBackground:(bool)solidBackground
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _context = context;
        
        _interfaceOrientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
        
        _backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        _backgroundView.backgroundColor = (solidBackground ? [TGPhotoEditorInterfaceAssets toolbarBackgroundColor] : [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor]);
        [self addSubview:_backgroundView];
        
        _buttonsWrapperView = [[UIView alloc] initWithFrame:_backgroundView.bounds];
        [_backgroundView addSubview:_buttonsWrapperView];
        
        CGSize buttonSize = CGSizeMake(49.0f, 49.0f);
        _cancelButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, buttonSize.width, buttonSize.height)];
        _cancelButton.exclusiveTouch = true;
        _cancelButton.adjustsImageWhenHighlighted = false;
        [self setBackButtonType:backButton];
        [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_backgroundView addSubview:_cancelButton];
        
        _doneButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, buttonSize.width, buttonSize.height)];
        _doneButton.exclusiveTouch = true;
        _doneButton.adjustsImageWhenHighlighted = false;
        [self setDoneButtonType:doneButton];
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_backgroundView addSubview:_doneButton];
        
        _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(doneButtonLongPressed:)];
        _longPressGestureRecognizer.minimumPressDuration = 0.4;
        [_doneButton addGestureRecognizer:_longPressGestureRecognizer];
    }
    return self;
}

- (void)setBackButtonType:(TGPhotoEditorBackButton)backButtonType {
    _backButtonType = backButtonType;
    
    UIImage *cancelImage = nil;
    switch (backButtonType)
    {
        case TGPhotoEditorBackButtonCancel:
            cancelImage = TGTintedImage([UIImage imageNamed:@"Editor/Cancel"], [UIColor whiteColor]);
            break;
            
        default:
            cancelImage = TGComponentsImageNamed(@"PhotoPickerBackIcon");
            break;
    }
    [_cancelButton setImage:cancelImage forState:UIControlStateNormal];
}

- (void)setDoneButtonType:(TGPhotoEditorDoneButton)doneButtonType {
    _doneButtonType = doneButtonType;
    
    TGMediaAssetsPallete *pallete = nil;
    if ([_context respondsToSelector:@selector(mediaAssetsPallete)])
        pallete = [_context mediaAssetsPallete];
    
    UIImage *doneImage;
    switch (doneButtonType)
    {
        case TGPhotoEditorDoneButtonCheck:
            doneImage = TGTintedImage([UIImage imageNamed:@"Editor/Commit"], [UIColor whiteColor]);
            break;
            
        case TGPhotoEditorDoneButtonDone:
        {
            doneImage = pallete != nil ? pallete.doneIconImage : TGTintedImage([UIImage imageNamed:@"Editor/Commit"], [UIColor whiteColor]);
            break;
        }
        default:
        {
            doneImage = pallete != nil ? pallete.sendIconImage : TGComponentsImageNamed(@"PhotoPickerSendIcon");
        }
            break;
    }
    [_doneButton setImage:doneImage forState:UIControlStateNormal];
}

- (UIButton *)doneButton
{
    return _doneButton;
}

- (TGPhotoEditorButton *)createButtonForTab:(TGPhotoEditorTab)editorTab
{
    TGPhotoEditorButton *button = [[TGPhotoEditorButton alloc] initWithFrame:CGRectMake(0, 0, 33, 33)];
    button.tag = editorTab;
    [button addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    switch (editorTab)
    {
        case TGPhotoEditorCropTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets cropIcon];
            break;

        case TGPhotoEditorToolsTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets toolsIcon];
            break;

        case TGPhotoEditorRotateTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets rotateIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorPaintTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets paintIcon];
            break;
            
        case TGPhotoEditorStickerTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets stickerIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorTextTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets textIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorQualityTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets qualityIconForPreset:TGMediaVideoConversionPresetCompressedMedium];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorTimerTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets timerIconForValue:0.0];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorEraserTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets eraserIcon];
            break;
            
        case TGPhotoEditorMirrorTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets mirrorIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorAspectRatioTab:
            [button setIconImage:[TGPhotoEditorInterfaceAssets aspectRatioIcon] activeIconImage:[TGPhotoEditorInterfaceAssets aspectRatioActiveIcon]];
            button.dontHighlightOnSelection = true;
            break;
        
        case TGPhotoEditorTintTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets tintIcon];
            break;
            
        case TGPhotoEditorBlurTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets blurIcon];
            break;
            
        case TGPhotoEditorCurvesTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets curvesIcon];
            break;
            
        default:
            button = nil;
            break;
    }
    
    return button;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool inside = [super pointInside:point withEvent:event];
    if ([_doneButton pointInside:[self convertPoint:point toView:_doneButton] withEvent:nil])
        return true;
    
    return inside;
}

- (void)setToolbarTabs:(TGPhotoEditorTab)tabs animated:(bool)animated
{
    if (tabs == _currentTabs)
        return;
    
    NSArray *buttons = [_buttonsWrapperView.subviews copy];
    NSMutableArray *transitionViews = [[NSMutableArray alloc] init];
    if (animated && _currentTabs != TGPhotoEditorNoneTab)
    {
        for (TGPhotoEditorButton *button in buttons)
        {
            if (![button isKindOfClass:[TGPhotoEditorButton class]])
                continue;
            
            if (!(tabs & button.tag))
            {
                UIView *transitionView = [button snapshotViewAfterScreenUpdates:false];
                if (transitionView != nil)
                {
                    transitionView.frame = button.frame;
                    [button.superview addSubview:transitionView];
                    [transitionViews addObject:transitionView];
                }
                [button removeFromSuperview];
            }
        }
    }
    
    TGPhotoEditorTab previousTabs = _currentTabs;
    _currentTabs = tabs;
    
    NSMutableArray *newButtons = [[NSMutableArray alloc] init];
    if ((_currentTabs & TGPhotoEditorCropTab) && !(previousTabs & TGPhotoEditorCropTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorCropTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorStickerTab) && !(previousTabs & TGPhotoEditorStickerTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorStickerTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorPaintTab) && !(previousTabs & TGPhotoEditorPaintTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorPaintTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorEraserTab) && !(previousTabs & TGPhotoEditorEraserTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorEraserTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorTextTab) && !(previousTabs & TGPhotoEditorTextTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorTextTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorToolsTab) && !(previousTabs & TGPhotoEditorToolsTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorToolsTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorRotateTab) && !(previousTabs & TGPhotoEditorRotateTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorRotateTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorQualityTab) && !(previousTabs & TGPhotoEditorQualityTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorQualityTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorTimerTab) && !(previousTabs & TGPhotoEditorTimerTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorTimerTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorMirrorTab) && !(previousTabs & TGPhotoEditorMirrorTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorMirrorTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorAspectRatioTab) && !(previousTabs & TGPhotoEditorAspectRatioTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorAspectRatioTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorTintTab) && !(previousTabs & TGPhotoEditorTintTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorTintTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorBlurTab) && !(previousTabs & TGPhotoEditorBlurTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorBlurTab];
        [newButtons addObject:button];
    }
    if ((_currentTabs & TGPhotoEditorCurvesTab) && !(previousTabs & TGPhotoEditorCurvesTab))
    {
        TGPhotoEditorButton *button = [self createButtonForTab:TGPhotoEditorCurvesTab];
        [newButtons addObject:button];
    }
    
    for (TGPhotoEditorButton *button in newButtons)
    {
        bool added = false;
        for (UIView *exisingButton in _buttonsWrapperView.subviews)
        {
            if (exisingButton.tag > button.tag)
            {
                [_buttonsWrapperView insertSubview:button belowSubview:exisingButton];
                added = true;
                break;
            }
        }
        
        if (!added)
            [_buttonsWrapperView addSubview:button];
        
        if (animated)
            button.alpha = 0.0f;
    }
    
    [self setNeedsLayout];
    
    if (animated)
    {
        [UIView animateWithDuration:0.15 animations:^
        {
            for (TGPhotoEditorButton *button in newButtons)
            {
                button.alpha = 1.0f;
            }
            
            for (UIView *transitionView in transitionViews)
            {
                transitionView.alpha = 0.0f;
            }
        } completion:^(__unused BOOL finished)
        {
            for (UIView *transitionView in transitionViews)
            {
                transitionView.alpha = 0.0f;
            }
        }];
    }
}

- (CGRect)cancelButtonFrame
{
    return _cancelButton.frame;
}

- (void)cancelButtonPressed
{
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (CGRect)doneButtonFrame
{
    return _doneButton.frame;
}

- (void)doneButtonPressed
{
    if (self.donePressed != nil)
        self.donePressed();
}

- (void)doneButtonLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        if (self.doneLongPressed != nil)
            self.doneLongPressed(_doneButton);
    }
}

- (void)tabButtonPressed:(TGPhotoEditorButton *)sender
{
    if (self.tabPressed != nil)
        self.tabPressed((int)sender.tag);
}

- (void)setActiveTab:(TGPhotoEditorTab)tab
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
    {
        if ([button isKindOfClass:[TGPhotoEditorButton class]])
            [button setSelected:(button.tag == tab) animated:false];
    }
}

- (void)setDoneButtonEnabled:(bool)enabled animated:(bool)animated
{
    _doneButton.userInteractionEnabled = enabled;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
         {
             _doneButton.alpha = enabled ? 1.0f : 0.2f;
         } completion:nil];
    }
    else
    {
        _doneButton.alpha = enabled ? 1.0f : 0.2f;
    }
}

- (void)setEditButtonsEnabled:(bool)enabled animated:(bool)animated
{
    _buttonsWrapperView.userInteractionEnabled = enabled;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _buttonsWrapperView.alpha = enabled ? 1.0f : 0.2f;
        } completion:nil];
    }
    else
    {
        _buttonsWrapperView.alpha = enabled ? 1.0f : 0.2f;
    }
}

- (void)setEditButtonsHidden:(bool)hidden animated:(bool)animated
{
    CGFloat targetAlpha = hidden ? 0.0f : 1.0f;
    
    if (animated)
    {
        for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
        {
            if ([button isKindOfClass:[TGPhotoEditorButton class]])
                button.hidden = false;
        }
        
        [UIView animateWithDuration:0.2f
                         animations:^
        {
            for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
            {
                if ([button isKindOfClass:[TGPhotoEditorButton class]])
                    button.alpha = targetAlpha;
            }
        } completion:^(__unused BOOL finished)
        {
            for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
            {
                if ([button isKindOfClass:[TGPhotoEditorButton class]])
                    button.hidden = hidden;
            }
        }];
    }
    else
    {
        for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
        {
            if (![button isKindOfClass:[TGPhotoEditorButton class]])
                continue;
            
            button.alpha = (float)targetAlpha;
            button.hidden = hidden;
        }
    }
}

- (void)setEditButtonsHighlighted:(TGPhotoEditorTab)buttons
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
    {
        if ([button isKindOfClass:[TGPhotoEditorButton class]])
            button.active = (buttons & button.tag);
    }
}

- (void)setEditButtonsDisabled:(TGPhotoEditorTab)buttons
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
    {
        if ([button isKindOfClass:[TGPhotoEditorButton class]])
            button.disabled = (buttons & button.tag);
    }
}

- (void)setAllButtonsHidden:(bool)hidden animated:(bool)animated
{
    CGFloat targetAlpha = hidden ? 0.0f : 1.0f;
    
    if (animated)
    {
        _buttonsWrapperView.hidden = false;
        _cancelButton.hidden = false;
        _doneButton.hidden = false;
        
        [UIView animateWithDuration:0.2f
                         animations:^
        {
            _buttonsWrapperView.alpha = targetAlpha;
            _cancelButton.alpha = targetAlpha;
            _doneButton.alpha = targetAlpha;
        } completion:^(__unused BOOL finished)
        {
            _buttonsWrapperView.hidden = hidden;
            _cancelButton.hidden = hidden;
            _doneButton.hidden = hidden;
        }];
    }
    else
    {
        _buttonsWrapperView.alpha = targetAlpha;
        _cancelButton.alpha = targetAlpha;
        _doneButton.alpha = targetAlpha;
        _buttonsWrapperView.hidden = hidden;
        _cancelButton.hidden = hidden;
        _doneButton.hidden = hidden;
    }
}

- (TGPhotoEditorButton *)buttonForTab:(TGPhotoEditorTab)tab
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
    {
        if (![button isKindOfClass:[TGPhotoEditorButton class]])
            continue;
        
        if (button.tag == tab)
            return button;
    }
    return nil;
}

- (void)layoutSubviews
{
    CGRect backgroundFrame = self.bounds;
    if (!_transitionedOut)
    {
        _backgroundView.frame = backgroundFrame;
    }
    else
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            _backgroundView.frame = CGRectMake(backgroundFrame.origin.x, backgroundFrame.size.height, backgroundFrame.size.width, backgroundFrame.size.height);
        }
        else
        {
            if (_interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _backgroundView.frame = CGRectMake(-backgroundFrame.size.width, backgroundFrame.origin.y, backgroundFrame.size.width, backgroundFrame.size.height);
            }
            else
            {
                _backgroundView.frame = CGRectMake(backgroundFrame.size.width, backgroundFrame.origin.y, backgroundFrame.size.width, backgroundFrame.size.height);
            }
        }
    }
    _buttonsWrapperView.frame = _backgroundView.bounds;
    
    NSMutableArray *buttons = [[NSMutableArray alloc] init];
    
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
    {
        if ([button isKindOfClass:[TGPhotoEditorButton class]])
            [buttons addObject:button];
    }
    
    CGFloat offset = 8.0f;
    if (self.frame.size.width > self.frame.size.height)
    {
        if (buttons.count == 1)
        {
            UIView *button = buttons.firstObject;
            button.frame = CGRectMake(CGFloor(self.frame.size.width / 2 - button.frame.size.width / 2), offset, button.frame.size.width, button.frame.size.height);
        }
        else if (buttons.count == 2)
        {
            UIView *leftButton = buttons.firstObject;
            UIView *rightButton = buttons.lastObject;
            
            leftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 5 * 2 - 5 - leftButton.frame.size.width / 2), offset, leftButton.frame.size.width, leftButton.frame.size.height);
            rightButton.frame = CGRectMake(CGCeil(self.frame.size.width - leftButton.frame.origin.x - rightButton.frame.size.width), offset, rightButton.frame.size.width, rightButton.frame.size.height);
        }
        else if (buttons.count == 3)
        {
            UIView *leftButton = buttons.firstObject;
            UIView *centerButton = [buttons objectAtIndex:1];
            UIView *rightButton = buttons.lastObject;
            
            centerButton.frame = CGRectMake(CGFloor(self.frame.size.width / 2 - centerButton.frame.size.width / 2), offset, centerButton.frame.size.width, centerButton.frame.size.height);

            leftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 6 * 2 - 10 - leftButton.frame.size.width / 2), offset, leftButton.frame.size.width, leftButton.frame.size.height);
            
            rightButton.frame = CGRectMake(CGCeil(self.frame.size.width - leftButton.frame.origin.x - rightButton.frame.size.width), offset, rightButton.frame.size.width, rightButton.frame.size.height);
        }
        else if (buttons.count == 4)
        {
            UIView *leftButton = buttons.firstObject;
            UIView *centerLeftButton = [buttons objectAtIndex:1];
            UIView *centerRightButton = [buttons objectAtIndex:2];
            UIView *rightButton = buttons.lastObject;
            
            leftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 8 * 2 - 3 - leftButton.frame.size.width / 2), offset, leftButton.frame.size.width, leftButton.frame.size.height);
            
            centerLeftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 10 * 4 + 5 - centerLeftButton.frame.size.width / 2), offset, centerLeftButton.frame.size.width, centerLeftButton.frame.size.height);
            
            centerRightButton.frame = CGRectMake(CGCeil(self.frame.size.width - centerLeftButton.frame.origin.x - centerRightButton.frame.size.width), offset, centerRightButton.frame.size.width, centerRightButton.frame.size.height);
            
            rightButton.frame = CGRectMake(CGCeil(self.frame.size.width - leftButton.frame.origin.x - rightButton.frame.size.width), offset, rightButton.frame.size.width, rightButton.frame.size.height);
        }
        
        _cancelButton.frame = CGRectMake(0, 0, 49, 49);
        CGFloat offset = 49.0f;
        if (_doneButton.frame.size.width > 49.0f)
            offset = 60.0f;
        
        _doneButton.frame = CGRectMake(self.frame.size.width - offset, 49.0f - offset, _doneButton.frame.size.width, _doneButton.frame.size.height);
        
        _infoLabel.frame = CGRectMake(49.0f + 10.0f, 0.0f, self.frame.size.width - (49.0f + 10.0f) * 2.0f, 49.0f);
    }
    else
    {
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            offset = self.frame.size.width - [buttons.firstObject frame].size.width - offset;
        
        if (buttons.count == 1)
        {
            UIView *button = buttons.firstObject;
            button.frame = CGRectMake(offset, CGFloor((self.frame.size.height - button.frame.size.height) / 2), button.frame.size.width, button.frame.size.height);
        }
        else if (buttons.count == 2)
        {
            UIView *topButton = buttons.firstObject;
            UIView *bottomButton = buttons.lastObject;
            
            topButton.frame = CGRectMake(offset, CGFloor(self.frame.size.height / 5 * 2 - 10 - topButton.frame.size.height / 2), topButton.frame.size.width, topButton.frame.size.height);
            bottomButton.frame = CGRectMake(offset, CGCeil(self.frame.size.height - topButton.frame.origin.y - bottomButton.frame.size.height), bottomButton.frame.size.width, bottomButton.frame.size.height);
        }
        else if (buttons.count == 3)
        {
            UIView *topButton = buttons.firstObject;
            UIView *centerButton = [buttons objectAtIndex:1];
            UIView *bottomButton = buttons.lastObject;
            
            topButton.frame = CGRectMake(offset, CGFloor(self.frame.size.height / 6 * 2 - 10 - topButton.frame.size.height / 2), topButton.frame.size.width, topButton.frame.size.height);
            centerButton.frame = CGRectMake(offset, CGFloor((self.frame.size.height - centerButton.frame.size.height) / 2), centerButton.frame.size.width, centerButton.frame.size.height);
            bottomButton.frame = CGRectMake(offset, CGCeil(self.frame.size.height - topButton.frame.origin.y - bottomButton.frame.size.height), bottomButton.frame.size.width, bottomButton.frame.size.height);
        }
        else if (buttons.count == 4)
        {
            UIView *topButton = buttons.firstObject;
            UIView *centerTopButton = [buttons objectAtIndex:1];
            UIView *centerBottonButton = [buttons objectAtIndex:2];
            UIView *bottomButton = buttons.lastObject;
            
            topButton.frame = CGRectMake(offset, CGFloor(self.frame.size.height / 8 * 2 - 3 - topButton.frame.size.height / 2), topButton.frame.size.width, topButton.frame.size.height);
            
            centerTopButton.frame = CGRectMake(offset, CGFloor(self.frame.size.height / 10 * 4 + 5 - centerTopButton.frame.size.height / 2), centerTopButton.frame.size.width, centerTopButton.frame.size.height);
            
            centerBottonButton.frame = CGRectMake(offset, CGCeil(self.frame.size.height - centerTopButton.frame.origin.y - centerBottonButton.frame.size.height), centerBottonButton.frame.size.width, centerBottonButton.frame.size.height);
            
            bottomButton.frame = CGRectMake(offset, CGCeil(self.frame.size.height - topButton.frame.origin.y - bottomButton.frame.size.height), bottomButton.frame.size.width, bottomButton.frame.size.height);
        }
    
        CGFloat offset = self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft ? self.frame.size.width - 49.0f : 0.0f;
        _cancelButton.frame = CGRectMake(offset, self.frame.size.height - 49, 49, 49);
        _cancelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        
        _doneButton.frame = CGRectMake(offset, 0.0f, 49.0f, 49.0f);
        _doneButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        
        _infoLabel.center = CGPointMake(self.frame.size.width / 2.0f, self.frame.size.height / 2.0f);
        _infoLabel.bounds = CGRectMake(0.0f, 0.0f, self.frame.size.height - (49.0f + 10.0f) * 2.0f, self.frame.size.width);
        
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            _infoLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
        }
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            _infoLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
        }
    }
}

- (void)transitionInAnimated:(bool)animated
{
    [self transitionInAnimated:animated transparent:false];
}

- (void)transitionInAnimated:(bool)animated transparent:(bool)transparent
{
    _transitionedOut = false;
    self.backgroundColor = transparent ? [UIColor clearColor] : [UIColor blackColor];
    
    void (^animationBlock)(void) = ^
    {
        if (self.frame.size.width > self.frame.size.height)
            _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x, 0, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        else
            _backgroundView.frame = CGRectMake(0, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        if (finished)
            self.backgroundColor = [UIColor clearColor];
    };
    
    if (animated)
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x, _backgroundView.frame.size.height, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        }
        else
        {
            if (_interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _backgroundView.frame = CGRectMake(-_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
            else
            {
                _backgroundView.frame = CGRectMake(_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
        }
        
        if (iosMajorVersion() >= 7)
            [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:completionBlock];
        else
            [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:completionBlock];
    }
    else
    {
        animationBlock();
        completionBlock(true);
    }
}

- (void)transitionOutAnimated:(bool)animated
{
    [self transitionOutAnimated:animated transparent:false hideOnCompletion:false];
}

- (void)transitionOutAnimated:(bool)animated transparent:(bool)transparent hideOnCompletion:(bool)hideOnCompletion
{
    _transitionedOut = true;
    
    void (^animationBlock)(void) = ^
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x, _backgroundView.frame.size.height, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        }
        else
        {
            if (_interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _backgroundView.frame = CGRectMake(-_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
            else
            {
                _backgroundView.frame = CGRectMake(_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
        }
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (hideOnCompletion)
            self.hidden = true;
    };
    
    self.backgroundColor = transparent ? [UIColor clearColor] : [UIColor blackColor];
    
    if (animated)
    {
        if (iosMajorVersion() >= 7)
            [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:completionBlock];
        else
            [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:completionBlock];
    }
    else
    {
        animationBlock();
        completionBlock(true);
    }
}

- (void)setInfoString:(NSString *)string
{
    if (_infoLabel == nil)
    {
        _infoLabel = [[UILabel alloc] init];
        _infoLabel.backgroundColor = [UIColor clearColor];
        _infoLabel.font = TGSystemFontOfSize(13.0f);
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        _infoLabel.textColor = [UIColor whiteColor];
        [_backgroundView addSubview:_infoLabel];
    }
    
    _infoLabel.text = string;
    [self setNeedsLayout];
}

@end
