

#import <LegacyComponents/TGMediaAttachment.h>

#define TGActionMediaAttachmentType 0x1167E28B

typedef enum {
    TGMessageActionNone = 0,
    TGMessageActionChatEditTitle = 1,
    TGMessageActionChatAddMember = 2,
    TGMessageActionChatDeleteMember = 3,
    TGMessageActionCreateChat = 4,
    TGMessageActionChatEditPhoto = 5,
    TGMessageActionContactRequest = 6,
    TGMessageActionAcceptContactRequest = 7,
    TGMessageActionContactRegistered = 8,
    TGMessageActionUserChangedPhoto = 9,
    TGMessageActionEncryptedChatRequest = 10,
    TGMessageActionEncryptedChatAccept = 11,
    TGMessageActionEncryptedChatDecline = 12,
    TGMessageActionEncryptedChatMessageLifetime = 13,
    TGMessageActionEncryptedChatScreenshot = 14,
    TGMessageActionEncryptedChatMessageScreenshot = 15,
    TGMessageActionCreateBroadcastList = 16,
    TGMessageActionJoinedByLink = 17,
    TGMessageActionChannelCreated = 18,
    TGMessageActionChannelCommentsStatusChanged = 19,
    TGMessageActionChannelInviter = 20,
    TGMessageActionGroupMigratedTo = 21,
    TGMessageActionGroupDeactivated = 22,
    TGMessageActionGroupActivated = 23,
    TGMessageActionChannelMigratedFrom = 24,
    TGMessageActionPinnedMessage = 25,
    TGMessageActionClearChat = 26,
    TGMessageActionGameScore = 27,
    TGMessageActionPhoneCall = 28,
    TGMessageActionPaymentSent = 29,
    TGMessageActionText = 30,
    TGMessageActionGroupCall = 31,
    TGMessageActionBotAllowed = 32,
    TGMessageActionSecureValuesSent = 33,
    TGMessageActionCustom = 1000
} TGMessageAction;

@interface TGActionMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser>

@property (nonatomic) TGMessageAction actionType;
@property (nonatomic, strong) NSDictionary *actionData;

@end
