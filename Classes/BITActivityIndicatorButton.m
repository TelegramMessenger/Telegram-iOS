//
//  BITActivityIndicatorButton.m
//  HockeySDK
//
//  Created by Moritz Haarmann on 21.05.14.
//
//

#import "BITActivityIndicatorButton.h"

@interface BITActivityIndicatorButton()

@property (nonatomic, strong) UIActivityIndicatorView *indicator;
@property (nonatomic) BOOL indicatorVisible;

@end

@implementation BITActivityIndicatorButton

- (void)setShowsActivityIndicator:(BOOL)showsIndicator {
  if (self.indicatorVisible == showsIndicator){
    return;
  }
  
  if (!self.indicator){
    self.indicator = [[UIActivityIndicatorView alloc] initWithFrame:self.bounds];
    [self addSubview:self.indicator];
    [self.indicator setColor:[UIColor blackColor]];
  }
  
  self.indicatorVisible = showsIndicator;
  
  if (showsIndicator){
    [self.indicator startAnimating];
    self.indicator.alpha = 1;
    self.layer.borderWidth = 1;
    self.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.layer.cornerRadius = 5;
    self.imageView.image = nil;
  } else {
    [self.indicator stopAnimating];
    self.layer.cornerRadius = 0;
    self.indicator.alpha = 0;
    self.layer.borderWidth = 0;

  }
  
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  [self.indicator setFrame:self.bounds];
  
}


@end
