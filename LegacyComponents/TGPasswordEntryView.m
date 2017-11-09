#import "TGPasswordEntryView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGTextField.h"

#import "TGPasscodePinView.h"
#import "TGPasscodeEntryKeyboardView.h"

#import "TGDefaultPasscodeBackground.h"
#import "TGImageBasedPasscodeBackground.h"
#import <LegacyComponents/TGModernButton.h>

#import <AudioToolbox/AudioToolbox.h>

#import "TGBuiltinWallpaperInfo.h"

@interface TGPasswordEntryInputView : UIView <UIInputViewAudioFeedback>

@end

@implementation TGPasswordEntryInputView

- (BOOL)enableInputClicksWhenVisible
{
    return true;
}

@end

@interface TGPasswordEntryView () <UITextFieldDelegate>
{
    TGPasswordEntryViewStyle _style;
    TGTextField *_textField;
    UILabel *_titleLabel;
    UILabel *_infoLabel;
    NSString *_title;
    NSString *_errorTitle;
    bool _isComplex;
    TGPasscodePinView *_pinView;
    NSString *_passcode;
    
    UIImageView *_backgroundView;
    TGPasscodeEntryKeyboardView *_simpleKeyboardView;
    TGModernButton *_simpleKeyboardCancelButton;
    TGModernButton *_simpleKeyboardDeleteButton;
    UIView *_inputView;
    TGModernButton *_complexCancelButton;
    TGModernButton *_complexNextButton;
    
    TGWallpaperInfo *_currentWallpaperInfo;
}

@end

@implementation TGPasswordEntryView

- (instancetype)initWithFrame:(CGRect)frame style:(TGPasswordEntryViewStyle)style
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _style = style;

        _backgroundView = [[UIImageView alloc] init];
        [self addSubview:_backgroundView];
        
        _inputView = [[TGPasswordEntryInputView alloc] init];
        
        _textField = [[TGTextField alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 1.0f, 1.0f)];
        _textField.clipsToBounds = true;
        _textField.delegate = self;
        _textField.secureTextEntry = true;
        _textField.font = TGSystemFontOfSize(16.0f);
        _textField.leftInset = 8.0f;
        _textField.rightInset = 8.0f;
        _textField.keyboardType = UIKeyboardTypeDefault;
        _textField.returnKeyType = UIReturnKeyNext;
        _textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        if (iosMajorVersion() >= 7)
            _textField.keyboardAppearance = UIKeyboardAppearanceDark;
        else
            _textField.keyboardAppearance = UIKeyboardAppearanceAlert;
        
        [self addSubview:_textField];
        
        _pinView = [[TGPasscodePinView alloc] init];
        [_pinView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pinViewTapped:)]];
        [self addSubview:_pinView];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = TGSystemFontOfSize([self titleFontSize]);
        [self addSubview:_titleLabel];
        
        _infoLabel = [[UILabel alloc] init];
        _infoLabel.backgroundColor = [UIColor clearColor];
        _infoLabel.textColor = [UIColor whiteColor];
        _infoLabel.font = TGSystemFontOfSize(13.0f);
        [self addSubview:_infoLabel];
        
        _simpleKeyboardView = [[TGPasscodeEntryKeyboardView alloc] init];
        [_simpleKeyboardView sizeToFit];
        
        __weak TGPasswordEntryView *weakSelf = self;
        _simpleKeyboardView.characterEntered = ^(NSString *text)
        {
            //AudioServicesPlaySystemSound(0x450);
            
            __strong TGPasswordEntryView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_textField.text = [strongSelf->_textField.text stringByAppendingString:text];
                [strongSelf setPasscode:strongSelf->_textField.text];
                if (!strongSelf->_isComplex)
                {
                    if (strongSelf->_passcode.length == 4)
                    {
                        strongSelf.userInteractionEnabled = false;
                        TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
                        {
                            strongSelf.userInteractionEnabled = true;
                            
                            if (strongSelf->_simplePasscodeEntered)
                                strongSelf->_simplePasscodeEntered();
                        });
                    }
                }
            }
        };
        [self addSubview:_simpleKeyboardView];
        
        CGFloat simpleButtonInsetHorizontal = 0.0f;
        CGFloat simpleButtonInsetVertical = 0.0f;
        
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        if (screenSize.width > screenSize.height)
        {
            CGFloat tmp = screenSize.width;
            screenSize.width = screenSize.height;
            screenSize.height = tmp;
        }
        
        if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        {
            simpleButtonInsetHorizontal = 26.0f;
            simpleButtonInsetVertical = 21.0f;
        }
        else if ((int)screenSize.height == 812)
        {
            simpleButtonInsetHorizontal = 54.0f;
            simpleButtonInsetVertical = 67.0f;
        }
        else if ((int)screenSize.height == 736)
        {
            simpleButtonInsetHorizontal = 26.0f;
            simpleButtonInsetVertical = 21.0f;
        }
        else if ((int)screenSize.height == 667)
        {
            simpleButtonInsetHorizontal = 54.0f;
            simpleButtonInsetVertical = 33.0f;
        }
        else if ((int)screenSize.height == 568)
        {
            simpleButtonInsetHorizontal = 26.0f;
            simpleButtonInsetVertical = 21.0f;
        }
        else
        {
            simpleButtonInsetHorizontal = 26.0f;
            simpleButtonInsetVertical = 13.0f;
        }
        
        _complexCancelButton = [[TGModernButton alloc] init];
        [_complexCancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        [_complexCancelButton setTitleColor:[UIColor whiteColor]];
        _complexCancelButton.contentEdgeInsets = UIEdgeInsetsMake(14.0f, 10.0f, 14.0f, 10.0f);
        _complexCancelButton.titleLabel.font = TGSystemFontOfSize(18.0f);
        [_complexCancelButton sizeToFit];
        [_complexCancelButton addTarget:self action:@selector(simpleKeyboardCancel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_complexCancelButton];
        
        _complexNextButton = [[TGModernButton alloc] init];
        [_complexNextButton setTitle:TGLocalized(@"Common.Next") forState:UIControlStateNormal];
        [_complexNextButton setTitleColor:[UIColor whiteColor]];
        _complexNextButton.contentEdgeInsets = UIEdgeInsetsMake(14.0f, 10.0f, 14.0f, 10.0f);
        _complexNextButton.titleLabel.font = TGMediumSystemFontOfSize(18.0f);
        [_complexNextButton sizeToFit];
        [_complexNextButton addTarget:self action:@selector(simpleKeyboardNext) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_complexNextButton];
        
        _simpleKeyboardCancelButton = [[TGModernButton alloc] init];
        [_simpleKeyboardCancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        [_simpleKeyboardCancelButton setTitleColor:[UIColor whiteColor]];
        _simpleKeyboardCancelButton.contentEdgeInsets = UIEdgeInsetsMake(simpleButtonInsetVertical, simpleButtonInsetHorizontal, simpleButtonInsetVertical, simpleButtonInsetHorizontal);
        _simpleKeyboardCancelButton.titleLabel.font = TGSystemFontOfSize(16.0f);
        [_simpleKeyboardCancelButton sizeToFit];
        [_simpleKeyboardCancelButton addTarget:self action:@selector(simpleKeyboardCancel) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_simpleKeyboardCancelButton];
        
        _simpleKeyboardDeleteButton = [[TGModernButton alloc] init];
        [_simpleKeyboardDeleteButton setTitle:TGLocalized(@"Common.Delete") forState:UIControlStateNormal];
        [_simpleKeyboardDeleteButton setTitleColor:[UIColor whiteColor]];
        _simpleKeyboardDeleteButton.contentEdgeInsets = UIEdgeInsetsMake(simpleButtonInsetVertical, simpleButtonInsetHorizontal, simpleButtonInsetVertical, simpleButtonInsetHorizontal);
        _simpleKeyboardDeleteButton.titleLabel.font = TGSystemFontOfSize(16.0f);
        [_simpleKeyboardDeleteButton sizeToFit];
        [_simpleKeyboardDeleteButton addTarget:self action:@selector(simpleKeyboardDelete) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_simpleKeyboardDeleteButton];
        
        [self _updateBackground:frame.size];
    }
    return self;
}

- (CGFloat)titleFontSize
{
    if (_isComplex)
        return 20.0f;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        return 21.0f;
    else if ((int)screenSize.height == 736)
        return 19.0f;
    else if ((int)screenSize.height == 667 || (int)screenSize.height == 812)
        return 19.0f;
    else if ((int)screenSize.height == 568)
        return 18.0f;
    else
        return 18.0f;
}

- (CGFloat)infoFontSize
{
    if (_isComplex)
        return 14.0f;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        return 15.0f;
    
    return 13.0f;
}

- (void)updateBackgroundIfNeeded
{
    TGWallpaperInfo *wallpaperInfo = [[LegacyComponentsGlobals provider] currentWallpaperInfo];
    if (!TGObjectCompare(_currentWallpaperInfo, wallpaperInfo))
        [self _updateBackground:self.frame.size];
}

- (void)_updateBackground:(CGSize)size
{
    TGWallpaperInfo *wallpaperInfo = [[LegacyComponentsGlobals provider] currentWallpaperInfo];
    id<TGPasscodeBackground> background = nil;
    
    if ([wallpaperInfo isKindOfClass:[TGBuiltinWallpaperInfo class]])
    {
        if ([((TGBuiltinWallpaperInfo *)wallpaperInfo) isDefault])
            background = [[TGDefaultPasscodeBackground alloc] initWithSize:size];
    }
    
    if (background == nil)
    {
        background = [[TGImageBasedPasscodeBackground alloc] initWithImage:[[LegacyComponentsGlobals provider] currentWallpaperImage] size:size];
    }
    
    _currentWallpaperInfo = wallpaperInfo;
    
    _backgroundView.image = [background backgroundImage];
    [_pinView setBackground:background];
    [_simpleKeyboardView setBackground:background];
}

- (void)setFrame:(CGRect)frame
{
    bool updateBackground = false;
    if ((self.frame.size.width < self.frame.size.height) != (frame.size.width < frame.size.height))
        updateBackground = true;
    
    [super setFrame:frame];
    
    if (updateBackground)
        [self _updateBackground:frame.size];
}

- (void)setCancel:(void (^)())cancel
{
    _cancel = [cancel copy];
    _simpleKeyboardCancelButton.hidden = _simpleKeyboardDeleteButton.hidden || cancel == nil;
    _complexCancelButton.hidden = !_simpleKeyboardDeleteButton.hidden || cancel == nil;
    _complexNextButton.hidden = !_isComplex;
}

- (void)simpleKeyboardCancel
{
    if (_cancel)
        _cancel();
}

- (void)simpleKeyboardNext
{
    if (_passcode.length != 0 && _complexPasscodeEntered)
        _complexPasscodeEntered();
}

- (void)simpleKeyboardDelete
{
    NSString *text = _textField.text;
    if (text.length != 0)
    {
        text = [text substringToIndex:text.length - 1];
        _textField.text = text;
        [self setPasscode:text];
    }
}

- (void)setPasscode:(NSString *)passcode
{
    _passcode = passcode;
    [_pinView setCharacterCount:passcode.length maxCharacterCount:_isComplex ? 0 : 4];
}

- (void)pinViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded && ![_textField isFirstResponder] && _isComplex)
    {
        [_textField becomeFirstResponder];
    }
}

- (bool)errorTitleReplacesTitle
{
    if (_isComplex)
        return false;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 480)
        return true;
    
    return false;
}

- (void)setTitle:(NSString *)title errorTitle:(NSString *)errorTitle isComplex:(bool)isComplex animated:(bool)animated
{
    animated = false;
    
    _title = title;
    _errorTitle = errorTitle;
    _isComplex = isComplex;
    
    _titleLabel.font = TGSystemFontOfSize([self titleFontSize]);
    _infoLabel.font = TGSystemFontOfSize([self infoFontSize]);
    
    if (!animated)
    {
        if (errorTitle.length != 0)
        {
            if ([self errorTitleReplacesTitle])
                _titleLabel.text = errorTitle;
            else
            {
                _titleLabel.text = title;
                _infoLabel.text = errorTitle;
            }
            
            [_titleLabel sizeToFit];
            [_infoLabel sizeToFit];
        }
        else
        {
            _titleLabel.text = title;
            [_titleLabel sizeToFit];
            
            _infoLabel.text = errorTitle;
            [_infoLabel sizeToFit];
        }
        
        _textField.text = @"";
        
        if (_isComplex)
        {
            if (_textField.inputView != nil)
            {
                _textField.inputView = nil;
                [_textField resignFirstResponder];
            }
            [_textField becomeFirstResponder];
            _simpleKeyboardView.hidden = true;
            _simpleKeyboardCancelButton.hidden = true;
            _simpleKeyboardDeleteButton.hidden = true;
            _complexCancelButton.hidden = _cancel == nil;
            _complexNextButton.hidden = false;
        }
        else
        {
            if (_textField.inputView == nil)
            {
                _textField.inputView = _inputView;
                [_textField resignFirstResponder];
            }
            [_textField becomeFirstResponder];
            _simpleKeyboardView.hidden = false;
            _simpleKeyboardCancelButton.hidden = _cancel == nil;
            _simpleKeyboardDeleteButton.hidden = false;
            _complexCancelButton.hidden = true;
            _complexNextButton.hidden = true;
        }

        [_pinView setCharacterCount:0 maxCharacterCount:_isComplex ? 0 : 4];
        
        [self setPasscode:@""];
        
        [self setNeedsLayout];
        
        if (_passcodeChanged)
            _passcodeChanged(_passcode);
    }
}

- (void)setErrorTitle:(NSString *)errorTitle
{
    if (!TGStringCompare(_errorTitle, errorTitle))
    {
        _errorTitle = errorTitle;
        if (_errorTitle.length != 0)
        {
            if ([self errorTitleReplacesTitle])
            {
                _titleLabel.text = _errorTitle;
                [_titleLabel sizeToFit];
                [self setNeedsLayout];
            }
            else
            {
                _infoLabel.text = _errorTitle;
                [_infoLabel sizeToFit];
                [self setNeedsLayout];
            }
        }
        else
        {
            _titleLabel.text = _title;
            [_titleLabel sizeToFit];
            
            _infoLabel.text = _errorTitle;
            [_infoLabel sizeToFit];
        }
    }
}

- (NSString *)passcode
{
    return _passcode;
}

- (void)resetPasscode
{
    _textField.text = @"";
    [self setPasscode:@""];
}

- (void)becomeFirstResponder
{
    [_textField becomeFirstResponder];
}

- (void)willMoveToWindow:(UIWindow *)window {
    [super willMoveToWindow:window];
    [_textField becomeFirstResponder];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_textField becomeFirstResponder];
    });
}

- (BOOL)resignFirstResponder
{
    return [_textField resignFirstResponder];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _backgroundView.frame = self.bounds;
    
    CGFloat keyboardOffset = 0.0f;
    
    CGFloat titleOffset = 0.0f;
    CGFloat pinOffset = 0.0f;
    CGFloat infoOffset = 0.0f;
    CGFloat topOffset = 20.0f;
    CGFloat bottomOffset = 0.0f;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height)
    {
        CGFloat tmp = screenSize.width;
        screenSize.width = screenSize.height;
        screenSize.height = tmp;
    }
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
    {
        keyboardOffset = CGFloor((self.frame.size.height - 500.0f) / 2.0f + 119.0f);
        titleOffset = 122.0f;
        pinOffset = 89.0f;
        infoOffset = 7.0f;
    }
    else if ((int)screenSize.height == 812)
    {
        keyboardOffset = 300.0f;
        titleOffset = 116.0f;
        pinOffset = 79.0f + TGRetinaPixel;
        infoOffset = 6.0f - TGRetinaPixel;
        topOffset = 44.0f;
        bottomOffset = 34.0f;
    }
    else if ((int)screenSize.height == 736)
    {
        keyboardOffset = 246.0f;
        titleOffset = 112.0f;
        pinOffset = 79.0f + TGRetinaPixel;
        infoOffset = 6.0f - TGRetinaPixel;
    }
    else if ((int)screenSize.height == 667)
    {
        keyboardOffset = 206.0f;
        titleOffset = 112.0f;
        pinOffset = 79.0f + TGRetinaPixel;
        infoOffset = 6.0f - TGRetinaPixel;
    }
    else if ((int)screenSize.height == 568)
    {
        keyboardOffset = 163.0f;
        titleOffset = 98.0f - TGRetinaPixel;
        pinOffset = 72.0f;
        infoOffset = 0.0f;
    }
    else
    {
        keyboardOffset = 109.0f;
        titleOffset = 68.0f;
        pinOffset = 45.0f;
        infoOffset = 0.0f;
    }
    
    if (_complexNextButton.hidden)
    {
        _complexCancelButton.frame = CGRectMake(self.frame.size.width - _complexCancelButton.frame.size.width, topOffset, _complexCancelButton.frame.size.width, _complexCancelButton.frame.size.height);
    }
    else
    {
        _complexNextButton.frame = CGRectMake(self.frame.size.width - _complexNextButton.frame.size.width, topOffset, _complexNextButton.frame.size.width, _complexNextButton.frame.size.height);
        _complexCancelButton.frame = CGRectMake(0.0f, topOffset, _complexCancelButton.frame.size.width, _complexCancelButton.frame.size.height);
    }
    
    _simpleKeyboardView.frame = CGRectMake(CGFloor((self.frame.size.width - _simpleKeyboardView.frame.size.width) / 2.0f), keyboardOffset, _simpleKeyboardView.frame.size.width, _simpleKeyboardView.frame.size.height);
    
    CGFloat textFieldWidth = 0.0f;
    
    if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
    {
        textFieldWidth = 320.0f;
        
        _simpleKeyboardCancelButton.frame = CGRectMake(CGRectGetMinX(_simpleKeyboardView.frame) - 23.0f, CGRectGetMaxY(_simpleKeyboardView.frame) - _simpleKeyboardCancelButton.frame.size.height - 10.0f, _simpleKeyboardCancelButton.frame.size.width, _simpleKeyboardCancelButton.frame.size.height);
        
        _simpleKeyboardDeleteButton.frame = CGRectMake(CGRectGetMaxX(_simpleKeyboardView.frame) - _simpleKeyboardDeleteButton.frame.size.width + 23.0f, CGRectGetMaxY(_simpleKeyboardView.frame) - _simpleKeyboardDeleteButton.frame.size.height - 10.0f, _simpleKeyboardDeleteButton.frame.size.width, _simpleKeyboardDeleteButton.frame.size.height);
    }
    else
    {
        textFieldWidth = MAX(16.0f, self.frame.size.width - 17.0f * 2.0f);
        
        _simpleKeyboardCancelButton.frame = CGRectMake(0.0f, self.frame.size.height - _simpleKeyboardCancelButton.frame.size.height, _simpleKeyboardCancelButton.frame.size.width, _simpleKeyboardCancelButton.frame.size.height);
        _simpleKeyboardDeleteButton.frame = CGRectMake(self.frame.size.width - _simpleKeyboardDeleteButton.frame.size.width, self.frame.size.height - _simpleKeyboardDeleteButton.frame.size.height, _simpleKeyboardDeleteButton.frame.size.width, _simpleKeyboardDeleteButton.frame.size.height);
    }
    
    CGFloat topInset = topOffset + 44.0f;
    CGFloat bottomInset = self.frame.size.width > self.frame.size.height ? 162.0f : 216.0f + bottomOffset;
    CGFloat areaHeight = self.bounds.size.height - topInset - bottomInset;
    
    CGSize titleSize = _titleLabel.frame.size;
    CGSize infoSize = _infoLabel.frame.size;
    
    CGFloat textFieldHeight = 41.0f;
    
    if (_isComplex)
    {
        _titleLabel.frame = CGRectMake(CGFloor((self.bounds.size.width - titleSize.width) / 2.0f), CGFloor(areaHeight / 2.0f) - titleSize.height - 1.0f, titleSize.width, titleSize.height);
        _pinView.frame = CGRectMake(CGFloor((self.frame.size.width - textFieldWidth) / 2.0f), CGRectGetMaxY(_titleLabel.frame) + 23.0f, textFieldWidth, textFieldHeight);
        _infoLabel.frame = CGRectMake(CGFloor((self.bounds.size.width - infoSize.width) / 2.0f), CGRectGetMaxY(_pinView.frame) + 25.0f + TGRetinaPixel, infoSize.width, infoSize.height);
    }
    else
    {
        _titleLabel.frame = CGRectMake(CGFloor((self.bounds.size.width - titleSize.width) / 2.0f), _simpleKeyboardView.frame.origin.y - titleOffset, titleSize.width, titleSize.height);
        _pinView.frame = CGRectMake(0.0f, _simpleKeyboardView.frame.origin.y - pinOffset, self.frame.size.width, textFieldHeight);
        _infoLabel.frame = CGRectMake(CGFloor((self.bounds.size.width - infoSize.width) / 2.0f), CGRectGetMaxY(_pinView.frame) + infoOffset, infoSize.width, infoSize.height);
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _textField)
    {
        NSString *text = [textField.text stringByReplacingCharactersInRange:range withString:string];
        
        if (!_isComplex)
        {
            for (NSUInteger i = 0; i < text.length; i++)
            {
                unichar c = [text characterAtIndex:i];
                if (!(c >= '0' && c <= '9'))
                    return false;
            }
        }
        
        if (!_isComplex && text.length > 4)
            return false;
        
        if (!_isComplex)
            [_pinView setCharacterCount:text.length maxCharacterCount:4];
        
        [self setPasscode:text];
        
        if (_passcodeChanged)
            _passcodeChanged(_passcode);
        
        if (!_isComplex && text.length == 4)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (_simplePasscodeEntered)
                    _simplePasscodeEntered();
            });
        }
    }
    
    return true;
}

- (BOOL)textFieldShouldReturn:(UITextField *)__unused textField
{
    if (!_isComplex)
    {
        if (_passcode.length == 4 && _simplePasscodeEntered)
            _simplePasscodeEntered();
    }
    else
    {
        if (_passcode.length != 0 && _complexPasscodeEntered)
            _complexPasscodeEntered();
    }
    
    return false;
}

@end
