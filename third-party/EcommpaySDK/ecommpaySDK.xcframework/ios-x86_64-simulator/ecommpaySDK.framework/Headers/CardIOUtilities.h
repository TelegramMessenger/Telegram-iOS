//
//  CardIOUtilities.h
//  Version 5.4.1
//
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CardIOUtilities : NSObject

/// Please send the output of this method with any technical support requests.
/// @return Human-readable version of this library.
+ (NSString *)libraryVersion;

/// Determine whether this device supports camera-based card scanning, considering
/// factors such as hardware support and OS version.
///
/// card.io automatically provides manual entry of cards as a fallback,
/// so it is not typically necessary for your app to check this.
///
/// @return YES iff the user's device supports camera-based card scanning.
+ (BOOL)canReadCardWithCamera;

/// The preload method prepares card.io to launch faster. Calling preload is optional but suggested.
/// On an iPhone 5S, for example, preloading makes card.io launch ~400ms faster.
/// The best time to call preload is when displaying a view from which card.io might be launched;
/// e.g., inside your view controller's viewWillAppear: method.
/// preload works in the background; the call to preload returns immediately.
+ (void)preload;

/// Returns a doubly Gaussian-blurred screenshot, intended for screenshots when backgrounding.
/// @return Blurred screenshot.
+ (UIImageView *)blurredScreenImageView;

@end

/// Methods with names that do not conflict with Apple's private APIs.
@interface CardIOUtilities (NonConflictingAPINames)

/// Please send the output of this method with any technical support requests.
/// @return Human-readable version of this library.
+ (NSString *)cardIOLibraryVersion;

/// The preload method prepares card.io to launch faster. Calling preload is optional but suggested.
/// On an iPhone 5S, for example, preloading makes card.io launch ~400ms faster.
/// The best time to call preload is when displaying a view from which card.io might be launched;
/// e.g., inside your view controller's viewWillAppear: method.
/// preload works in the background; the call to preload returns immediately.
+ (void)preloadCardIO;

@end

