#import "TGCameraRectangleView.h"
#import "TGCameraInterfaceAssets.h"
#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import "TGCameraPreviewView.h"
#import "PGRectangleDetector.h"

@interface TGCameraRectangleView ()
{
    CAShapeLayer *_quadLayer;
    
    bool _clearing;
}
@end

@implementation TGCameraRectangleView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
        _enabled = true;
        
        self.backgroundColor = [UIColor clearColor];
        self.alpha = 0.0f;
        
        _quadLayer = [[CAShapeLayer alloc] init];
        _quadLayer.strokeColor = [[TGCameraInterfaceAssets accentColor] colorWithAlphaComponent:0.7].CGColor;
        _quadLayer.fillColor = [[TGCameraInterfaceAssets accentColor] colorWithAlphaComponent:0.45].CGColor;
        _quadLayer.lineWidth = 2.0;
        
        [self.layer addSublayer:_quadLayer];
    }
    return self;
}

- (CGPathRef)pathForRectangle:(PGRectangle *)rectangle
{
    CGAffineTransform transform = CGAffineTransformMakeScale(self.previewView.frame.size.width, self.previewView.frame.size.height);
    PGRectangle *displayRectangle = [[rectangle rotate90] transform:transform];
    
    UIBezierPath *path = [[UIBezierPath alloc] init];
    [path moveToPoint:displayRectangle.topLeft];
    [path addLineToPoint:displayRectangle.topRight];
    [path addLineToPoint:displayRectangle.bottomRight];
    [path addLineToPoint:displayRectangle.bottomLeft];
    [path closePath];
    return path.CGPath;
}

- (void)drawRectangle:(PGRectangle *)rectangle
{
    if (!_enabled) {
        return;
    }
    
    if (rectangle == nil) {
        [self clear];
        return;
    }
    
    _clearing = false;
    [self.layer removeAllAnimations];
    
    bool animated = _quadLayer.path != nil;
    if (animated) {
        CAAnimation *animation = [CABasicAnimation animationWithKeyPath:@"path"];
        animation.duration = 0.2;
        [_quadLayer addAnimation:animation forKey:@"path"];
    } else {
        self.transform = CGAffineTransformMakeScale(1.1, 1.1);
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionAllowAnimatedContent animations:^{
            self.transform = CGAffineTransformIdentity;
            self.alpha = 1.0f;
        } completion:nil];
    }
    _quadLayer.path = [self pathForRectangle:rectangle];
}

- (void)clear
{
    if (_quadLayer.path == nil || _clearing)
        return;
    
    _clearing = true;
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionAllowAnimatedContent animations:^{
        self.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (_clearing) {
            _quadLayer.path = nil;
            _clearing = false;
        }
    }];
}

- (void)layoutSubviews
{
    _quadLayer.frame = self.bounds;
}

@end
