#import <SSignalKit/SSignalKit.h>

@interface TGBridgeUserInfoSignals : NSObject

+ (SSignal *)userInfoWithUserId:(int32_t)userId;
+ (SSignal *)usersInfoWithUserIds:(NSArray *)userIds;

@end
