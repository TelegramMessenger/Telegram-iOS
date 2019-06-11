//
//  ASCollectionViewFlowLayoutInspector.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASCollectionViewLayoutInspector.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionView;
@class UICollectionViewFlowLayout;

/**
 * A layout inspector implementation specific for the sizing behavior of UICollectionViewFlowLayouts
 */
AS_SUBCLASSING_RESTRICTED
@interface ASCollectionViewFlowLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

@property (nonatomic, weak, readonly) UICollectionViewFlowLayout *layout;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFlowLayout:(UICollectionViewFlowLayout *)flowLayout NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END

#endif
