#import "TGMediaPickerCaptionInputPanel.h"

#import "TGMessage.h"
#import "TGInputTextTag.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGViewController.h"
#import "TGHacks.h"

#import "TGPhotoEditorInterfaceAssets.h"

#import "HPTextViewInternal.h"

#import "TGModernConversationAssociatedInputPanel.h"

const NSInteger TGMediaPickerCaptionInputPanelCaptionLimit = 1024;

static void setViewFrame(UIView *view, CGRect frame)
{
    CGAffineTransform transform = view.transform;
    view.transform = CGAffineTransformIdentity;
    if (!CGRectEqualToRect(view.frame, frame))
        view.frame = frame;
    view.transform = transform;
}

@interface TGMediaPickerCaptionInputPanel () <HPGrowingTextViewDelegate>
{
    CGFloat _keyboardHeight;
    NSString *_caption;
    bool _dismissing;
    bool _dismissDisabled;
    
    NSArray *_entities;
    
    UIView *_wrapperView;
    UIView *_backgroundView;
    UIImageView *_fieldBackground;
    UIView *_inputFieldClippingContainer;
    HPGrowingTextView *_inputField;
    UILabel *_placeholderLabel;
    
    UILabel *_inputFieldOnelineLabel;
    
    UILabel *_counterLabel;

    TGModernConversationAssociatedInputPanel *_associatedPanel;
    
    CGFloat _contentAreaHeight;
    
    __weak TGKeyCommandController *_keyCommandController;
}

@end

@implementation TGMediaPickerCaptionInputPanel

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController frame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _keyCommandController = keyCommandController;
        static UIImage *fieldBackgroundImage = nil;
        static UIImage *placeholderImage = nil;
        
        static NSString *localizationPlaceholderText = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(33, 33), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.1f).CGColor);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 33, 33) cornerRadius:16.5f];
            [path fill];
            
            fieldBackgroundImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(16, 16, 16, 16)];
            UIGraphicsEndImageContext();
        });
        
        if (placeholderImage == nil || localizationPlaceholderText != TGLocalized(@"MediaPicker.AddCaption"))
        {
            localizationPlaceholderText = TGLocalized(@"MediaPicker.AddCaption");
            NSString *placeholderText = TGLocalized(@"MediaPicker.AddCaption");
            UIFont *placeholderFont = TGSystemFontOfSize(16);
            CGSize placeholderSize = [placeholderText sizeWithFont:placeholderFont];
            placeholderSize.width += 2.0f;
            placeholderSize.height += 2.0f;
            
            UIGraphicsBeginImageContextWithOptions(placeholderSize, false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, UIColorRGB(0xffffff).CGColor);
            [placeholderText drawAtPoint:CGPointMake(1.0f, 1.0f) withFont:placeholderFont];
            placeholderImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        
        UIView *backgroundWrapperView = [[UIView alloc] initWithFrame:frame];
        backgroundWrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        backgroundWrapperView.clipsToBounds = true;
        [self addSubview:backgroundWrapperView];
        
        _wrapperView = [[UIView alloc] initWithFrame:frame];
        _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_wrapperView];
        
        _backgroundView = [[UIView alloc] initWithFrame:_wrapperView.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        [backgroundWrapperView addSubview:_backgroundView];
        
        _fieldBackground = [[UIImageView alloc] initWithImage:fieldBackgroundImage];
        _fieldBackground.alpha = 0.0f;
        _fieldBackground.userInteractionEnabled = true;
        [_wrapperView addSubview:_fieldBackground];
        
        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _placeholderLabel.backgroundColor = [UIColor clearColor];
        _placeholderLabel.font = TGSystemFontOfSize(16);
        _placeholderLabel.textColor = UIColorRGB(0x7f7f7f);
        _placeholderLabel.text = TGLocalized(@"MediaPicker.AddCaption");
        _placeholderLabel.userInteractionEnabled = true;
        [_placeholderLabel sizeToFit];
        [_wrapperView addSubview:_placeholderLabel];
        
        _inputFieldOnelineLabel = [[UILabel alloc] init];
        _inputFieldOnelineLabel.backgroundColor = [UIColor clearColor];
        _inputFieldOnelineLabel.font = TGSystemFontOfSize(16);
        _inputFieldOnelineLabel.hidden = true;
        _inputFieldOnelineLabel.numberOfLines = 1;
        _inputFieldOnelineLabel.textColor = [UIColor whiteColor];
        _inputFieldOnelineLabel.userInteractionEnabled = false;
        [_wrapperView addSubview:_inputFieldOnelineLabel];
        
        _counterLabel = [[UILabel alloc] initWithFrame:CGRectMake(_fieldBackground.frame.size.width - 45, 5, 36, 16)];
        _counterLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _counterLabel.backgroundColor = [UIColor clearColor];
        _counterLabel.font = TGSystemFontOfSize(12);
        _counterLabel.hidden = true;
        _counterLabel.textAlignment = NSTextAlignmentRight;
        _counterLabel.textColor = UIColorRGB(0x828282);
        _counterLabel.highlightedTextColor = UIColorRGB(0xff4848);
        _counterLabel.userInteractionEnabled = false;
        [_fieldBackground addSubview:_counterLabel];
        
        [_wrapperView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleFieldBackgroundTap:)]];
    }
    return self;
}

- (void)createInputFieldIfNeeded
{
    if (_inputField != nil)
        return;
    
    CGRect inputFieldClippingFrame = _fieldBackground.frame;
    _inputFieldClippingContainer = [[UIView alloc] initWithFrame:inputFieldClippingFrame];
    _inputFieldClippingContainer.clipsToBounds = true;
    [_wrapperView addSubview:_inputFieldClippingContainer];
    
    UIEdgeInsets inputFieldInternalEdgeInsets = [self _inputFieldInternalEdgeInsets];
    _inputField = [[HPGrowingTextView alloc] initWithKeyCommandController:_keyCommandController];
    _inputField.frame = CGRectMake(inputFieldInternalEdgeInsets.left, inputFieldInternalEdgeInsets.top + TGRetinaPixel, _inputFieldClippingContainer.frame.size.width - inputFieldInternalEdgeInsets.left - 36, _inputFieldClippingContainer.frame.size.height);
    _inputField.textColor = [UIColor whiteColor];
    _inputField.disableFormatting = !_allowEntities;
    _inputField.placeholderView = _placeholderLabel;
    _inputField.font = TGSystemFontOfSize(16);
    _inputField.accentColor = UIColorRGB(0x78b1f9);
    _inputField.clipsToBounds = true;
    _inputField.backgroundColor = nil;
    _inputField.opaque = false;
    _inputField.showPlaceholderWhenFocussed = true;
    _inputField.internalTextView.returnKeyType = UIReturnKeyDone;
    _inputField.internalTextView.backgroundColor = nil;
    _inputField.internalTextView.opaque = false;
    _inputField.internalTextView.contentMode = UIViewContentModeLeft;
    if (iosMajorVersion() >= 7)
        _inputField.internalTextView.keyboardAppearance = UIKeyboardAppearanceDark;
    else
        _inputField.internalTextView.keyboardAppearance = UIKeyboardAppearanceAlert;
    _inputField.maxNumberOfLines = [self _maxNumberOfLinesForSize:CGSizeMake(320.0f, 480.0f)];
    _inputField.delegate = self;
    
    _inputField.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(-inputFieldInternalEdgeInsets.top, 0, 5 - TGRetinaPixel, 0);
    
    [_inputField setAttributedText:[TGMediaPickerCaptionInputPanel attributedStringForText:_caption entities:_entities fontSize:16.0f] keepFormatting:true animated:false];
    
    [_inputFieldClippingContainer addSubview:_inputField];
}

- (void)setAllowEntities:(bool)allowEntities
{
    _allowEntities = allowEntities;
    _inputField.disableFormatting = !_allowEntities;
}

- (void)handleFieldBackgroundTap:(UITapGestureRecognizer *)__unused gestureRecognizer
{
    bool shouldBecomeFirstResponder = true;
    
    id<TGMediaPickerCaptionInputPanelDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(inputPanelShouldBecomeFirstResponder:)])
        shouldBecomeFirstResponder = [delegate inputPanelShouldBecomeFirstResponder:self];
    
    if (!shouldBecomeFirstResponder || self.isCollapsed)
        return;
    
    [self createInputFieldIfNeeded];
    _inputFieldClippingContainer.hidden = false;
    _inputField.internalTextView.enableFirstResponder = true;
    [_inputField.internalTextView becomeFirstResponder];
}

- (bool)setButtonPressed
{
    if (_dismissDisabled)
        return false;
    
    if (_inputField.text.length > TGMediaPickerCaptionInputPanelCaptionLimit)
    {
        [self shakeControls];
        return false;
    }
        
    if (_inputField.internalTextView.isFirstResponder)
        [TGHacks applyCurrentKeyboardAutocorrectionVariant];
    
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithAttributedString:_inputField.text == nil ? [[NSAttributedString alloc] initWithString:@""] : _inputField.attributedText]; //[[NSMutableAttributedString alloc] initWithString:_inputField.text == nil ? @"" : _inputField.text];
    NSMutableString *usualString = [text.string mutableCopy];
    int textLength = (int)text.length;
    for (int i = 0; i < textLength; i++)
    {
        unichar c = [usualString characterAtIndex:i];
        
        if (c == ' ' || c == '\t' || c == '\n')
        {
            [text deleteCharactersInRange:NSMakeRange(i, 1)];
            [usualString deleteCharactersInRange:NSMakeRange(i, 1)];
            i--;
            textLength--;
        }
        else
            break;
    }
    
    for (int i = textLength - 1; i >= 0; i--)
    {
        unichar c = [usualString characterAtIndex:i];
        
        if (c == ' ' || c == '\t' || c == '\n')
        {
            [text deleteCharactersInRange:NSMakeRange(i, 1)];
            [usualString deleteCharactersInRange:NSMakeRange(i, 1)];
            textLength--;
        }
        else
            break;
    }
    
    _inputField.internalTextView.attributedText = text;
    
    __autoreleasing NSArray *entities = nil;
    NSString *finalText = [_inputField textWithEntities:&entities];
    
    id<TGMediaPickerCaptionInputPanelDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(inputPanelRequestedSetCaption:text:entities:)])
        [delegate inputPanelRequestedSetCaption:self text:finalText entities:entities];
    
    _dismissing = true;
    
    [_inputField.internalTextView resignFirstResponder];
    
    return true;
}

- (void)dismiss
{
    [self setButtonPressed];
}

#pragma mark - 

- (void)setCollapsed:(bool)collapsed
{
    [self setCollapsed:collapsed animated:false];
}

- (void)setCollapsed:(bool)collapsed animated:(bool)animated
{
    _collapsed = collapsed;
    
    void (^frameChangeBlock)(void) = ^
    {
        _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x,
                                           collapsed ? self.frame.size.height : 0,
                                           _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        _wrapperView.frame = CGRectMake(_wrapperView.frame.origin.x,
                                        collapsed ? self.frame.size.height : 0,
                                        _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    };
    
    void (^visibilityChangeBlock)(void) = ^
    {
        CGFloat alpha = collapsed ? 0.0f : 1.0f;
        _wrapperView.alpha = alpha;
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0.0f options:[TGViewController preferredAnimationCurve] << 16 animations:frameChangeBlock completion:nil];
        [UIView animateWithDuration:0.25f delay:collapsed ? 0.0f : 0.05f options:kNilOptions animations:visibilityChangeBlock completion:nil];
    }
    else
    {
        frameChangeBlock();
        visibilityChangeBlock();
    }
}

#pragma mark - 

- (void)adjustForOrientation:(UIInterfaceOrientation)orientation keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration animationCurve:(NSInteger)animationCurve
{
    [self adjustForOrientation:orientation keyboardHeight:keyboardHeight duration:duration animationCurve:animationCurve completion:nil];
}

- (void)adjustForOrientation:(UIInterfaceOrientation)__unused orientation keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration animationCurve:(NSInteger)animationCurve completion:(void (^)(void))completion
{
    _keyboardHeight = keyboardHeight;
    
    void(^changeBlock)(void) = ^
    {
        bool isKeyboardVisible = (keyboardHeight > FLT_EPSILON);
        CGFloat inputContainerHeight = [self heightForInputFieldHeight:[self isFirstResponder] ? _inputField.frame.size.height : 0];
        CGSize screenSize = self.superview.frame.size;
        
        if (isKeyboardVisible)
        {
            self.frame = CGRectMake(self.frame.origin.x, screenSize.height - keyboardHeight - inputContainerHeight, self.frame.size.width, inputContainerHeight + keyboardHeight - self.bottomMargin);
            _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
        }
        else
        {
            self.frame = CGRectMake(self.frame.origin.x, screenSize.height - self.bottomMargin - inputContainerHeight, self.frame.size.width, inputContainerHeight);
            _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor];
        }
        
        [self layoutSubviews];
    };
    
    void (^finishedBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    };
    
    if (duration > DBL_EPSILON)
    {
        [UIView animateWithDuration:duration delay:0.0f options:animationCurve animations:changeBlock completion:finishedBlock];
    }
    else
    {
        changeBlock();
        finishedBlock(true);
    }
}

#pragma mark -

- (NSString *)caption
{
    return _caption;
}

- (void)setCaption:(NSString *)caption
{
    [self setCaption:caption entities:nil animated:false];
}

- (void)setCaption:(NSString *)caption entities:(NSArray *)entities animated:(bool)animated
{
    NSString *previousCaption = _caption;
    _caption = caption;
    _entities = entities;
    
    if (animated)
    {
        _inputFieldOnelineLabel.attributedText = [self oneLinedCaptionForText:caption entities:entities];
        
        if ([previousCaption isEqualToString:caption] || (previousCaption.length == 0 && caption.length == 0))
            return;
        
        UIView *snapshotView = nil;
        UIView *snapshottedView = nil;
        UIView *fadingInView = nil;
        if (previousCaption.length > 0)
            snapshottedView = _inputFieldOnelineLabel;
        else
            snapshottedView = _placeholderLabel;
        
        snapshotView = [snapshottedView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = snapshottedView.frame;
        [snapshottedView.superview addSubview:snapshotView];
        
        if (previousCaption.length > 0 && caption.length == 0)
            fadingInView = _placeholderLabel;
        else
            fadingInView = _inputFieldOnelineLabel;
        
        fadingInView.hidden = false;
        fadingInView.alpha = 0.0f;
        
        _placeholderLabel.hidden = (caption.length > 0);
        
        [UIView animateWithDuration:0.3f delay:0.05f options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            fadingInView.alpha = 1.0f;
        } completion:nil];
        
        [UIView animateWithDuration:0.21f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            snapshotView.alpha = 0.0f;
            _fieldBackground.alpha = _placeholderLabel.hidden ? 1.0f : 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    }
    else
    {
        _inputFieldOnelineLabel.attributedText = [self oneLinedCaptionForText:caption entities:entities];
        _inputFieldOnelineLabel.hidden = (caption.length == 0);
        _placeholderLabel.hidden = !_inputFieldOnelineLabel.hidden;
        _fieldBackground.alpha = _placeholderLabel.hidden ? 1.0f : 0.0f;
    }
    
    [self.inputField setAttributedText:[TGMediaPickerCaptionInputPanel attributedStringForText:_caption entities:_entities fontSize:16.0f] keepFormatting:true animated:false];
}

+ (NSAttributedString *)attributedStringForText:(NSString *)text entities:(NSArray *)entities fontSize:(CGFloat)fontSize {
    if (text == nil) {
        return nil;
    }
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: TGSystemFontOfSize(fontSize)}];
    for (id entity in entities) {
        if ([entity isKindOfClass:[TGMessageEntityMentionName class]]) {
            TGMessageEntityMentionName *mentionEntity = entity;
            static int64_t nextId = 1000000;
            int64_t uniqueId = nextId;
            nextId++;
            @try {
                [attributedString addAttributes:@{TGMentionUidAttributeName: [[TGInputTextTag alloc] initWithUniqueId:uniqueId left:true attachment:@(mentionEntity.userId)]} range:mentionEntity.range];
            } @catch(NSException *e) {
            }
        }
        else if (iosMajorVersion() >= 7) {
            if ([entity isKindOfClass:[TGMessageEntityBold class]]) {
                TGMessageEntityBold *boldEntity = entity;
                @try {
                    [attributedString addAttributes:@{NSFontAttributeName: TGBoldSystemFontOfSize(fontSize)} range:boldEntity.range];
                } @catch(NSException *e) {
                }
            } else if ([entity isKindOfClass:[TGMessageEntityItalic class]]) {
                TGMessageEntityItalic *italicEntity = entity;
                @try {
                    [attributedString addAttributes:@{NSFontAttributeName: TGItalicSystemFontOfSize(fontSize)} range:italicEntity.range];
                } @catch(NSException *e) {
                }
            }
        }
    }
    return attributedString;
}

- (void)updateCounterWithText:(NSString *)text
{
    bool appearance = false;
    
    NSInteger textLength = text.length;
    _counterLabel.text = [NSString stringWithFormat:@"%d", (int)(TGMediaPickerCaptionInputPanelCaptionLimit - textLength)];
    
    bool hidden = (text.length < (TGMediaPickerCaptionInputPanelCaptionLimit - 100));
    if (hidden != _counterLabel.hidden)
    {
        appearance = true;
        
        [UIView transitionWithView:_counterLabel duration:0.16f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _counterLabel.hidden = hidden;
        } completion:nil];
    }

    bool highlighted = (textLength > TGMediaPickerCaptionInputPanelCaptionLimit);
    if (highlighted != _counterLabel.highlighted)
    {
        if (!appearance)
        {
            [UIView transitionWithView:_counterLabel duration:0.16f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
            {
                _counterLabel.highlighted = highlighted;
            } completion:nil];
        }
        else
        {
            _counterLabel.highlighted = highlighted;
        }
    }
    
    _counterLabel.hidden = ![self isFirstResponder] || textLength < (TGMediaPickerCaptionInputPanelCaptionLimit - 100);
}

- (void)shakeControls
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    NSMutableArray *values = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < 6; i++)
        [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeTranslation(i % 2 == 0 ? -3.0f : 3.0f, 0.0f, 0.0f)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeTranslation(0.0f, 0.0f, 0.0f)]];
    animation.values = values;
    NSMutableArray *keyTimes = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < animation.values.count; i++)
        [keyTimes addObject:@((NSTimeInterval)i / (animation.values.count - 1.0))];
    animation.keyTimes = keyTimes;
    animation.duration = 0.3;
    [_wrapperView.layer addAnimation:animation forKey:@"transform"];
    
    _dismissDisabled = true;
    TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
    {
        _dismissDisabled = false;
    });
}

#pragma mark -

- (BOOL)becomeFirstResponder
{
    [self handleFieldBackgroundTap:nil];
    return true;
}

- (BOOL)isFirstResponder
{
    return _inputField.internalTextView.isFirstResponder && !_dismissing;
}

- (void)growingTextViewDidBeginEditing:(HPGrowingTextView *)__unused growingTextView
{
    id<TGMediaPickerCaptionInputPanelDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(inputPanelFocused:)])
        [delegate inputPanelFocused:self];
    
    [self updateCounterWithText:_caption];
    
    _inputField.alpha = 0.0f;
    [UIView animateWithDuration:0.2f animations:^
    {
        _inputField.alpha = 1.0f;
        _inputFieldOnelineLabel.alpha = 0.0f;
        _fieldBackground.alpha = 1.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            _inputFieldOnelineLabel.alpha = 1.0f;
            _inputFieldOnelineLabel.hidden = true;
        }
    }];
    
    if (_keyboardHeight < FLT_EPSILON)
    {
        [self adjustForOrientation:UIInterfaceOrientationPortrait keyboardHeight:0 duration:0.2f animationCurve:[TGViewController preferredAnimationCurve]];
    }
    
    [_inputField refreshHeight:false];
}

- (void)growingTextViewDidEndEditing:(HPGrowingTextView *)__unused growingTextView
{
    _caption = _inputField.text;
    
    __autoreleasing NSArray *entities = nil;
    [_inputField textWithEntities:&entities];
    _entities = entities;
    
    _inputFieldOnelineLabel.attributedText = [self oneLinedCaptionForText:_caption entities:_entities];
    _inputFieldOnelineLabel.alpha = 0.0f;
    _inputFieldOnelineLabel.hidden = false;
    
    [self updateCounterWithText:_caption];
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _inputField.alpha = 0.0f;
        _inputFieldOnelineLabel.alpha = 1.0f;
        
        if (_caption.length == 0)
            _fieldBackground.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            _inputField.alpha = 1.0f;
            _inputFieldClippingContainer.hidden = true;
        }
    }];
    
    [self setAssociatedPanel:nil animated:true];
    
    [self setButtonPressed];
}

- (void)growingTextView:(HPGrowingTextView *)__unused growingTextView willChangeHeight:(CGFloat)height duration:(NSTimeInterval)duration animationCurve:(int)animationCurve
{
    UIEdgeInsets inputFieldInsets = [self _inputFieldInsets];
    CGFloat inputContainerHeight = MAX([self baseHeight], height - 8 + inputFieldInsets.top + inputFieldInsets.bottom);
    
    id<TGMediaPickerCaptionInputPanelDelegate> delegate = (id<TGMediaPickerCaptionInputPanelDelegate>)self.delegate;
    if ([delegate respondsToSelector:@selector(inputPanelWillChangeHeight:height:duration:animationCurve:)])
    {
        [delegate inputPanelWillChangeHeight:self height:inputContainerHeight duration:duration animationCurve:animationCurve];
    }
}

- (void)growingTextViewDidChange:(HPGrowingTextView *)__unused growingTextView afterSetText:(bool)__unused afterSetText afterPastingText:(bool)__unused afterPastingText
{
    id<TGMediaPickerCaptionInputPanelDelegate> delegate = (id<TGMediaPickerCaptionInputPanelDelegate>)self.delegate;
    
    int textLength = (int)growingTextView.text.length;
    NSString *text = growingTextView.text;
    
    UITextRange *selRange = _inputField.internalTextView.selectedTextRange;
    UITextPosition *selStartPos = selRange.start;
    NSInteger idx = [_inputField.internalTextView offsetFromPosition:_inputField.internalTextView.beginningOfDocument toPosition:selStartPos];
    idx--;
    
    NSString *candidateMention = nil;
    bool candidateMentionStartOfLine = false;
    NSString *candidateHashtag = nil;
    NSString *candidateAlphacode = nil;
    
    if (idx >= 0 && idx < textLength)
    {
        for (NSInteger i = idx; i >= 0; i--)
        {
            unichar c = [text characterAtIndex:i];
            if (c == '@')
            {
                if (i == idx){
                    candidateMention = @"";
                    candidateMentionStartOfLine = i == 0;
                }
                else
                {
                    @try {
                        candidateMention = [text substringWithRange:NSMakeRange(i + 1, idx - i)];
                        candidateMentionStartOfLine = i == 0;
                    } @catch(NSException *e) { }
                }
                break;
            }
            
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'))
                break;
        }
    }
    
    if (candidateMention == nil)
    {
        static NSCharacterSet *characterSet = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            characterSet = [NSCharacterSet alphanumericCharacterSet];
        });
        
        if (idx >= 0 && idx < textLength)
        {
            for (NSInteger i = idx; i >= 0; i--)
            {
                unichar c = [text characterAtIndex:i];
                if (c == '#')
                {
                    if (i == idx)
                        candidateHashtag = @"";
                    else
                    {
                        @try {
                            candidateHashtag = [text substringWithRange:NSMakeRange(i + 1, idx - i)];
                        } @catch(NSException *e) { }
                    }
                    
                    break;
                }
                
                if (c == ' ' || (![characterSet characterIsMember:c] && c != '_'))
                    break;
            }
        }
    
        if (candidateHashtag == nil)
        {
            if (idx >= 0 && idx < textLength)
            {
                for (NSInteger i = idx; i >= 0; i--)
                {
                    unichar c = [text characterAtIndex:i];
                    unichar previousC = 0;
                    if (i > 0)
                        previousC = [text characterAtIndex:i - 1];
                    if (c == ':' && (previousC == 0 || ![characterSet characterIsMember:previousC]))
                    {
                        if (i == idx) {
                            candidateAlphacode = nil;
                        }
                        else
                        {
                            @try {
                                candidateAlphacode = [text substringWithRange:NSMakeRange(i + 1, idx - i)];
                            } @catch(NSException *e) { }
                        }
                        break;
                    }
                    
                    if (c == ' ' || (![characterSet characterIsMember:c]))
                        break;
                }
            }
        }
}
    
    if ([delegate respondsToSelector:@selector(inputPanelMentionEntered:mention:startOfLine:)])
        [delegate inputPanelMentionEntered:self mention:candidateMention startOfLine:candidateMentionStartOfLine];
    
    if ([delegate respondsToSelector:@selector(inputPanelHashtagEntered:hashtag:)])
        [delegate inputPanelHashtagEntered:self hashtag:candidateHashtag];
    
    if ([delegate respondsToSelector:@selector(inputPanelAlphacodeEntered:alphacode:)])
        [delegate inputPanelAlphacodeEntered:self alphacode:candidateAlphacode];
    
    if ([delegate respondsToSelector:@selector(inputPanelTextChanged:text:)])
        [delegate inputPanelTextChanged:self text:text];
    
    [self updateCounterWithText:text];
}

- (BOOL)growingTextViewShouldReturn:(HPGrowingTextView *)__unused growingTextView
{
    [self setButtonPressed];
    return false;
}

- (void)growingTextView:(HPGrowingTextView *)__unused growingTextView receivedReturnKeyCommandWithModifierFlags:(UIKeyModifierFlags)__unused flags
{
    [self setButtonPressed];
}

- (void)addNewLine
{
    self.caption = [NSString stringWithFormat:@"%@\n", self.caption];
}

- (NSMutableAttributedString *)oneLinedCaptionForText:(NSString *)text entities:(NSArray *)entities
{
    static NSString *tokenString = nil;
    if (tokenString == nil)
    {
        unichar tokenChar = 0x2026;
        tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
    }
    
    if (text == nil)
        return nil;
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithAttributedString:[TGMediaPickerCaptionInputPanel attributedStringForText:text entities:entities fontSize:16.0f]];
    
    for (NSUInteger i = 0; i < string.length; i++)
    {
        unichar c = [text characterAtIndex:i];
        if (c == '\t' || c == '\n')
        {
            [string insertAttributedString:[[NSAttributedString alloc] initWithString:tokenString attributes:@{NSFontAttributeName:TGSystemFontOfSize(16.0f)}] atIndex:i];
            break;
        }
    }
    
    return string;
}

- (NSInteger)textCaretPosition {
    UITextRange *selRange = _inputField.internalTextView.selectedTextRange;
    UITextPosition *selStartPos = selRange.start;
    NSInteger idx = [_inputField.internalTextView offsetFromPosition:_inputField.internalTextView.beginningOfDocument toPosition:selStartPos];
    return idx;
}

#pragma mark -

- (void)replaceMention:(NSString *)mention
{
    [HPGrowingTextView replaceMention:mention inputField:_inputField username:true userId:0];
}

- (void)replaceMention:(NSString *)mention username:(bool)username userId:(int32_t)userId {
    [HPGrowingTextView replaceMention:mention inputField:_inputField username:username userId:userId];
}

- (void)replaceHashtag:(NSString *)hashtag
{
    [HPGrowingTextView replaceHashtag:hashtag inputField:_inputField];
}

- (bool)shouldDisplayPanels
{
    return true;
}

- (TGModernConversationAssociatedInputPanel *)associatedPanel
{
    return _associatedPanel;
}

- (void)setAssociatedPanel:(TGModernConversationAssociatedInputPanel *)associatedPanel animated:(bool)animated
{
    if (_associatedPanel != associatedPanel)
    {
        TGModernConversationAssociatedInputPanel *currentPanel = _associatedPanel;
        if (currentPanel != nil)
        {
            if (animated)
            {
                [UIView animateWithDuration:0.18 animations:^
                {
                     currentPanel.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                        [currentPanel removeFromSuperview];
                }];
            }
            else
                [currentPanel removeFromSuperview];
        }
        
        _associatedPanel = associatedPanel;
        if (_associatedPanel != nil)
        {
            if ([_associatedPanel fillsAvailableSpace]) {
                CGFloat inputContainerHeight = [self heightForInputFieldHeight:[self isFirstResponder] ? _inputField.frame.size.height : 0];
                _associatedPanel.frame = CGRectMake(0.0f, -_contentAreaHeight + inputContainerHeight, self.frame.size.width, _contentAreaHeight - inputContainerHeight);
            } else {
                __weak TGMediaPickerCaptionInputPanel *weakSelf = self;
                _associatedPanel.preferredHeightUpdated = ^
                {
                    __strong TGMediaPickerCaptionInputPanel *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        strongSelf->_associatedPanel.frame = CGRectMake(0.0f, -[strongSelf->_associatedPanel preferredHeight], strongSelf.frame.size.width, [strongSelf shouldDisplayPanels] ? [strongSelf->_associatedPanel preferredHeight] : 0.0f);
                    }
                };
                _associatedPanel.frame = CGRectMake(0.0f, -[_associatedPanel preferredHeight], self.frame.size.width, [self shouldDisplayPanels] ? [_associatedPanel preferredHeight] : 0.0f);
            }

            [self addSubview:_associatedPanel];
            if (animated)
            {
                _associatedPanel.alpha = 0.0f;
                [UIView animateWithDuration:0.18 animations:^
                {
                    _associatedPanel.alpha = 1.0f;
                }];
            }
            else
            {
                _associatedPanel.alpha = 1.0f;
            }
        }
    }
}

- (void)setContentAreaHeight:(CGFloat)contentAreaHeight
{
    _contentAreaHeight = contentAreaHeight;
    [self setNeedsLayout];
    
    _dismissing = false;
}

#pragma mark - Style

- (UIEdgeInsets)_inputFieldInsets
{
    static UIEdgeInsets insets;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            insets = UIEdgeInsetsMake(6.0f, 6.0f, 6.0f, 6.0f);
        else
            insets = UIEdgeInsetsMake(11.0f, 11.0f, 11.0f, 11.0f);
    });
    
    return insets;
}

- (UIEdgeInsets)_inputFieldInternalEdgeInsets
{
    static UIEdgeInsets insets;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (!TGIsPad())
            insets = UIEdgeInsetsMake(-3.0f, 8.0f, 0.0f, 0.0f);
        else
            insets = UIEdgeInsetsMake(-2.0f, 8.0f, 0.0f, 0.0f);
    });
    
    return insets;
}

- (CGPoint)_inputFieldPlaceholderOffset
{
    static CGPoint offset;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (!TGIsPad())
            offset = CGPointMake(12.0f, 5.0f + TGScreenPixel);
        else
            offset = CGPointMake(12.0f, 6.0f);
    });
    
    return offset;
}

- (CGFloat)heightForInputFieldHeight:(CGFloat)inputFieldHeight
{
    if (inputFieldHeight < FLT_EPSILON)
        inputFieldHeight = 36;
    
    if (TGIsPad())
        inputFieldHeight += 4;
    
    UIEdgeInsets inputFieldInsets = [self _inputFieldInsets];
    CGFloat height = MAX([self baseHeight], inputFieldHeight - 4 + inputFieldInsets.top + inputFieldInsets.bottom);
    
    return height;
}

- (CGFloat)baseHeight
{
    static CGFloat value = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = !TGIsPad() ? 45.0f : 56.0f;
    });
    
    return value;
}

- (CGPoint)_setButtonOffset
{
    static CGPoint offset;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            offset = CGPointZero;
        else
            offset = CGPointMake(-11.0f, -6.0f);
    });
    
    return offset;
}

- (int)_maxNumberOfLinesForSize:(CGSize)size
{
    if (size.height <= 320.0f - FLT_EPSILON) {
        return 3;
    } else if (size.height <= 480.0f - FLT_EPSILON) {
        return 5;
    } else {
        return 7;
    }
}

#pragma mark - 

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_associatedPanel != nil)
    {
        UIView *result = [_associatedPanel hitTest:[self convertPoint:point toView:_associatedPanel] withEvent:event];
        if (result != nil)
            return result;
    }
    
    return [super hitTest:point withEvent:event];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect frame = self.frame;
    
    if (_associatedPanel != nil)
    {
        CGFloat inputContainerHeight = [self heightForInputFieldHeight:[self isFirstResponder] ? _inputField.frame.size.height : 0];
        
        CGRect associatedPanelFrame = CGRectZero;
        if ([_associatedPanel fillsAvailableSpace]) {
            associatedPanelFrame = CGRectMake(0.0f, -_contentAreaHeight + inputContainerHeight, self.frame.size.width, _contentAreaHeight - inputContainerHeight);
        } else {
            associatedPanelFrame = CGRectMake(0.0f, -[_associatedPanel preferredHeight], frame.size.width, [self shouldDisplayPanels] ? [_associatedPanel preferredHeight] : 0.0f);
        }

        if (!CGRectEqualToRect(associatedPanelFrame, _associatedPanel.frame))
            _associatedPanel.frame = associatedPanelFrame;
    }
    
    UIEdgeInsets inputFieldInsets = [self _inputFieldInsets];
    CGFloat inputContainerHeight = [self heightForInputFieldHeight:self.isFirstResponder ? _inputField.frame.size.height : 0];
    setViewFrame(_fieldBackground, CGRectMake(inputFieldInsets.left, inputFieldInsets.top, frame.size.width - inputFieldInsets.left - inputFieldInsets.right, inputContainerHeight - inputFieldInsets.top - inputFieldInsets.bottom));
    
    UIEdgeInsets inputFieldInternalEdgeInsets = [self _inputFieldInternalEdgeInsets];
    CGRect onelineFrame = _fieldBackground.frame;
    onelineFrame.origin.x += inputFieldInternalEdgeInsets.left + 5;
    onelineFrame.origin.y += inputFieldInternalEdgeInsets.top + TGScreenPixel;
    onelineFrame.size.width -= inputFieldInternalEdgeInsets.left * 2 + 10;
    onelineFrame.size.height = 36;
    setViewFrame(_inputFieldOnelineLabel, onelineFrame);
    
    CGRect placeholderFrame = CGRectMake(floor((self.frame.size.width - _placeholderLabel.frame.size.width) / 2.0f), floor(([self baseHeight] - _placeholderLabel.frame.size.height) / 2.0f), _placeholderLabel.frame.size.width, _placeholderLabel.frame.size.height);
    if (self.isFirstResponder)
        placeholderFrame.origin.x = onelineFrame.origin.x;
    setViewFrame(_placeholderLabel, placeholderFrame);
    
    CGRect inputFieldClippingFrame = _fieldBackground.frame;
    setViewFrame(_inputFieldClippingContainer, inputFieldClippingFrame);

    CGFloat inputFieldWidth = _inputFieldClippingContainer.frame.size.width - inputFieldInternalEdgeInsets.left - 36;
    if (fabs(inputFieldWidth - _inputField.frame.size.width) > FLT_EPSILON)
    {
        CGRect inputFieldFrame = CGRectMake(inputFieldInternalEdgeInsets.left, inputFieldInternalEdgeInsets.top + TGRetinaPixel, inputFieldWidth, _inputFieldClippingContainer.frame.size.height);
        setViewFrame(_inputField, inputFieldFrame);
    }
}

@end
