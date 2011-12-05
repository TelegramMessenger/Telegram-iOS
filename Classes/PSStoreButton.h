//
//  PSStoreButton.h
//  HockeyDemo
//
//  Created by Peter Steinberger on 09.01.11.
//  Copyright 2011 Peter Steinberger. All rights reserved.
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

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

// defines a button action set (data container)
@interface PSStoreButtonData : NSObject {
  CGPoint customPadding_;
  NSString *label_;
  NSArray *colors_;
  BOOL enabled_;
}

+ (id)dataWithLabel:(NSString*)aLabel colors:(NSArray*)aColors enabled:(BOOL)flag;

@property (nonatomic, copy) NSString *label;
@property (nonatomic, retain) NSArray *colors;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

@end


@class PSStoreButton;
@protocol PSStoreButtonDelegate
- (void)storeButtonFired:(PSStoreButton *)button;
@end


// Simulate the Paymeny-Button from the AppStore
// The interface is flexible, so there is now fixed order
@interface PSStoreButton : UIButton {
  PSStoreButtonData *buttonData_;
  id<PSStoreButtonDelegate> buttonDelegate_;
  
  CAGradientLayer *gradient_;
  CGPoint customPadding_;
}

- (id)initWithFrame:(CGRect)frame;
- (id)initWithPadding:(CGPoint)padding;

// action delegate
@property (nonatomic, assign) id<PSStoreButtonDelegate> buttonDelegate;

// change the button layer
@property (nonatomic, retain) PSStoreButtonData *buttonData;
- (void)setButtonData:(PSStoreButtonData *)aButtonData animated:(BOOL)animated;

// align helper
@property (nonatomic, assign) CGPoint customPadding;
- (void)alignToSuperview;

// helpers to mimic an AppStore button
+ (NSArray *)appStoreGreenColor;
+ (NSArray *)appStoreBlueColor;
+ (NSArray *)appStoreGrayColor;

@end
