//
// Created by Tikhonenko Pavel on 23/05/2014.
// Copyright (c) 2014 Coub. All rights reserved.
//

#import "CBGenericDownloadOperation.h"

@interface CBChunkDownloadOperation : CBGenericDownloadOperation

@property (nonatomic, assign) NSInteger chunkIdx;

@property(nonatomic, copy) void (^chunkDownloadedBlock)(id<CBCoubAsset>, NSInteger tag, NSInteger chunkIdx);

@end