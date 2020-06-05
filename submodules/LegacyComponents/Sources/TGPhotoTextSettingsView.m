#import "TGPhotoTextSettingsView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGPhotoEditorSliderView.h"

#import <LegacyComponents/TGModernButton.h>
#import "TGPhotoTextEntityView.h"

const CGFloat TGPhotoTextSettingsViewMargin = 10.0f;
const CGFloat TGPhotoTextSettingsItemHeight = 44.0f;

@interface TGPhotoTextSettingsView ()
{
    NSArray *_fonts;
    
    UIInterfaceOrientation _interfaceOrientation;
    
    UIView *_wrapperView;
    UIView *_contentView;
    UIVisualEffectView *_effectView;
    
    NSArray *_fontViews;
    NSArray *_fontIconViews;
    NSArray *_fontSeparatorViews;
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
        
        _wrapperView = [[UIView alloc] init];
        _wrapperView.clipsToBounds = true;
        _wrapperView.layer.cornerRadius = 12.0;
        [self addSubview:_wrapperView];
        
        _effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        _effectView.alpha = 0.0f;
        _effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_wrapperView addSubview:_effectView];
        
        _contentView = [[UIView alloc] init];
        _contentView.alpha = 0.0f;
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_wrapperView addSubview:_contentView];
        
        NSMutableArray *fontViews = [[NSMutableArray alloc] init];
        NSMutableArray *fontIconViews = [[NSMutableArray alloc] init];
        NSMutableArray *separatorViews = [[NSMutableArray alloc] init];
        
        UIFont *font = [UIFont systemFontOfSize:17];
        
        TGModernButton *frameButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        frameButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        frameButton.titleLabel.font = font;
        frameButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 16.0f, 0.0f, 0.0f);
        frameButton.tag = TGPhotoPaintTextEntityStyleFramed;
        [frameButton setTitle:TGLocalized(@"Paint.Framed") forState:UIControlStateNormal];
        [frameButton setTitleColor:[UIColor whiteColor]];
        [frameButton addTarget:self action:@selector(styleValueChanged:) forControlEvents:UIControlEventTouchUpInside];
        [_contentView addSubview:frameButton];
        [fontViews addObject:frameButton];
        
        UIImageView *iconView = [[UIImageView alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"Editor/TextFramed"], [UIColor whiteColor])];
        [frameButton addSubview:iconView];
        [fontIconViews addObject:iconView];
        
        TGModernButton *outlineButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        outlineButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        outlineButton.titleLabel.font = font;
        outlineButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 16.0f, 0.0f, 0.0f);
        outlineButton.tag = TGPhotoPaintTextEntityStyleOutlined;
        [outlineButton setTitle:TGLocalized(@"Paint.Outlined") forState:UIControlStateNormal];
        [outlineButton setTitleColor:[UIColor whiteColor]];
        [outlineButton addTarget:self action:@selector(styleValueChanged:) forControlEvents:UIControlEventTouchUpInside];
        [_contentView addSubview:outlineButton];
        [fontViews addObject:outlineButton];
        
        iconView = [[UIImageView alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"Editor/TextOutlined"], [UIColor whiteColor])];
        [outlineButton addSubview:iconView];
        [fontIconViews addObject:iconView];
        
        UIView *separatorView = [[UIView alloc] init];
        separatorView.backgroundColor = UIColorRGBA(0xffffff, 0.2);
        [_contentView addSubview:separatorView];
        [separatorViews addObject:separatorView];
        
        TGModernButton *regularButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        regularButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        regularButton.titleLabel.font = font;
        regularButton.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 16.0f, 0.0f, 0.0f);
        regularButton.tag = TGPhotoPaintTextEntityStyleRegular;
        [regularButton setTitle:TGLocalized(@"Paint.Regular") forState:UIControlStateNormal];
        [regularButton setTitleColor:[UIColor whiteColor]];
        [regularButton addTarget:self action:@selector(styleValueChanged:) forControlEvents:UIControlEventTouchUpInside];
        [_contentView addSubview:regularButton];
        [fontViews addObject:regularButton];
        
        iconView = [[UIImageView alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"Editor/TextRegular"], [UIColor whiteColor])];
        [regularButton addSubview:iconView];
        [fontIconViews addObject:iconView];
        
        separatorView = [[UIView alloc] init];
        separatorView.backgroundColor = UIColorRGBA(0xffffff, 0.2);
        [_contentView addSubview:separatorView];
        [separatorViews addObject:separatorView];
        
        _fontViews = fontViews;
        _fontIconViews = fontIconViews;
        _fontSeparatorViews = separatorViews;
    }
    return self;
}

- (void)fontButtonPressed:(TGModernButton *)sender
{
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
    [UIView animateWithDuration:0.25 animations:^
    {
        _effectView.alpha = 1.0f;
        _contentView.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        
    }];
}

- (void)dismissWithCompletion:(void (^)(void))completion
{
    [UIView animateWithDuration:0.2 animations:^
    {
        _effectView.alpha = 0.0f;
        _contentView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    return CGSizeMake(220, _fontViews.count * TGPhotoTextSettingsItemHeight + TGPhotoTextSettingsViewMargin * 2);
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _interfaceOrientation = interfaceOrientation;
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    CGFloat arrowSize = 0.0f;
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _wrapperView.frame = CGRectMake(TGPhotoTextSettingsViewMargin - arrowSize, TGPhotoTextSettingsViewMargin, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2 + arrowSize, self.frame.size.height - TGPhotoTextSettingsViewMargin * 2);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _wrapperView.frame = CGRectMake(TGPhotoTextSettingsViewMargin, TGPhotoTextSettingsViewMargin, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2 + arrowSize, self.frame.size.height - TGPhotoTextSettingsViewMargin * 2);
        }
            break;
            
        default:
        {
            _wrapperView.frame = CGRectMake(TGPhotoTextSettingsViewMargin, TGPhotoTextSettingsViewMargin, self.frame.size.width - TGPhotoTextSettingsViewMargin * 2, self.frame.size.height - TGPhotoTextSettingsViewMargin * 2 + arrowSize);
        }
            break;
    }

    CGFloat thickness = TGScreenPixel;
    
    [_fontViews enumerateObjectsUsingBlock:^(TGModernButton *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(0.0, TGPhotoTextSettingsItemHeight * index, _contentView.frame.size.width, TGPhotoTextSettingsItemHeight);
    }];
    
    [_fontIconViews enumerateObjectsUsingBlock:^(UIImageView *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(_contentView.frame.size.width - 42.0f, (TGPhotoTextSettingsItemHeight - view.frame.size.height) / 2.0, view.frame.size.width, view.frame.size.height);
    }];

    [_fontSeparatorViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(0.0, TGPhotoTextSettingsItemHeight * (index + 1), _contentView.frame.size.width, thickness);
    }];
}

@end
