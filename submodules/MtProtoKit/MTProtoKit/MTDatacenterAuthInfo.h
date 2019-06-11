#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MTDatacenterAuthTempKeyType) {
    MTDatacenterAuthTempKeyTypeMain,
    MTDatacenterAuthTempKeyTypeMedia
};

@interface MTDatacenterAuthKey: NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *authKey;
@property (nonatomic, readonly) int64_t authKeyId;
@property (nonatomic, readonly) bool notBound;

- (instancetype)initWithAuthKey:(NSData *)tempAuthKey authKeyId:(int64_t)authKeyId notBound:(bool)notBound;

@end

@interface MTDatacenterAuthInfo : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *authKey;
@property (nonatomic, readonly) int64_t authKeyId;
@property (nonatomic, strong, readonly) NSArray *saltSet;
@property (nonatomic, strong, readonly) NSDictionary *authKeyAttributes;
@property (nonatomic, strong, readonly) MTDatacenterAuthKey *mainTempAuthKey;
@property (nonatomic, strong, readonly) MTDatacenterAuthKey *mediaTempAuthKey;

@property (nonatomic, strong, readonly) MTDatacenterAuthKey *persistentAuthKey;

- (instancetype)initWithAuthKey:(NSData *)authKey authKeyId:(int64_t)authKeyId saltSet:(NSArray *)saltSet authKeyAttributes:(NSDictionary *)authKeyAttributes mainTempAuthKey:(MTDatacenterAuthKey *)mainTempAuthKey mediaTempAuthKey:(MTDatacenterAuthKey *)mediaTempAuthKey;

- (int64_t)authSaltForMessageId:(int64_t)messageId;
- (MTDatacenterAuthInfo *)mergeSaltSet:(NSArray *)updatedSaltSet forTimestamp:(NSTimeInterval)timestamp;

- (MTDatacenterAuthInfo *)withUpdatedAuthKeyAttributes:(NSDictionary *)authKeyAttributes;
- (MTDatacenterAuthKey *)tempAuthKeyWithType:(MTDatacenterAuthTempKeyType)type;
- (MTDatacenterAuthInfo *)withUpdatedTempAuthKeyWithType:(MTDatacenterAuthTempKeyType)type key:(MTDatacenterAuthKey *)key;

@end
