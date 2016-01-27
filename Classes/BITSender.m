#import "BITSender.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITPersistencePrivate.h"
#import "BITChannelPrivate.h"
#import "BITGZIP.h"
#import "HockeySDKPrivate.h"
#import "BITHTTPOperation.h"
#import "BITHockeyHelper.h"

static char const *kBITSenderTasksQueueString = "net.hockeyapp.sender.tasksQueue";
static char const *kBITSenderRequestsCountQueueString = "net.hockeyapp.sender.requestsCount";
static NSUInteger const BITDefaultRequestLimit = 10;

@interface BITSender ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation BITSender

@synthesize runningRequestsCount = _runningRequestsCount;
@synthesize persistence = _persistence;

#pragma mark - Initialize instance

- (instancetype)initWithPersistence:(nonnull BITPersistence *)persistence serverURL:(nonnull NSURL *)serverURL {
  if ((self = [super init])) {
    _requestsCountQueue = dispatch_queue_create(kBITSenderRequestsCountQueueString, DISPATCH_QUEUE_CONCURRENT);
    _senderTasksQueue = dispatch_queue_create(kBITSenderTasksQueueString, DISPATCH_QUEUE_CONCURRENT);
    _maxRequestCount = BITDefaultRequestLimit;
    _serverURL = serverURL;
    _persistence = persistence;
    [self registerObservers];
  }
  return self;
}

#pragma mark - Handle persistence events

- (void)registerObservers {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;
  
  [center addObserverForName:BITPersistenceSuccessNotification
                      object:nil
                       queue:nil
                  usingBlock:^(NSNotification *notification) {
                    typeof(self) strongSelf = weakSelf;
                    [strongSelf sendSavedDataAsync];
                  }];
  
  [center addObserverForName:BITChannelBlockedNotification
                      object:nil
                       queue:nil
                  usingBlock:^(NSNotification *notification) {
                    typeof(self) strongSelf = weakSelf;
                    [strongSelf sendSavedDataAsync];
                  }];
}

#pragma mark - Sending

- (void)sendSavedDataAsync {
  dispatch_async(self.senderTasksQueue, ^{
    [self sendSavedData];
  });
}

- (void)sendSavedData {
  @synchronized(self){
    if(_runningRequestsCount < _maxRequestCount){
      _runningRequestsCount++;
      BITHockeyLogDebug(@"INFO: Create new sender thread. Current count is %ld", (long) _runningRequestsCount);
    }else{
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

    [self sendRequest:request filePath:filePath];
  } else {
    self.runningRequestsCount -= 1;
    BITHockeyLogDebug(@"INFO: Close sender thread due empty package. Current count is %ld", (long) _runningRequestsCount);
    // TODO: Delete data and send next file
  }
}

- (void)sendRequest:(nonnull NSURLRequest *) request filePath:(nonnull NSString *) path {
  if (!path || !request) {return;}
  
  if ([self isURLSessionSupported]) {
    [self sendUsingURLSessionWithRequest:request filePath:path];
  } else {
    [self sendUsingURLConnectionWithRequest:request filePath:path];
  }
}

- (BOOL)isURLSessionSupported {
  id nsurlsessionClass = NSClassFromString(@"NSURLSessionUploadTask");
  BOOL isUrlSessionSupported = (nsurlsessionClass && !bit_isRunningInAppExtension());
  return isUrlSessionSupported;
}

- (void)sendUsingURLConnectionWithRequest:(nonnull NSURLRequest *)request filePath:(nonnull NSString *)filePath {
  BITHTTPOperation *operation = [BITHTTPOperation operationWithRequest:request];
  [operation setCompletion:^(BITHTTPOperation *operation, NSData *responseData, NSError *error) {
    NSInteger statusCode = [operation.response statusCode];
    [self handleResponseWithStatusCode:statusCode responseData:responseData filePath:filePath error:error];
  }];

  [self.operationQueue addOperation:operation];
}

- (void)sendUsingURLSessionWithRequest:(nonnull NSURLRequest *)request filePath:(nonnull NSString *)filePath {
  NSURLSession *session = self.session;
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                            NSInteger statusCode = httpResponse.statusCode;
                                            [self handleResponseWithStatusCode:statusCode responseData:data filePath:filePath error:error];
                                          }];
  [self resumeSessionDataTask:task];
}

- (void)resumeSessionDataTask:(nonnull NSURLSessionDataTask *)sessionDataTask {
  [sessionDataTask resume];
}

- (void)handleResponseWithStatusCode:(NSInteger)statusCode responseData:(nonnull NSData *)responseData filePath:(nonnull NSString *)filePath error:(nonnull NSError *)error {
  self.runningRequestsCount -= 1;
  BITHockeyLogDebug(@"INFO: Close sender thread due incoming response. Current count is %ld", (long) _runningRequestsCount);

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

- (NSOperationQueue *)operationQueue {
  if (nil == _operationQueue) {
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = BITDefaultRequestLimit;
  }
  return _operationQueue;
}

- (NSUInteger)runningRequestsCount {
  __block NSUInteger count;
  dispatch_sync(_requestsCountQueue, ^{
    count = _runningRequestsCount;
  });
  return count;
}

- (void)setRunningRequestsCount:(NSUInteger)runningRequestsCount {
  dispatch_sync(_requestsCountQueue, ^{
    _runningRequestsCount = runningRequestsCount;
  });
}

@end

#endif /* HOCKEYSDK_FEATURE_METRICS */

