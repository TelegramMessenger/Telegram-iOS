//
// Created by Tikhonenko Pavel on 27/05/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import "CBGenericDownloadOperation.h"
#import "CBCoubAsset.h"

@implementation CBGenericDownloadOperation
{
	NSOperationQueuePriority _queuePriority;
}

- (NSOperationQueuePriority)queuePriority
{
	return _queuePriority;
}

- (void)setQueuePriority:(NSOperationQueuePriority)queuePriority
{
	_queuePriority = queuePriority;

	if(_downloadOperation)
		_downloadOperation.queuePriority = queuePriority;
}

- (void)start
{
	self.starting = YES;
}

- (void)cancel
{
	self.starting = NO;

	NSError *cancelError = nil;

	if (!_downloadOperation.isFinished && !_downloadOperation.isCancelled)
	{
		//cancelError = [NSError errorWithDomain:kCBAssetDownloadManagerErrorDomain code:99 userInfo:nil];
		[_downloadOperation cancel];
	}

	[_operationViewDelegate downloadHasBeenCancelledWithError:cancelError];

	self.clientSuccess = nil;
	self.clientFailure = nil;
}

- (void)successDownload
{
	if(self.starting)
	{
		self.starting = NO;
		self.comleted = YES;
		
		if(self.operationViewDelegate != nil)[self.operationViewDelegate downloadHasBeenCancelledWithError:nil];
		if(self.clientSuccess != nil) self.clientSuccess(self.coub, self.tag);
		if(self.completionBlock != nil) self.completionBlock(self, nil);
		
		self.downloadOperation = nil;
	}
}


- (void)failureDownloadWithError:(NSError *)error
{
	if(self.starting)
	{
		self.starting = NO;
		self.comleted = YES;
		
		if(self.operationViewDelegate != nil)[self.operationViewDelegate downloadHasBeenCancelledWithError:error];
		if(self.clientFailure != nil) self.clientFailure(self.coub, self.tag, error);
		if(self.completionBlock != nil) self.completionBlock(self, error);
	}
}

- (instancetype)clone
{
	return nil;
}

- (void)dealloc
{
	self.completionBlock = nil;
}

@end
