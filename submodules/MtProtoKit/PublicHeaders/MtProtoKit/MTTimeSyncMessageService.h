
#import <MtProtoKit/MTMessageService.h>

@class MTTimeSyncMessageService;

@protocol MTTimeSyncMessageServiceDelegate <NSObject>

@optional

- (void)timeSyncServiceCompleted:(MTTimeSyncMessageService *)timeSyncService timeDifference:(NSTimeInterval)timeDifference saltList:(NSArray *)saltList;

@end

@interface MTTimeSyncMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTTimeSyncMessageServiceDelegate> delegate;

@end
