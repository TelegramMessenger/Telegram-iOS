#import "TGBridgeClient.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"

#import <WatchConnectivity/WatchConnectivity.h>

#import "TGFileCache.h"

#import "TGBridgeStickersSignals.h"
#import "TGBridgePresetsSignals.h"

#import "TGExtensionDelegate.h"

#import <libkern/OSAtomic.h>

NSString *const TGBridgeContextDomain = @"com.telegram.BridgeContext";

const NSTimeInterval TGBridgeClientTimerInterval = 4.0;
const NSTimeInterval TGBridgeClientWakeInterval = 2.0;

@interface TGBridgeClient () <WCSessionDelegate>
{
    int32_t _sessionId;
    bool _reachable;
    
    bool _processingNotification;
    
    SMulticastSignalManager *_signalManager;
    SMulticastSignalManager *_fileSignalManager;
    SVariable *_context;

    SPipe *_actualReachabilityPipe;
    SPipe *_reachabilityPipe;
    
    SPipe *_userInfoPipe;
    
    dispatch_queue_t _contextQueue;
    
    OSSpinLock _outgoingQueueLock;
    NSMutableArray *_outgoingMessageQueue;
    
    NSArray *_stickerPacks;
    OSSpinLock _stickerPacksLock;
    
    NSMutableDictionary *_subscriptions;
    
    NSTimeInterval _lastForegroundEntry;
    STimer *_timer;
    
    bool _sentFirstPing;
    bool _isActive;
}

@property (nonatomic, readonly) WCSession *session;

@end

@implementation TGBridgeClient

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        int32_t sessionId = 0;
        arc4random_buf(&sessionId, sizeof(int32_t));
        _sessionId = sessionId;
        
        _contextQueue = dispatch_queue_create(TGBridgeContextDomain.UTF8String, nil);
        
        _signalManager = [[SMulticastSignalManager alloc] init];
        _fileSignalManager = [[SMulticastSignalManager alloc] init];
        _context = [[SVariable alloc] init];
        _userInfoPipe = [[SPipe alloc] init];
        _actualReachabilityPipe = [[SPipe alloc] init];
        _reachabilityPipe = [[SPipe alloc] init];
        _reachable = true;
        
        _outgoingMessageQueue = [[NSMutableArray alloc] init];
        _subscriptions = [[NSMutableDictionary alloc] init];

        self.session.delegate = self;
        [self.session activateSession];
        
        TGLog(@"BridgeClient: initialized");
        
        [self ping];
    }
    return self;
}

- (void)transferUserInfo:(NSDictionary *)userInfo
{
    [self.session transferUserInfo:userInfo];
}

- (SSignal *)requestSignalWithSubscription:(TGBridgeSubscription *)subscription
{
    if (!_sentFirstPing)
        [self ping];
    
    NSData *messageData = [NSKeyedArchiver archivedDataWithRootObject:subscription];
    void (^transcribe)(id, SSubscriber *, bool *) = ^(id message, SSubscriber *subscriber, bool *completed)
    {
        NSLog(@"BridgeClient: received %p %@", subscription, NSStringFromClass(subscription.class));
        
        TGBridgeResponse *response = nil;
        if ([message isKindOfClass:[TGBridgeResponse class]])
        {
            response = message;
        }
        else if ([message isKindOfClass:[NSData class]])
        {
            @try
            {
                id unarchivedMessage = [NSKeyedUnarchiver unarchiveObjectWithData:message];
                if ([unarchivedMessage isKindOfClass:[TGBridgeResponse class]])
                    response = (TGBridgeResponse *)unarchivedMessage;
            }
            @catch (NSException *exception)
            {

            }
        }
        
        if (response == nil)
            return;
        
        switch (response.type)
        {
            case TGBridgeResponseTypeNext:
                [subscriber putNext:response.next];
                break;
                
            case TGBridgeResponseTypeFailed:
                [subscriber putError:response.error];
                break;
                
            case TGBridgeResponseTypeCompleted:
                if (completed != NULL)
                    *completed = true;
                
                [subscriber putCompletion];
                break;
                
            default:
                break;
        }
    };
    
    __weak TGBridgeClient *weakSelf = self;
    return [[[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSLog(@"BridgeClient: requestSub %p %@", subscription, NSStringFromClass(subscription.class));
        
        SDisposableSet *combinedDisposable = [[SDisposableSet alloc] init];
        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        
        __block bool completed = false;
        [combinedDisposable add:currentDisposable];
        
        void (^afterSendMessage)(void) = ^
        {
            __strong TGBridgeClient *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [combinedDisposable add:[[strongSelf->_signalManager multicastedPipeForKey:[NSString stringWithFormat:@"%lld", subscription.identifier]] startWithNext:^(id next)
            {
                transcribe(next, subscriber, NULL);
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        };
        
        [currentDisposable setDisposable:[[[self sendMessageData:messageData] onStart:^
        {
            __strong TGBridgeClient *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_subscriptions[@(subscription.identifier)] = subscription;
        }] startWithNext:^(id next)
        {
            __strong TGBridgeClient *strongSelf = weakSelf;
            if (strongSelf != nil)
                transcribe(next, subscriber, &completed);
        } error:^(NSError *error)
        {
            if ([error isKindOfClass:[NSError class]] && error.domain == WCErrorDomain)
            {
                __strong TGBridgeClient *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf _enqueueMessage:messageData];
                
                afterSendMessage();
            }
            else
            {
                [subscriber putError:error];
            }
        } completed:^
        {
            if (completed)
                return;
            
            afterSendMessage();
        }]];
        
        return combinedDisposable;
    }] onCompletion:^
    {
        __strong TGBridgeClient *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_subscriptions removeObjectForKey:@(subscription.identifier)];
    }] onDispose:^
    {
        __strong TGBridgeClient *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf->_subscriptions removeObjectForKey:@(subscription.identifier)];
            [strongSelf unsubscribe:subscription.identifier];
        }
    }];
}

- (void)unsubscribe:(int64_t)identifier
{
    TGBridgeDisposal *disposal = [[TGBridgeDisposal alloc] initWithIdentifier:identifier];
    NSData *message = [NSKeyedArchiver archivedDataWithRootObject:disposal];
    [self.session sendMessageData:message replyHandler:nil errorHandler:^(NSError *error)
    {
        [self _logError:error];
    }];
}

- (SSignal *)sendMessageData:(NSData *)messageData
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [self.session sendMessageData:messageData replyHandler:^(NSData *replyMessageData)
        {
            if (replyMessageData.length > 0)
                [subscriber putNext:replyMessageData];
            [subscriber putCompletion];
        } errorHandler:^(NSError * _Nonnull error)
        {
            [self _logError:error];
            [subscriber putError:error];
        }];
        return nil;
    }];
}

- (void)sendRawMessageData:(NSData *)messageData replyHandler:(void (^)(NSData *))replyHandler errorHandler:(void (^)(NSError *))errorHandler
{
    [self.session sendMessageData:messageData replyHandler:replyHandler errorHandler:errorHandler];
}

#pragma mark -

- (SSignal *)contextSignal
{
    return _context.signal;
}

#pragma mark -

- (SSignal *)fileSignalForKey:(NSString *)key
{
    return [_fileSignalManager multicastedPipeForKey:key];
}

- (void)sendFileWithURL:(NSURL *)url metadata:(NSDictionary *)metadata
{
    [self.session transferFile:url metadata:metadata];
}

#pragma mark - 

- (NSArray *)stickerPacks
{
    OSSpinLockLock(&_stickerPacksLock);
    if (_stickerPacks != nil)
    {
        NSArray *stickerPacks = [_stickerPacks copy];
        OSSpinLockUnlock(&_stickerPacksLock);

        return stickerPacks;
    }
    else
    {
        NSArray *stickerPacks = [self readStickerPacks];
        if (stickerPacks == nil)
            stickerPacks = [NSArray array];
        
        _stickerPacks = stickerPacks;
    
        OSSpinLockUnlock(&_stickerPacksLock);
        
        return stickerPacks;
    }
}

- (NSArray *)readStickerPacks
{
    NSURL *url = [TGBridgeStickersSignals stickerPacksURL];
    
    NSData *data = [[NSData alloc] initWithContentsOfURL:url];
    if (data == nil)
        return nil;
    
    NSArray *stickerPacks = nil;
    @try
    {
        stickerPacks = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (NSException *exception)
    {
        
    }
    
    if (![stickerPacks isKindOfClass:[NSArray class]])
        return nil;
    
    return stickerPacks;
}

#pragma mark - 

- (void)session:(WCSession *)session didReceiveMessageData:(NSData *)messageData
{
    [self handleReceivedData:messageData replyHandler:nil];
}

- (void)session:(WCSession *)session didReceiveMessageData:(NSData *)messageData replyHandler:(nonnull void (^)(NSData * _Nonnull))replyHandler
{
    [self handleReceivedData:messageData replyHandler:replyHandler];
}

- (void)handleReceivedData:(NSData *)messageData replyHandler:(void (^)(NSData *))replyHandler
{
    id message =  nil;
    @try
    {
        message = [NSKeyedUnarchiver unarchiveObjectWithData:messageData];
    }
    @catch (NSException *exception)
    {
        
    }
    
    if ([message isKindOfClass:[TGBridgeResponse class]])
    {
        TGBridgeResponse *response = (TGBridgeResponse *)message;
        [_signalManager putNext:response toMulticastedPipeForKey:[NSString stringWithFormat:@"%lld", response.subscriptionIdentifier]];
    }
    else if ([message isKindOfClass:[TGBridgeSubscriptionListRequest class]])
    {
        [self refreshSubscriptions];
    }
    else if ([message isKindOfClass:[TGBridgeFile class]])
    {
        TGBridgeFile *file = (TGBridgeFile *)message;
        
        NSString *type = file.metadata[TGBridgeIncomingFileTypeKey];
        NSString *identifier = file.metadata[TGBridgeIncomingFileIdentifierKey];
        if (identifier == nil)
            return;
        
        if ([type isEqualToString:TGBridgeIncomingFileTypeImage])
        {
            NSLog(@"Received message image file: %@", identifier);
            [[TGExtensionDelegate instance].imageCache cacheData:file.data key:identifier synchronous:true unserializeBlock:^id(NSData *data)
            {
                return data;
            } completion:^(NSURL *url)
            {
                [_fileSignalManager putNext:url toMulticastedPipeForKey:identifier];
            }];
        }
    }
}

- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary *)applicationContext
{
    TGBridgeContext *context = [[TGBridgeContext alloc] initWithDictionary:applicationContext];
    [_context set:[SSignal single:context]];
}

- (void)session:(WCSession *)session didReceiveFile:(WCSessionFile *)file
{
    NSString *type = file.metadata[TGBridgeIncomingFileTypeKey];
    NSString *identifier = file.metadata[TGBridgeIncomingFileIdentifierKey];
    if (identifier == nil)
        return;
    
    if ([identifier isEqualToString:@"stickers"])
    {
        NSURL *stickerPacksURL = [TGBridgeStickersSignals stickerPacksURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:stickerPacksURL.path])
            [[NSFileManager defaultManager] removeItemAtURL:stickerPacksURL error:nil];
        
        [[NSFileManager defaultManager] moveItemAtURL:file.fileURL toURL:stickerPacksURL error:nil];
        
        NSArray *stickerPacks = [self readStickerPacks];
        OSSpinLockLock(&_stickerPacksLock);
        _stickerPacks = stickerPacks;
        OSSpinLockUnlock(&_stickerPacksLock);
        
        [_fileSignalManager putNext:stickerPacks toMulticastedPipeForKey:identifier];
    }
    else if ([identifier isEqualToString:@"localization"])
    {
        [[TGExtensionDelegate instance] setCustomLocalizationFile:file.fileURL];
    }
    else if ([identifier isEqualToString:@"presets"])
    {
        NSURL *presetsURL = [TGBridgePresetsSignals presetsURL];
        if ([[NSFileManager defaultManager] fileExistsAtPath:presetsURL.path])
            [[NSFileManager defaultManager] removeItemAtURL:presetsURL error:nil];
        
        [[NSFileManager defaultManager] moveItemAtURL:file.fileURL toURL:presetsURL error:nil];
    }
    else if ([type isEqualToString:TGBridgeIncomingFileTypeImage])
    {
        NSLog(@"Received image file: %@", identifier);
        [[TGExtensionDelegate instance].imageCache cacheFileAtURL:file.fileURL key:identifier synchronous:true unserializeBlock:^id(NSData *data)
        {
            return data;
        } completion:^(NSURL *url)
        {
            [_fileSignalManager putNext:url toMulticastedPipeForKey:identifier];
        }];
    }
    else if ([type isEqualToString:TGBridgeIncomingFileTypeAudio])
    {
        NSLog(@"Received audio file: %@", identifier);
        [[TGExtensionDelegate instance].audioCache cacheFileAtURL:file.fileURL key:identifier synchronous:true unserializeBlock:nil completion:^(NSURL *url)
        {
            [_fileSignalManager putNext:url toMulticastedPipeForKey:identifier];
        }];
    }
}

- (void)sessionReachabilityDidChange:(WCSession *)session
{
    bool reachable = session.isReachable;
    if (!reachable)
    {
        TGDispatchAfter(4.5, dispatch_get_main_queue(), ^
        {
            bool newReachable = session.isReachable;
            if (newReachable == reachable && newReachable != _reachable)
            {
                _reachable = newReachable;
                _reachabilityPipe.sink(@(newReachable));
            }
        });
    }
    else if (_reachable != reachable)
    {
        _reachable = reachable;
        _reachabilityPipe.sink(@(reachable));
        
        [self ping];
    }
    
    if (reachable && !_processingNotification)
        [self sendQueuedMessages];
}

- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *,id> *)userInfo
{
    _userInfoPipe.sink(userInfo);
}

- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
    if (activationState == WCSessionActivationStateActivated) {
        TGBridgeContext *context = [[TGBridgeContext alloc] initWithDictionary:session.receivedApplicationContext];
        [_context set:[SSignal single:context]];
    } else {
         TGLog(@"[BridgeClient] inactive session state");
    }
}


- (SSignal *)userInfoSignal
{
    return _userInfoPipe.signalProducer();
}

#pragma mark - 

- (void)_enqueueMessage:(NSData *)message
{
    TGLog(@"[BridgeClient] Enqued failed message");
    
    OSSpinLockLock(&_outgoingQueueLock);
    [_outgoingMessageQueue addObject:message];
    OSSpinLockUnlock(&_outgoingQueueLock);
}

- (void)sendQueuedMessages
{
    OSSpinLockLock(&_outgoingQueueLock);
    
    if (_outgoingMessageQueue.count > 0)
    {
        TGLog(@"[BridgeClient] Sending queued messages");
        
        for (NSData *messageData in _outgoingMessageQueue)
            [self.session sendMessageData:messageData replyHandler:nil errorHandler:nil];
        
        [_outgoingMessageQueue removeAllObjects];
    }
    OSSpinLockUnlock(&_outgoingQueueLock);
}

#pragma mark -

- (void)ping
{
    if (!_isActive || _processingNotification)
        return;
    
    TGBridgePing *ping = [[TGBridgePing alloc] initWithSessionId:_sessionId];
    NSData *message = [NSKeyedArchiver archivedDataWithRootObject:ping];
    [self.session sendMessageData:message replyHandler:^(NSData *replyData)
    {
        _sentFirstPing = true;
    } errorHandler:^(NSError *error)
    {
        [self _logError:error];
    }];
}

- (void)refreshSubscriptions
{
    NSArray *activeSubscriptions = [_subscriptions allValues];
    NSMutableArray *subscriptions = [[NSMutableArray alloc] init];
    for (TGBridgeSubscription *subscription in activeSubscriptions)
    {
        if (subscription.renewable)
            [subscriptions addObject:subscription];
    }
    
    TGBridgeSubscriptionList *subscriptionsList = [[TGBridgeSubscriptionList alloc] initWithArray:subscriptions];
    NSData *message = [NSKeyedArchiver archivedDataWithRootObject:subscriptionsList];
    [self.session sendMessageData:message replyHandler:nil errorHandler:^(NSError *error)
    {
        [self _logError:error];
    }];
}

#pragma mark -

- (void)handleDidBecomeActive
{
    _isActive = true;

    NSTimeInterval currentTime = [[NSDate date] timeIntervalSinceReferenceDate];
    if (_lastForegroundEntry == 0 || currentTime - _lastForegroundEntry > TGBridgeClientWakeInterval)
    {
        if (_lastForegroundEntry != 0)
            [self ping];
        
        _lastForegroundEntry = currentTime;
    }
    
    if (_timer == nil)
    {
        __weak TGBridgeClient *weakSelf = self;
        NSTimeInterval interval = _lastForegroundEntry == 0 ? TGBridgeClientTimerInterval : MAX(MIN(TGBridgeClientTimerInterval - currentTime - _lastForegroundEntry, TGBridgeClientTimerInterval), 1);
        
        __block void (^completion)(void) = ^
        {
            __strong TGBridgeClient *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf ping];
            
            strongSelf->_lastForegroundEntry = [[NSDate date] timeIntervalSinceReferenceDate];
            strongSelf->_timer = [[STimer alloc] initWithTimeout:TGBridgeClientTimerInterval repeat:false completion:completion queue:[SQueue mainQueue]];
            [strongSelf->_timer start];
        };
        
        _timer = [[STimer alloc] initWithTimeout:interval repeat:false completion:completion queue:[SQueue mainQueue]];
        [_timer start];
    }
}

- (void)handleWillResignActive
{
    _isActive = false;
    
    [_timer invalidate];
    _timer = nil;
}

#pragma mark -

- (void)updateReachability
{
    if (self.session.isReachable && !_reachable)
        _reachable = true;
}

- (bool)isServerReachable
{
    return _reachable;
}

- (bool)isActuallyReachable
{
    return self.session.isReachable;
}

- (SSignal *)actualReachabilitySignal
{
    return [[SSignal single:@(self.session.isReachable)] then:_actualReachabilityPipe.signalProducer()];
}

- (SSignal *)reachabilitySignal
{
    return [[SSignal single:@(self.session.isReachable)] then:_reachabilityPipe.signalProducer()];
}

- (void)_logError:(NSError *)error
{
    NSLog(@"%@", error);
}

#pragma mark -

- (WCSession *)session
{
    return [WCSession defaultSession];
}

+ (instancetype)instance
{
    static dispatch_once_t onceToken;
    static TGBridgeClient *instance;
    dispatch_once(&onceToken, ^
    {
        instance = [[TGBridgeClient alloc] init];
    });
    return instance;
}

@end
