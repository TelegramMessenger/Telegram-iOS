#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//! Project version number for AppBundle.
FOUNDATION_EXPORT double AppBundleVersionNumber;

//! Project version string for AppBundle.
FOUNDATION_EXPORT const unsigned char AppBundleVersionString[];

NSBundle * _Nonnull getAppBundle(void);

@interface UIImage (AppBundle)

- (instancetype _Nullable)initWithBundleImageName:(NSString * _Nonnull)bundleImageName;

@end
