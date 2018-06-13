

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTMessageService.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTMessageService.h>
#else
#   import <MTProtoKit/MTMessageService.h>
#endif

@class MTContext;
@class MTRequest;
@class MTApiEnvironment;

@class MTRequestMessageService;

@protocol MTRequestMessageServiceDelegate <NSObject>

@optional

- (void)requestMessageServiceAuthorizationRequired:(MTRequestMessageService *)requestMessageService;
- (void)requestMessageServiceDidCompleteAllRequests:(MTRequestMessageService *)requestMessageService;

@end

@interface MTRequestMessageService : NSObject <MTMessageService>

@property (nonatomic, weak) id<MTRequestMessageServiceDelegate> delegate;

@property (nonatomic, strong) MTApiEnvironment *apiEnvironment;
@property (nonatomic) bool forceBackgroundRequests;

- (instancetype)initWithContext:(MTContext *)context;

- (void)addRequest:(MTRequest *)request;
- (void)removeRequestByInternalId:(id)internalId;
- (void)removeRequestByInternalId:(id)internalId askForReconnectionOnDrop:(bool)askForReconnectionOnDrop;

- (void)requestCount:(void (^)(NSUInteger requestCount))completion;

@end
