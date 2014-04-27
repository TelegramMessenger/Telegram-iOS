//
//  BITImageAnnotation.h
//  HockeySDK
//
//  Created by Moritz Haarmann on 24.02.14.
//
//

#import <UIKit/UIKit.h>

@interface BITImageAnnotation : UIView {
  BOOL _selected;
}

@property (nonatomic) CGSize movedDelta;
@property (nonatomic, weak) UIImage *sourceImage;
@property (nonatomic) CGRect imageFrame;

-(BOOL)resizable;

- (void)setSelected:(BOOL)selected;
- (BOOL)isSelected;

@end
