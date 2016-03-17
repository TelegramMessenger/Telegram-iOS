#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import <Foundation/Foundation.h>
#import "BITHockeyBaseManager.h"

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

@interface BITMetricsManager : BITHockeyBaseManager

@property (nonatomic, assign) BOOL disabled;

- (void)trackEventWithName:(NSString *)eventName;

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
