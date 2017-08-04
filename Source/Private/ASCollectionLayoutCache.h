//
//  ASCollectionLayoutCache.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
