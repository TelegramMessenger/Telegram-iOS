//
// Created by Tikhonenko Pavel on 04/04/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBCoubPlayerContance.h"

@protocol CBCoubAsset<NSObject>

@property(nonatomic, readonly) NSString *assetId; //permalink
@property(nonatomic, readonly) NSURL *localVideoFileURL;
@property(nonatomic, readonly) CBCoubAudioType audioType;
@property(nonatomic, readonly) NSURL *externalAudioURL; //may be nil
@property(nonatomic, readonly) NSURL *largeImageURL;

- (BOOL)failedDownloadChunk;

- (NSURL *)remoteVideoFileURL;

- (NSURL *)localAudioChunkWithIdx:(NSInteger)idx;
- (NSURL *)remoteAudioChunkWithIdx:(NSInteger)idx;


@end