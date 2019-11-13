//
//  ASTextKitAttributes.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTextKitAttributes.h>

#if AS_ENABLE_TEXTNODE

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

#endif
