#import "TGBridgeUser+TGUser.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGBridgeBotInfo+TGBotInfo.h"

@implementation TGBridgeUser (TGUser)

+ (TGBridgeUser *)userWithTGUser:(TGUser *)user
{
    if (user == nil)
        return nil;
    
    TGBridgeUser *bridgeUser = [[TGBridgeUser alloc] init];
    bridgeUser->_identifier = user.uid;
    bridgeUser->_firstName = user.firstName;
    bridgeUser->_lastName = user.lastName;
    bridgeUser->_userName = user.userName;
    bridgeUser->_phoneNumber = user.phoneNumber;
    if (user.phoneNumber != nil)
        bridgeUser->_prettyPhoneNumber = [TGPhoneUtils formatPhone:user.phoneNumber forceInternational:false];
    bridgeUser->_online = user.presence.online;
    bridgeUser->_lastSeen = user.presence.lastSeen;
    bridgeUser->_photoSmall = user.photoUrlSmall;
    bridgeUser->_photoBig = user.photoUrlBig;
    bridgeUser->_kind = user.kind;
    bridgeUser->_botKind = user.botKind;
    bridgeUser->_botVersion = user.botInfoVersion;
    bridgeUser->_verified = user.isVerified;
    
    return bridgeUser;
}

@end
