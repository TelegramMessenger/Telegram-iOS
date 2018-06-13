

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTMessageService.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTMessageService.h>
#else
#   import <MTProtoKit/MTMessageService.h>
#endif

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
