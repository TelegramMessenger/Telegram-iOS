#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeMediaAttachment.h>
#else
#import <WatchCommon/TGBridgeMediaAttachment.h>
#endif

@class TGBridgeBotReplyMarkup;

@interface TGBridgeReplyMarkupMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, strong) TGBridgeBotReplyMarkup *replyMarkup;

@end
