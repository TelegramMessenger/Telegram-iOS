//
//  ASGraphicsContext.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <CoreGraphics/CoreGraphics.h>

@class UIImage;

/**
 * Functions for creating one-shot graphics contexts that do not have to copy
 * their contents when an image is generated from them. This is efficient
 * for our use, since we do not reuse graphics contexts.
 *
 * The API mirrors the UIGraphics API, with the exception that forming an image
 * ends the context as well.
 *
 * Note: You must not mix-and-match between ASGraphics* and UIGraphics* functions
 * within the same drawing operation.
 */

NS_ASSUME_NONNULL_BEGIN

/**
 * Creates a one-shot context.
 *
 * Behavior is the same as UIGraphicsBeginImageContextWithOptions.
 */
AS_EXTERN void ASGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);

/**
 * Generates and image and ends the current one-shot context.
 *
 * Behavior is the same as UIGraphicsGetImageFromCurrentImageContext followed by UIGraphicsEndImageContext.
 */
AS_EXTERN UIImage * _Nullable ASGraphicsGetImageAndEndCurrentContext(void) NS_RETURNS_RETAINED;

/**
 * Call this if you want to end the current context without making an image.
 *
 * Behavior is the same as UIGraphicsEndImageContext.
 */
AS_EXTERN void ASGraphicsEndImageContext(void);

NS_ASSUME_NONNULL_END
