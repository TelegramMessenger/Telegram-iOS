/*
 * Author: Christoph Wendt <chwend@microsoft.com>
 *
 * Copyright (c) 2012-2015 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_METRICS

@class BITOrderedDictionary;
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
 *  Enqueue telemetry data (events, metrics, exceptions, traces) before processing it.
 *
 *  @param item The telemetry object, which should be processed
 *
 *  @return YES if the item was successfully enqueued, no if an error occured or the data pipeline was saturated.
 */
- (BOOL)enqueueTelemetryItem:(BITTelemetryData *)item;

/**
 *  Deletes all currently queued items and resets the data items queue.
 */
- (void)resetQueue;

@end
NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_METRICS */
