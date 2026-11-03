#import <Foundation/Foundation.h>

@interface MTDestroySessionResponseMessage : NSObject

@end

@interface MTDestroySessionResponseOkMessage : MTDestroySessionResponseMessage

@property (nonatomic, readonly) int64_t sessionId;

- (instancetype)initWithSessionId:(int64_t)sessionId;

@end

@interface MTDestroySessionResponseNoneMessage : MTDestroySessionResponseMessage

@property (nonatomic, readonly) int64_t sessionId;

- (instancetype)initWithSessionId:(int64_t)sessionId;

@end

@interface MTDestroySessionMultipleResponseMessage : MTDestroySessionResponseMessage

@property (nonatomic, strong, readonly) NSData *responsesData;

- (instancetype)initWithResponses:(NSData *)responsesData;

@end
