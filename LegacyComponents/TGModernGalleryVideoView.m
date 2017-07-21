#import "TGModernGalleryVideoView.h"
#import <AVFoundation/AVFoundation.h>

/*@interface AVPlayerLayer ()

- (id)_sublayersForPIP;

@end

@interface TGModernGalleryVideoViewLayer : AVPlayerLayer {
    CALayer *_testLayer;
}

@end

@implementation TGModernGalleryVideoViewLayer

- (id)_sublayersForPIP {
    NSDictionary *current = [super _sublayersForPIP];
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:current];
    
    if (_testLayer == nil) {
        _testLayer = [[CALayer alloc] init];
        _testLayer.frame = CGRectMake(0.0f, 0.0f, 40.0f, 20.0f);
        _testLayer.backgroundColor = [UIColor greenColor].CGColor;
        
        //[(CALayer *)result[@"videoLayer"] addSublayer:_testLayer];
    }
    
    CALayer *videoLayer = ((CALayer *)result[@"videoLayer"]);
    CALayer *sublayer = [videoLayer valueForKey:@"_videoLayer"];
    [sublayer addSublayer:_testLayer];
    
    return result;
}

@end*/

@implementation TGModernGalleryVideoView

- (instancetype)initWithFrame:(CGRect)frame player:(AVPlayer *)player
{
    return [self initWithFrame:frame player:player key:nil];
}

- (instancetype)initWithFrame:(CGRect)frame player:(AVPlayer *)player key:(NSString *)key
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _key = key;
        self.playerLayer.player = player;
    }
    return self;
}

- (void)dealloc
{
    void (^deallocBlock)(void) = self.deallocBlock;
    if (deallocBlock != nil)
        deallocBlock();
}

- (void)setPlayer:(AVPlayer *)player
{
    self.playerLayer.player = player;
}

- (AVPlayer *)player
{
    return self.playerLayer.player;
}

- (void)cleanupPlayer
{
    self.playerLayer.player = nil;
}

+ (Class)layerClass
{
    //return [TGModernGalleryVideoViewLayer class];
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer
{
    return (AVPlayerLayer *)self.layer;
}

@end
