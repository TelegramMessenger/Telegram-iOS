#import "BITPersistence.h"
#import "HockeySDKPrivate.h"
#import "BITHockeyManager.h"
#import "BITHockeyHelper.h"


NSString *const kRegular = @"regular";
NSString *const kMetaData = @"metaData";
NSString *const kFileBaseString = @"hockey-app-bundle-";

NSString *const BITHockeyPersistenceSuccessNotification = @"MSAIPersistenceSuccessNotification";
char const *kPersistenceQueueString = "com.microsoft.HockeyApp.persistenceQueue";
NSUInteger const defaultFileCount = 50;

@implementation BITPersistence {
  BOOL _maxFileCountReached;
}

#pragma mark - Public

- (instancetype)init {
  self = [super init];
  if ( self ) {
    _persistenceQueue = dispatch_queue_create(kPersistenceQueueString, DISPATCH_QUEUE_SERIAL); //TODO several queues?
    _requestedBundlePaths = [NSMutableArray new];
    _maxFileCount = defaultFileCount;

    // Evantually, there will be old files on disk, the flag will be updated before the first event gets created
    _maxFileCountReached = YES;

    [self createApplicationSupportDirectoryIfNeeded];
  }
  return self;
}

/**
 * Creates a serial background queue that saves the Bundle using NSKeyedArchiver and NSData's writeToFile:atomically
 * Sends out a BITHockeyPersistenceSuccessNotification in case of success
 */
- (void)persistBundle:(NSData *)bundle {
  //TODO send out a fail notification?
  NSString *fileURL = [self fileURLForType:BITPersistenceTypeRegular];

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
        BITHockeyLog(@"Error writing bundle to %@",fileURL);
      }
    });
  }
  else {
    BITHockeyLog(@"Unable to write %@ as provided bundle was null", fileURL);
  }
}

- (void)persistMetaData:(NSDictionary *)metaData {
  NSString *fileURL = [self fileURLForType:BITPersistenceTypeMetaData];

  dispatch_async(self.persistenceQueue, ^{
    [NSKeyedArchiver archiveRootObject:metaData toFile:fileURL];
  });
}

- (BOOL)isFreeSpaceAvailable{
  return !_maxFileCountReached;
}

- (NSString *)requestNextPath {
  __block NSString *path = nil;
  __weak typeof(self) weakSelf = self;
  dispatch_sync(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;

    path = [strongSelf nextURLWithPriority:BITPersistenceTypeRegular];

    if(path){
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
- (NSArray *)bundleAtPath:(NSString *)path {
  NSArray *bundle = nil;
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
    }else {
      BITHockeyLog(@"Empty path, nothing to delete");
    }
  });

}

- (void)giveBackRequestedPath:(NSString *) path {
  __weak typeof(self) weakSelf = self;
  dispatch_async(self.persistenceQueue, ^() {
    typeof(self) strongSelf = weakSelf;

    [strongSelf.requestedBundlePaths removeObject:path];
  });
}

#pragma mark - Private

- (NSString *)fileURLForType:(BITPersistenceType)type {
  static NSString *fileDir;
  static dispatch_once_t dirToken;

  dispatch_once(&dirToken, ^{
    NSString *applicationSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    fileDir = [applicationSupportDir stringByAppendingPathComponent:@"com.microsoft.ApplicationInsights/"];
    [self createFolderAtPathIfNeeded:fileDir];
  });

  NSString *uuid = bit_UUID();
  NSString *fileName = [NSString stringWithFormat:@"%@%@", kFileBaseString, uuid];
  NSString *filePath;

  switch(type) {
    case BITPersistenceTypeMetaData: {
      [self createFolderAtPathIfNeeded:[fileDir stringByAppendingPathComponent:kMetaData]];
      filePath = [[fileDir stringByAppendingPathComponent:kMetaData] stringByAppendingPathComponent:kMetaData];
      break;
    };
    default: {
      [self createFolderAtPathIfNeeded:[fileDir stringByAppendingPathComponent:kRegular]];
      filePath = [[fileDir stringByAppendingPathComponent:kRegular] stringByAppendingPathComponent:fileName];
      break;
    };
  }

  return filePath;
}

/**
 * create a folder within at the given path
 */
- (void)createFolderAtPathIfNeeded:(NSString *)path {
  if(path && ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error]) {
      BITHockeyLog(@"Error while creating folder at: %@, with error: %@", path, error);
    }
  }
}

/**
 * Create ApplicationSupport directory if necessary and exclude it from iCloud Backup
 */
- (void)createApplicationSupportDirectoryIfNeeded {
  NSString *appplicationSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
  if(![[NSFileManager defaultManager] fileExistsAtPath:appplicationSupportDir isDirectory:NULL]) {
    NSError *error = nil;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:appplicationSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
      BITHockeyLog(@"%@", error.localizedDescription);
    }
    else {
      NSURL *url = [NSURL fileURLWithPath:appplicationSupportDir];
      if(![url setResourceValue:@YES
      forKey:NSURLIsExcludedFromBackupKey
      error:&error]) {
        BITHockeyLog(@"Error excluding %@ from backup %@", url.lastPathComponent, error.localizedDescription);
      }
      else {
        BITHockeyLog(@"Exclude %@ from backup", url);
      }
    }
  }
}

/**
 * @returns the URL to the next file depending on the specified type. If there's no file, return nil.
 */
- (NSString *)nextURLWithPriority:(BITPersistenceType)type {

  NSString *directoryPath = [self folderPathForPersistenceType:type];
  NSError *error = nil;
  NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:directoryPath]
                                                     includingPropertiesForKeys:@[NSURLNameKey]
                                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                          error:&error];

  // each track method asks, if space is still available. Getting the file count for each event would be too expensive,
  // so let's get it here
  if(type == BITPersistenceTypeRegular){
    _maxFileCountReached = fileNames.count >= _maxFileCount;
  }

  if(fileNames && fileNames.count > 0) {
    for(NSURL *filename in fileNames){
      NSString *absolutePath = filename.path;
      if(![self.requestedBundlePaths containsObject:absolutePath]){
        return absolutePath;
      }
    }
  }
  return nil;
}

- (NSString *)folderPathForPersistenceType:(BITPersistenceType)type {
  static NSString *persistenceFolder;
  static dispatch_once_t persistenceFolderToken;
  dispatch_once(&persistenceFolderToken, ^{
    NSString *documentsFolder = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    persistenceFolder = [documentsFolder stringByAppendingPathComponent:@"com.microsoft.HockeyApp/"];
    [self createFolderAtPathIfNeeded:persistenceFolder];
  });

  NSString *subfolderPath;

  switch(type) {
    case BITPersistenceTypeRegular: {
      subfolderPath = kRegular;
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
- (void)sendBundleSavedNotification{
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:BITHockeyPersistenceSuccessNotification
                                                        object:nil
                                                      userInfo:nil];
  });
}


@end
