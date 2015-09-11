#import "BITSender.h"
#import "BITPersistencePrivate.h"
#import "BITGZIP.h"
#import "HockeySDKPrivate.h"
#import "BITHTTPOperation.h"
#import "BITHockeyHelper.h"

static char const *kSenderQueueString = "net.hockeyapp.senderQueue";
static NSUInteger const defaultRequestLimit = 10;

@implementation BITSender

@synthesize runningRequestsCount = _runningRequestsCount;
@synthesize persistence = _persistence;

#pragma mark - Initialize instance

- (instancetype)initWithPersistence:(BITPersistence *)persistence serverURL:(NSURL *)serverURL {
  if ((self = [super init])) {
    _senderQueue = dispatch_queue_create(kSenderQueueString, DISPATCH_QUEUE_CONCURRENT);
    _maxRequestCount = defaultRequestLimit;
    _serverURL = serverURL;
    _persistence = persistence;
    [self registerObservers];
  }
  return self;
}

#pragma mark - Handle persistence events

- (void)registerObservers{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  __weak typeof(self) weakSelf = self;
  [center addObserverForName:BITPersistenceSuccessNotification
                      object:nil
                       queue:nil
                  usingBlock:^(NSNotification *notification) {
                    typeof(self) strongSelf = weakSelf;
                    [strongSelf sendSavedDataAsync];
                  }];
}

#pragma mark - Sending

- (void)sendSavedDataAsync{
  dispatch_async(self.senderQueue, ^{
    [self sendSavedData];
  });
}

- (void)sendSavedData{
  @synchronized(self){
    if(_runningRequestsCount < _maxRequestCount){
      _runningRequestsCount++;
    }else{
      return;
    }
  }
  NSString *path = [self.persistence requestNextPath];
  NSData *data = [self.persistence dataAtPath:path];
  [self sendData:data withPath:path];
}

- (void)sendData:(NSData * __nonnull)data withPath:(NSString * __nonnull)path {
  if(data && data.length > 0) {
    NSData *gzippedData = [data gzippedData];
    NSURLRequest *request = [self requestForData:gzippedData];
    id nsurlsessionClass = NSClassFromString(@"NSURLSessionUploadTask");
    BOOL isUrlSessionSupported = (nsurlsessionClass && !bit_isRunningInAppExtension());
    
    [self sendRequest:request path:path urlSessionSupported:isUrlSessionSupported];
  } else {
    self.runningRequestsCount -= 1;
  }
}

- (void)sendRequest:(NSURLRequest * __nonnull)request path:(NSString * __nonnull)path urlSessionSupported:(BOOL)isUrlSessionSupported{
  if(!path || !request) return;
  __weak typeof(self) weakSelf = self;
  
  if(!isUrlSessionSupported) {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
                                              typeof (self) strongSelf = weakSelf;
                                              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                              NSInteger statusCode = httpResponse.statusCode;
                                              [strongSelf handleResponseWithStatusCode:statusCode responseData:data filePath:path error:error];
                                            }];
    [self resumeSessionDataTask:task];
  }else{
    BITHTTPOperation *operation = [BITHTTPOperation operationWithRequest:request];
    [operation setCompletion:^(BITHTTPOperation *operation, NSData *responseData, NSError *error) {
      typeof(self) strongSelf = weakSelf;
      NSInteger statusCode = [operation.response statusCode];
      [strongSelf handleResponseWithStatusCode:statusCode responseData:responseData filePath:path error:error];
    }];
    
    [self.operationQueue addOperation:operation];
  }
}

- (void)resumeSessionDataTask:(NSURLSessionDataTask *)sessionDataTask {
  [sessionDataTask resume];
}

- (void)handleResponseWithStatusCode:(NSInteger)statusCode responseData:(NSData *)responseData filePath:(NSString *)filePath error:(NSError *)error{
  self.runningRequestsCount -= 1;
  
  if(responseData && [self shouldDeleteDataWithStatusCode:statusCode]) {
    //we delete data that was either sent successfully or if we have a non-recoverable error
    BITHockeyLog(@"Sent data with status code: %ld", (long) statusCode);
    BITHockeyLog(@"Response data:\n%@", [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil]);
    [self.persistence deleteFileAtPath:filePath];
    [self sendSavedData];
  } else {
    BITHockeyLog(@"Sending telemetry data failed");
    BITHockeyLog(@"Error description: %@", error.localizedDescription);
    [self.persistence giveBackRequestedPath:filePath];
  }
}

#pragma mark - Helper

- (NSURLRequest *)requestForData:(NSData * __nonnull)data {

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.serverURL];
  request.HTTPMethod = @"POST";
  
  request.HTTPBody = data;
  request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
  
  NSDictionary *headers = @{@"Charset": @"UTF-8",
                            @"Content-Encoding": @"gzip",
                            @"Content-Type": @"application/x-json-stream",
                            @"Accept-Encoding": @"gzip"};
  [request setAllHTTPHeaderFields:headers];
  
  return request;
}

//some status codes represent recoverable error codes
//we try sending again some point later
- (BOOL)shouldDeleteDataWithStatusCode:(NSInteger)statusCode {
  NSArray *recoverableStatusCodes = @[@429, @408, @500, @503, @511];

  return ![recoverableStatusCodes containsObject:@(statusCode)];
}

#pragma mark - Getter/Setter

- (NSOperationQueue *)operationQueue {
  if(nil == _operationQueue) {
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = defaultRequestLimit;
  }
  return _operationQueue;
}

- (NSUInteger)runningRequestsCount {
  @synchronized(self) {
    return _runningRequestsCount;
  }
}

- (void)setRunningRequestsCount:(NSUInteger)runningRequestsCount {
  @synchronized(self) {
    _runningRequestsCount = runningRequestsCount;
  }
}

@end
