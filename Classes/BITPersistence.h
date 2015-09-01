#import <Foundation/Foundation.h>
#import "HockeySDKNullability.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The MSAIPersistenceType determines the way how a bundle is saved.
 * Bundles of type MSAIPersistenceTypeHighPriority will be loaded before all bundles if type MSAIPersistenceTypeRegular.
 */
typedef NS_ENUM(NSInteger, BITPersistenceType) {
    BITPersistenceTypeRegular = 0,
    BITPersistenceTypeMetaData = 1
};

/**
 * A simple class that handles serialisation and deserialisation of bundles of data.
 */
@interface BITPersistence : NSObject

/**
 * Notification that will be send on the main thread to notifiy observers of a successfully saved bundle.
 * This is typically used to trigger sending to the server.
 */
FOUNDATION_EXPORT NSString *const MSAIPersistenceSuccessNotification;


///-----------------------------------------------------------------------------
/// @name Save/delete bundle of data
///-----------------------------------------------------------------------------

/**
 *  A queue which makes file system operations thread safe.
 */
@property (nonatomic, strong) dispatch_queue_t persistenceQueue;

/**
 *  Determines how many files (regular prio) can be on disk at a time.
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
- (void)deleteFileAtPath:(NSString *)path ;

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
 * It will return bundles of MSAIPersistenceType first.
 * Between bundles of the same MSAIPersistenceType, the order is arbitrary.
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
- (NSString *)requestNextPath;

/**
 *  Release a requested path. This method should be called after sending a file failed.
 *
 *  @param path the path that should be available for sending again.
 */
- (void)giveBackRequestedPath:(NSString *)path;

/**
 *  Return the bundle for a given path.
 *
 *  @param path the path of the bundle.
 *
 *  @return an array with all envelope objects.
 */
- (NSArray *)bundleAtPath:(NSString *)path;

/**
 *  Return the json data for a given path
 *
 *  @param path the path of the file
 *
 *  @return a data object which contains telemetry data in json representation
 */
- (NSData *)dataAtPath:(NSString *)path;

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
 * *
 *  @return a folder path for items of a given type
 */
- (NSString *)folderPath;//TODO remove this one?


///-----------------------------------------------------------------------------
/// @name Getting a path
///-----------------------------------------------------------------------------

/**
 * Creates the path for a file
 * The filename includes the timestamp.
 *
 * @param the type of
*/
 - (NSString *)fileURLForType:(BITPersistenceType)type;

@end

NS_ASSUME_NONNULL_END
