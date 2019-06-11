#import "TGPaintInput.h"
#import <CoreGraphics/CoreGraphics.h>

#import "LegacyComponentsInternal.h"

#import "TGPaintPanGestureRecognizer.h"

#import "TGPainting.h"
#import "TGPaintPath.h"
#import "TGPaintState.h"
#import "TGPaintCanvas.h"
#import <LegacyComponents/TGPaintUtils.h>

@interface TGPaintInput ()
{
    bool _first;
    bool _moved;
    bool _clearBuffer;
    
    CGPoint _lastLocation;
    CGFloat _lastRemainder;
    
    TGPaintPoint *_points[3];
    NSInteger _pointsCount;
}
@end

@implementation TGPaintInput

- (CGPoint)_location:(CGPoint)location inView:(UIView *)view
{
    location.y = view.bounds.size.height - location.y;
    
    CGAffineTransform inverted = CGAffineTransformInvert(_transform);
    CGPoint transformed = CGPointApplyAffineTransform(location, inverted);
    
    return transformed;
}

- (void)smoothenAndPaintPoints:(TGPaintCanvas *)canvas ended:(bool)ended
{
    NSMutableArray *points = [[NSMutableArray alloc] init];
    
    TGPaintPoint *prev2 = _points[0];
    TGPaintPoint *prev1 = _points[1];
    TGPaintPoint *cur = _points[2];
    
    CGPoint midPoint1 = TGPaintMultiplyPoint(TGPaintAddPoints(prev1.CGPoint, prev2.CGPoint), 0.5f);
    CGFloat midPressure1 = (prev1.z + prev2.z) * 0.5f;
    CGPoint midPoint2 = TGPaintMultiplyPoint(TGPaintAddPoints(cur.CGPoint, prev1.CGPoint), 0.5f);
    CGFloat midPressure2 = (cur.z + prev2.z) * 0.5f;
    
    NSInteger segmentDistance = 2;
    CGFloat distance = TGPaintDistance(midPoint1, midPoint2);
    NSInteger numberOfSegments = (NSInteger)MIN(72, MAX(floor(distance / segmentDistance), 36));
    
    CGFloat t = 0.0f;
    CGFloat step = 1.0f / numberOfSegments;
    for (NSInteger j = 0; j < numberOfSegments; j++)
    {
        CGFloat f1 = pow(1 - t, 2);
        CGFloat f2 = 2.0 * (1 - t) * t;
        CGFloat f3 = t * t;
        
        CGPoint pos = TGPaintAddPoints(TGPaintAddPoints(TGPaintMultiplyPoint(midPoint1, f1), TGPaintMultiplyPoint(prev1.CGPoint, f2)), TGPaintMultiplyPoint(midPoint2, f3));
        CGFloat pressure = (midPressure1 * f1 + prev1.z * f2) + (midPressure2 * f3);
        TGPaintPoint *newPoint = [TGPaintPoint pointWithCGPoint:pos z:pressure];
        if (_first)
        {
            newPoint.edge = true;
            _first = false;
        }
        [points addObject:newPoint];
        t += step;
    }
    
    TGPaintPoint *finalPoint = [TGPaintPoint pointWithCGPoint:midPoint2 z:midPressure2];
    if (ended)
        finalPoint.edge = true;
    [points addObject:finalPoint];
    
    TGPaintPath *path = [[TGPaintPath alloc] initWithPoints:points];
    [self paintPath:path inCanvas:canvas];
    
    for (int i = 0; i < 2; i++)
    {
        _points[i] = _points[i + 1];
    }
    
    if (ended)
        _pointsCount = 0;
    else
        _pointsCount = 2;
}

- (void)gestureBegan:(TGPaintPanGestureRecognizer *)recognizer
{
    _moved = false;
    _first = true;
    
    CGPoint location = [self _location:[recognizer locationInView:recognizer.view] inView:recognizer.view];
    _lastLocation = location;
    
    TGPaintPoint *point = [TGPaintPoint pointWithX:location.x y:location.y z:1.0f];
    _points[0] = point;
    _pointsCount = 1;
    
    _clearBuffer = true;
}

- (void)gestureMoved:(TGPaintPanGestureRecognizer *)recognizer
{
    TGPaintCanvas *canvas = (TGPaintCanvas *)recognizer.view;
    CGPoint location = [self _location:[recognizer locationInView:recognizer.view] inView:recognizer.view];
    CGFloat distanceMoved = TGPaintDistance(location, _lastLocation);
    
    if (distanceMoved < 8.0f)
        return;
    
    const CGFloat speedFactor = 3.0f;
    CGPoint velocity = [recognizer velocityInView:recognizer.view];
    CGFloat speed = TGPaintDistance(CGPointZero, velocity) / 1000.0f;
    CGFloat pressure = TGPaintSineCurve(1.0f - MIN(speedFactor, speed) / speedFactor);
    pressure = 1.0f - pressure;
    
    if (_pointsCount != 0)
        pressure = (pressure + _points[_pointsCount - 1].z) / 2.0f;
    
    pressure = 1.0f;
    TGPaintPoint *point = [TGPaintPoint pointWithX:location.x y:location.y z:pressure];
    _points[_pointsCount++] = point;
    
    if (_pointsCount == 3)
    {
        [self smoothenAndPaintPoints:canvas ended:false];
        _moved = true;
    }
    
    _lastLocation = location;
}

- (void)gestureEnded:(TGPaintPanGestureRecognizer *)recognizer
{
    TGPaintCanvas *canvas = (TGPaintCanvas *)recognizer.view;
    TGPainting *painting = canvas.painting;
    
    CGPoint location = [self _location:[recognizer locationInView:recognizer.view] inView:recognizer.view];
    if (!_moved)
    {
        TGPaintPoint *point = [TGPaintPoint pointWithX:location.x y:location.y z:1.0];
        point.edge = true;
        
        TGPaintPath *path = [[TGPaintPath alloc] initWithPoint:point];
        [self paintPath:path inCanvas:canvas];
    }
    else
    {
        [self smoothenAndPaintPoints:canvas ended:true];
    }
    
    _pointsCount = 0;
    
    [painting commitStrokeWithColor:canvas.state.color erase:canvas.state.isEraser];
}

- (void)gestureCanceled:(UIGestureRecognizer *)recognizer
{
     TGPaintCanvas *canvas = (TGPaintCanvas *) recognizer.view;
     TGPainting *painting = canvas.painting;

     painting.activePath = nil;
     [canvas draw];
}

- (void)paintPath:(TGPaintPath *)path inCanvas:(TGPaintCanvas *)canvas
{
    path.color = canvas.state.color;
    path.action = canvas.state.isEraser ? TGPaintActionErase : TGPaintActionDraw;
    path.brush = canvas.state.brush;
    path.baseWeight = canvas.state.weight;
    
    if (_clearBuffer)
        _lastRemainder = 0.0f;
    
    path.remainder = _lastRemainder;
    
    [canvas.painting paintStroke:path clearBuffer:_clearBuffer completion:^
    {
        TGDispatchOnMainThread(^
        {
            _lastRemainder = path.remainder;
            _clearBuffer = false;
        });
    }];
}

@end
