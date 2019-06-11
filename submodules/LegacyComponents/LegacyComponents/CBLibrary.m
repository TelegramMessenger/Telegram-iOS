//
//  CBLibrary.m
//  Coub
//
//  Created by Konstantin Anoshkin on 26.06.12.
//  Copyright 2012 Coub. All rights reserved.
//

#define CBLIBRARY_IMPLEMENTATION_FILE

#import "CBLibrary.h"
#import <sys/xattr.h>


#if TARGET_IPHONE_SIMULATOR
NSString *CBTemporaryDirectory (void)
{
    return [NSHomeDirectory() stringByAppendingPathComponent: @"tmp"];
}
#endif


NSString *CBDocumentsDirectory (void)
{
    static NSString *sPath = nil;
    if (!sPath)
        sPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] copy];
    return sPath;
}


NSString *CBCachesDirectory (void)
{
    static NSString *sPath = nil;
    if (!sPath) {
        sPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] copy];
        if (![[NSFileManager defaultManager] fileExistsAtPath: sPath])
            [[NSFileManager defaultManager] createDirectoryAtPath: sPath withIntermediateDirectories: YES attributes: nil error: NULL];
    }
    return sPath;
}


NSString *CBMediaDirectory (void)
{
    static NSString *sPath = nil;
    if (!sPath) {
        sPath = [[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent: @"Media"] copy];
    }
    return sPath;
}

NSString *const kCBLibraryDatabaseFileNameExtension = @"sqlite";
NSString *const kCBLibraryCurrentUserID = @"currentUserID";


@implementation CBLibrary
{
@private
	NSURL *_mediaDirectory;
	NSMutableDictionary *_cachedMediaFiles;
}


+ (CBLibrary *)sharedLibrary
{
	static id sSharedInstance = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^
	{
		sSharedInstance = [[self alloc] init];
	});
	return sSharedInstance;
}


- (id)init
{
	self = [super init];

	if(self)
	{
		_cachedMediaFiles = [NSMutableDictionary new];
	}

	return self;
}

#pragma mark - Paths & URLs

- (void)setMediaDirectory:(NSURL *)mediaDirectory
{
    if (_mediaDirectory && ![mediaDirectory.absoluteString isEqualToString:_mediaDirectory.absoluteString]) {
        [self cleanUpMediaCache];
    }
    
    if (mediaDirectory && ![mediaDirectory.absoluteString isEqualToString:_mediaDirectory.absoluteString]) {
        _mediaDirectory = mediaDirectory;
        [self createMediaDirectory];
    } else {
        _mediaDirectory = mediaDirectory;
    }
}

- (NSURL *)mediaDirectory
{
    if(!_mediaDirectory) {
		_mediaDirectory = [NSURL fileURLWithPath:CBMediaDirectory() isDirectory:YES];
        [self createMediaDirectory];
    }
	return _mediaDirectory;
}

- (void)createMediaDirectory
{
	NSError *error = nil;
	NSString *mediaDirectoryPath = [[self mediaDirectory] path];
	if(![[NSFileManager defaultManager] fileExistsAtPath:mediaDirectoryPath])
	{
		if(![[NSFileManager defaultManager] createDirectoryAtPath:mediaDirectoryPath withIntermediateDirectories:YES attributes:nil error:&error])
		{
			NSLog(@"*** Could not recreate Media directory, %@", error);
			return;
		}

		if(&NSURLIsExcludedFromBackupKey)
		{
			if(![[self mediaDirectory] setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error])
				NSLog(@"*** Failed to set NSURLIsExcludedFromBackupKey for %@, %@", [self mediaDirectory], error);
		}else
		{
			// Set the Do Not Backup extended attribute, http://developer.apple.com/library/ios/#qa/qa1719/_index.html


			u_int8_t attrValue = 1;
			if(setxattr([mediaDirectoryPath fileSystemRepresentation], "com.apple.MobileBackup", &attrValue, sizeof(attrValue), 0, 0))
			{
				//KAObjectLogError(@"setxattr(%@) failed: %s (%d)", mediaDirectoryPath, strerror(errno), errno);
			}
		}
	}



}

- (void)markCoubAsset:(id<CBCoubAsset>)coub asDownloaded:(BOOL)downloaded
{
	if(downloaded)
	{
		if([self isCoubDownloadedByPermalink:coub.assetId])
			return;

		NSError *error = nil;
		NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:[coub.localVideoFileURL path] error:&error];
		if(attrs)
		{
            _cachedMediaFiles[coub.assetId] = [NSMutableDictionary dictionaryWithDictionary:@{@"coub" : coub, @"downloadedChunks": @0}];
		}else
		{
			//KAObjectLogError(@"Can't get attributes at %@: %@", coub.localVideoFileURL, error);
		}
	}else
	{
		[_cachedMediaFiles removeObjectForKey:coub.assetId];
	}
}

- (BOOL)isCoubDownloadedByPermalink:(NSString *)permalink
{
	return _cachedMediaFiles[permalink] != nil;
}

- (void)markCoubChunk:(id<CBCoubAsset>)coub idx:(NSInteger)idx asDownloaded:(BOOL)downloaded
{
	//NSLog(@"markCoubChunk %i", idx);

	NSMutableDictionary *mediaFile = _cachedMediaFiles[coub.assetId];

	if(mediaFile)
    {
        NSInteger downloadedChunks = ((NSNumber *)mediaFile[@"downloadedChunks"]).integerValue;
        NSInteger normalIdx = 1<<idx;

        if(downloaded)
            downloadedChunks |= normalIdx;
        else
            downloadedChunks &= normalIdx;
        
        mediaFile[@"downloadedChunks"] = [NSNumber numberWithInteger:downloadedChunks];
    }
		
}

- (BOOL)isCoubChunkDownloadedByPermalink:(NSString *)permalink idx:(NSInteger)idx
{
	NSMutableDictionary *mediaFile = _cachedMediaFiles[permalink];

	if(mediaFile == nil)
		return NO;

    idx = 1<<idx;
  
    NSInteger downloadedChunks = ((NSNumber *)mediaFile[@"downloadedChunks"]).integerValue;
    
	BOOL downloaded = (downloadedChunks & idx) == idx;
	return downloaded;
}

- (void)cleanUpMediaCache
{
	NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = self.mediaDirectory.path;
	NSError *error = nil;
	
    for(NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error])
	{
		BOOL (^isMedia)(void) = ^BOOL(void){
			BOOL isMp3 = [file rangeOfString:@"mp3"].length != 0;
			BOOL isMp4 = [file rangeOfString:@"mp4"].length != 0;

			return isMp3 || isMp4;
		};

		if(!isMedia()) continue;



		BOOL success = [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directory, file] error:&error];
		if(!success || error) {}
	}

	[_cachedMediaFiles removeAllObjects];
}

@end
