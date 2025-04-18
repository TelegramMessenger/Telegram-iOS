#import <Foundation/Foundation.h>

@interface MTDropRpcResultMessage : NSObject

@end


@interface MTDropRpcResultUnknownMessage : MTDropRpcResultMessage

@end

@interface MTDropRpcResultDroppedRunningMessage : MTDropRpcResultMessage

@end

@interface MTDropRpcResultDroppedMessage : MTDropRpcResultMessage

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t seqNo;
@property (nonatomic, readonly) int32_t size;

- (instancetype)initWithMessageId:(int64_t)messageId seqNo:(int32_t)seqNo size:(int32_t)size;

@end