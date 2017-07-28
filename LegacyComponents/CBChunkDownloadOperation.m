//
// Created by Tikhonenko Pavel on 23/05/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import "CBChunkDownloadOperation.h"

#import "LegacyComponentsInternal.h"
#import "LegacyHTTPRequestOperation.h"

@implementation CBChunkDownloadOperation
{

}

- (void)start
{
	[super start];
	[self downloadChunk];
}

- (void)downloadChunk
{
	NSURL *localURL = [self.coub localAudioChunkWithIdx:_chunkIdx];
	
	NSURL *remoteURL = [self.coub remoteAudioChunkWithIdx:_chunkIdx+1];

	NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:remoteURL];

    self.downloadOperation = [[LegacyComponentsGlobals provider] makeHTTPRequestOperationWithRequest:downloadRequest];
	self.downloadOperation.queuePriority = self.queuePriority;
	self.downloadOperation.outputStream = [NSOutputStream outputStreamToFileAtPath:localURL.path append:NO];
	//[self.downloadOperation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];

	__weak typeof(self) wSelf = self;
	
	[self.downloadOperation setCompletionBlockWithSuccess:^(__unused id operation, __unused id responseObject) {
		[wSelf successChunkDownload];
	} failure:^(__unused id operation, __unused NSError *error) {
		[wSelf failureDownloadWithError:error];
	}];

	[self.downloadOperation start];
}

- (void)successChunkDownload
{
	//NSLog(@"successChunkDownload");

	[self successDownload];
}

- (instancetype)clone
{
	CBChunkDownloadOperation *clone = [CBChunkDownloadOperation new];
	[clone setTag:self.tag];
	[clone setCoub:self.coub];
	[clone setCompletionBlock:self.completionBlock];
	[clone setClientSuccess:self.clientSuccess];
	[clone setClientFailure:self.clientFailure];
	[clone setChunkDownloadedBlock:self.chunkDownloadedBlock];
	return clone;
}

@end
