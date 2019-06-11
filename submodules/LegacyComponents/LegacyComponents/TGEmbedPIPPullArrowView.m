#import "TGEmbedPIPPullArrowView.h"

#import <LegacyComponents/LegacyComponents.h>

@interface TGEmbedPIPPullArrowView ()
{
    UIImageView *_topPart;
    UIImageView *_bottomPart;
}
@end

@implementation TGEmbedPIPPullArrowView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.layer.rasterizationScale = TGScreenScaling();
        self.layer.shouldRasterize = true;
        if ([self.layer respondsToSelector:@selector(setAllowsEdgeAntialiasing:)])
            self.layer.allowsEdgeAntialiasing = true;
        
        static dispatch_once_t onceToken;
        static UIImage *image;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 23), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 8, 23) cornerRadius:4.5f] fill];
            
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _topPart = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 8, 38)];
        _topPart.contentMode = UIViewContentModeBottom;
        _topPart.image = image;
        [self addSubview:_topPart];
        
        _bottomPart = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 8, 38)];
        _bottomPart.contentMode = UIViewContentModeTop;
        _bottomPart.image = image;
        _bottomPart.transform = CGAffineTransformMakeScale(1, -1);
        [self addSubview:_bottomPart];
    }
    return self;
}

- (void)setAngled:(bool)angled animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        CGFloat angle = angled ? 0.20944f : 0.0f;
        
        _topPart.transform = CGAffineTransformMakeRotation(angle);
        _bottomPart.transform = CGAffineTransformMakeRotation(-angle);
    };
    
    if (animated)
        [UIView animateWithDuration:0.25 animations:changeBlock];
    else
        changeBlock();
}

@end
