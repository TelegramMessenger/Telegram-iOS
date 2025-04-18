#import <Foundation/Foundation.h>

@interface MTTimeFixContext : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t messageSeqNo;
@property (nonatomic, strong, readonly) id transactionId;
@property (nonatomic, readonly) CFAbsoluteTime timeFixAbsoluteStartTime;

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId timeFixAbsoluteStartTime:(CFAbsoluteTime)timeFixAbsoluteStartTime;

@end
