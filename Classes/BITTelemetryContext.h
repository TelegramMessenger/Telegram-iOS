#import <Foundation/Foundation.h>
#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "HockeySDKPrivate.h"
#import "BITApplication.h"
#import "BITDevice.h"
#import "BITOperation.h"
#import "BITInternal.h"
#import "BITUser.h"
#import "BITSession.h"
#import "BITLocation.h"

@class BITPersistence;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kBITApplicationWasLaunched;

/**
 *  Context object which contains information about the device, user, session etc.
 */
@interface BITTelemetryContext : NSObject

///-----------------------------------------------------------------------------
/// @name Initialisation
///-----------------------------------------------------------------------------

/**
 */
@property(nonatomic, strong) BITPersistence *persistence;

/**
 *  The instrumentation key of the app.
 */
@property(nonatomic, copy) NSString *appIdentifier;

/**
 *  A queue which makes array operations thread safe.
 */
@property (nonatomic, strong) dispatch_queue_t operationsQueue;

/**
 *  The application context.
 */
@property(nonatomic, strong, readonly) BITApplication *application;

/**
 *  The device context.
 */
@property (nonatomic, strong, readonly)BITDevice *device;

/**
 *  The location context.
 */
@property (nonatomic, strong, readonly)BITLocation *location;

/**
 *  The session context.
 */
@property (nonatomic, strong, readonly)BITSession *session;

/**
 *  The user context.
 */
@property (nonatomic, strong, readonly)BITUser *user;

/**
 *  The internal context.
 */
@property (nonatomic, strong, readonly)BITInternal *internal;

/**
 *  The operation context.
 */
@property (nonatomic, strong, readonly)BITOperation *operation;

/**
 *  Initializes a telemetry context.
 *
 *  @param appIdentifier the appIdentifier of the app
 *  @param persistence the persistence used to save and load metadata
 *
 *  @return the telemetry context
 */
- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier persistence:(BITPersistence *)persistence;

///-----------------------------------------------------------------------------
/// @name Network status
///-----------------------------------------------------------------------------

/**
 *  Get current network type and register for updates.
 */
- (void)configureNetworkStatusTracking;

///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  Returns context objects as dictionary.
 *
 *  @return a dictionary containing all context fields
 */
- (BITOrderedDictionary *)contextDictionary;

///-----------------------------------------------------------------------------
/// @name Getter/Setter
///-----------------------------------------------------------------------------

- (NSString *)screenResolution;

- (void)setScreenResolution:(NSString *)screenResolution;

- (NSString *)appVersion;

- (void)setAppVersion:(NSString *)appVersion;

- (NSString *)userId;

- (void)setUserId:(NSString *)userId;

- (NSString *)userAcquisitionDate;

- (void)setUserAcquisitionDate:(NSString *)userAcqusitionDate;

- (NSString *)accountId;

- (void)setAccountId:(NSString *)accountId;

- (NSString *)authenticatedUserId;

- (void)setAuthenticatedUserId:(NSString *)authenticatedUserId;

- (NSString *)authenticatedUserAcquisitionDate;

- (void)setAuthenticatedUserAcquisitionDate:(NSString *)authenticatedUserAcquisitionDate;

- (NSString *)anonymousUserAquisitionDate;

- (void)setAnonymousUserAquisitionDate:(NSString *)anonymousUserAquisitionDate;

- (NSString *)sdkVersion;

- (void)setSdkVersion:(NSString *)sdkVersion;

- (NSString *)sessionId;

- (void)setSessionId:(NSString *)sessionId;

- (NSString *)isFirstSession;

- (void)setIsFirstSession:(NSString *)isFirstSession;

- (NSString *)isNewSession;

- (void)setIsNewSession:(NSString *)isNewSession;

- (NSString *)osVersion;

- (void)setOsVersion:(NSString *)osVersion;

- (NSString *)osName;

- (void)setOsName:(NSString *)osName;

- (NSString *)deviceModel;

- (void)setDeviceModel:(NSString *)deviceModel;

- (NSString *)deviceOemName;

- (void)setDeviceOemName:(NSString *)oemName;

- (NSString *)osLocale;

- (void)setOsLocale:(NSString *)osLocale;

- (NSString *)deviceId;

- (void)setDeviceId:(NSString *)deviceId;

- (NSString *)deviceType;

- (void)setDeviceType:(NSString *)deviceType;

- (NSString *)networkType;

- (void)setNetworkType:(NSString *)networkType;

@end
NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */
