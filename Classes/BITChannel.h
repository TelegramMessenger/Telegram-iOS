#import <Foundation/Foundation.h>
#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

@class BITConfiguration;
@class BITTelemetryData;
@class BITTelemetryContext;
@class BITPersistence;

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT char *BITSafeJsonEventsString;

/**
 *  Items get queued before they are persisted and sent out as a batch. This class managed the queue, and forwards the batch
 *  to the persistence layer once the max batch count has been reached.
 */
@interface BITChannel : NSObject


/**
 *  Initializes a new BITChannel instance.
 *
 *  @param telemetryContext the context used to add context values to the metrics payload
 *  @param persistence the persistence used to save metrics after the queue gets flushed
 *
 *  @return the telemetry context
 */
- (instancetype)initWithTelemetryContext:(BITTelemetryContext *)telemetryContext persistence:(BITPersistence *) persistence;

/**
 *  Reset BITSafeJsonEventsString so we can start appending JSON dictionaries.
 *
 *  @param item The telemetry object, which should be processed
 */
- (void)enqueueTelemetryItem:(BITTelemetryData *)item;

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
