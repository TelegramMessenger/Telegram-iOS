#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#endif

@class TGBridgeMessage;

@interface TGBridgeReplyMessageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int32_t mid;
@property (nonatomic, strong) TGBridgeMessage *message;

@end
