#import <Foundation/Foundation.h>

@class TGBridgeUser;
@class TGBridgeBotInfo;

@interface TGBridgeUserCache : NSObject

- (TGBridgeUser *)userWithId:(int32_t)userId;
- (NSDictionary *)usersWithIndexSet:(NSIndexSet *)indexSet;
- (void)storeUser:(TGBridgeUser *)user;
- (void)storeUsers:(NSArray *)users;
- (NSArray *)applyUserChanges:(NSArray *)userChanges;

- (TGBridgeBotInfo *)botInfoForUserId:(int32_t)userId;
- (void)storeBotInfo:(TGBridgeBotInfo *)botInfo forUserId:(int32_t)userId;

+ (instancetype)instance;

@end
