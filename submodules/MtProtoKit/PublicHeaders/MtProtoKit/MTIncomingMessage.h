

#import <Foundation/Foundation.h>

@interface MTIncomingMessage : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t seqNo;
@property (nonatomic, readonly) int64_t authKeyId;
@property (nonatomic, readonly) int64_t sessionId;
@property (nonatomic, readonly) int64_t salt;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) NSInteger size;
@property (nonatomic, strong, readonly) id body;

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo authKeyId:(int64_t)authKeyId sessionId:(int64_t)sessionId salt:(int64_t)salt timestamp:(NSTimeInterval)timestamp size:(NSInteger)size body:(id)body;

@end
