#import "TGChannelIntroController.h"

#import <LegacyComponents/LegacyComponents.h>
#import <LegacyComponents/TGModernButton.h>

@implementation TGChannelIntroControllerTheme

- (instancetype)initWithBackgroundColor:(UIColor *)backgroundColor primaryColor:(UIColor *)primaryColor secondaryColor:(UIColor *)secondaryColor accentColor:(UIColor *)accentColor backArrowImage:(UIImage *)backArrowImage introImage:(UIImage *)introImage {
    self = [super init];
    if (self != nil) {
        _backgroundColor = backgroundColor;
        _primaryColor = primaryColor;
        _secondaryColor = secondaryColor;
        _accentColor = accentColor;
        _backArrowImage = backArrowImage;
        _introImage = introImage;
    }
    return self;
}

@end

@interface TGChannelIntroController ()
{
    TGModernButton *_backButton;
    UIImageView *_phoneImageView;
    UILabel *_titleLabel;
    UILabel *_descriptionLabel;
    TGModernButton *_createButton;
    TGChannelIntroControllerTheme *_theme;
    NSString *(^_getLocalizedString)(NSString *);
    void (^_dismiss)(void);
    void (^_completion)(void);
}
@end

@implementation TGChannelIntroController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context getLocalizedString:(NSString *(^)(NSString *))getLocalizedString theme:(TGChannelIntroControllerTheme *)theme dismiss:(void (^)(void))dismiss completion:(void (^)(void))completion {
    self = [super initWithContext:context];
    if (self != nil) {
        _getLocalizedString = [getLocalizedString copy];
        _theme = theme;
        _dismiss = [dismiss copy];
        _completion = [completion copy];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = _theme.backgroundColor;
    
    UIImage *image = _theme.backArrowImage;
    UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
    CGContextSetFillColorWithColor(context, _theme.accentColor.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
    
    UIImage *arrowImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    _backButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _backButton.exclusiveTouch = true;
    _backButton.titleLabel.font = TGSystemFontOfSize(17);
    [_backButton setTitle:_getLocalizedString(@"Common.Back") forState:UIControlStateNormal];
    [_backButton setTitleColor:_theme.accentColor];
    [_backButton addTarget:self action:@selector(backButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_backButton];
    
    UIImageView *arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(-19, 5.5f, 13, 22)];
    arrowView.image = arrowImage;
    [_backButton addSubview:arrowView];
    
    _phoneImageView = [[UIImageView alloc] initWithImage:_theme.introImage];
    _phoneImageView.frame = CGRectMake(0, 0, 154, 220);
    [self.view addSubview:_phoneImageView];
    
    _titleLabel = [[UILabel alloc] init];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.font = TGSystemFontOfSize(21);
    _titleLabel.textColor = _theme.primaryColor;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.text = _getLocalizedString(@"ChannelIntro.Title");
    [self.view addSubview:_titleLabel];
    
    _descriptionLabel = [[UILabel alloc] init];
    _descriptionLabel.backgroundColor = [UIColor clearColor];
    _descriptionLabel.numberOfLines = 0;
    _descriptionLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_descriptionLabel];
    
    NSString *description = _getLocalizedString(@"ChannelIntro.Text");
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:description];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 2;
    style.alignment = NSTextAlignmentCenter;
    [attrString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, description.length)];
    [attrString addAttribute:NSForegroundColorAttributeName value:_theme.secondaryColor range:NSMakeRange(0, description.length)];
    [attrString addAttribute:NSFontAttributeName value:TGSystemFontOfSize(16) range:NSMakeRange(0, description.length)];
    _descriptionLabel.attributedText = attrString;
    
    _createButton = [[TGModernButton alloc] init];
    _createButton.exclusiveTouch = true;
    _createButton.backgroundColor = [UIColor clearColor];
    _createButton.titleLabel.font = TGSystemFontOfSize(21);
    [_createButton setTitleColor:_theme.accentColor];
    [_createButton setTitle:_getLocalizedString(@"ChannelIntro.CreateChannel") forState:UIControlStateNormal];
    [_createButton addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_createButton];
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (void)backButtonPressed
{
    if (_dismiss != nil)
        _dismiss();
    else
        [self.navigationController popViewControllerAnimated:true];
}

- (void)buttonPressed
{
    _completion();
}

- (void)viewWillLayoutSubviews
{
    CGRect bounds = self.context.fullscreenBounds;
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (bounds.size.width > bounds.size.height) {
        orientation = UIInterfaceOrientationLandscapeLeft;
    }
    
    UIEdgeInsets safeAreaInset = [self calculatedSafeAreaInset];
    int iosVersion = [[[UIDevice currentDevice] systemVersion] intValue];
    if (UIEdgeInsetsEqualToEdgeInsets(safeAreaInset, UIEdgeInsetsZero) && (iosVersion < 11 || TGIsPad() || UIInterfaceOrientationIsPortrait(orientation)))
        safeAreaInset.top = 20.0f;
    
    [_backButton sizeToFit];
    _backButton.frame = CGRectMake(27 + safeAreaInset.left, 5.0f + TGScreenPixel + safeAreaInset.top, ceil(_backButton.frame.size.width), ceil(_backButton.frame.size.height));
    
    [_titleLabel sizeToFit];
    [_descriptionLabel sizeToFit];
    [_createButton sizeToFit];
    
    int screenSize = (int)TGScreenSize().height;
    CGFloat titleY = 0;
    CGFloat imageY = 0;
    CGFloat descY = 0;
    CGFloat buttonY = 0;
        
    if (UIInterfaceOrientationIsPortrait(orientation))
    {
        switch (screenSize)
        {
            case 812:
            case 896:
                titleY = 445 + 44;
                imageY = 141 + 44;
                descY = 490 + 44;
                buttonY = 610 + 44;
                break;
                
            case 736:
                titleY = 445;
                imageY = 141;
                descY = 490;
                buttonY = 610;
                break;
                
            case 667:
                titleY = 407;
                imageY = 120;
                descY = 448;
                buttonY = 558;
                break;
                
            case 568:
                titleY = 354;
                imageY = 87;
                descY = 397;
                buttonY = 496;
                break;
                
            default:
                titleY = 307;
                imageY = 60;
                descY = 344;
                buttonY = 424;
                break;
        }
       
        _phoneImageView.frame = CGRectMake((self.view.frame.size.width - _phoneImageView.frame.size.width) / 2, imageY, _phoneImageView.frame.size.width, _phoneImageView.frame.size.height);
        _titleLabel.frame = CGRectMake((self.view.frame.size.width - _titleLabel.frame.size.width) / 2, titleY, ceil(_titleLabel.frame.size.width), ceil(_titleLabel.frame.size.height));
        _descriptionLabel.frame = CGRectMake((self.view.frame.size.width - _descriptionLabel.frame.size.width) / 2, descY, ceil(_descriptionLabel.frame.size.width), ceil(_descriptionLabel.frame.size.height));

        _createButton.frame = CGRectMake((self.view.frame.size.width - _createButton.frame.size.width) / 2, buttonY, ceil(_createButton.frame.size.width), ceil(_createButton.frame.size.height));
    }
    else
    {
        CGFloat leftX = 0;
        CGFloat rightX = 0;
        
        switch (screenSize)
        {
            case 812:
                leftX = 190 + 44;
                rightX = 448 + 44;
                titleY = 103;
                descY = 148;
                buttonY = 237;
                break;
                
            case 736:
                leftX = 209;
                rightX = 504;
                titleY = 115;
                descY = 156;
                buttonY = 278;
                break;
                
            case 667:
                leftX = 190;
                rightX = 448;
                titleY = 103;
                descY = 148;
                buttonY = 237;
                break;
                
            case 568:
                leftX = 164;
                rightX = 388;
                titleY = 78;
                descY = 121;
                buttonY = 217;
                break;
                
            default:
                leftX = 125;
                rightX = 328;
                titleY = 78;
                descY = 121;
                buttonY = 219;
                break;
        }
        
        _phoneImageView.frame = CGRectMake(leftX - _phoneImageView.frame.size.width / 2, (self.view.frame.size.height - _phoneImageView.frame.size.height) / 2, _phoneImageView.frame.size.width, _phoneImageView.frame.size.height);

        _titleLabel.frame = CGRectMake(rightX - _titleLabel.frame.size.width / 2, titleY, ceil(_titleLabel.frame.size.width), ceil(_titleLabel.frame.size.height));
        
        _descriptionLabel.frame = CGRectMake(rightX - _descriptionLabel.frame.size.width / 2, descY, ceil(_descriptionLabel.frame.size.width), ceil(_descriptionLabel.frame.size.height));
        
        _createButton.frame = CGRectMake(rightX - _createButton.frame.size.width / 2, buttonY, ceil(_createButton.frame.size.width), ceil(_createButton.frame.size.height));
    }
}

@end
