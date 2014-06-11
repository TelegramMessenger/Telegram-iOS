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

#import "BITRectangleImageAnnotation.h"

@interface BITRectangleImageAnnotation()

@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@property (nonatomic, strong) CAShapeLayer *strokeLayer;


@end

@implementation BITRectangleImageAnnotation

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
      self.shapeLayer = [CAShapeLayer layer];
      self.shapeLayer.strokeColor = [UIColor redColor].CGColor;
      self.shapeLayer.lineWidth = 5;
      self.shapeLayer.fillColor = [UIColor clearColor].CGColor;
      
      self.strokeLayer = [CAShapeLayer layer];
      self.strokeLayer.strokeColor = [UIColor whiteColor].CGColor;
      self.strokeLayer.lineWidth = 10;
      self.strokeLayer.fillColor = [UIColor clearColor].CGColor;
      [self.layer addSublayer:self.strokeLayer];

      [self.layer addSublayer:self.shapeLayer];
    
    }
    return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  self.shapeLayer.frame = self.bounds;
  self.shapeLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:10].CGPath;
  
  
  self.strokeLayer.frame = self.bounds;
  self.strokeLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:10].CGPath;
  
  CGFloat lineWidth = MAX(self.frame.size.width / 10.0f,10);
  
  [CATransaction begin];
  [CATransaction setAnimationDuration:0];
  self.strokeLayer.lineWidth = lineWidth/1.5f;
  self.shapeLayer.lineWidth = lineWidth / 3.0f;
  
  [CATransaction commit];
}

- (BOOL)resizable {
  return YES;
}


@end
