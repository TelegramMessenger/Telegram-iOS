#import <Foundation/Foundation.h>

@interface MTFutureSalt : NSObject

@property (nonatomic, readonly) int32_t validSince;
@property (nonatomic, readonly) int32_t validUntil;
@property (nonatomic, readonly) int64_t salt;

- (instancetype)initWithValidSince:(int32_t)validSince validUntil:(int32_t)validUntil salt:(int64_t)salt;

@end

@interface MTFutureSaltsMessage : NSObject

@property (nonatomic, readonly) int64_t requestMessageId;
@property (nonatomic, readonly) int32_t now;
@property (nonatomic, strong, readonly) NSArray *salts;

- (instancetype)initWithRequestMessageId:(int64_t)requestMessageId now:(int32_t)now salts:(NSArray *)salts;

@end
