//
//  CBCoubNew.m
//  Coub
//
//  Created by Tikhonenko Pavel on 18/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import "CBCoubNew.h"
//#import "Formatters.h"
//#import "NSDictionary+Extensions.h"
#import "CBLibrary.h"
#import "CBJSONCoubMapper.h"
#import "CBConstance.h"

@interface CBCoubNew ()
{
	BOOL _failedDownloadChunks;
}
@end

@implementation CBCoubNew

//- (void)setNaturalVideoSize:(CGSize)size
//{
//	_naturalVideoSize = size;
//}

- (BOOL)isDraft
{
	return NO;
}

//- (NSDate *)creationDate
//{
//	if(!_creationDate)
//		_creationDate = [[NSDateFormatter sharedCoubJSONDateFormatter] dateFromString:_creationDateAsString];
//
//	return _creationDate;
//}

//- (NSDate *)originalCreationDate
//{
//	if(!_originalCreationDate)
//		_originalCreationDate = [[NSDateFormatter sharedCoubJSONDateFormatter] dateFromString:_originalCreationDateAsString];
//
//	return _originalCreationDate;
//}

- (NSURL *)mediumImageURL
{
	NSString *remoteImageFilePath = self.mediumPicture;
	if(remoteImageFilePath)
		return [NSURL URLWithString:[remoteImageFilePath hasPrefix:@"http://"] ? remoteImageFilePath : [[@"http://" stringByAppendingString:kCBServerURL] stringByAppendingPathComponent:remoteImageFilePath]];
	return nil;
}


- (NSURL *)largeImageURL
{
	NSString *remoteImageFilePath = self.largePicture;
	if(remoteImageFilePath)
		return [NSURL URLWithString:[remoteImageFilePath hasPrefix:@"http://"] ? remoteImageFilePath : [[@"http://" stringByAppendingString:kCBServerURL] stringByAppendingPathComponent:remoteImageFilePath]];
	return nil;
}

- (BOOL)isRecoub
{
	return _recouber != nil ? YES : NO;
}

//- (CBCoubStatusFlags)statusFlags
//{
//	CBCoubStatusFlags statusFlags = 0;
//
//	if([_visibility isEqualToString:kCBCoubVisibilityFriends])
//		statusFlags |= CBCoubStatusFriendsOnly;
//	else if([_visibility isEqualToString:kCBCoubVisibilityPrivate])
//		statusFlags |= CBCoubStatusPrivate;
//	else if([_visibility isEqualToString:kCBCoubVisibilityUnlisted])
//		statusFlags |= CBCoubStatusUnlisted;
//	switch(_audioType)
//	{
//		case CBCoubAudioTypeExternal:
//			statusFlags |= CBCoubStatusExternalAudio;
//			break;
//		case CBCoubAudioTypeInternal:
//			statusFlags |= CBCoubStatusHasAudioTrack;
//			break;
//		default:
//			break;
//	}
//
//	return statusFlags;
//}

- (NSURL *)remoteVideoFileURL
{
	NSURL *url = nil;

	NSString *remoteFilePath = self.remoteVideoLocation;
	if([remoteFilePath isKindOfClass:[NSString class]] && remoteFilePath.length > 0)
	{
		url = [NSURL URLWithString:[remoteFilePath hasPrefix:@"http://"] ? remoteFilePath : [[@"http://" stringByAppendingString:kCBServerURL] stringByAppendingPathComponent:remoteFilePath]];
		if(!url)
			[NSException raise:NSInternalInconsistencyException format:@"Could not make a URL from \"%@\"", remoteFilePath];
	}
	return url;
}

- (NSURL *)externalAudioURL
{
	NSURL *url = nil;

	NSString *remoteFilePath = self.remoteAudioLocation;
	if([remoteFilePath isKindOfClass:[NSString class]] && remoteFilePath.length > 0)
	{
		url = [NSURL URLWithString:[remoteFilePath hasPrefix:@"http://"] ? remoteFilePath : [[@"http://" stringByAppendingString:kCBServerURL] stringByAppendingPathComponent:remoteFilePath]];
		if(!url)
			[NSException raise:NSInternalInconsistencyException format:@"Could not make a URL from \"%@\"", remoteFilePath];
	}
	return url;
}

- (NSURL *)localVideoFileURL
{
	if(self.permalink == nil)
		return nil;


	NSString *fileNameExtension = [self.remoteVideoLocation pathExtension] ?: @"mp4";
	NSString *localFileName = [[@"coub " stringByAppendingString:self.permalink] stringByAppendingPathExtension:fileNameExtension];
	NSString *path = [[CBLibrary sharedLibrary].mediaDirectory.path stringByAppendingPathComponent:localFileName];
	return [NSURL fileURLWithPath:path isDirectory:NO];
}

- (NSURL *)localAudioFileURL
{
	if(self.permalink == nil)
		return nil;

	NSString *fileNameExtension = @"m4a";
	NSString *localFileName = [[@"coub " stringByAppendingString:self.permalink] stringByAppendingPathExtension:fileNameExtension];
	return [NSURL fileURLWithPath:[[CBLibrary sharedLibrary].mediaDirectory.path stringByAppendingPathComponent:localFileName] isDirectory:NO];
}

- (NSString *)assetId
{
	return self.permalink;
}

- (BOOL)isAudioAvailable
{
	return (_audioType != CBCoubAudioTypeNone && !_failedDownloadChunks);
}

- (BOOL)isEqualToCoub:(CBCoubNew *)coub
{
	return [coub.permalink isEqualToString:self.permalink];
}

+ (CBCoubNew *)coubWithAttributes:(NSDictionary *)attributes
{
	CBCoubNew *coub = [CBJSONCoubMapper coubFromJSONObject:attributes];

	return coub;
}

//- (NSURL *)coubWebViewURL
//{
//	return [NSURL URLWithString:[NSString stringWithFormat:@"%@/view/%@", kCBServerURL, self.permalink]];
//}

- (NSURL *)remoteAudioChunkWithIdx:(NSInteger)idx
{
	//NSLog(@"remoteAudioChunkWithIdx = %@ ", [NSURL URLWithString:[NSString stringWithFormat:_remoteAudioLocationPattern, idx]]);

    //NOTE: sometimes _remoteAudioLocationPattern
	return [NSURL URLWithString:[NSString stringWithFormat:_remoteAudioLocationPattern, idx]];
}

- (NSURL *)localAudioChunkWithIdx:(NSInteger)idx
{
	//NSLog(@"localAudioChunkWithIdx = %i", idx);

	NSString *fileNameExtension = @"mp3";
	NSString *fileName = [[NSString stringWithFormat:@"coub mp3 chunk %i ", idx] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *localFileName = [[fileName stringByAppendingString:self.permalink] stringByAppendingPathExtension:fileNameExtension];

	return [NSURL fileURLWithPath:[[CBLibrary sharedLibrary].mediaDirectory.path stringByAppendingPathComponent:localFileName] isDirectory:NO];
}

- (BOOL)failedDownloadChunk
{
	return _failedDownloadChunks;
}

- (void)setFailedDownloadChunk:(BOOL)failed
{
	_failedDownloadChunks = failed;
}

@end
