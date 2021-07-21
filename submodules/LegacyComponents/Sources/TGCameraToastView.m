#import "TGCameraToastView.h"
#import "TGCameraInterfaceAssets.h"
#import "TGFont.h"

@implementation TGCameraToastView
{
    UIView *_backgroundView;
    UILabel *_label;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _backgroundView = [[UIView alloc] init];
        _backgroundView.alpha = 0.0f;
        _backgroundView.clipsToBounds = true;
        _backgroundView.layer.cornerRadius = 5.0f;
        _backgroundView.backgroundColor = [TGCameraInterfaceAssets transparentPanelBackgroundColor];
        [self addSubview:_backgroundView];
        
        _label = [[UILabel alloc] init];
        _label.alpha = 0.0f;
        _label.textColor = [UIColor whiteColor];
        _label.font = [TGFont systemFontOfSize:17.0f];
        [self addSubview:_label];
    }
    return self;
}

- (void)setText:(NSString *)text animated:(bool)animated
{
    if (text.length == 0)
    {
        if (animated) {
            [UIView animateWithDuration:0.2 animations:^{
                _backgroundView.alpha = 0.0f;
                _label.alpha = 0.0f;
            }];
        } else {
            _backgroundView.alpha = 0.0f;
            _label.alpha = 0.0f;
        }
        return;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            _backgroundView.alpha = 1.0f;
            _label.alpha = 1.0f;
        }];
    } else {
        _backgroundView.alpha = 1.0f;
        _label.alpha = 1.0f;
    }
    
    _label.text = text;
    [_label sizeToFit];
    
    CGFloat inset = 8.0f;
    CGFloat backgroundWidth = _label.frame.size.width + inset * 2.0;
    _backgroundView.frame = CGRectMake(floor((self.frame.size.width - backgroundWidth) / 2.0), 0.0, backgroundWidth, 32.0);
    
    _label.frame = CGRectMake(floor((self.frame.size.width - _label.frame.size.width) / 2.0), floor((32 - _label.frame.size.height) / 2.0), _label.frame.size.width, _label.frame.size.height);
    
    [self setNeedsLayout];
}

@end
