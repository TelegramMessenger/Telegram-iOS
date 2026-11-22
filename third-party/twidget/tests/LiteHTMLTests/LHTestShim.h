// Telegram-authored, not part of twidget. Force-included into every LiteHTMLTests source by the BUILD
// (`-include`), so the vendored tests stay as upstream wrote them apart from their guards.
//
// twidget's tests are macOS tests: they read rects and sizes back with AppKit's NSValue and NSGeometry
// spellings. On iOS those are spelled here, over CoreGraphics. The macOS build sees nothing.
#pragma once

#include <TargetConditionals.h>

#if !TARGET_OS_OSX
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef CGRect NSRect;
typedef CGSize NSSize;

static inline NSRect NSRectFromCGRect(CGRect rect)
{
    return rect;
}

static inline NSSize NSSizeFromCGSize(CGSize size)
{
    return size;
}

// NSStringFromRect's and NSStringFromSize's format.
static inline NSString* NSStringFromRect(NSRect rect)
{
    return [NSString stringWithFormat:@"{{%g, %g}, {%g, %g}}", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height];
}

static inline NSString* NSStringFromSize(NSSize size)
{
    return [NSString stringWithFormat:@"{%g, %g}", size.width, size.height];
}

// Declared only. iOS Foundation implements both without declaring them, and they read the values the
// vendored LHDocument boxes on iOS ([NSValue valueWithBytes:objCType:@encode(CGRect)], see VENDOR.md),
// as measured in the iOS 26.5 and 27.0 simulators. Defining them in a category would replace
// Foundation's own methods for the whole process.
@interface NSValue (LHTestShimGeometry)
@property (nonatomic, readonly) NSRect rectValue;
@property (nonatomic, readonly) NSSize sizeValue;
@end

// The corpus upstream's tests read from `__FILE__/../../Examples/chats`: a test bundle has no source
// tree, so the BUILD bundles twidget's Examples/chats as a structured resource of the test bundle.
static inline NSString* LHTestExamplesChatsDirectory(Class testClass)
{
    return [[NSBundle bundleForClass:testClass].resourcePath stringByAppendingPathComponent:@"Examples/chats"];
}
#endif
