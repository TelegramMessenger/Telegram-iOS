//
//  NSMutableAttributedString+TextKitAdditions.m
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

#import <AsyncDisplayKit/NSMutableAttributedString+TextKitAdditions.h>

@implementation NSMutableAttributedString (TextKitAdditions)

#pragma mark - Convenience Methods

- (void)attributeTextInRange:(NSRange)range withTextKitMinimumLineHeight:(CGFloat)minimumLineHeight
{
  if (range.length) {

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setMinimumLineHeight:minimumLineHeight];
    [self attributeTextInRange:range withTextKitParagraphStyle:style];
  }
}

- (void)attributeTextInRange:(NSRange)range withTextKitMinimumLineHeight:(CGFloat)minimumLineHeight maximumLineHeight:(CGFloat)maximumLineHeight
{
  if (range.length) {

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setMinimumLineHeight:minimumLineHeight];
    [style setMaximumLineHeight:maximumLineHeight];
    [self attributeTextInRange:range withTextKitParagraphStyle:style];
  }
}

- (void)attributeTextInRange:(NSRange)range withTextKitLineHeight:(CGFloat)lineHeight
{
  [self attributeTextInRange:range withTextKitMinimumLineHeight:lineHeight maximumLineHeight:lineHeight];
}

- (void)attributeTextInRange:(NSRange)range withTextKitParagraphStyle:(NSParagraphStyle *)paragraphStyle
{
  if (range.length) {
    [self addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
  }
}

@end
