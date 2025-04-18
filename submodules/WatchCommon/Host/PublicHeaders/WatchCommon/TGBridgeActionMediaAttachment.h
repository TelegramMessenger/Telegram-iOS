#import <WatchCommon/TGBridgeMediaAttachment.h>

typedef NS_ENUM(NSUInteger, TGBridgeMessageAction) {
    TGBridgeMessageActionNone = 0,
    TGBridgeMessageActionChatEditTitle = 1,
    TGBridgeMessageActionChatAddMember = 2,
    TGBridgeMessageActionChatDeleteMember = 3,
    TGBridgeMessageActionCreateChat = 4,
    TGBridgeMessageActionChatEditPhoto = 5,
    TGBridgeMessageActionContactRequest = 6,
    TGBridgeMessageActionAcceptContactRequest = 7,
    TGBridgeMessageActionContactRegistered = 8,
    TGBridgeMessageActionUserChangedPhoto = 9,
    TGBridgeMessageActionEncryptedChatRequest = 10,
    TGBridgeMessageActionEncryptedChatAccept = 11,
    TGBridgeMessageActionEncryptedChatDecline = 12,
    TGBridgeMessageActionEncryptedChatMessageLifetime = 13,
    TGBridgeMessageActionEncryptedChatScreenshot = 14,
    TGBridgeMessageActionEncryptedChatMessageScreenshot = 15,
    TGBridgeMessageActionCreateBroadcastList = 16,
    TGBridgeMessageActionJoinedByLink = 17,
    TGBridgeMessageActionChannelCreated = 18,
    TGBridgeMessageActionChannelCommentsStatusChanged = 19,
    TGBridgeMessageActionChannelInviter = 20,
    TGBridgeMessageActionGroupMigratedTo = 21,
    TGBridgeMessageActionGroupDeactivated = 22,
    TGBridgeMessageActionGroupActivated = 23,
    TGBridgeMessageActionChannelMigratedFrom = 24
};

@interface TGBridgeActionMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) TGBridgeMessageAction actionType;
@property (nonatomic, strong) NSDictionary *actionData;

@end
