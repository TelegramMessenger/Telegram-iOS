#import <WatchCommonWatch/TGBridgeCommon.h>

@class TGBridgeBotInfo;
@class TGBridgeUserChange;

typedef NS_ENUM(NSUInteger, TGBridgeUserKind) {
    TGBridgeUserKindGeneric,
    TGBridgeUserKindBot,
    TGBridgeUserKindSmartBot
};

typedef NS_ENUM(NSUInteger, TGBridgeBotKind) {
    TGBridgeBotKindGeneric,
    TGBridgeBotKindPrivate
};

@interface TGBridgeUser : NSObject <NSCoding, NSCopying>

@property (nonatomic) int64_t identifier;
@property (nonatomic, strong) NSString *firstName;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *prettyPhoneNumber;
@property (nonatomic, strong) NSString *about;

@property (nonatomic) bool online;
@property (nonatomic) NSTimeInterval lastSeen;

@property (nonatomic, strong) NSString *photoSmall;
@property (nonatomic, strong) NSString *photoBig;

@property (nonatomic) TGBridgeUserKind kind;
@property (nonatomic) TGBridgeBotKind botKind;
@property (nonatomic) int32_t botVersion;

@property (nonatomic) bool verified;

@property (nonatomic) int32_t userVersion;

- (NSString *)displayName;
- (TGBridgeUserChange *)changeFromUser:(TGBridgeUser *)user;
- (TGBridgeUser *)userByApplyingChange:(TGBridgeUserChange *)change;

- (bool)isBot;

@end


@interface TGBridgeUserChange : NSObject <NSCoding>

@property (nonatomic, readonly) int32_t userIdentifier;
@property (nonatomic, readonly) NSDictionary *fields;

- (instancetype)initWithUserIdentifier:(int32_t)userIdentifier fields:(NSDictionary *)fields;

@end

extern NSString *const TGBridgeUsersDictionaryKey;
