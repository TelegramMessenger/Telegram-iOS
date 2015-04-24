/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
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

- (instancetype)initWithLabel:(NSString*)aLabel enabled:(BOOL)flag {
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


@implementation BITStoreButton {
  CALayer *_defaultBorderLayer;
  CALayer *_inActiveBorderLayer;
}

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
    if (self.style == BITStoreButtonStyleDefault) {
      [self setTitleColor:BIT_RGBCOLOR(106, 106, 106) forState:UIControlStateNormal];
    } else {
      [self setTitleColor:BIT_RGBCOLOR(35, 111, 251) forState:UIControlStateNormal];
      [_defaultBorderLayer setHidden:NO];
      [_inActiveBorderLayer setHidden:YES];
    }
  } else {
    [self setTitleColor:BIT_RGBCOLOR(148, 150, 151) forState:UIControlStateNormal];
    if (self.style == BITStoreButtonStyleOS7) {
      [_defaultBorderLayer setHidden:YES];
      [_inActiveBorderLayer setHidden:NO];
    }
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
      // frame is calculated and explicitly animated. so we absolutely need kCATransactionDisableActions
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

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
		self.layer.needsDisplayOnBoundsChange = YES;
    
    // setup title label
    [self.titleLabel setFont:[UIFont boldSystemFontOfSize:13.0]];
    
    // register for touch events
		[self addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    [self bringSubviewToFront:self.titleLabel];
  }
  return self;
}

- (instancetype)initWithPadding:(CGPoint)padding style:(BITStoreButtonStyle)style {
  CGRect frame = CGRectMake(0, 0, 40, BIT_MIN_HEIGHT);
  if ((self = [self initWithFrame:frame])) {
    _customPadding = padding;
    _style = style;

    if (style == BITStoreButtonStyleDefault) {
      // main gradient layer
      CAGradientLayer *gradient = [CAGradientLayer layer];
      gradient.colors = @[(id)BIT_RGBCOLOR(243, 243, 243).CGColor, (id)BIT_RGBCOLOR(222, 222, 222).CGColor];
      gradient.locations = @[[NSNumber numberWithFloat:0.0], [NSNumber numberWithFloat:1.0]];
      gradient.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(frame), CGRectGetHeight(frame));
      gradient.cornerRadius = 2.5;
      gradient.needsDisplayOnBoundsChange = YES;
      [self.layer addSublayer:gradient];
    }
    
    // border layers for more sex!
    _defaultBorderLayer = [CALayer layer];
    if (style == BITStoreButtonStyleDefault) {
      _defaultBorderLayer.borderColor = [BIT_RGBCOLOR(191, 191, 191) CGColor];
    } else {
      _defaultBorderLayer.borderColor = [BIT_RGBCOLOR(35, 111, 251) CGColor];
    }
    _defaultBorderLayer.borderWidth = 1.0;
		_defaultBorderLayer.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(frame), CGRectGetHeight(frame));
		_defaultBorderLayer.cornerRadius = 2.5;
		_defaultBorderLayer.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:_defaultBorderLayer];
    
    if (style == BITStoreButtonStyleOS7) {
      _inActiveBorderLayer = [CALayer layer];
      _inActiveBorderLayer.borderColor = [BIT_RGBCOLOR(148, 150, 151) CGColor];
      _inActiveBorderLayer.borderWidth = 1.0;
      _inActiveBorderLayer.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(frame), CGRectGetHeight(frame));
      _inActiveBorderLayer.cornerRadius = 2.5;
      _inActiveBorderLayer.needsDisplayOnBoundsChange = YES;
      [self.layer addSublayer:_inActiveBorderLayer];
      [_inActiveBorderLayer setHidden:YES];
    }
    
    [self bringSubviewToFront:self.titleLabel];
  }
  return self;
}



#pragma mark - UIView

- (CGSize)sizeThatFits:(CGSize)size {
  CGSize constr = (CGSize){.height = self.frame.size.height, .width = BIT_MAX_WIDTH};
  CGSize newSize;
  
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
  if ([self.buttonData.label respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
    CGRect calculatedRect = [self.buttonData.label boundingRectWithSize:constr
                                                                options:NSStringDrawingUsesFontLeading
                                                             attributes:@{NSFontAttributeName:self.titleLabel.font}
                                                                context:nil];
    newSize = calculatedRect.size;
  } else {
#endif
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    newSize = [self.buttonData.label sizeWithFont:self.titleLabel.font
                                constrainedToSize:constr
                                    lineBreakMode:kBITLineBreakModeMiddleTruncation];
#pragma clang diagnostic pop
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_6_1
  }
#endif
  
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
