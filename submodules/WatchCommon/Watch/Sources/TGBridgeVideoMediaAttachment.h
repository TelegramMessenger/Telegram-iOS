#import <WatchCommonWatch/TGBridgeMediaAttachment.h>

#import <CoreGraphics/CoreGraphics.h>

@interface TGBridgeVideoMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t videoId;
@property (nonatomic, assign) int32_t duration;
@property (nonatomic, assign) CGSize dimensions;
@property (nonatomic, assign) bool round;

@end
