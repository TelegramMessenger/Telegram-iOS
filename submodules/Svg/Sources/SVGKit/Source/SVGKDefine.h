/**
 SVGKDefine.h
 
 SVGKDefine define some common macro used for public header or private header.
 Currently here are some platform define to allow us to simply write code cross Apple's platforms.
 */

#ifndef SVGKDefine_h
#define SVGKDefine_h

#include "TargetConditionals.h"

// Apple's defines from TargetConditionals.h are a bit weird.
// Seems like TARGET_OS_MAC is always defined (on all platforms).
// To determine if we are running on OSX, we can only rely on TARGET_OS_IPHONE=0 and all the other platforms
#if !TARGET_OS_IPHONE && !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
#define SVGKIT_MAC 1
#else
#define SVGKIT_MAC 0
#endif

// iOS and tvOS are very similar, UIKit exists on both platforms
// Note: watchOS also has UIKit, but it's very limited
#if TARGET_OS_IOS || TARGET_OS_TV
#define SVGKIT_UIKIT 1
#else
#define SVGKIT_UIKIT 0
#endif

#if TARGET_OS_IOS
#define SVGKIT_IOS 1
#else
#define SVGKIT_IOS 0
#endif

#if TARGET_OS_TV
#define SVGKIT_TV 1
#else
#define SVGKIT_TV 0
#endif

#if TARGET_OS_WATCH
#define SVGKIT_WATCH 1
#else
#define SVGKIT_WATCH 0
#endif

#if SVGKIT_MAC
#ifndef UIImage
#define UIImage NSImage
#endif
#ifndef UIImageView
#define UIImageView NSImageView
#endif
#ifndef UIView
#define UIView NSView
#endif
#ifndef UIColor
#define UIColor NSColor
#endif
#ifndef UIFont
#define UIFont NSFont
#endif
#endif

#if SVGKIT_MAC
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#endif /* SVGKDefine_h */
