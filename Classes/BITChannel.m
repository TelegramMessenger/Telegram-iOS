#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "HockeySDKPrivate.h"
#import "BITHockeyManager.h"
#import "BITChannelPrivate.h"
#import "BITHockeyHelper.h"
#import "BITTelemetryContext.h"
#import "BITTelemetryData.h"
#import "BITEnvelope.h"
#import "BITData.h"
#import "BITDevice.h"
#import "BITPersistencePrivate.h"
#import "BITSender.h"
#import <libkern/OSAtomic.h>


static char *const BITDataItemsOperationsQueue = "net.hockeyapp.senderQueue";
char *BITTelemetryEventBuffer;

NSString *const BITChannelBlockedNotification = @"BITChannelBlockedNotification";

static NSInteger const BITDefaultMaxBatchSize  = 50;
static NSInteger const BITDefaultBatchInterval = 15;
static NSInteger const BITSchemaVersion = 2;

static NSInteger const BITDebugMaxBatchSize = 5;
static NSInteger const BITDebugBatchInterval = 3;

NS_ASSUME_NONNULL_BEGIN

@interface BITChannel ()

@property (nonatomic, weak, nullable) id appDidEnterBackgroundObserver;
@property (nonatomic, weak, nullable) id persistenceSuccessObserver;
@property (nonatomic, weak, nullable) id senderFinishSendingDataObserver;

@property (nonatomic, nonnull) dispatch_group_t senderGroup;

@end

@implementation BITChannel

@synthesize persistence = _persistence;
@synthesize channelBlocked = _channelBlocked;

#pragma mark - Initialisation

- (instancetype)init {
  if ((self = [super init])) {
    bit_resetEventBuffer(&BITTelemetryEventBuffer);
    _dataItemCount = 0;
    if (bit_isDebuggerAttached()) {
      _maxBatchSize = BITDebugMaxBatchSize;
      _batchInterval = BITDebugBatchInterval;
    } else {
      _maxBatchSize = BITDefaultMaxBatchSize;
      _batchInterval = BITDefaultBatchInterval;
    }
    dispatch_queue_t serialQueue = dispatch_queue_create(BITDataItemsOperationsQueue, DISPATCH_QUEUE_SERIAL);
    _dataItemsOperations = serialQueue;
    
    _senderGroup = dispatch_group_create();
    
    [self registerObservers];
  }
  return self;
}

- (instancetype)initWithTelemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *)persistence {
  if ((self = [self init])) {
    _telemetryContext = telemetryContext;
    _persistence = persistence;
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
  [self invalidateTimer];
}

#pragma mark - Observers

- (void) registerObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;
  
  if (nil == self.appDidEnterBackgroundObserver) {
    void (^notificationBlock)(NSNotification *note) = ^(NSNotification __unused *note) {
      typeof(self) strongSelf = weakSelf;
      if ([strongSelf timerIsRunning]) {
        
        /**
         * From the documentation for applicationDidEnterBackground:
         * It's likely any background tasks you start in applicationDidEnterBackground: will not run until after that method exits,
         * you should request additional background execution time before starting those tasks. In other words,
         * first call beginBackgroundTaskWithExpirationHandler: and then run the task on a dispatch queue or secondary thread.
         */
        UIApplication *application = [UIApplication sharedApplication];
        [strongSelf persistDataItemQueueWithBackgroundTask: application];
      }
    };
    self.appDidEnterBackgroundObserver = [center addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                             object:nil
                                                              queue:NSOperationQueue.mainQueue
                                                         usingBlock:notificationBlock];
  }
  if (nil == self.persistenceSuccessObserver) {
    self.persistenceSuccessObserver =
        [center addObserverForName:BITPersistenceSuccessNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification __unused *notification) {
                          typeof(self) strongSelf = weakSelf;
                          dispatch_group_enter(strongSelf.senderGroup);
                        }];
  }
  if (nil == self.senderFinishSendingDataObserver) {
    self.senderFinishSendingDataObserver =
        [center addObserverForName:BITSenderFinishSendingDataNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification __unused *notification) {
                          typeof(self) strongSelf = weakSelf;
                          dispatch_group_leave(strongSelf.senderGroup);
                        }];
  }
}

- (void) unregisterObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  id appDidEnterBackgroundObserver = self.appDidEnterBackgroundObserver;
  if (appDidEnterBackgroundObserver) {
    [center removeObserver:appDidEnterBackgroundObserver];
    self.appDidEnterBackgroundObserver = nil;
  }
  id persistenceSuccessObserver = self.persistenceSuccessObserver;
  if (persistenceSuccessObserver) {
    [center removeObserver:persistenceSuccessObserver];
    self.persistenceSuccessObserver = nil;
  }
  id senderFinishSendingDataObserver = self.senderFinishSendingDataObserver;
  if (senderFinishSendingDataObserver) {
    [center removeObserver:senderFinishSendingDataObserver];
    self.senderFinishSendingDataObserver = nil;
  }
}

#pragma mark - Queue management

- (BOOL)isQueueBusy {
  if (!self.channelBlocked) {
    BOOL persistenceBusy = ![self.persistence isFreeSpaceAvailable];
    if (persistenceBusy) {
      self.channelBlocked = YES;
      [self sendBlockingChannelNotification];
    }
  }
  return self.channelBlocked;
}

- (void)persistDataItemQueue:(char **)eventBuffer {
  [self invalidateTimer];
  
  // Make sure string (which points to BITTelemetryEventBuffer) is not changed.
  char *previousBuffer = NULL;
  char *newEmptyString = NULL;
  do {
    newEmptyString = strdup("");
    previousBuffer = *eventBuffer;
    
    // This swaps pointers and makes sure eventBuffer now has the balue of newEmptyString.
    if (OSAtomicCompareAndSwapPtr(previousBuffer, newEmptyString, (void*)eventBuffer)) {
      @synchronized(self) {
        self.dataItemCount = 0;
      }
      break;
    }
  } while(true);
  
  // Nothing to persist, freeing memory and existing.
  if (!previousBuffer || strlen(previousBuffer) == 0) {
    free(previousBuffer);
    return;
  }
  
  // Persist the data
  NSData *bundle = [NSData dataWithBytes:previousBuffer length:strlen(previousBuffer)];
  [self.persistence persistBundle:bundle];
  free(previousBuffer);
  
  // Reset both, the async-signal-safe and item counter.
  [self resetQueue];
}

- (void)persistDataItemQueueWithBackgroundTask:(UIApplication *)application {
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.dataItemsOperations, ^{
    typeof(self) strongSelf = weakSelf;
    [strongSelf persistDataItemQueue:&BITTelemetryEventBuffer];
  });
  [self createBackgroundTask:application withWaitingGroup:nil];
}

- (void)createBackgroundTask:(UIApplication *)application withWaitingGroup:(nullable dispatch_group_t)group {
  if (application == nil) {
    return;
  }
  NSArray *queues = @[
                      self.dataItemsOperations,           // For enqueue
                      self.persistence.persistenceQueue,  // For persist
                      dispatch_get_main_queue()           // For notification
                      ];
  BITHockeyLogVerbose(@"BITChannel: Start background task");
  __block UIBackgroundTaskIdentifier backgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
    BITHockeyLogVerbose(@"BITChannel: Background task is expired");
    [application endBackgroundTask:backgroundTask];
    backgroundTask = UIBackgroundTaskInvalid;
  }];
  __block NSUInteger i = 0;
  __weak typeof(self) weakSelf = self;
  __block __weak void (^weakWaitBlock)(void);
  void (^waitBlock)(void);
  weakWaitBlock = waitBlock = ^{
    typeof(self) strongSelf = weakSelf;
    if (i < queues.count) {
      dispatch_queue_t queue = [queues objectAtIndex:i++];
      BITHockeyLogVerbose(@"BITChannel: Waiting queue: %@", [[NSString alloc] initWithUTF8String:dispatch_queue_get_label(queue)]);
      dispatch_async(queue, weakWaitBlock);
    } else {
      BITHockeyLogVerbose(@"BITChannel: Waiting sender");
      dispatch_group_notify(strongSelf.senderGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (backgroundTask != UIBackgroundTaskInvalid) {
          BITHockeyLogVerbose(@"BITChannel: Cancel background task");
          [application endBackgroundTask:backgroundTask];
          backgroundTask = UIBackgroundTaskInvalid;
        }
      });
    }
  };
  if (group != nil) {
    BITHockeyLogVerbose(@"BITChannel: Waiting group");
    dispatch_group_notify((dispatch_group_t)group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), waitBlock);
  } else {
    waitBlock();
  }
}

// Resets the event buffer and count of events in the queue.
- (void)resetQueue {
  @synchronized (self) {
    bit_resetEventBuffer(&BITTelemetryEventBuffer);
    self.dataItemCount = 0;
  }
}

#pragma mark - Adding to queue

- (void)enqueueTelemetryItem:(BITTelemetryData *)item {
  
  if (!item) {
    
    // Item is nil: Do not enqueue item and abort operation.
    BITHockeyLogWarning(@"WARNING: TelemetryItem was nil.");
    return;
  }
  
  // First assigning self to weakSelf and then assigning this to strongSelf in the block is not very intuitive, this
  // blog post explains it very well: https://dhoerl.wordpress.com/2013/04/23/i-finally-figured-out-weakself-and-strongself/
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.dataItemsOperations, ^{
    
    typeof(self) strongSelf = weakSelf;
    if (strongSelf.isQueueBusy) {
      
      // Case 1: Channel is in blocked state: Trigger sender, start timer to check after again after a while and abort operation.
      BITHockeyLogDebug(@"INFO: The channel is saturated. %@ was dropped.", item.debugDescription);
      if (![strongSelf timerIsRunning]) {
        [strongSelf startTimer];
      }
      return;
    }
    
    // Enqueue item.
    @synchronized(self) {
      NSDictionary *dict = [strongSelf dictionaryForTelemetryData:item];
      [strongSelf appendDictionaryToEventBuffer:dict];
      UIApplication *application = [UIApplication sharedApplication];
      UIApplicationState state = [self checkApplicationStateForApplication:application];
      if (strongSelf.dataItemCount >= strongSelf.maxBatchSize ||
         (application && state == UIApplicationStateBackground)) {
        
        // Case 2: Max batch count has been reached or the app is running in the background, so write queue to disk and delete all items.
        [strongSelf persistDataItemQueue:&BITTelemetryEventBuffer];
      } else if (strongSelf.dataItemCount > 0) {
        
        // Case 3: It is the first item, let's start the timer.
        if (![strongSelf timerIsRunning]) {
          [strongSelf startTimer];
        }
      }
    }
  });
}

- (UIApplicationState)checkApplicationStateForApplication:(UIApplication *)application {
  __block UIApplicationState state;
  dispatch_async(dispatch_get_main_queue(), ^{
    state = application.applicationState;
  });
  
  return state;
}

#pragma mark - Envelope telemerty items

- (NSDictionary *)dictionaryForTelemetryData:(BITTelemetryData *) telemetryData {
  
  BITEnvelope *envelope = [self envelopeForTelemetryData:telemetryData];
  NSDictionary *dict = [envelope serializeToDictionary];
  return dict;
}

- (BITEnvelope *)envelopeForTelemetryData:(BITTelemetryData *)telemetryData {
  telemetryData.version = @(BITSchemaVersion);
  
  BITData *data = [BITData new];
  data.baseData = telemetryData;
  data.baseType = telemetryData.dataTypeName;
  
  BITEnvelope *envelope = [BITEnvelope new];
  envelope.time = bit_utcDateString([NSDate date]);
  envelope.iKey = self.telemetryContext.appIdentifier;
  
  envelope.tags = self.telemetryContext.contextDictionary;
  envelope.data = data;
  envelope.name = telemetryData.envelopeTypeName;
  
  return envelope;
}

#pragma mark - Serialization Helper

- (NSString *)serializeDictionaryToJSONString:(NSDictionary *)dictionary {
  NSError *error;
  NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:(NSJSONWritingOptions)0 error:&error];
  if (!data) {
    BITHockeyLogError(@"ERROR: JSONSerialization error: %@", error.localizedDescription);
    return @"{}";
  } else {
    return (NSString *)[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  }
}

#pragma mark JSON Stream

- (void)appendDictionaryToEventBuffer:(NSDictionary *)dictionary {
  if (dictionary) {
    NSString *string = [self serializeDictionaryToJSONString:dictionary];
    
    // Since we can't persist every event right away, we write it to a simple C string.
    // This can then be written to disk by a signal handler in case of a crash.
    @synchronized (self) {
      bit_appendStringToEventBuffer(string, &BITTelemetryEventBuffer);
      self.dataItemCount += 1;
    }
    
    BITHockeyLogVerbose(@"VERBOSE: Appended data to buffer:\n%@", string);
  }
}

void bit_appendStringToEventBuffer(NSString *string, char **eventBuffer) {
  if (eventBuffer == NULL) {
    return;
  }
  
  if (!string) {
    return;
  }
  
  if (*eventBuffer == NULL || strlen(*eventBuffer) == 0) {
    bit_resetEventBuffer(eventBuffer);
  }
  
  if (string.length == 0) {
    return;
  }
  
  do {
    char *newBuffer = NULL;
    char *previousBuffer = *eventBuffer;
    
    // Concatenate old string with new JSON string and add a comma.
    asprintf(&newBuffer, "%s%.*s\n", previousBuffer, (int)MIN(string.length, (NSUInteger)INT_MAX), string.UTF8String);
    
    // Compare newBuffer and previousBuffer. If they point to the same address, we are safe to use them.
    if (OSAtomicCompareAndSwapPtr(previousBuffer, newBuffer, (void*)eventBuffer)) {
 
      // Free the intermediate pointer.
      free(previousBuffer);
      return;
    } else {
      
      // newBuffer has been changed by another thread.
      free(newBuffer);
    }
  } while (true);
}

void bit_resetEventBuffer(char **eventBuffer) {
  if (!eventBuffer) { return; }
  
  char *newEmptyString = NULL;
  char *prevString = NULL;
  do {
    prevString = *eventBuffer;
    newEmptyString = strdup("");
    
    // Compare pointers to strings to make sure we are still threadsafe!
    if (OSAtomicCompareAndSwapPtr(prevString, newEmptyString, (void*)eventBuffer)) {
      free(prevString);
      return;
    }
  } while(true);
}

#pragma mark - Batching

- (NSUInteger)maxBatchSize {
  if(_maxBatchSize <= 0){
    return BITDefaultMaxBatchSize;
  }
  return _maxBatchSize;
}

- (void)invalidateTimer {
  @synchronized(self) {
    if (self.timerSource != nil) {
      dispatch_source_cancel((dispatch_source_t)self.timerSource);
      self.timerSource = nil;
    }
  }
}

-(BOOL)timerIsRunning {
  @synchronized(self) {
    return self.timerSource != nil;
  }
}

- (void)startTimer {
  @synchronized(self) {

    // Reset timer, if it is already running.
    [self invalidateTimer];
    
    dispatch_source_t timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.dataItemsOperations);
    dispatch_source_set_timer(timerSource, dispatch_walltime(NULL, NSEC_PER_SEC * self.batchInterval), 1ull * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timerSource, ^{
      typeof(self) strongSelf = weakSelf;
      if (strongSelf) {
        if (strongSelf.dataItemCount > 0) {
          [strongSelf persistDataItemQueue:&BITTelemetryEventBuffer];
        } else {
          strongSelf.channelBlocked = NO;
        }
        [strongSelf invalidateTimer];
      }
    });
    dispatch_resume(timerSource);
    self.timerSource = timerSource;
  }
}

/**
 * Send a BITHockeyBlockingChannelNotification to the main thread to notify observers that channel can't enqueue new items.
 * This is typically used to trigger sending.
 */
- (void)sendBlockingChannelNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    BITHockeyLogDebug(@"Sending notification: %@", BITChannelBlockedNotification);
    [[NSNotificationCenter defaultCenter] postNotificationName:BITChannelBlockedNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */

