

#import <MtProtoKit/MTMessageService.h>

@class MTResendMessageService;

@protocol MTResendMessageServiceDelegate <NSObject>

@optional

- (void)resendMessageServiceCompleted:(MTResendMessageService *)resendService;

@end

@interface MTResendMessageService : NSObject <MTMessageService>

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, weak) id<MTResendMessageServiceDelegate> delegate;

- (instancetype)initWithMessageId:(int64_t)messageId;

@end
