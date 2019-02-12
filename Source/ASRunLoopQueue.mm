//
//  ASRunLoopQueue.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>
#import <AsyncDisplayKit/ASLog.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>
#import <AsyncDisplayKit/ASRunLoopQueue.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASSignpost.h>
#import <QuartzCore/QuartzCore.h>
#import <cstdlib>
#import <deque>
#import <vector>

#define ASRunLoopQueueLoggingEnabled 0
#define ASRunLoopQueueVerboseLoggingEnabled 0

static void runLoopSourceCallback(void *info) {
  // No-op
#if ASRunLoopQueueVerboseLoggingEnabled
  NSLog(@"<%@> - Called runLoopSourceCallback", info);
#endif
}

#pragma mark - ASDeallocQueue

@implementation ASDeallocQueue {
  std::vector<CFTypeRef> _queue;
  ASDN::Mutex _lock;
}

+ (ASDeallocQueue *)sharedDeallocationQueue NS_RETURNS_RETAINED
{
  static ASDeallocQueue *deallocQueue = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    deallocQueue = [[ASDeallocQueue alloc] init];
  });
  return deallocQueue;
}

- (void)dealloc
{
  ASDisplayNodeFailAssert(@"Singleton should not dealloc.");
}

- (void)releaseObjectInBackground:(id  _Nullable __strong *)objectPtr
{
  NSParameterAssert(objectPtr != NULL);
  
  // Cast to CFType so we can manipulate retain count manually.
  const auto cfPtr = (CFTypeRef *)(void *)objectPtr;
  if (!cfPtr || !*cfPtr) {
    return;
  }
  
  _lock.lock();
  const auto isFirstEntry = _queue.empty();
  // Push the pointer into our queue and clear their pointer.
  // This "steals" the +1 from ARC and nils their pointer so they can't
  // access or release the object.
  _queue.push_back(*cfPtr);
  *cfPtr = NULL;
  _lock.unlock();
  
  if (isFirstEntry) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.100 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
      [self drain];
    });
  }
}

- (void)drain
{
  _lock.lock();
  const auto q = std::move(_queue);
  _lock.unlock();
  for (CFTypeRef ref : q) {
    // NOTE: Could check that retain count is 1 and retry later if not.
    CFRelease(ref);
  }
}

@end

@implementation ASAbstractRunLoopQueue

- (instancetype)init
{
  self = [super init];
  if (self == nil) {
    return nil;
  }
  ASDisplayNodeAssert(self.class != [ASAbstractRunLoopQueue class], @"Should never create instances of abstract class ASAbstractRunLoopQueue.");
  return self;
}

@end

#pragma mark - ASRunLoopQueue

@interface ASRunLoopQueue () {
  CFRunLoopRef _runLoop;
  CFRunLoopSourceRef _runLoopSource;
  CFRunLoopObserverRef _runLoopObserver;
  NSPointerArray *_internalQueue; // Use NSPointerArray so we can decide __strong or __weak per-instance.
  ASDN::RecursiveMutex _internalQueueLock;

  // In order to not pollute the top-level activities, each queue has 1 root activity.
  os_activity_t _rootActivity;

#if ASRunLoopQueueLoggingEnabled
  NSTimer *_runloopQueueLoggingTimer;
#endif
}

@property (nonatomic) void (^queueConsumer)(id dequeuedItem, BOOL isQueueDrained);

@end

@implementation ASRunLoopQueue

- (instancetype)initWithRunLoop:(CFRunLoopRef)runloop retainObjects:(BOOL)retainsObjects handler:(void (^)(id _Nullable, BOOL))handlerBlock
{
  if (self = [super init]) {
    _runLoop = runloop;
    NSPointerFunctionsOptions options = retainsObjects ? NSPointerFunctionsStrongMemory : NSPointerFunctionsWeakMemory;
    _internalQueue = [[NSPointerArray alloc] initWithOptions:options];
    _queueConsumer = handlerBlock;
    _batchSize = 1;
    _ensureExclusiveMembership = YES;

    // We don't want to pollute the top-level app activities with run loop batches, so we create one top-level
    // activity per queue, and each batch activity joins that one instead.
    _rootActivity = as_activity_create("Process run loop queue items", OS_ACTIVITY_NONE, OS_ACTIVITY_FLAG_DEFAULT);
    {
      // Log a message identifying this queue into the queue's root activity.
      as_activity_scope_verbose(_rootActivity);
      as_log_verbose(ASDisplayLog(), "Created run loop queue: %@", self);
    }
    
    // Self is guaranteed to outlive the observer.  Without the high cost of a weak pointer,
    // __unsafe_unretained allows us to avoid flagging the memory cycle detector.
    __unsafe_unretained __typeof__(self) weakSelf = self;
    void (^handlerBlock) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) = ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
      [weakSelf processQueue];
    };
    _runLoopObserver = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, 0, handlerBlock);
    CFRunLoopAddObserver(_runLoop, _runLoopObserver,  kCFRunLoopCommonModes);
    
    // It is not guaranteed that the runloop will turn if it has no scheduled work, and this causes processing of
    // the queue to stop. Attaching a custom loop source to the run loop and signal it if new work needs to be done
    CFRunLoopSourceContext sourceContext = {};
    sourceContext.perform = runLoopSourceCallback;
#if ASRunLoopQueueLoggingEnabled
    sourceContext.info = (__bridge void *)self;
#endif
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    CFRunLoopAddSource(runloop, _runLoopSource, kCFRunLoopCommonModes);

#if ASRunLoopQueueLoggingEnabled
    _runloopQueueLoggingTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(checkRunLoop) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_runloopQueueLoggingTimer forMode:NSRunLoopCommonModes];
#endif
  }
  return self;
}

- (void)dealloc
{
  if (CFRunLoopContainsSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes)) {
    CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes);
  }
  CFRelease(_runLoopSource);
  _runLoopSource = nil;
  
  if (CFRunLoopObserverIsValid(_runLoopObserver)) {
    CFRunLoopObserverInvalidate(_runLoopObserver);
  }
  CFRelease(_runLoopObserver);
  _runLoopObserver = nil;
}

#if ASRunLoopQueueLoggingEnabled
- (void)checkRunLoop
{
    NSLog(@"<%@> - Jobs: %ld", self, _internalQueue.count);
}
#endif

- (void)processQueue
{
  BOOL hasExecutionBlock = (_queueConsumer != nil);

  // If we have an execution block, this vector will be populated, otherwise remains empty.
  // This is to avoid needlessly retaining/releasing the objects if we don't have a block.
  std::vector<id> itemsToProcess;

  BOOL isQueueDrained = NO;
  {
    ASDN::MutexLocker l(_internalQueueLock);

    NSInteger internalQueueCount = _internalQueue.count;
    // Early-exit if the queue is empty.
    if (internalQueueCount == 0) {
      return;
    }

    ASSignpostStart(ASSignpostRunLoopQueueBatch);

    // Snatch the next batch of items.
    NSInteger maxCountToProcess = MIN(internalQueueCount, self.batchSize);

    /**
     * For each item in the next batch, if it's non-nil then NULL it out
     * and if we have an execution block then add it in.
     * This could be written a bunch of different ways but
     * this particular one nicely balances readability, safety, and efficiency.
     */
    NSInteger foundItemCount = 0;
    for (NSInteger i = 0; i < internalQueueCount && foundItemCount < maxCountToProcess; i++) {
      /**
       * It is safe to use unsafe_unretained here. If the queue is weak, the
       * object will be added to the autorelease pool. If the queue is strong,
       * it will retain the object until we transfer it (retain it) in itemsToProcess.
       */
      __unsafe_unretained id ptr = (__bridge id)[_internalQueue pointerAtIndex:i];
      if (ptr != nil) {
        foundItemCount++;
        if (hasExecutionBlock) {
          itemsToProcess.push_back(ptr);
        }
        [_internalQueue replacePointerAtIndex:i withPointer:NULL];
      }
    }

    if (foundItemCount == 0) {
      // If _internalQueue holds weak references, and all of them just become NULL, then the array
      // is never marked as needsCompletion, and compact will return early, not removing the NULL's.
      // Inserting a NULL here ensures the compaction will take place.
      // See http://www.openradar.me/15396578 and https://stackoverflow.com/a/40274426/1136669
      [_internalQueue addPointer:NULL];
    }

    [_internalQueue compact];
    if (_internalQueue.count == 0) {
      isQueueDrained = YES;
    }
  }

  // itemsToProcess will be empty if _queueConsumer == nil so no need to check again.
  const auto count = itemsToProcess.size();
  if (count > 0) {
    as_activity_scope_verbose(as_activity_create("Process run loop queue batch", _rootActivity, OS_ACTIVITY_FLAG_DEFAULT));
    const auto itemsEnd = itemsToProcess.cend();
    for (auto iterator = itemsToProcess.begin(); iterator < itemsEnd; iterator++) {
      __unsafe_unretained id value = *iterator;
      _queueConsumer(value, isQueueDrained && iterator == itemsEnd - 1);
      as_log_verbose(ASDisplayLog(), "processed %@", value);
    }
    if (count > 1) {
      as_log_verbose(ASDisplayLog(), "processed %lu items", (unsigned long)count);
    }
  }

  // If the queue is not fully drained yet force another run loop to process next batch of items
  if (!isQueueDrained) {
    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
  
  ASSignpostEnd(ASSignpostRunLoopQueueBatch);
}

- (void)enqueue:(id)object
{
  if (!object) {
    return;
  }
  
  ASDN::MutexLocker l(_internalQueueLock);

  // Check if the object exists.
  BOOL foundObject = NO;
    
  if (_ensureExclusiveMembership) {
    for (id currentObject in _internalQueue) {
      if (currentObject == object) {
        foundObject = YES;
        break;
      }
    }
  }

  if (!foundObject) {
    [_internalQueue addPointer:(__bridge void *)object];

    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
}

- (BOOL)isEmpty
{
  ASDN::MutexLocker l(_internalQueueLock);
  return _internalQueue.count == 0;
}

ASSynthesizeLockingMethodsWithMutex(_internalQueueLock)

@end

#pragma mark - ASCATransactionQueue

@interface ASCATransactionQueue () {
  CFRunLoopRef _runLoop;
  CFRunLoopSourceRef _runLoopSource;
  CFRunLoopObserverRef _preTransactionObserver;
  NSPointerArray *_internalQueue;
  ASDN::RecursiveMutex _internalQueueLock;

  // In order to not pollute the top-level activities, each queue has 1 root activity.
  os_activity_t _rootActivity;

#if ASRunLoopQueueLoggingEnabled
  NSTimer *_runloopQueueLoggingTimer;
#endif
}

@end

@implementation ASCATransactionQueue

// CoreAnimation commit order is 2000000, the goal of this is to process shortly beforehand
// but after most other scheduled work on the runloop has processed.
static int const kASASCATransactionQueueOrder = 1000000;

+ (ASCATransactionQueue *)sharedQueue NS_RETURNS_RETAINED
{
  static dispatch_once_t onceToken;
  static ASCATransactionQueue *sharedQueue;
  dispatch_once(&onceToken, ^{
    sharedQueue = [[ASCATransactionQueue alloc] init];
  });
  return sharedQueue;
}

- (instancetype)init
{
  if (self = [super init]) {
    _runLoop = CFRunLoopGetMain();
    NSPointerFunctionsOptions options = NSPointerFunctionsStrongMemory;
    _internalQueue = [[NSPointerArray alloc] initWithOptions:options];

    // We don't want to pollute the top-level app activities with run loop batches, so we create one top-level
    // activity per queue, and each batch activity joins that one instead.
    _rootActivity = as_activity_create("Process run loop queue items", OS_ACTIVITY_NONE, OS_ACTIVITY_FLAG_DEFAULT);
    {
      // Log a message identifying this queue into the queue's root activity.
      as_activity_scope_verbose(_rootActivity);
      as_log_verbose(ASDisplayLog(), "Created run loop queue: %@", self);
    }

    // Self is guaranteed to outlive the observer.  Without the high cost of a weak pointer,
    // __unsafe_unretained allows us to avoid flagging the memory cycle detector.
    __unsafe_unretained __typeof__(self) weakSelf = self;
    void (^handlerBlock) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) = ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
      while (weakSelf->_internalQueue.count > 0) {
      [weakSelf processQueue];
      }
    };
    _preTransactionObserver = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, kASASCATransactionQueueOrder, handlerBlock);

    CFRunLoopAddObserver(_runLoop, _preTransactionObserver,  kCFRunLoopCommonModes);

    // It is not guaranteed that the runloop will turn if it has no scheduled work, and this causes processing of
    // the queue to stop. Attaching a custom loop source to the run loop and signal it if new work needs to be done
    CFRunLoopSourceContext sourceContext = {};
    sourceContext.perform = runLoopSourceCallback;
#if ASRunLoopQueueLoggingEnabled
    sourceContext.info = (__bridge void *)self;
#endif
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes);

#if ASRunLoopQueueLoggingEnabled
    _runloopQueueLoggingTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(checkRunLoop) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_runloopQueueLoggingTimer forMode:NSRunLoopCommonModes];
#endif
  }
  return self;
}

- (void)dealloc
{
  CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes);
  CFRelease(_runLoopSource);
  _runLoopSource = nil;

  if (CFRunLoopObserverIsValid(_preTransactionObserver)) {
    CFRunLoopObserverInvalidate(_preTransactionObserver);
  }
  CFRelease(_preTransactionObserver);
  _preTransactionObserver = nil;
}

#if ASRunLoopQueueLoggingEnabled
- (void)checkRunLoop
{
  NSLog(@"<%@> - Jobs: %ld", self, _internalQueue.count);
}
#endif

- (void)processQueue
{
  // If we have an execution block, this vector will be populated, otherwise remains empty.
  // This is to avoid needlessly retaining/releasing the objects if we don't have a block.
  std::vector<id> itemsToProcess;

  {
    ASDN::MutexLocker l(_internalQueueLock);

    NSInteger internalQueueCount = _internalQueue.count;
    // Early-exit if the queue is empty.
    if (internalQueueCount == 0) {
      return;
    }

    ASSignpostStart(ASSignpostRunLoopQueueBatch);

    /**
     * For each item in the next batch, if it's non-nil then NULL it out
     * and if we have an execution block then add it in.
     * This could be written a bunch of different ways but
     * this particular one nicely balances readability, safety, and efficiency.
     */
    NSInteger foundItemCount = 0;
    for (NSInteger i = 0; i < internalQueueCount && foundItemCount < internalQueueCount; i++) {
      /**
       * It is safe to use unsafe_unretained here. If the queue is weak, the
       * object will be added to the autorelease pool. If the queue is strong,
       * it will retain the object until we transfer it (retain it) in itemsToProcess.
       */
      __unsafe_unretained id ptr = (__bridge id)[_internalQueue pointerAtIndex:i];
      if (ptr != nil) {
        foundItemCount++;
        itemsToProcess.push_back(ptr);
        [_internalQueue replacePointerAtIndex:i withPointer:NULL];
      }
    }

    [_internalQueue compact];
  }

  // itemsToProcess will be empty if _queueConsumer == nil so no need to check again.
  const auto count = itemsToProcess.size();
  if (count > 0) {
    as_activity_scope_verbose(as_activity_create("Process run loop queue batch", _rootActivity, OS_ACTIVITY_FLAG_DEFAULT));
    const auto itemsEnd = itemsToProcess.cend();
    for (auto iterator = itemsToProcess.begin(); iterator < itemsEnd; iterator++) {
      __unsafe_unretained id value = *iterator;
      [value prepareForCATransactionCommit];
      as_log_verbose(ASDisplayLog(), "processed %@", value);
    }
    if (count > 1) {
      as_log_verbose(ASDisplayLog(), "processed %lu items", (unsigned long)count);
    }
  }

  ASSignpostEnd(ASSignpostRunLoopQueueBatch);
}

- (void)enqueue:(id<ASCATransactionQueueObserving>)object
{
  if (!object) {
    return;
  }

  if (!self.enabled) {
    [object prepareForCATransactionCommit];
    return;
  }

  ASDN::MutexLocker l(_internalQueueLock);

  // Check if the object exists.
  BOOL foundObject = NO;

  for (id currentObject in _internalQueue) {
    if (currentObject == object) {
      foundObject = YES;
      break;
    }
  }

  if (!foundObject) {
    [_internalQueue addPointer:(__bridge void *)object];

    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
}

- (BOOL)isEmpty
{
  ASDN::MutexLocker l(_internalQueueLock);
  return _internalQueue.count == 0;
}

- (BOOL)isEnabled
{
  return ASActivateExperimentalFeature(ASExperimentalInterfaceStateCoalescing);
}

@end
