//
//  ASBasicImageDownloader.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//
#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASBasicImageDownloader.h>

#import <Foundation/NSURLSession.h>
#import <objc/runtime.h>

#import <AsyncDisplayKit/ASBasicImageDownloaderInternal.h>
#import <AsyncDisplayKit/ASImageContainerProtocolCategories.h>
#import <AsyncDisplayKit/ASThread.h>

using AS::MutexLocker;

#pragma mark -
/**
 * Collection of properties associated with a download request.
 */

NSString * const kASBasicImageDownloaderContextCallbackQueue = @"kASBasicImageDownloaderContextCallbackQueue";
NSString * const kASBasicImageDownloaderContextProgressBlock = @"kASBasicImageDownloaderContextProgressBlock";
NSString * const kASBasicImageDownloaderContextCompletionBlock = @"kASBasicImageDownloaderContextCompletionBlock";

static inline float NSURLSessionTaskPriorityWithImageDownloaderPriority(ASImageDownloaderPriority priority) {
  switch (priority) {
    case ASImageDownloaderPriorityPreload:
      return NSURLSessionTaskPriorityLow;

    case ASImageDownloaderPriorityImminent:
      return NSURLSessionTaskPriorityDefault;

    case ASImageDownloaderPriorityVisible:
      return NSURLSessionTaskPriorityHigh;
  }
}

@interface ASBasicImageDownloaderContext ()
{
  BOOL _invalid;
  AS::RecursiveMutex __instanceLock__;
}

@property (nonatomic) NSMutableArray *callbackDatas;

@end

@implementation ASBasicImageDownloaderContext

static NSMutableDictionary *currentRequests = nil;

+ (AS::Mutex *)currentRequestLock
{
  static dispatch_once_t onceToken;
  static AS::Mutex *currentRequestsLock;
  dispatch_once(&onceToken, ^{
    currentRequestsLock = new AS::Mutex();
  });
  return currentRequestsLock;
}

+ (ASBasicImageDownloaderContext *)contextForURL:(NSURL *)URL
{
  MutexLocker l(*self.currentRequestLock);
  if (!currentRequests) {
    currentRequests = [[NSMutableDictionary alloc] init];
  }
  ASBasicImageDownloaderContext *context = currentRequests[URL];
  if (!context) {
    context = [[ASBasicImageDownloaderContext alloc] initWithURL:URL];
    currentRequests[URL] = context;
  }
  return context;
}

+ (void)cancelContextWithURL:(NSURL *)URL
{
  MutexLocker l(*self.currentRequestLock);
  if (currentRequests) {
    [currentRequests removeObjectForKey:URL];
  }
}

- (instancetype)initWithURL:(NSURL *)URL
{
  if (self = [super init]) {
    _URL = URL;
    _callbackDatas = [NSMutableArray array];
  }
  return self;
}

- (void)cancel
{
  MutexLocker l(__instanceLock__);

  NSURLSessionTask *sessionTask = self.sessionTask;
  if (sessionTask) {
    [sessionTask cancel];
    self.sessionTask = nil;
  }

  _invalid = YES;
  [self.class cancelContextWithURL:self.URL];
}

- (BOOL)isCancelled
{
  MutexLocker l(__instanceLock__);
  return _invalid;
}

- (void)addCallbackData:(NSDictionary *)callbackData
{
  MutexLocker l(__instanceLock__);
  [self.callbackDatas addObject:callbackData];
}

- (void)performProgressBlocks:(CGFloat)progress
{
  MutexLocker l(__instanceLock__);
  for (NSDictionary *callbackData in self.callbackDatas) {
    ASImageDownloaderProgress progressBlock = callbackData[kASBasicImageDownloaderContextProgressBlock];
    dispatch_queue_t callbackQueue = callbackData[kASBasicImageDownloaderContextCallbackQueue];

    if (progressBlock) {
      dispatch_async(callbackQueue, ^{
        progressBlock(progress);
      });
    }
  }
}

- (void)completeWithImage:(UIImage *)image error:(NSError *)error
{
  MutexLocker l(__instanceLock__);
  for (NSDictionary *callbackData in self.callbackDatas) {
    ASImageDownloaderCompletion completionBlock = callbackData[kASBasicImageDownloaderContextCompletionBlock];
    dispatch_queue_t callbackQueue = callbackData[kASBasicImageDownloaderContextCallbackQueue];

    if (completionBlock) {
      dispatch_async(callbackQueue, ^{
        completionBlock(image, error, nil, nil);
      });
    }
  }

  self.sessionTask = nil;
  [self.callbackDatas removeAllObjects];
}

- (NSURLSessionTask *)createSessionTaskIfNecessaryWithBlock:(NSURLSessionTask *(^)())creationBlock {
  {
    MutexLocker l(__instanceLock__);

    if (self.isCancelled) {
      return nil;
    }

    if (self.sessionTask && (self.sessionTask.state == NSURLSessionTaskStateRunning)) {
      return nil;
    }
  }

  NSURLSessionTask *newTask = creationBlock();

  {
    MutexLocker l(__instanceLock__);

    if (self.isCancelled) {
      return nil;
    }

    if (self.sessionTask && (self.sessionTask.state == NSURLSessionTaskStateRunning)) {
      return nil;
    }

    self.sessionTask = newTask;
    
    return self.sessionTask;
  }
}

@end


#pragma mark -
/**
 * NSURLSessionDownloadTask lacks a `userInfo` property, so add this association ourselves.
 */
@interface NSURLRequest (ASBasicImageDownloader)
@property (nonatomic) ASBasicImageDownloaderContext *asyncdisplaykit_context;
@end

@implementation NSURLRequest (ASBasicImageDownloader)

static const void *ContextKey() {
  return @selector(asyncdisplaykit_context);
}

- (void)setAsyncdisplaykit_context:(ASBasicImageDownloaderContext *)asyncdisplaykit_context
{
  objc_setAssociatedObject(self, ContextKey(), asyncdisplaykit_context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (ASBasicImageDownloader *)asyncdisplaykit_context
{
  return objc_getAssociatedObject(self, ContextKey());
}
@end


#pragma mark -
@interface ASBasicImageDownloader () <NSURLSessionDownloadDelegate>
{
  NSOperationQueue *_sessionDelegateQueue;
  NSURLSession *_session;
}

@end

@implementation ASBasicImageDownloader

+ (ASBasicImageDownloader *)sharedImageDownloader
{
  static ASBasicImageDownloader *sharedImageDownloader = nil;
  static dispatch_once_t once = 0;
  dispatch_once(&once, ^{
    sharedImageDownloader = [[ASBasicImageDownloader alloc] _init];
  });
  return sharedImageDownloader;
}

#pragma mark Lifecycle.

- (instancetype)_init
{
  if (!(self = [super init]))
    return nil;

  _sessionDelegateQueue = [[NSOperationQueue alloc] init];
  _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                           delegate:self
                                      delegateQueue:_sessionDelegateQueue];

  return self;
}


#pragma mark ASImageDownloaderProtocol.

- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(nullable ASImageDownloaderProgress)downloadProgress
                         completion:(ASImageDownloaderCompletion)completion
{
  return [self downloadImageWithURL:URL
                           priority:ASImageDownloaderPriorityImminent // maps to default priority
                      callbackQueue:callbackQueue
                   downloadProgress:downloadProgress
                         completion:completion];
}

- (nullable id)downloadImageWithURL:(NSURL *)URL
                           priority:(ASImageDownloaderPriority)priority
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(ASImageDownloaderProgress)downloadProgress
                         completion:(ASImageDownloaderCompletion)completion
{
  ASBasicImageDownloaderContext *context = [ASBasicImageDownloaderContext contextForURL:URL];

  // NSURLSessionDownloadTask will do file I/O to create a temp directory. If called on the main thread this will
  // cause significant performance issues.
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // associate metadata with it
    const auto callbackData = [[NSMutableDictionary alloc] init];
    callbackData[kASBasicImageDownloaderContextCallbackQueue] = callbackQueue ? : dispatch_get_main_queue();

    if (downloadProgress) {
      callbackData[kASBasicImageDownloaderContextProgressBlock] = [downloadProgress copy];
    }

    if (completion) {
      callbackData[kASBasicImageDownloaderContextCompletionBlock] = [completion copy];
    }

    [context addCallbackData:[[NSDictionary alloc] initWithDictionary:callbackData]];

    // Create new task if necessary
    NSURLSessionDownloadTask *task = (NSURLSessionDownloadTask *)[context createSessionTaskIfNecessaryWithBlock:^(){return [_session downloadTaskWithURL:URL];}];

    if (task) {
      task.priority = NSURLSessionTaskPriorityWithImageDownloaderPriority(priority);
      task.originalRequest.asyncdisplaykit_context = context;

      // start downloading
      [task resume];
    }
  });

  return context;
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:ASBasicImageDownloaderContext.class], @"unexpected downloadIdentifier");
  ASBasicImageDownloaderContext *context = (ASBasicImageDownloaderContext *)downloadIdentifier;

  [context cancel];
}


#pragma mark NSURLSessionDownloadDelegate.

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  ASBasicImageDownloaderContext *context = downloadTask.originalRequest.asyncdisplaykit_context;
  [context performProgressBlocks:(CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite];
}

// invoked if the download succeeded with no error
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location
{
  ASBasicImageDownloaderContext *context = downloadTask.originalRequest.asyncdisplaykit_context;
  if ([context isCancelled]) {
    return;
  }

  if (context) {
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];
    [context completeWithImage:image error:nil];
  }
}

// invoked unconditionally
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)task
                           didCompleteWithError:(NSError *)error
{
  ASBasicImageDownloaderContext *context = task.originalRequest.asyncdisplaykit_context;
  if (context && error) {
    [context completeWithImage:nil error:error];
  }
}

@end

#endif
