#import "TGSearchBar.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"

#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/TGFont.h>

#import <LegacyComponents/TGModernButton.h>

#import <LegacyComponents/TGTimerTarget.h>

#import <LegacyComponents/TGTextField.h>

#import <LegacyComponents/TGStringUtils.h>

@interface TGSearchBar () <UITextFieldDelegate>
{
    CGFloat _cancelButtonWidth;
    
    TGSearchBarPallete *_pallete;
}

@property (nonatomic, strong) UIView *wrappingClip;
@property (nonatomic, strong) UIView *wrappingView;

@property (nonatomic, strong) UIImageView *textFieldBackground;

@property (nonatomic, strong) UIImage *normalTextFieldBackgroundImage;
@property (nonatomic, strong) UIImage *activeTextFieldBackgroundImage;

@property (nonatomic) bool showsCustomCancelButton;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UILabel *prefixLabel;
@property (nonatomic, strong) UIImageView *customSearchIcon;
@property (nonatomic, strong) UIActivityIndicatorView *customSearchActivityIndicator;
@property (nonatomic, strong) NSTimer *searchActivityTimer;
@property (nonatomic, strong) UIButton *customClearButton;

@property (nonatomic, strong) UIView *customScopeButtonContainer;
@property (nonatomic, strong) UISegmentedControl *customSegmentedControl;
@property (nonatomic) int customCurrentScope;

@end

@implementation TGSearchBar

+ (CGFloat)searchBarBaseHeight
{
    return 44.0f;
}

- (CGFloat)baseHeight {
    if (self.showsScopeBar)
        return 44.0f;
    if (_style == TGSearchBarStyleKeyboard) {
        return [self inputHeight] + 17.0f;
    }
    return [self inputHeight] + 12.0f;
}

- (CGFloat)inputContentOffset {
    if (_style == TGSearchBarStyleKeyboard) {
        return 3.0f;
    }
    return _style == TGSearchBarStyleLightAlwaysPlain ? 3.0f : 0.0f;
}

- (CGFloat)searchIconOffset {
    return _style == TGSearchBarStyleLightAlwaysPlain ? TGScreenPixel : 0.0f;
}

- (CGFloat)inputHeight {
    if (_style == TGSearchBarStyleKeyboard) {
        return 33.0f;
    } else {
        return _style == TGSearchBarStyleLightAlwaysPlain ? 36.0f : 28.0f;
    }
}

+ (CGFloat)searchBarScopeHeight
{
    return 44.0f;
}

- (CGFloat)topPadding
{
    if (_style == TGSearchBarStyleKeyboard)
        return 4.0f;
    
    return -1.0f;
}

- (CGFloat)cancelButtonPadding
{
    if (_style == TGSearchBarStyleKeyboard)
        return -2.0f;
    
    return 0.0f;
}

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame style:TGSearchBarStyleLightPlain];
}

- (instancetype)initWithFrame:(CGRect)frame style:(TGSearchBarStyle)style
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _delayActivity = true;
        
        _wrappingClip = [[UIView alloc] initWithFrame:CGRectMake(0.0f, -20.0f, frame.size.width, frame.size.height + 20.0f)];
        _wrappingClip.clipsToBounds = true;
        [self addSubview:_wrappingClip];
        
        _wrappingView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 20.0f, frame.size.width, frame.size.height)];
        [_wrappingClip addSubview:_wrappingView];
        
        _style = style;
        
        NSString *backgroundFileName = nil;
        NSString *backgroundActiveFileName = nil;
        
        UIImage *backgroundManualImage = nil;
        UIImage *backgroundManualActiveImage = nil;
        
        if (_style == TGSearchBarStyleDefault)
        {
            backgroundFileName = @"SearchBarBackground.png";
            backgroundActiveFileName = @"SearchBarBackground_Active.png";
        }
        else if (_style == TGSearchBarStyleDark)
        {
            backgroundFileName = @"SearchBarBackgroundDark.png";
            backgroundActiveFileName = @"SearchBarBackgroundDark.png";
        }
        else if (_style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain || _style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleHeader)
        {
            static UIImage *image = nil;
            static UIImage *imagePlain = nil;
            static UIImage *imagePlainForced = nil;
            static UIImage *imageHeader = nil;
            
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 3.0f), false, 0.0f);
                CGContextRef context = UIGraphicsGetCurrentContext();
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 3.0f));
                imagePlain = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
                CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 3.0f));
                imagePlainForced = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
                
                CGContextSetFillColorWithColor(context, UIColorRGB(0xc8c7cc).CGColor);
                CGFloat separatorHeight = TGScreenPixel;
                CGContextFillRect(context, CGRectMake(0.0f, 3.0f - separatorHeight, 1.0f, separatorHeight));
                
                image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
                UIGraphicsEndImageContext();
                
                
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 3.0f), true, 0.0f);
                context = UIGraphicsGetCurrentContext();
                CGContextSetFillColorWithColor(context, UIColorRGB(0xf7f7f7).CGColor);
                CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 3.0f));
                
                CGContextSetFillColorWithColor(context, UIColorRGB(0xc8c7cc).CGColor);
                CGContextFillRect(context, CGRectMake(0.0f, 3.0f - separatorHeight, 1.0f, separatorHeight));
                
                imageHeader = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
                
                UIGraphicsEndImageContext();
            });
            
            if (_style == TGSearchBarStyleHeader)
            {
                backgroundManualImage = imageHeader;
                backgroundManualActiveImage = imageHeader;
            }
            else
            {
                backgroundManualImage = _style == TGSearchBarStyleLight ? image : imagePlain;
                backgroundManualActiveImage = _style == TGSearchBarStyleLightAlwaysPlain ? imagePlainForced : image;
            }
        }
        
        UIImage *backgroundImage = nil;
        if (backgroundManualImage != nil)
            backgroundImage = backgroundManualImage;
        else
            backgroundImage = [TGImageNamed(backgroundFileName) stretchableImageWithLeftCapWidth:1 topCapHeight:1];
        _customBackgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
        _customBackgroundView.image = backgroundImage;
        _customBackgroundView.userInteractionEnabled = true;
        [_customBackgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundTapGesture:)]];
        [_wrappingView addSubview:_customBackgroundView];
        
        UIImage *activeBackgroundImage = nil;
        if (backgroundManualActiveImage != nil)
            activeBackgroundImage = backgroundManualActiveImage;
        else
            activeBackgroundImage = [TGImageNamed(backgroundActiveFileName) stretchableImageWithLeftCapWidth:1 topCapHeight:1];
        _customActiveBackgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
        _customActiveBackgroundView.image = activeBackgroundImage;
        _customActiveBackgroundView.alpha = 0.0f;
        [_wrappingView addSubview:_customActiveBackgroundView];
        
        _textFieldBackground = [[UIImageView alloc] initWithImage:self.normalTextFieldBackgroundImage];
        _textFieldBackground.userInteractionEnabled = false;
        [_wrappingView addSubview:_textFieldBackground];
        
        UIColor *placeholderColor = nil;
        if (_style == TGSearchBarStyleDefault)
            placeholderColor = UIColorRGB(0x8e8e93);
        else if (_style == TGSearchBarStyleDark)
            placeholderColor = [UIColor whiteColor];
        else if (_style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain || _style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleHeader)
            placeholderColor = UIColorRGB(0x8e8e93);
        
        _placeholderLabel = [[UILabel alloc] init];
        _placeholderLabel.textAlignment = NSTextAlignmentLeft;
        _placeholderLabel.userInteractionEnabled = false;
        _placeholderLabel.textColor = placeholderColor;
        _placeholderLabel.backgroundColor = [UIColor clearColor];
        _placeholderLabel.font = TGSystemFontOfSize(style == TGSearchBarStyleLightAlwaysPlain ? 16.0f : 14.0f);
        _placeholderLabel.text = TGLocalized(@"Common.Search");
        [_wrappingView addSubview:_placeholderLabel];
        
        _prefixLabel = [[UILabel alloc] init];
        _prefixLabel.textAlignment = NSTextAlignmentLeft;
        _prefixLabel.userInteractionEnabled = false;
        _prefixLabel.textColor = placeholderColor;
        _prefixLabel.backgroundColor = [UIColor clearColor];
        _prefixLabel.font = TGSystemFontOfSize(style == TGSearchBarStyleLightAlwaysPlain ? 16.0f : 14.0f);
        [_wrappingView addSubview:_prefixLabel];
        
        UIImage *iconImage = nil;
        if (_style == TGSearchBarStyleDefault)
        {
            iconImage = TGImageNamed(@"SearchBarIcon.png");
        }
        else if (_style == TGSearchBarStyleDark)
        {
            iconImage = TGImageNamed(@"SearchBarIconDark.png");
        }
        else if (_style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain || _style == TGSearchBarStyleHeader)
        {
            iconImage = [TGSearchBar searchBarIcon:UIColorRGB(0x8e8e93)];
        }
        else if (_style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleKeyboard)
        {
            iconImage = TGImageNamed(@"SearchBarIconLightLarge.png");
        }
        
        _customSearchIcon = [[UIImageView alloc] initWithImage:iconImage];
        _customSearchIcon.userInteractionEnabled = false;
        [_wrappingView addSubview:_customSearchIcon];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    return [super hitTest:point withEvent:event];
}

+ (UIImage *)searchBarIcon:(UIColor *)color
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(13, 13), false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, 1.0f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextStrokeEllipseInRect(context, CGRectMake(0.5f, 0.5f, 9.0f, 9.0f));
    
    CGContextSetLineWidth(context, 1.5f);
    CGContextMoveToPoint(context, 8.5f, 8.5f);
    CGContextAddLineToPoint(context, 8.5f + 3.5f, 8.5f + 3.5f);
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)setHighContrast:(bool)highContrast {
    if (_highContrast != highContrast) {
        _highContrast = highContrast;
        _textFieldBackground.image = _showsCustomCancelButton ? self.activeTextFieldBackgroundImage : self.normalTextFieldBackgroundImage;
    }
}

- (void)setAlwaysExtended:(bool)alwaysExtended
{
    if (_alwaysExtended != alwaysExtended)
    {
        _alwaysExtended = alwaysExtended;
        
        [self layoutSubviews];
    }
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
}

- (void)sizeToFit
{
    CGFloat requiredHeight = 0;
    
    if (_searchBarShouldShowScopeControl && ![self landscapeMode] && !_scopeBarCollapsed)
    {
        requiredHeight = [self baseHeight] + [TGSearchBar searchBarScopeHeight];
    }
    else
    {
        requiredHeight = [self baseHeight];
    }
    
    if (_style == TGSearchBarStyleLight)
        requiredHeight += 4.0f;
    
    CGRect frame = self.frame;
    frame.size.height = requiredHeight;
    self.frame = frame;
}

- (BOOL)showsCancelButton
{
    return _showsCustomCancelButton;
}

- (void)setPallete:(TGSearchBarPallete *)pallete
{
    _pallete = pallete;
    
    _customSearchActivityIndicator.color = _pallete.placeholderColor;
    
    _customTextField.textColor = pallete.textColor;
    _prefixLabel.textColor = pallete.placeholderColor;
    _placeholderLabel.textColor = pallete.placeholderColor;
    
    [UIView performWithoutAnimation:^
    {
        bool shouldFlip = _customTextField.isFirstResponder;
        if (shouldFlip)
            [_customTextField resignFirstResponder];
        _customTextField.keyboardAppearance = _style == TGSearchBarStyleDark || _pallete.isDark ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
        if (shouldFlip)
            [_customTextField becomeFirstResponder];
    }];
    _customSearchIcon.image = [TGSearchBar searchBarIcon:pallete.placeholderColor];
    [_customClearButton setBackgroundImage:_pallete.clearIcon forState:UIControlStateNormal];
    
    _normalTextFieldBackgroundImage = nil;
    _activeTextFieldBackgroundImage = nil;
    _textFieldBackground.image = _showsCustomCancelButton ? self.activeTextFieldBackgroundImage : self.normalTextFieldBackgroundImage;
    
    UIImage *backgroundManualImage = nil;
    UIImage *backgroundManualActiveImage = nil;
    
    if (_style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain || _style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleHeader || _style == TGSearchBarStyleKeyboard)
    {
        [(TGModernButton *)_customCancelButton setTitleColor:_pallete.accentColor];
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 3.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 3.0f));
        UIImage *imagePlain = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
        CGContextSetFillColorWithColor(context, _style == TGSearchBarStyleLightAlwaysPlain ? pallete.menuBackgroundColor.CGColor : pallete.plainBackgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 3.0f));
        UIImage *imagePlainForced = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
        
        CGContextSetFillColorWithColor(context, pallete.barSeparatorColor.CGColor);
        CGFloat separatorHeight = TGScreenPixel;
        CGContextFillRect(context, CGRectMake(0.0f, 3.0f - separatorHeight, 1.0f, separatorHeight));
        
        UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
        UIGraphicsEndImageContext();
        
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 3.0f), true, 0.0f);
        context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, pallete.barBackgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, 1.0f, 3.0f));
        
        CGContextSetFillColorWithColor(context, pallete.barSeparatorColor.CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 3.0f - separatorHeight, 1.0f, separatorHeight));
        
        UIImage *imageHeader = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:0 topCapHeight:1];
        
        UIGraphicsEndImageContext();
        
        if (_style == TGSearchBarStyleHeader)
        {
            backgroundManualImage = imageHeader;
            backgroundManualActiveImage = imageHeader;
        }
        else
        {
            backgroundManualImage = _style == TGSearchBarStyleLight ? image : imagePlain;
            backgroundManualActiveImage = _style == TGSearchBarStyleLightAlwaysPlain ? imagePlainForced : image;
        }
        
        if (backgroundManualImage != nil)
            _customBackgroundView.image = backgroundManualImage;
        
        if (backgroundManualActiveImage != nil)
            _customActiveBackgroundView.image = backgroundManualActiveImage;
    }
}

- (UIImage *)normalTextFieldBackgroundImage
{
    if (_highContrast) {
        UIColor *highContrastColor = _pallete != nil ? _pallete.highContrastBackgroundColor : UIColorRGB(0xe5e5e5);
        CGFloat diameter = 14.0f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, highContrastColor.CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
        UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(diameter / 2.0f) topCapHeight:(NSInteger)(diameter / 2.0f)];
        UIGraphicsEndImageContext();
        
        return image;
    } else if (_normalTextFieldBackgroundImage == nil) {
        NSString *fileName = nil;
        
        if (_style == TGSearchBarStyleDefault)
            fileName = @"SearchInputField.png";
        else if (_style == TGSearchBarStyleDark)
            fileName = @"SearchInputFieldDark.png";
        else if (_style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain)
        {
            UIColor *color = _pallete != nil ? _pallete.backgroundColor : UIColorRGB(0xf1f1f1);
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(14.0f, 14.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 14.0f, 14.0f));
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            image = [image stretchableImageWithLeftCapWidth:(int)(image.size.width / 2) topCapHeight:(int)(image.size.height / 2)];
            UIGraphicsEndImageContext();
            
            _normalTextFieldBackgroundImage = image;
            return _normalTextFieldBackgroundImage;
        }
        else if (_style == TGSearchBarStyleLightAlwaysPlain)
        {
            CGFloat diameter = 16.0f;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, (_pallete != nil ? _pallete.highContrastBackgroundColor : UIColorRGB(0xe4e4e4)).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(diameter / 2.0f) topCapHeight:(NSInteger)(diameter / 2.0f)];
            UIGraphicsEndImageContext();
            
            _normalTextFieldBackgroundImage = image;
            return _normalTextFieldBackgroundImage;
        }
        else if (_style == TGSearchBarStyleKeyboard)
        {
            CGFloat diameter = 33.0;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, (_pallete != nil ? _pallete.highContrastBackgroundColor : UIColorRGB(0xe4e4e4)).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(diameter / 2.0f) topCapHeight:(NSInteger)(diameter / 2.0f)];
            UIGraphicsEndImageContext();
            
            _normalTextFieldBackgroundImage = image;
            return _normalTextFieldBackgroundImage;
        }
        else if (_style == TGSearchBarStyleHeader)
        {
            CGFloat diameter = 10.0f;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, (_pallete != nil ? _pallete.highContrastBackgroundColor : UIColorRGB(0xe4e4e4)).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            UIImage *headerImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)(diameter / 2.0f) topCapHeight:(NSInteger)(diameter / 2.0f)];
            UIGraphicsEndImageContext();
            
            _normalTextFieldBackgroundImage = headerImage;
            return _normalTextFieldBackgroundImage;
        }
    
        UIImage *rawImage = TGImageNamed(fileName);
        _normalTextFieldBackgroundImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    }
    
    return _normalTextFieldBackgroundImage;
}

- (UIImage *)activeTextFieldBackgroundImage
{
    if (_activeTextFieldBackgroundImage == nil)
    {
        NSString *fileName = nil;
        
        if (_style == TGSearchBarStyleDefault)
            fileName = @"SearchInputField_Active.png";
        else if (_style == TGSearchBarStyleDark)
            fileName = @"SearchInputFieldDark.png";
        else if (_style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain)
        {
            UIColor *color = _pallete != nil ? _pallete.backgroundColor : UIColorRGB(0xf1f1f1);
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(14.0f, 14.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 14.0f, 14.0f));
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            image = [image stretchableImageWithLeftCapWidth:(int)(image.size.width / 2) topCapHeight:(int)(image.size.height / 2)];
            UIGraphicsEndImageContext();
            
            _activeTextFieldBackgroundImage = image;
            return _activeTextFieldBackgroundImage;
        }
        else if (_style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleHeader || _style == TGSearchBarStyleKeyboard) {
            _activeTextFieldBackgroundImage = [self normalTextFieldBackgroundImage];
            return _activeTextFieldBackgroundImage;
        }

        UIImage *rawImage = TGImageNamed(fileName);
        _activeTextFieldBackgroundImage = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:(int)(rawImage.size.height / 2)];
    }
    
    return _activeTextFieldBackgroundImage;
}

- (UITextField *)maybeCustomTextField
{
    return _customTextField;
}

- (UITextField *)customTextField
{
    if (_customTextField == nil)
    {
        CGRect frame = _textFieldBackground.frame;
        frame.origin.y -= TGIsRetina() ? 0.0f : 0.0f;
        frame.origin.x += 27;
        frame.size.width -= 27 + 8 + 14;
        _customTextField = [[TGTextField alloc] initWithFrame:frame];
        __weak TGSearchBar *weakSelf = self;
        ((TGTextField *)_customTextField).deleteBackwardEmpty = ^{
            __strong TGSearchBar *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_clearPrefix) {
                strongSelf->_clearPrefix(false);
            }
        };
        _customTextField.font = _placeholderLabel.font;
        if (iosMajorVersion() >= 7)
            _customTextField.textAlignment = NSTextAlignmentNatural;
        _customTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        _customTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        
        UIColor *textColor = nil;
        UIImage *clearImage = nil;
        
        if (_style == TGSearchBarStyleDefault || _style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain || _style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleHeader || _style == TGSearchBarStyleKeyboard)
        {
            textColor = _pallete != nil ? _pallete.textColor : [UIColor blackColor];
            clearImage = TGImageNamed(@"SearchBarClearIcon.png");
        }
        else if (_style == TGSearchBarStyleDark)
        {
            textColor = [UIColor whiteColor];
            clearImage = TGImageNamed(@"SearchBarClearIconDark.png");
        }
        
        _customTextField.textColor = textColor;
        
        _customTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        _customTextField.returnKeyType = UIReturnKeySearch;
        _customTextField.keyboardAppearance = _style == TGSearchBarStyleDark || _pallete.isDark ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
        _customTextField.delegate = self;
        [_customTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
        _customClearButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, clearImage.size.width, clearImage.size.height)];
        [_customClearButton setBackgroundImage:_pallete != nil ? _pallete.clearIcon : clearImage forState:UIControlStateNormal];
        [_customClearButton addTarget:self action:@selector(customClearButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _customClearButton.hidden = true;
        
        [_wrappingView addSubview:_customTextField];
        [_wrappingView addSubview:_customClearButton];
        
        [self setNeedsLayout];
    }
    
    return _customTextField;
}

- (UIButton *)customCancelButton
{
    if (_customCancelButton == nil)
    {
        _cancelButtonWidth = [TGLocalized(@"Common.Cancel") sizeWithFont:TGSystemFontOfSize(17.0f)].width + 11.0f;
        
        CGRect textFieldBackgroundFrame = _textFieldBackground.frame;
        _customCancelButton = [[TGModernButton alloc] initWithFrame:CGRectMake(textFieldBackgroundFrame.origin.x + textFieldBackgroundFrame.size.width + 10, 0, _cancelButtonWidth, [self baseHeight])];
        [_customCancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
        
        UIColor *buttonColor = nil;
        
        if (_style == TGSearchBarStyleDefault || _style == TGSearchBarStyleLight || _style == TGSearchBarStyleLightPlain || _style == TGSearchBarStyleLightAlwaysPlain || _style == TGSearchBarStyleHeader || _style == TGSearchBarStyleKeyboard)
            buttonColor = _pallete != nil ? _pallete.accentColor : TGAccentColor();
        else if (_style == TGSearchBarStyleDark)
            buttonColor = [UIColor whiteColor];
        
        [(TGModernButton *)_customCancelButton setTitleColor:buttonColor];
        _customCancelButton.titleLabel.font = TGSystemFontOfSize(17.0f);
        _customCancelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        _customCancelButton.hidden = true;
        [_customCancelButton addTarget:self action:@selector(searchCancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_wrappingView addSubview:_customCancelButton];
    }
    
    return _customCancelButton;
}

- (void)setShowsCancelButton:(BOOL)showsCancelButton
{
    [self setShowsCancelButton:showsCancelButton animated:false];
}

- (void)setShowsCancelButton:(bool)showsCancelButton animated:(bool)animated
{
    if (_showsCustomCancelButton != showsCancelButton)
    {
        if (showsCancelButton)
        {
            [self customCancelButton];
            _customCancelButton.hidden = _hidesCancelButton;
            
            if (_customScopeButtonTitles.count > 1)
            {
                self.customScopeButtonContainer.hidden = false;
                [_customSegmentedControl setSelectedSegmentIndex:0];
            }
        }
        else
        {
            [_customTextField setText:@""];
            [self updatePlaceholder:@""];
        }
        
        _textFieldBackground.image = showsCancelButton ? self.activeTextFieldBackgroundImage : self.normalTextFieldBackgroundImage;
        
        _showsCustomCancelButton = showsCancelButton;
        
        if (animated)
        {
            if (showsCancelButton)
                _wrappingClip.clipsToBounds = false;
            
            [UIView animateWithDuration:0.2 animations:^
            {
                if (!showsCancelButton)
                {
                    _customTextField.alpha = 0.0f;
                    _customClearButton.alpha = 0.0f;
                }
                
                if (_customScopeButtonTitles.count > 1)
                {
                    [self setSearchBarShouldShowScopeControl:showsCancelButton];
                    _customScopeButtonContainer.alpha = showsCancelButton ? 1.0f : 0.0f;
                }
                
                [self layoutSubviews];
                
                _customActiveBackgroundView.alpha = showsCancelButton ? 1.0f : 0.0f;
            } completion:^(__unused BOOL finished)
            {
                //if (finished)
                {
                    if (showsCancelButton)
                    {
                        _customTextField.alpha = 1.0f;
                        _customClearButton.alpha = 1.0f;
                    }
                    else
                    {
                        _customCancelButton.hidden = true;
                        _customScopeButtonContainer.hidden = true;
                        
                        _wrappingClip.clipsToBounds = true;
                    }
                }
            }];
        }
        else
        {
            _wrappingClip.clipsToBounds = !showsCancelButton;
            
            if (_customScopeButtonTitles.count > 1)
            {
                [self setSearchBarShouldShowScopeControl:showsCancelButton];
                _customScopeButtonContainer.alpha = showsCancelButton ? 1.0f : 0.0f;
            }
            
            _customTextField.alpha = showsCancelButton ? 1.0f : 0.0f;
            _customClearButton.alpha = _customTextField.alpha;
            _customActiveBackgroundView.alpha = showsCancelButton ? 1.0f : 0.0f;
            _customCancelButton.hidden = !showsCancelButton;
            _customScopeButtonContainer.hidden = !showsCancelButton;
            
            [self layoutSubviews];
        }
    }
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    bool landscapeMode = [self landscapeMode];
    
    CGRect clippingFrame = _wrappingClip.frame;
    clippingFrame.size = CGSizeMake(bounds.size.width, bounds.size.height + 20.0f);
    _wrappingClip.frame = clippingFrame;
    
    CGRect wrappingFrame = _wrappingView.frame;
    wrappingFrame.size = bounds.size;
    _wrappingView.frame = wrappingFrame;
    
    float retinaPixel = TGIsRetina() ? TGScreenPixel : 0.0f;
    const float scopeBarHorizontalWidth = 220;
    
    CGFloat rightPadding = _showsCustomCancelButton && !_hidesCancelButton ? ((_customScopeButtonContainer != nil && landscapeMode ? scopeBarHorizontalWidth : 0) + _cancelButtonWidth) : 0.0f;
    
    CGFloat safeInsetHeight = self.safeAreaInset.top > FLT_EPSILON ? self.safeAreaInset.top : 20.0f;
    _customBackgroundView.frame = CGRectMake(0, ((_showsCustomCancelButton || _alwaysExtended) ? -safeInsetHeight : 0.0f), self.frame.size.width, self.frame.size.height + (_showsCustomCancelButton || _alwaysExtended ? safeInsetHeight : 0.0f));
    _customActiveBackgroundView.frame = _customBackgroundView.frame;
    
    _textFieldBackground.frame = CGRectMake(8 + _safeAreaInset.left, 9 + [self topPadding], self.frame.size.width - 16 - rightPadding - _safeAreaInset.left - _safeAreaInset.right, [self inputHeight]);
    
    CGFloat prefixOffset = 0.0f;
    {
        [_prefixLabel sizeToFit];
        
        CGRect frame = _textFieldBackground.frame;
        frame.origin.y += 5.0f;
        frame.origin.x += 27;
        frame.size = _prefixLabel.bounds.size;
        
        frame.size.width = MIN(frame.size.width, CGFloor((bounds.size.width - rightPadding - 20.0f) / 2.0f));
        
        _prefixLabel.frame = frame;
        
        prefixOffset = frame.size.width;
    }
    
    CGSize placeholderSize = [_placeholderLabel.text sizeWithFont:_placeholderLabel.font];
    placeholderSize.width = MIN(placeholderSize.width, self.frame.size.width - rightPadding - 50.0f - prefixOffset);
    
    _customSearchIcon.frame = CGRectMake(_showsCustomCancelButton ? (_textFieldBackground.frame.origin.x + 8.0f) : ((CGFloor((self.frame.size.width - placeholderSize.width) / 2) + 10 + TGScreenPixel) - 20), [self searchIconOffset] + [self inputContentOffset] + 16 + retinaPixel + [self topPadding], _customSearchIcon.frame.size.width, _customSearchIcon.frame.size.height);
    
    _customSearchActivityIndicator.frame = (CGRect){{CGFloor(_customSearchIcon.frame.origin.x + (_customSearchIcon.frame.size.width - _customSearchActivityIndicator.frame.size.width) / 2.0f), CGFloor(_customSearchIcon.frame.origin.y + (_customSearchIcon.frame.size.height - _customSearchActivityIndicator.frame.size.height) / 2.0f) + 1.0f + TGScreenPixel}, _customSearchActivityIndicator.frame.size};
    
    _placeholderLabel.frame = CGRectMake(_showsCustomCancelButton ? ((TGIsRTL() ? (CGRectGetMaxX(_textFieldBackground.frame) - placeholderSize.width - 32.0f) : 36 + _safeAreaInset.left) + prefixOffset) : (CGFloor((self.frame.size.width - placeholderSize.width) / 2) + 10 + TGScreenPixel), [self inputContentOffset] + 14 + [self topPadding], placeholderSize.width, placeholderSize.height);
    
    if (_customTextField != nil)
    {
        CGRect frame = _textFieldBackground.frame;
        frame.origin.y -= retinaPixel;
        frame.origin.x += 27;
        frame.size.width -= 27 + 8 + 24;
        
        frame.origin.x += prefixOffset;
        frame.size.width -= prefixOffset;
        
        _customTextField.frame = frame;
        
        _customClearButton.frame = CGRectMake(CGRectGetMaxX(_textFieldBackground.frame) - 22, [self inputContentOffset] + 16 + [self topPadding] + (_style == TGSearchBarStyleLightAlwaysPlain ? 1.0f : 0.0f), _customClearButton.frame.size.width, _customClearButton.frame.size.height);
    }
    
    if (_customCancelButton != nil)
    {
        _customCancelButton.frame = CGRectMake(self.frame.size.width + (_showsCustomCancelButton ? (-_customCancelButton.frame.size.width - 9 - self.safeAreaInset.right) : 9), [self topPadding] + 2.0f + [self cancelButtonPadding], _cancelButtonWidth, [self baseHeight]);
    }
    
    if (_customScopeButtonContainer != nil)
    {
        if (_showsCustomCancelButton)
        {
            if (!landscapeMode)
                _customScopeButtonContainer.frame = CGRectMake(7.0f, self.frame.size.height - 29.0f - 9.0f + [self topPadding], self.frame.size.width - 14.0f, 29.0f);
            else
                _customScopeButtonContainer.frame = CGRectMake(self.frame.size.width - scopeBarHorizontalWidth - _customCancelButton.frame.size.width - self.safeAreaInset.right, 5.0f + [self topPadding], scopeBarHorizontalWidth - 14.0f, 32.0f);
        }
        else
        {
            if (!landscapeMode)
                _customScopeButtonContainer.frame = CGRectMake(7.0f, self.frame.size.height - 29.0f - 9.0f + [self topPadding], self.frame.size.width - 14.0f, 29.0f);
            else
                _customScopeButtonContainer.frame = CGRectMake(self.frame.size.width + 71.0f, 5.0f + [self topPadding], scopeBarHorizontalWidth - 14.0f, 29.0f);
        }
    }
}

- (bool)landscapeMode
{
    static CGFloat landscapeScreenWidth = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        landscapeScreenWidth = MAX(screenSize.width, screenSize.height);
    });

    return self.frame.size.width >= landscapeScreenWidth - FLT_EPSILON;
}

- (void)setSearchBarShouldShowScopeControl:(bool)searchBarShouldShowScopeControl
{
    _searchBarShouldShowScopeControl = searchBarShouldShowScopeControl;
    
    if (_searchBarShouldShowScopeControl)
        self.customScopeButtonContainer.hidden = false;
    
    CGFloat requiredHeight = 0;
    
    if (_searchBarShouldShowScopeControl && ![self landscapeMode])
        requiredHeight = [self baseHeight] + [TGSearchBar searchBarScopeHeight];
    else
        requiredHeight = [self baseHeight];
    
    if (ABS(requiredHeight - self.frame.size.height) > FLT_EPSILON)
    {   
        id<TGSearchBarDelegate> delegate = (id<TGSearchBarDelegate>)self.delegate;
        if ([delegate respondsToSelector:@selector(searchBar:willChangeHeight:)])
            [delegate searchBar:self willChangeHeight:requiredHeight];
    }
}

- (void)setCustomScopeBarHidden:(bool)hidden
{
    self.customScopeButtonContainer.alpha = hidden ? 0.0f : 1.0f;
    self.customScopeButtonContainer.userInteractionEnabled = !hidden;
}

#pragma mark -

- (void)tappedSearchBar:(id)__unused arg
{
}

- (BOOL)becomeFirstResponder
{
    if (![_customTextField isFirstResponder])
    {
        bool shouldBeginEditing = true;
        id<UISearchBarDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(searchBarShouldBeginEditing:)])
            shouldBeginEditing = [delegate searchBarShouldBeginEditing:(UISearchBar *)self];
        
        if (shouldBeginEditing)
        {
            [self.customTextField becomeFirstResponder];
            
            if ([delegate respondsToSelector:@selector(searchBarTextDidBeginEditing:)])
                [delegate searchBarTextDidBeginEditing:(UISearchBar *)self];
            
            return true;
        }
    }
    
    return false;
}

- (BOOL)resignFirstResponder
{
    return [_customTextField resignFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return _customTextField == nil || [_customTextField canBecomeFirstResponder];
}

- (BOOL)canResignFirstResponder
{
    return [_customTextField canResignFirstResponder];
}

- (BOOL)isFirstResponder {
    return [_customTextField isFirstResponder];
}

#pragma mark -

- (void)searchCancelButtonPressed
{
    id delegate = self.delegate;
    
    if ([delegate respondsToSelector:@selector(searchBarCancelButtonClicked:)])
        [delegate searchBarCancelButtonClicked:(UISearchBar *)self];
}

- (UIView *)customScopeButtonContainer
{
    if (_customScopeButtonContainer == nil)
    {
        CGRect frame = CGRectZero;
        if (![self landscapeMode])
            frame = CGRectMake(7.0f, self.frame.size.height - 29.0f - 9.0f, self.frame.size.width - 14.0f, 29.0f);
        else
            frame = CGRectMake(0, 0, self.frame.size.width, 29.0f);
        
        _customScopeButtonContainer = [[UIView alloc] initWithFrame:frame];
        _customScopeButtonContainer.alpha = 0.0f;
        [_wrappingView insertSubview:_customScopeButtonContainer aboveSubview:_customActiveBackgroundView];
        
        _customSegmentedControl = [[UISegmentedControl alloc] initWithItems:self.customScopeButtonTitles];
        
        [_customSegmentedControl setBackgroundImage:_pallete != nil ? _pallete.segmentedControlBackgroundImage : TGComponentsImageNamed(@"ModernSegmentedControlBackground.png") forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [_customSegmentedControl setBackgroundImage:_pallete != nil ? _pallete.segmentedControlSelectedImage : TGComponentsImageNamed(@"ModernSegmentedControlSelected.png") forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [_customSegmentedControl setBackgroundImage:_pallete != nil ? _pallete.segmentedControlSelectedImage : TGComponentsImageNamed(@"ModernSegmentedControlSelected.png") forState:UIControlStateSelected | UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [_customSegmentedControl setBackgroundImage:_pallete != nil ? _pallete.segmentedControlHighlightedImage : TGComponentsImageNamed(@"ModernSegmentedControlHighlighted.png") forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [_customSegmentedControl setDividerImage:_pallete != nil ? _pallete.segmentedControlDividerImage : TGComponentsImageNamed(@"ModernSegmentedControlDivider.png") forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        
        [_customSegmentedControl setTitleTextAttributes:@{UITextAttributeTextColor:_pallete != nil ? _pallete.accentColor : TGAccentColor(), UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateNormal];
        [_customSegmentedControl setTitleTextAttributes:@{UITextAttributeTextColor:_pallete != nil ? _pallete.accentContrastColor : [UIColor whiteColor], UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateSelected];
        
        _customSegmentedControl.frame = CGRectMake(0, _customScopeButtonContainer.frame.size.height - 29.0f, _customScopeButtonContainer.frame.size.width, 29.0f);
        _customSegmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        
        [_customSegmentedControl setSelectedSegmentIndex:0];
        [_customSegmentedControl addTarget:self action:@selector(segmentedControlChanged) forControlEvents:UIControlEventValueChanged];
        
        [_customScopeButtonContainer addSubview:_customSegmentedControl];
    }
    
    return _customScopeButtonContainer;
}
    
- (void)backgroundTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (![_customTextField isFirstResponder])
        {
            bool shouldBeginEditing = true;
            id<UISearchBarDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(searchBarShouldBeginEditing:)])
                shouldBeginEditing = [delegate searchBarShouldBeginEditing:(UISearchBar *)self];
            
            if (shouldBeginEditing)
            {
                [self.customTextField becomeFirstResponder];
                
                if ([delegate respondsToSelector:@selector(searchBarTextDidBeginEditing:)])
                    [delegate searchBarTextDidBeginEditing:(UISearchBar *)self];
            }
        }
    }
}

- (void)updatePlaceholder:(NSString *)text
{
    _placeholderLabel.hidden = text.length != 0;
    _customClearButton.hidden = !_placeholderLabel.hidden && _prefixText.length == 0;
}

- (void)textFieldDidChange:(UITextField *)textField
{
    if (textField == _customTextField)
    {
        NSString *text = textField.text;
        
        id<UISearchBarDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(searchBar:textDidChange:)])
            [delegate searchBar:(UISearchBar *)self textDidChange:text];
        
        [self updatePlaceholder:text];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _customTextField)
    {
        if (textField.text.length != 0)
        {
            id<UISearchBarDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(searchBarSearchButtonClicked:)])
                [delegate searchBarSearchButtonClicked:(UISearchBar *)self];
        }
        
        [textField resignFirstResponder];
        
        return false;
    }
    
    return false;
}

- (void)customClearButtonPressed
{
    if (_customTextField.text.length == 0) {
        if (_prefixText.length != 0) {
            if (_clearPrefix) {
                _clearPrefix(true);
            }
        }
    } else {
        [_customTextField setText:@""];
        [self updatePlaceholder:@""];
        
        [self becomeFirstResponder];
        
        NSString *text = @"";
        
        id<UISearchBarDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(searchBar:textDidChange:)])
            [delegate searchBar:(UISearchBar *)self textDidChange:text];
    }
}

- (NSInteger)selectedScopeButtonIndex
{
    return _customSegmentedControl.selectedSegmentIndex;
}

- (void)setSelectedScopeButtonIndex:(NSInteger)selectedScopeButtonIndex
{
    [self.customSegmentedControl setSelectedSegmentIndex:selectedScopeButtonIndex];
}

- (void)setPlaceholder:(NSString *)placeholder
{
    _placeholder = placeholder;
    _placeholderLabel.text = placeholder;
    
    [self setNeedsLayout];
}

- (NSString *)text
{
    return _customTextField.text;
}

- (void)setText:(NSString *)text
{
    bool layout = _customTextField == nil;
    self.customTextField.text = text;
    if (layout)
        [self setNeedsLayout];
    
    [self textFieldDidChange:_customTextField];
}

- (void)segmentedControlChanged
{
    if (_showsCustomCancelButton)
    {
        id<UISearchBarDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(searchBar:selectedScopeButtonIndexDidChange:)])
            [delegate searchBar:(UISearchBar *)self selectedScopeButtonIndexDidChange:_customSegmentedControl.selectedSegmentIndex];
    }
}

- (void)updateClipping:(CGFloat)clippedHeight
{
    CGFloat offset = self.frame.size.height + MAX(0.0f, MIN(clippedHeight, self.frame.size.height));
    
    CGRect frame = _wrappingClip.frame;
    frame.origin.y = offset - frame.size.height + 20.0f;
    _wrappingClip.frame = frame;
    
    CGRect wrapFrame = _wrappingView.frame;
    wrapFrame.origin.y = -offset + wrapFrame.size.height;
    _wrappingView.frame = wrapFrame;
}

- (void)localizationUpdated
{
    _placeholderLabel.text = TGLocalized(@"Common.Search");
    
    _cancelButtonWidth = [TGLocalized(@"Common.Cancel") sizeWithFont:TGSystemFontOfSize(17.0f)].width + 11.0f;
    
    CGRect textFieldBackgroundFrame = _textFieldBackground.frame;
    _customCancelButton.frame = CGRectMake(textFieldBackgroundFrame.origin.x + textFieldBackgroundFrame.size.width + 10, _customCancelButton.frame.origin.y, _cancelButtonWidth, [self baseHeight]);
    [_customCancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
    
    [_customSegmentedControl removeAllSegments];
    int index = -1;
    for (NSString *itemText in _customScopeButtonTitles)
    {
        index++;
        [_customSegmentedControl insertSegmentWithTitle:itemText atIndex:(NSUInteger)index animated:false];
    }
    
    [self setNeedsLayout];
}

- (void)setShowActivity:(bool)showActivity
{
    if (_showActivity != showActivity)
    {
        [_searchActivityTimer invalidate];
        _searchActivityTimer = nil;
        
        _showActivity = showActivity;
        
        if (_delayActivity && showActivity)
        {
            _searchActivityTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(searchActivityTimerEvent) interval:0.2 repeat:false];
        }
        else
            [self searchActivityTimerEvent];
    }
}

- (void)searchActivityTimerEvent
{
    _customSearchIcon.hidden = _showActivity;
    UIActivityIndicatorView *indicator = _customSearchActivityIndicator;
    if (_showActivity)
    {
        if (indicator == nil)
        {
            indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:4];
            if (_pallete != nil)
                indicator.color = _pallete.placeholderColor;
            indicator.userInteractionEnabled = false;
            indicator.hidden = true;
            [_wrappingView addSubview:indicator];
            
            _customSearchActivityIndicator = indicator;
        }
        
        indicator.hidden = false;
        indicator.frame = (CGRect){{CGFloor(_customSearchIcon.frame.origin.x + (_customSearchIcon.frame.size.width - indicator.frame.size.width) / 2.0f), CGFloor(_customSearchIcon.frame.origin.y + (_customSearchIcon.frame.size.height - indicator.frame.size.height) / 2.0f) + 1.0f}, indicator.frame.size};
        [indicator startAnimating];
    }
    else
    {
        indicator.hidden = true;
        [indicator stopAnimating];
    }
}

- (void)setPrefixText:(NSAttributedString *)prefixText {
    _prefixText = prefixText;
    _prefixLabel.attributedText = prefixText;
    _customClearButton.hidden = !_placeholderLabel.hidden && _prefixText.length == 0;
    
    [self setNeedsLayout];
}

@end


@implementation TGSearchBarPallete

+ (instancetype)palleteWithDark:(bool)dark backgroundColor:(UIColor *)backgroundColor highContrastBackgroundColor:(UIColor *)highContrastBackgroundColor textColor:(UIColor *)textColor placeholderColor:(UIColor *)placeholderColor clearIcon:(UIImage *)clearIcon barBackgroundColor:(UIColor *)barBackgroundColor barSeparatorColor:(UIColor *)barSeparatorColor plainBackgroundColor:(UIColor *)plainBackgroundColor accentColor:(UIColor *)accentColor accentContrastColor:(UIColor *)accentContrastColor menuBackgroundColor:(UIColor *)menuBackgroundColor segmentedControlBackgroundImage:(UIImage *)segmentedControlBackgroundImage segmentedControlSelectedImage:(UIImage *)segmentedControlSelectedImage segmentedControlHighlightedImage:(UIImage *)segmentedControlHighlightedImage segmentedControlDividerImage:(UIImage *)segmentedControlDividerImage
{
    TGSearchBarPallete *pallete = [[TGSearchBarPallete alloc] init];
    pallete->_isDark = dark;
    pallete->_backgroundColor = backgroundColor;
    pallete->_highContrastBackgroundColor = highContrastBackgroundColor;
    pallete->_textColor = textColor;
    pallete->_placeholderColor = placeholderColor;
    pallete->_clearIcon = clearIcon;
    pallete->_barBackgroundColor = barBackgroundColor;
    pallete->_barSeparatorColor = barSeparatorColor;
    pallete->_plainBackgroundColor = plainBackgroundColor;
    pallete->_accentColor = accentColor;
    pallete->_accentContrastColor = accentContrastColor;
    pallete->_menuBackgroundColor = menuBackgroundColor;
    pallete->_segmentedControlBackgroundImage = segmentedControlBackgroundImage;
    pallete->_segmentedControlSelectedImage = segmentedControlSelectedImage;
    pallete->_segmentedControlHighlightedImage = segmentedControlHighlightedImage;
    pallete->_segmentedControlDividerImage = segmentedControlDividerImage;
    return pallete;
}

@end
