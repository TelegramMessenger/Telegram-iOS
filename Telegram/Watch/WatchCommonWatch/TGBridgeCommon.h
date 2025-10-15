#import <Foundation/Foundation.h>

extern NSString *const TGBridgeIncomingFileTypeKey;
extern NSString *const TGBridgeIncomingFileIdentifierKey;
extern NSString *const TGBridgeIncomingFileRandomIdKey;
extern NSString *const TGBridgeIncomingFilePeerIdKey;
extern NSString *const TGBridgeIncomingFileReplyToMidKey;

extern NSString *const TGBridgeIncomingFileTypeAudio;
extern NSString *const TGBridgeIncomingFileTypeImage;

@interface TGBridgeSubscription : NSObject <NSCoding>

@property (nonatomic, readonly) int64_t identifier;
@property (nonatomic, readonly, strong) NSString *name;

@property (nonatomic, readonly) bool isOneTime;
@property (nonatomic, readonly) bool renewable;
@property (nonatomic, readonly) bool dropPreviouslyQueued;
@property (nonatomic, readonly) bool synchronous;

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder;
- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder;

+ (NSString *)subscriptionName;

@end


@interface TGBridgeDisposal : NSObject <NSCoding>

@property (nonatomic, readonly) int64_t identifier;

- (instancetype)initWithIdentifier:(int64_t)identifier;

@end


@interface TGBridgeFile : NSObject <NSCoding>

@property (nonatomic, readonly, strong) NSData *data;
@property (nonatomic, readonly, strong) NSDictionary *metadata;

- (instancetype)initWithData:(NSData *)data metadata:(NSDictionary *)metadata;

@end


@interface TGBridgePing : NSObject <NSCoding>

@property (nonatomic, readonly) int32_t sessionId;

- (instancetype)initWithSessionId:(int32_t)sessionId;

@end


@interface TGBridgeSubscriptionListRequest : NSObject <NSCoding>

@property (nonatomic, readonly) int32_t sessionId;

- (instancetype)initWithSessionId:(int32_t)sessionId;

@end


@interface TGBridgeSubscriptionList : NSObject <NSCoding>

@property (nonatomic, readonly, strong) NSArray *subscriptions;

- (instancetype)initWithArray:(NSArray *)array;

@end


typedef NS_ENUM(int32_t, TGBridgeResponseType) {
    TGBridgeResponseTypeUndefined,
    TGBridgeResponseTypeNext,
    TGBridgeResponseTypeFailed,
    TGBridgeResponseTypeCompleted
};

@interface TGBridgeResponse : NSObject <NSCoding>

@property (nonatomic, readonly) int64_t subscriptionIdentifier;

@property (nonatomic, readonly) TGBridgeResponseType type;
@property (nonatomic, readonly, strong) id next;
@property (nonatomic, readonly, strong) NSString *error;

+ (TGBridgeResponse *)single:(id)next forSubscription:(TGBridgeSubscription *)subscription;
+ (TGBridgeResponse *)fail:(id)error forSubscription:(TGBridgeSubscription *)subscription;
+ (TGBridgeResponse *)completeForSubscription:(TGBridgeSubscription *)subscription;

@end
