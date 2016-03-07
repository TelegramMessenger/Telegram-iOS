#import "BITChannel.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITHockeyHelper.h"
#import "HockeySDK.h"
#import "BITTelemetryContext.h"
#import "BITTelemetryData.h"
#import "HockeySDKPrivate.h"
#import "BITOrderedDictionary.h"
#import "BITEnvelope.h"
#import "BITData.h"
#import "BITDevice.h"
#import "BITPersistencePrivate.h"

static char *const BITDataItemsOperationsQueue = "net.hockeyapp.senderQueue";
char *BITSafeJsonEventsString;

static NSInteger const BITDefaultMaxBatchCount  = 1;
static NSInteger const BITSchemaVersion  = 2;

NS_ASSUME_NONNULL_BEGIN

@implementation BITChannel

@synthesize persistence = _persistence;

#pragma mark - Initialisation

- (instancetype)init {
  if(self = [super init]) {
    bit_resetSafeJsonStream(&BITSafeJsonEventsString);
    _dataItemCount = 0;
    dispatch_queue_t serialQueue = dispatch_queue_create(BITDataItemsOperationsQueue, DISPATCH_QUEUE_SERIAL);
    _dataItemsOperations = serialQueue;
  }
  return self;
}

- (instancetype)initWithTelemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *) persistence {
  if(self = [self init]) {
    _telemetryContext = telemetryContext;
    _persistence = persistence;
  }
  return self;
}

#pragma mark - Queue management

- (BOOL)isQueueBusy{
  [self.persistence isFreeSpaceAvailable];
  return true;
}

- (void)persistDataItemQueue {
  if(!BITSafeJsonEventsString || strlen(BITSafeJsonEventsString) == 0) {
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

- (void)enqueueTelemetryItem:(BITTelemetryData *)item {
  if (item) {
    BITOrderedDictionary *dict = [self dictionaryForTelemetryData:item];
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.dataItemsOperations, ^{
      typeof(self) strongSelf = weakSelf;
      if (strongSelf) {
        // Enqueue item
        [strongSelf appendDictionaryToJsonStream:dict];
        
        if(strongSelf->_dataItemCount >= self.maxBatchCount) {
          // Max batch count has been reached, so write queue to disk and delete all items.
          [strongSelf persistDataItemQueue];
        }
      }
    });
  }
}

#pragma mark - Envelope telemerty items

- (BITOrderedDictionary *)dictionaryForTelemetryData:(BITTelemetryData *) telemetryData {
  
  BITEnvelope *envelope = [self envelopeForTelemetryData:telemetryData];
  BITOrderedDictionary *dict = [envelope serializeToDictionary];
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

- (NSString *)serializeDictionaryToJSONString:(BITOrderedDictionary *)dictionary {
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

- (void)appendDictionaryToJsonStream:(BITOrderedDictionary *)dictionary {
  if(dictionary) {
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

- (NSUInteger)maxBatchCount {
  if(_maxBatchCount <= 0){
    return BITDefaultMaxBatchCount;
  }
  return _maxBatchCount;
}

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
