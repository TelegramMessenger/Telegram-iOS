/*
 * Author: Stephan Diederich
 *
 * Copyright (c) 2013-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "BITHTTPOperation.h"

@interface BITHTTPOperation() <NSURLConnectionDelegate>

@property (nonatomic, strong) NSURLRequest *URLRequest;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;

// Redeclare BITHTTPOperation properties with readwrite attribute.
@property (nonatomic, readwrite) NSHTTPURLResponse *response;
@property (nonatomic, readwrite) NSError *error;

@end

@implementation BITHTTPOperation

+ (instancetype)operationWithRequest:(NSURLRequest *)urlRequest {
  BITHTTPOperation *op = [[self class] new];
  op.URLRequest = urlRequest;
  return op;
}

#pragma mark - NSOperation overrides
- (BOOL)isConcurrent {
  return YES;
}

- (void)cancel {
  [self.connection cancel];
  [super cancel];
}

- (void) start {
  if(self.isCancelled) {
    [self finish];
    return;
  }
  
  if (![[NSThread currentThread] isMainThread]) {
    [self performSelector:@selector(start) onThread:NSThread.mainThread withObject:nil waitUntilDone:NO];
    return;
  }
  
  if(self.isCancelled) {
    [self finish];
    return;
  }

  [self willChangeValueForKey:@"isExecuting"];
  self.isExecuting = YES;
  [self didChangeValueForKey:@"isExecuting"];
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  self.connection = [[NSURLConnection alloc] initWithRequest:self.URLRequest
                                                delegate:self
                                        startImmediately:YES];
#pragma clang diagnostic pop
}

- (void) finish {
  [self willChangeValueForKey:@"isExecuting"];
  [self willChangeValueForKey:@"isFinished"];
  self.isExecuting = NO;
  self.isFinished = YES;
  [self didChangeValueForKey:@"isExecuting"];
  [self didChangeValueForKey:@"isFinished"];
}

#pragma mark - NSURLConnectionDelegate
-(void)connection:(NSURLConnection*) __unused connection didReceiveResponse:(NSURLResponse*)response {
  self.mutableData = [[NSMutableData alloc] init];
  self.response = (id)response;
}

-(void)connection:(NSURLConnection*) __unused connection didReceiveData:(NSData*)data {
  [self.mutableData appendData:data];
}

-(void)connection:(NSURLConnection*) __unused connection didFailWithError:(NSError*)error {
  //FINISHED and failed
  self.error = error;
  self.mutableData = nil;
  
  [self finish];
}

-(void)connectionDidFinishLoading:(NSURLConnection*) __unused connection {
  [self finish];
}

#pragma mark - Public interface
- (NSData *)data {
  return self.mutableData;
}

- (void)setCompletion:(BITNetworkCompletionBlock)completion {
  if(!completion) {
    [super setCompletionBlock:nil];
  } else {
    __weak typeof(self) weakSelf = self;
    [super setCompletionBlock:^{
      typeof(self) strongSelf = weakSelf;
      if(strongSelf) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if(!strongSelf.isCancelled) {
            completion(strongSelf, strongSelf.data, strongSelf.error);
          }
          [strongSelf setCompletionBlock:nil];
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
