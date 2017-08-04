//
//  CoreGraphics+ASConvenience.h
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

#import <CoreGraphics/CoreGraphics.h>
#import <tgmath.h>

#import <AsyncDisplayKit/ASBaseDefines.h>


#ifndef CGFLOAT_EPSILON
  #if CGFLOAT_IS_DOUBLE
    #define CGFLOAT_EPSILON DBL_EPSILON
  #else
    #define CGFLOAT_EPSILON FLT_EPSILON
  #endif
#endif

NS_ASSUME_NONNULL_BEGIN

ASDISPLAYNODE_EXTERN_C_BEGIN

ASDISPLAYNODE_INLINE CGFloat ASCGFloatFromString(NSString *string)
{
#if CGFLOAT_IS_DOUBLE
  return string.doubleValue;
#else
  return string.floatValue;
#endif
}

ASDISPLAYNODE_INLINE CGFloat ASCGFloatFromNumber(NSNumber *number)
{
#if CGFLOAT_IS_DOUBLE
  return number.doubleValue;
#else
  return number.floatValue;
#endif
}

ASDISPLAYNODE_INLINE BOOL CGSizeEqualToSizeWithIn(CGSize size1, CGSize size2, CGFloat delta)
{
  return fabs(size1.width - size2.width) < delta && fabs(size1.height - size2.height) < delta;
};

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END
