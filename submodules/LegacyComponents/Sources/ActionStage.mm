#import "ActionStage.h"

#import <SSignalKit/SSignalKit.h>

#import "LegacyComponentsInternal.h"

#import "ASActor.h"

#import <os/lock.h>

#include <vector>
#include <unordered_map>

static const char *graphQueueSpecific = "com.telegraph.graphdispatchqueue";

static dispatch_queue_t mainGraphQueue = nil;
static dispatch_queue_t globalGraphQueue = nil;
static dispatch_queue_t highPriorityGraphQueue = nil;

static os_unfair_lock removeWatcherRequestsLock = OS_UNFAIR_LOCK_INIT;
static os_unfair_lock removeWatcherFromPathRequestsLock = OS_UNFAIR_LOCK_INIT;

@interface ActionStage ()
{
    std::vector<std::pair<ASHandle *, NSString *> > _removeWatcherFromPathRequests;
    std::vector<ASHandle *> _removeWatcherRequests;
}

@property (nonatomic, strong) NSMutableDictionary *requestQueues;

@property (nonatomic, strong) NSMutableDictionary *activeRequests;
@property (nonatomic, strong) NSMutableDictionary *cancelRequestTimers;

@property (nonatomic, strong) NSMutableDictionary *liveNodeWatchers;
@property (nonatomic, strong) NSMutableDictionary *actorMessagesWatchers;

@end

ActionStage *ActionStageInstance()
{
    static ActionStage *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        singleton = [[ActionStage alloc] init];
    });
    
    return singleton;
}

@implementation ActionStage

#pragma mark - Singleton

#pragma mark - Implemetation

@synthesize requestQueues = _requestQueues;

@synthesize activeRequests = _activeRequests;
@synthesize cancelRequestTimers = _cancelRequestTimers;

@synthesize liveNodeWatchers = _liveNodeWatchers;
@synthesize actorMessagesWatchers = _actorMessagesWatchers;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _requestQueues = [[NSMutableDictionary alloc] init];
        
        _activeRequests = [[NSMutableDictionary alloc] init];
        _cancelRequestTimers = [[NSMutableDictionary alloc] init];
        
        _liveNodeWatchers = [[NSMutableDictionary alloc] init];
        _actorMessagesWatchers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (dispatch_queue_t)globalStageDispatchQueue
{
    if (mainGraphQueue == NULL)
    {
        mainGraphQueue = dispatch_queue_create("com.telegraph.graphdispatchqueue", 0);
        
        globalGraphQueue = dispatch_queue_create("com.telegraph.graphdispatchqueue-global", 0);
        dispatch_set_target_queue(globalGraphQueue, mainGraphQueue);
        
        highPriorityGraphQueue = dispatch_queue_create("com.telegraph.graphdispatchqueue-high", 0);
        dispatch_set_target_queue(highPriorityGraphQueue, mainGraphQueue);
        
        dispatch_queue_set_specific(mainGraphQueue, graphQueueSpecific, (void *)graphQueueSpecific, NULL);
        dispatch_queue_set_specific(globalGraphQueue, graphQueueSpecific, (void *)graphQueueSpecific, NULL);
        dispatch_queue_set_specific(highPriorityGraphQueue, graphQueueSpecific, (void *)graphQueueSpecific, NULL);
    }
    return globalGraphQueue;
}

- (bool)isCurrentQueueStageQueue
{
    return dispatch_get_specific(graphQueueSpecific) != NULL;
}

#ifdef DEBUG
- (void)dispatchOnStageQueueDebug:(const char *)function line:(int)line block:(dispatch_block_t)block
#else
- (void)dispatchOnStageQueue:(dispatch_block_t)block
#endif
{
    bool isGraphQueue = false;

    isGraphQueue = dispatch_get_specific(graphQueueSpecific) != NULL;
    
    if (isGraphQueue)
    {
#ifdef DEBUG
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
#endif
        
        block();
        
#ifdef DEBUG
        CFAbsoluteTime executionTime = (CFAbsoluteTimeGetCurrent() - startTime);
        if (executionTime > 0.1)
            TGLegacyLog(@"***** Dispatch from %s:%d took %f s", function, line, executionTime);
#endif
    }
    else
    {
#ifdef DEBUG
        dispatch_async([self globalStageDispatchQueue], ^
        {
            CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
            
            block();
            
            CFAbsoluteTime executionTime = (CFAbsoluteTimeGetCurrent() - startTime);
            if (executionTime > 0.1)
                TGLegacyLog(@"***** Dispatch from %s:%d took %f s", function, line, executionTime);
        });
#else
        dispatch_async([self globalStageDispatchQueue], block);
#endif
    }
}

- (void)dispatchOnHighPriorityQueue:(dispatch_block_t)block
{
    if ([self isCurrentQueueStageQueue])
        block();
    else
    {
        if (highPriorityGraphQueue == NULL)
            [self globalStageDispatchQueue];
        
        dispatch_async(highPriorityGraphQueue, block);
    }
}

- (void)dumpGraphState
{
    [self dispatchOnStageQueue:^
    {
        TGLegacyLog(@"===== SGraph State =====");
        TGLegacyLog(@"%d live node watchers", _liveNodeWatchers.count);
        [_liveNodeWatchers enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSArray *watchers, __unused BOOL *stop)
        {
            TGLegacyLog(@"    %@", path);
            for (ASHandle *handle in watchers)
            {
                id<ASWatcher> watcher = handle.delegate;
                if (watcher != nil)
                {
                    TGLegacyLog(@"        %@", [watcher description]);
                }
            }
        }];
        TGLegacyLog(@"%d requests", _activeRequests.count);
        [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, __unused BOOL *stop) {
            TGLegacyLog(@"        %@", path);
        }];
        TGLegacyLog(@"========================");
    }];
}

- (NSFileManager *)globalFileManager
{
    static NSFileManager *fileManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        fileManager = [[NSFileManager alloc] init];
    });
    
    return fileManager;
}

- (NSString *)optionsHash:(NSDictionary *)options
{
    if (options.count == 0)
        return @"";
    
    NSMutableString *string = [[NSMutableString alloc] initWithString:@"#"];
    
    Class StringClass = [NSString class];
    NSArray *keys = [[options allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
    {
        if ([obj1 isKindOfClass:StringClass] && [obj2 isKindOfClass:StringClass])
        {
            return [(NSString *)obj1 compare:(NSString *)obj2];
        }
        else
            return NSOrderedSame;
    }];
    
    bool first = true;
    for (NSString *key in keys)
    {
        if (![key isKindOfClass:StringClass])
        {
            TGLegacyLog(@"Warning: optionsHash: key is not a string");
            continue;
        }
        
        if (first)
        {
            [string appendString:@","];
            first = false;
        }
        
        NSObject *value = [options objectForKey:key];
        if ([value respondsToSelector:@selector(stringValue)])
            [string appendFormat:@"%@=%@", key, value];
    }
    
    return string;
}

- (NSString *)genericStringForParametrizedPath:(NSString *)path
{
    if (path == nil)
        return @"";
    
    int length = (int)path.length;
    unichar newPath[path.length];
    int newLength = 0;
    
    SEL sel = @selector(characterAtIndex:);
    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[path methodForSelector:sel];
    
    bool skipCharacters = false;
    bool skippedCharacters = false;
    
    for (int i = 0; i < length; i++)
    {
        unichar c = characterAtIndexImp(path, sel, i);
        if (c == '(')
        {
            skipCharacters = true;
            skippedCharacters = true;
            newPath[newLength++] = '@';
        }
        else if (c == ')')
        {
            skipCharacters = false;
        }
        else if (!skipCharacters)
        {
            newPath[newLength++] = c;
        }
    }
    
    if (!skippedCharacters)
        return path;
    
    NSString *genericPath = [[NSString alloc] initWithCharacters:newPath length:newLength];
    return genericPath;
}

- (void)_requestGeneric:(bool)joinOnly inCurrentQueue:(bool)inCurrentQueue path:(NSString *)path options:(NSDictionary *)options flags:(int)flags watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    dispatch_block_t requestBlock = ^
    {
        if (![actionHandle hasDelegate])
        {
            TGLegacyLog(@"Error: %s:%d: actionHandle.delegate is nil", __PRETTY_FUNCTION__, __LINE__); 
            return;
        }
        
        NSMutableDictionary *activeRequests = _activeRequests;
        NSMutableDictionary *cancelTimers = _cancelRequestTimers;

        NSString *genericPath = [self genericStringForParametrizedPath:path];

        NSMutableDictionary *requestInfo = nil;

        NSMutableDictionary *cancelRequestInfo = [cancelTimers objectForKey:path];
        if (cancelRequestInfo != nil)
        {
            STimer *timer = [cancelRequestInfo objectForKey:@"timer"];
            [timer invalidate];
            timer = nil;
            requestInfo = [cancelRequestInfo objectForKey:@"requestInfo"];
            [activeRequests setObject:requestInfo forKey:path];
            [cancelTimers removeObjectForKey:path];
            TGLegacyLog(@"Resuming request to \"%@\"", path);
        }

        if (requestInfo == nil)
            requestInfo = [activeRequests objectForKey:path];
        
        if (joinOnly && requestInfo == nil)
            return;
        
        if (requestInfo == nil)
        {
            ASActor *requestBuilder = [ASActor requestBuilderForGenericPath:genericPath path:path];
            if (requestBuilder != nil)
            {
                NSMutableArray *watchers = [[NSMutableArray alloc] initWithObjects:actionHandle, nil];
                
                requestInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                               requestBuilder, @"requestBuilder",
                               watchers, @"watchers",
                               nil];
                
                [activeRequests setObject:requestInfo forKey:path];
                
                [requestBuilder prepare:options];
                
                bool executeNow = true;
                if (requestBuilder.requestQueueName != nil)
                {
                    NSMutableArray *requestQueue = [_requestQueues objectForKey:requestBuilder.requestQueueName];
                    if (requestQueue == nil)
                    {
                        requestQueue = [[NSMutableArray alloc] initWithObjects:requestBuilder, nil];
                        [_requestQueues setObject:requestQueue forKey:requestBuilder.requestQueueName];
                    }
                    else
                    {
                        [requestQueue addObject:requestBuilder];
                        if ([requestQueue count] > 1)
                        {
                            executeNow = false;
                            TGLegacyLog(@"Adding request %@ to request queue \"%@\"", requestBuilder, requestBuilder.requestQueueName);
                            
                            if (flags & TGActorRequestChangePriority)
                            {
                                if (requestQueue.count > 2)
                                {
                                    [requestQueue removeLastObject];
                                    [requestQueue insertObject:requestBuilder atIndex:1];
                                    
                                    TGLegacyLog(@"(Inserted actor with high priority (next in queue)");
                                }
                            }
                        }
                    }
                }
                
                if (executeNow)
                    [requestBuilder execute:options];
                else
                    requestBuilder.storedOptions = options;
            }
            else
            {
                TGLegacyLog(@"Error: request builder not found for \"%@\"", path);
            }
        }
        else
        {
            NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
            if (![watchers containsObject:actionHandle])
            {
                TGLegacyLog(@"Joining watcher to the watchers of \"%@\"", path);
                [watchers addObject:actionHandle];
            }
            else
            {
                TGLegacyLog(@"Continue to watch for actor \"%@\"", path);
            }
            
            ASActor *actor = [requestInfo objectForKey:@"requestBuilder"];
            if (actor.requestQueueName == nil)
                [actor watcherJoined:actionHandle options:options waitingInActorQueue:false];
            else
            {
                NSMutableArray *requestQueue = [_requestQueues objectForKey:actor.requestQueueName];
                if (requestQueue == nil || requestQueue.count == 0)
                {
                    [actor watcherJoined:actionHandle options:options waitingInActorQueue:false];
                }
                else
                {
                    [actor watcherJoined:actionHandle options:options waitingInActorQueue:[requestQueue objectAtIndex:0] != actor];
                    
                    if (flags & TGActorRequestChangePriority)
                        [self changeActorPriority:path];
                }
            }
        }
    };
    
    if (inCurrentQueue)
        requestBlock();
    else
        [self dispatchOnStageQueue:requestBlock];
}

- (void)changeActorPriority:(NSString *)path
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSDictionary *requestInfo = [_activeRequests objectForKey:path];
        if (requestInfo != nil)
        {
            ASActor *actor = [requestInfo objectForKey:@"requestBuilder"];
            if (actor.requestQueueName != nil)
            {
                NSMutableArray *requestQueue = [_requestQueues objectForKey:actor.requestQueueName];
                if (requestQueue != nil && requestQueue.count != 0)
                {
                    NSUInteger index = [requestQueue indexOfObject:actor];
                    if (index != NSNotFound && index != 0 && index != 1)
                    {
                        [requestQueue removeObjectAtIndex:index];
                        [requestQueue insertObject:actor atIndex:1];
                        
                        TGLegacyLog(@"Changed actor %@ priority (next in %@)", path, actor.requestQueueName);
                    }
                }
            }
        }
    }];
}

- (NSArray *)rejoinActionsWithGenericPathNow:(NSString *)genericPath prefix:(NSString *)prefix watcher:(id<ASWatcher>)watcher
{
    NSMutableDictionary *activeRequests = _activeRequests;
    NSMutableDictionary *cancelTimers = _cancelRequestTimers;
    
    NSMutableArray *rejoinPaths = [[NSMutableArray alloc] init];
    
    for (NSString *path in activeRequests.allKeys)
    {
        if ([path isEqualToString:genericPath] || ([[self genericStringForParametrizedPath:path] isEqualToString:genericPath] && (prefix.length == 0 || [path hasPrefix:prefix])))
        {
            [rejoinPaths addObject:path];
        }
    }
    
    for (NSString *path in cancelTimers.allKeys)
    {
        if ([[self genericStringForParametrizedPath:path] isEqualToString:genericPath] && [path hasPrefix:prefix])
        {
            [rejoinPaths addObject:path];
        }
    }
    
    for (NSString *path in rejoinPaths)
    {
        [self _requestGeneric:true inCurrentQueue:true path:path options:nil flags:0 watcher:watcher];
    }
    
    return rejoinPaths;
}

- (bool)isExecutingActorsWithGenericPath:(NSString *)genericPath
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        
        return false;
    }
    
    __block bool result = false;
    
    [_activeRequests enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, NSDictionary *actionInfo, BOOL *stop)
    {
        ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
        
        if ([genericPath isEqualToString:[actor.class genericPath]])
        {
            result = true;
            if (stop != NULL)
                *stop = true;
        }
    }];
    
    if (!result)
    {
        [_cancelRequestTimers enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, NSDictionary *actionInfo, BOOL *stop)
        {
            ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
            
            if ([genericPath isEqualToString:[actor.class genericPath]])
            {
                result = true;
                if (stop != NULL)
                    *stop = true;
            }
        }];
    }
    
    return result;
}

- (bool)isExecutingActorsWithPathPrefix:(NSString *)pathPrefix
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        
        return false;
    }

    __block bool result = false;

    [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, BOOL *stop)
    {
        if ([path hasPrefix:pathPrefix])
        {
            result = true;
            if (stop != NULL)
                *stop = true;
        }
    }];

    if (!result)
    {
        [_cancelRequestTimers enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, BOOL *stop)
        {
            if ([path hasPrefix:pathPrefix])
            {
                result = true;
                if (stop != NULL)
                    *stop = true;
            }
        }];
    }

    return result;
}

- (NSArray *)executingActorsWithPathPrefix:(NSString *)pathPrefix
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        
        return nil;
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSDictionary *actionInfo, __unused BOOL *stop)
    {
        if ([path hasPrefix:pathPrefix])
        {
            ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
            if (actor != nil)
                [array addObject:actor];
        }
    }];
    
    [_cancelRequestTimers enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSDictionary *actionInfo, __unused BOOL *stop)
    {
        if ([path hasPrefix:pathPrefix])
        {
            ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
            if (actor != nil)
                [array addObject:actor];
        }
    }];
    
    return array;
}

- (ASActor *)executingActorWithPath:(NSString *)path
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        
        return nil;
    }
    
    NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
    if (requestInfo != nil)
    {
        ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
        return requestBuilder;
    }
    
    NSMutableDictionary *cancelRequestInfo = [_cancelRequestTimers objectForKey:path];
    if (cancelRequestInfo != nil)
    {
        ASActor *requestBuilder = [[cancelRequestInfo objectForKey:@"requestInfo"] objectForKey:@"requestBuilder"];
        return requestBuilder;
    }
    
    return nil;
}

- (void)cancelActorTimeout:(NSString *)path
{
    NSMutableDictionary *cancelRequestInfo = [_cancelRequestTimers objectForKey:path];
    if (cancelRequestInfo != nil)
    {
        STimer *timer = [cancelRequestInfo objectForKey:@"timer"];
        [timer fireAndInvalidate];
        timer = nil;
        
        return;
    }
}

- (void)requestActor:(NSString *)action options:(NSDictionary *)options watcher:(id<ASWatcher>)watcher
{
    [self _requestGeneric:false inCurrentQueue:false path:action options:options flags:0 watcher:watcher];
}

- (void)requestActor:(NSString *)path options:(NSDictionary *)options flags:(int)flags watcher:(id<ASWatcher>)watcher
{
    [self _requestGeneric:false inCurrentQueue:false path:path options:options flags:flags watcher:watcher];
}

- (void)watchForPath:(NSString *)path watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    if (actionHandle == nil)
    {
        TGLegacyLog(@"***** Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
    {
        NSMutableArray *pathWatchers = [_liveNodeWatchers objectForKey:path];
        if (pathWatchers == nil)
        {
            pathWatchers = [[NSMutableArray alloc] init];
            [_liveNodeWatchers setObject:pathWatchers forKey:path];
        }
        
        if (![pathWatchers containsObject:actionHandle])
            [pathWatchers addObject:actionHandle];
    }];
}

- (void)watchForPaths:(NSArray *)paths watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    if (actionHandle == nil)
    {
        TGLegacyLog(@"***** Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
    {
        for (NSString *path in paths)
        {
            NSMutableArray *pathWatchers = [_liveNodeWatchers objectForKey:path];
            if (pathWatchers == nil)
            {
                pathWatchers = [[NSMutableArray alloc] init];
                [_liveNodeWatchers setObject:pathWatchers forKey:path];
            }
            
            if (![pathWatchers containsObject:actionHandle])
                [pathWatchers addObject:actionHandle];
        }
    }];
}

- (void)watchForGenericPath:(NSString *)path watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    if (actionHandle == nil)
    {
        TGLegacyLog(@"***** Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
    {
        NSString *genericPath = [self genericStringForParametrizedPath:path];
        NSMutableArray *pathWatchers = [_liveNodeWatchers objectForKey:genericPath];
        if (pathWatchers == nil)
        {
            pathWatchers = [[NSMutableArray alloc] init];
            [_liveNodeWatchers setObject:pathWatchers forKey:genericPath];
        }

        [pathWatchers addObject:actionHandle];
    }];
}

- (void)watchForMessagesToWatchersAtGenericPath:(NSString *)genericPath watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    if (actionHandle == nil)
    {
        TGLegacyLog(@"***** Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
    {
        NSMutableArray *pathWatchers = [_actorMessagesWatchers objectForKey:genericPath];
        if (pathWatchers == nil)
        {
            pathWatchers = [[NSMutableArray alloc] init];
            [_actorMessagesWatchers setObject:pathWatchers forKey:genericPath];
        }
        
        [pathWatchers addObject:actionHandle];
    }];
}

- (void)removeRequestFromQueueAndProceedIfFirst:(NSString *)name fromRequestBuilder:(ASActor *)requestBuilder
{
    NSMutableArray *requestQueue = [_requestQueues objectForKey:requestBuilder.requestQueueName == nil ? name : requestBuilder.requestQueueName];
    if (requestQueue == nil)
        TGLegacyLog(@"Warning: requestQueue is nil");
    else
    {
        if (requestQueue.count == 0)
        {
            TGLegacyLog(@"***** Warning ***** request queue \"%@\" is empty.", requestBuilder.requestQueueName);
        }
        else
        {   
            if ([requestQueue objectAtIndex:0] == requestBuilder)
            {
                [requestQueue removeObjectAtIndex:0];
                
                if (requestQueue.count != 0)
                {
                    ASActor *nextRequest = nil;
                    id nextRequestOptions = nil;
                    
                    nextRequest = [requestQueue objectAtIndex:0];
                    nextRequestOptions = nextRequest.storedOptions;
                    nextRequest.storedOptions = nil;
                    
                    if (nextRequest != nil && !nextRequest.cancelled)
                        [nextRequest execute:nextRequestOptions];
                }
                else
                {
                    //TGLegacyLog(@"Request queue %@ finished", requestBuilder.requestQueueName);
                    [_requestQueues removeObjectForKey:requestBuilder.requestQueueName];
                }
            }
            else
            {
                if ([requestQueue containsObject:requestBuilder])
                {
                    [requestQueue removeObject:requestBuilder];
                }
                else
                {
                    TGLegacyLog(@"***** Warning ***** request queue \"%@\" doesn't contain request to %@", requestBuilder.requestQueueName, requestBuilder.path);
                }
            }
        }
    }
}

- (void)removeWatcher:(id<ASWatcher>)watcher
{
    [self removeWatcherByHandle:watcher.actionHandle];
}

- (void)removeWatcherByHandle:(ASHandle *)actionHandle
{
    ASHandle *watcherGraphHandle = actionHandle;
    if (watcherGraphHandle == nil)
    {
        TGLegacyLog(@"***** Warning: graph handle is nil in removeWatcher");
        return;
    }
    
    bool alreadyExecuting = false;
    os_unfair_lock_lock(&removeWatcherRequestsLock);
    if (!_removeWatcherRequests.empty())
        alreadyExecuting = true;
    _removeWatcherRequests.push_back(watcherGraphHandle);
    os_unfair_lock_unlock(&removeWatcherRequestsLock);
    
    if (alreadyExecuting && ![self isCurrentQueueStageQueue])
        return;
    
    [self dispatchOnHighPriorityQueue:^
    {
        std::vector<ASHandle *> removeWatchers;
        
        os_unfair_lock_lock(&removeWatcherRequestsLock);
        removeWatchers.insert(removeWatchers.begin(), _removeWatcherRequests.begin(), _removeWatcherRequests.end());
        _removeWatcherRequests.clear();
        os_unfair_lock_unlock(&removeWatcherRequestsLock);
        
        for (std::vector<ASHandle *>::iterator it = removeWatchers.begin(); it != removeWatchers.end(); it++)
        {
            ASHandle *actionHandle = *it;
            
            for (id key in [_activeRequests allKeys])
            {
                NSMutableDictionary *requestInfo = [_activeRequests objectForKey:key];
                NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
                [watchers removeObject:actionHandle];
                
                if (watchers.count == 0)
                {
                    [self scheduleCancelRequest:(NSString *)key];
                }
            }
            
            {
                NSMutableArray *keysToRemove = nil;
                for (NSString *key in [_liveNodeWatchers allKeys])
                {
                    NSMutableArray *watchers = [_liveNodeWatchers objectForKey:key];
                    [watchers removeObject:actionHandle];
                    
                    if (watchers.count == 0)
                    {
                        if (keysToRemove == nil)
                            keysToRemove = [[NSMutableArray alloc] init];
                        [keysToRemove addObject:key];
                    }
                }
                if (keysToRemove != nil)
                    [_liveNodeWatchers removeObjectsForKeys:keysToRemove];
            }
            
            {
                NSMutableArray *keysToRemove = nil;
                for (NSString *key in [_actorMessagesWatchers allKeys])
                {
                    NSMutableArray *watchers = [_actorMessagesWatchers objectForKey:key];
                    [watchers removeObject:actionHandle];
                    
                    if (watchers.count == 0)
                    {
                        if (keysToRemove == nil)
                            keysToRemove = [[NSMutableArray alloc] init];
                        [keysToRemove addObject:key];
                    }
                }
                if (keysToRemove != nil)
                    [_actorMessagesWatchers removeObjectsForKeys:keysToRemove];
            }
        }
    }];
}

- (void)removeAllWatchersFromPath:(NSString *)path
{
    [self dispatchOnHighPriorityQueue:^
    {
        {
            NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
            if (requestInfo != nil)
            {
                NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
                [watchers removeAllObjects];
                [self scheduleCancelRequest:(NSString *)path];
            }
        }
    }];
}

- (void)removeWatcher:(id<ASWatcher>)watcher fromPath:(NSString *)path
{
    ASHandle *actionHandle = watcher.actionHandle;
    [self removeWatcherByHandle:actionHandle fromPath:path];
}

- (void)removeWatcherByHandle:(ASHandle *)watcherGraphHandle fromPath:(NSString *)watcherPath
{
    if (watcherGraphHandle == nil)
    {
        TGLegacyLog(@"***** Warning: graph handle is nil in removeWatcher:fromPath");
        return;
    }
    
    bool alreadyExecuting = false;
    os_unfair_lock_lock(&removeWatcherFromPathRequestsLock);
    if (!_removeWatcherFromPathRequests.empty())
        alreadyExecuting = true;
    _removeWatcherFromPathRequests.push_back(std::pair<ASHandle *, NSString *>(watcherGraphHandle, watcherPath));
    os_unfair_lock_unlock(&removeWatcherFromPathRequestsLock);
    
    if (alreadyExecuting && ![self isCurrentQueueStageQueue])
        return;
    
    [self dispatchOnHighPriorityQueue:^
    {
        std::vector<std::pair<ASHandle *, NSString *> > removeWatchersFromPath;
        
        os_unfair_lock_lock(&removeWatcherFromPathRequestsLock);
        removeWatchersFromPath.insert(removeWatchersFromPath.begin(), _removeWatcherFromPathRequests.begin(), _removeWatcherFromPathRequests.end());
        _removeWatcherFromPathRequests.clear();
        os_unfair_lock_unlock(&removeWatcherFromPathRequestsLock);
        
        if (removeWatchersFromPath.size() > 1)
        {
            TGLegacyLog(@"Cancelled %ld requests at once", removeWatchersFromPath.size());
        }
        
        for (std::vector<std::pair<ASHandle *, NSString *> >::iterator it = removeWatchersFromPath.begin(); it != removeWatchersFromPath.end(); it++)
        {
            ASHandle *actionHandle = it->first;
            NSString *path = it->second;
            if (path == nil)
                continue;
            
            {
                NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
                if (requestInfo != nil)
                {
                    NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
                    if ([watchers containsObject:actionHandle])
                    {
                        [watchers removeObject:actionHandle];
                    }
                    if (watchers.count == 0)
                    {
                        [self scheduleCancelRequest:(NSString *)path];
                    }
                }
            }
            {
                NSMutableArray *watchers = [_liveNodeWatchers objectForKey:path];
                if ([watchers containsObject:actionHandle])
                {
                    [watchers removeObject:actionHandle];
                }
                if (watchers.count == 0)
                {
                    [_liveNodeWatchers removeObjectForKey:path];
                }
            }
            {
                NSMutableArray *watchers = [_actorMessagesWatchers objectForKey:path];
                if ([watchers containsObject:actionHandle])
                {
                    [watchers removeObject:actionHandle];
                }
                if (watchers.count == 0)
                {
                    [_actorMessagesWatchers removeObjectForKey:path];
                }
            }
        }
    }];
}

- (bool)requestActorStateNow:(NSString *)path
{
    if ([_activeRequests objectForKey:path] != nil)
        return true;
    return false;
}

- (void)dispatchResource:(NSString *)path resource:(id)resource
{
    [self dispatchResource:path resource:resource arguments:nil];
}

- (void)dispatchResource:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    [self dispatchOnStageQueue:^
    {
        NSString *genericPath = [self genericStringForParametrizedPath:path];
        {
            NSArray *watchers = [[_liveNodeWatchers objectForKey:path] copy];
            if (watchers != nil)
            {
                for (ASHandle *handle in watchers)
                {
                    id<ASWatcher> watcher = handle.delegate;
                    if (watcher != nil)
                    {
                        if ([watcher respondsToSelector:@selector(actionStageResourceDispatched:resource:arguments:)])
                            [watcher actionStageResourceDispatched:path resource:resource arguments:arguments];
                        
                        if (handle.releaseOnMainThread)
                            dispatch_async(dispatch_get_main_queue(), ^ { [watcher class]; });
                        watcher = nil;
                    }
                }
            }
        }
        if (![genericPath isEqualToString:path])
        {
            NSArray *watchers = [_liveNodeWatchers objectForKey:genericPath];
            if (watchers != nil)
            {
                for (ASHandle *handle in watchers)
                {
                    id<ASWatcher> watcher = handle.delegate;
                    if (watcher != nil)
                    {
                        if ([watcher respondsToSelector:@selector(actionStageResourceDispatched:resource:arguments:)])
                            [watcher actionStageResourceDispatched:path resource:resource arguments:arguments];
                        
                        if (handle.releaseOnMainThread)
                            dispatch_async(dispatch_get_main_queue(), ^ { [watcher class]; });
                        watcher = nil;
                    }
                }
            }
        }
    }];
}

- (void)actionCompleted:(NSString *)action result:(id)result
{
    [self dispatchOnStageQueue:^
    {
        NSMutableDictionary *requestInfo = [_activeRequests objectForKey:action];
        if (requestInfo != nil)
        {
            ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
            
            NSMutableArray *actionWatchers = [requestInfo objectForKey:@"watchers"];   
            [_activeRequests removeObjectForKey:action];
            for (ASHandle *handle in actionWatchers)
            {
                id<ASWatcher> watcher = handle.delegate;
                if (watcher != nil)
                {
                    if ([watcher respondsToSelector:@selector(actorCompleted:path:result:)])
                        [watcher actorCompleted:ASStatusSuccess path:action result:result];
                    
                    if (handle.releaseOnMainThread)
                        dispatch_async(dispatch_get_main_queue(), ^ { [watcher class]; });
                    watcher = nil;
                }
            }
            [actionWatchers removeAllObjects];
            
            if (requestBuilder == nil)
                TGLegacyLog(@"***** Warning ***** requestBuilder is nil");
            else if (requestBuilder.requestQueueName != nil)
            {
                [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName fromRequestBuilder:requestBuilder];
            }
        }
    }];
}

- (void)dispatchMessageToWatchers:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    [self dispatchOnStageQueue:^
    {
        NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
        if (requestInfo != nil)
        {
            NSArray *actionWatchersCopy = [[requestInfo objectForKey:@"watchers"] copy];
            for (ASHandle *handle in actionWatchersCopy)
            {
                [handle receiveActorMessage:path messageType:messageType message:message];
            }
        }
        
        if (_actorMessagesWatchers.count != 0)
        {
            NSString *genericPath = [self genericStringForParametrizedPath:path];
            NSArray *messagesWatchersCopy = [[_actorMessagesWatchers objectForKey:genericPath] copy];
            
            if (messagesWatchersCopy != nil)
            {
                for (ASHandle *handle in messagesWatchersCopy)
                {
                    [handle receiveActorMessage:path messageType:messageType message:message];
                }
            }
        }
    }];
}

- (void)actionFailed:(NSString *)action reason:(int)reason
{
    [self dispatchOnStageQueue:^
    {
        NSMutableDictionary *requestInfo = [_activeRequests objectForKey:action];
        if (requestInfo != nil)
        {
            ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
            
            NSMutableArray *actionWatchers = [requestInfo objectForKey:@"watchers"];   
            [_activeRequests removeObjectForKey:action];
            for (ASHandle *handle in actionWatchers)
            {
                id<ASWatcher> watcher = handle.delegate;
                if (watcher != nil)
                {
                    if ([watcher respondsToSelector:@selector(actorCompleted:path:result:)])
                        [watcher actorCompleted:reason path:action result:nil];
                    
                    if (handle.releaseOnMainThread)
                        dispatch_async(dispatch_get_main_queue(), ^ { [watcher class]; });
                    watcher = nil;
                }
            }
            [actionWatchers removeAllObjects];
            
            if (requestBuilder == nil)
                TGLegacyLog(@"***** Warning ***** requestBuilder is nil");
            else if (requestBuilder.requestQueueName != nil)
            {
                [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName fromRequestBuilder:requestBuilder];
            }
        }
    }];
}

- (void)nodeRetrieved:(NSString *)path node:(SGraphNode *)node
{
    [self actionCompleted:path result:node];
}

- (void)nodeRetrieveProgress:(NSString *)path progress:(float)progress
{
    [self dispatchOnStageQueue:^
    {
        NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
        if (requestInfo == nil)
            requestInfo = [_activeRequests objectForKey:path];
        
        if (requestInfo != nil)
        {
            NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
            for (ASHandle *handle in watchers)
            {
                id<ASWatcher> watcher = handle.delegate;
                if (watcher != nil)
                {
                    if ([watcher respondsToSelector:@selector(actorReportedProgress:progress:)])
                        [watcher actorReportedProgress:path progress:progress];
                    
                    if (handle.releaseOnMainThread)
                        dispatch_async(dispatch_get_main_queue(), ^ { [watcher class]; });
                    watcher = nil;
                }
            }
        }
    }];
}

- (void)nodeRetrieveFailed:(NSString *)path
{
    [self actionFailed:path reason:-1];
}

- (void)scheduleCancelRequest:(NSString *)path
{
    NSMutableDictionary *activeRequests = _activeRequests;
    NSMutableDictionary *cancelTimers = _cancelRequestTimers;
    
    NSMutableDictionary *requestInfo = [activeRequests objectForKey:path];
    NSMutableDictionary *cancelRequestInfo = [cancelTimers objectForKey:path];
    if (requestInfo != nil && cancelRequestInfo == nil)
    {
        ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
        NSTimeInterval cancelTimeout = requestBuilder.cancelTimeout;
        
        if (cancelTimeout <= DBL_EPSILON)
        {
            [activeRequests removeObjectForKey:path];
            
            [requestBuilder cancel];
            TGLegacyLog(@"Cancelled request to \"%@\"", path);
            if (requestBuilder.requestQueueName != nil)
                [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName fromRequestBuilder:requestBuilder];
        }
        else
        {
            TGLegacyLog(@"Will cancel request to \"%@\" in %f s", path, cancelTimeout);
            NSDictionary *cancelDict = [NSDictionary dictionaryWithObjectsAndKeys:path, @"path", [NSNumber numberWithInt:0], @"type", nil];
            STimer *timer = [[STimer alloc] initWithTimeout:cancelTimeout repeat:false completion:^
            {
                [self performCancelRequest:cancelDict];
            } nativeQueue:[ActionStageInstance() globalStageDispatchQueue]];
            
            cancelRequestInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:requestInfo, @"requestInfo", nil];
            [cancelRequestInfo setObject:timer forKey:@"timer"];
            [cancelTimers setObject:cancelRequestInfo forKey:path];
            [activeRequests removeObjectForKey:path];
            
            [timer start];
        }
    }
    else if (cancelRequestInfo == nil)
    {
        TGLegacyLog(@"Warning: cannot cancel request to \"%@\": no active request found", path);
    }
}
         
- (void)performCancelRequest:(NSDictionary *)cancelDict
{
    NSString *path = [cancelDict objectForKey:@"path"];
    
    [self dispatchOnStageQueue:^
    {
        NSMutableDictionary *cancelTimers = _cancelRequestTimers;

        NSMutableDictionary *cancelRequestInfo = [cancelTimers objectForKey:path];
        if (cancelRequestInfo == nil)
        {
            TGLegacyLog(@"Warning: cancelNodeRequestTimerEvent: \"%@\": no cancel info found", path);
            return;
        }
        NSDictionary *requestInfo = [cancelRequestInfo objectForKey:@"requestInfo"];
        ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
        if (requestBuilder == nil)
        {
            TGLegacyLog(@"Warning: active request builder for \"%@\" not fond, cannot cancel request", path);
        }
        else
        {
            [requestBuilder cancel];
            TGLegacyLog(@"Cancelled request to \"%@\"", path);
            if (requestBuilder.requestQueueName != nil)
                [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName fromRequestBuilder:requestBuilder];
        }
        [cancelTimers removeObjectForKey:path];
    }];
}

@end
