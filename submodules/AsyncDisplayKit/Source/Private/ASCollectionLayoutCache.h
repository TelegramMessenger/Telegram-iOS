//
//  ASCollectionLayoutCache.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionLayoutContext, ASCollectionLayoutState;

/// A thread-safe cache for ASCollectionLayoutContext-ASCollectionLayoutState pairs
AS_SUBCLASSING_RESTRICTED
@interface ASCollectionLayoutCache : NSObject

- (nullable ASCollectionLayoutState *)layoutForContext:(ASCollectionLayoutContext *)context;

- (void)setLayout:(ASCollectionLayoutState *)layout forContext:(ASCollectionLayoutContext *)context;

- (void)removeLayoutForContext:(ASCollectionLayoutContext *)context;

- (void)removeAllLayouts;

@end

NS_ASSUME_NONNULL_END

#endif
