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

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_UPDATES

#import "BITAppStoreHeader.h"
#import "BITHockeyHelper.h"
#import "HockeySDKPrivate.h"

#define kDarkGrayColor  BIT_RGBCOLOR(186, 186, 186)
#define kWhiteBackgroundColorDefault  BIT_RGBCOLOR(245, 245, 245)
#define kWhiteBackgroundColorOS7  BIT_RGBCOLOR(255, 255, 255)
#define kImageHeight 72
#define kImageBorderRadiusiOS7 16.5
#define kImageLeftMargin 14
#define kImageTopMargin 12
#define kTextRow kImageTopMargin*2 + kImageHeight

@interface BITAppStoreHeader ()

@property (nonatomic, strong) UILabel *headerLabelView;
@property (nonatomic, strong) UILabel *middleLabelView;

@end

@implementation BITAppStoreHeader


#pragma mark - NSObject

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.backgroundColor = kWhiteBackgroundColorDefault;
  }
  return self;
}


#pragma mark - UIView

- (void)drawRect:(CGRect)rect {
  CGRect bounds = self.bounds;

  // draw the line
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGContextSetLineWidth(ctx, 1.0);
  CGContextSetStrokeColorWithColor(ctx, kDarkGrayColor.CGColor);
  CGContextMoveToPoint(ctx, 0, CGRectGetMaxY(bounds));
  CGContextAddLineToPoint( ctx, CGRectGetMaxX(bounds), CGRectGetMaxY(bounds));
  CGContextStrokePath(ctx);
  
  // icon
  [self.iconImage drawAtPoint:CGPointMake(kImageLeftMargin, kImageTopMargin)];
  
  [super drawRect:rect];
}


- (void)layoutSubviews {
  self.backgroundColor = kWhiteBackgroundColorOS7;

  [super layoutSubviews];
  
  CGFloat globalWidth = self.frame.size.width;
  
  // draw header name
  UIColor *mainTextColor = BIT_RGBCOLOR(61, 61, 61);
  UIColor *secondaryTextColor = BIT_RGBCOLOR(100, 100, 100);
  UIFont *mainFont = [UIFont boldSystemFontOfSize:15];
  UIFont *secondaryFont = [UIFont systemFontOfSize:10];
  
  if (!self.headerLabelView) self.headerLabelView = [[UILabel alloc] init];
  [self.headerLabelView setFont:mainFont];
  [self.headerLabelView setFrame:CGRectMake(kTextRow, kImageTopMargin, globalWidth-kTextRow, 20)];
  [self.headerLabelView setTextColor:mainTextColor];
  [self.headerLabelView setBackgroundColor:[UIColor clearColor]];
  [self.headerLabelView setText:self.headerText];
  [self addSubview:self.headerLabelView];
  
  // middle
  if (!self.middleLabelView) self.middleLabelView = [[UILabel alloc] init];
  [self.middleLabelView setFont:secondaryFont];
  [self.middleLabelView setFrame:CGRectMake(kTextRow, kImageTopMargin + 17, globalWidth-kTextRow, 20)];
  [self.middleLabelView setTextColor:secondaryTextColor];
  [self.middleLabelView setBackgroundColor:[UIColor clearColor]];
  [self.middleLabelView setText:self.subHeaderText];
  [self addSubview:self.middleLabelView];
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
    _iconImage = bit_roundedCornerImage(_iconImage, kImageBorderRadiusiOS7, 0.0);
    
    [self setNeedsDisplay];
  }
}

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
