#import <Foundation/Foundation.h>
#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "HockeySDKNullability.h"
@class BITPersistence;

NS_ASSUME_NONNULL_BEGIN
/**
 * Utility class that's responsible for sending a bundle of data to the server
 */
@interface BITSender : NSObject

///-----------------------------------------------------------------------------
/// @name Initialize instance
///-----------------------------------------------------------------------------

/**
 *  Initializes a sender instance with a given persistence object.
 *
 *  @param persistence used for loading files before sending them out
 *  @param serverURL the endpoint URL for telemetry data
 *  @return an initialized sender instance
 */
- (instancetype)initWithPersistence:(BITPersistence *)persistence serverURL:(NSURL *)serverURL;

/**
 *	Access to the internal operation queue
 */
@property (nonatomic, strong) NSOperationQueue *operationQueue;

/**
 *  A queue which is used to handle BITHTTPOperation completion blocks.
 */
@property (nonatomic, strong) dispatch_queue_t senderQueue;

/**
 *  The endpoint url of the telemetry server.
 */
@property (nonatomic, copy) NSString *endpointPath;

/**
 *  The max number of request that can run at a time.
 */
@property NSUInteger maxRequestCount;

/**
 *  The number of requests that are currently running.
 */
@property NSUInteger runningRequestsCount;

/**
 *	BaseURL to which relative paths are appended.
 */
@property (nonatomic, strong, readonly) NSURL *serverURL;

/**
 *  The persistence instance used for loading files before sending them out.
 */
@property (nonatomic, strong, readonly) BITPersistence *persistence;

///-----------------------------------------------------------------------------
/// @name Sending data
///-----------------------------------------------------------------------------

/**
 *  Triggers sending the saved data. Does nothing if nothing has been persisted, yet. This method should be called by BITTelemetryManager on app start.
 */
- (void)sendSavedData;

/**
 *  Creates a HTTP operation and puts it to the queue.
 *
 *  @param request a request for sending a data object to the telemetry server
 *  @param path path to the file which should be sent
 *  @param urlSessionSupported a flag which determines whether to use NSURLConnection or NSURLSession for sending out data
 */
- (void)sendRequest:(NSURLRequest * __nonnull)request path:(NSString * __nonnull)path urlSessionSupported:(BOOL)isUrlSessionSupported;

///-----------------------------------------------------------------------------
/// @name Helper
///-----------------------------------------------------------------------------

/**
 *  Returns a request for sending data to the telemetry sender.
 *
 *  @param data the data which should be sent
 *
 *  @return a request which contains the given data
 */
- (NSURLRequest *)requestForData:(NSData *)data;

/**
 *  Returns if data should be deleted based on a given status code.
 *
 *  @param statusCode the status code which is part of the response object
 *
 *  @return YES if data should be deleted, NO if the payload should be sent at a later time again.
 */
- (BOOL)shouldDeleteDataWithStatusCode:(NSInteger)statusCode;

@end
NS_ASSUME_NONNULL_END

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */
