#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_TELEMETRY

#import "BITPersistence.h"
#import "BITPersistencePrivate.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyHelper.h"

NSString *const kTelemetry = @"Telemetry";
NSString *const kMetaData = @"MetaData";
NSString *const kFileBaseString = @"hockey-app-bundle-";
NSString *const kHockeyAppDirectory = @"com.microsoft.HockeyApp/";
NSString *const kTelemetryDirectoryPath = @"com.microsoft.HockeyApp/Telemetry/";
NSString *const kMetaDataDirectoryPath = @"com.microsoft.HockeyApp/MetaData/";

NSString *const BITHockeyPersistenceSuccessNotification = @"BITHockeyPersistenceSuccessNotification";
char const *kPersistenceQueueString = "com.microsoft.HockeyApp.persistenceQueue";
NSUInteger const defaultFileCount = 50;

@implementation BITPersistence {
  BOOL _maxFileCountReached;
  BOOL _directorySetupComplete;
}

#pragma mark - Public

- (instancetype)init {
  self = [super init];
  if(self) {
    _persistenceQueue = dispatch_queue_create(kPersistenceQueueString, DISPATCH_QUEUE_SERIAL); //TODO several queues?
    _requestedBundlePaths = [NSMutableArray new];
    _maxFileCount = defaultFileCount;

    // Evantually, there will be old files on disk, the flag will be updated before the first event gets created
    
    
    _maxFileCountReached = YES;
    _directorySetupComplete = NO; //will be set to true in createDirectoryStructureIfNeeded

    [self createDirectoryStructureIfNeeded];
    
    NSString *directoryPath = [self folderPathForType:BITPersistenceTypeTelemetry];
    NSError *error = nil;
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directoryPath]
                                                       includingPropertiesForKeys:@[NSURLNameKey]
                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                            error:&error];
      _maxFileCountReached = fileNames.count >= _maxFileCount;
  }
  return self;
}

/**
 * Saves the Bundle using NSKeyedArchiver and NSData's writeToFile:atomically
 * Sends out a BITHockeyPersistenceSuccessNotification in case of success
 */
- (void)persistBundle:(NSData *)bundle {
  //TODO send out a fail notification?
  NSString *fileURL = [self fileURLForType:BITPersistenceTypeTelemetry];

  if(bundle) {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.persistenceQueue, ^{
      typeof(self) strongSelf = weakSelf;
      BOOL success = [bundle writeToFile:fileURL atomically:YES];
      if(success) {
        BITHockeyLog(@"Wrote bundle to %@", fileURL);
        [strongSelf sendBundleSavedNotification];
      }
      else {
        BITHockeyLog(@"Error writing bundle to %@", fileURL);
      }
    });
  }
  else {
    BITHockeyLog(@"Unable to write %@ as provided bundle was null", fileURL);
  }
}

- (void)persistMetaData:(NSDictionary *)metaData {
  NSString *fileURL = [self fileURLForType:BITPersistenceTypeMetaData];
    //TODO send out a notification, too?!
  dispatch_async(self.persistenceQueue, ^{
    [NSKeyedArchiver archiveRootObject:metaData toFile:fileURL];
  });
}

- (BOOL)isFreeSpaceAvailable {
  return !_maxFileCountReached;
}

- (NSString *)requestNextPath {
  __block NSString *path = nil;
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;

    path = [strongSelf nextURLOfType:BITPersistenceTypeTelemetry];

    if(path) {
      [self.requestedBundlePaths addObject:path];
    }
  });
  return path;
}


/**
 * Deserializes a bundle from disk using NSKeyedUnarchiver
 *
 * @return a bundle of data or nil
 */
- (id)bundleAtPath:(NSString *)path {
  id bundle = nil;
  if(path && [path rangeOfString:kFileBaseString].location != NSNotFound) {
    bundle = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
  }
  return bundle;
}

- (NSDictionary *)metaData {
  NSString *path = [self fileURLForType:BITPersistenceTypeMetaData];
  return [self bundleAtPath:path];
}

- (NSData *)dataAtPath:(NSString *)path {
  NSData *data = nil;
  if(path && [path rangeOfString:kFileBaseString].location != NSNotFound) {
    data = [NSData dataWithContentsOfFile:path];
  }
  return data;
}

/**
 * Deletes a file at the given path.
 *
 * @param the path to look for a file and delete it.
 */
- (void)deleteFileAtPath:(NSString *)path {
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;
    if([path rangeOfString:kFileBaseString].location != NSNotFound) {
      NSError *error = nil;
      if(![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
        BITHockeyLog(@"Error deleting file at path %@", path);
      }
      else {
        BITHockeyLog(@"Successfully deleted file at path %@", path);
        [strongSelf.requestedBundlePaths removeObject:path];
      }
    } else {
      BITHockeyLog(@"Empty path, nothing to delete");
    }
  });

}

- (void)giveBackRequestedPath:(NSString *)path {
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;

    [strongSelf.requestedBundlePaths removeObject:path];
  });
}

#pragma mark - Private

- (NSString *)fileURLForType:(BITPersistenceType)type {
  static NSString *fileDir;

  NSString *uuid = bit_UUID();
  NSString *fileName = [NSString stringWithFormat:@"%@%@", kFileBaseString, uuid];
  NSString *filePath;

  switch(type) {
    case BITPersistenceTypeMetaData: {
      filePath = [[fileDir stringByAppendingPathComponent:kMetaData] stringByAppendingPathComponent:kMetaData];
      break;
    };
    default: {
      filePath = [[fileDir stringByAppendingPathComponent:kTelemetry] stringByAppendingPathComponent:fileName];
      break;
    };
  }

  return filePath;
}

/**
 * Create directory structure if necessary and exclude it from iCloud backup
 */
- (void)createDirectoryStructureIfNeeded {
  //Application Support Dir
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray *urls = [fileManager URLsForDirectory:NSApplicationDirectory inDomains:NSUserDomainMask];
  NSURL *appSupportURL = [urls lastObject];
  if(appSupportURL) {
    NSError *error = nil;
    //App Support and Telemetry Directory
    NSURL *folderURL = [appSupportURL URLByAppendingPathComponent:kTelemetryDirectoryPath];
    //NOTE: createDirectoryAtURL:withIntermediateDirectories:attributes:error
    //will return YES if the directory already exists and won't override anything.
    //No need to check if the directory already exists.
    if(![fileManager createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:&error]) {
      BITHockeyLog(@"%@", error.localizedDescription);
      return; //TODO we can't use persistence at all in this case, what do we want to do now? Notify the user?
    }

    //MetaData Directory
    folderURL = [appSupportURL URLByAppendingPathComponent:kMetaDataDirectoryPath];
    if(![fileManager createDirectoryAtURL:folderURL withIntermediateDirectories:NO attributes:nil error:&error]) {
      BITHockeyLog(@"%@", error.localizedDescription);
      return; //TODO we can't use persistence at all in this case, what do we want to do now? Notify the user?
    }

    _directorySetupComplete = YES;

    //Exclude from Backup
    if(![appSupportURL setResourceValue:@YES
                                 forKey:NSURLIsExcludedFromBackupKey
                                  error:&error]) {
      BITHockeyLog(@"Error excluding %@ from backup %@", appSupportURL.lastPathComponent, error.localizedDescription);
    }
    else {
      BITHockeyLog(@"Exclude %@ from backup", appSupportURL);
    }
  }
}

/**
 * @returns the URL to the next file depending on the specified type. If there's no file, return nil.
 */
- (NSString *)nextURLOfType:(BITPersistenceType)type {

  NSString *directoryPath = [self folderPathForType:type];
  NSError *error = nil;
  NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directoryPath]
                                                     includingPropertiesForKeys:@[NSURLNameKey]
                                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                          error:&error];

  // each track method asks, if space is still available. Getting the file count for each event would be too expensive,
  // so let's get it here
  if(type == BITPersistenceTypeTelemetry) {
    _maxFileCountReached = fileNames.count >= _maxFileCount;
  }

  if(fileNames && fileNames.count > 0) {
    for(NSURL *filename in fileNames) {
      NSString *absolutePath = filename.path;
      if(![self.requestedBundlePaths containsObject:absolutePath]) {
        return absolutePath;
      }
    }
  }
  return nil;
}

- (NSString *)folderPathForType:(BITPersistenceType)type {
  NSString *persistenceFolder;
  NSString *appSupportFolder = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
  persistenceFolder = [appSupportFolder stringByAppendingPathComponent:kHockeyAppDirectory];

  NSString *subfolderPath;

  switch(type) {
    case BITPersistenceTypeTelemetry: {
      subfolderPath = kTelemetry;
      break;
    }
    case BITPersistenceTypeMetaData: {
      subfolderPath = kMetaData;
      break;
    }
  }
  NSString *path = [persistenceFolder stringByAppendingPathComponent:subfolderPath];

  return path;
}

/**
 * Send a BITHockeyPersistenceSuccessNotification to the main thread to notify observers that we have successfully saved a file
 * This is typically used to trigger sending.
 */
- (void)sendBundleSavedNotification {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyPersistenceSuccessNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}

@end

#endif /* HOCKEYSDK_FEATURE_TELEMETRY */

