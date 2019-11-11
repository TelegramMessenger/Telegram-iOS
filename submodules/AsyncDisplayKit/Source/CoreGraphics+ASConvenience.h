//
//  CoreGraphics+ASConvenience.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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

NS_ASSUME_NONNULL_END
