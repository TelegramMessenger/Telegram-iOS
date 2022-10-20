#import "TGBridgeBotSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeUserCache.h"

#import "TGBridgeClient.h"

@implementation TGBridgeBotSignals

+ (SSignal *)botInfoForUserId:(int32_t)userId
{
    SSignal *cachedSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:userId];
        TGBridgeBotInfo *botInfo = [[TGBridgeUserCache instance] botInfoForUserId:userId];
        
        if (botInfo == nil)
        {
            [subscriber putError:nil];
        }
        else
        {
            [subscriber putNext:botInfo];
        }
        
        return nil;
    }];
    
    return [cachedSignal catch:^SSignal *(__unused id error)
    {
        return [[[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeUserBotInfoSubscription alloc] initWithUserIds:@[ @(userId) ]]] mapToSignal:^SSignal *(NSDictionary *bots)
        {
            TGBridgeBotInfo *botInfo = bots[@(userId)];
            
            if (botInfo != nil)
            {
                [[TGBridgeUserCache instance] storeBotInfo:botInfo forUserId:userId];
                return [SSignal single:botInfo];
            }
            else
            {
                return [SSignal fail:nil];
            }
        }];
    }];
}

+ (SSignal *)botReplyMarkupForPeerId:(int64_t)peerId
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeBotReplyMarkupSubscription alloc] initWithPeerId:peerId]];
}

@end
