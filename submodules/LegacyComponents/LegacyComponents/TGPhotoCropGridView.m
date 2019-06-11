#import "TGPhotoCropGridView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

const NSInteger TGPhotoCropMajorGridViewLinesCount = 2;
const NSInteger TGPhotoCropMinorGridViewLinesCount = 8;

@interface TGPhotoCropGridView ()
{
    bool _animatingHidden;
    bool _targetHidden;
}
@end

@implementation TGPhotoCropGridView

- (instancetype)initWithMode:(TGPhotoCropViewGridMode)mode
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.opaque = false;
        self.userInteractionEnabled = false;
        
        _mode = mode;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (!self.hidden)
        [self setNeedsDisplay];
}

- (void)setHidden:(BOOL)hidden
{
    [self setHidden:hidden animated:false duration:0 delay:0];
}

- (void)setHidden:(bool)hidden animated:(bool)animated duration:(CGFloat)duration delay:(CGFloat)delay
{
    if (_animatingHidden && _targetHidden == hidden)
        return;
    
    [self setNeedsDisplay];
    
    _targetHidden = hidden;
    
    if (animated)
    {
        _animatingHidden = YES;
        super.hidden = false;
        
        [UIView animateWithDuration:duration
                              delay:delay
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut
                         animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                super.hidden = hidden;
                _animatingHidden = NO;
            }
        }];
    }
    else
    {
        super.hidden = hidden;
        self.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)drawRect:(CGRect)rect
{
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    
    CGFloat thickness = 1.0f;
    if (TGIsRetina())
        thickness = 0.5f;
    
    for (NSInteger i = 0; i < 3; i++)
    {
        if (_mode == TGPhotoCropViewGridModeMinor)
        {
            for (NSInteger j = 1; j < 4; j++)
            {
                [UIColorRGBA(0xeeeeee, 0.7f) set];
                
                UIRectFill(CGRectMake(CGRound(width / 3 / 3 * j + width / 3 * i), 0, thickness, CGRound(height)));
                UIRectFill(CGRectMake(0, CGRound(height / 3 / 3 * j + height / 3 * i), CGRound(width), thickness));
            }
        }
        
        if (_mode == TGPhotoCropViewGridModeMajor)
        {
            if (i > 0)
            {
                [[UIColor whiteColor] set];
                
                UIRectFill(CGRectMake(CGRound(width / 3 * i), 0, thickness, CGRound(height)));
                UIRectFill(CGRectMake(0, CGRound(height / 3 * i), CGRound(width), thickness));
            }
        }
    }
}

@end
