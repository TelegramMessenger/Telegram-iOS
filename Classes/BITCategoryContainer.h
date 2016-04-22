#import <Foundation/Foundation.h>
#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

@interface BITCategoryContainer : NSObject

+ (void)activateCategory;

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
