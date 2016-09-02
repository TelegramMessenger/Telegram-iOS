#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import <Foundation/Foundation.h>
#import "BITApplication.h"
#import "BITDevice.h"
#import "BITInternal.h"
#import "BITUser.h"
#import "BITSession.h"

@class BITPersistence;

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

/**
 *  Context object which contains information about the device, user, session etc.
 */
@interface BITTelemetryContext : NSObject

///-----------------------------------------------------------------------------
/// @name Initialisation
///-----------------------------------------------------------------------------

/**
 *  The persistence instance used to save/load metadata.
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
 *  Initializes a telemetry context.
 *
 *  @param appIdentifier the appIdentifier of the app
 *  @param persistence the persistence used to save and load metadata
 *
 *  @return the telemetry context
 */
- (instancetype)initWithAppIdentifier:(NSString *)appIdentifier persistence:(BITPersistence *)persistence;

///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  A dictionary which holds static tag fields for the purpose of caching
 */
@property (nonatomic, strong) NSDictionary *tags;

/**
 *  Returns context objects as dictionary.
 *
 *  @return a dictionary containing all context fields
 */
- (NSDictionary *)contextDictionary;

///-----------------------------------------------------------------------------
/// @name Getter/Setter
///-----------------------------------------------------------------------------

- (void)setSessionId:(NSString *)sessionId;

- (void)setIsFirstSession:(NSString *)isFirstSession;

- (void)setIsNewSession:(NSString *)isNewSession;

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
