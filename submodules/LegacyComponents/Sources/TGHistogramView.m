#import "TGHistogramView.h"
#import "PGPhotoHistogram.h"
#import "TGPhotoEditorCurvesToolView.h"

const NSUInteger TGHistogramGranularity = 20;

@interface CAAnimatedShapeLayer : CAShapeLayer

@end

@implementation CAAnimatedShapeLayer

- (id<CAAction>)actionForKey:(NSString *)event
{
    if ([event isEqualToString:@"path"] || [event isEqualToString:@"fillColor"])
    {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:event];
        animation.duration = [CATransaction animationDuration];
        animation.timingFunction = [CATransaction animationTimingFunction];
        return animation;
    }
    
    return [super actionForKey:event];
}

@end

@implementation TGHistogramView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        [self shapeLayer].fillColor = [UIColor whiteColor].CGColor;
    }
    return self;
}

- (CAShapeLayer *)shapeLayer
{
    return (CAShapeLayer *)self.layer;
}

+ (Class)layerClass
{
    return [CAAnimatedShapeLayer class];
}

- (void)setHistogram:(PGPhotoHistogram *)histogram type:(PGCurvesType)type animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        [self shapeLayer].path = [self _bezierPathForHistogramBins:[histogram histogramBinsForType:type]].CGPath;
        [self shapeLayer].fillColor = [TGPhotoEditorCurvesToolView colorForCurveType:type].CGColor;
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.25f animations:changeBlock];
    }
    else
    {
        changeBlock();
    }
}

- (CGPoint)_viewPointWithValue:(CGFloat)value index:(NSInteger)index step:(CGFloat)step actualSize:(CGSize)actualSize
{
    return CGPointMake(index * step, (1.0 - value) * actualSize.height);
}

- (UIBezierPath *)_bezierPathForHistogramBins:(PGPhotoHistogramBins *)histogramBins
{
    UIBezierPath *path = [[UIBezierPath alloc] init];
 
    if (histogramBins == nil)
        return path;
    
    CGSize actualSize = self.frame.size;
    if (self.isLandscape)
        actualSize = CGSizeMake(actualSize.height, actualSize.width);
    
    CGFloat firstValue = [histogramBins[0] floatValue];
    [path moveToPoint:CGPointMake(-1, actualSize.height)];
    [path addLineToPoint:CGPointMake(-1, (1 - firstValue) * actualSize.height)];
    
    CGFloat xStep = actualSize.width / 255.0f;
    
    for (NSUInteger index = 1; index < histogramBins.count - 2; index++)
    {
        CGPoint point0 = [self _viewPointWithValue:[histogramBins[index - 1] floatValue] index:index - 1 step:xStep actualSize:actualSize];
        CGPoint point1 = [self _viewPointWithValue:[histogramBins[index] floatValue] index:index step:xStep actualSize:actualSize];
        CGPoint point2 = [self _viewPointWithValue:[histogramBins[index + 1] floatValue] index:index + 1 step:xStep actualSize:actualSize];
        CGPoint point3 = [self _viewPointWithValue:[histogramBins[index + 2] floatValue] index:index + 2 step:xStep actualSize:actualSize];
        
        for (NSUInteger i = 1; i < TGHistogramGranularity; i++)
        {
            CGFloat t = (CGFloat)i * (1.0f / (CGFloat)TGHistogramGranularity);
            CGFloat tt = t * t;
            CGFloat ttt = tt * t;
            
            CGPoint pi =
            {
                0.5 * (2 * point1.x + (point2.x - point0.x) * t + (2 * point0.x - 5 * point1.x + 4 * point2.x - point3.x) * tt + (3 * point1.x - point0.x - 3 * point2.x + point3.x) * ttt),
                0.5 * (2 * point1.y + (point2.y - point0.y) * t + (2 * point0.y - 5 * point1.y + 4 * point2.y - point3.y) * tt + (3 * point1.y - point0.y - 3 * point2.y + point3.y) * ttt)
            };
            
            pi.y = MAX(0, MIN(actualSize.height, pi.y));
            
            if (pi.x > point0.x)
                [path addLineToPoint:pi];
        }
        
        [path addLineToPoint:point2];
    }
    
    CGFloat lastValue = [histogramBins[histogramBins.count - 1] floatValue];
    [path addLineToPoint:CGPointMake(actualSize.width + 1, (1 - lastValue) * actualSize.height)];
    
    [path addLineToPoint:CGPointMake(actualSize.width+ 1, actualSize.height)];
    
    [path closePath];
    
    return path;
}

@end
