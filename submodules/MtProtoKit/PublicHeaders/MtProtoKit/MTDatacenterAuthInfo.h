#import <Foundation/Foundation.h>

@interface MTDatacenterAuthKey: NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *authKey;
@property (nonatomic, readonly) int64_t authKeyId;
@property (nonatomic, readonly) int32_t validUntilTimestamp;
@property (nonatomic, readonly) bool notBound;

- (instancetype)initWithAuthKey:(NSData *)tempAuthKey authKeyId:(int64_t)authKeyId validUntilTimestamp:(int32_t)validUntilTimestamp notBound:(bool)notBound;

@end

typedef NS_ENUM(int64_t, MTDatacenterAuthInfoSelector) {
    MTDatacenterAuthInfoSelectorPersistent = 0,
    MTDatacenterAuthInfoSelectorEphemeralMain,
    MTDatacenterAuthInfoSelectorEphemeralMedia
};

@interface MTDatacenterAuthInfo : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *authKey;
@property (nonatomic, readonly) int64_t authKeyId;
@property (nonatomic, readonly) int32_t validUntilTimestamp;
@property (nonatomic, strong, readonly) NSArray *saltSet;
@property (nonatomic, strong, readonly) NSDictionary *authKeyAttributes;

- (instancetype)initWithAuthKey:(NSData *)authKey authKeyId:(int64_t)authKeyId validUntilTimestamp:(int32_t)validUntilTimestamp saltSet:(NSArray *)saltSet authKeyAttributes:(NSDictionary *)authKeyAttributes;

- (int64_t)authSaltForMessageId:(int64_t)messageId;
- (MTDatacenterAuthInfo *)mergeSaltSet:(NSArray *)updatedSaltSet forTimestamp:(NSTimeInterval)timestamp;

- (MTDatacenterAuthInfo *)withUpdatedAuthKeyAttributes:(NSDictionary *)authKeyAttributes;

@end
