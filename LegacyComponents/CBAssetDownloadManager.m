//
// Created by Tikhonenko Pavel on 23/05/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import "CBAssetDownloadManager.h"
#import "CBCoubDownloadOperation.h"
#import "CBChunkDownloadOperation.h"
#import "CBDownloadOperation.h"
#import "CBDownloadOperationDelegate.h"


@interface CBAssetDownloadManager ()

@property (nonatomic, strong) CBCoubDownloadOperation *currentCoubDownloadingOperation;
@property (nonatomic, strong) CBCoubDownloadOperation *pausedCoubDownloadingOperation;
@property (nonatomic, strong) CBCoubDownloadOperation *nextCoubDownloadingOperation;
@property (nonatomic, strong) CBChunkDownloadOperation *currentChunksDownloadingOperation;

- (void)resumeCoubDownloading;
- (void)destroyDownloadOperation:(id<CBDownloadOperation>)downloadOperation;

- (id<CBDownloadOperation>)operationWithType:(CBDownloadProcessType)type
										coub:(id<CBCoubAsset>)coub tag:(NSInteger)tag
							  downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success
							 downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;
@end

@implementation CBAssetDownloadManager

- (id)init
{
	self = [super init];

	if(self)
	{
	}

	return self;
}

- (void)downloadCoubWithoutChunks:(id<CBCoubAsset>)coub
                 tag:(NSInteger)tag
        withDelegate:(id<CBDownloadOperationDelegate>)delegate
      downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure
{
    if(_currentChunksDownloadingOperation)
    {
        //_pausedCoubDownloadingOperation = _currentChunksDownloadingOperation;
        [self destroyDownloadOperation:_currentChunksDownloadingOperation];
        _currentChunksDownloadingOperation = nil;
    }
    
    [self downloadCoub:coub tag:tag withDelegate:delegate queuePriority:NSOperationQueuePriorityNormal withChunks:NO downloadSucces:success downloadFailure:failure];
}


#pragma mark -
#pragma mark Downloading video and first chunk

- (void)downloadCoub:(id<CBCoubAsset>)coub
				 tag:(NSInteger)tag
		withDelegate:(id<CBDownloadOperationDelegate>)delegate
          withChunks:(BOOL)withChunks
	  downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure
{
	if(_currentChunksDownloadingOperation)
	{
		//_pausedCoubDownloadingOperation = _currentChunksDownloadingOperation;
		[self destroyDownloadOperation:_currentChunksDownloadingOperation];
		_currentChunksDownloadingOperation = nil;
	}

    [self downloadCoub:coub tag:tag withDelegate:delegate queuePriority:NSOperationQueuePriorityNormal withChunks:withChunks downloadSucces:success downloadFailure:failure];
}

- (void)downloadCoub:(id<CBCoubAsset>)coub
				 tag:(NSInteger)tag
		withDelegate:(id<CBDownloadOperationDelegate>)delegate
	   queuePriority:(NSOperationQueuePriority)queuePriority
          withChunks:(BOOL)withChunks
	  downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure
{
	if(_currentCoubDownloadingOperation && _currentCoubDownloadingOperation.coub == coub && !_currentChunksDownloadingOperation.comleted)
	{
		_currentCoubDownloadingOperation.operationViewDelegate = delegate;
		[_currentCoubDownloadingOperation setClientSuccess:success];
		[_currentCoubDownloadingOperation setClientFailure:failure];
		return;
	}

	if(_nextCoubDownloadingOperation && _nextCoubDownloadingOperation.coub == coub && !_nextCoubDownloadingOperation.comleted)
	{
		[self destroyDownloadOperation:_nextCoubDownloadingOperation];
	}

	if(_currentCoubDownloadingOperation)
		[self destroyDownloadOperation:_currentCoubDownloadingOperation];

	id<CBDownloadOperation> downloadOperation = [self operationWithType:CBDownloadProcessTypeCoub
																   coub:coub tag:tag downloadSucces:success downloadFailure:failure];
	downloadOperation.queuePriority = queuePriority;

	_currentCoubDownloadingOperation = downloadOperation;
    _currentCoubDownloadingOperation.chunkDownloadingNeeded = withChunks;
	[_currentCoubDownloadingOperation setOperationViewDelegate:delegate];
	[_currentCoubDownloadingOperation start];
}

- (void)downloadNextCoub:(id<CBCoubAsset>)coub
				 	 tag:(NSInteger)tag
	 	  downloadSucces:(void (^)(id<CBCoubAsset> coub,NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub,NSInteger tag, NSError *error))failure
{
	if(_currentChunksDownloadingOperation && _currentChunksDownloadingOperation.coub == coub && !_currentChunksDownloadingOperation.comleted)
	{
		failure(self, 0, nil);
		return;
	}


	if(_nextCoubDownloadingOperation)
		[self destroyDownloadOperation:_nextCoubDownloadingOperation];


	id<CBDownloadOperation> downloadOperation = [self operationWithType:CBDownloadProcessTypeCoub
																   coub:coub tag:tag downloadSucces:success downloadFailure:failure];
	downloadOperation.queuePriority = NSOperationQueuePriorityVeryLow;

	_nextCoubDownloadingOperation = downloadOperation;
	[_nextCoubDownloadingOperation setOperationViewDelegate:nil];
	[_nextCoubDownloadingOperation start];
}

- (void)cancelDownloadingForCoub:(id<CBCoubAsset>)coub
{
	if(_currentCoubDownloadingOperation && _currentCoubDownloadingOperation.coub == coub)
		[self destroyDownloadOperation:_currentCoubDownloadingOperation];
}

#pragma mark -
#pragma mark Downloading remaining chunks

- (void)downloadChunkWithCoub:(id<CBCoubAsset>)coub
						  tag:(NSInteger)tag
					 chunkIdx:(NSInteger)chunkIdx
			   downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success
			  downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure
{
	[self destroyDownloadOperation:_currentChunksDownloadingOperation];

	_currentChunksDownloadingOperation = [self operationWithType:CBDownloadProcessTypeChunks coub:coub
															 tag:tag downloadSucces:success downloadFailure:failure];
	
	__weak typeof(self) wSelf = self;
	
	_currentChunksDownloadingOperation.chunkIdx = chunkIdx;
	[_currentChunksDownloadingOperation setCompletionBlock:^(id<CBDownloadOperation> process, NSError *error) {
		[wSelf destroyDownloadOperation:process];
		[wSelf resumeCoubDownloading];
	}];

	[_currentChunksDownloadingOperation start];
}

- (void)downloadNextChunkWithCoub:(id<CBCoubAsset>)coub
				   downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success
				  downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure
{
	NSInteger chunkIdx = 0;
	[self downloadChunkWithCoub:coub tag:chunkIdx chunkIdx:chunkIdx downloadSucces:success downloadFailure:failure];
}

- (void)downloadRemainingChunksWithCoub:(id<CBCoubAsset>)coub tag:(NSInteger)tag
					downloadChunkSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSInteger chunkIdx))chunkDownloaded
						 downloadSucces:(void (^)(id<CBCoubAsset> coub,NSInteger tag))success
						downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure
{
	[self destroyDownloadOperation:_currentChunksDownloadingOperation];

	_currentChunksDownloadingOperation = [self operationWithType:CBDownloadProcessTypeChunks coub:coub
															 tag:tag downloadSucces:success downloadFailure:failure];
	
	__weak typeof(self) wSelf = self;
	
	_currentChunksDownloadingOperation.chunkDownloadedBlock = chunkDownloaded;
	[_currentChunksDownloadingOperation setCompletionBlock:^(id<CBDownloadOperation> process, NSError *error) {
		[wSelf destroyDownloadOperation:process];
		[wSelf resumeCoubDownloading];
	}];

	[_currentChunksDownloadingOperation start];
}

- (void)stopAllDownloads
{
	[self destroyCurrentOperations];

	_pausedCoubDownloadingOperation = nil;
}

#pragma mark -
#pragma mark private method

- (void)resumeCoubDownloading
{
	if(_pausedCoubDownloadingOperation)
	{
		_currentCoubDownloadingOperation = _pausedCoubDownloadingOperation;
		[_currentCoubDownloadingOperation start];
	}
}

- (void)destroyCurrentOperations
{
	[self destroyDownloadOperation:_currentCoubDownloadingOperation];

	[self destroyDownloadOperation:_currentChunksDownloadingOperation];

	//_pausedCoubDownloadingOperation = nil;
}

- (void)destroyDownloadOperation:(id<CBDownloadOperation>)downloadOperation
{
	if(downloadOperation)
		[downloadOperation cancel];
	
	if(downloadOperation == _currentCoubDownloadingOperation)
		_currentCoubDownloadingOperation = nil;
	
	if(downloadOperation == _currentChunksDownloadingOperation)
		_currentChunksDownloadingOperation = nil;
}

#pragma mark -
#pragma mark Factory method

- (id<CBDownloadOperation>)operationWithType:(CBDownloadProcessType)type
										coub:(id<CBCoubAsset>)coub tag:(NSInteger)tag
							  downloadSucces:(void (^)(id<CBCoubAsset>, NSInteger tag))success
							 downloadFailure:(void (^)(id<CBCoubAsset>, NSInteger tag, NSError *error))failure
{
	id<CBDownloadOperation> downloadOperation;

	switch(type)
	{
		case CBDownloadProcessTypeCoub:
		{
			downloadOperation = [CBCoubDownloadOperation new];
			break;
		}

		case CBDownloadProcessTypeChunks:
		{
			downloadOperation = [CBChunkDownloadOperation new];
			break;
		}
	}

	[downloadOperation setTag:tag];
	[downloadOperation setCoub:coub];
	[downloadOperation setClientSuccess:success];
	[downloadOperation setClientFailure:failure];
	
	__weak typeof(self) wSelf = self;
	
	[downloadOperation setCompletionBlock:^(id<CBCoubAsset> operation, NSError *error) {
		[wSelf destroyDownloadOperation:operation];
		[wSelf resumeCoubDownloading];
	}];

	return downloadOperation;
}

#pragma mark -
#pragma mark Singleton implementation

static CBAssetDownloadManager *instance = nil;

+ (instancetype)sharedManager
{
	if(instance != nil) return instance;

	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		instance = [[self alloc] init];
	});
	return instance;
}

@end