//
//  ASGraphicsContext.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASGraphicsContext.h"
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <UIKit/UIGraphics.h>
#import <UIKit/UIImage.h>
#import <stdatomic.h>
#import <objc/runtime.h>

#pragma mark - Feature Gating

// Two flags that we atomically manipulate to control the feature.
typedef NS_OPTIONS(uint, ASNoCopyFlags) {
  ASNoCopyEnabled = 1 << 0,
  ASNoCopyBlocked = 1 << 1
};
static atomic_uint __noCopyFlags;

// Check if it's blocked, and set the enabled flag if not.
extern BOOL ASEnableNoCopyRendering()
{
  ASNoCopyFlags expectedFlags = 0;
  BOOL enabled = atomic_compare_exchange_strong(&__noCopyFlags, &expectedFlags, ASNoCopyEnabled);
  ASDisplayNodeCAssert(enabled, @"Can't enable no-copy rendering after first render started.");
  return enabled;
}

// Check if it's enabled and set the "blocked" flag either way.
static BOOL ASNoCopyRenderingBlockAndCheckEnabled() {
  ASNoCopyFlags oldFlags = atomic_fetch_or(&__noCopyFlags, ASNoCopyBlocked);
  return (oldFlags & ASNoCopyEnabled) != 0;
}

/**
 * Our version of the private CGBitmapGetAlignedBytesPerRow function.
 *
 * In both 32-bit and 64-bit, this function rounds up to nearest multiple of 32
 * in iOS 9, 10, and 11. We'll try to catch if this ever changes by asserting that
 * the bytes-per-row for a 1x1 context from the system is 32.
 */
static size_t ASGraphicsGetAlignedBytesPerRow(size_t baseValue) {
  // Add 31 then zero out low 5 bits.
  return (baseValue + 31) & ~0x1F;
}

/**
 * A key used to associate CGContextRef -> NSMutableData, nonatomic retain.
 *
 * That way the data will be released when the context dies. If they pull an image,
 * we will retain the data object (in a CGDataProvider) before releasing the context.
 */
static UInt8 __contextDataAssociationKey;

#pragma mark - Graphics Contexts

extern void ASGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
{
  if (!ASNoCopyRenderingBlockAndCheckEnabled()) {
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
    return;
  }
  
  // We use "reference contexts" to get device-specific options that UIKit
  // uses.
  static dispatch_once_t onceToken;
  static CGContextRef refCtxOpaque;
  static CGContextRef refCtxTransparent;
  dispatch_once(&onceToken, ^{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 1);
    refCtxOpaque = CGContextRetain(UIGraphicsGetCurrentContext());
    ASDisplayNodeCAssert(CGBitmapContextGetBytesPerRow(refCtxOpaque) == 32, @"Expected bytes per row to be aligned to 32. Has CGBitmapGetAlignedBytesPerRow implementation changed?");
    UIGraphicsEndImageContext();
    
    // Make transparent ref context.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), NO, 1);
    refCtxTransparent = CGContextRetain(UIGraphicsGetCurrentContext());
    UIGraphicsEndImageContext();
  });
  
  // These options are taken from UIGraphicsBeginImageContext.
  CGContextRef refCtx = opaque ? refCtxOpaque : refCtxTransparent;
  CGBitmapInfo bitmapInfo = CGBitmapContextGetBitmapInfo(refCtx);
  
  if (scale == 0) {
    scale = ASScreenScale();
  }
  size_t intWidth = (size_t)ceil(size.width * scale);
  size_t intHeight = (size_t)ceil(size.height * scale);
  size_t bitsPerComponent = CGBitmapContextGetBitsPerComponent(refCtx);
  size_t bytesPerRow = CGBitmapContextGetBitsPerPixel(refCtx) * intWidth / 8;
  bytesPerRow = ASGraphicsGetAlignedBytesPerRow(bytesPerRow);
  size_t bufferSize = bytesPerRow * intHeight;
  CGColorSpaceRef colorspace = CGBitmapContextGetColorSpace(refCtx);

  // We create our own buffer, and wrap the context around that. This way we can prevent
  // the copy that usually gets made when you form a CGImage from the context.
  NSMutableData *data = [[NSMutableData alloc] initWithLength:bufferSize];
  CGContextRef context = CGBitmapContextCreate(data.mutableBytes, intWidth, intHeight, bitsPerComponent, bytesPerRow, colorspace, bitmapInfo);
  
  // Transfer ownership of the data to the context. So that if the context
  // is destroyed before we create an image from it, the data will be released.
  objc_setAssociatedObject((__bridge id)context, &__contextDataAssociationKey, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  
  // Set the CTM to account for iOS orientation & specified scale.
  // If only we could use CGContextSetBaseCTM. It doesn't
  // seem like there are any consequences for our use case
  // but we'll be on the look out. The internet hinted that it
  // affects shadowing but I tested and shadowing works.
  CGContextTranslateCTM(context, 0, intHeight);
  CGContextScaleCTM(context, scale, -scale);
  
  // Save the state so we can restore it and recover our scale in GetImageAndEnd
  CGContextSaveGState(context);
  
  // Transfer context ownership to the UIKit stack.
  UIGraphicsPushContext(context);
  CGContextRelease(context);
}

extern UIImage * _Nullable ASGraphicsGetImageAndEndCurrentContext()
{
  if (!ASNoCopyRenderingBlockAndCheckEnabled()) {
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
  }
  
  // Pop the context and make sure we have one.
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context == NULL) {
    ASDisplayNodeCFailAssert(@"Can't end image context without having begun one.");
    return nil;
  }
  
  // Read the device-specific ICC-based color space to use for the image.
  // For DeviceRGB contexts (e.g. UIGraphics), CGBitmapContextCreateImage
  // generates an image in a device-specific color space (for wide color support).
  // We replicate that behavior, even though at this time CA does not
  // require the image to be in this space. Plain DeviceRGB images seem
  // to be treated exactly the same, but better safe than sorry.
  static CGColorSpaceRef imageColorSpace;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), YES, 0);
    UIImage *refImage = UIGraphicsGetImageFromCurrentImageContext();
    imageColorSpace = CGColorSpaceRetain(CGImageGetColorSpace(refImage.CGImage));
    ASDisplayNodeCAssertNotNil(imageColorSpace, nil);
    UIGraphicsEndImageContext();
  });
  
  // Retrieve our data and wrap it in a CGDataProvider.
  // Don't worry, the provider doesn't copy the data – it just retains it.
  NSMutableData *data = objc_getAssociatedObject((__bridge id)context, &__contextDataAssociationKey);
  ASDisplayNodeCAssertNotNil(data, nil);
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  
  // Create the CGImage. Options taken from CGBitmapContextCreateImage.
  CGImageRef cgImg = CGImageCreate(CGBitmapContextGetWidth(context), CGBitmapContextGetHeight(context), CGBitmapContextGetBitsPerComponent(context), CGBitmapContextGetBitsPerPixel(context), CGBitmapContextGetBytesPerRow(context), imageColorSpace, CGBitmapContextGetBitmapInfo(context), provider, NULL, true, kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  
  // We saved our GState right after setting the CTM so that we could restore it
  // here and get the original scale back.
  CGContextRestoreGState(context);
  CGFloat scale = CGContextGetCTM(context).a;
  
  // Note: popping from the UIKit stack will probably destroy the context.
  context = NULL;
  UIGraphicsPopContext();
  
  UIImage *result = [[UIImage alloc] initWithCGImage:cgImg scale:scale orientation:UIImageOrientationUp];
  CGImageRelease(cgImg);
  return result;
}

extern void ASGraphicsEndImageContext()
{
  if (!ASNoCopyRenderingBlockAndCheckEnabled()) {
    UIGraphicsEndImageContext();
    return;
  }
  
  UIGraphicsPopContext();
}
