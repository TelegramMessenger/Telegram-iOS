//
//  ASCollectionViewLayoutController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASAbstractLayoutController.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionView;

AS_SUBCLASSING_RESTRICTED
@interface ASCollectionViewLayoutController : ASAbstractLayoutController

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView;

@end

NS_ASSUME_NONNULL_END

#endif
