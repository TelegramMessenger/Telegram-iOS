#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "BITHockeyHelper.h"
/*
 * Workaround for exporting symbols from category object files.
 */
extern NSString *BITHockeyHelperApplicationCategory;

/**
 *  App states
 */
typedef NS_ENUM(NSInteger, BITApplicationState) {
  
  /**
   * Application is active.
   */
  BITApplicationStateActive = UIApplicationStateActive,
  
  /**
   * Application is inactive.
   */
  BITApplicationStateInactive = UIApplicationStateInactive,
  
  /**
   * Application is in background.
   */
  BITApplicationStateBackground = UIApplicationStateBackground,
  
  /**
   * Application state can't be determined.
   */
  BITApplicationStateUnknown
};

@interface BITHockeyHelper (Application)

/**
 * Get current application state.
 *
 * @return Current state of the application or BITApplicationStateUnknown while the state can't be determined.
 *
 * @discussion The application state may not be available everywhere. Application extensions doesn't have it for instance,
 * in that case the BITApplicationStateUnknown value is returned.
 */
+ (BITApplicationState)applicationState;

@end
