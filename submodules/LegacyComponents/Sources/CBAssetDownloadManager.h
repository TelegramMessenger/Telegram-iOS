//
// Created by Tikhonenko Pavel on 23/05/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBCoubAsset.h"

@protocol CBDownloadOperationDelegate;

typedef NS_ENUM(NSInteger, CBDownloadProcessType)
{
	CBDownloadProcessTypeCoub,
	CBDownloadProcessTypeChunks,
};

@interface CBAssetDownloadManager : NSObject

- (void)downloadCoubWithoutChunks:(id<CBCoubAsset>)coub
                              tag:(NSInteger)tag
                     withDelegate:(id<CBDownloadOperationDelegate>)delegate
                   downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;

- (void)downloadCoub:(id<CBCoubAsset>)coub
                 tag:(NSInteger)tag
        withDelegate:(id<CBDownloadOperationDelegate>)delegate
          withChunks:(BOOL)withChunks
      downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;

#pragma mark -
#pragma mark Downloading video and first chunk

//- (void)downloadCoub:(id<CBCoubAsset>)coub
//				 tag:(NSInteger)tag
//	    withDelegate:(id<CBDownloadOperationDelegate>)delegate
//	  downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;

- (void)downloadNextCoub:(id<CBCoubAsset>)coub
				 tag:(NSInteger)tag
	  downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;

- (void)cancelDownloadingForCoub:(id<CBCoubAsset>)coub;

#pragma mark -
#pragma mark Downloading remaining chunks

- (void)downloadChunkWithCoub:(id<CBCoubAsset>)coub
						  tag:(NSInteger)tag
					 chunkIdx:(NSInteger)chunkIdx
			   downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success
			  downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;

- (void)downloadNextChunkWithCoub:(id<CBCoubAsset>)coub
				   downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success
				  downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;
//- (void)downloadRemainingChunksWithCoub:(id<CBCoubAsset>)coub
//									tag:(NSInteger)tag
//						 downloadChunkSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSInteger chunkIdx))chunkDownloaded
//						 downloadSucces:(void (^)(id<CBCoubAsset> coub, NSInteger tag))success
//						downloadFailure:(void (^)(id<CBCoubAsset> coub, NSInteger tag, NSError *error))failure;

- (void)stopAllDownloads;

+ (instancetype)sharedManager;

@end