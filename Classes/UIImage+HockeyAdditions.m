//
//  UIImage+HockeyAdditions.m
//  HockeyDemo
//
//  Created by Peter Steinberger on 10.01.11.
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

#import "UIImage+HockeyAdditions.h"
#import "BWGlobal.h"

// Private helper methods
@interface UIImage (HockeyAdditionsPrivate)
- (void)addRoundedRectToPath:(CGRect)rect context:(CGContextRef)context ovalWidth:(CGFloat)ovalWidth ovalHeight:(CGFloat)ovalHeight;

CGContextRef MyOpenBitmapContext(int pixelsWide, int pixelsHigh);
CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh, float fromAlpha, float toAlpha);
@end

@implementation UIImage (HockeyAdditions)

// Returns true if the image has an alpha layer
- (BOOL)hasAlpha {
  CGImageAlphaInfo alpha = CGImageGetAlphaInfo(self.CGImage);
  return (alpha == kCGImageAlphaFirst ||
          alpha == kCGImageAlphaLast ||
          alpha == kCGImageAlphaPremultipliedFirst ||
          alpha == kCGImageAlphaPremultipliedLast);
}

// Returns a copy of the given image, adding an alpha channel if it doesn't already have one
- (UIImage *)imageWithAlpha {
  if ([self hasAlpha]) {
    return self;
  }
  
  CGImageRef imageRef = self.CGImage;
  size_t width = CGImageGetWidth(imageRef) * self.scale;
  size_t height = CGImageGetHeight(imageRef) * self.scale;
  
  // The bitsPerComponent and bitmapInfo values are hard-coded to prevent an "unsupported parameter combination" error
  CGContextRef offscreenContext = CGBitmapContextCreate(NULL,
                                                        width,
                                                        height,
                                                        8,
                                                        0,
                                                        CGImageGetColorSpace(imageRef),
                                                        kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
  
  // Draw the image into the context and retrieve the new image, which will now have an alpha layer
  CGContextDrawImage(offscreenContext, CGRectMake(0, 0, width, height), imageRef);
  CGImageRef imageRefWithAlpha = CGBitmapContextCreateImage(offscreenContext);
  UIImage *imageWithAlpha = [UIImage imageWithCGImage:imageRefWithAlpha];
  
  // Clean up
  CGContextRelease(offscreenContext);
  CGImageRelease(imageRefWithAlpha);
  
  return imageWithAlpha;
}

// Creates a copy of this image with rounded corners
// If borderSize is non-zero, a transparent border of the given size will also be added
// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
- (UIImage *)bw_roundedCornerImage:(NSInteger)cornerSize borderSize:(NSInteger)borderSize {
  // If the image does not have an alpha layer, add one
  
	UIImage *roundedImage = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
	BW_IF_IOS4_OR_GREATER(
                        UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0); // 0.0 for scale means "correct scale for device's main screen".
                        CGImageRef sourceImg = CGImageCreateWithImageInRect([self CGImage], CGRectMake(0, 0, self.size.width * self.scale, self.size.height * self.scale)); // cropping happens here.
                        
                        // Create a clipping path with rounded corners
                        CGContextRef context = UIGraphicsGetCurrentContext();
                        CGContextBeginPath(context);
                        [self addRoundedRectToPath:CGRectMake(borderSize, borderSize, self.size.width - borderSize * 2, self.size.height - borderSize * 2)
                                           context:context
                                         ovalWidth:cornerSize
                                        ovalHeight:cornerSize];
                        CGContextClosePath(context);
                        CGContextClip(context);
                        
                        roundedImage = [UIImage imageWithCGImage:sourceImg scale:0.0 orientation:self.imageOrientation]; // create cropped UIImage.
                        [roundedImage drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)]; // the actual scaling happens here, and orientation is taken care of automatically.
                        CGImageRelease(sourceImg);
                        roundedImage = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                        )
#endif
  if (!roundedImage) {
    // Try older method.
    UIImage *image = [self imageWithAlpha];
    
    // Build a context that's the same dimensions as the new size
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 image.size.width,
                                                 image.size.height,
                                                 CGImageGetBitsPerComponent(image.CGImage),
                                                 0,
                                                 CGImageGetColorSpace(image.CGImage),
                                                 CGImageGetBitmapInfo(image.CGImage));
    
    // Create a clipping path with rounded corners
    CGContextBeginPath(context);
    [self addRoundedRectToPath:CGRectMake(borderSize, borderSize, image.size.width - borderSize * 2, image.size.height - borderSize * 2)
                       context:context
                     ovalWidth:cornerSize
                    ovalHeight:cornerSize];
    CGContextClosePath(context);
    CGContextClip(context);
    
    // Draw the image to the context; the clipping path will make anything outside the rounded rect transparent
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
    
    // Create a CGImage from the context
    CGImageRef clippedImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    // Create a UIImage from the CGImage
    roundedImage = [UIImage imageWithCGImage:clippedImage];
    CGImageRelease(clippedImage);
  }
  return roundedImage;
}

#pragma mark -
#pragma mark Private helper methods

// Adds a rectangular path to the given context and rounds its corners by the given extents
// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
- (void)addRoundedRectToPath:(CGRect)rect context:(CGContextRef)context ovalWidth:(CGFloat)ovalWidth ovalHeight:(CGFloat)ovalHeight {
  if (ovalWidth == 0 || ovalHeight == 0) {
    CGContextAddRect(context, rect);
    return;
  }
  CGContextSaveGState(context);
  CGContextTranslateCTM(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
  CGContextScaleCTM(context, ovalWidth, ovalHeight);
  CGFloat fw = CGRectGetWidth(rect) / ovalWidth;
  CGFloat fh = CGRectGetHeight(rect) / ovalHeight;
  CGContextMoveToPoint(context, fw, fh/2);
  CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
  CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
  CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
  CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
  CGContextClosePath(context);
  CGContextRestoreGState(context);
}

- (UIImage *)bw_imageToFitSize:(CGSize)fitSize honorScaleFactor:(BOOL)honorScaleFactor
{
	float imageScaleFactor = 1.0;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
  if (honorScaleFactor) {
    if ([self respondsToSelector:@selector(scale)]) {
      imageScaleFactor = [self scale];
    }
  }
#endif
  
  float sourceWidth = [self size].width * imageScaleFactor;
  float sourceHeight = [self size].height * imageScaleFactor;
  float targetWidth = fitSize.width;
  float targetHeight = fitSize.height;
  
  // Calculate aspect ratios
  float sourceRatio = sourceWidth / sourceHeight;
  float targetRatio = targetWidth / targetHeight;
  
  // Determine what side of the source image to use for proportional scaling
  BOOL scaleWidth = (sourceRatio <= targetRatio);
  // Deal with the case of just scaling proportionally to fit, without cropping
  scaleWidth = !scaleWidth;
  
  // Proportionally scale source image
  float scalingFactor, scaledWidth, scaledHeight;
  if (scaleWidth) {
    scalingFactor = 1.0 / sourceRatio;
    scaledWidth = targetWidth;
    scaledHeight = round(targetWidth * scalingFactor);
  } else {
    scalingFactor = sourceRatio;
    scaledWidth = round(targetHeight * scalingFactor);
    scaledHeight = targetHeight;
  }
  
  // Calculate compositing rectangles
  CGRect sourceRect, destRect;
  sourceRect = CGRectMake(0, 0, sourceWidth, sourceHeight);
  destRect = CGRectMake(0, 0, scaledWidth, scaledHeight);
  
  // Create appropriately modified image.
	UIImage *image = nil;
	BW_IF_IOS4_OR_GREATER
  (
   UIGraphicsBeginImageContextWithOptions(destRect.size, NO, honorScaleFactor ? 0.0 : 1.0); // 0.0 for scale means "correct scale for device's main screen".
   CGImageRef sourceImg = CGImageCreateWithImageInRect([self CGImage], sourceRect); // cropping happens here.
   image = [UIImage imageWithCGImage:sourceImg scale:0.0 orientation:self.imageOrientation]; // create cropped UIImage.
   [image drawInRect:destRect]; // the actual scaling happens here, and orientation is taken care of automatically.
   CGImageRelease(sourceImg);
   image = UIGraphicsGetImageFromCurrentImageContext();
   UIGraphicsEndImageContext();
   )
	if (!image) {
		// Try older method.
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGContextRef context = CGBitmapContextCreate(NULL,  scaledWidth, scaledHeight, 8, (fitSize.width * 4),
                                                 colorSpace, kCGImageAlphaPremultipliedLast);
		CGImageRef sourceImg = CGImageCreateWithImageInRect([self CGImage], sourceRect);
		CGContextDrawImage(context, destRect, sourceImg);
		CGImageRelease(sourceImg);
		CGImageRef finalImage = CGBitmapContextCreateImage(context);
		CGContextRelease(context);
		CGColorSpaceRelease(colorSpace);
		image = [UIImage imageWithCGImage:finalImage];
		CGImageRelease(finalImage);
	}
  
  return image;
}



CGImageRef CreateGradientImage(int pixelsWide, int pixelsHigh, float fromAlpha, float toAlpha) {
	CGImageRef theCGImage = NULL;
  
	// gradient is always black-white and the mask must be in the gray colorspace
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
  
	// create the bitmap context
	CGContextRef gradientBitmapContext = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh,
                                                             8, 0, colorSpace, kCGImageAlphaNone);
  
	// define the start and end grayscale values (with the alpha, even though
	// our bitmap context doesn't support alpha the gradient requires it)
	CGFloat colors[] = {toAlpha, 1.0, fromAlpha, 1.0};
  
	// create the CGGradient and then release the gray color space
	CGGradientRef grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);
	CGColorSpaceRelease(colorSpace);
  
	// create the start and end points for the gradient vector (straight down)
	CGPoint gradientEndPoint = CGPointZero;
	CGPoint gradientStartPoint = CGPointMake(0, pixelsHigh);
  
	// draw the gradient into the gray bitmap context
	CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint,
                              gradientEndPoint, kCGGradientDrawsAfterEndLocation);
	CGGradientRelease(grayScaleGradient);
  
	// convert the context into a CGImageRef and release the context
	theCGImage = CGBitmapContextCreateImage(gradientBitmapContext);
	CGContextRelease(gradientBitmapContext);
  
	// return the imageref containing the gradient
  return theCGImage;
}

CGContextRef MyOpenBitmapContext(int pixelsWide, int pixelsHigh) {
  CGSize size = CGSizeMake(pixelsWide, pixelsHigh);
  if (UIGraphicsBeginImageContextWithOptions != NULL) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
  }
  else {
    UIGraphicsBeginImageContext(size);
  }
  
  return UIGraphicsGetCurrentContext();
}

- (UIImage *)bw_reflectedImageWithHeight:(NSUInteger)height fromAlpha:(float)fromAlpha toAlpha:(float)toAlpha {
  if(height == 0)
		return nil;
  
	// create a bitmap graphics context the size of the image
	CGContextRef mainViewContentContext = MyOpenBitmapContext(self.size.width, height);
  
	// create a 2 bit CGImage containing a gradient that will be used for masking the
	// main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
	// function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
	CGImageRef gradientMaskImage = CreateGradientImage(1, height, fromAlpha, toAlpha);
  
	// create an image by masking the bitmap of the mainView content with the gradient view
	// then release the  pre-masked content bitmap and the gradient bitmap
	CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, self.size.width, height), gradientMaskImage);
	CGImageRelease(gradientMaskImage);
  
	// draw the image into the bitmap context
	CGContextDrawImage(mainViewContentContext, CGRectMake(0, 0, self.size.width, self.size.height), self.CGImage);
  
	// convert the finished reflection image to a UIImage
	UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext(); // returns autoreleased
  UIGraphicsEndImageContext();
  
	return theImage;
}

- (id)bw_initWithContentsOfResolutionIndependentFile:(NSString *)path {
  if ([UIScreen instancesRespondToSelector:@selector(scale)] && (int)[[UIScreen mainScreen] scale] == 2.0) {
    NSString *path2x = [[path stringByDeletingLastPathComponent]
                        stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.%@",
                                                        [[path lastPathComponent] stringByDeletingPathExtension],
                                                        [path pathExtension]]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path2x]) {
      return [self initWithContentsOfFile:path2x];
    }
  }
  
  return [self initWithContentsOfFile:path];
}

+ (UIImage*)bw_imageWithContentsOfResolutionIndependentFile:(NSString *)path {
#ifndef __clang_analyzer__
  // clang alayzer in 4.2b3 thinks here's a leak, which is not the case.
  return [[[UIImage alloc] bw_initWithContentsOfResolutionIndependentFile:path] autorelease];
#endif
}


+ (UIImage *)bw_imageNamed:(NSString *)imageName bundle:(NSString *)bundleName {
	NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
	NSString *bundlePath = [resourcePath stringByAppendingPathComponent:bundleName];
	NSString *imagePath = [bundlePath stringByAppendingPathComponent:imageName];
	return [UIImage bw_imageWithContentsOfResolutionIndependentFile:imagePath];
}

@end
