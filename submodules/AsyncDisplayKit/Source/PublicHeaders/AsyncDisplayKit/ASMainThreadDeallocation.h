//
//  ASMainThreadDeallocation.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (ASMainThreadIvarTeardown)

/**
 * Call this from -dealloc to schedule this instance's
 * ivars for main thread deallocation as needed.
 *
 * This method includes a check for whether it's on the main thread,
 * and it will do nothing in that case.
 */
- (void)scheduleIvarsForMainThreadDeallocation;

@end

@interface NSObject (ASNeedsMainThreadDeallocation)

/**
 * Override this property to indicate that instances of this
 * class need to be deallocated on the main thread.
 * You do not access this property yourself.
 *
 * The NSObject implementation returns YES if the class name has
 * a prefix UI, AV, or CA. This property is also overridden to
 * return fixed values for other common classes, such as UIImage,
 * UIGestureRecognizer, and UIResponder.
 */
@property (class, readonly) BOOL needsMainThreadDeallocation;

@end

@interface NSProxy (ASNeedsMainThreadDeallocation)

/**
 * Override this property to indicate that instances of this
 * class need to be deallocated on the main thread.
 * You do not access this property yourself.
 *
 * The NSProxy implementation returns NO because
 * proxies almost always hold weak references.
 */
@property (class, readonly) BOOL needsMainThreadDeallocation;

@end

NS_ASSUME_NONNULL_END
