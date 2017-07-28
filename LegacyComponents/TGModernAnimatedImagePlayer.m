#import "TGModernAnimatedImagePlayer.h"

#import <LegacyComponents/LegacyComponents.h>

#import "FLAnimatedImage.h"
#import <LegacyComponents/TGTimerTarget.h>

#import <LegacyComponents/TGImageBlur.h>

@interface TGModernAnimatedImagePlayer ()
{
    FLAnimatedImage *_image;
    NSTimer *_timer;
    NSInteger _currentFrame;
}

@end

@implementation TGModernAnimatedImagePlayer

- (instancetype)initWithSize:(CGSize)size renderSize:(CGSize)renderSize path:(NSString *)path
{
    self = [super init];
    if (self != nil)
    {
        NSData *data = [[NSData alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] options:NSDataReadingMappedIfSafe error:nil];
        _image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:data imageDrawingBlock:^UIImage *(UIImage *image)
        {
            return TGAnimationFrameAttachmentImage(image, size, renderSize);
        }];
    }
    return self;
}

- (instancetype)initWithSize:(CGSize)size data:(NSData *)data
{
    self = [super init];
    if (self != nil)
    {
        _image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:data imageDrawingBlock:^UIImage *(UIImage *image)
        {
            return TGScaleImageToPixelSize(image, size);
        }];
    }
    return self;
}

- (void)dealloc
{
    [_timer invalidate];
}

- (void)play
{
    [_timer invalidate];
    _timer = nil;
    
    [self _pollNextFrame];
}

- (void)_pollNextFrame
{
    UIImage *image = [_image imageLazilyCachedAtIndex:_currentFrame];
    bool gotFrame = false;
    if (image != nil)
    {
        gotFrame = true;
        
        if ([[NSRunLoop mainRunLoop].currentMode isEqualToString:NSDefaultRunLoopMode])
        {
            _currentFrame++;
            if (_currentFrame >= (NSInteger)_image.delayTimes.count)
                _currentFrame = 0;
        }
        
        if (_frameReady)
            _frameReady(image);
    }
    
    if ((NSInteger)[_image delayTimes].count > _currentFrame)
    {
        _timer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(_pollNextFrame) interval:gotFrame ? [_image.delayTimes[_currentFrame] doubleValue] : (1.0f / 80.0f) repeat:false runLoopModes:NSDefaultRunLoopMode];
    }
}

- (void)stop
{
    [_timer invalidate];
    _timer = nil;
    _currentFrame = 0;
}

- (void)pause
{
    [_timer invalidate];
    _timer = nil;
    
    
}

@end
