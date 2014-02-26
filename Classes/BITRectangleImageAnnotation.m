//
//  BITRectangleImageAnnotation.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 25.02.14.
//
//

#import "BITRectangleImageAnnotation.h"

@interface BITRectangleImageAnnotation()

@property (nonatomic, strong) CAShapeLayer *shapeLayer;
@property (nonatomic, strong) CAShapeLayer *strokeLayer;


@end

@implementation BITRectangleImageAnnotation

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

- (void)layoutSubviews {
  [super layoutSubviews];
  
  self.shapeLayer.frame = self.bounds;
  self.shapeLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:10].CGPath;
  
  
  self.strokeLayer.frame = self.bounds;
  self.strokeLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:10].CGPath;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
