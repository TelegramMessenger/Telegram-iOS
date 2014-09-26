/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011-2012 Peter Steinberger.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


#import "BITAppStoreHeader.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"


#define kLightGrayColor BIT_RGBCOLOR(235, 235, 235)
#define kDarkGrayColor  BIT_RGBCOLOR(186, 186, 186)
#define kWhiteBackgroundColorDefault  BIT_RGBCOLOR(245, 245, 245)
#define kWhiteBackgroundColorOS7  BIT_RGBCOLOR(255, 255, 255)
#define kImageHeight 72
#define kImageBorderRadius 12
#define kImageBorderRadiusiOS7 16.5
#define kImageLeftMargin 14
#define kImageTopMargin 12
#define kTextRow kImageTopMargin*2 + kImageHeight

@implementation BITAppStoreHeader {
  UILabel *_headerLabelView;
  UILabel *_middleLabelView;
}


#pragma mark - NSObject

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.backgroundColor = kWhiteBackgroundColorDefault;
    self.style = BITAppStoreHeaderStyleDefault;
  }
  return self;
}


#pragma mark - UIView

- (void)drawRect:(CGRect)rect {
  CGRect bounds = self.bounds;
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  if (self.style == BITAppStoreHeaderStyleDefault) {
    // draw the gradient
    NSArray *colors = [NSArray arrayWithObjects:(id)kDarkGrayColor.CGColor, (id)kLightGrayColor.CGColor, nil];
    CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace((__bridge CGColorRef)[colors objectAtIndex:0]), (__bridge CFArrayRef)colors, (CGFloat[2]){0, 1});
    CGPoint top = CGPointMake(CGRectGetMidX(bounds), bounds.size.height - 3);
    CGPoint bottom = CGPointMake(CGRectGetMidX(bounds), CGRectGetMaxY(bounds));
    CGContextDrawLinearGradient(context, gradient, top, bottom, 0);
    CGGradientRelease(gradient);
  } else {
    // draw the line
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(ctx, 1.0);
    CGContextSetStrokeColorWithColor(ctx, kDarkGrayColor.CGColor);
    CGContextMoveToPoint(ctx, 0, CGRectGetMaxY(bounds));
    CGContextAddLineToPoint( ctx, CGRectGetMaxX(bounds), CGRectGetMaxY(bounds));
    CGContextStrokePath(ctx);
  }
  
  // icon
  [_iconImage drawAtPoint:CGPointMake(kImageLeftMargin, kImageTopMargin)];
  
  [super drawRect:rect];
}


- (void)layoutSubviews {
  if (self.style == BITAppStoreHeaderStyleOS7)
    self.backgroundColor = kWhiteBackgroundColorOS7;

  [super layoutSubviews];
  
  CGFloat globalWidth = self.frame.size.width;
  
  // draw header name
  UIColor *mainTextColor = BIT_RGBCOLOR(61, 61, 61);
  UIColor *secondaryTextColor = BIT_RGBCOLOR(100, 100, 100);
  UIFont *mainFont = [UIFont boldSystemFontOfSize:15];
  UIFont *secondaryFont = [UIFont systemFontOfSize:10];
  
  if (!_headerLabelView) _headerLabelView = [[UILabel alloc] init];
  [_headerLabelView setFont:mainFont];
  [_headerLabelView setFrame:CGRectMake(kTextRow, kImageTopMargin, globalWidth-kTextRow, 20)];
  [_headerLabelView setTextColor:mainTextColor];
  [_headerLabelView setBackgroundColor:[UIColor clearColor]];
  [_headerLabelView setText:_headerText];
  [self addSubview:_headerLabelView];
  
  // middle
  if (!_middleLabelView) _middleLabelView = [[UILabel alloc] init];
  [_middleLabelView setFont:secondaryFont];
  [_middleLabelView setFrame:CGRectMake(kTextRow, kImageTopMargin + 17, globalWidth-kTextRow, 20)];
  [_middleLabelView setTextColor:secondaryTextColor];
  [_middleLabelView setBackgroundColor:[UIColor clearColor]];
  [_middleLabelView setText:_subHeaderText];
  [self addSubview:_middleLabelView];
}


#pragma mark - Properties

- (void)setHeaderText:(NSString *)anHeaderText {
  if (_headerText != anHeaderText) {
    _headerText = [anHeaderText copy];
    [self setNeedsDisplay];
  }
}

- (void)setSubHeaderText:(NSString *)aSubHeaderText {
  if (_subHeaderText != aSubHeaderText) {
    _subHeaderText = [aSubHeaderText copy];
    [self setNeedsDisplay];
  }
}

- (void)setIconImage:(UIImage *)anIconImage {
  if (_iconImage != anIconImage) {
    
    // scale, make borders and reflection
    _iconImage = bit_imageToFitSize(anIconImage, CGSizeMake(kImageHeight, kImageHeight), YES);
    CGFloat radius = kImageBorderRadius;
    if (self.style == BITAppStoreHeaderStyleOS7)
      radius = kImageBorderRadiusiOS7;
    _iconImage = bit_roundedCornerImage(_iconImage, radius, 0.0);
    
    [self setNeedsDisplay];
  }
}

@end
