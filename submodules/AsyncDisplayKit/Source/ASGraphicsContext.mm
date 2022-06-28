//
//  ASGraphicsContext.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASGraphicsContext.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASAvailability.h>


#if AS_AT_LEAST_IOS13
#define ASPerformBlockWithTraitCollection(work, traitCollection) \
    if (@available(iOS 13.0, tvOS 13.0, *)) { \
      UITraitCollection *uiTraitCollection = ASPrimitiveTraitCollectionToUITraitCollection(traitCollection); \
      [uiTraitCollection performAsCurrentTraitCollection:^{ \
        work(); \
      }];\
    } else { \
      work(); \
    }
#else
#define ASPerformBlockWithTraitCollection(work, traitCollection) work();
#endif


NS_AVAILABLE_IOS(10)
NS_INLINE void ASConfigureExtendedRange(UIGraphicsImageRendererFormat *format)
{
  if (AS_AVAILABLE_IOS_TVOS(12, 12)) {
    // nop. We always use automatic range on iOS >= 12.
  } else {
    // Currently we never do wide color. One day we could pipe this information through from the ASImageNode if it was worth it.
    format.prefersExtendedRange = NO;
  }
}

UIImage *ASGraphicsCreateImageWithOptions(CGSize size, BOOL opaque, CGFloat scale, UIImage *sourceImage,
                                          asdisplaynode_iscancelled_block_t NS_NOESCAPE isCancelled,
                                          void (^NS_NOESCAPE work)())
{
  return ASGraphicsCreateImage(ASPrimitiveTraitCollectionMakeDefault(), size, opaque, scale, sourceImage, isCancelled, work);
}

UIImage *ASGraphicsCreateImage(ASPrimitiveTraitCollection traitCollection, CGSize size, BOOL opaque, CGFloat scale, UIImage * sourceImage, asdisplaynode_iscancelled_block_t NS_NOESCAPE isCancelled, void (NS_NOESCAPE ^work)()) {
    if (@available(iOS 10.0, *)) {
    if (true /*ASActivateExperimentalFeature(ASExperimentalDrawingGlobal)*/) {
      // If they used default scale, reuse one of two preferred formats.
      static UIGraphicsImageRendererFormat *defaultFormat;
      static UIGraphicsImageRendererFormat *opaqueFormat;
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
          defaultFormat = [UIGraphicsImageRendererFormat preferredFormat];
          opaqueFormat = [UIGraphicsImageRendererFormat preferredFormat];
        } else {
          defaultFormat = [UIGraphicsImageRendererFormat defaultFormat];
          opaqueFormat = [UIGraphicsImageRendererFormat defaultFormat];
        }
        opaqueFormat.opaque = YES;
        ASConfigureExtendedRange(defaultFormat);
        ASConfigureExtendedRange(opaqueFormat);
      });

      UIGraphicsImageRendererFormat *format;
      if (sourceImage) {
        if (sourceImage.renderingMode == UIImageRenderingModeAlwaysTemplate) {
          // Template images will be black and transparent, so if we use
          // sourceImage.imageRenderFormat it will assume a grayscale color space.
          // This is not good because a template image should be able to tint to any color,
          // so we'll just use the default here.
          if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
            format = [UIGraphicsImageRendererFormat preferredFormat];
          } else {
            format = [UIGraphicsImageRendererFormat defaultFormat];
          }
        } else {
          format = sourceImage.imageRendererFormat;
        }
        // We only want the private bits (color space and bits per component) from the image.
        // We have our own ideas about opacity and scale.
        format.opaque = opaque;
        format.scale = scale;
      } else if (scale == 0 || scale == ASScreenScale()) {
        format = opaque ? opaqueFormat : defaultFormat;
      } else {
        if (AS_AVAILABLE_IOS_TVOS(11, 11)) {
          format = [UIGraphicsImageRendererFormat preferredFormat];
        } else {
          format = [UIGraphicsImageRendererFormat defaultFormat];
        }
        if (opaque) format.opaque = YES;
        format.scale = scale;
        ASConfigureExtendedRange(format);
      }
      
      // Avoid using the imageWithActions: method because it does not support cancellation at the
      // last moment i.e. before actually creating the resulting image.
      __block UIImage *image;
      NSError *error;
      [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format]
          runDrawingActions:^(UIGraphicsImageRendererContext *rendererContext) {
            ASDisplayNodeCAssert(UIGraphicsGetCurrentContext(), @"Should have a context!");
            ASPerformBlockWithTraitCollection(work, traitCollection);
          }
          completionActions:^(UIGraphicsImageRendererContext *rendererContext) {
            if (isCancelled == nil || !isCancelled()) {
              image = rendererContext.currentImage;
            }
          }
          error:&error];
      if (error) {
        NSCAssert(NO, @"Error drawing: %@", error);
      }
      return image;
    }
  }

  // Bad OS or experiment flag. Use UIGraphics* API.
  UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
  ASPerformBlockWithTraitCollection(work, traitCollection)
  UIImage *image = nil;
  if (isCancelled == nil || !isCancelled()) {
    image = UIGraphicsGetImageFromCurrentImageContext();
  }
  UIGraphicsEndImageContext();
  return image;
}

UIImage *ASGraphicsCreateImageWithTraitCollectionAndOptions(ASPrimitiveTraitCollection traitCollection, CGSize size, BOOL opaque, CGFloat scale, UIImage * sourceImage, void (NS_NOESCAPE ^work)()) {
  return ASGraphicsCreateImage(traitCollection, size, opaque, scale, sourceImage, nil, work);
}
