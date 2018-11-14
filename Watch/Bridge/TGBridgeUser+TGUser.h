#import "TGBridgeUser.h"

@class TGUser;
@class TGBotInfo;

@interface TGBridgeUser (TGUser)

+ (TGBridgeUser *)userWithTGUser:(TGUser *)user;

@end
