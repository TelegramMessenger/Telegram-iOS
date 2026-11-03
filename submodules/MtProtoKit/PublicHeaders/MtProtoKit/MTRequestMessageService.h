

#import <MtProtoKit/MTMessageService.h>

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
    
@property (nonatomic, copy) void (^didReceiveSoftAuthResetError)(void);

- (instancetype)initWithContext:(MTContext *)context;

- (void)addRequest:(MTRequest *)request;
- (void)removeRequestByInternalId:(id)internalId;
- (void)removeRequestByInternalId:(id)internalId askForReconnectionOnDrop:(bool)askForReconnectionOnDrop;

- (void)requestCount:(void (^)(NSUInteger requestCount))completion;

/// Hands the requests over to another session (a live engine switch) without running any of them twice.
/// From now on no request goes out under a new message id. A request that has none (never sent, or sent
/// again after an answer it was retried for) leaves at once through `released`, on the service's queue,
/// unless it depends on one still waiting; one that has a message id waits for its answer, which completes
/// it as usual, and goes out again only under that id. `mayHaveReachedServer` is true for a request that
/// had a message id when the handover began or got one since, unless the server answered it with an
/// error it was retried for; `retryAfter` is what is left of the wait it was serving. Requests added
/// afterwards are released at once. Unused (nil) by default.
- (void)handOverRequests:(void (^)(MTRequest *request, bool mayHaveReachedServer, double retryAfter))released;

/// Releases every request still waiting after `handOverRequests:` (its deadline).
- (void)releaseHandedOverRequests;

@end
