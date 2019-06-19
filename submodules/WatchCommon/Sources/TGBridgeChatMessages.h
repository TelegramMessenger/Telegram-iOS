#if TARGET_OS_WATCH
#import <WatchCommonWatch/TGBridgeCommon.h>
#else
#import <WatchCommon/TGBridgeCommon.h>
#endif

@class SSignal;

@interface TGBridgeChatMessages : NSObject <NSCoding>
{
    NSArray *_messages;
}

@property (nonatomic, readonly) NSArray *messages;

@end

extern NSString *const TGBridgeChatMessageListViewKey;
