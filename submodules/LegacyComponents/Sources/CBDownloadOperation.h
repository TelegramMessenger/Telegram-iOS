//
//  CBDownloadOperation.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 19/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol CBCoubAsset;
@protocol CBDownloadOperationDelegate;

@protocol CBDownloadOperation<NSObject>

@required
- (void)setTag:(NSInteger)tag;
- (NSInteger)tag;

- (void)setCoub:(id<CBCoubAsset>)coub;
- (id<CBCoubAsset>)coub;

- (void)setQueuePriority:(NSOperationQueuePriority)queuePriority;
- (NSOperationQueuePriority)queuePriority;

//- (void)setDelegate:(id<CBDownloadOperationDelegate>)delegate;

- (void)setClientSuccess:(void (^)(id<CBCoubAsset> operation, NSInteger tag))success;
- (void)setClientFailure:(void (^)(id<CBCoubAsset> operation, NSInteger tag, NSError *error))failure;

- (void)setCompletionBlock:(void (^)(id<CBCoubAsset> operation, NSError *error))completion;

- (void)start;
- (void)cancel;

- (instancetype)clone;

@end
