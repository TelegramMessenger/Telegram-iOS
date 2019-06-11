#import "TGPhotoEditorHUDView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"

#import "TGPhotoEditorInterfaceAssets.h"

@interface TGPhotoEditorHUDView ()
{
    UIImageView *_backgroundView;
    UILabel *_label;
}
@end

@implementation TGPhotoEditorHUDView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        
        static UIImage *background = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(21, 21), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [TGPhotoEditorInterfaceAssets panelBackgroundColor].CGColor);
            
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 21, 21) cornerRadius:6];
            [path fill];
            
            background = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
            UIGraphicsEndImageContext();
        });
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _backgroundView.alpha = 0.0f;
        _backgroundView.image = background;
        [self addSubview:_backgroundView];
        
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = TGSystemFontOfSize(14);
        _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = [UIColor whiteColor];
        [_backgroundView addSubview:_label];
    }
    return self;
}

- (void)setText:(NSString *)text
{
    if (text.length == 0)
    {
        [self setHidden:true animated:true];
        return;
    }
    
    _label.text = text;
    [_label sizeToFit];
    
    [self setNeedsLayout];
    
    [self setHidden:false animated:true];
}

- (void)setAttributedText:(NSAttributedString *)text
{
    if (text.length == 0)
    {
        [self setHidden:true animated:true];
        return;
    }
    
    _label.attributedText = text;
    [_label sizeToFit];
    
    [self setNeedsLayout];
    
    [self setHidden:false animated:true];
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.1f delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _backgroundView.alpha = hidden ? 0.0f : 1.0f;
        } completion:nil];
    }
    else
    {
        _backgroundView.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)layoutSubviews
{
    CGFloat padding = 8.0f;
    
    _label.frame = CGRectMake(padding, 6.0f, CGCeil(_label.frame.size.width), CGCeil(_label.frame.size.height));
    
    CGFloat width = _label.frame.size.width + 2.0f * padding;
    _backgroundView.frame = CGRectMake((self.frame.size.width - width) / 2, 15, width, 30);
}

@end
