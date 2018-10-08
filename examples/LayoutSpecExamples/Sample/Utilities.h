//
//  Utilities.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIColor (Additions)
+ (UIColor *)darkBlueColor;
+ (UIColor *)lightBlueColor;
@end

@interface UIImage (Additions)
- (UIImage *)makeCircularImageWithSize:(CGSize)size withBorderWidth:(CGFloat)width;
+ (UIImage *)imageWithSize:(CGSize)size fillColor:(UIColor *)fillColor shapeBlock:(UIBezierPath *(^)(void))shapeBlock;
@end

@interface NSAttributedString (Additions)
+ (NSAttributedString *)attributedStringWithString:(NSString *)string fontSize:(CGFloat)size color:(UIColor *)color;
@end
