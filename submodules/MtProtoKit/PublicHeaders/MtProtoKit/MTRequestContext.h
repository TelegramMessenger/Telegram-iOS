

#import <Foundation/Foundation.h>

@interface MTRequestContext : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t messageSeqNo;
@property (nonatomic) bool waitingForMessageId;
@property (nonatomic, strong) id transactionId;
@property (nonatomic) int32_t quickAckId;
@property (nonatomic) bool delivered;
@property (nonatomic) int64_t responseMessageId;
@property (nonatomic) bool willInitializeApi;

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId quickAckId:(int32_t)quickAckId;

@end
