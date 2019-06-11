//
//  UICollectionViewLayout+ASConvenience.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UICollectionViewLayout.h>

@protocol ASCollectionViewLayoutInspecting;

NS_ASSUME_NONNULL_BEGIN

@interface UICollectionViewLayout (ASLayoutInspectorProviding)

/**
 * You can override this method on your @c UICollectionViewLayout subclass to
 * return a layout inspector tailored to your layout.
 *
 * It's fine to return @c self. You must not return @c nil.
 */
- (id<ASCollectionViewLayoutInspecting>)asdk_layoutInspector;

@end

NS_ASSUME_NONNULL_END
