#import <WatchCommonWatch/TGBridgeMediaAttachment.h>

@interface TGBridgeForwardedMessageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t peerId;
@property (nonatomic, assign) int32_t mid;
@property (nonatomic, assign) int32_t date;

@end
