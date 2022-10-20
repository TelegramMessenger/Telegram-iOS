// AFHTTPOperation.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <MtProtoKit/AFHTTPRequestOperation.h>

static NSString * AFStringFromIndexSet(NSIndexSet *indexSet) {
    NSMutableString *string = [NSMutableString string];

    NSRange range = NSMakeRange([indexSet firstIndex], 1);
    while (range.location != NSNotFound) {
        NSUInteger nextIndex = [indexSet indexGreaterThanIndex:range.location];
        while (nextIndex == range.location + range.length) {
            range.length++;
            nextIndex = [indexSet indexGreaterThanIndex:nextIndex];
        }

        if (string.length) {
            [string appendString:@","];
        }

        if (range.length == 1) {
            [string appendFormat:@"%lu", (unsigned long)range.location];
        } else {
            NSUInteger firstIndex = range.location;
            NSUInteger lastIndex = firstIndex + range.length - 1;
            [string appendFormat:@"%lu-%lu", (unsigned long)firstIndex, (unsigned long)lastIndex];
        }

        range.location = nextIndex;
        range.length = 1;
    }

    return string;
}

#pragma mark -

@interface AFHTTPRequestOperation ()
@property (readwrite, nonatomic, strong) NSError *HTTPError;
@property (nonatomic) dispatch_once_t onceToken;
@property (atomic) dispatch_semaphore_t dispatchSemaphore;
@end

@implementation AFHTTPRequestOperation
@synthesize acceptableStatusCodes = _acceptableStatusCodes;
@synthesize acceptableContentTypes = _acceptableContentTypes;
@synthesize HTTPError = _HTTPError;
@synthesize successCallbackQueue = _successCallbackQueue;
@synthesize failureCallbackQueue = _failureCallbackQueue;
@synthesize dispatchGroup = _dispatchGroup;
@synthesize onceToken = _onceToken;
@synthesize dispatchSemaphore = _dispatchSemaphore;


- (id)initWithRequest:(NSURLRequest *)request {
    self = [super initWithRequest:request];
    if (!self) {
        return nil;
    }
    
    self.acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
    self.dispatchSemaphore = dispatch_semaphore_create(1);
    self.completionBlock = NULL;
    
    return self;
}

- (NSHTTPURLResponse *)response {
    return (NSHTTPURLResponse *)[super response];
}

- (NSError *)error {
    if (self.response && !self.HTTPError) {
        if (![self hasAcceptableStatusCode]) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"Expected status code in (%@), got %ld", nil), AFStringFromIndexSet(self.acceptableStatusCodes), (long)[self.response statusCode]] forKey:NSLocalizedDescriptionKey];
            [userInfo setValue:[self.request URL] forKey:NSURLErrorFailingURLErrorKey];
            
            self.HTTPError = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
        } else if ([self.responseData length] > 0 && ![self hasAcceptableContentType]) { // Don't invalidate content type if there is no content
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:[NSString stringWithFormat:NSLocalizedString(@"Expected content type %@, got %@", nil), self.acceptableContentTypes, [self.response MIMEType]] forKey:NSLocalizedDescriptionKey];
            [userInfo setValue:[self.request URL] forKey:NSURLErrorFailingURLErrorKey];
            
            self.HTTPError = [[NSError alloc] initWithDomain:AFNetworkingErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:userInfo];
        }
    }
    
    if (self.HTTPError) {
        return self.HTTPError;
    } else {
        return [super error];
    }
}

- (BOOL)hasAcceptableStatusCode {
    return !self.acceptableStatusCodes || [self.acceptableStatusCodes containsIndex:(NSUInteger)[self.response statusCode]];
}

- (BOOL)hasAcceptableContentType {
    return !self.acceptableContentTypes || [self.acceptableContentTypes containsObject:[self.response MIMEType]];
}

- (void)setSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue {
    if (successCallbackQueue != _successCallbackQueue) {
        _successCallbackQueue = successCallbackQueue;
    }    
}

- (void)setFailureCallbackQueue:(dispatch_queue_t)failureCallbackQueue {
    if (failureCallbackQueue != _failureCallbackQueue) {
        _failureCallbackQueue = failureCallbackQueue;
    }    
}

- (void)setDispatchGroup:(dispatch_group_t)dispatchGroup {
    dispatch_semaphore_wait(self.dispatchSemaphore, DISPATCH_TIME_FOREVER);
    if (dispatchGroup != _dispatchGroup) {
        if (_dispatchGroup) {
            dispatch_group_leave(_dispatchGroup);
            _dispatchGroup = NULL;
        }
        
        if (dispatchGroup) {
            _dispatchGroup = dispatchGroup;
            dispatch_group_enter(_dispatchGroup);
        }
    } 
    dispatch_semaphore_signal(self.dispatchSemaphore);
}

- (dispatch_group_t)dispatchGroup {
    dispatch_semaphore_wait(self.dispatchSemaphore, DISPATCH_TIME_FOREVER);
    if(_dispatchGroup == NULL) {
        _dispatchGroup = dispatch_group_create();
        dispatch_group_enter(_dispatchGroup);
    }
    dispatch_semaphore_signal(self.dispatchSemaphore);
    return _dispatchGroup;
}

- (void)setCompletionBlock:(void (^)(void))block {
     __block id _blockSelf = self;
    dispatch_once_t *blockOnceToken = &_onceToken;
    
    [super setCompletionBlock:^{
        if(block) {
            block();
        }
        // Dispatch once is used to ensure that setting the block with this block will not cause multiple calls to 'dispatch_group_leave'
        dispatch_once(blockOnceToken, ^{
            dispatch_group_leave([_blockSelf dispatchGroup]);
        });
    }];
}

- (void)setCompletionBlockWithSuccess:(void (^)(NSOperation *operation, id responseObject))success
                              failure:(void (^)(NSOperation *operation, NSError *error))failure
{
    __weak typeof(self) weakSelf = self;
    self.completionBlock = ^ {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if ([strongSelf isCancelled]) {
            return;
        }
        
        if (strongSelf.error) {
            if (failure) {
                dispatch_group_async(strongSelf.dispatchGroup, strongSelf.failureCallbackQueue ? strongSelf.failureCallbackQueue : dispatch_get_main_queue(), ^{
                    failure(strongSelf, strongSelf.error);
                });
            }
        } else {
            if (success) {
                dispatch_group_async(strongSelf.dispatchGroup, strongSelf.successCallbackQueue ? strongSelf.successCallbackQueue : dispatch_get_main_queue(), ^{
                    success(strongSelf, strongSelf.responseData);
                });
            }
        }
    };
}

#pragma mark - AFHTTPClientOperation

+ (BOOL)canProcessRequest:(NSURLRequest *)__unused request {
    return YES;
}

@end
