/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTHttpWorker.h"

#import "MTTimer.h"
#import "MTQueue.h"

#import "MTDatacenterAddress.h"

#import "MTInternalId.h"

MTInternalIdClass(MTHttpWorker)

@implementation MTHttpWorkerBlockDelegate

- (void)httpWorker:(MTHttpWorker *)__unused httpWorker completedWithData:(NSData *)data
{
    if (_completedWithData)
        _completedWithData(data);
}

- (void)httpWorkerConnected:(MTHttpWorker *)__unused httpWorker
{
    if (_connected)
        _connected();
}

- (void)httpWorkerFailed:(MTHttpWorker *)__unused httpWorker
{
    if (_failed)
        _failed();
}

@end

@interface MTHttpWorker ()
{
    MTTimer *_timeoutTimer;
    AFHTTPRequestOperation *_operation;
    bool _notifiedDelegateAboutConnection;
    bool _isConnected;
    bool _stopped;
    NSTimeInterval _timeout;
}

@end

@implementation MTHttpWorker

+ (MTQueue *)httpWorkerProcessingQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.httpWorkerProcessingQueue"];
    });
    return queue;
}

- (instancetype)initWithDelegate:(id<MTHttpWorkerDelegate>)delegate address:(MTDatacenterAddress *)address payloadData:(NSData *)payloadData performsLongPolling:(bool)performsLongPolling
{
    int32_t randomId = 0;
    arc4random_buf(&randomId, 4);
    
    NSString *urlString = [[NSString alloc] initWithFormat:@"http://%@:%d/api%" PRIx32 "", address.ip, (int)address.port, randomId];
    
    self = [super initWithBaseURL:[[NSURL alloc] initWithString:urlString]];
    if (self != nil)
    {
        _internalId = [[MTInternalId(MTHttpWorker) alloc] init];
        _delegate = delegate;
        _performsLongPolling = performsLongPolling;
        
        [[MTHttpWorker httpWorkerProcessingQueue] dispatchOnQueue:^
        {
            __weak MTHttpWorker *weakSelf = self;
            
            _timeout = performsLongPolling ? 40 : 12;
            _timeoutTimer = [[MTTimer alloc] initWithTimeout:_timeout repeat:false completion:^
            {
                MTHttpWorker *strongSelf = weakSelf;
                [strongSelf requestTimeout];
            } queue:[MTHttpWorker httpWorkerProcessingQueue].nativeQueue];
            [_timeoutTimer start];
            
            NSMutableURLRequest *urlRequest = [self requestWithMethod:@"POST" path:urlString parameters:nil];
            [urlRequest setHTTPBody:payloadData];
            
            _operation = [[AFHTTPRequestOperation alloc] initWithRequest:urlRequest];
            
            [_operation setSuccessCallbackQueue:[MTHttpWorker httpWorkerProcessingQueue].nativeQueue];
            [_operation setFailureCallbackQueue:[MTHttpWorker httpWorkerProcessingQueue].nativeQueue];
            
            [_operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, __unused id responseObject)
            {
                MTHttpWorker *strongSelf = weakSelf;
                [strongSelf requestCompleted:[operation responseData] error:nil];
            } failure:^(__unused AFHTTPRequestOperation *operation, NSError *error)
            {
                MTHttpWorker *strongSelf = weakSelf;
                [strongSelf requestCompleted:nil error:error];
            }];
            
            [_operation setUploadProgressBlock:^(__unused NSInteger bytesWritten, __unused NSInteger totalBytesWritten, __unused NSInteger totalBytesExpectedToWrite)
            {
                MTHttpWorker *strongSelf = weakSelf;
                [strongSelf requestUploadProgress];
            }];
            
            /*if (request.progressBlock != nil)
            {
                [httpOperation setDownloadProgressBlock:^(__unused NSInteger bytesRead, NSInteger totalBytesRead, NSInteger totalBytesExpectedToRead)
                {
                    if (totalBytesExpectedToRead > 0 && totalBytesRead > 0)
                    {
                        request.progressBlock(((float)totalBytesRead) / ((float)totalBytesExpectedToRead));
                    }
                }];
            }*/
            
            [self enqueueHTTPRequestOperation:_operation];
        }];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

- (bool)isConnected
{
    return _isConnected;
}

- (void)stop
{
    _stopped = true;
    
    AFHTTPRequestOperation *operation = _operation;
    _operation = nil;

    [[MTHttpWorker httpWorkerProcessingQueue] dispatchOnQueue:^
    {
        [operation cancel];
    }];
    
    [self cancelTimer];
}

- (void)terminateWithFailure
{
    [[MTHttpWorker httpWorkerProcessingQueue] dispatchOnQueue:^
    {
        [self stop];
        
        id<MTHttpWorkerDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(httpWorkerFailed:)])
            [delegate httpWorkerFailed:self];
    }];
}

- (void)cancelTimer
{
    if (_timeoutTimer != nil)
    {
        MTTimer *timeoutTimer = _timeoutTimer;
        _timeoutTimer = nil;
        
        [[MTHttpWorker httpWorkerProcessingQueue] dispatchOnQueue:^
        {
            [timeoutTimer invalidate];
        }];
    }
}

- (void)requestUploadProgress
{
    [[MTHttpWorker httpWorkerProcessingQueue] dispatchOnQueue:^
    {
        _isConnected = true;
        
        if (!_notifiedDelegateAboutConnection)
        {
            _notifiedDelegateAboutConnection = true;
            
            id<MTHttpWorkerDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(httpWorkerConnected:)])
                [delegate httpWorkerConnected:self];
        }
        
        [_timeoutTimer resetTimeout:_timeout];
    }];
}

- (void)requestCompleted:(NSData *)response error:(NSError *)error
{
    if (!_stopped)
    {
        id<MTHttpWorkerDelegate> delegate = _delegate;
        
        if (error == nil && response != nil)
        {   
            if ([delegate respondsToSelector:@selector(httpWorker:completedWithData:)])
                [delegate httpWorker:self completedWithData:response];
        }
        else
        {
            if ([delegate respondsToSelector:@selector(httpWorkerFailed:)])
                [delegate httpWorkerFailed:self];
        }
    }
    
    [self cancelTimer];
    _stopped = true;
    _operation = nil;
}

- (void)requestTimeout
{
    if (!_stopped)
    {
        [self stop];
        
        id<MTHttpWorkerDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(httpWorkerFailed:)])
            [delegate httpWorkerFailed:self];
    }
    
    [self cancelTimer];
    _stopped = true;
    _operation = nil;
}

@end
