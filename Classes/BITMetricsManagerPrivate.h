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

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITSessionState.h"

@class BITChannel;
@class BITTelemetryContext;
@class BITSession;
@class BITPersistence;
@class BITSender;

@interface BITMetricsManager ()

/**
 *  Create a new BITMetricsManager instance by passing the channel, the telemetry context, and persistence instance to use 
 for processing metrics. This method can be used for dependency injection.
 */
- (instancetype)initWithChannel:(BITChannel *)channel
               telemetryContext:(BITTelemetryContext *)telemetryContext
                    persistence:(BITPersistence *)persistence
                   userDefaults:(NSUserDefaults *)userDefaults;

/**
 *  The user defaults object used to store meta data.
 */
@property (nonatomic, strong, readonly) NSUserDefaults *userDefaults;

/**
 *  A channel for collecting new events before storing and sending them.
 */
@property (nonatomic, strong, readonly) BITPersistence *persistence;

/**
 *  A channel for collecting new events before storing and sending them.
 */
@property (nonatomic, strong, readonly) BITChannel *channel;

/**
 *  A telemetry context which is used to add meta info to events, before they're sent out.
 */
@property (nonatomic, strong, readonly) BITTelemetryContext *telemetryContext;

/**
 *  A concurrent queue which creates and processes telemetry items.
 */
@property (nonatomic, strong, readonly)dispatch_queue_t metricsEventQueue;

/**
 *  Sender instance to send out telemetry data.
 */
@property (nonatomic, strong) BITSender *sender;

///-----------------------------------------------------------------------------
/// @name Session Management
///-----------------------------------------------------------------------------

/**
 *  The Interval an app has to be in the background until the current session gets renewed.
 */
@property (nonatomic, assign)NSUInteger appBackgroundTimeBeforeSessionExpires;

/**
 *  Registers manager for several notifications, which influence the session state.
 */
- (void)registerObservers;

/**
 *  Unregisters manager for several notifications, which influence the session state.
 */
- (void)unregisterObservers;

/**
 *  Stores the current date before app is sent to background.
 *
 *  @see appBackgroundTimeBeforeSessionExpires
 *  @see startNewSessionIfNeeded
 */
- (void)updateDidEnterBackgroundTime;

/**
 *  Determines whether the current session needs to be renewed or not.
 *
 *  @see appBackgroundTimeBeforeSessionExpires
 *  @see updateDidEnterBackgroundTime
 */
- (void)startNewSessionIfNeeded;

/**
 *  Creates a new session, updates the session context and sends it to the channel.
 *
 *  @param sessionId the id for the new session
 */
- (void)startNewSessionWithId:(NSString *)sessionId;

/**
 *  Creates a new session and stores it to NSUserDefaults.
 *
 *  @param sessionId the id for the new session
 *  @return the newly created session
 */
- (BITSession *)createNewSessionWithId:(NSString *)sessionId;

///-----------------------------------------------------------------------------
/// @name Track telemetry data
///-----------------------------------------------------------------------------

/**
 *  Creates and enqueues a session event for the given state.
 *
 *  @param state value that determines whether the session started or ended
 */
- (void)trackSessionWithState:(BITSessionState) state;

@end

#endif /* HOCKEYSDK_FEATURE_METRICS */
