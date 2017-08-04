//
//  AsyncDisplayKit+IGListKitMethods.h
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

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_IG_LIST_KIT

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * If you are using AsyncDisplayKit with IGListKit, you should use
 * these methods to provide implementations for methods like
 * -cellForItemAtIndex: that don't apply when used with AsyncDisplayKit.
 *
 * Your section controllers should also conform to @c ASSectionController and your
 * supplementary view sources should conform to @c ASSupplementaryNodeSource.
 */

AS_SUBCLASSING_RESTRICTED
@interface ASIGListSectionControllerMethods : NSObject

/**
 * Call this for your section controller's @c cellForItemAtIndex: method.
 */
+ (__kindof UICollectionViewCell *)cellForItemAtIndex:(NSInteger)index sectionController:(IGListSectionController *)sectionController;

/**
 * Call this for your section controller's @c sizeForItemAtIndex: method.
 */
+ (CGSize)sizeForItemAtIndex:(NSInteger)index;

@end

AS_SUBCLASSING_RESTRICTED
@interface ASIGListSupplementaryViewSourceMethods : NSObject

/**
 * Call this for your supplementary source's @c viewForSupplementaryElementOfKind:atIndex: method.
 */
+ (__kindof UICollectionReusableView *)viewForSupplementaryElementOfKind:(NSString *)elementKind
                                                                 atIndex:(NSInteger)index
                                                       sectionController:(IGListSectionController *)sectionController;

/**
 * Call this for your supplementary source's @c sizeForSupplementaryViewOfKind:atIndex: method.
 */
+ (CGSize)sizeForSupplementaryViewOfKind:(NSString *)elementKind atIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END

#endif
