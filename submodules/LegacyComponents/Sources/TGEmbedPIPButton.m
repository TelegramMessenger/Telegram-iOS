#import "TGEmbedPIPButton.h"

const CGSize TGEmbedPIPButtonSize = { 42.0f, 42.0f };

@interface TGEmbedPIPButton ()
{
    UIVisualEffectView *_backView;
    UIView *_highlightView;
    UIImageView *_iconView;
    
    bool _animateHighlight;
}
@end

@implementation TGEmbedPIPButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        self.exclusiveTouch = true;
        
        UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _backView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        _backView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backView.frame = self.bounds;
        _backView.userInteractionEnabled = false;
        [self addSubview:_backView];
        
        _highlightView = [[UIView alloc] initWithFrame:self.bounds];
        _highlightView.alpha = 0.0f;
        _highlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _highlightView.backgroundColor = [UIColor whiteColor];
        _highlightView.userInteractionEnabled = false;
        [self addSubview:_highlightView];
        
        _iconView = [[UIImageView alloc] initWithFrame:self.bounds];
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.layer.cornerRadius = frame.size.width / 2.0f;
}

- (void)setIconImage:(UIImage *)iconImage
{
    _iconView.image = iconImage;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    void (^changeBlock)(void) = ^
    {
        _highlightView.alpha = highlighted ? 1.0f : 0.0f;
    };
    
    if (_animateHighlight)
        [UIView animateWithDuration:0.2 animations:changeBlock];
    else
        changeBlock();
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesMoved:touches withEvent:event];
    _animateHighlight = false;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesEnded:touches withEvent:event];
    _animateHighlight = false;
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _animateHighlight = true;
    [super touchesCancelled:touches withEvent:event];
    _animateHighlight = false;
}

@end
