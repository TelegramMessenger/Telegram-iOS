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

#ifndef __IPHONE_6_1
#define __IPHONE_6_1     60100
#endif


/**
 * Header style depending on the iOS version
 */
typedef NS_ENUM(NSUInteger, BITAppStoreHeaderStyle) {
  /**
   * Default is iOS 6 style
   */
  BITAppStoreHeaderStyleDefault = 0,
  /**
   * Draw header in the iOS 7 style
   */
  BITAppStoreHeaderStyleOS7 = 1
};

@interface BITAppStoreHeader : UIView

@property (nonatomic, copy) NSString *headerText;
@property (nonatomic, copy) NSString *subHeaderText;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) BITAppStoreHeaderStyle style;

@end
