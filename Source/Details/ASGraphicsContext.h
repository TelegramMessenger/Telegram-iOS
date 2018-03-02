//
//  ASGraphicsContext.h
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
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
ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 * Call this to enable the experimental no-copy rendering.
 *
 * Returns YES if it was enabled, or NO + assert if it's too late because
 * rendering has already started. In practice it's fine to call this
 * during -didFinishLaunchingWithOptions:.
 */
extern BOOL ASEnableNoCopyRendering(void);

/**
 * Creates a one-shot context.
 *
 * Behavior is the same as UIGraphicsBeginImageContextWithOptions.
 */
extern void ASGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);

/**
 * Generates and image and ends the current one-shot context.
 *
 * Behavior is the same as UIGraphicsGetImageFromCurrentImageContext followed by UIGraphicsEndImageContext.
 */
extern UIImage * _Nullable ASGraphicsGetImageAndEndCurrentContext(void);

/**
 * Call this if you want to end the current context without making an image.
 *
 * Behavior is the same as UIGraphicsEndImageContext.
 */
extern void ASGraphicsEndImageContext(void);

ASDISPLAYNODE_EXTERN_C_END
NS_ASSUME_NONNULL_END
