//
//  ASImageNode+CGExtras.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

/**
 @abstract Decides how to scale and crop an image to fit in the provided size, while not wasting memory by upscaling images
 @param sourceImageSize The size of the encoded image.
 @param boundsSize The bounds in which the image will be displayed.
 @param contentMode The mode that defines how image will be scaled and cropped to fit. Supported values are UIViewContentModeScaleToAspectFill and UIViewContentModeScaleToAspectFit.
 @param cropRect A rectangle that is to be featured by the cropped image. The rectangle is specified as a "unit rectangle," using fractions of the source image's width and height, e.g. CGRectMake(0.5, 0, 0.5, 1.0) will feature the full right half a photo. If the cropRect is empty, the contentMode will be used to determine the drawRect's size, and only the cropRect's origin will be used for positioning.
 @param forceUpscaling A boolean that indicates you would *not* like the backing size to be downscaled if the image is smaller than the destination size. Setting this to YES will result in higher memory usage when images are smaller than their destination.
 @param forcedSize A CGSize, that if non-CGSizeZero, indicates that the backing size should be forcedSize and not calculated based on boundsSize.
 @discussion If the image is smaller than the size and UIViewContentModeScaleToAspectFill is specified, we suggest the input size so it will be efficiently upscaled on the GPU by the displaying layer at composite time.
 */
AS_EXTERN void ASCroppedImageBackingSizeAndDrawRectInBounds(CGSize sourceImageSize,
                                                         CGSize boundsSize,
                                                         UIViewContentMode contentMode,
                                                         CGRect cropRect,
                                                         BOOL forceUpscaling,
                                                         CGSize forcedSize,
                                                         CGSize *outBackingSize,
                                                         CGRect *outDrawRect
                                                         );
