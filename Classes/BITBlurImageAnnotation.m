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


@end

@implementation BITBlurImageAnnotation

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
      self.clipsToBounds = YES;
      self.imageLayer = [CALayer layer];
      [self.layer addSublayer:self.imageLayer];
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

- (void)layoutSubviews {
  [super layoutSubviews];
  
  [CATransaction begin];
  [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
  
  self.imageLayer.frame = self.imageFrame;
  self.imageLayer.masksToBounds = YES;
  
  [CATransaction commit];
}

-(BOOL)resizable {
  return YES;
}

@end
