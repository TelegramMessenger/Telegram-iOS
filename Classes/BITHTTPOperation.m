//
//  BITHTTPOperation.m
//  HockeySDK
//
//  Created by Stephan Diederich on 10.08.13.
//
//

#import "BITHTTPOperation.h"

@interface BITHTTPOperation()<NSURLConnectionDelegate>
@end

@implementation BITHTTPOperation {
  NSURLRequest *_URLRequest;
  NSURLConnection *_connection;
  NSMutableData *_data;
  
  BOOL _isExecuting;
  BOOL _isFinished;
}


+ (instancetype)operationWithRequest:(NSURLRequest *)urlRequest {
  BITHTTPOperation *op = [[self class] new];
  op->_URLRequest = urlRequest;
  return op;
}

#pragma mark - NSOperation overrides
- (BOOL)isConcurrent {
  return YES;
}

- (void)cancel {
  [_connection cancel];
  [super cancel];
}

- (void) start {
  if (![[NSThread currentThread] isMainThread]) {
    [self performSelector:@selector(start) onThread:NSThread.mainThread withObject:nil waitUntilDone:NO];
  }
  
  [self willChangeValueForKey:@"isExecuting"];
  _isExecuting = YES;
  [self didChangeValueForKey:@"isExecuting"];
  
  _connection = [[NSURLConnection alloc] initWithRequest:_URLRequest
                                                delegate:self
                                        startImmediately:NO];

  [_connection scheduleInRunLoop:[NSRunLoop currentRunLoop]
                         forMode:NSDefaultRunLoopMode];
  
  [_connection start];
}

- (void) finish {
  [self willChangeValueForKey:@"isExecuting"];
  [self willChangeValueForKey:@"isFinished"];
  _isExecuting = NO;
  _isFinished = YES;
  [self didChangeValueForKey:@"isExecuting"];
  [self didChangeValueForKey:@"isFinished"];
}

#pragma mark - NSURLConnectionDelegate
-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
  _data = [[NSMutableData alloc] init];
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
  [_data appendData:data];
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
  //FINISHED and failed
  _error = error;
  _data = nil;
  
  [self finish];
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection {
  [self finish];
}

#pragma mark - Public interface
- (NSData *)data {
  return _data;
}

- (void)setCompletion:(BITNetworkCompletionBlock)completion {
  __weak typeof(self) weakSelf = self;
  if(nil == completion) {
    [super setCompletionBlock:nil];
  } else {
    [super setCompletionBlock:^{
      typeof(self) strongSelf = weakSelf;
      if(strongSelf) {
        dispatch_async(dispatch_get_main_queue(), ^{
          completion(strongSelf, strongSelf->_data, strongSelf->_error);
        });
      }
    }];
  }
}

- (BOOL)isFinished {
  return _isFinished;
}

- (BOOL)isExecuting {
  return _isExecuting;
}

@end
