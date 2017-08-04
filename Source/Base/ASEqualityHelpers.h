//
//  ASEqualityHelpers.h
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

#import <AsyncDisplayKit/ASBaseDefines.h>

/**
 @abstract Correctly equates two objects, including cases where both objects are nil. The latter is a case where `isEqual:` fails.
 @param obj The first object in the comparison. Can be nil.
 @param otherObj The second object in the comparison. Can be nil.
 @result YES if the objects are equal, including cases where both object are nil.
 */
ASDISPLAYNODE_INLINE BOOL ASObjectIsEqual(id<NSObject> obj, id<NSObject> otherObj)
{
  return obj == otherObj || [obj isEqual:otherObj];
}
