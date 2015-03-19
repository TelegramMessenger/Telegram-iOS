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


#import <UIKit/UIKit.h>

// defines a button action set (data container)
@interface BITStoreButtonData : NSObject

+ (id)dataWithLabel:(NSString*)aLabel enabled:(BOOL)flag;

@property (nonatomic, copy) NSString *label;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

@end


@class BITStoreButton;
@protocol BITStoreButtonDelegate
- (void)storeButtonFired:(BITStoreButton *)button;
@end


#ifndef __IPHONE_6_1
#define __IPHONE_6_1     60100
#endif

/**
 * Button style depending on the iOS version
 */
typedef NS_ENUM(NSUInteger, BITStoreButtonStyle) {
  /**
   * Default is iOS 6 style
   */
  BITStoreButtonStyleDefault = 0,
  /**
   * Draw buttons in the iOS 7 style
   */
  BITStoreButtonStyleOS7 = 1
};


// Simulate the Payment Button from the AppStore
// The interface is flexible, so there is now fixed order
@interface BITStoreButton : UIButton

- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithPadding:(CGPoint)padding style:(BITStoreButtonStyle)style;

// action delegate
@property (nonatomic, weak) id<BITStoreButtonDelegate> buttonDelegate;

// change the button layer
@property (nonatomic, strong) BITStoreButtonData *buttonData;
- (void)setButtonData:(BITStoreButtonData *)aButtonData animated:(BOOL)animated;

// align helper
@property (nonatomic, assign) CGPoint customPadding;

// align helper
@property (nonatomic, assign) BITStoreButtonStyle style;


- (void)alignToSuperview;

@end
