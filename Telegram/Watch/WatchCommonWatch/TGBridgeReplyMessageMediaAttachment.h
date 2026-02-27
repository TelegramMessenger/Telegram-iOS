#import <WatchCommonWatch/TGBridgeMediaAttachment.h>

@class TGBridgeMessage;

@interface TGBridgeReplyMessageMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) int32_t mid;
@property (nonatomic, strong) TGBridgeMessage *message;

@end
