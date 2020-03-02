//
// Created by Tikhonenko Pavel on 23/05/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import "CBCoubDownloadOperation.h"
#import "CBDownloadOperationDelegate.h"

#import "LegacyComponentsInternal.h"

@implementation CBCoubDownloadOperation
{
	BOOL _isVideoDownloaded;
	NSInteger _currentChunkIdx;
}

- (void)start
{
	[super start];

	_neededChunkCount = NSNotFound;
	_currentChunkIdx = 0;

	[self downloadVideo];
}

- (void)downloadVideo
{
	NSURL *remoteURL = [self.coub remoteVideoFileURL];
	NSURL *localURL = [self.coub localVideoFileURL];

    _isVideoDownloaded = [[NSFileManager defaultManager] fileExistsAtPath:[localURL path]];
	if(_isVideoDownloaded)
	{
		[self successVideoDownload];
		return;
	}else{
		//KALog(@"video doesn't %i", _currentChunkIdx);
	}

	NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:remoteURL];

	__weak typeof(self) wSelf = self;

    self.downloadOperation = [[LegacyComponentsGlobals provider] makeHTTPRequestOperationWithRequest:downloadRequest];
	self.downloadOperation.queuePriority = self.queuePriority;
	self.downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:localURL.path append:NO];
	//[self.downloadOperation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
	[self.downloadOperation setDownloadProgressBlock:^(__unused NSInteger bytesRead, NSInteger totalBytesRead, NSInteger totalBytesExpectedToRead) {
		float progress = totalBytesRead / (float) totalBytesExpectedToRead;
		[wSelf progressDownload:progress];
	}];

	[self.downloadOperation setCompletionBlockWithSuccess:^(__unused id operation, __unused id responseObject) {
		[wSelf successVideoDownload];
	} failure:^(__unused id operation, NSError *error) {

		if([[NSFileManager defaultManager] fileExistsAtPath:[localURL path]])
			[[NSFileManager defaultManager] removeItemAtPath:[localURL path] error:nil];

		[wSelf failureDownloadWithError:error];
	}];

	[self.downloadOperation start];
}

- (void)downloadChunk
{
	NSURL *localURL = [self.coub localAudioChunkWithIdx:_currentChunkIdx];
	
	//int fileExist = [[CBLibrary sharedLibrary] isCoubChunkDownloadedByPermalink:self.coub.permalink idx:_currentChunkIdx];
	int fileExist = [[NSFileManager defaultManager] fileExistsAtPath:[localURL path]];

	if(fileExist || (_neededChunkCount == NSNotFound && _currentChunkIdx > 1))
	{
		[self successDownload];
		return;
	}

	NSURL *remoteURL = [self.coub remoteAudioChunkWithIdx:_currentChunkIdx + 1];
	NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:remoteURL];

	//NSLog(@"chunk idx = %i, remoteURL = %@", _currentChunkIdx, remoteURL);

	__weak typeof(self) wSelf = self;

	self.downloadOperation = [[LegacyComponentsGlobals provider] makeHTTPRequestOperationWithRequest:downloadRequest];
	self.downloadOperation.queuePriority = self.queuePriority;
	self.downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:localURL.path append:NO];
	//[self.downloadOperation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
	[self.downloadOperation setDownloadProgressBlock:^(__unused NSInteger bytesRead, NSInteger totalBytesRead, NSInteger totalBytesExpectedToRead) {

		if(wSelf.neededChunkCount == NSNotFound)
		{
			//NSLog(@"totalBytesExpectedToRead = %llu", totalBytesExpectedToRead);

			wSelf.neededChunkCount = MIN((int) ((1024*1024)/totalBytesExpectedToRead), 4);
			wSelf.neededChunkCount = MAX(wSelf.neededChunkCount, 1);
		}

		float progress = totalBytesRead / (float) totalBytesExpectedToRead;
		[wSelf progressDownload:progress];
	}];

	[self.downloadOperation setCompletionBlockWithSuccess:^(__unused id operation, __unused id responseObject) {
		//[wSelf.coub setFailedDownloadChunk:NO];
		[wSelf successChunkDownload];
	} failure:^(__unused id operation, NSError *error) {

		if([[NSFileManager defaultManager] fileExistsAtPath:[localURL path]])
			[[NSFileManager defaultManager] removeItemAtPath:[localURL path] error:nil];

		if(error.code == -1011)
		{
			//NSLog(@"failed download");

			//[wSelf.coub setFailedDownloadChunk:YES];
			[wSelf successDownload];

			return;
		}
		//NSLog(@"failed download unknown");
		
		[wSelf failureDownloadWithError:error];
	}];

	[self.downloadOperation start];
}

- (void)successVideoDownload
{
	//[[CBLibrary sharedLibrary] markCoubAsset:self.coub asDownloaded:YES];

	_isVideoDownloaded = YES;

	if(self.starting)
	{
		if(self.chunkDownloadingNeeded && [self.coub audioType] == CBCoubAudioTypeExternal)
			[self downloadChunk];
		else
			[super successDownload];
	}
}

- (void)successDownload
{
	_currentChunkIdx++;

	if([self.coub audioType] != CBCoubAudioTypeExternal || _currentChunkIdx >= MIN(4, _neededChunkCount))
	{
		[super successDownload];
	}
	else
		[self downloadChunk];
}

- (void)successChunkDownload
{
	[self successDownload];
}

- (void)progressDownload:(float)progress
{
	if(self.starting && self.operationViewDelegate)
	{
		float newProgress;

		if(_isVideoDownloaded)
		{
			newProgress = .5f + (_currentChunkIdx * 1/(float)_neededChunkCount + progress/(float)_neededChunkCount)*.5f;
		}else{
			newProgress = progress/2.0f;
		}
		[self.operationViewDelegate downloadDidReachProgress:newProgress];
	}
}

- (instancetype)clone
{
	CBCoubDownloadOperation *clone = [CBCoubDownloadOperation new];
	[clone setOperationViewDelegate:self.operationViewDelegate];
	[clone setTag:self.tag];
	[clone setCoub:self.coub];
	[clone setCompletionBlock:self.completionBlock];
	[clone setClientSuccess:self.clientSuccess];
	[clone setClientFailure:self.clientFailure];
	return clone;
}

@end
