

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTMessageService.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTMessageService.h>
#else
#   import <MTProtoKit/MTMessageService.h>
#endif

@class MTTimeSyncMessageService;

@protocol MTTimeSyncMessageServiceDelegate <NSObject>

@optional

- (void)timeSyncServiceCompleted:(MTTimeSyncMessageService *)timeSyncService timeDifference:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList;

@end

@interface MTTimeSyncMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTTimeSyncMessageServiceDelegate> delegate;

@end
