

#import <MtProtoKit/MTMessageService.h>

@class MTContext;
@class MTDatacenterAuthMessageService;
@class MTDatacenterAuthKey;

@protocol MTDatacenterAuthMessageServiceDelegate <NSObject>

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp;

@end

@interface MTDatacenterAuthMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTDatacenterAuthMessageServiceDelegate> delegate;

- (instancetype)initWithContext:(MTContext *)context tempAuth:(bool)tempAuth;

@end
