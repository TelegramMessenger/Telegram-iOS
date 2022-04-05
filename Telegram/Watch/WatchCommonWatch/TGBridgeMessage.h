#import <WatchCommonWatch/TGBridgeCommon.h>
#import <WatchCommonWatch/TGBridgeImageMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeVideoMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeAudioMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeDocumentMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeLocationMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeContactMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeActionMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeReplyMessageMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeForwardedMessageMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeWebPageMediaAttachment.h>
#import <WatchCommonWatch/TGBridgeMessageEntitiesAttachment.h>
#import <WatchCommonWatch/TGBridgeUnsupportedMediaAttachment.h>

typedef enum {
    TGBridgeTextCheckingResultTypeUndefined,
    TGBridgeTextCheckingResultTypeBold,
    TGBridgeTextCheckingResultTypeItalic,
    TGBridgeTextCheckingResultTypeCode,
    TGBridgeTextCheckingResultTypePre
} TGBridgeTextCheckingResultType;

@interface TGBridgeTextCheckingResult : NSObject

@property (nonatomic, assign) TGBridgeTextCheckingResultType type;
@property (nonatomic, assign) NSRange range;

@end


typedef NS_ENUM(NSUInteger, TGBridgeMessageDeliveryState) {
    TGBridgeMessageDeliveryStateDelivered = 0,
    TGBridgeMessageDeliveryStatePending = 1,
    TGBridgeMessageDeliveryStateFailed = 2
};

@interface TGBridgeMessage : NSObject <NSCoding>

@property (nonatomic) int32_t identifier;
@property (nonatomic) NSTimeInterval date;
@property (nonatomic) int64_t randomId;
@property (nonatomic) bool unread;
@property (nonatomic) bool deliveryError;
@property (nonatomic) TGBridgeMessageDeliveryState deliveryState;
@property (nonatomic) bool outgoing;
@property (nonatomic) int64_t fromUid;
@property (nonatomic) int64_t toUid;
@property (nonatomic) int64_t cid;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSArray *media;
@property (nonatomic) bool forceReply;

- (NSArray<NSNumber *> *)involvedUserIds;
- (NSArray *)textCheckingResults;

+ (instancetype)temporaryNewMessageForText:(NSString *)text userId:(int32_t)userId;
+ (instancetype)temporaryNewMessageForText:(NSString *)text userId:(int32_t)userId replyToMessage:(TGBridgeMessage *)replyToMessage;
+ (instancetype)temporaryNewMessageForSticker:(TGBridgeDocumentMediaAttachment *)sticker userId:(int32_t)userId;
+ (instancetype)temporaryNewMessageForLocation:(TGBridgeLocationMediaAttachment *)location userId:(int32_t)userId;
+ (instancetype)temporaryNewMessageForAudioWithDuration:(int32_t)duration userId:(int32_t)userId localAudioId:(int64_t)localAudioId;

@end

extern NSString *const TGBridgeMessageKey;
extern NSString *const TGBridgeMessagesArrayKey;
