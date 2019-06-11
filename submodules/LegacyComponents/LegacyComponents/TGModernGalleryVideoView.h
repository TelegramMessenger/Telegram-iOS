#import <UIKit/UIKit.h>

@class AVPlayer;
@class AVPlayerLayer;

@interface TGModernGalleryVideoView : UIView

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, copy) void (^deallocBlock)(void);
@property (nonatomic, strong) NSString *key;

- (instancetype)initWithFrame:(CGRect)frame player:(AVPlayer *)player;
- (instancetype)initWithFrame:(CGRect)frame player:(AVPlayer *)player key:(NSString *)key;
- (void)cleanupPlayer;

@end
