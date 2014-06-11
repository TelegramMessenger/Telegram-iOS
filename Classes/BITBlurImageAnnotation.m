/*
 * Author: Moritz Haarmann <post@moritzhaarmann.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

#import "BITBlurImageAnnotation.h"

@interface BITBlurImageAnnotation()

@property (nonatomic, strong) CALayer* imageLayer;
@property (nonatomic, strong) UIImage* scaledImage;
@property (nonatomic, strong) CALayer* selectedLayer;


@end

@implementation BITBlurImageAnnotation

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
      self.clipsToBounds = YES;
      self.imageLayer = [CALayer layer];
      [self.layer addSublayer:self.imageLayer];
      
      self.selectedLayer = [CALayer layer];
      [self.layer insertSublayer:self.selectedLayer above:self.imageLayer];
      
      self.selectedLayer.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5f].CGColor;
      self.selectedLayer.opacity = 0.6f;
      self.clipsToBounds = YES;
    }
    return self;
}

- (void)setSourceImage:(UIImage *)sourceImage {
  CGSize size = CGSizeMake(sourceImage.size.width/30, sourceImage.size.height/30);
  
  UIGraphicsBeginImageContext(size);
  
  [sourceImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
  self.scaledImage = UIGraphicsGetImageFromCurrentImageContext();
  self.imageLayer.shouldRasterize = YES;
  self.imageLayer.rasterizationScale = 1;
  self.imageLayer.magnificationFilter = kCAFilterNearest;
  self.imageLayer.contents = (id)self.scaledImage.CGImage;
  
  UIGraphicsEndImageContext();
}

- (void)setSelected:(BOOL)selected {
  self->_selected = selected;
  
  if (selected){
    self.selectedLayer.opacity = 0.6f;
  } else {
    self.selectedLayer.opacity = 0.0f;
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  [CATransaction begin];
  [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
  
  self.imageLayer.frame = self.imageFrame;
  self.imageLayer.masksToBounds = YES;
  
  self.selectedLayer.frame= self.bounds;
  [CATransaction commit];
}

- (BOOL)resizable {
  return YES;
}

@end
