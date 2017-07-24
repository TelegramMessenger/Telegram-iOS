#import "PGCameraMomentSession.h"
#import "PGCamera.h"

@interface PGCameraMomentSession ()
{
    NSString *_uniqueIdentifier;
    NSURL *_segmentsDirectory;
    
    PGCamera *_camera;
    NSMutableArray *_segments;
}
@end

@implementation PGCameraMomentSession

- (instancetype)initWithCamera:(PGCamera *)camera
{
    self = [super init];
    if (self != nil)
    {
        _camera = camera;
        _segments = [[NSMutableArray alloc] init];
        
        int64_t uniqueId = 0;
        arc4random_buf(&uniqueId, 8);
        _uniqueIdentifier = [NSString stringWithFormat:@"%x", (int)arc4random()];
    }
    return self;
}

- (NSURL *)segmentsDirectory
{
    if (_segmentsDirectory == nil)
        _segmentsDirectory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:_uniqueIdentifier]];
    
    return _segmentsDirectory;
}

- (void)captureSegment
{
    if (self.isCapturing)
        return;
    
    _isCapturing = true;
    
    if (self.beganCapture != nil)
        self.beganCapture();
    
    [_camera startVideoRecordingForMoment:true completion:^(NSURL *resultUrl, __unused CGAffineTransform transform, __unused CGSize dimensions, NSTimeInterval duration, bool success)
    {
        if (!success)
            return;
        
        _isCapturing = false;
        
        if (self.finishedCapture != nil)
            self.finishedCapture();
        
        PGCameraMomentSegment *segment = [[PGCameraMomentSegment alloc] initWithURL:resultUrl duration:duration];
        [self addSegment:segment];
    }];
}

- (void)commitSegment
{
    [_camera stopVideoRecording];
}

- (void)addSegment:(PGCameraMomentSegment *)segment
{
    [_segments addObject:segment];
}

- (void)removeSegment:(PGCameraMomentSegment *)segment
{
    [_segments removeObject:segment];
}

- (void)removeLastSegment
{
    [_segments removeLastObject];
}

- (void)removeAllSegments
{
    [_segments removeAllObjects];
}

@end
