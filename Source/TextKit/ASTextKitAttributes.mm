//
//  ASTextKitAttributes.mm
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

#import <AsyncDisplayKit/ASTextKitAttributes.h>

#import <AsyncDisplayKit/ASHashing.h>

NSString *const ASTextKitTruncationAttributeName = @"ck_truncation";
NSString *const ASTextKitEntityAttributeName = @"ck_entity";

size_t ASTextKitAttributes::hash() const
{
#pragma clang diagnostic push
#pragma clang diagnostic warning "-Wpadded"
  struct {
    NSUInteger attrStringHash;
    NSUInteger truncationStringHash;
    NSUInteger avoidTrunactionSetHash;
    NSLineBreakMode lineBreakMode;
    NSUInteger maximumNumberOfLines;
    NSUInteger exclusionPathsHash;
    CGSize shadowOffset;
    NSUInteger shadowColorHash;
    CGFloat shadowOpacity;
    CGFloat shadowRadius;
#pragma clang diagnostic pop
  } data = {
    [attributedString hash],
    [truncationAttributedString hash],
    [avoidTailTruncationSet hash],
    lineBreakMode,
    maximumNumberOfLines,
    [exclusionPaths hash],
    shadowOffset,
    [shadowColor hash],
    shadowOpacity,
    shadowRadius,
  };
  return ASHashBytes(&data, sizeof(data));
}
