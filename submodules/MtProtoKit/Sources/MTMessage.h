#import <Foundation/Foundation.h>

@interface MTMessage : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t seqNo;
@property (nonatomic, strong, readonly) NSData *data;

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo data:(NSData *)data;

@end
