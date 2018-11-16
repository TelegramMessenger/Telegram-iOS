//
//  NSMutableAttributedString+TextKitAdditions.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
