#import <WatchCommon/TGBridgeMediaAttachment.h>

@class TGBridgeBotReplyMarkup;

@interface TGBridgeReplyMarkupMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, strong) TGBridgeBotReplyMarkup *replyMarkup;

@end
