

#import <Foundation/Foundation.h>

#import <LegacyComponents/TGImageInfo.h>
#import <LegacyComponents/TGMessage.h>
#import <LegacyComponents/PSKeyValueCoder.h>
#import <LegacyComponents/TGDatabaseMessageDraft.h>
#import <LegacyComponents/TGChannelAdminRights.h>
#import <LegacyComponents/TGChannelBannedRights.h>

#define TGConversationKindPersistentChannel 0
#define TGConversationKindTemporaryChannel 1

#define TGChannelDisplayVariantImportant 0
#define TGChannelDisplayVariantAll 1

#define TGConversationPinnedDateBase 1600000000

typedef enum {
    TGConversationFlagPostAsChannel = (1 << 1),
    TGConversationFlagKicked = (1 << 2),
    TGConversationFlagVerified = (1 << 3),
    TGConversationFlagHasAdmins = (1 << 4),
    TGConversationFlagIsAdmin = (1 << 5),
    TGConversationFlagIsCreator = (1 << 6),
    TGConversationFlagIsChannelGroup = (1 << 7),
    TGConversationFlagIsDeactivated = (1 << 8),
    TGConversationFlagHasExplicitContent = (1 << 9),
    TGConversationFlagEverybodyCanAddMembers = (1 << 10),
    TGConversationFlagSignaturesEnabled = (1 << 11),
    TGConversationFlagPinnedMessageHidden = (1 << 12),
    TGConversationFlagIsMin = (1 << 13),
    TGConversationFlagCanNotSetUsername = (1 << 14)
} TGConversationFlags;

typedef struct {
    uint8_t key[9];
} TGConversationSortKey;

static inline int TGConversationSortKeyCompare(TGConversationSortKey lhs, TGConversationSortKey rhs) {
    return memcmp(lhs.key, rhs.key, 9);
}

static inline TGConversationSortKey TGConversationSortKeyDecode(PSKeyValueCoder *coder, const char *name) {
    TGConversationSortKey key;
    [coder decodeBytesForCKey:name value:key.key length:9];
    return key;
}

static inline void TGConversationSortKeyEncode(PSKeyValueCoder *coder, const char *name, TGConversationSortKey key) {
    [coder encodeBytes:key.key length:9 forCKey:name];
}

static inline TGConversationSortKey TGConversationSortKeyMake(uint8_t kind, int32_t timestamp, int32_t mid) {
    TGConversationSortKey key;
    key.key[0] = kind;
    
    timestamp = NSSwapInt(timestamp);
    memcpy(key.key + 1, &timestamp, 4);
    
    mid = NSSwapInt(mid);
    memcpy(key.key + 1 + 4, &mid, 4);
    
    return key;
}

static inline TGConversationSortKey TGConversationSortKeyLowerBound(uint8_t kind) {
    return TGConversationSortKeyMake(kind, 0, 0);
}

static inline TGConversationSortKey TGConversationSortKeyUpperBound(uint8_t kind) {
    return TGConversationSortKeyMake(kind, INT32_MAX, INT32_MAX);
}

static inline uint8_t TGConversationSortKeyKind(TGConversationSortKey key) {
    return key.key[0];
}

static inline TGConversationSortKey TGConversationSortKeyUpdateKind(TGConversationSortKey key, uint8_t kind) {
    TGConversationSortKey updatedKey;
    memcpy(updatedKey.key, key.key, 8);
    updatedKey.key[0] = kind;
    return updatedKey;
}

static inline int32_t TGConversationSortKeyTimestamp(TGConversationSortKey key) {
    int32_t timestamp = 0;
    memcpy(&timestamp, key.key + 1, 4);
    return NSSwapInt(timestamp);
}

static inline int32_t TGConversationSortKeyMid(TGConversationSortKey key) {
    int32_t mid = 0;
    memcpy(&mid, key.key + 1 + 4, 4);
    return NSSwapInt(mid);
}

static inline NSData *TGConversationSortKeyData(TGConversationSortKey key) {
    return [NSData dataWithBytes:key.key length:9];
}

static inline TGConversationSortKey TGConversationSortKeyFromData(NSData *data) {
    TGConversationSortKey key;
    memcpy(key.key, data.bytes, 9);
    return key;
}

typedef enum {
    TGChannelRoleMember,
    TGChannelRoleCreator,
    TGChannelRoleModerator,
    TGChannelRolePublisher
} TGChannelRole;

@interface TGConversationParticipantsData : NSObject <NSCopying>
{
    NSData *_serializedData;
}

@property (nonatomic, strong) NSArray *chatParticipantUids;
@property (nonatomic, strong) NSDictionary *chatInvitedBy;
@property (nonatomic, strong) NSDictionary *chatInvitedDates;
@property (nonatomic, strong) NSSet *chatAdminUids;

@property (nonatomic, strong) NSArray *chatParticipantSecretChatPeerIds;
@property (nonatomic, strong) NSArray *chatParticipantChatPeerIds;

@property (nonatomic) int chatAdminId;

@property (nonatomic) int version;

@property (nonatomic, strong) NSString *exportedChatInviteString;

+ (TGConversationParticipantsData *)deserializeData:(NSData *)data;
- (NSData *)serializedData;

- (void)addParticipantWithId:(int32_t)uid invitedBy:(int32_t)invitedBy date:(int32_t)date;
- (void)removeParticipantWithId:(int32_t)uid;

- (void)addSecretChatPeerWithId:(int64_t)peerId;
- (void)removeSecretChatPeerWithId:(int64_t)peerId;
- (void)addChatPeerWithId:(int64_t)peerId;
- (void)removeChatPeerWithId:(int64_t)peerId;

@end

@interface TGEncryptedConversationData : NSObject <NSCopying>

@property (nonatomic) int64_t encryptedConversationId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int64_t keyFingerprint;
@property (nonatomic) int32_t handshakeState;
@property (nonatomic) int64_t currentRekeyExchangeId;
@property (nonatomic) bool currentRekeyIsInitiatedByLocalClient;
@property (nonatomic) NSData *currentRekeyNumber;
@property (nonatomic) NSData *currentRekeyKey;
@property (nonatomic) int64_t currentRekeyKeyId;

@end

@interface TGConversation : NSObject <NSCopying, PSCoding>

@property (nonatomic) int64_t conversationId;
@property (nonatomic) int64_t accessHash;

@property (nonatomic) int32_t displayVariant;
@property (nonatomic) uint8_t kind;

@property (nonatomic, readonly) TGConversationSortKey databaseSortKey;
@property (nonatomic) TGConversationSortKey variantSortKey;
@property (nonatomic) TGConversationSortKey importantSortKey;
@property (nonatomic) TGConversationSortKey unimportantSortKey;
@property (nonatomic) int32_t pts;

@property (nonatomic) int32_t maxReadMessageId;
@property (nonatomic) int32_t maxOutgoingReadMessageId;
@property (nonatomic) int32_t maxKnownMessageId;
@property (nonatomic) int32_t maxLocallyReadMessageId;

@property (nonatomic) int32_t maxReadDate;
@property (nonatomic) int32_t maxOutgoingReadDate;

@property (nonatomic, strong) NSString *about;
@property (nonatomic, strong) NSString *username;

@property (nonatomic) id additionalProperties;

@property (nonatomic) bool outgoing;
@property (nonatomic) bool unread;
@property (nonatomic) bool deliveryError;
@property (nonatomic) TGMessageDeliveryState deliveryState;
@property (nonatomic) int32_t messageDate;
@property (nonatomic) int32_t minMessageDate;
@property (nonatomic) int32_t pinnedDate;
@property (nonatomic) int fromUid;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSArray *media;
@property (nonatomic, strong) NSData *mediaData;
@property (nonatomic) int64_t messageFlags;

@property (nonatomic) bool unreadMark;

@property (nonatomic) int unreadCount;
@property (nonatomic) int serviceUnreadCount;

@property (nonatomic, strong) NSString *chatTitle;
@property (nonatomic, strong) NSString *chatPhotoSmall;
@property (nonatomic, strong) NSString *chatPhotoMedium;
@property (nonatomic, strong) NSString *chatPhotoBig;
@property (nonatomic) NSData *chatPhotoFileReferenceSmall;
@property (nonatomic) NSData *chatPhotoFileReferenceBig;

@property (nonatomic, strong, readonly) NSString *chatPhotoFullSmall;
@property (nonatomic, strong, readonly) NSString *chatPhotoFullBig;

@property (nonatomic) int chatParticipantCount;

@property (nonatomic) bool leftChat;
@property (nonatomic) bool kickedFromChat;

@property (nonatomic) TGChannelRole channelRole;

@property (nonatomic) int chatCreationDate;
@property (nonatomic) int chatVersion;
@property (nonatomic) bool chatIsAdmin;
@property (nonatomic) bool channelIsReadOnly;
@property (nonatomic) bool isVerified;
@property (nonatomic) bool hasExplicitContent;
@property (nonatomic, strong) NSString *restrictionReason;

@property (nonatomic, strong) TGConversationParticipantsData *chatParticipants;

@property (nonatomic, strong) NSDictionary *dialogListData;

@property (nonatomic) bool isChat;
@property (nonatomic) bool isDeleted;
@property (nonatomic) bool isBroadcast;
@property (nonatomic) bool isChannel;

@property (nonatomic) bool postAsChannel;
@property (nonatomic) bool hasAdmins;
@property (nonatomic) bool isAdmin;
@property (nonatomic) bool isCreator;
@property (nonatomic) bool isChannelGroup;
@property (nonatomic) bool everybodyCanAddMembers;
@property (nonatomic) bool signaturesEnabled;

@property (nonatomic) bool isDeactivated;
@property (nonatomic) bool isMigrated;
@property (nonatomic) int32_t migratedToChannelId;
@property (nonatomic) int64_t migratedToChannelAccessHash;

@property (nonatomic) int32_t pinnedMessageId;
@property (nonatomic) bool pinnedMessageHidden;

@property (nonatomic) int64_t flags;

@property (nonatomic) bool isMin;
@property (nonatomic) bool canNotSetUsername;

@property (nonatomic, strong) TGEncryptedConversationData *encryptedData;

@property (nonatomic, strong, readonly) TGDatabaseMessageDraft *draft;
@property (nonatomic) int32_t unreadMentionCount;

@property (nonatomic, readonly) int32_t date;
@property (nonatomic, readonly) int32_t unpinnedDate;

@property (nonatomic, strong) TGChannelAdminRights *channelAdminRights;
@property (nonatomic, strong) TGChannelBannedRights *channelBannedRights;

@property (nonatomic, strong) NSNumber *feedId;
- (int64_t)conversationFeedId;

- (id)initWithConversationId:(int64_t)conversationId unreadCount:(int)unreadCount serviceUnreadCount:(int)serviceUnreadCount;

- (void)mergeMessage:(TGMessage *)message;
- (void)mergeEmptyMessage;

- (BOOL)isEqualToConversation:(TGConversation *)other;
- (BOOL)isEqualToConversationIgnoringMessage:(TGConversation *)other;

- (NSData *)serializeChatPhoto;
- (void)deserializeChatPhoto:(NSData *)data;

- (bool)isEncrypted;

- (void)mergeConversation:(TGConversation *)conversation;
- (void)mergeChannel:(TGConversation *)channel;
- (void)mergeDraft:(TGDatabaseMessageDraft *)draft;

- (bool)currentUserCanSendMessages;

+ (NSString *)chatTitleForDecoder:(PSKeyValueCoder *)coder;

- (bool)isMessageUnread:(TGMessage *)message;
- (bool)isMessageUnread:(int32_t)messageId date:(int32_t)messageDate outgoing:(bool)outgoing;

- (bool)pinnedToTop;

- (int32_t)searchMessageId;

@end
