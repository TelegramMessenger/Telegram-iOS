#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NSBundle * _Nonnull getAppBundle(void);

@interface UIImage (AppBundle)

- (instancetype _Nullable)initWithBundleImageName:(NSString * _Nonnull)bundleImageName;

@end
