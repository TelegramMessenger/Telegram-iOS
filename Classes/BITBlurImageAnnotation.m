//
//  BITBlurImageAnnotation.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 26.02.14.
//
//

#import "BITBlurImageAnnotation.h"

@interface BITBlurImageAnnotation()

@property (nonatomic, strong) CALayer* imageLayer;
@property (nonatomic, strong) UIImage* scaledImage;
@property (nonatomic, strong) CALayer* selectedLayer;


@end

@implementation BITBlurImageAnnotation

- (id)initWithFrame:(CGRect)frame
{
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

-(void)setSourceImage:(UIImage *)sourceImage {
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

-(BOOL)resizable {
  return YES;
}

@end
