//
//  UICollectionViewLayout+ASConvenience.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
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
