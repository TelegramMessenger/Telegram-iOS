#import <Foundation/Foundation.h>

@interface MTNewSessionCreatedMessage : NSObject

@property (nonatomic, readonly) int64_t firstMessageId;
@property (nonatomic, readonly) int64_t uniqueId;
@property (nonatomic, readonly) int64_t serverSalt;

- (instancetype)initWithFirstMessageId:(int64_t)firstMessageId uniqueId:(int64_t)uniqueId serverSalt:(int64_t)serverSalt;

@end
