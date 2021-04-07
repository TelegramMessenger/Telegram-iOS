#import "TGPhotoBrushSettingsView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGPhotoEditorSliderView.h"

#import <LegacyComponents/TGModernButton.h>

#import "TGPaintBrush.h"
#import "TGPaintBrushPreview.h"

const CGFloat TGPhotoBrushSettingsViewMargin = 10.0f;
const CGFloat TGPhotoBrushSettingsItemHeight = 44.0f;

@interface TGPhotoBrushSettingsView ()
{
    NSArray *_brushes;
    
    UIView *_wrapperView;
    UIView *_contentView;
    UIVisualEffectView *_effectView;
    
    NSArray *_brushViews;
    NSArray *_brushIconViews;
    NSArray *_brushSeparatorViews;
}
@end

@implementation TGPhotoBrushSettingsView

@synthesize interfaceOrientation = _interfaceOrientation;

- (instancetype)initWithBrushes:(NSArray *)brushes preview:(TGPaintBrushPreview *)preview
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _brushes = brushes;
        
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
        
        UIFont *font = [UIFont systemFontOfSize:17];
        
        NSMutableArray *brushViews = [[NSMutableArray alloc] init];
        NSMutableArray *brushIconViews = [[NSMutableArray alloc] init];
        NSMutableArray *separatorViews = [[NSMutableArray alloc] init];
        [brushes enumerateObjectsUsingBlock:^(__unused TGPaintBrush *brush, NSUInteger index, __unused BOOL *stop)
        {
            NSString *title;
            UIImage *icon;
            switch (index) {
                case 0:
                    title = TGLocalized(@"Paint.Pen");
                    icon = [UIImage imageNamed:@"Editor/BrushPen"];
                    break;
                case 1:
                    title = TGLocalized(@"Paint.Marker");
                    icon = [UIImage imageNamed:@"Editor/BrushMarker"];
                    break;
                case 2:
                    title = TGLocalized(@"Paint.Neon");
                    icon = [UIImage imageNamed:@"Editor/BrushNeon"];
                    break;
                case 3:
                    title = TGLocalized(@"Paint.Arrow");
                    icon = [UIImage imageNamed:@"Editor/BrushArrow"];
                    break;
                default:
                    break;
            }
            
            TGModernButton *button = [[TGModernButton alloc] initWithFrame:CGRectMake(0, index * TGPhotoBrushSettingsItemHeight, 0, 0)];
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            button.titleLabel.font = font;
            button.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 16.0f, 0.0f, 0.0f);
            button.tag = index;
            [button setTitle:title forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor]];
            [button addTarget:self action:@selector(brushButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            [_contentView addSubview:button];
            [brushViews addObject:button];
            
            UIImageView *iconView = [[UIImageView alloc] initWithImage:TGTintedImage(icon, [UIColor whiteColor])];
            [button addSubview:iconView];
            [brushIconViews addObject:iconView];
            
            if (index != brushes.count - 1)
            {
                UIView *separatorView = [[UIView alloc] init];
                separatorView.backgroundColor = UIColorRGBA(0xffffff, 0.2);
                [_contentView addSubview:separatorView];
                
                [separatorViews addObject:separatorView];
            }
        }];
        
        _brushViews = brushViews;
        _brushIconViews = brushIconViews;
        _brushSeparatorViews = separatorViews;
    }
    return self;
}

- (void)brushButtonPressed:(TGModernButton *)sender
{
    if (self.brushChanged != nil)
        self.brushChanged(_brushes[sender.tag]);
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
    return CGSizeMake(220, _brushViews.count * TGPhotoBrushSettingsItemHeight + TGPhotoBrushSettingsViewMargin * 2);
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
            _wrapperView.frame = CGRectMake(TGPhotoBrushSettingsViewMargin - arrowSize, TGPhotoBrushSettingsViewMargin, self.frame.size.width - TGPhotoBrushSettingsViewMargin * 2 + arrowSize, self.frame.size.height - TGPhotoBrushSettingsViewMargin * 2);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _wrapperView.frame = CGRectMake(TGPhotoBrushSettingsViewMargin, TGPhotoBrushSettingsViewMargin, self.frame.size.width - TGPhotoBrushSettingsViewMargin * 2 + arrowSize, self.frame.size.height - TGPhotoBrushSettingsViewMargin * 2);
        }
            break;
            
        default:
        {
            _wrapperView.frame = CGRectMake(TGPhotoBrushSettingsViewMargin, TGPhotoBrushSettingsViewMargin, self.frame.size.width - TGPhotoBrushSettingsViewMargin * 2, self.frame.size.height - TGPhotoBrushSettingsViewMargin * 2 + arrowSize);
        }
            break;
    }
    
    CGFloat thickness = TGScreenPixel;
    
    [_brushViews enumerateObjectsUsingBlock:^(TGModernButton *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(0.0f, TGPhotoBrushSettingsItemHeight * index, _contentView.frame.size.width, TGPhotoBrushSettingsItemHeight);
    }];
    
    [_brushIconViews enumerateObjectsUsingBlock:^(UIImageView *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(_contentView.frame.size.width - 42.0f, (TGPhotoBrushSettingsItemHeight - view.frame.size.height) / 2.0, view.frame.size.width, view.frame.size.height);
    }];
    
    [_brushSeparatorViews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, __unused BOOL *stop)
    {
        view.frame = CGRectMake(0.0f, TGPhotoBrushSettingsItemHeight * (index + 1), _contentView.frame.size.width, thickness);
    }];
}

@end
