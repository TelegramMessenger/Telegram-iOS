#import "PGRectangleDetector.h"
#import "LegacyComponentsInternal.h"

#import <Vision/Vision.h>
#import <CoreImage/CoreImage.h>

#import <SSignalKit/SSignalKit.h>

@interface PGRectangle ()

- (instancetype)initWithRectangleFeature:(CIRectangleFeature *)rectangleFeature;
- (instancetype)initWithRectangleObservation:(VNRectangleObservation *)rectangleObservation API_AVAILABLE(ios(11.0));

- (CGFloat)size;

@end

@interface PGRectangleEntry : NSObject

@property (nonatomic, readonly) PGRectangle *rectangle;
@property (nonatomic, assign) NSInteger rate;

- (instancetype)initWithRectangle:(PGRectangle *)rectangle;

@end

@implementation PGRectangleEntry

- (instancetype)initWithRectangle:(PGRectangle *)rectangle
{
    self = [super init];
    if (self != nil)
    {
        _rectangle = rectangle;
        _rate = 0;
    }
    return self;
}

@end

@implementation PGRectangle

- (instancetype)initWithRectangleFeature:(CIRectangleFeature *)rectangleFeature
{
    self = [super init];
    if (self != nil) {
        _topLeft = rectangleFeature.topLeft;
        _topRight = rectangleFeature.topRight;
        _bottomLeft = rectangleFeature.bottomLeft;
        _bottomRight = rectangleFeature.bottomRight;
    }
    return self;
}

- (instancetype)initWithRectangleObservation:(VNRectangleObservation *)rectangleObservation API_AVAILABLE(ios(11.0))
{
    self = [super init];
    if (self != nil) {
        _topLeft = rectangleObservation.topLeft;
        _topRight = rectangleObservation.topRight;
        _bottomLeft = rectangleObservation.bottomLeft;
        _bottomRight = rectangleObservation.bottomRight;
    }
    return self;
}

- (PGRectangle *)transform:(CGAffineTransform)transform
{
    PGRectangle *rectangle = [[PGRectangle alloc] init];
    rectangle->_topLeft = CGPointApplyAffineTransform(_topLeft, transform);
    rectangle->_topRight = CGPointApplyAffineTransform(_topRight, transform);
    rectangle->_bottomLeft = CGPointApplyAffineTransform(_bottomLeft, transform);
    rectangle->_bottomRight = CGPointApplyAffineTransform(_bottomRight, transform);
    return rectangle;
}

- (PGRectangle *)rotate90
{
    PGRectangle *rectangle = [[PGRectangle alloc] init];
    rectangle->_topLeft = CGPointMake(_topLeft.y, _topLeft.x);
    rectangle->_topRight = CGPointMake(_topRight.y, _topRight.x);
    rectangle->_bottomLeft = CGPointMake(_bottomLeft.y, _bottomLeft.x);
    rectangle->_bottomRight = CGPointMake(_bottomRight.y, _bottomRight.x);
    return rectangle;
}

- (PGRectangle *)sort
{
    NSArray *points = @[ [NSValue valueWithCGPoint:_topLeft], [NSValue valueWithCGPoint:_topRight], [NSValue valueWithCGPoint:_bottomLeft], [NSValue valueWithCGPoint:_bottomRight] ];
    
    NSArray *ySorted = [points sortedArrayUsingComparator:^NSComparisonResult(id firstObject, id secondObject) {
        CGPoint firstPoint = [firstObject CGPointValue];
        CGPoint secondPoint = [secondObject CGPointValue];
        if (firstPoint.y < secondPoint.y) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
    
    NSArray *top = [ySorted subarrayWithRange:NSMakeRange(0, 2)];
    NSArray *bottom = [ySorted subarrayWithRange:NSMakeRange(2, 2)];
    
    NSArray *xSortedTop = [top sortedArrayUsingComparator:^NSComparisonResult(id firstObject, id secondObject) {
        CGPoint firstPoint = [firstObject CGPointValue];
        CGPoint secondPoint = [secondObject CGPointValue];
        if (firstPoint.x < secondPoint.x) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
    
    NSArray *xSortedBottom = [bottom sortedArrayUsingComparator:^NSComparisonResult(id firstObject, id secondObject) {
        CGPoint firstPoint = [firstObject CGPointValue];
        CGPoint secondPoint = [secondObject CGPointValue];
        if (firstPoint.x < secondPoint.x) {
            return NSOrderedAscending;
        } else {
            return NSOrderedDescending;
        }
    }];
    
    PGRectangle *rectangle = [[PGRectangle alloc] init];
    rectangle->_topLeft = [xSortedTop[0] CGPointValue];
    rectangle->_topRight = [xSortedTop[1] CGPointValue];
    rectangle->_bottomLeft = [xSortedBottom[0] CGPointValue];
    rectangle->_bottomRight = [xSortedBottom[1] CGPointValue];
    return rectangle;
}

- (PGRectangle *)cartesian:(CGFloat)height
{
    PGRectangle *rectangle = [[PGRectangle alloc] init];
    rectangle->_topLeft = CGPointMake(_topLeft.x, height - _topLeft.y);
    rectangle->_topRight = CGPointMake(_topRight.x, height - _topRight.y);
    rectangle->_bottomLeft = CGPointMake(_bottomLeft.x, height - _bottomLeft.y);
    rectangle->_bottomRight = CGPointMake(_bottomRight.x, height - _bottomRight.y);
    return rectangle;
}

- (PGRectangle *)normalize:(CGSize)size
{
    return [self transform:CGAffineTransformMakeScale(1.0 / size.width, 1.0 / size.height)];
}

+ (CGFloat)distance:(CGPoint)a to:(CGPoint)b
{
    return hypot(a.x - b.x, a.y - b.y);
}

- (CGFloat)size
{
    CGFloat sum = 0.0f;
    sum += [PGRectangle distance:self.topLeft to:self.topRight];
    sum += [PGRectangle distance:self.topRight to:self.bottomRight];
    sum += [PGRectangle distance:self.bottomRight to:self.bottomLeft];
    sum += [PGRectangle distance:self.bottomLeft to:self.topLeft];
    return sum;
}

+ (CGRect)pointSquare:(CGPoint)point size:(CGFloat)size
{
    return CGRectMake(point.x - size / 2.0, point.y - size / 2.0, size, size);
}

- (bool)matches:(PGRectangle *)other threshold:(CGFloat)threshold
{
    if (!CGRectContainsPoint([PGRectangle pointSquare:self.topLeft size:threshold], other.topLeft))
        return false;
    
    if (!CGRectContainsPoint([PGRectangle pointSquare:self.topRight size:threshold], other.topRight))
        return false;
    
    if (!CGRectContainsPoint([PGRectangle pointSquare:self.bottomLeft size:threshold], other.bottomLeft))
        return false;
    
    if (!CGRectContainsPoint([PGRectangle pointSquare:self.bottomRight size:threshold], other.bottomRight))
        return false;
    
    return true;
}

@end

@implementation PGRectangleDetector
{
    SQueue *_queue;
    CIDetector *_detector;
    
    bool _disabled;
    
    CGSize _imageSize;
    NSInteger _notFoundCount;
    NSMutableArray *_rectangles;
    
    PGRectangle *_detectedRectangle;
    NSInteger _autoscanCount;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _queue = [[SQueue alloc] init];
        _rectangles = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)updateEntries
{
    for (PGRectangleEntry *entry in _rectangles) {
        entry.rate = 1;
    }
    
    for (NSInteger i = 0; i < _rectangles.count; i++) {
        for (NSInteger j = 0; i < _rectangles.count; i++) {
            if (j > i && [[_rectangles[i] rectangle] matches:_rectangles[j] threshold:40.0]) {
                ((PGRectangleEntry *)_rectangles[i]).rate += 1;
                ((PGRectangleEntry *)_rectangles[j]).rate += 1;
            }
        }
    }
}

- (void)addRectangle:(PGRectangle *)rectangle
{
    if (_disabled)
        return;
    
    PGRectangleEntry *entry = [[PGRectangleEntry alloc] initWithRectangle:rectangle];
    [_rectangles addObject:entry];
    
    if (_rectangles.count < 3)
        return;
    
    if (_rectangles.count > 8)
        [_rectangles removeObjectAtIndex:0];
    
    [self updateEntries];
    
    __block PGRectangleEntry *best = nil;
    [_rectangles enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(PGRectangleEntry *rectangle, NSUInteger idx, BOOL * stop) {
        if (best == nil) {
            best = rectangle;
            return;
        }
        
        if (rectangle.rate > best.rate) {
            best = rectangle;
        } else if (rectangle.rate == best.rate) {
            if (_detectedRectangle != nil) {
                if ([rectangle.rectangle matches:_detectedRectangle threshold:40.0]) {
                    best = rectangle;
                }
            }
        }
    }];
    
    if (_detectedRectangle != nil && [best.rectangle matches:_detectedRectangle threshold:24.0f]) {
        _autoscanCount += 1;
        _detectedRectangle = best.rectangle;
        if (_autoscanCount > 20) {
            _autoscanCount = 0;
            self.update(true, [_detectedRectangle normalize:_imageSize]);
            
            _detectedRectangle = nil;
            
            _disabled = true;
            TGDispatchAfter(2.0, _queue._dispatch_queue, ^{
                _disabled = false;
            });
        }
    } else {
        _autoscanCount = 0;
        _detectedRectangle = best.rectangle;
        self.update(false, [_detectedRectangle normalize:_imageSize]);
    }
}

- (void)processRectangle:(PGRectangle *)rectangle imageSize:(CGSize)imageSize
{
    _imageSize = imageSize;
    
    if (rectangle != nil) {
        _notFoundCount = 0;
        
        [self addRectangle:rectangle];
    } else {
        _notFoundCount += 1;
        
        if (_notFoundCount > 3) {
            _autoscanCount = 0;
            _detectedRectangle = nil;
            
            self.update(false, nil);
        }
    }
}

- (void)detectRectangle:(CVPixelBufferRef)pixelBuffer
{
    CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    if (@available(iOS 11.0, *)) {
        CVPixelBufferRetain(pixelBuffer);
        NSError *error;
        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
        VNDetectRectanglesRequest *request = [[VNDetectRectanglesRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            CVPixelBufferRelease(pixelBuffer);
            
            [_queue dispatch:^{
                if (error == nil && request.results.count > 0) {
                    PGRectangle *largestRectangle = nil;
                    for (VNRectangleObservation *result in request.results) {
                        if (![result isKindOfClass:[VNRectangleObservation class]])
                            continue;
                        
                        PGRectangle *rectangle = [[PGRectangle alloc] initWithRectangleObservation:result];
                        if (largestRectangle == nil || largestRectangle.size < rectangle.size) {
                            largestRectangle = rectangle;
                        }
                    }
                    [self processRectangle:[largestRectangle transform:CGAffineTransformMakeScale(size.width, size.height)] imageSize:size];
                } else {
                    [self processRectangle:nil imageSize:size];
                }
            }];
        }];
        request.minimumConfidence = 0.85f;
        request.maximumObservations = 15;
        request.minimumAspectRatio = 0.33;
        request.minimumSize = 0.4;
        [handler performRequests:@[request] error:&error];
    } else {
        CVPixelBufferRetain(pixelBuffer);
        [_queue dispatch:^{
            if (_detector == nil) {
                _detector = [CIDetector detectorOfType:CIDetectorTypeRectangle context:[CIContext contextWithOptions:nil] options:@{ CIDetectorAccuracy: CIDetectorAccuracyHigh }];
            }
            
            CIImage *image = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer];
            NSArray *results = [_detector featuresInImage:image];
            CVPixelBufferRelease(pixelBuffer);
            
            PGRectangle *largestRectangle = nil;
            for (CIRectangleFeature *result in results) {
                if (![result isKindOfClass:[CIRectangleFeature class]])
                    continue;
                
                PGRectangle *rectangle = [[PGRectangle alloc] initWithRectangleFeature:result];
                if (largestRectangle == nil || largestRectangle.size < rectangle.size) {
                    largestRectangle = rectangle;
                }
            }
            [self processRectangle:largestRectangle imageSize:size];
        }];
    }
}

@end
