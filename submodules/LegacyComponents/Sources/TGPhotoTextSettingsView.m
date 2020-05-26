#import "TGPhotoTextSettingsView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGPhotoEditorSliderView.h"

#import <LegacyComponents/TGModernButton.h>
#import "TGPhotoTextEntityView.h"

const CGFloat TGPhotoTextSettingsViewMargin = 19.0f;
const CGFloat TGPhotoTextSettingsItemHeight = 44.0f;

@interface TGPhotoTextSettingsView ()
{
    NSArray *_fonts;
    
    UIInterfaceOrientation _interfaceOrientation;
    
    UIImageView *_backgroundView;
    
    NSArray *_fontViews;
    NSArray *_fontSeparatorViews;
    UIImageView *_selectedCheckView;
}
@end

@implementation TGPhotoTextSettingsView

@synthesize interfaceOrientation = _interfaceOrientation;

- (instancetype)initWithFonts:(NSArray *)fonts selectedFont:(TGPhotoPaintFont *)__unused selectedFont selectedStyle:(TGPhotoPaintTextEntityStyle)selectedStyle
{
    self = [super initWithFrame:CGRectZero];
    if (self)
    {
        _fonts = fonts;
        
        _interfaceOrientation = UIInterfaceOrientationPortrait;
        
        _backgroundView = [[UIImageView alloc] init];
        _backgroundView.alpha = 0.98f;
        [self addSubview:_backgroundView];
        
        NSMutableArray *fontViews = [[NSMutableArray alloc] init];
        NSMutableArray *separatorViews = [[NSMutableArray alloc] init];
        
        UIFont *font = [UIFont boldSystemFontOfSize:18];
        
        TGModernButton *outlineButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, TGPhotoTextSettingsViewMargin, 0, 0)];
        outlineButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        outlineButton.titleLabel.font = font;
        outlineButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 44.0f, 0.0f, 0.0f);
        outlineButton.tag = TGPhotoPaintTextEntityStyleBorder;
        [outlineButton setTitle:@"" forState:UIControlStateNormal];
        [outlineButton setTitleColor:[UIColor clearColor]];
        [outlineButton addTarget:self action:@selector(styleValueChanged:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:outlineButton];
        [fontViews addObject:outlineButton];
        
        TGPhotoTextView *textView = [[TGPhotoTextView alloc] init];
        textView.backgroundColor = [UIColor clearColor];
        textView.textColor = [UIColor whiteColor];
        textView.strokeWidth = 3.0f;
        textView.strokeColor = [UIColor blackColor];
        textView.strokeOffset = CGPointMake(0.0f, 0.5f);
        textView.font = font;
        textView.text = TGLocalized(@"Paint.Outlined");
        [textView sizeToFit];
        textView.frame = CGRectMake(39.0f, ceil((TGPhotoTextSettingsItemHeight - textView.frame.size.height) / 2.0f) - 1.0f, ceil(textView.frame.size.width), ceil(textView.frame.size.height + 0.5f));
        [outlineButton addSubview:textView];
        
        UIView *separatorView = [[UIView alloc] init];
        separatorView.backgroundColor = UIColorRGB(0xd6d6da);
        [self addSubview:separatorView];
        [separatorViews addObject:separatorView];
        
        TGModernButton *regularButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, TGPhotoTextSettingsViewMargin +  TGPhotoTextSettingsItemHeight, 0, 0)];
        regularButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        regularButton.titleLabel.font = font;
        regularButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 44.0f, 0.0f, 0.0f);
        regularButton.tag = TGPhotoPaintTextEntityStyleClassic;
        [regularButton setTitle:TGLocalized(@"Paint.Regular") forState:UIControlStateNormal];
        [regularButton setTitleColor:[UIColor blackColor]];
        [regularButton addTarget:self action:@selector(styleValueChanged:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:regularButton];
        [fontViews addObject:regularButton];
        
        separatorView = [[UIView alloc] init];
        separatorView.backgroundColor = UIColorRGB(0xd6d6da);
        [self addSubview:separatorView];
        [separatorViews addObject:separatorView];
        
        TGModernButton *frameButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, TGPhotoTextSettingsViewMargin +  TGPhotoTextSettingsItemHeight + TGPhotoTextSettingsItemHeight, 0, 0)];
        frameButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        frameButton.titleLabel.font = font;
        frameButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 44.0f, 0.0f, 0.0f);
        frameButton.tag = TGPhotoPaintTextEntityStyleFrame;
        [frameButton setTitle:@"" forState:UIControlStateNormal];
        [frameButton setTitleColor:[UIColor blackColor]];
        [frameButton addTarget:self action:@selector(styleValueChanged:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:frameButton];
        [fontViews addObject:frameButton];
        
        textView = [[TGPhotoTextView alloc] init];
        textView.backgroundColor = [UIColor clearColor];
        textView.textColor = [UIColor whiteColor];
        textView.frameColor = [UIColor blackColor];
        textView.font = font;
        textView.text = TGLocalized(@"Paint.Framed");
        [textView sizeToFit];
        textView.frame = CGRectMake(39.0f, ceil((TGPhotoTextSettingsItemHeight - textView.frame.size.height) / 2.0f) - 1.0f, ceil(textView.frame.size.width), ceil(textView.frame.size.height + 0.5f));
        [frameButton addSubview:textView];
        
        _fontViews = fontViews;
        _fontSeparatorViews = separatorViews;
        
        _selectedCheckView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"PaintCheck")];
        _selectedCheckView.frame = CGRectMake(15.0f, 16.0f, _selectedCheckView.frame.size.width, _selectedCheckView.frame.size.height);
        
        [self setStyle:selectedStyle];
    }
    return self;
}

- (void)fontButtonPressed:(TGModernButton *)sender
{
    [sender addSubview:_selectedCheckView];
    
    if (self.fontChanged != nil)
        self.fontChanged(_fonts[sender.tag]);
}

- (void)styleValueChanged:(TGModernButton *)sender
{
    if (self.styleChanged != nil)
        self.styleChanged((TGPhotoPaintTextEntityStyle)sender.tag);
}

- (void)present
{
    self.alpha = 0.0f;
    
    self.layer.rasterizationScale = TGScreenScaling();
    self.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.2 animations:^
    {
        self.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        self.layer.shouldRasterize = false;
    }];
}

- (void)dismissWithCompletion:(void (^)(void))completion
{
    self.layer.rasterizationScale = TGScreenScaling();
    self.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.15 animations:^
    {
        self.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
}

- (TGPhotoPaintTextEntityStyle)style
{
    return (TGPhotoPaintTextEntityStyle)_selectedCheckView.superview.tag;
}

- (void)setStyle:(TGPhotoPaintTextEntityStyle)style
{
    [_fontViews[style] addSubview:_selectedCheckView];
}

- (NSString *)font
{
    return _fonts[_selectedCheckView.superview.tag];
}

- (void)setFont:(TGPhotoPaintFont *)__unused font
{
    
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    return CGSizeMake(256, _fontViews.count * TGPhotoTextSettingsItemHeight + TGPhotoTextSettingsViewMargin * 2);
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _interfaceOrientation = interfaceOrientation;
    
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _backgroundView.image = [TGPhotoPaintSettingsView landscapeLeftBackgroundImage];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _backgroundView.image = [TGPhotoPaintSettingsView landscapeRightBackgroundImage];
        }
            break;
            
        default:
        {
            _backgroundView.image = [TGPhotoPaintSettingsView portraitBackgroundImage];
        }
            break;
    }
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _backgroundView.image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupLandscapeLeftBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
            _backgroundView.frame = CGRectMake(TGPhotoTextSettingsViewMargin - 13.0f, TGPhotoTextSettingsViewMargin, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2 + 13.0f, self.frame.size.height - TGPhotoTextSettingsViewMargin * 2);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _backgroundView.image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupLandscapeRightBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
            _backgroundView.frame = CGRectMake(TGPhotoTextSettingsViewMargin, TGPhotoTextSettingsViewMargin, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2 + 13.0f, self.frame.size.height - TGPhotoTextSettingsViewMargin * 2);
        }
            break;
            
        default:
        {
            _backgroundView.image = [TGTintedImage(TGComponentsImageNamed(@"PaintPopupPortraitBackground"), UIColorRGB(0xf7f7f7)) resizableImageWithCapInsets:UIEdgeInsetsMake(32.0f, 32.0f, 32.0f, 32.0f)];
            _backgroundView.frame = CGRectMake(TGPhotoTextSettingsViewMargin, TGPhotoTextSettingsViewMargin, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2, self.frame.size.height - TGPhotoTextSettingsViewMargin * 2 + 13.0f);
        }
            break;
    }

    CGFloat thickness = TGScreenPixel;
    
    [_fontViews enumerateObjectsUsingBlock:^(TGModernButton *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(TGPhotoTextSettingsViewMargin, TGPhotoTextSettingsViewMargin + TGPhotoTextSettingsItemHeight * index, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2, TGPhotoTextSettingsItemHeight);

    }];

    [_fontSeparatorViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(TGPhotoTextSettingsViewMargin + 44.0f, TGPhotoTextSettingsViewMargin + TGPhotoTextSettingsItemHeight * (index + 1), self.frame.size.width - TGPhotoTextSettingsViewMargin * 2 - 44.0f, thickness);
    }];
}

@end
