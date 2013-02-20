/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2013 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011-2012 Peter Steinberger.
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


#import "BITStoreButton.h"
#import "HockeySDKPrivate.h"
#import <QuartzCore/QuartzCore.h>

#define BIT_MIN_HEIGHT 25.0f
#define BIT_MAX_WIDTH 120.0f
#define BIT_PADDING 12.0f
#define kDefaultButtonAnimationTime 0.25f


@implementation BITStoreButtonData

#pragma mark - NSObject

- (id)initWithLabel:(NSString*)aLabel enabled:(BOOL)flag {
  if ((self = [super init])) {
    self.label = aLabel;
    self.enabled = flag;
  }
  return self;
}

+ (id)dataWithLabel:(NSString*)aLabel enabled:(BOOL)flag {
  return [[[self class] alloc] initWithLabel:aLabel enabled:flag];
}

@end


@implementation BITStoreButton

#pragma mark - private

- (void)buttonPressed:(id)sender {
  [_buttonDelegate storeButtonFired:self];
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
  // show text again, but only if animation did finish (or else another animation is on the way)
  if ([finished boolValue]) {
    [self setTitle:self.buttonData.label forState:UIControlStateNormal];
  }
}

- (void)updateButtonAnimated:(BOOL)animated {
  if (animated) {
    // hide text, then start animation
    [self setTitle:@"" forState:UIControlStateNormal];
    [UIView beginAnimations:@"storeButtonUpdate" context:nil];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:kDefaultButtonAnimationTime];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
  } else {
    [self setTitle:self.buttonData.label forState:UIControlStateNormal];
  }
  
  self.enabled = self.buttonData.isEnabled;
  
  // show white or gray text, depending on the state
  if (self.buttonData.isEnabled) {
    [self setTitleColor:BIT_RGBCOLOR(106, 106, 106) forState:UIControlStateNormal];
  } else {
    [self setTitleColor:BIT_RGBCOLOR(148, 150, 151) forState:UIControlStateNormal];
  }
  
  // calculate optimal new size
  CGSize sizeThatFits = [self sizeThatFits:CGSizeZero];
  
  // move sublayer (can't be animated explcitely)
  for (CALayer *aLayer in self.layer.sublayers) {
    [CATransaction begin];
    
    if (animated) {
      [CATransaction setAnimationDuration:kDefaultButtonAnimationTime];
      [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    } else {
      // frame is calculated and explicitely animated. so we absolutely need kCATransactionDisableActions
      [CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
    }
    
    CGRect newFrame = aLayer.frame;
    newFrame.size.width = sizeThatFits.width;
    aLayer.frame = newFrame;
    
    [CATransaction commit];
	}
  
  // set outer frame changes
  self.titleEdgeInsets = UIEdgeInsetsMake(2.0, self.titleEdgeInsets.left, 0.0, 0.0);
  [self alignToSuperview];
  
  if (animated) {
    [UIView commitAnimations];
  }
}

- (void)alignToSuperview {
  [self sizeToFit];
  if (self.superview) {
    CGRect cr = self.frame;
    cr.origin.y = _customPadding.y;
    cr.origin.x = self.superview.frame.size.width - cr.size.width - _customPadding.x * 2;
    self.frame = cr;
  }
}


#pragma mark - NSObject

- (id)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
		self.layer.needsDisplayOnBoundsChange = YES;
    
    // setup title label
    [self.titleLabel setFont:[UIFont boldSystemFontOfSize:13.0]];
    
    // register for touch events
		[self addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    // main gradient layer
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[(id)BIT_RGBCOLOR(243, 243, 243).CGColor, (id)BIT_RGBCOLOR(222, 222, 222).CGColor];
    gradient.locations = @[[NSNumber numberWithFloat:0.0], [NSNumber numberWithFloat:1.0]];
		gradient.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(frame), CGRectGetHeight(frame));
		gradient.cornerRadius = 2.5;
		gradient.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:gradient];
    
    // border layers for more sex!
    CALayer *borderLayer = [CALayer layer];
		borderLayer.borderColor = [BIT_RGBCOLOR(191, 191, 191) CGColor];
    borderLayer.borderWidth = 1.0;
		borderLayer.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(frame), CGRectGetHeight(frame));
		borderLayer.cornerRadius = 2.5;
		borderLayer.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:borderLayer];

    [self bringSubviewToFront:self.titleLabel];
  }
  return self;
}

- (id)initWithPadding:(CGPoint)padding {
  if ((self = [self initWithFrame:CGRectMake(0, 0, 40, BIT_MIN_HEIGHT)])) {
    _customPadding = padding;
  }
  return self;
}



#pragma mark - UIView

- (CGSize)sizeThatFits:(CGSize)size {
  CGSize constr = (CGSize){.height = self.frame.size.height, .width = BIT_MAX_WIDTH};
  CGSize newSize = [self.buttonData.label sizeWithFont:self.titleLabel.font constrainedToSize:constr lineBreakMode:kBITLineBreakModeMiddleTruncation];
  CGFloat newWidth = newSize.width + (BIT_PADDING * 2);
  CGFloat newHeight = BIT_MIN_HEIGHT > newSize.height ? BIT_MIN_HEIGHT : newSize.height;
  
  CGSize sizeThatFits = CGSizeMake(newWidth, newHeight);
  return sizeThatFits;
}

- (void)setFrame:(CGRect)aRect {
  [super setFrame:aRect];
  
  // copy frame changes to sublayers (but watch out for NaN's)
  for (CALayer *aLayer in self.layer.sublayers) {
    CGRect rect = aLayer.frame;
    rect.size.width = self.frame.size.width;
    rect.size.height = self.frame.size.height;
    aLayer.frame = rect;
    [aLayer layoutIfNeeded];
  }
}


#pragma mark - Properties

- (void)setButtonData:(BITStoreButtonData *)aButtonData {
  [self setButtonData:aButtonData animated:NO];
}

- (void)setButtonData:(BITStoreButtonData *)aButtonData animated:(BOOL)animated {
  if (_buttonData != aButtonData) {
    _buttonData = aButtonData;
  }
  
  [self updateButtonAnimated:animated];
}

@end
