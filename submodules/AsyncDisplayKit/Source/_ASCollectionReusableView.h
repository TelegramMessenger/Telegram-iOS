//
//  _ASCollectionReusableView.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASCellNode, ASCollectionElement;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED // Note: ASDynamicCastStrict is used on instances of this class based on this restriction.
@interface _ASCollectionReusableView : UICollectionReusableView

@property (nullable, nonatomic, readonly) ASCellNode *node;
@property (nullable, nonatomic) ASCollectionElement *element;
@property (nullable, nonatomic) UICollectionViewLayoutAttributes *layoutAttributes;

@end

NS_ASSUME_NONNULL_END

#endif
