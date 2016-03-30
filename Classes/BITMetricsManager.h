#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import <Foundation/Foundation.h>
#import "BITHockeyBaseManager.h"

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

/**
 The metrics module.
 
 This is the HockeySDK module that handles users, sessions and events tracking.
 
 Unless disabled, this module automatically tracks users and session of your app to give you
 better insights about how your app is being used.
 Users are tracked in a completely anonymous way without collecting any personally identifiable
 information.
 
 Before starting to track events, ask yourself the questions that you want to get answers to.
 For instance, you might be interested in business, performance/quality or user experience aspects.
 Name your events in a meaningful way and keep in mind that you will use these names 
 when searching for events in the HockeyApp web portal.
 
 It is your reponsibility to not collect personal information as part of the events tracking or get
 prior consent from your users as necessary.
 */
@interface BITMetricsManager : BITHockeyBaseManager

/**
 *  A property indicating whether the BITMetricsManager instance is disabled.
 */
@property (nonatomic, assign) BOOL disabled;

/**
 *  This method allows to track an event that happened in your app.
 *  Remember to choose meaningful event names to have the best experience when diagnosing your app
 *  in the HockeyApp web portal.
 *
 *  @param eventName The event's name as a string.
 */
- (void)trackEventWithName:(NSString *)eventName;

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
