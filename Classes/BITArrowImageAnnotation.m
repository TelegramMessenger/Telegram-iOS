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

#import "BITArrowImageAnnotation.h"

#define kArrowPointCount 7


@interface BITArrowImageAnnotation()

@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@property (nonatomic, strong) CAShapeLayer *strokeLayer;

@end

@implementation BITArrowImageAnnotation

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.shapeLayer = [CAShapeLayer layer];
    self.shapeLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.shapeLayer.lineWidth = 5;
    self.shapeLayer.fillColor = [UIColor redColor].CGColor;
    
    self.strokeLayer = [CAShapeLayer layer];
    self.strokeLayer.strokeColor = [UIColor redColor].CGColor;
    self.strokeLayer.lineWidth = 10;
    self.strokeLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.strokeLayer];

    [self.layer addSublayer:self.shapeLayer];

    
  }
  return self;
}

- (void)buildShape {
  CGFloat baseWidth = MAX(self.frame.size.width, self.frame.size.height);
  CGFloat topHeight = MAX(baseWidth / 3.0f,10);

  
  CGFloat lineWidth = MAX(baseWidth / 10.0f,3);
  CGFloat startX, startY, endX, endY;
  
  CGRect boundRect = CGRectInset(self.bounds, 0, 0);
  CGFloat arrowLength= sqrt(pow(CGRectGetWidth(boundRect), 2) + pow(CGRectGetHeight(boundRect), 2));
  if (arrowLength < 30){
    
    CGFloat factor = 30.f/arrowLength;
    
    boundRect = CGRectApplyAffineTransform(boundRect, CGAffineTransformMakeScale(factor,factor));
  }
  
  if ( self.movedDelta.width < 0){
    startX = CGRectGetMinX(boundRect);
    endX =  CGRectGetMaxX(boundRect);
  } else {
    startX = CGRectGetMaxX(boundRect);
    endX = CGRectGetMinX(boundRect);

  }
  
  if ( self.movedDelta.height < 0){
    startY = CGRectGetMinY(boundRect);
    endY =  CGRectGetMaxY(boundRect);
  } else {
    startY = CGRectGetMaxY(boundRect);
    endY =  CGRectGetMinY(boundRect);
    
  }
  
  
  if (fabs(CGRectGetWidth(boundRect)) < 30 || fabs(CGRectGetHeight(boundRect)) < 30){
    CGFloat smallerOne = MIN(fabs(CGRectGetHeight(boundRect)), fabs(CGRectGetWidth(boundRect)));
    
    CGFloat factor = smallerOne/30.f;
    
    CGRectApplyAffineTransform(boundRect, CGAffineTransformMakeScale(factor,factor));
  }
  
  UIBezierPath *path = [self bezierPathWithArrowFromPoint:CGPointMake(endX, endY) toPoint:CGPointMake(startX, startY) tailWidth:lineWidth headWidth:topHeight headLength:topHeight];
  
  self.shapeLayer.path = path.CGPath;
  self.strokeLayer.path = path.CGPath;
  [CATransaction begin];
  [CATransaction setAnimationDuration:0];
  self.strokeLayer.lineWidth = lineWidth/1.5f;
  self.shapeLayer.lineWidth = lineWidth / 3.0f;

  [CATransaction commit];

}


- (UIBezierPath *)bezierPathWithArrowFromPoint:(CGPoint)startPoint
                                           toPoint:(CGPoint)endPoint
                                         tailWidth:(CGFloat)tailWidth
                                         headWidth:(CGFloat)headWidth
                                        headLength:(CGFloat)headLength {
  CGFloat length = hypotf(endPoint.x - startPoint.x, endPoint.y - startPoint.y);
  
  CGPoint points[kArrowPointCount];
  [self getAxisAlignedArrowPoints:points
                            forLength:length
                            tailWidth:tailWidth
                            headWidth:headWidth
                           headLength:headLength];
  
  CGAffineTransform transform = [self transformForStartPoint:startPoint
                                                        endPoint:endPoint
                                                          length:length];
  
  CGMutablePathRef cgPath = CGPathCreateMutable();
  CGPathAddLines(cgPath, &transform, points, sizeof points / sizeof *points);
  CGPathCloseSubpath(cgPath);
  
  UIBezierPath *uiPath = [UIBezierPath bezierPathWithCGPath:cgPath];
  CGPathRelease(cgPath);
  return uiPath;
}

- (void)getAxisAlignedArrowPoints:(CGPoint[kArrowPointCount])points
                            forLength:(CGFloat)length
                            tailWidth:(CGFloat)tailWidth
                            headWidth:(CGFloat)headWidth
                           headLength:(CGFloat)headLength {
  CGFloat tailLength = length - headLength;
  points[0] = CGPointMake(0, tailWidth / 2);
  points[1] = CGPointMake(tailLength, tailWidth / 2);
  points[2] = CGPointMake(tailLength, headWidth / 2);
  points[3] = CGPointMake(length, 0);
  points[4] = CGPointMake(tailLength, -headWidth / 2);
  points[5] = CGPointMake(tailLength, -tailWidth / 2);
  points[6] = CGPointMake(0, -tailWidth / 2);
}

+ (CGAffineTransform)dqd_transformForStartPoint:(CGPoint)startPoint
                                       endPoint:(CGPoint)endPoint
                                         length:(CGFloat)length {
  CGFloat cosine = (endPoint.x - startPoint.x) / length;
  CGFloat sine = (endPoint.y - startPoint.y) / length;
  return (CGAffineTransform){ cosine, sine, -sine, cosine, startPoint.x, startPoint.y };
}

- (CGAffineTransform)transformForStartPoint:(CGPoint)startPoint
                                       endPoint:(CGPoint)endPoint
                                         length:(CGFloat)length {
  CGFloat cosine = (endPoint.x - startPoint.x) / length;
  CGFloat sine = (endPoint.y - startPoint.y) / length;
  return (CGAffineTransform){ cosine, sine, -sine, cosine, startPoint.x, startPoint.y };
}

#pragma mark - UIView 

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {

  CGPathRef strokePath = CGPathCreateCopyByStrokingPath(self.shapeLayer.path, NULL, fmaxf(90.0f, self.shapeLayer.lineWidth), kCGLineCapRound,kCGLineJoinMiter,0);
  
  BOOL containsPoint = CGPathContainsPoint(strokePath, NULL, point, NO);
  
  CGPathRelease(strokePath);
  
  if (containsPoint){
    return self;
  } else {
    return nil;
  }

}

- (void)layoutSubviews{
  [super layoutSubviews];
  
  [self buildShape];
}

@end
