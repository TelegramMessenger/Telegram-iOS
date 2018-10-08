//
//  ASCollectionLayoutContext+Private.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionLayoutContext.h>

@class ASCollectionLayoutCache;
@protocol ASCollectionLayoutDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionLayoutContext (Private)

@property (nonatomic, readonly) Class<ASCollectionLayoutDelegate> layoutDelegateClass;
@property (nonatomic, weak, readonly) ASCollectionLayoutCache *layoutCache;

- (instancetype)initWithViewportSize:(CGSize)viewportSize
                initialContentOffset:(CGPoint)initialContentOffset
                scrollableDirections:(ASScrollDirection)scrollableDirections
                            elements:(ASElementMap *)elements
                 layoutDelegateClass:(Class<ASCollectionLayoutDelegate>)layoutDelegateClass
                         layoutCache:(ASCollectionLayoutCache *)layoutCache
                      additionalInfo:(nullable id)additionalInfo;

@end

NS_ASSUME_NONNULL_END

#endif
