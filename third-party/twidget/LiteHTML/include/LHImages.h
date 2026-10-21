#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
#else
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface LHImages : NSObject

#if TARGET_OS_OSX
+ (void)registerImage:(NSImage *)image name:(NSString *)name;
+ (void)setProvider:(nullable NSImage *_Nullable (^)(NSString *url))provider;
@property (class, readonly, nullable) NSImage *_Nullable (^provider)(NSString *url);
#endif
+ (void)forgetImageWithURL:(NSString *)url;
+ (nullable CGImageRef)copyImageForURL:(NSString *)url CF_RETURNS_RETAINED NS_SWIFT_NAME(copyImage(forURL:));
+ (void)prefetchURLs:(NSArray<NSString *> *)urls completion:(nullable void (^)(void))completion;
#if TARGET_OS_OSX
+ (void)registerDemoImages;
#endif
@property (class, nonatomic) BOOL portableSymbols;

@end

NS_ASSUME_NONNULL_END
