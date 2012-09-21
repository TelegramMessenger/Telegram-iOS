/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012 HockeyApp, Bit Stadium GmbH.
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


#import "BITHockeyHelper.h"

#pragma mark NSString helpers

NSString *bit_URLEncodedString(NSString *inputString) {
  NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                         (CFStringRef)inputString,
                                                                         NULL,
                                                                         CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                         kCFStringEncodingUTF8);
  [result autorelease];
  return result;
}

NSString *bit_URLDecodedString(NSString *inputString) {
  NSString *result = (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                         (CFStringRef)inputString,
                                                                                         CFSTR(""),
                                                                                         kCFStringEncodingUTF8);
  [result autorelease];
  return result;
}

NSComparisonResult bit_versionCompare(NSString *stringA, NSString *stringB) {
  // Extract plain version number from self
  NSString *plainSelf = stringA;
  NSRange letterRange = [plainSelf rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainSelf = [plainSelf substringToIndex: letterRange.location];
	
  // Extract plain version number from other
  NSString *plainOther = stringB;
  letterRange = [plainOther rangeOfCharacterFromSet: [NSCharacterSet letterCharacterSet]];
  if (letterRange.length)
    plainOther = [plainOther substringToIndex: letterRange.location];
	
  // Compare plain versions
  NSComparisonResult result = [plainSelf compare:plainOther options:NSNumericSearch];
	
  // If plain versions are equal, compare full versions
  if (result == NSOrderedSame)
    result = [stringA compare:stringB options:NSNumericSearch];
	
  // Done
  return result;
}


#pragma mark UIImage private helpers

static void bit_addRoundedRectToPath(CGRect rect, CGContextRef context, CGFloat ovalWidth, CGFloat ovalHeight);
static CGContextRef bit_MyOpenBitmapContext(int pixelsWide, int pixelsHigh);
static CGImageRef bit_CreateGradientImage(int pixelsWide, int pixelsHigh, float fromAlpha, float toAlpha);
static BOOL bit_hasAlpha(UIImage *inputImage);
UIImage *bit_imageWithAlpha(UIImage *inputImage);

// Adds a rectangular path to the given context and rounds its corners by the given extents
// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
void bit_addRoundedRectToPath(CGRect rect, CGContextRef context, CGFloat ovalWidth, CGFloat ovalHeight) {
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

CGImageRef bit_CreateGradientImage(int pixelsWide, int pixelsHigh, float fromAlpha, float toAlpha) {
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

CGContextRef bit_MyOpenBitmapContext(int pixelsWide, int pixelsHigh) {
  CGSize size = CGSizeMake(pixelsWide, pixelsHigh);
  if (UIGraphicsBeginImageContextWithOptions != NULL) {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
  }
  else {
    UIGraphicsBeginImageContext(size);
  }
  
  return UIGraphicsGetCurrentContext();
}


// Returns true if the image has an alpha layer
BOOL bit_hasAlpha(UIImage *inputImage) {
  CGImageAlphaInfo alpha = CGImageGetAlphaInfo(inputImage.CGImage);
  return (alpha == kCGImageAlphaFirst ||
          alpha == kCGImageAlphaLast ||
          alpha == kCGImageAlphaPremultipliedFirst ||
          alpha == kCGImageAlphaPremultipliedLast);
}

// Returns a copy of the given image, adding an alpha channel if it doesn't already have one
UIImage *bit_imageWithAlpha(UIImage *inputImage) {
  if (bit_hasAlpha(inputImage)) {
    return inputImage;
  }
  
  CGImageRef imageRef = inputImage.CGImage;
  size_t width = CGImageGetWidth(imageRef) * inputImage.scale;
  size_t height = CGImageGetHeight(imageRef) * inputImage.scale;
  
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


#pragma mark UIImage helpers

UIImage *bit_imageToFitSize(UIImage *inputImage, CGSize fitSize, BOOL honorScaleFactor) {
	float imageScaleFactor = 1.0;
  if (honorScaleFactor) {
    if ([inputImage respondsToSelector:@selector(scale)]) {
      imageScaleFactor = [inputImage scale];
    }
  }
  
  float sourceWidth = [inputImage size].width * imageScaleFactor;
  float sourceHeight = [inputImage size].height * imageScaleFactor;
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
  UIGraphicsBeginImageContextWithOptions(destRect.size, NO, honorScaleFactor ? 0.0 : 1.0); // 0.0 for scale means "correct scale for device's main screen".
  CGImageRef sourceImg = CGImageCreateWithImageInRect([inputImage CGImage], sourceRect); // cropping happens here.
  image = [UIImage imageWithCGImage:sourceImg scale:0.0 orientation:inputImage.imageOrientation]; // create cropped UIImage.
  [image drawInRect:destRect]; // the actual scaling happens here, and orientation is taken care of automatically.
  CGImageRelease(sourceImg);
  image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
	if (!image) {
    // Try older method.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,  scaledWidth, scaledHeight, 8, (fitSize.width * 4),
                                                 colorSpace, kCGImageAlphaPremultipliedLast);
    CGImageRef sourceImg = CGImageCreateWithImageInRect([inputImage CGImage], sourceRect);
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


UIImage *bit_reflectedImageWithHeight(UIImage *inputImage, NSUInteger height, float fromAlpha, float toAlpha) {
  if(height == 0)
    return nil;
  
  // create a bitmap graphics context the size of the image
  CGContextRef mainViewContentContext = bit_MyOpenBitmapContext(inputImage.size.width, height);
  
  // create a 2 bit CGImage containing a gradient that will be used for masking the
  // main view content to create the 'fade' of the reflection.  The CGImageCreateWithMask
  // function will stretch the bitmap image as required, so we can create a 1 pixel wide gradient
  CGImageRef gradientMaskImage = bit_CreateGradientImage(1, height, fromAlpha, toAlpha);
  
  // create an image by masking the bitmap of the mainView content with the gradient view
  // then release the  pre-masked content bitmap and the gradient bitmap
  CGContextClipToMask(mainViewContentContext, CGRectMake(0.0, 0.0, inputImage.size.width, height), gradientMaskImage);
  CGImageRelease(gradientMaskImage);
  
  // draw the image into the bitmap context
  CGContextDrawImage(mainViewContentContext, CGRectMake(0, 0, inputImage.size.width, inputImage.size.height), inputImage.CGImage);
  
  // convert the finished reflection image to a UIImage
  UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext(); // returns autoreleased
  UIGraphicsEndImageContext();
  
  return theImage;
}


UIImage *bit_newWithContentsOfResolutionIndependentFile(NSString * path) {
  if ([UIScreen instancesRespondToSelector:@selector(scale)] && (int)[[UIScreen mainScreen] scale] == 2.0) {
    NSString *path2x = [[path stringByDeletingLastPathComponent]
                        stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.%@",
                                                        [[path lastPathComponent] stringByDeletingPathExtension],
                                                        [path pathExtension]]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path2x]) {
      return [[UIImage alloc] initWithContentsOfFile:path2x];
    }
  }
  
  return [[UIImage alloc] initWithContentsOfFile:path];
}


UIImage *bit_imageWithContentsOfResolutionIndependentFile(NSString *path) {
#ifndef __clang_analyzer__
  // clang alayzer in 4.2b3 thinks here's a leak, which is not the case.
  return [bit_newWithContentsOfResolutionIndependentFile(path) autorelease];
#endif
}


UIImage *bit_imageNamed(NSString *imageName, NSString *bundleName) {
  NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
  NSString *bundlePath = [resourcePath stringByAppendingPathComponent:bundleName];
  NSString *imagePath = [bundlePath stringByAppendingPathComponent:imageName];
  return bit_imageWithContentsOfResolutionIndependentFile(imagePath);
}



// Creates a copy of this image with rounded corners
// If borderSize is non-zero, a transparent border of the given size will also be added
// Original author: Björn Sållarp. Used with permission. See: http://blog.sallarp.com/iphone-uiimage-round-corners/
UIImage *bit_roundedCornerImage(UIImage *inputImage, NSInteger cornerSize, NSInteger borderSize) {
  // If the image does not have an alpha layer, add one
  
  UIImage *roundedImage = nil;
  UIGraphicsBeginImageContextWithOptions(inputImage.size, NO, 0.0); // 0.0 for scale means "correct scale for device's main screen".
  CGImageRef sourceImg = CGImageCreateWithImageInRect([inputImage CGImage], CGRectMake(0, 0, inputImage.size.width * inputImage.scale, inputImage.size.height * inputImage.scale)); // cropping happens here.
  
  // Create a clipping path with rounded corners
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextBeginPath(context);
  bit_addRoundedRectToPath(CGRectMake(borderSize, borderSize, inputImage.size.width - borderSize * 2, inputImage.size.height - borderSize * 2), context, cornerSize, cornerSize);
  CGContextClosePath(context);
  CGContextClip(context);
  
  roundedImage = [UIImage imageWithCGImage:sourceImg scale:0.0 orientation:inputImage.imageOrientation]; // create cropped UIImage.
  [roundedImage drawInRect:CGRectMake(0, 0, inputImage.size.width, inputImage.size.height)]; // the actual scaling happens here, and orientation is taken care of automatically.
  CGImageRelease(sourceImg);
  roundedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  if (!roundedImage) {
    // Try older method.
    UIImage *image = bit_imageWithAlpha(inputImage);
    
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
    bit_addRoundedRectToPath(CGRectMake(borderSize, borderSize, image.size.width - borderSize * 2, image.size.height - borderSize * 2), context, cornerSize, cornerSize);
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
