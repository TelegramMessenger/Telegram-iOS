//
//  ItemStyles.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ItemStyles.h"

const CGFloat kTitleFontSize = 20.0;
const CGFloat kInfoFontSize = 14.0;

UIColor *kTitleColor;
UIColor *kInfoColor;
UIColor *kFinalPriceColor;
UIFont *kTitleFont;
UIFont *kInfoFont;

@implementation ItemStyles

+ (void)initialize {
  if (self == [ItemStyles class]) {
    kTitleColor = [UIColor darkGrayColor];
    kInfoColor = [UIColor grayColor];
    kFinalPriceColor = [UIColor greenColor];
    kTitleFont = [UIFont boldSystemFontOfSize:kTitleFontSize];
    kInfoFont = [UIFont systemFontOfSize:kInfoFontSize];
  }
}

+ (NSDictionary *)titleStyle {
  // Title Label
  return @{ NSFontAttributeName:kTitleFont,
            NSForegroundColorAttributeName:kTitleColor };
}

+ (NSDictionary *)subtitleStyle {
  // First Subtitle
  return @{ NSFontAttributeName:kInfoFont,
            NSForegroundColorAttributeName:kInfoColor };
}

+ (NSDictionary *)distanceStyle {
  // Distance Label
  return @{ NSFontAttributeName:kInfoFont,
            NSForegroundColorAttributeName:kInfoColor};
}

+ (NSDictionary *)secondInfoStyle {
  // Second Subtitle
  return @{ NSFontAttributeName:kInfoFont,
            NSForegroundColorAttributeName:kInfoColor};
}

+ (NSDictionary *)originalPriceStyle {
  // Original price
  return @{ NSFontAttributeName:kInfoFont,
            NSForegroundColorAttributeName:kInfoColor,
            NSStrikethroughStyleAttributeName:@(NSUnderlineStyleSingle)};
}

+ (NSDictionary *)finalPriceStyle {
  //     Discounted / Claimable price label
  return @{ NSFontAttributeName:kTitleFont,
            NSForegroundColorAttributeName:kFinalPriceColor};
}

+ (NSDictionary *)soldOutStyle {
  // Setup Sold Out Label
  return @{ NSFontAttributeName:kTitleFont,
            NSForegroundColorAttributeName:kTitleColor};
}

+ (NSDictionary *)badgeStyle {
  // Setup Sold Out Label
  return @{ NSFontAttributeName:kTitleFont,
            NSForegroundColorAttributeName:[UIColor whiteColor]};
}

+ (UIColor *)badgeColor {
  return [[UIColor purpleColor] colorWithAlphaComponent:0.4];
}

+ (UIImage *)placeholderImage {
  static UIImage *__catFace = nil;
  static dispatch_once_t onceToken;
  dispatch_once (&onceToken, ^{
    __catFace = [UIImage imageNamed:@"cat_face"];
  });
  return __catFace;
}

@end
