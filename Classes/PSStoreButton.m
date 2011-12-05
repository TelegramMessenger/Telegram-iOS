//
//  PSStoreButton.m
//  HockeyDemo
//
//  Created by Peter Steinberger on 09.01.11.
//  Copyright 2011 Peter Steinberger. All rights reserved.
//
//  This code was inspired by https://github.com/dhmspector/ZIStoreButton
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "PSStoreButton.h"

#ifdef DEBUG
#define PSLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define PSLog(...)
#endif

#define PS_RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define PS_MIN_HEIGHT 25.0f
#define PS_MAX_WIDTH 120.0f
#define PS_PADDING 12.0f
#define kDefaultButtonAnimationTime 0.25f

@implementation PSStoreButtonData

@synthesize label = label_;
@synthesize colors = colors_;
@synthesize enabled = enabled_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject

- (id)initWithLabel:(NSString*)aLabel colors:(NSArray*)aColors enabled:(BOOL)flag {
  if ((self = [super init])) {
    self.label = aLabel;
    self.colors = aColors;
    self.enabled = flag;
  }
  return self;
}

+ (id)dataWithLabel:(NSString*)aLabel colors:(NSArray*)aColors enabled:(BOOL)flag {
  return [[[[self class] alloc] initWithLabel:aLabel colors:aColors enabled:flag] autorelease];
}

- (void)dealloc {
  [label_ release];
  [colors_ release];
  
  [super dealloc];
}
@end


@interface PSStoreButton ()
// call when buttonData was updated
- (void)updateButtonAnimated:(BOOL)animated;
@end


@implementation PSStoreButton

@synthesize buttonData = buttonData_;
@synthesize buttonDelegate = buttonDelegate_;
@synthesize customPadding = customPadding_;

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark private

- (void)touchedUpOutside:(id)sender {
  PSLog(@"touched outside...");
}

- (void)buttonPressed:(id)sender {
  PSLog(@"calling delegate:storeButtonFired for %@", sender);
  [buttonDelegate_ storeButtonFired:self];
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
  }else {
    [self setTitle:self.buttonData.label forState:UIControlStateNormal];
  }
  
  self.enabled = self.buttonData.isEnabled;
  gradient_.colors = self.buttonData.colors;
  
  // show white or gray text, depending on the state
  if (self.buttonData.isEnabled) {
    [self setTitleShadowColor:[UIColor colorWithWhite:0.200 alpha:1.000] forState:UIControlStateNormal];
    [self.titleLabel setShadowOffset:CGSizeMake(0.0, -0.6)];
    [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:1.000] forState:UIControlStateNormal];
  }else {
    [self.titleLabel setShadowOffset:CGSizeMake(0.0, 0.0)];
    [self setTitleColor:PS_RGBCOLOR(148,150,151) forState:UIControlStateNormal];
  }
  
  // calculate optimal new size
  CGSize sizeThatFits = [self sizeThatFits:CGSizeZero];
  
  // move sublayer (can't be animated explcitely)
  for (CALayer *aLayer in self.layer.sublayers) {
    [CATransaction begin];
    
    if (animated) {
      [CATransaction setAnimationDuration:kDefaultButtonAnimationTime];
      [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    }else {
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
    cr.origin.y = customPadding_.y;
    cr.origin.x = self.superview.frame.size.width - cr.size.width - customPadding_.x * 2;
    self.frame = cr;
  }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSObject

- (id)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
		self.layer.needsDisplayOnBoundsChange = YES;
    
    // setup title label
    [self.titleLabel setFont:[UIFont boldSystemFontOfSize:13.0]];
    
    // register for touch events
    [self addTarget:self action:@selector(touchedUpOutside:) forControlEvents:UIControlEventTouchUpOutside];
		[self addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    // border layers for more sex!
    CAGradientLayer *bevelLayer = [CAGradientLayer layer];
		bevelLayer.colors = [NSArray arrayWithObjects:(id)[[UIColor colorWithWhite:0.4 alpha:1.0] CGColor], [[UIColor whiteColor] CGColor], nil];
		bevelLayer.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(frame), CGRectGetHeight(frame));
		bevelLayer.cornerRadius = 2.5;
		bevelLayer.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:bevelLayer];
    
		CAGradientLayer *topBorderLayer = [CAGradientLayer layer];
		topBorderLayer.colors = [NSArray arrayWithObjects:(id)[[UIColor darkGrayColor] CGColor], [[UIColor lightGrayColor] CGColor], nil];
		topBorderLayer.frame = CGRectMake(0.5, 0.5, CGRectGetWidth(frame) - 1.0, CGRectGetHeight(frame) - 1.0);
		topBorderLayer.cornerRadius = 2.6;
		topBorderLayer.needsDisplayOnBoundsChange = YES;
		[self.layer addSublayer:topBorderLayer];
    
    // main gradient layer
    gradient_ = [[CAGradientLayer layer] retain];
    gradient_.locations = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0], [NSNumber numberWithFloat:1.0], nil];//[NSNumber numberWithFloat:0.500], [NSNumber numberWithFloat:0.5001],
		gradient_.frame = CGRectMake(0.75, 0.75, CGRectGetWidth(frame) - 1.5, CGRectGetHeight(frame) - 1.5);
		gradient_.cornerRadius = 2.5;
		gradient_.needsDisplayOnBoundsChange = YES;
    [self.layer addSublayer:gradient_];
    [self bringSubviewToFront:self.titleLabel];
  }
  return self;
}

- (id)initWithPadding:(CGPoint)padding {
  if ((self = [self initWithFrame:CGRectMake(0, 0, 40, PS_MIN_HEIGHT)])) {
    customPadding_ = padding;
  }
  return self;
}

- (void)dealloc {
  [buttonData_ release];
  [gradient_ release];
  
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UIView

- (CGSize)sizeThatFits:(CGSize)size {
  CGSize constr = (CGSize){.height = self.frame.size.height, .width = PS_MAX_WIDTH};
	CGSize newSize = [self.buttonData.label sizeWithFont:self.titleLabel.font constrainedToSize:constr lineBreakMode:UILineBreakModeMiddleTruncation];
	CGFloat newWidth = newSize.width + (PS_PADDING * 2);
  CGFloat newHeight = PS_MIN_HEIGHT > newSize.height ? PS_MIN_HEIGHT : newSize.height;
  
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

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Properties

- (void)setButtonData:(PSStoreButtonData *)aButtonData {
  [self setButtonData:aButtonData animated:NO];
}

- (void)setButtonData:(PSStoreButtonData *)aButtonData animated:(BOOL)animated {
  if (buttonData_ != aButtonData) {
    [buttonData_ release];
    buttonData_ = [aButtonData retain];
  }
  
  [self updateButtonAnimated:animated];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Static

+ (NSArray *)appStoreGreenColor {
  return [NSArray arrayWithObjects:(id)
          [UIColor colorWithRed:0.482 green:0.674 blue:0.406 alpha:1.000].CGColor,
          [UIColor colorWithRed:0.299 green:0.606 blue:0.163 alpha:1.000].CGColor, nil];
}

+ (NSArray *)appStoreBlueColor {
  return [NSArray arrayWithObjects:(id)
          [UIColor colorWithRed:0.306 green:0.380 blue:0.547 alpha:1.000].CGColor,
          [UIColor colorWithRed:0.129 green:0.220 blue:0.452 alpha:1.000].CGColor, nil];
}

+ (NSArray *)appStoreGrayColor {
  return [NSArray arrayWithObjects:(id)
          PS_RGBCOLOR(187,189,191).CGColor,
          PS_RGBCOLOR(210,210,210).CGColor, nil];
}

@end
