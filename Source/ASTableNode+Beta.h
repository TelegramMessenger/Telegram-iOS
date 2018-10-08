//
//  ASTableNode+Beta.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTableNode.h>

@protocol ASBatchFetchingDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface ASTableNode (Beta)

@property (nonatomic, weak) id<ASBatchFetchingDelegate> batchFetchingDelegate;

@end

NS_ASSUME_NONNULL_END
