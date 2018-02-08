#import "BITSender.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITPersistencePrivate.h"
#import "BITChannelPrivate.h"
#import "BITGZIP.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

NSString *const BITSenderFinishSendingDataNotification = @"BITSenderFinishSendingDataNotification";

static char const *kBITSenderTasksQueueString = "net.hockeyapp.sender.tasksQueue";
static NSUInteger const BITDefaultRequestLimit = 10;

@interface BITSender ()

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, weak, nullable) id persistenceSuccessObserver;
@property (nonatomic, weak, nullable) id channelBlockedObserver;

@end

@implementation BITSender

@synthesize runningRequestsCount = _runningRequestsCount;
@synthesize persistence = _persistence;

#pragma mark - Initialize instance

- (instancetype)initWithPersistence:(nonnull BITPersistence *)persistence serverURL:(nonnull NSURL *)serverURL {
  if ((self = [super init])) {
    _senderTasksQueue = dispatch_queue_create(kBITSenderTasksQueueString, DISPATCH_QUEUE_CONCURRENT);
    _maxRequestCount = BITDefaultRequestLimit;
    _serverURL = serverURL;
    _persistence = persistence;
    [self registerObservers];
  }
  return self;
}

- (void)dealloc {
  [self unregisterObservers];
}

#pragma mark - Handle persistence events

- (void)registerObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;

  if (nil == self.persistenceSuccessObserver) {
    self.persistenceSuccessObserver =
        [center addObserverForName:BITPersistenceSuccessNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification __unused *notification) {
                          typeof(self) strongSelf = weakSelf;
                          [strongSelf sendSavedDataAsync];
                        }];
  }
  if (nil == self.channelBlockedObserver) {
    self.channelBlockedObserver =
        [center addObserverForName:BITChannelBlockedNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification __unused *notification) {
                          typeof(self) strongSelf = weakSelf;
                          [strongSelf sendSavedDataAsync];
                        }];
  }
}

- (void)unregisterObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  id persistenceSuccessObserver = self.persistenceSuccessObserver;
  if(persistenceSuccessObserver) {
    [center removeObserver:persistenceSuccessObserver];
    self.persistenceSuccessObserver = nil;
  }
  id channelBlockedObserver = self.channelBlockedObserver;
  if(channelBlockedObserver) {
    [center removeObserver:channelBlockedObserver];
    self.channelBlockedObserver = nil;
  }
}

#pragma mark - Sending

- (void)sendSavedDataAsync {
  dispatch_async(self.senderTasksQueue, ^{
    [self sendSavedData];
  });
}

- (void)sendSavedData {
  @synchronized(self) {
    if (self.runningRequestsCount < self.maxRequestCount) {
      self.runningRequestsCount++;
      BITHockeyLogDebug(@"INFO: Create new sender thread. Current count is %ld", (long) self.runningRequestsCount);
    } else {
      return;
    }
  }

  NSString *filePath = [self.persistence requestNextFilePath];
  NSData *data = [self.persistence dataAtFilePath:filePath];
  [self sendData:data withFilePath:filePath];
}

- (void)sendData:(nonnull NSData *)data withFilePath:(nonnull NSString *)filePath {
  if (data && data.length > 0) {
    NSData *gzippedData = [data bit_gzippedData];
    NSURLRequest *request = [self requestForData:gzippedData];

    BITHockeyLogVerbose(@"VERBOSE: Sending data:\n%@", [[NSString alloc] initWithData:data encoding:kCFStringEncodingUTF8]);
    [self sendRequest:request filePath:filePath];
  } else {
    self.runningRequestsCount--;
    BITHockeyLogDebug(@"INFO: Close sender thread due empty package. Current count is %ld", (long) self.runningRequestsCount);
  }
}

- (void)sendRequest:(nonnull NSURLRequest *)request filePath:(nonnull NSString *)path {
  if (!path || !request) {
    return;
  }
  NSURLSession *session = self.session;
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                            NSInteger statusCode = httpResponse.statusCode;
                                            [self handleResponseWithStatusCode:statusCode responseData:data filePath:path error:error];
                                          }];
  [task resume];
}

- (void)handleResponseWithStatusCode:(NSInteger)statusCode responseData:(nonnull NSData *)responseData filePath:(nonnull NSString *)filePath error:(nonnull NSError *)error {
  self.runningRequestsCount--;
  BITHockeyLogDebug(@"INFO: Close sender thread due incoming response. Current count is %ld", (long) self.runningRequestsCount);

  if (responseData && (responseData.length > 0) && [self shouldDeleteDataWithStatusCode:statusCode]) {
    //we delete data that was either sent successfully or if we have a non-recoverable error
    BITHockeyLogDebug(@"INFO: Sent data with status code: %ld", (long) statusCode);
    BITHockeyLogDebug(@"INFO: Response data:\n%@", [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil]);
    [self.persistence deleteFileAtPath:filePath];
    [self sendSavedData];
  } else {
    BITHockeyLogError(@"ERROR: Sending telemetry data failed");
    BITHockeyLogError(@"Error description: %@", error.localizedDescription);
    [self.persistence giveBackRequestedFilePath:filePath];
  }
  
  if (self.runningRequestsCount == 0) {
    [self sendSenderFinishSendingDataNotification];
  }
}

- (void)sendSenderFinishSendingDataNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    BITHockeyLogDebug(@"Sending notification: %@", BITSenderFinishSendingDataNotification);
    [[NSNotificationCenter defaultCenter] postNotificationName:BITSenderFinishSendingDataNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}

#pragma mark - Helper

- (NSURLRequest *)requestForData:(nonnull NSData *)data {

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.serverURL];
  request.HTTPMethod = @"POST";

  request.HTTPBody = data;
  request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

  NSDictionary<NSString *,NSString *> *headers = @{@"Charset" : @"UTF-8",
      @"Content-Encoding" : @"gzip",
      @"Content-Type" : @"application/x-json-stream",
      @"Accept-Encoding" : @"gzip"};
  [request setAllHTTPHeaderFields:headers];

  return request;
}

//some status codes represent recoverable error codes
//we try sending again some point later
- (BOOL)shouldDeleteDataWithStatusCode:(NSInteger)statusCode {
  NSArray<NSNumber *> *recoverableStatusCodes = @[@429, @408, @500, @503, @511];

  return ![recoverableStatusCodes containsObject:@(statusCode)];
}

#pragma mark - Getter/Setter

- (NSURLSession *)session {
  if (!_session) {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
  }
  return _session;
}

@end

#endif /* HOCKEYSDK_FEATURE_METRICS */

