

#import <Foundation/Foundation.h>

#import <LegacyComponents/TGActionMediaAttachment.h>
#import <LegacyComponents/TGMediaAttachment.h>
#import <LegacyComponents/TGImageMediaAttachment.h>
#import <LegacyComponents/TGLocationMediaAttachment.h>
#import <LegacyComponents/TGLocalMessageMetaMediaAttachment.h>
#import <LegacyComponents/TGVideoMediaAttachment.h>
#import <LegacyComponents/TGContactMediaAttachment.h>
#import <LegacyComponents/TGForwardedMessageMediaAttachment.h>
#import <LegacyComponents/TGUnsupportedMediaAttachment.h>
#import <LegacyComponents/TGDocumentMediaAttachment.h>
#import <LegacyComponents/TGAudioMediaAttachment.h>
#import <LegacyComponents/TGReplyMessageMediaAttachment.h>
#import <LegacyComponents/TGWebPageMediaAttachment.h>
#import <LegacyComponents/TGReplyMarkupAttachment.h>
#import <LegacyComponents/TGMessageEntitiesAttachment.h>
#import <LegacyComponents/TGBotContextResultAttachment.h>
#import <LegacyComponents/TGViaUserAttachment.h>
#import <LegacyComponents/TGGameMediaAttachment.h>
#import <LegacyComponents/TGInvoiceMediaAttachment.h>
#import <LegacyComponents/TGAuthorSignatureMediaAttachment.h>

#import <LegacyComponents/TGMessageViewCountContentProperty.h>

#import <LegacyComponents/TGBotReplyMarkup.h>

#import <LegacyComponents/PSCoding.h>

#import <LegacyComponents/TGMessageHole.h>
#import <LegacyComponents/TGMessageGroup.h>

typedef enum {
    TGMessageDeliveryStateDelivered = 0,
    TGMessageDeliveryStatePending = 1,
    TGMessageDeliveryStateFailed = 2
} TGMessageDeliveryState;

#define TGMessageLocalMidBaseline 800000000
#define TGMessageLocalMidEditBaseline 900000000

typedef struct {
    uint8_t key[8 + 1 + 4 + 4];
} TGMessageSortKey;

typedef struct {
    uint8_t key[8 + 4 + 4 + 1];
} TGMessageTransparentSortKey;

#define TGMessageSpaceUnimportant 0
#define TGMessageSpaceImportant 1
#define TGMessageSpaceUnimportantGroup 126
#define TGMessageSpaceHole 127

static inline TGMessageSortKey TGMessageSortKeyMake(int64_t peerId, uint8_t space, int32_t timestamp, int32_t mid) {
    TGMessageSortKey key;
    memcpy(key.key, &peerId, 8);
    key.key[8] = space;
    timestamp = NSSwapInt(timestamp);
    memcpy(key.key + 8 + 1, &timestamp, 4);
    mid = NSSwapInt(mid);
    memcpy(key.key + 8 + 1 + 4, &mid, 4);
    return key;
}

static inline TGMessageTransparentSortKey TGMessageTransparentSortKeyMake(int64_t peerId, int32_t timestamp, int32_t mid, uint8_t space) {
    TGMessageTransparentSortKey key;
    memcpy(key.key, &peerId, 8);
    timestamp = NSSwapInt(timestamp);
    memcpy(key.key + 8, &timestamp, 4);
    mid = NSSwapInt(mid);
    memcpy(key.key + 8 + 4, &mid, 4);
    key.key[8 + 4 + 4] = space;
    return key;
}

static inline TGMessageTransparentSortKey TGMessageTransparentSortKeyLowerBound(int64_t peerId) {
    return TGMessageTransparentSortKeyMake(peerId, 0, 0, 0);
}

static inline TGMessageTransparentSortKey TGMessageTransparentSortKeyUpperBound(int64_t peerId) {
    return TGMessageTransparentSortKeyMake(peerId, INT32_MAX, INT32_MAX, 127);
}

static inline TGMessageSortKey TGMessageSortKeyLowerBound(int64_t peerId, uint8_t space) {
    return TGMessageSortKeyMake(peerId, space, 0, 0);
}

static inline TGMessageSortKey TGMessageSortKeyUpperBound(int64_t peerId, uint8_t space) {
    return TGMessageSortKeyMake(peerId, space, INT32_MAX, INT32_MAX);
}

static inline TGMessageSortKey TGMessageSortKeyFromData(NSData *data) {
    TGMessageSortKey key;
    memcpy(key.key, data.bytes, 8 + 1 + 4 + 4);
    return key;
}

static inline NSData *TGMessageSortKeyData(TGMessageSortKey key) {
    return [NSData dataWithBytes:key.key length: 8 + 1 + 4 + 4];
}

static inline NSData *TGMessageTransparentSortKeyData(TGMessageTransparentSortKey key) {
    return [NSData dataWithBytes:key.key length: 8 + 4 + 4 + 1];
}

static inline TGMessageTransparentSortKey TGMessageTransparentSortKeyFromData(NSData *data) {
    TGMessageTransparentSortKey key;
    memcpy(key.key, data.bytes, 8 + 4 + 4 + 1);
    return key;
}

static inline int TGMessageSortKeyCompare(TGMessageSortKey lhs, TGMessageSortKey rhs) {
    return memcmp(lhs.key, rhs.key, 8 + 1 + 4 + 4);
}

static inline int TGMessageTransparentSortKeyCompare(TGMessageTransparentSortKey lhs, TGMessageTransparentSortKey rhs) {
    return memcmp(lhs.key, rhs.key, 8 + 4 + 4 + 1);
}

static inline int64_t TGMessageSortKeyPeerId(TGMessageSortKey key) {
    int64_t peerId = 0;
    memcpy(&peerId, key.key, 8);
    return peerId;
}

static inline int64_t TGMessageTransparentSortKeyPeerId(TGMessageTransparentSortKey key) {
    int64_t peerId = 0;
    memcpy(&peerId, key.key, 8);
    return peerId;
}

static inline uint8_t TGMessageSortKeySpace(TGMessageSortKey key) {
    return key.key[8];
}

static inline uint8_t TGMessageTransparentSortKeySpace(TGMessageTransparentSortKey key) {
    return key.key[8 + 4 + 4];
}

static inline int32_t TGMessageSortKeyTimestamp(TGMessageSortKey key) {
    int32_t timestamp = 0;
    memcpy(&timestamp, key.key + 8 + 1, 4);
    return NSSwapInt(timestamp);
}

static inline int32_t TGMessageTransparentSortKeyTimestamp(TGMessageTransparentSortKey key) {
    int32_t timestamp = 0;
    memcpy(&timestamp, key.key + 8, 4);
    return NSSwapInt(timestamp);
}

static inline int32_t TGMessageSortKeyMid(TGMessageSortKey key) {
    int32_t mid = 0;
    memcpy(&mid, key.key + 8 + 1 + 4, 4);
    return NSSwapInt(mid);
}

static inline int32_t TGMessageTransparentSortKeyMid(TGMessageTransparentSortKey key) {
    int32_t mid = 0;
    memcpy(&mid, key.key + 8 + 4, 4);
    return NSSwapInt(mid);
}

static inline NSData *TGTaggedMessageSortKeyData(int32_t tag, TGMessageSortKey key) {
    uint8_t data[4 + 8 + 1 + 4 + 4];
    memcpy(data, &tag, 4);
    memcpy(data + 4, key.key, 8 + 1 + 4 + 4);
    return [[NSData alloc] initWithBytes:data length:4 + 8 + 1 + 4 + 4];
}

static inline TGMessageSortKey TGTaggedMessageSortKeyExtract(NSData *data, int32_t *outTag) {
    if (outTag != NULL) {
        [data getBytes:(void *)outTag range:NSMakeRange(0, 4)];
    }
    
    TGMessageSortKey sortKey;
    [data getBytes:sortKey.key range:NSMakeRange(4, 17)];
    return sortKey;
}

@interface TGMessage : NSObject <NSCopying, PSCoding>

@property (nonatomic) int mid;

@property (nonatomic) TGMessageSortKey sortKey;
@property (nonatomic, readonly) TGMessageTransparentSortKey transparentSortKey;

@property (nonatomic) int32_t pts;

//@property (nonatomic, readonly) bool unread;
@property (nonatomic) bool hintUnread;
@property (nonatomic) bool outgoing;
@property (nonatomic) TGMessageDeliveryState deliveryState;
@property (nonatomic) int64_t fromUid;
@property (nonatomic) int64_t toUid;
@property (nonatomic) int64_t cid;
@property (nonatomic) int64_t groupedId;
@property (nonatomic, copy) NSString *text;
@property (nonatomic) NSTimeInterval date;
@property (nonatomic) NSTimeInterval editDate;
@property (nonatomic, strong) NSArray *mediaAttachments;

@property (nonatomic) int32_t realDate;
@property (nonatomic) int64_t randomId;

@property (nonatomic, readonly) int64_t forwardPeerId;

@property (nonatomic) bool containsMention;
@property (nonatomic) bool containsUnseenMention;

@property (nonatomic, strong) TGActionMediaAttachment *actionInfo;
@property (nonatomic, readonly) TGLocationMediaAttachment *locationAttachment;

@property (nonatomic, strong) NSArray *textCheckingResults;

@property (nonatomic) int32_t messageLifetime;
@property (nonatomic) int64_t flags;
@property (nonatomic) int32_t seqIn;
@property (nonatomic) int32_t seqOut;

@property (nonatomic) bool isBroadcast;
@property (nonatomic) NSUInteger layer;

@property (nonatomic, strong) TGBotReplyMarkup *replyMarkup;
@property (nonatomic) bool hideReplyMarkup;
@property (nonatomic) bool forceReply;

@property (nonatomic) bool isSilent;
@property (nonatomic) bool isEdited;

@property (nonatomic, strong) TGMessageViewCountContentProperty *viewCount;

@property (nonatomic, strong) NSArray *entities;
@property (nonatomic, strong, readonly) NSString *authorSignature;
@property (nonatomic, strong, readonly) NSString *forwardAuthorSignature;

@property (nonatomic, strong) NSDictionary *contentProperties;

@property (nonatomic, strong) TGMessageHole *hole;
@property (nonatomic, strong) TGMessageGroup *group;

- (NSArray *)effectiveTextAndEntities;

- (bool)local;

+ (void)registerMediaAttachmentParser:(int)type parser:(id<TGMediaAttachmentParser>)parser;
+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands entities:(NSArray *)entities;
+ (NSArray *)entitiesForMarkedUpText:(NSString *)text resultingText:(__autoreleasing NSString **)resultingText;
+ (NSArray *)textCheckingResultsForText:(NSString *)text highlightMentionsAndTags:(bool)highlightMentionsAndTags highlightCommands:(bool)highlightCommands entities:(NSArray *)entities highlightAsExternalMentionsAndHashtags:(bool)highlightAsExternalMentionsAndHashtags;

- (NSData *)serializeMediaAttachments:(bool)includeMeta;
+ (NSData *)serializeMediaAttachments:(bool)includeMeta attachments:(NSArray *)attachments;
+ (NSData *)serializeAttachment:(TGMediaAttachment *)attachment;
+ (NSArray *)parseMediaAttachments:(NSData *)data;
+ (NSUInteger)layerFromFlags:(int64_t)flags;
+ (bool)containsUnseenMention:(int64_t)flags;

- (NSData *)serializeContentProperties;
+ (NSData *)serializeContentProperties:(NSDictionary *)contentProperties;
+ (NSDictionary *)parseContentProperties:(NSData *)data;

- (void)removeReplyAndMarkup;

- (void)filterOutExpiredMedia;
- (bool)hasExpiredMedia;
- (bool)hasUnreadContent;

- (int32_t)actualDate;
- (NSString *)caption;

@end

@interface TGMediaId : NSObject <NSCopying>

@property (nonatomic, readonly) uint8_t type;
@property (nonatomic, readonly) int64_t itemId;

- (id)initWithType:(uint8_t)type itemId:(int64_t)itemId;

@end

@interface NSTextCheckingResult (TGMessage)

- (bool)isTelegramHiddenLink;

@end

@interface TGMessageIndex : NSObject

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;

+ (instancetype)indexWithPeerId:(int64_t)peerId messageId:(int32_t)messageId;

@end
