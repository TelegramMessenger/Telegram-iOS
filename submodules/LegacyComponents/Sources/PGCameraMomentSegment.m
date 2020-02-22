#import "PGCameraMomentSegment.h"

@interface PGCameraMomentSegment ()
{
    
}
@end

@implementation PGCameraMomentSegment

- (instancetype)initWithURL:(NSURL *)url duration:(NSTimeInterval)duration
{
    self = [super init];
    if (self != nil)
    {
        _fileURL = url;
        _duration = duration;
    }
    return self;
}

@end
