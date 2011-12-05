//
//  PSAppStoreHeader.m
//  HockeyDemo
//
//  Created by Peter Steinberger on 09.01.11.
//  Copyright 2011 Peter Steinberger. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "PSAppStoreHeader.h"
#import "UIImage+HockeyAdditions.h"
#import "BWGlobal.h"

#define BW_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]

#define kLightGrayColor BW_RGBCOLOR(200, 202, 204)
#define kDarkGrayColor  BW_RGBCOLOR(140, 141, 142)

#define kImageHeight 57
#define kReflectionHeight 20
#define kImageBorderRadius 10
#define kImageMargin 8
#define kTextRow kImageMargin*2 + kImageHeight

@implementation PSAppStoreHeader

@synthesize headerLabel = headerLabel_;
@synthesize middleHeaderLabel = middleHeaderLabel_;
@synthesize subHeaderLabel;
@synthesize iconImage = iconImage_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject

- (id)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.backgroundColor = kLightGrayColor;
  }
  return self;
}

- (void)dealloc {
  [headerLabel_ release];
  [middleHeaderLabel_ release];
  [subHeaderLabel release];
  [iconImage_ release];
  
  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIView

- (void)drawRect:(CGRect)rect {
  CGRect bounds = self.bounds;
  CGFloat globalWidth = self.frame.size.width;
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  // draw the gradient
  NSArray *colors = [NSArray arrayWithObjects:(id)kDarkGrayColor.CGColor, (id)kLightGrayColor.CGColor, nil];
  CGGradientRef gradient = CGGradientCreateWithColors(CGColorGetColorSpace((CGColorRef)[colors objectAtIndex:0]), (CFArrayRef)colors, (CGFloat[2]){0, 1});
  CGPoint top = CGPointMake(CGRectGetMidX(bounds), bounds.origin.y);
  CGPoint bottom = CGPointMake(CGRectGetMidX(bounds), CGRectGetMaxY(bounds)-kReflectionHeight);
  CGContextDrawLinearGradient(context, gradient, top, bottom, 0);
  CGGradientRelease(gradient);
  
  // draw header name
  UIColor *mainTextColor = BW_RGBCOLOR(0,0,0);
  UIColor *secondaryTextColor = BW_RGBCOLOR(48,48,48);
  UIFont *mainFont = [UIFont boldSystemFontOfSize:20];
  UIFont *secondaryFont = [UIFont boldSystemFontOfSize:12];
  UIFont *smallFont = [UIFont systemFontOfSize:12];
  
  float myColorValues[] = {255, 255, 255, .6};
  CGColorSpaceRef myColorSpace = CGColorSpaceCreateDeviceRGB();
  CGColorRef myColor = CGColorCreate(myColorSpace, myColorValues);
  
  // icon
  [iconImage_ drawAtPoint:CGPointMake(kImageMargin, kImageMargin)];
  [reflectedImage_ drawAtPoint:CGPointMake(kImageMargin, kImageMargin+kImageHeight)];
  
  // shadows are a beast
  NSInteger shadowOffset = 2;
  BW_IF_IOS4_OR_GREATER(if([[UIScreen mainScreen] scale] == 2) shadowOffset = 1;)
  BW_IF_IOS5_OR_GREATER(shadowOffset = 1;) // iOS5 changes this - again!
  
  BW_IF_3_2_OR_GREATER(CGContextSetShadowWithColor(context, CGSizeMake(shadowOffset, shadowOffset), 0, myColor);)
  BW_IF_PRE_3_2(shadowOffset=1;CGContextSetShadowWithColor(context, CGSizeMake(shadowOffset, -shadowOffset), 0, myColor);)
  
  
  [mainTextColor set];
  [headerLabel_ drawInRect:CGRectMake(kTextRow, kImageMargin, globalWidth-kTextRow, 20) withFont:mainFont lineBreakMode:UILineBreakModeTailTruncation];
  
  // middle
  [secondaryTextColor set];
  [middleHeaderLabel_ drawInRect:CGRectMake(kTextRow, kImageMargin + 25, globalWidth-kTextRow, 20) withFont:secondaryFont lineBreakMode:UILineBreakModeTailTruncation];
  CGContextSetShadowWithColor(context, CGSizeZero, 0, nil);
  
  // sub
  [secondaryTextColor set];
  [subHeaderLabel drawAtPoint:CGPointMake(kTextRow, kImageMargin+kImageHeight-12) forWidth:globalWidth-kTextRow withFont:smallFont lineBreakMode:UILineBreakModeTailTruncation];
  
  CGColorRelease(myColor);
  CGColorSpaceRelease(myColorSpace);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Properties

- (void)setHeaderLabel:(NSString *)anHeaderLabel {
  if (headerLabel_ != anHeaderLabel) {
    [headerLabel_ release];
    headerLabel_ = [anHeaderLabel copy];
    [self setNeedsDisplay];
  }
}

- (void)setMiddleHeaderLabel:(NSString *)aMiddleHeaderLabel {
  if (middleHeaderLabel_ != aMiddleHeaderLabel) {
    [middleHeaderLabel_ release];
    middleHeaderLabel_ = [aMiddleHeaderLabel copy];
    [self setNeedsDisplay];
  }
}

- (void)setSubHeaderLabel:(NSString *)aSubHeaderLabel {
  if (subHeaderLabel != aSubHeaderLabel) {
    [subHeaderLabel release];
    subHeaderLabel = [aSubHeaderLabel copy];
    [self setNeedsDisplay];
  }
}

- (void)setIconImage:(UIImage *)anIconImage {
  if (iconImage_ != anIconImage) {
    [iconImage_ release];
    
    // scale, make borders and reflection
    iconImage_ = [anIconImage bw_imageToFitSize:CGSizeMake(kImageHeight, kImageHeight) honorScaleFactor:YES];
    iconImage_ = [[iconImage_ bw_roundedCornerImage:kImageBorderRadius borderSize:0.0] retain];
    
    // create reflected image
    [reflectedImage_ release];
    reflectedImage_ = nil;
    if (anIconImage) {
      reflectedImage_ = [[iconImage_ bw_reflectedImageWithHeight:kReflectionHeight fromAlpha:0.5 toAlpha:0.0] retain];
    }
    [self setNeedsDisplay];
  }
}

@end
