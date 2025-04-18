#import "ASActor.h"

#import "ActionStage.h"

#import "LegacyComponentsInternal.h"

static NSMutableDictionary *registeredRequestBuilders()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

@implementation ASActor

+ (void)registerActorClass:(Class)requestBuilderClass
{
    NSString *genericPath = [requestBuilderClass genericPath];
    if (genericPath == nil || genericPath.length == 0)
    {
        TGLegacyLog(@"Error: ASActor::registerActorClass: genericPath is nil");
        return;
    }
    
    [registeredRequestBuilders() setObject:requestBuilderClass forKey:genericPath];
}

+ (ASActor *)requestBuilderForGenericPath:(NSString *)genericPath path:(NSString *)path
{
    Class builderClass = [registeredRequestBuilders() objectForKey:genericPath];
    if (builderClass != nil)
    {
        ASActor *builderInstance = [[builderClass alloc] initWithPath:path];
        return builderInstance;
    }
    return nil;
}

+ (NSString *)genericPath
{
    TGLegacyLog(@"Error: ASActor::genericPath: no default implementation provided");
    
    return nil;
}

@synthesize path = _path;

@synthesize requestQueueName = _requestQueueName;
@synthesize storedOptions = _storedOptions;

@synthesize requiresAuthorization = _requiresAuthorization;

@synthesize cancelTimeout = _cancelTimeout;
@synthesize cancelToken = _cancelToken;
@synthesize cancelled = _cancelled;

/*#if TARGET_IPHONE_SIMULATOR
static int instanceCount = 0;
#endif*/

- (id)initWithPath:(NSString *)path
{
    self = [super init];
    if (self != nil)
    {
        _cancelTimeout = 0;
        _path = path;
        
/*#if TARGET_IPHONE_SIMULATOR
        instanceCount++;
        
        TGLegacyLog(@"%d actors (++)", instanceCount);
#endif*/
    }
    return self;
}

- (void)dealloc
{
/*#if TARGET_IPHONE_SIMULATOR
    instanceCount--;
    
    TGLegacyLog(@"%d actors (--)", instanceCount);
#endif*/
}

- (void)prepare:(NSDictionary *)__unused options
{
}

- (void)execute:(NSDictionary *)__unused options
{
    TGLegacyLog(@"Error: ASActor::execute: no default implementation provided");
}

- (void)cancel
{
    self.cancelled = true;
}

- (void)addCancelToken:(id)token
{
    if (_multipleCancelTokens == nil)
        _multipleCancelTokens = [[NSMutableArray alloc] init];
    
    [_multipleCancelTokens addObject:token];
}

- (void)handleRequestProblem
{
}

- (void)watcherJoined:(ASHandle *)__unused watcherHandle options:(NSDictionary *)__unused options waitingInActorQueue:(bool)__unused waitingInActorQueue
{
}

@end
