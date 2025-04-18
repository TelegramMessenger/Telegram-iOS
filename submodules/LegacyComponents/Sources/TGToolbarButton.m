#import "TGToolbarButton.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

static UIImage *backgroundBack()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"BackButton.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    return image;
}

static UIImage *backgroundBackPressed()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"BackButton_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    return image;
}

static UIImage *backgroundBackLandscape()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"BackButton_Landscape.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    return image;
}

static UIImage *backgroundBackLandscapePressed()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"BackButton_Landscape_Pressed.png"] stretchableImageWithLeftCapWidth:15 topCapHeight:0];
    return image;
}

static UIImage *backgroundGeneric()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"HeaderButton.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    return image;
}

static UIImage *backgroundGenericPressed()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"HeaderButton_Pressed.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    return image;
}

static UIImage *backgroundGenericLandscape()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"HeaderButton_Landscape.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    return image;
}

static UIImage *backgroundGenericPressedLandscape()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"HeaderButton_Landscape_Pressed.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    return image;
}

static UIImage *backgroundDone()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Blue.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDonePressed()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Blue_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDoneLandscape()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Blue_Landscape.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDoneLandscapePressed()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Blue_Landscape_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDoneBlack()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Login_Blue.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDoneBlackPressed()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Login_Blue_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDoneBlackLandscape()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Login_Blue_Landscape.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDoneBlackLandscapePressed()
{
    static UIImage *image = nil;
    if (image == nil)
    {
        UIImage *rawImage = [UIImage imageNamed:@"HeaderButton_Login_Blue_Landscape_Pressed.png"];
        image = [rawImage stretchableImageWithLeftCapWidth:(int)(rawImage.size.width / 2) topCapHeight:0];
    }
    return image;
}

static UIImage *backgroundDelete()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"Header_Button_Delete.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    return image;
}

static UIImage *backgroundDeleteLandscape()
{
    static UIImage *image = nil;
    if (image == nil)
        image = [[UIImage imageNamed:@"Header_Button_Delete.png"] stretchableImageWithLeftCapWidth:6 topCapHeight:0];
    return image;
}

static UIColor *textColorForButton(int type)
{
    switch (type)
    {
        case TGToolbarButtonTypeDone:
        case TGToolbarButtonTypeDoneBlack:
        {
            break;
        }
            
        default:
            break;
    }
    
    return [UIColor whiteColor];
}

static UIColor *shadowColorForButton(int type)
{
    switch (type)
    {
        case TGToolbarButtonTypeDone:
        case TGToolbarButtonTypeDoneBlack:
        {
            return UIColorRGBA(0x042651, 0.3f);
        }
        
        default:
            break;
    }
    
    return UIColorRGBA(0x0e284d, 0.4f);
}

@interface TGToolbarButton ()
{
    NSString *_text;
    UIImage *_image;
    UIImage *_imageLandscape;
    UIImage *_imageHighlighted;
}

@property (nonatomic) bool landscapeInitialized;

@property (nonatomic, strong) UIImage *customImageNormal;
@property (nonatomic, strong) UIImage *customImageNormalHighlighted;
@property (nonatomic, strong) UIImage *customImageLandscape;
@property (nonatomic, strong) UIImage *customImageLandscapeHighlighted;

@property (nonatomic, strong) UIColor *customTextColor;
@property (nonatomic, strong) UIColor *customShadowColor;

@end

@implementation TGToolbarButton

@synthesize type = _type;

@synthesize touchInset = _touchInset;

@synthesize minWidth = _minWidth;
@synthesize paddingLeft = _paddingLeft;
@synthesize paddingRight = _paddingRight;

@synthesize landscapeOffset = _landscapeOffset;

@synthesize buttonLabelView = _buttonLabelView;
@synthesize buttonImageView = _buttonImageView;

@synthesize landscapeInitialized = _landscapeInitialized;

@synthesize isLandscape = _isLandscape;

@synthesize customImageNormal = _customImageNormal;
@synthesize customImageNormalHighlighted = _customImageNormalHighlighted;
@synthesize customImageLandscape = _customImageLandscape;
@synthesize customImageLandscapeHighlighted = _customImageLandscapeHighlighted;

@synthesize customTextColor = _customTextColor;
@synthesize customShadowColor = _customShadowColor;

@synthesize backSemantics = _backSemantics;

- (id)initWithType:(TGToolbarButtonType)type
{
    self = [super init];
    if (self != nil)
    {
        _type = type;
        
        _touchInset = CGSizeMake(8, 8);
        
        _minWidth = 0;
        _paddingLeft = 7;
        _paddingRight = 7;
        
        self.exclusiveTouch = true;
        
        if (type == TGToolbarButtonTypeBack)
        {
            _paddingLeft = 15;
            _paddingRight = 9;
        }
        
        _isLandscape = false;
        _landscapeInitialized = false;
        
        _buttonLabelView = [[UILabel alloc] init];
        _buttonLabelView.font = [UIFont boldSystemFontOfSize:12];
        _buttonLabelView.textColor = textColorForButton(type);
        _buttonLabelView.shadowColor = shadowColorForButton(type);
        _buttonLabelView.shadowOffset = CGSizeMake(0, -1);
        _buttonLabelView.backgroundColor = [UIColor clearColor];
        [self addSubview:_buttonLabelView];
        
        _buttonImageView = [[UIImageView alloc] init];
        [self addSubview:_buttonImageView];
        self.text = @"";
        self.image = nil;
        
        _landscapeOffset = 0;
        
        self.adjustsImageWhenDisabled = false;
        self.adjustsImageWhenHighlighted = false;
        self.enabled = true;
        
        [self updateBackground];
    }
    return self;
}

- (id)initWithCustomImages:(UIImage *)imageNormal imageNormalHighlighted:(UIImage *)imageNormalHighlighted imageLandscape:(UIImage *)imageLandscape imageLandscapeHighlighted:(UIImage *)imageLandscapeHighlighted textColor:(UIColor *)textColor shadowColor:(UIColor *)shadowColor
{
    self = [super init];
    if (self != nil)
    {
        _type = TGToolbarButtonTypeCustom;
        
        _touchInset = CGSizeMake(8, 8);
        
        _minWidth = 0;
        _paddingLeft = 7;
        _paddingRight = 7;
        
        self.exclusiveTouch = true;
        
        _isLandscape = false;
        _landscapeInitialized = false;
        
        _customTextColor = textColor;
        _customShadowColor = shadowColor;
        
        _buttonLabelView = [[UILabel alloc] init];
        _buttonLabelView.font = [UIFont boldSystemFontOfSize:12];
        _buttonLabelView.textColor = _customTextColor != nil ? _customTextColor : textColorForButton(TGToolbarButtonTypeGeneric);
        _buttonLabelView.shadowColor = _customShadowColor != nil ? _customShadowColor : shadowColorForButton(TGToolbarButtonTypeGeneric);
        _buttonLabelView.shadowOffset = CGSizeMake(0, -1);
        _buttonLabelView.backgroundColor = [UIColor clearColor];
        [self addSubview:_buttonLabelView];
        
        _buttonImageView = [[UIImageView alloc] init];
        [self addSubview:_buttonImageView];
        self.text = @"";
        self.image = nil;
        
        _landscapeOffset = 0;
        
        self.adjustsImageWhenDisabled = false;
        self.adjustsImageWhenHighlighted = false;
        self.enabled = true;
        
        _customImageNormal = imageNormal;
        _customImageNormalHighlighted = imageNormalHighlighted;
        _customImageLandscape = imageLandscape;
        _customImageLandscapeHighlighted = imageLandscapeHighlighted;
        
        [self updateBackground];
    }
    return self;
}

- (bool)backSemantics
{
    return _type == TGToolbarButtonTypeBack || _backSemantics;
}

- (void)updateBackground
{
    UIImage *background = nil;
    UIImage *backgroundPressed = nil;
    if (_type == TGToolbarButtonTypeCustom)
    {
        background = _isLandscape ? _customImageLandscape : _customImageNormal;
        backgroundPressed = _isLandscape ? _customImageLandscapeHighlighted : _customImageNormalHighlighted;
    }
    else if (_type == TGToolbarButtonTypeGeneric)
    {
        background = _isLandscape ? backgroundGenericLandscape() : backgroundGeneric();
        backgroundPressed = _isLandscape ? backgroundGenericPressedLandscape() : backgroundGenericPressed();
    }
    else if (_type == TGToolbarButtonTypeBack)
    {
        background = _isLandscape ? backgroundBackLandscape() : backgroundBack();
        backgroundPressed = _isLandscape ? backgroundBackLandscapePressed() : backgroundBackPressed();
    }
    else if (_type == TGToolbarButtonTypeDone)
    {
        background = _isLandscape ? backgroundDoneLandscape() : backgroundDone();
        backgroundPressed = _isLandscape ? backgroundDoneLandscapePressed() : backgroundDonePressed();
    }
    else if (_type == TGToolbarButtonTypeDoneBlack)
    {
        background = _isLandscape ? backgroundDoneBlackLandscape() : backgroundDoneBlack();
        backgroundPressed = _isLandscape ? backgroundDoneBlackLandscapePressed() : backgroundDoneBlackPressed();
    }
    else if (_type == TGToolbarButtonTypeImage)
    {
        background = nil;
    }
    else if (_type == TGToolbarButtonTypeDelete)
    {
        background = _isLandscape ? backgroundDeleteLandscape() : backgroundDelete();
    }
    [self setBackgroundImage:background forState:UIControlStateNormal];
    [self setBackgroundImage:backgroundPressed forState:UIControlStateHighlighted];
    [self setBackgroundImage:backgroundPressed forState:UIControlStateHighlighted | UIControlStateSelected];
    [self setBackgroundImage:backgroundPressed forState:UIControlStateSelected];
}

- (NSString *)text
{
    return _text;
}

- (void)setText:(NSString *)text
{
    _text = text;
    
    if (text == nil)
    {
        _buttonLabelView.text = @"";
        _buttonLabelView.hidden = true;
    }
    else
    {
        _buttonLabelView.text = text;
        _buttonLabelView.hidden = false;
    }
}

- (UIImage *)image
{
    return _image;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    
    if (image == nil)
    {
        _buttonImageView.image = nil;
        _buttonImageView.hidden = true;
    }
    else
    {
        _buttonImageView.image = image;
        _buttonImageView.hidden = false;
    }
}

- (UIImage *)imageLandscape
{
    return _imageLandscape;
}

- (void)setImageLandscape:(UIImage *)imageLandscape
{
    _imageLandscape = imageLandscape;
}

- (UIImage *)imageHighlighted
{
    return _imageHighlighted;
}

- (void)setImageHighlighted:(UIImage *)image
{
    _imageHighlighted = image;
    
    if (image == nil)
    {
        _buttonImageView.highlightedImage = nil;
    }
    else
    {
        _buttonImageView.highlightedImage = image;
    }
}

- (bool)isLandscape
{
    return _isLandscape;
}

- (void)setIsLandscape:(bool)isLandscape
{
    if (isLandscape != _isLandscape || !_landscapeInitialized)
    {
        _landscapeInitialized = true;
        _isLandscape = isLandscape;
        
        if (_image != nil && _imageLandscape != nil)
        {
            _buttonImageView.image = isLandscape ? _imageLandscape : _image;
            [_buttonImageView sizeToFit];
        }
        
        [self layoutSubviews];
        [self updateBackground];
        
        CGRect frame = self.frame;
        
        if ([self.superview conformsToProtocol:@protocol(TGBarItemSemantics)])
        {
            float offset = [(id<TGBarItemSemantics>)self.superview barButtonsOffset];
            
            if (isLandscape)
                frame.origin.y = 2 + offset;
            else
                frame.origin.y = 0 + offset;
        }
        else
        {
            if (isLandscape)
                frame.origin.y = 3;
            else
                frame.origin.y = 7;
        }
        
        frame.size.height = isLandscape ? 25 : 30;
        self.frame = frame;
    }
}

- (void)sizeToFit
{
    float width = _paddingLeft + _paddingRight;
    float height = _isLandscape ? 25 : 30;
    
    if (!_buttonLabelView.hidden)
    {
        [_buttonLabelView sizeToFit];
        width += _buttonLabelView.frame.size.width;
    }
    
    if (_buttonImageView.image != nil)
    {
        CGRect frame = _buttonImageView.frame;
        frame.size = _buttonImageView.image.size;
        _buttonImageView.frame = frame;
        width += _buttonImageView.frame.size.width;
    }
    
    if (width < _minWidth)
        width = _minWidth;
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, width, height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    CGRect labelFrame = _buttonLabelView.frame;
    CGRect imageFrame = _buttonImageView.frame;
    
    float retinaPixel = TGIsRetina() ? 0.5f : 0.0f;
    
    int addY = _isLandscape ? 1 : 0;
    int imageAddY = 0;
    
    if (!_buttonLabelView.hidden)
    {
        [_buttonLabelView sizeToFit];
        labelFrame = _buttonLabelView.frame;
        labelFrame.origin.y = (float)((bounds.size.height - labelFrame.size.height) / 2) - (!_isLandscape ? 0 : 1.0f) - retinaPixel + addY - (_type != TGToolbarButtonTypeBack && !_isLandscape ? retinaPixel : 0.0f);
    }
    else
        labelFrame.size = CGSizeZero;
    
    if (!_buttonImageView.hidden && _buttonImageView.image != nil)
    {
        imageFrame = _buttonImageView.frame;
        imageFrame.origin.y = CGFloor(((bounds.size.height - imageFrame.size.height) / 2) + imageAddY);
    }
    else
        imageFrame.size = CGSizeZero;
    
    int spacing = 4;
    if (labelFrame.size.width == 0 || imageFrame.size.width == 0)
        spacing = 0;
    
    labelFrame.origin.x = ((bounds.size.width - _paddingLeft - _paddingRight - labelFrame.size.width - spacing - imageFrame.size.width) / 2 + _paddingLeft);
    imageFrame.origin.x = (labelFrame.origin.x + labelFrame.size.width + spacing);
    
    if (TGIsRetina())
    {
        labelFrame.origin.x = ((int)(labelFrame.origin.x * 2.0f)) / 2;
        imageFrame.origin.x = ((int)(imageFrame.origin.x * 2.0f)) / 2;
    }
    else
    {
        labelFrame.origin.x = CGFloor(labelFrame.origin.x);
        imageFrame.origin.x = CGFloor(imageFrame.origin.x);
    }
    
    if (_type == TGToolbarButtonTypeBack && _isLandscape)
        labelFrame.origin.x -= 1;

    _buttonLabelView.frame = labelFrame;
    _buttonImageView.frame = imageFrame;
}

- (void)setEnabled:(BOOL)enabled
{
    _buttonLabelView.alpha = !enabled ? 0.6f : 1.0f;
    
    [super setEnabled:enabled];
}

- (void)setHighlighted:(BOOL)highlighted
{
    //_buttonLabelView.shadowColor = shadowColorForButton(_type, highlighted || self.selected);
    
    [super setHighlighted:highlighted];
}

- (void)setSelected:(BOOL)selected
{
    //_buttonLabelView.shadowColor = shadowColorForButton(_type, selected || self.highlighted);
    
    [super setSelected:selected];
}

- (CGRect)backgroundRectForBounds:(CGRect)bounds
{
    CGRect backgroundFrame = CGRectOffset([super backgroundRectForBounds:bounds], 0, (TGIsRetina() && _isLandscape) ? 0.5f : 0.0f);
    
    if (_type == TGToolbarButtonTypeBack)
    {
        backgroundFrame.origin.x -= 1;
        backgroundFrame.size.width += 1;
        
        if (!_isLandscape && TGIsRetina())
        {
            backgroundFrame.origin.y += 0.5f;
        }
    }
    
    return backgroundFrame;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    if (self.alpha < FLT_EPSILON || self.hidden)
        return nil;
    
    if (CGRectContainsPoint(CGRectInset(self.bounds, -_touchInset.width, -_touchInset.height), point))
        return self;
    return nil;
}

@end
