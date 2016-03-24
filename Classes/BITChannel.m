#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "HockeySDKPrivate.h"
#import "BITChannelPrivate.h"
#import "BITHockeyHelper.h"
#import "BITTelemetryContext.h"
#import "BITTelemetryData.h"
#import "HockeySDKPrivate.h"
#import "BITEnvelope.h"
#import "BITData.h"
#import "BITDevice.h"
#import "BITPersistencePrivate.h"

static char *const BITDataItemsOperationsQueue = "net.hockeyapp.senderQueue";
char *BITSafeJsonEventsString;

NSString *const BITChannelBlockedNotification = @"BITChannelBlockedNotification";

static NSInteger const BITDefaultMaxBatchSize  = 50;
static NSInteger const BITDefaultBatchInterval = 15;
static NSInteger const BITSchemaVersion = 2;

static NSInteger const BITDebugMaxBatchSize = 5;
static NSInteger const BITDebugBatchInterval = 3;

NS_ASSUME_NONNULL_BEGIN

@implementation BITChannel

@synthesize persistence = _persistence;
@synthesize channelBlocked = _channelBlocked;

#pragma mark - Initialisation

- (instancetype)init {
  if (self = [super init]) {
    bit_resetSafeJsonStream(&BITSafeJsonEventsString);
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
  }
  return self;
}

- (instancetype)initWithTelemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *)persistence {
  if (self = [self init]) {
    _telemetryContext = telemetryContext;
    _persistence = persistence;
  }
  return self;
}

#pragma mark - Queue management

- (BOOL)isQueueBusy {
  if (!self.channelBlocked) {
   _channelBlocked = ![self.persistence isFreeSpaceAvailable];
  }
  return self.channelBlocked;
}

- (void)persistDataItemQueue {
  [self invalidateTimer];
  if (!BITSafeJsonEventsString || strlen(BITSafeJsonEventsString) == 0) {
    return;
  }

  NSData *bundle = [NSData dataWithBytes:BITSafeJsonEventsString length:strlen(BITSafeJsonEventsString)];
  [self.persistence persistBundle:bundle];

  // Reset both, the async-signal-safe and item counter.
  [self resetQueue];
}

- (void)resetQueue {
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  _dataItemCount = 0;
}

#pragma mark - Adding to queue

- (BOOL)enqueueTelemetryItem:(BITTelemetryData *)item {
  if (!item) {
    BITHockeyLog(@"WARNING: TelemetryItem was nil.");
    return NO;
  }

  if (self.isQueueBusy) {
    BITHockeyLog(@"The channel is saturated. %@ was dropped.", item.name);
    if (![self timerIsRunning]) {
      [self startTimer];
    }
    return NO;
  }

  NSDictionary *dict = [self dictionaryForTelemetryData:item];
  __weak typeof(self) weakSelf = self;

  dispatch_async(self.dataItemsOperations, ^{
    typeof(self) strongSelf = weakSelf;

    // Enqueue item
    [strongSelf appendDictionaryToJsonStream:dict];

    if (strongSelf->_dataItemCount >= self.maxBatchSize) {
      // Max batch count has been reached, so write queue to disk and delete all items.
      [strongSelf persistDataItemQueue];
      [strongSelf sendBlockingChannelNotification];
    } else if (strongSelf->_dataItemCount == 1) {
        // It is the first item, let's start the timer
        [strongSelf startTimer];
      }
  });
  return YES;
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
  envelope.iKey = _telemetryContext.appIdentifier;

  envelope.tags = _telemetryContext.contextDictionary;
  envelope.data = data;
  envelope.name = telemetryData.envelopeTypeName;

  return envelope;
}

#pragma mark - Serialization Helper

- (NSString *)serializeDictionaryToJSONString:(NSDictionary *)dictionary {
  NSError *error;
  NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:(NSJSONWritingOptions)0 error:&error];
  if (!data) {
    BITHockeyLog(@"ERROR: JSONSerialization error: %@", error.localizedDescription);
    return @"{}";
  } else {
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  }
}

#pragma mark JSON Stream

- (void)appendDictionaryToJsonStream:(NSDictionary *)dictionary {
  if (dictionary) {
    NSString *string = [self serializeDictionaryToJSONString:dictionary];

    // Since we can't persist every event right away, we write it to a simple C string.
    // This can then be written to disk by a signal handler in case of a crash.
    BITSafeJsonEventsString = bit_jsonStreamByAppendingJsonString(BITSafeJsonEventsString, string);
    _dataItemCount += 1;
  }
}

char * bit_jsonStreamByAppendingJsonString(char *json_stream, NSString *jsonString) {
  if ((json_stream == NULL) || !json_stream) {

    return strdup("");
  }

  if (!jsonString || (jsonString.length == 0)) {
    return json_stream;
  }

  
  char *concatenated_string = NULL;
  // Concatenate old string with new JSON string and add a new line.
  asprintf(&concatenated_string, "%s%.*s\n", json_stream, (int)MIN(jsonString.length, (NSUInteger)INT_MAX), jsonString.UTF8String);
  return concatenated_string;
}

void bit_resetSafeJsonStream(char **string) {
  if (!string) { return; }
  free(*string);
  *string = strdup("");
}

#pragma mark - Batching

- (NSUInteger)maxBatchSize {
  if(_maxBatchSize <= 0){
    return BITDefaultMaxBatchSize;
  }
  return _maxBatchSize;
}

- (void)invalidateTimer {
  if ([self timerIsRunning]) {
    dispatch_source_cancel(self.timerSource);
    self.timerSource = nil;
  }
}

-(BOOL)timerIsRunning {
  return self.timerSource != nil;
}

- (void)startTimer {
  // Reset timer, if it is already running
  if ([self timerIsRunning]) {
    [self invalidateTimer];
  }
  
  self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.dataItemsOperations);
  dispatch_source_set_timer(self.timerSource, dispatch_walltime(NULL, NSEC_PER_SEC * self.batchInterval), 1ull * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
  __weak typeof(self) weakSelf = self;
  dispatch_source_set_event_handler(self.timerSource, ^{
    typeof(self) strongSelf = weakSelf;
    
    if (strongSelf->_dataItemCount > 0) {
      [strongSelf persistDataItemQueue];
    } else {
      [strongSelf sendBlockingChannelNotification];
      [strongSelf invalidateTimer];
      strongSelf.channelBlocked = NO;
    }
  });
  dispatch_resume(self.timerSource);
}

/**
 * Send a BITHockeyBlockingChannelNotification to the main thread to notify observers that channel can't enqueue new items.
 * This is typically used to trigger sending.
 */
- (void)sendBlockingChannelNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:BITChannelBlockedNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
