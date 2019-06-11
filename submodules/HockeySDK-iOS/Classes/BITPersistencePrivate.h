#import "HockeySDKFeatureConfig.h"

#if HOCKEYSDK_FEATURE_METRICS

#import "BITPersistence.h"

#import "HockeySDKNullability.h"
NS_ASSUME_NONNULL_BEGIN

@interface BITPersistence ()

/**
 * The BITPersistenceType determines if we have a bundle of meta data or telemetry that we want to safe.
 */
typedef NS_ENUM(NSInteger, BITPersistenceType) {
    BITPersistenceTypeTelemetry = 0,
    BITPersistenceTypeMetaData = 1
};

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
@property (nonatomic, assign) NSUInteger maxFileCount;

@property (nonatomic, copy) NSString *appHockeySDKDirectoryPath;

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
 *  Returns the path for the next item to send. The requested path is reserved as long
 *  as leaveUpRequestedPath: gets called.
 *
 *  @see giveBackRequestedPath:
 *
 *  @return the path of the item, which should be sent next
 */
- (nullable NSString *)requestNextFilePath;

/**
 *  Release a requested path. This method should be called after sending a file failed.
 *
 *  @param filePath The path that should be available for sending again.
 */
- (void)giveBackRequestedFilePath:(NSString *)filePath;

/**
 *  Return the json data for a given path
 *
 *  @param filePath The path of the file
 *
 *  @return a data object which contains telemetry data in json representation
 */
- (nullable NSData *)dataAtFilePath:(NSString *)filePath;

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
 *  @param type The type
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
 * @param type The type that you want the fileURL for
*/
- (nullable NSString *)fileURLForType:(BITPersistenceType)type;

- (void)createDirectoryStructureIfNeeded;

#endif /* HOCKEYSDK_FEATURE_METRICS */

@end

NS_ASSUME_NONNULL_END
