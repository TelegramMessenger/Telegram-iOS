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
@property (nonatomic, strong) CAShapeLayer *strokeLayer;


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
    
    self.strokeLayer = [CAShapeLayer layer];
    self.strokeLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.strokeLayer.lineWidth = 10;
    self.strokeLayer.fillColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:self.strokeLayer];

    [self.layer addSublayer:self.shapeLayer];

    
  }
  return self;
}

- (void)buildShape {
  CGFloat topHeight = MAX(self.frame.size.width / 3.0f,20);

  
  CGFloat lineWidth = MAX(self.frame.size.width / 10.0f,10);
  CGFloat startX, startY, endX, endY;
  if ( self.movedDelta.width > 0){
    startX = CGRectGetMinX(self.bounds);
    endX =  CGRectGetMaxX(self.bounds);
  } else {
    startX = CGRectGetMaxX(self.bounds);
    endX = CGRectGetMinX(self.bounds);

  }
  
  if ( self.movedDelta.height > 0){
    startY = CGRectGetMinY(self.bounds);
    endY =  CGRectGetMaxY(self.bounds);
  } else {
    startY = CGRectGetMaxY(self.bounds);
    endY =  CGRectGetMinY(self.bounds);
    
  }
  
  NSLog(@"Start X: %f, Y: %f, END: %f %f %@", startX, startY, endX,endY, self);
  
  UIBezierPath *path = [self bezierPathWithArrowFromPoint:CGPointMake(endX,endY) toPoint:CGPointMake(startX,startY) tailWidth:lineWidth headWidth:topHeight headLength:topHeight];
  
  self.shapeLayer.path = path.CGPath;
  self.strokeLayer.path = path.CGPath;
}

-(void)layoutSubviews{
  [super layoutSubviews];

  [self buildShape];
  
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
