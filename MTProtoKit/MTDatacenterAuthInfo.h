#import <Foundation/Foundation.h>

@interface MTDatacenterAuthKey: NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *authKey;
@property (nonatomic, readonly) int64_t authKeyId;

- (instancetype)initWithAuthKey:(NSData *)tempAuthKey authKeyId:(int64_t)authKeyId;

@end

@interface MTDatacenterAuthInfo : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *authKey;
@property (nonatomic, readonly) int64_t authKeyId;
@property (nonatomic, strong, readonly) NSArray *saltSet;
@property (nonatomic, strong, readonly) NSDictionary *authKeyAttributes;
@property (nonatomic, strong, readonly) MTDatacenterAuthKey *tempAuthKey;

- (instancetype)initWithAuthKey:(NSData *)authKey authKeyId:(int64_t)authKeyId saltSet:(NSArray *)saltSet authKeyAttributes:(NSDictionary *)authKeyAttributes tempAuthKey:(MTDatacenterAuthKey *)tempAuthKey;

- (int64_t)authSaltForMessageId:(int64_t)messageId;
- (MTDatacenterAuthInfo *)mergeSaltSet:(NSArray *)updatedSaltSet forTimestamp:(NSTimeInterval)timestamp;

- (MTDatacenterAuthInfo *)withUpdatedTempAuthKey:(MTDatacenterAuthKey *)tempAuthKey;

@end
