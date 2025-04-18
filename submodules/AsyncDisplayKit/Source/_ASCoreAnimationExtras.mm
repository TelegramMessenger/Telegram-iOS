//
//  _ASCoreAnimationExtras.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASAssert.h>

void ASDisplayNodeSetupLayerContentsWithResizableImage(CALayer *layer, UIImage *image)
{
  ASDisplayNodeSetResizableContents(layer, image);
}

void ASDisplayNodeSetResizableContents(id<ASResizableContents> obj, UIImage *image)
{
  // FIXME (https://github.com/TextureGroup/Texture/issues/1046): This method does not currently handle UIImageResizingModeTile, which is the default.
  // See also https://developer.apple.com/documentation/uikit/uiimage/1624157-resizingmode?language=objc
  // I'm not sure of a way to use CALayer directly to perform such tiling on the GPU, though the stretch is handled by the GPU,
  // and CALayer.h documents the fact that contentsCenter is used to stretch the pixels.

  if (image) {
    ASDisplayNodeCAssert(image.resizingMode == UIImageResizingModeStretch || UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero),
                         @"Image insets must be all-zero or resizingMode has to be UIImageResizingModeStretch. XCode assets default value is UIImageResizingModeTile which is not supported by Texture because of GPU-accelerated CALayer features.");
    
    // Image may not actually be stretchable in one or both dimensions; this is handled
    obj.contents = (id)[image CGImage];
    obj.contentsScale = [image scale];
    obj.rasterizationScale = [image scale];
    CGSize imageSize = [image size];

    UIEdgeInsets insets = [image capInsets];

    // These are lifted from what UIImageView does by experimentation. Without these exact values, the stretching is slightly off.
    const CGFloat halfPixelFudge = 0.49f;
    const CGFloat otherPixelFudge = 0.02f;
    // Convert to unit coordinates for the contentsCenter property.
    CGRect contentsCenter = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    if (insets.left > 0 || insets.right > 0) {
      contentsCenter.origin.x = ((insets.left + halfPixelFudge) / imageSize.width);
      contentsCenter.size.width = (imageSize.width - (insets.left + insets.right + 1.f) + otherPixelFudge) / imageSize.width;
    }
    if (insets.top > 0 || insets.bottom > 0) {
      contentsCenter.origin.y = ((insets.top + halfPixelFudge) / imageSize.height);
      contentsCenter.size.height = (imageSize.height - (insets.top + insets.bottom + 1.f) + otherPixelFudge) / imageSize.height;
    }
    obj.contentsGravity = kCAGravityResize;
    obj.contentsCenter = contentsCenter;

  } else {
    obj.contents = nil;
  }
}


struct _UIContentModeStringLUTEntry {
  UIViewContentMode contentMode;
  NSString *const string;
};

static const _UIContentModeStringLUTEntry *UIContentModeCAGravityLUT(size_t *count)
{
  // Initialize this in a function (instead of at file level) to avoid
  // startup initialization time.
  static const _UIContentModeStringLUTEntry sUIContentModeCAGravityLUT[] = {
    {UIViewContentModeScaleToFill,     kCAGravityResize},
    {UIViewContentModeScaleAspectFit,  kCAGravityResizeAspect},
    {UIViewContentModeScaleAspectFill, kCAGravityResizeAspectFill},
    {UIViewContentModeCenter,          kCAGravityCenter},
    {UIViewContentModeTop,             kCAGravityBottom},
    {UIViewContentModeBottom,          kCAGravityTop},
    {UIViewContentModeLeft,            kCAGravityLeft},
    {UIViewContentModeRight,           kCAGravityRight},
    {UIViewContentModeTopLeft,         kCAGravityBottomLeft},
    {UIViewContentModeTopRight,        kCAGravityBottomRight},
    {UIViewContentModeBottomLeft,      kCAGravityTopLeft},
    {UIViewContentModeBottomRight,     kCAGravityTopRight},
  };
  *count = sizeof(sUIContentModeCAGravityLUT) / sizeof(sUIContentModeCAGravityLUT[0]);
  return sUIContentModeCAGravityLUT;
}

static const _UIContentModeStringLUTEntry *UIContentModeDescriptionLUT(size_t *count)
{
  // Initialize this in a function (instead of at file level) to avoid
  // startup initialization time.
  static const _UIContentModeStringLUTEntry sUIContentModeDescriptionLUT[] = {
    {UIViewContentModeScaleToFill,     @"scaleToFill"},
    {UIViewContentModeScaleAspectFit,  @"aspectFit"},
    {UIViewContentModeScaleAspectFill, @"aspectFill"},
    {UIViewContentModeRedraw,          @"redraw"},
    {UIViewContentModeCenter,          @"center"},
    {UIViewContentModeTop,             @"top"},
    {UIViewContentModeBottom,          @"bottom"},
    {UIViewContentModeLeft,            @"left"},
    {UIViewContentModeRight,           @"right"},
    {UIViewContentModeTopLeft,         @"topLeft"},
    {UIViewContentModeTopRight,        @"topRight"},
    {UIViewContentModeBottomLeft,      @"bottomLeft"},
    {UIViewContentModeBottomRight,     @"bottomRight"},
  };
  *count = sizeof(sUIContentModeDescriptionLUT) / sizeof(sUIContentModeDescriptionLUT[0]);
  return sUIContentModeDescriptionLUT;
}

NSString *ASDisplayNodeNSStringFromUIContentMode(UIViewContentMode contentMode)
{
  size_t lutSize;
  const _UIContentModeStringLUTEntry *lut = UIContentModeDescriptionLUT(&lutSize);
  for (size_t i = 0; i < lutSize; ++i) {
    if (lut[i].contentMode == contentMode) {
      return lut[i].string;
    }
  }
  return [NSString stringWithFormat:@"%d", (int)contentMode];
}

UIViewContentMode ASDisplayNodeUIContentModeFromNSString(NSString *string)
{
  size_t lutSize;
  const _UIContentModeStringLUTEntry *lut = UIContentModeDescriptionLUT(&lutSize);
  for (size_t i = 0; i < lutSize; ++i) {
    if (ASObjectIsEqual(lut[i].string, string)) {
      return lut[i].contentMode;
    }
  }
  return UIViewContentModeScaleToFill;
}

NSString *const ASDisplayNodeCAContentsGravityFromUIContentMode(UIViewContentMode contentMode)
{
  size_t lutSize;
  const _UIContentModeStringLUTEntry *lut = UIContentModeCAGravityLUT(&lutSize);
  for (size_t i = 0; i < lutSize; ++i) {
    if (lut[i].contentMode == contentMode) {
      return lut[i].string;
    }
  }
  ASDisplayNodeCAssert(contentMode == UIViewContentModeRedraw, @"Encountered an unknown contentMode %ld. Is this a new version of iOS?", (long)contentMode);
  // Redraw is ok to return nil.
  return nil;
}

#define ContentModeCacheSize 10
UIViewContentMode ASDisplayNodeUIContentModeFromCAContentsGravity(NSString *const contentsGravity)
{
  static int currentCacheIndex = 0;
  static NSMutableArray *cachedStrings = [NSMutableArray arrayWithCapacity:ContentModeCacheSize];
  static UIViewContentMode cachedModes[ContentModeCacheSize] = {};
  
  NSInteger foundCacheIndex = [cachedStrings indexOfObjectIdenticalTo:contentsGravity];
  if (foundCacheIndex != NSNotFound && foundCacheIndex < ContentModeCacheSize) {
    return cachedModes[foundCacheIndex];
  }
  
    size_t lutSize;
    const _UIContentModeStringLUTEntry *lut = UIContentModeCAGravityLUT(&lutSize);
    for (size_t i = 0; i < lutSize; ++i) {
    if (ASObjectIsEqual(lut[i].string, contentsGravity)) {
      UIViewContentMode foundContentMode = lut[i].contentMode;
      
      if (currentCacheIndex < ContentModeCacheSize) {
        // Cache the input value.  This is almost always a different pointer than in our LUT and will frequently
        // be the same value for an overwhelming majority of inputs.
        [cachedStrings addObject:contentsGravity];
        cachedModes[currentCacheIndex] = foundContentMode;
        currentCacheIndex++;
      }
      
      return foundContentMode;
    }
  }

  ASDisplayNodeCAssert(contentsGravity, @"Encountered an unknown contentsGravity \"%@\". Is this a new version of iOS?", contentsGravity);
  ASDisplayNodeCAssert(!contentsGravity, @"You passed nil to ASDisplayNodeUIContentModeFromCAContentsGravity. We're falling back to resize, but this is probably a bug.");
  // If asserts disabled, fall back to this
  return UIViewContentModeScaleToFill;
}

BOOL ASDisplayNodeLayerHasAnimations(CALayer *layer)
{
  return (layer.animationKeys.count != 0);
}
