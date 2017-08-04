//
//  NSArray+Diffing.h
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

@interface NSArray (Diffing)

/**
 * @abstract Compares two arrays, providing the insertion and deletion indexes needed to transform into the target array.
 * @discussion This compares the equality of each object with `isEqual:`.
 * This diffing algorithm uses a bottom-up memoized longest common subsequence solution to identify differences.
 * It runs in O(mn) complexity.
 */
- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions;

/**
 * @abstract Compares two arrays, providing the insertion and deletion indexes needed to transform into the target array.
 * @discussion The `compareBlock` is used to identify the equality of the objects within the arrays.
 * This diffing algorithm uses a bottom-up memoized longest common subsequence solution to identify differences.
 * It runs in O(mn) complexity.
 */
- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions compareBlock:(BOOL (^)(id lhs, id rhs))comparison;

@end
