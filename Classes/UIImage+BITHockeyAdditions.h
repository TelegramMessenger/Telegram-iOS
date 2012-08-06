//
//  UIImage+BITHockeyAdditions.h
//
//  Created by Peter Steinberger on 10.01.11.
//  Copyright (c) 2011-2012 Peter Steinberger.
//  Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
//  All rights reserved.
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

#import <UIKit/UIKit.h>

@interface UIImage (BITHockeyAdditions)

- (UIImage *)bit_roundedCornerImage:(NSInteger)cornerSize borderSize:(NSInteger)borderSize;
- (UIImage *)bit_imageToFitSize:(CGSize)fitSize honorScaleFactor:(BOOL)honorScaleFactor;
- (UIImage *)bit_reflectedImageWithHeight:(NSUInteger)height fromAlpha:(float)fromAlpha toAlpha:(float)toAlpha;

- (id)bit_initWithContentsOfResolutionIndependentFile:(NSString *)path NS_RETURNS_RETAINED;
+ (UIImage *)bit_imageWithContentsOfResolutionIndependentFile:(NSString *)path;
+ (UIImage *)bit_imageNamed:(NSString *)imageName bundle:(NSString *)bundleName;

@end
