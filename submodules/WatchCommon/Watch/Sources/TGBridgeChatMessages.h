#import <WatchCommonWatch/TGBridgeCommon.h>

@class SSignal;

@interface TGBridgeChatMessages : NSObject <NSCoding>
{
    NSArray *_messages;
}

@property (nonatomic, readonly) NSArray *messages;

@end

extern NSString *const TGBridgeChatMessageListViewKey;
