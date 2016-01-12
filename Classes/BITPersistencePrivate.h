/*
 * Author: Benjamin Reimold <bereimol@microsoft.com>
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
#import "BITPersistence.h"

@interface BITPersistence ()


/**
 * The BITPersistenceType determines if we have a bundle of meta data or telemetry that we want to safe.
 */
typedef NS_ENUM(NSInteger, BITPersistenceType) {
    BITPersistenceTypeTelemetry = 0,
    BITPersistenceTypeMetaData = 1
};

#if HOCKEYSDK_FEATURE_METRICS

/**
 * Notification that will be send on the main thread to notifiy observers of a successfully saved bundle.
 * This is typically used to trigger sending to the server.
 */
FOUNDATION_EXPORT NSString *const BITPersistenceSuccessNotification;


///-----------------------------------------------------------------------------
/// @name Save/delete bundle of data
///-----------------------------------------------------------------------------

/**
 *  A queue which makes file system operations thread safe.
 */
@property (nonatomic, strong) dispatch_queue_t persistenceQueue;

/**
 *  Determines how many telemetry files can be on disk at a time.
 */
@property NSUInteger maxFileCount;

/**
 *  An array with all file paths, that have been requested by the sender. If the sender
 *  triggers a delete, the appropriate path should also be removed here. We keep to
 *  track of requested bundles to make sure that bundles don't get sent twice at the same
 *  time by differend http operations.
 */
@property (nonatomic, strong) NSMutableArray *requestedBundlePaths;

/**
 *  Saves the bundle to disk.
 *
 *  @param bundle            the bundle, which should be saved to disk
 *  @param completionBlock   a block which is executed after the bundle has been stored
 */
- (void)persistBundle:(NSData *)bundle;

/**
 *  Saves the given dictionary to the session Ids file.
 *
 *  @param metaData a dictionary consisting of unix timestamps and session ids
 */
- (void)persistMetaData:(NSDictionary *)metaData;

/**
 *  Deletes the file for the given path.
 *
 *  @param path the path of the file, which should be deleted
 */
- (void)deleteFileAtPath:(NSString *)path;

/**
 *  Determines whether the persistence layer is able to write more files to disk.
 *
 *  @return YES if the maxFileCount has not been reached, yet (otherwise NO).
 */
- (BOOL)isFreeSpaceAvailable;

///-----------------------------------------------------------------------------
/// @name Get a bundle of saved data
///-----------------------------------------------------------------------------

/**
 * Get a bundle of previously saved data from disk and deletes it using dispatch_sync.
 *
 * @warning Make sure nextBundle is not called from the main thread.
 *
 * It will return a bundle of Telemtry in arbitrary order.
 * Returns 'nil' if no bundle is available
 *
 * @return a bundle of data that's ready to be sent to the server
 */

/**
 *  Returns the path for the next item to send. The requested path is reserved as long
 *  as leaveUpRequestedPath: gets called.
 *
 *  @see giveBackRequestedPath:
 *
 *  @return the path of the item, which should be sent next
 */
- (NSString *)requestNextFilePath;

/**
 *  Release a requested path. This method should be called after sending a file failed.
 *
 *  @param path the path that should be available for sending again.
 */
- (void)giveBackRequestedFilePath:(NSString *)filePath;

/**
 *  Return the json data for a given path
 *
 *  @param path the path of the file
 *
 *  @return a data object which contains telemetry data in json representation
 */
- (NSData *)dataAtFilePath:(NSString *)filePath;

/**
 *  Returns the content of the session Ids file.
 *
 *  @return return a dictionary containing all session Ids
 */
- (NSDictionary *)metaData;

///-----------------------------------------------------------------------------
/// @name Getting a path
///-----------------------------------------------------------------------------

/**
 *  Returns a folder path for items of a given type.
 *  @param the type
 *  @return a folder path for items of a given type
 */
- (NSString *)folderPathForType:(BITPersistenceType)type;

///-----------------------------------------------------------------------------
/// @name Getting a path
///-----------------------------------------------------------------------------

/**
 * Creates the path for a file
 * The filename includes the timestamp.
 *
 * @param the type that you want the fileURL for
*/
- (NSString *)fileURLForType:(BITPersistenceType)type;


#endif /* HOCKEYSDK_FEATURE_METRICS */

@end
