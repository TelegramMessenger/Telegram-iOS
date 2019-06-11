//
//  CBLibrary.h
//  Coub
//
//  Created by Konstantin Anoshkin on 26.06.12.
//  Copyright 2012 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBCoubAsset.h"

#if TARGET_IPHONE_SIMULATOR
// On iPhone Simulator NSTemporaryDirectory() returns a Mac OS X temporary directory which is outside our application sandbox.
// For consistency's sake we want to make it behave as on an honest-to-goodness iPhone device.
NSString *CBTemporaryDirectory (void);
#define NSTemporaryDirectory() CBTemporaryDirectory()
#endif

NSString *CBDocumentsDirectory (void);
NSString *CBCachesDirectory (void);

@interface CBLibrary : NSObject

+ (CBLibrary *)sharedLibrary;

- (void)markCoubAsset:(id<CBCoubAsset>)coub asDownloaded:(BOOL)downloaded;
- (BOOL)isCoubDownloadedByPermalink:(NSString *)permalink;

- (void)markCoubChunk:(id<CBCoubAsset>)coub idx:(NSInteger)idx asDownloaded:(BOOL)downloaded;
- (BOOL)isCoubChunkDownloadedByPermalink:(NSString *)permalink idx:(NSInteger)idx;

- (void)cleanUpMediaCache;

@property (strong, nonatomic) NSURL *mediaDirectory;

@end
