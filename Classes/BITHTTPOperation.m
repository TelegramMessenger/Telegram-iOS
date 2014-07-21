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
  _isExecuting = YES;
  [self didChangeValueForKey:@"isExecuting"];
  
  _connection = [[NSURLConnection alloc] initWithRequest:_URLRequest
                                                delegate:self
                                        startImmediately:YES];
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
  _response = (id)response;
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
  if(!completion) {
    [super setCompletionBlock:nil];
  } else {
    __weak typeof(self) weakSelf = self;
    [super setCompletionBlock:^{
      typeof(self) strongSelf = weakSelf;
      if(strongSelf) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if(!strongSelf.isCancelled) {
            completion(strongSelf, strongSelf->_data, strongSelf->_error);
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
