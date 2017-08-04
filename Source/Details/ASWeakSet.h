//
//  ASWeakSet.h
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

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A class similar to NSSet that stores objects weakly.
 * Note that this class uses NSPointerFunctionsObjectPointerPersonality –
 * that is, it uses shifted pointer for hashing, and identity comparison for equality.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASWeakSet<__covariant ObjectType> : NSObject<NSFastEnumeration>

/// Returns YES if the receiver is empty, NO otherwise.
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

/// Returns YES if `object` is in the receiver, NO otherwise.
- (BOOL)containsObject:(ObjectType)object AS_WARN_UNUSED_RESULT;

/// Insets `object` into the set.
- (void)addObject:(ObjectType)object;

/// Removes object from the set.
- (void)removeObject:(ObjectType)object;

/// Removes all objects from the set.
- (void)removeAllObjects;

/// Returns a standard *retained* NSArray of all objects.  Not free to generate, but useful for iterating over contents.
- (NSArray<ObjectType> *)allObjects AS_WARN_UNUSED_RESULT;

/**
 * How many objects are contained in this set.
 
 * NOTE: This computed property is O(N). Consider using the `empty` property.
 */
@property (nonatomic, readonly) NSUInteger count;

@end

NS_ASSUME_NONNULL_END
