#import <UIKit/UIKit.h>

@interface TGEmbedPlayerScrubber : UIControl

@property (nonatomic, copy) void (^onInteractionStart)();
@property (nonatomic, copy) void (^onSeek)(CGFloat position);
@property (nonatomic, copy) void (^onInteractionEnd)();

@property (nonatomic, readonly) bool isTracking;

- (void)setPosition:(CGFloat)position;
- (void)setDownloadProgress:(CGFloat)progress;

- (void)setTintColor:(UIColor *)tintColor;

@end
