#import <Foundation/Foundation.h>
#import "HockeySDKPrivate.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

NS_ASSUME_NONNULL_BEGIN
/**
 *  Enum for representing different network statuses.
 */
typedef NS_ENUM(NSInteger, BITReachabilityType){
  /**
   *  Type used if no connection is available.
   */
  BITReachabilityTypeNone,
  /**
   *  Type used for WiFi connnection.
   */
  BITReachabilityTypeWIFI,
  /**
   *  Type for Edge, 3G, LTE etc.
   */
  BITReachabilityTypeWWAN,
  BITReachabilityTypeGPRS,
  BITReachabilityTypeEDGE,
  BITReachabilityType3G,
  BITReachabilityTypeLTE
};

FOUNDATION_EXPORT NSString* const kBITReachabilityTypeChangedNotification;
FOUNDATION_EXPORT NSString* const kBITReachabilityUserInfoName;
FOUNDATION_EXPORT NSString* const kBITReachabilityUserInfoType;

/**
 *  The BITReachability class is responsible for keep track of the network status currently used.
 *  Some customers need to send data only via WiFi. The network status is part of the context fields
 *  of an envelop object.
 */
@interface BITReachability : NSObject

///-----------------------------------------------------------------------------
/// @name Initialization
///-----------------------------------------------------------------------------

/**
 *  A queue to make calls to the singleton thread safe.
 */
@property (nonatomic, strong) dispatch_queue_t singletonQueue;

/**
 *  Returns a shared BITReachability object
 *
 *  @return singleton instance.
 */
+ (instancetype)sharedInstance;

///-----------------------------------------------------------------------------
/// @name Register for network changes
///-----------------------------------------------------------------------------

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
/**
 *  Object to determine current radio type.
 */
@property (nonatomic, strong) CTTelephonyNetworkInfo *radioInfo;
#endif

/**
 *  A queue for dispatching reachability operations.
 */
@property (nonatomic, strong) dispatch_queue_t networkQueue;

/**
 *  Register for network status notifications.
 */
- (void)startNetworkStatusTracking;

/**
 *  Unregister for network status notifications.
 */
- (void)stopNetworkStatusTracking;

///-----------------------------------------------------------------------------
/// @name Broadcast network changes
///-----------------------------------------------------------------------------

/**
 *  Updates and broadcasts network changes.
 */
- (void)notify;

///-----------------------------------------------------------------------------
/// @name Get network status
///-----------------------------------------------------------------------------

/**
 *  Get the current network type.
 *
 *  @return the connection type currently used.
 */
- (BITReachabilityType)activeReachabilityType;

/**
 *  Get the current network type name.
 *
 *  @return a human readable name for the current reachability type.
 */
- (NSString *)descriptionForActiveReachabilityType;

///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  Returns a BITReachabilityType for a given radio technology name.
 *
 *  @param technology name of the active radio technology
 *
 *  @return reachability Type, which expresses the WWAN connection
 */
- (BITReachabilityType)wwanTypeForRadioAccessTechnology:(NSString *)technology;

/**
 *  Returns a human readable name for a given BITReachabilityType.
 *
 *  @param reachabilityType the reachability type to convert.
 *
 *  @return a human readable type name
 */
- (NSString *)descriptionForReachabilityType:(BITReachabilityType)reachabilityType;

@end
NS_ASSUME_NONNULL_END
