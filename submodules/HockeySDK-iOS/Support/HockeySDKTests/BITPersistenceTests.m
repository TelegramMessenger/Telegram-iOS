#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "BITTestsDependencyInjection.h"
#import "BITPersistence.h"
#import "BITPersistencePrivate.h"

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface BITPersistenceTests : BITTestsDependencyInjection

@property (strong) BITPersistence *sut;

@end

@implementation BITPersistenceTests

- (void)setUp {
  [super setUp];
  self.sut = [BITPersistence new];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testPersistenceSetupWorks {
  XCTAssertNotNil(self.sut, @"Should not be nil.");
  XCTAssertNotNil(self.sut.requestedBundlePaths, @"Should not be nil");
  XCTAssertNotNil(self.sut.persistenceQueue, @"Should not be nil");
  BOOL spaceAvailable = [self.sut isFreeSpaceAvailable];
  XCTAssertTrue(spaceAvailable);
  XCTAssertTrue(self.sut.maxFileCount == 50);
}

- (void)testSuccessNotificationIsSent {
  id observerMock = [OCMockObject observerMock];
  [self.mockNotificationCenter addMockObserver:observerMock name:@"BITHockeyPersistenceSuccessNotification" object:nil];

  NSData *testData = [NSKeyedArchiver archivedDataWithRootObject:@{@"key1" : @"value1", @"key2" : @"value2"}];
  [self.sut persistBundle:testData];

  [observerMock verify];

  [self.mockNotificationCenter removeObserver:observerMock];
}

- (void)testCreateDirectoryStructureIfNeeded {
  // Setup
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *appSupportPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
  NSString *path = self.sut.appHockeySDKDirectoryPath;
  
  NSError *fileRemovalError = nil;
  [fileManager removeItemAtPath:path error:&fileRemovalError];

  NSError *getResourceError = nil;
  NSNumber *resourveValue = nil;
  XCTAssertTrue([[NSURL fileURLWithPath:appSupportPath] setResourceValue:@NO
                                                    forKey:NSURLIsExcludedFromBackupKey
                                                     error:&getResourceError]);
  
  // Assert
  XCTAssertNil(fileRemovalError);
  XCTAssertFalse([fileManager fileExistsAtPath:path]);
  
  // Act
  [self.sut createDirectoryStructureIfNeeded];
  
  // Verify
  BOOL isDirectory = NO;
  [fileManager fileExistsAtPath:path isDirectory:&isDirectory];
  
  XCTAssertTrue(isDirectory);
  
  // Flag stays @NO on Application Support directory
  getResourceError = nil;
  resourveValue = nil;
  [[NSURL fileURLWithPath:appSupportPath] getResourceValue:&resourveValue
                                          forKey:NSURLIsExcludedFromBackupKey
                                           error:&getResourceError];
  XCTAssertNil(getResourceError);
  XCTAssertEqual(resourveValue, @NO);
  
  // Flag is set to @YES on our custom subdirectory
  getResourceError = nil;
  resourveValue = nil;
  [[NSURL fileURLWithPath:path] getResourceValue:&resourveValue
                                          forKey:NSURLIsExcludedFromBackupKey
                                           error:&getResourceError];
  XCTAssertNil(getResourceError);
  XCTAssertEqual(resourveValue, @YES);
  
  // TODO: Check subdirectories have been created
}

- (void)testFolderPathForType {
  NSString *path = [self.sut folderPathForType:BITPersistenceTypeTelemetry];
  XCTAssertFalse([path rangeOfString:@"com.microsoft.HockeyApp/Telemetry"].location == NSNotFound);
  path = [self.sut folderPathForType:BITPersistenceTypeMetaData];
  XCTAssertFalse([path rangeOfString:@"com.microsoft.HockeyApp/MetaData"].location == NSNotFound);
}

- (void)testFileUrlForType {
  NSString *path = [self.sut fileURLForType:BITPersistenceTypeTelemetry];
  XCTAssertFalse([path rangeOfString:@"com.microsoft.HockeyApp/Telemetry/hockey-app-bundle-"].location == NSNotFound);
  path = [self.sut fileURLForType:BITPersistenceTypeMetaData];
  XCTAssertFalse([path rangeOfString:@"com.microsoft.HockeyApp/MetaData/metadata"].location == NSNotFound);
}




@end
