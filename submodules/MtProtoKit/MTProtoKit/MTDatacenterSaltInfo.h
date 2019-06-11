

#import <Foundation/Foundation.h>

@interface MTDatacenterSaltInfo : NSObject <NSCoding>

@property (nonatomic, readonly) int64_t salt;
@property (nonatomic, readonly) int64_t firstValidMessageId;
@property (nonatomic, readonly) int64_t lastValidMessageId;

- (instancetype)initWithSalt:(int64_t)salt firstValidMessageId:(int64_t)firstValidMessageId lastValidMessageId:(int64_t)lastValidMessageId;

- (int64_t)validMessageCountAfterId:(int64_t)messageId;
- (bool)isValidFutureSaltForMessageId:(int64_t)messageId;

@end
