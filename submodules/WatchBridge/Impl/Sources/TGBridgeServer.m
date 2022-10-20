#import <WatchBridgeImpl/TGBridgeServer.h>

#import <LegacyComponents/LegacyComponents.h>
#import <WatchConnectivity/WatchConnectivity.h>
#import <os/lock.h>
#import <WatchCommon/WatchCommon.h>

@interface TGBridgeSignalManager : NSObject

- (bool)startSignalForKey:(NSString *)key producer:(SSignal *(^)())producer;
- (void)haltSignalForKey:(NSString *)key;
- (void)haltAllSignals;

@end

@interface TGBridgeServer () <WCSessionDelegate>
{
    SSignal *(^_handler)(TGBridgeSubscription *);
    void (^_fileHandler)(NSString *, NSDictionary *);
    void (^_logFunction)(NSString *);
    void (^_dispatch)(void (^)(void));
    
    bool _pendingStart;

    bool _processingNotification;
    
    int32_t _sessionId;
    volatile int32_t _tasksVersion;
    
    TGBridgeContext *_activeContext;
    
    TGBridgeSignalManager *_signalManager;
    
    os_unfair_lock _incomingQueueLock;
    NSMutableArray *_incomingMessageQueue;
    
    bool _requestSubscriptionList;
    NSArray *_initialSubscriptionList;
    
    os_unfair_lock _outgoingQueueLock;
    NSMutableArray *_outgoingMessageQueue;
    
    os_unfair_lock _replyHandlerMapLock;
    NSMutableDictionary *_replyHandlerMap;
    
    SPipe *_appInstalled;
    
    NSMutableDictionary *_runningTasks;
    SVariable *_hasRunningTasks;
    
    void (^_allowBackgroundTimeExtension)();
}

@property (nonatomic, readonly) WCSession *session;

@end

@implementation TGBridgeServer

- (instancetype)initWithHandler:(SSignal *(^)(TGBridgeSubscription *))handler fileHandler:(void (^)(NSString *, NSDictionary *))fileHandler dispatchOnQueue:(void (^)(void (^)(void)))dispatchOnQueue logFunction:(void (^)(NSString *))logFunction allowBackgroundTimeExtension:(void (^)())allowBackgroundTimeExtension
{
    self = [super init];
    if (self != nil)
    {
        _handler = [handler copy];
        _fileHandler = [fileHandler copy];
        _dispatch = [dispatchOnQueue copy];
        _logFunction = [logFunction copy];
        _allowBackgroundTimeExtension = [allowBackgroundTimeExtension copy];
        
        _runningTasks = [[NSMutableDictionary alloc] init];
        _hasRunningTasks = [[SVariable alloc] init];
        [_hasRunningTasks set:[SSignal single:@false]];
        
        _signalManager = [[TGBridgeSignalManager alloc] init];
        _incomingMessageQueue = [[NSMutableArray alloc] init];
        
        self.session.delegate = self;
        [self.session activateSession];
        
        _replyHandlerMap = [[NSMutableDictionary alloc] init];
        
        _appInstalled = [[SPipe alloc] init];
        
        _activeContext = [[TGBridgeContext alloc] initWithDictionary:[self.session applicationContext]];
    }
    return  self;
}

- (void)log:(NSString *)message
{
    _logFunction(message);
}

- (void)dispatch:(void (^)(void))action
{
    _dispatch(action);
}

- (void)startRunning
{
    if (self.isRunning)
        return;
    
    os_unfair_lock_lock(&_incomingQueueLock);
    _isRunning = true;
    
    for (id message in _incomingMessageQueue)
        [self handleMessage:message replyHandler:nil finishTask:nil completion:nil];
    
    [_incomingMessageQueue removeAllObjects];
    os_unfair_lock_unlock(&_incomingQueueLock);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dispatch:^{
            _appInstalled.sink(@(self.session.isWatchAppInstalled));
        }];
    });
}

- (NSURL *)temporaryFilesURL
{
    return self.session.watchDirectoryURL;
}

- (SSignal *)watchAppInstalledSignal
{
    return [[SSignal single:@(self.session.watchAppInstalled)] then:_appInstalled.signalProducer()];
}

- (SSignal *)runningRequestsSignal
{
    return _hasRunningTasks.signal;
}

#pragma mark -

- (void)setAuthorized:(bool)authorized userId:(int64_t)userId
{
    _activeContext = [_activeContext updatedWithAuthorized:authorized peerId:userId];
}

- (void)setMicAccessAllowed:(bool)allowed
{
    _activeContext = [_activeContext updatedWithMicAccessAllowed:allowed];
}

- (void)setStartupData:(NSDictionary *)data
{
    _activeContext = [_activeContext updatedWithPreheatData:data];
}

- (void)pushContext
{
    NSError *error;
    [self.session updateApplicationContext:[_activeContext dictionary] error:&error];
        
    //if (error != nil)
        //TGLog(@"[BridgeServer][ERROR] Failed to push active application context: %@", error.localizedDescription);
}

#pragma mark -

- (void)handleMessageData:(NSData *)messageData task:(id<SDisposable>)task replyHandler:(void (^)(NSData *))replyHandler completion:(void (^)(void))completion
{
    if (_allowBackgroundTimeExtension) {
        _allowBackgroundTimeExtension();
    }
    
    __block id<SDisposable> runningTask = task;
    void (^finishTask)(NSTimeInterval) = ^(NSTimeInterval delay)
    {
        if (runningTask == nil)
            return;
        
        void (^block)(void) = ^
        {
            [self dispatch:^{
                [runningTask dispose];
                //TGLog(@"[BridgeServer]: ended taskid: %d", runningTask);
                runningTask = nil;
            }];
        };
        
        if (delay > DBL_EPSILON)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
        else
            block();
    };
    
    id message = [NSKeyedUnarchiver unarchiveObjectWithData:messageData];
    os_unfair_lock_lock(&_incomingQueueLock);
    if (!self.isRunning)
    {
        [_incomingMessageQueue addObject:message];
        
        if (replyHandler != nil)
            replyHandler([NSData data]);
        
        finishTask(4.0);
        
        os_unfair_lock_unlock(&_incomingQueueLock);
        return;
    }
    os_unfair_lock_unlock(&_incomingQueueLock);
    
    [self handleMessage:message replyHandler:replyHandler finishTask:finishTask completion:completion];
}

- (void)handleMessage:(id)message replyHandler:(void (^)(NSData *))replyHandler finishTask:(void (^)(NSTimeInterval))finishTask completion:(void (^)(void))completion
{
    if ([message isKindOfClass:[TGBridgeSubscription class]])
    {
        TGBridgeSubscription *subcription = (TGBridgeSubscription *)message;
        [self _createSubscription:subcription replyHandler:replyHandler finishTask:finishTask completion:completion];
        
        //TGLog(@"[BridgeServer] Create subscription: %@", subcription);
    }
    else if ([message isKindOfClass:[TGBridgeDisposal class]])
    {
        TGBridgeDisposal *disposal = (TGBridgeDisposal *)message;
        [_signalManager haltSignalForKey:[NSString stringWithFormat:@"%lld", disposal.identifier]];
        
        if (replyHandler != nil)
            replyHandler([NSData data]);
        
        if (completion != nil)
            completion();
        
        //TGLog(@"[BridgeServer] Dispose subscription %lld", disposal.identifier);
        
        if (finishTask != nil)
            finishTask(0);
    }
    else if ([message isKindOfClass:[TGBridgeSubscriptionList class]])
    {
        TGBridgeSubscriptionList *list = (TGBridgeSubscriptionList *)message;
        for (TGBridgeSubscription *subscription in list.subscriptions)
            [self _createSubscription:subscription replyHandler:nil finishTask:nil completion:nil];
        
        //TGLog(@"[BridgeServer] Received subscription list, applying");
        
        if (replyHandler != nil)
            replyHandler([NSData data]);
        
        if (finishTask != nil)
            finishTask(4.0);
        
        if (completion != nil)
            completion();
    }
    else if ([message isKindOfClass:[TGBridgePing class]])
    {
        TGBridgePing *ping = (TGBridgePing *)message;
        if (_sessionId != ping.sessionId)
        {
            //TGLog(@"[BridgeServer] Session id mismatch");
            
            if (_sessionId != 0)
            {
                //TGLog(@"[BridgeServer] Halt all active subscriptions");
                [_signalManager haltAllSignals];
                
                os_unfair_lock_lock(&_outgoingQueueLock);
                [_outgoingMessageQueue removeAllObjects];
                os_unfair_lock_unlock(&_outgoingQueueLock);
            }
            
            _sessionId = ping.sessionId;
            
            if (self.session.isReachable)
                [self _requestSubscriptionList];
            else
                _requestSubscriptionList = true;
        }
        else
        {
            if (_requestSubscriptionList)
            {
                _requestSubscriptionList = false;
                [self _requestSubscriptionList];
            }
            
            [self _sendQueuedResponses];
            
            if (replyHandler != nil)
                replyHandler([NSData data]);
        }
        
        if (completion != nil)
            completion();
        
        if (finishTask != nil)
            finishTask(4.0);
    }
    else
    {
        if (completion != nil)
            completion();
        if (finishTask != nil)
            finishTask(1.0);
    }
}

- (void)_createSubscription:(TGBridgeSubscription *)subscription replyHandler:(void (^)(NSData *))replyHandler finishTask:(void (^)(NSTimeInterval))finishTask completion:(void (^)(void))completion
{
    SSignal *subscriptionHandler = _handler(subscription);
    if (replyHandler != nil)
    {
        os_unfair_lock_lock(&_replyHandlerMapLock);
        _replyHandlerMap[@(subscription.identifier)] = replyHandler;
        os_unfair_lock_unlock(&_replyHandlerMapLock);
    }
    
    if (subscriptionHandler != nil)
    {
        [_signalManager startSignalForKey:[NSString stringWithFormat:@"%lld", subscription.identifier] producer:^SSignal *
        {
            STimer *timer = [[STimer alloc] initWithTimeout:2.0 repeat:false completion:^
            {
                os_unfair_lock_lock(&_replyHandlerMapLock);
                void (^reply)(NSData *) = _replyHandlerMap[@(subscription.identifier)];
                if (reply == nil)
                {
                    os_unfair_lock_unlock(&_replyHandlerMapLock);
                    
                    if (finishTask != nil)
                        finishTask(2.0);
                    return;
                }
                
                reply([NSData data]);
                [_replyHandlerMap removeObjectForKey:@(subscription.identifier)];
                os_unfair_lock_unlock(&_replyHandlerMapLock);
                
                if (finishTask != nil)
                    finishTask(4.0);
                
                //TGLog(@"[BridgeServer]: subscription 0x%x hit 2.0s timeout, releasing reply handler", subscription.identifier);
            } queue:[SQueue mainQueue]];
            [timer start];
            
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(__unused SSubscriber *subscriber)
            {
                return [subscriptionHandler startWithNext:^(id next)
                {
                    [timer invalidate];
                    [self _responseToSubscription:subscription message:next type:TGBridgeResponseTypeNext completion:completion];
                    
                    if (finishTask != nil)
                        finishTask(4.0);
                } error:^(id error)
                {
                    [timer invalidate];
                    [self _responseToSubscription:subscription message:error type:TGBridgeResponseTypeFailed completion:completion];
                    
                    if (finishTask != nil)
                        finishTask(4.0);
                } completed:^
                {
                    [timer invalidate];
                    [self _responseToSubscription:subscription message:nil type:TGBridgeResponseTypeCompleted completion:completion];
                    
                    if (finishTask != nil)
                        finishTask(4.0);
                }];
            }];
        }];
    }
    else
    {
        os_unfair_lock_lock(&_replyHandlerMapLock);
        void (^reply)(NSData *) = _replyHandlerMap[@(subscription.identifier)];
        if (reply == nil)
        {
            os_unfair_lock_unlock(&_replyHandlerMapLock);
            
            if (finishTask != nil)
                finishTask(2.0);
            return;
        }
        
        reply([NSData data]);
        [_replyHandlerMap removeObjectForKey:@(subscription.identifier)];
        os_unfair_lock_unlock(&_replyHandlerMapLock);
        
        if (finishTask != nil)
            finishTask(2.0);
    }
}

- (void)_responseToSubscription:(TGBridgeSubscription *)subscription message:(id<NSCoding>)message type:(TGBridgeResponseType)type completion:(void (^)(void))completion
{
    TGBridgeResponse *response = nil;
    switch (type)
    {
        case TGBridgeResponseTypeNext:
            response = [TGBridgeResponse single:message forSubscription:subscription];
            break;
            
        case TGBridgeResponseTypeFailed:
            response = [TGBridgeResponse fail:message forSubscription:subscription];
            break;
            
        case TGBridgeResponseTypeCompleted:
            response = [TGBridgeResponse completeForSubscription:subscription];
            break;
            
        default:
            break;
    }
    
    os_unfair_lock_lock(&_replyHandlerMapLock);
    void (^reply)(NSData *) = _replyHandlerMap[@(subscription.identifier)];
    if (reply != nil)
        [_replyHandlerMap removeObjectForKey:@(subscription.identifier)];
    os_unfair_lock_unlock(&_replyHandlerMapLock);
    
    if (_processingNotification)
    {
        [self _enqueueResponse:response forSubscription:subscription];
        
        if (completion != nil)
            completion();
        
        return;
    }
    
    NSData *messageData = [NSKeyedArchiver archivedDataWithRootObject:response];
    if (reply != nil && messageData.length < 64000)
    {
        reply(messageData);
        
        if (completion != nil)
            completion();
    }
    else
    {
        if (reply != nil)
            reply([NSData data]);
        
        if (self.session.isReachable)
        {
            [self.session sendMessageData:messageData replyHandler:nil errorHandler:^(NSError *error)
            {
                 //if (error != nil)
                 //    TGLog(@"[BridgeServer]: send response for subscription %lld failed with error %@", subscription.identifier, error);
            }];
        }
        else
        {
            //TGLog(@"[BridgeServer]: client out of reach, queueing response for subscription %lld", subscription.identifier);
            [self _enqueueResponse:response forSubscription:subscription];
        }
        
        if (completion != nil)
            completion();
    }
}

- (void)_enqueueResponse:(TGBridgeResponse *)response forSubscription:(TGBridgeSubscription *)subscription
{
    os_unfair_lock_lock(&_outgoingQueueLock);
    NSMutableArray *updatedResponses = (_outgoingMessageQueue != nil) ? [_outgoingMessageQueue mutableCopy] : [[NSMutableArray alloc] init];
    
    if (subscription.dropPreviouslyQueued)
    {
        NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
        
        [updatedResponses enumerateObjectsUsingBlock:^(TGBridgeResponse *queuedResponse, NSUInteger index, __unused BOOL *stop)
        {
            if (queuedResponse.subscriptionIdentifier == subscription.identifier)
                [indexSet addIndex:index];
        }];
        
        [updatedResponses removeObjectsAtIndexes:indexSet];
    }
    
    [updatedResponses addObject:response];
    
    _outgoingMessageQueue = updatedResponses;
    os_unfair_lock_unlock(&_outgoingQueueLock);
}

- (void)_sendQueuedResponses
{
    if (_processingNotification)
        return;
    
    os_unfair_lock_lock(&_outgoingQueueLock);
    
    if (_outgoingMessageQueue.count > 0)
    {
        //TGLog(@"[BridgeServer] Sending queued responses");
        
        for (TGBridgeResponse *response in _outgoingMessageQueue)
        {
            NSData *messageData = [NSKeyedArchiver archivedDataWithRootObject:response];
            [self.session sendMessageData:messageData replyHandler:nil errorHandler:nil];
        }
        
        [_outgoingMessageQueue removeAllObjects];
    }
    os_unfair_lock_unlock(&_outgoingQueueLock);
}

- (void)_requestSubscriptionList 
{
    TGBridgeSubscriptionListRequest *request = [[TGBridgeSubscriptionListRequest alloc] initWithSessionId:_sessionId];
    NSData *messageData = [NSKeyedArchiver archivedDataWithRootObject:request];
    [self.session sendMessageData:messageData replyHandler:nil errorHandler:nil];
}

- (void)sendFileWithURL:(NSURL *)url metadata:(NSDictionary *)metadata asMessageData:(bool)asMessageData
{
    //TGLog(@"[BridgeServer] Sent file with metadata %@", metadata);
    if (asMessageData && self.session.isReachable) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        [self sendFileWithData:data metadata:metadata errorHandler:^{
            [self.session transferFile:url metadata:metadata];
        }];
    } else {
        [self.session transferFile:url metadata:metadata];
    }
}

- (void)sendFileWithData:(NSData *)data metadata:(NSDictionary *)metadata errorHandler:(void (^)(void))errorHandler
{
    TGBridgeFile *file = [[TGBridgeFile alloc] initWithData:data metadata:metadata];
    NSData *messageData = [NSKeyedArchiver archivedDataWithRootObject:file];
    [self.session sendMessageData:messageData replyHandler:nil errorHandler:^(NSError *error) {
        if (errorHandler != nil)
            errorHandler();
    }];
}

#pragma mark - Tasks

- (id<SDisposable>)beginTask
{
    int64_t randomId = 0;
    arc4random_buf(&randomId, 8);
    NSNumber *taskId = @(randomId);
    
    _runningTasks[taskId] = @true;
    [_hasRunningTasks set:[SSignal single:@{@"version": @(_tasksVersion++), @"running": @true}]];
    
    SBlockDisposable *taskDisposable = [[SBlockDisposable alloc] initWithBlock:^{
        [_runningTasks removeObjectForKey:taskId];
        [_hasRunningTasks set:[SSignal single:@{@"version": @(_tasksVersion++), @"running": @(_runningTasks.count > 0)}]];
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((4.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dispatch:^{
            [taskDisposable dispose];
        }];
    });
    
    return taskDisposable;
}

#pragma mark - Session Delegate

- (void)handleReceivedData:(NSData *)messageData replyHandler:(void (^)(NSData *))replyHandler
{
    if (messageData.length == 0)
    {
        if (replyHandler != nil)
            replyHandler([NSData data]);
        return;
    }
    
//    __block UIBackgroundTaskIdentifier backgroundTask;
//    backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^
//    {
//        if (replyHandler != nil)
//            replyHandler([NSData data]);
//        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
//    }];
//
    
    [self handleMessageData:messageData task:[self beginTask] replyHandler:replyHandler completion:^{}];
}

- (void)session:(WCSession *)__unused session didReceiveMessageData:(NSData *)messageData
{
    [self dispatch:^{
        [self handleReceivedData:messageData replyHandler:nil];
    }];
}

- (void)session:(WCSession *)__unused session didReceiveMessageData:(NSData *)messageData replyHandler:(void (^)(NSData *))replyHandler
{
    [self dispatch:^{
        [self handleReceivedData:messageData replyHandler:replyHandler];
    }];
}

- (void)session:(WCSession *)__unused session didReceiveFile:(WCSessionFile *)file
{
    NSDictionary *metadata = file.metadata;
    if (metadata == nil || ![metadata[TGBridgeIncomingFileTypeKey] isEqualToString:TGBridgeIncomingFileTypeAudio])
        return;
    
    NSError *error;
    NSURL *tempURL = [NSURL URLWithString:file.fileURL.lastPathComponent relativeToURL:self.temporaryFilesURL];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.temporaryFilesURL.path withIntermediateDirectories:true attributes:nil error:&error];
    [[NSFileManager defaultManager] moveItemAtURL:file.fileURL toURL:tempURL error:&error];
    
    [self dispatch:^{
        _fileHandler(tempURL.path, file.metadata);
    }];
}

- (void)session:(WCSession *)__unused session didFinishFileTransfer:(WCSessionFileTransfer *)__unused fileTransfer error:(NSError *)__unused error
{
    
}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
    
}


- (void)sessionDidBecomeInactive:(nonnull WCSession *)session {
    
}


- (void)sessionDidDeactivate:(nonnull WCSession *)session {
    
}

- (void)sessionWatchStateDidChange:(WCSession *)session
{
    [self dispatch:^{
        if (session.isWatchAppInstalled)
            [self pushContext];
        
        _appInstalled.sink(@(session.isWatchAppInstalled));
    }];
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    NSLog(@"[TGBridgeServer] Reachability changed: %d", session.isReachable);
}

#pragma mark - 

- (NSInteger)wakeupNetwork
{
    return 0;
}

- (void)suspendNetworkIfReady:(NSInteger)token
{
}

#pragma mark -

- (WCSession *)session
{
    return [WCSession defaultSession];
}

@end


@interface TGBridgeSignalManager()
{
    os_unfair_lock _lock;
    NSMutableDictionary *_disposables;
}
@end

@implementation TGBridgeSignalManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _disposables = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    NSArray *disposables = nil;
    os_unfair_lock_lock(&_lock);
    disposables = [_disposables allValues];
    os_unfair_lock_unlock(&_lock);
    
    for (id<SDisposable> disposable in disposables)
    {
        [disposable dispose];
    }
}

- (bool)startSignalForKey:(NSString *)key producer:(SSignal *(^)())producer
{
    if (key == nil)
        return false;
    
    bool produce = false;
    os_unfair_lock_lock(&_lock);
    if (_disposables[key] == nil)
    {
        _disposables[key] = [[SMetaDisposable alloc] init];
        produce = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (produce)
    {
        __weak TGBridgeSignalManager *weakSelf = self;
        id<SDisposable> disposable = [producer() startWithNext:nil error:^(__unused id error)
        {
            __strong TGBridgeSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                os_unfair_lock_lock(&strongSelf->_lock);
                [strongSelf->_disposables removeObjectForKey:key];
                os_unfair_lock_unlock(&strongSelf->_lock);
            }
        } completed:^
        {
            __strong TGBridgeSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                os_unfair_lock_lock(&strongSelf->_lock);
                [strongSelf->_disposables removeObjectForKey:key];
                os_unfair_lock_unlock(&strongSelf->_lock);
            }
        }];
        
        os_unfair_lock_lock(&_lock);
        [(SMetaDisposable *)_disposables[key] setDisposable:disposable];
        os_unfair_lock_unlock(&_lock);
    }
    
    return produce;
}

- (void)haltSignalForKey:(NSString *)key
{
    if (key == nil)
        return;
    
    os_unfair_lock_lock(&_lock);
    if (_disposables[key] != nil)
    {
        [_disposables[key] dispose];
        [_disposables removeObjectForKey:key];
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)haltAllSignals
{
    os_unfair_lock_lock(&_lock);
    for (NSObject <SDisposable> *disposable in _disposables.allValues)
        [disposable dispose];
    [_disposables removeAllObjects];
    os_unfair_lock_unlock(&_lock);
}

@end
