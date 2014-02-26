//
//  BITArrowImageAnnotation.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 26.02.14.
//
//

#import "BITArrowImageAnnotation.h"

#define kArrowPointCount 7


@interface BITArrowImageAnnotation()

@property (nonatomic, strong) CAShapeLayer *shapeLayer;

@end

@implementation BITArrowImageAnnotation

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.shapeLayer = [CAShapeLayer layer];
    self.shapeLayer.strokeColor = [UIColor redColor].CGColor;
    self.shapeLayer.lineWidth = 5;
    self.shapeLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.shapeLayer];
    
  }
  return self;
}

- (void)buildShape {
  CGFloat topHeight = MAX(self.frame.size.width / 3.0f,20);
  
  CGFloat lineWidth = MAX(self.frame.size.width / 5.0f,20);
  
  UIBezierPath *path = [self bezierPathWithArrowFromPoint:CGPointMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame)) toPoint:CGPointMake(CGRectGetMaxX(self.frame), CGRectGetMaxY(self.frame)) tailWidth:lineWidth headWidth:self.frame.size.height headLength:topHeight];
  
  self.shapeLayer.path = path.CGPath;
}

-(void)layoutSubviews{
  [super layoutSubviews];
  
  [self buildShape];
  
  self.shapeLayer.frame = self.bounds;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

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

@end
