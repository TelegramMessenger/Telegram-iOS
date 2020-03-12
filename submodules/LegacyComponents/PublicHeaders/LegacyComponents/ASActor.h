#import <Foundation/Foundation.h>

#import <LegacyComponents/ASHandle.h>

@interface ASActor : NSObject

+ (void)registerActorClass:(Class)requestBuilderClass;

+ (ASActor *)requestBuilderForGenericPath:(NSString *)genericPath path:(NSString *)path;

+ (NSString *)genericPath;

@property (nonatomic, strong) NSString *path;

@property (nonatomic, strong) NSString *requestQueueName;
@property (nonatomic, strong) NSDictionary *storedOptions;

@property (nonatomic) bool requiresAuthorization;

@property (nonatomic) NSTimeInterval cancelTimeout;
@property (nonatomic, strong) id cancelToken;
@property (nonatomic, strong) NSMutableArray *multipleCancelTokens;
@property (nonatomic) bool cancelled;

- (id)initWithPath:(NSString *)path;
- (void)prepare:(NSDictionary *)options;
- (void)execute:(NSDictionary *)options;
- (void)cancel;

- (void)addCancelToken:(id)token;

- (void)watcherJoined:(ASHandle *)watcherHandle options:(NSDictionary *)options waitingInActorQueue:(bool)waitingInActorQueue;

- (void)handleRequestProblem;

@end
