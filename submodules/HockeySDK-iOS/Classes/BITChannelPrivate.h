#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

@class BITTelemetryData;
@class BITTelemetryContext;
@class BITPersistence;

#import "BITChannel.h"

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

@interface BITChannel ()

/**
 * Notification that will be send on the main thread to notifiy observers that channel can't enqueue new items.
 * This is typically used to trigger sending to the server.
 */
FOUNDATION_EXPORT NSString *const BITChannelBlockedNotification;

/**
 *  Telemetry context used by the channel to create the payload (testing).
 */
@property (nonatomic, strong) BITTelemetryContext *telemetryContext;

/**
 *  Persistence instance for storing files after the queue gets flushed (testing).
 */
@property (nonatomic, strong) BITPersistence *persistence;

/*
 * Threshold for sending data to the server. Default batch size for debugging is 150, for release
 * configuration, the batch size is 5.
 *
 * Default: 50
 *
 * @warning: We advice to not set the batch size below 5 events.
 */
@property (nonatomic) NSUInteger maxBatchSize;

/*
 * Interval for sending data to the server in seconds.
 *
 * Default: 15
 */
@property (nonatomic, assign) NSInteger batchInterval;

/**
 *  A timer source which is used to flush the queue after a cretain time.
 */
@property (nonatomic, strong, nullable) dispatch_source_t timerSource;

/**
 *  A queue which makes array operations thread safe.
 */
@property (nonatomic, strong) dispatch_queue_t dataItemsOperations;

/**
 *  An integer value that keeps tracks of the number of data items added to the JSON Stream string.
 */
@property (nonatomic, assign) NSUInteger dataItemCount;

/**
 *  Indicates that channel is currently in a blocked state.
 */
@property BOOL channelBlocked;

/**
 *  Manually trigger the BITChannel to persist all items currently in its data item queue.
 */
- (void)persistDataItemQueue:(char *_Nullable*_Nullable)eventBuffer;

/**
 *  Create background task for queues and group.
 */
- (void)createBackgroundTaskWhileDataIsSending:(UIApplication *)application
                              withWaitingGroup:(nullable dispatch_group_t)group;

/**
 *  Adds the specified dictionary to the JSON Stream string.
 *
 *  @param dictionary the dictionary object which is to be added to the JSON Stream queue string.
 */
- (void)appendDictionaryToEventBuffer:(NSDictionary *)dictionary;

/**
 *  A C function that serializes a given dictionary to JSON and appends it to a char string
 *
 *  @param string The C string which the dictionary's JSON representation will be appended to.
 */
void bit_appendStringToEventBuffer(NSString *string, char *__nonnull*__nonnull eventBuffer);

/**
 *  Reset the event buffer so we can start appending JSON dictionaries.
 *
 *  @param eventBuffer The string that will be reset.
 */
void bit_resetEventBuffer(char *__nonnull*__nonnull eventBuffer);

/**
 *  A method which indicates whether the telemetry pipeline is busy and no new data should be enqueued.
 *  Currently, we drop telemetry data if this returns YES.
 *  This depends on defaultMaxBatchCount and defaultBatchInterval.
 *
 *  @return Returns yes if currently no new data should be enqueued on the channel.
 */
- (BOOL)isQueueBusy;

/**
 * Enqueue a telemetry item. This is for testing purposes where we actually use the completion handler.
 *
 * @param completionHandler The completion handler that will be called after enqueuing a BITTelemetryData object.
 *
 * @discussion intended for testing purposes.
 */
- (void)enqueueTelemetryItem:(BITTelemetryData *)item completionHandler:(nullable void (^)(void))completionHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
