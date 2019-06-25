#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#endif

@interface TGBridgeForwardedMessageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int64_t peerId;
@property (nonatomic, assign) int32_t mid;
@property (nonatomic, assign) int32_t date;

@end
