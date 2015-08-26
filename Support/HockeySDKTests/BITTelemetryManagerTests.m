#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "BITTestsDependencyInjection.h"
#import "BITTelemetryManager.h"
#import "BITTelemetryManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITSession.h"

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface BITTelemetryManagerTests : BITTestsDependencyInjection

@property (strong) BITTelemetryManager *sut;

@end

@implementation BITTelemetryManagerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    [super tearDown];
}

- (void)testTelemetryManagerGetsInstantiated {
  self.sut = [BITTelemetryManager new];
  XCTAssertNotNil(self.sut, @"Should not be nil.");
}

- (void)testNewSessionIsCreatedCorrectly {
  self.sut = [BITTelemetryManager new];
  [self.mockUserDefaults setBool:NO forKey:@"BITApplicationWasLaunched"];
  NSString *testSessionId1 = @"12345";
  NSString *testSessionId2 = @"67890";
  
  // First session
  BITSession *actualSession1 = [self.sut createNewSessionWithId:testSessionId1];
  XCTAssertEqualObjects(actualSession1.sessionId, testSessionId1);
  XCTAssertEqualObjects(actualSession1.isNew, @"true");
  XCTAssertEqualObjects(actualSession1.isFirst, @"true");
  
  // Next sessions
  BITSession *actualSession2 = [self.sut createNewSessionWithId:testSessionId2];
  XCTAssertEqualObjects(actualSession2.sessionId, testSessionId2);
  XCTAssertEqualObjects(actualSession2.isNew, @"true");
  XCTAssertEqualObjects(actualSession2.isFirst, @"false");
}

- (void)testRegisterObserversOnStart {
  self.mockNotificationCenter = mock(NSNotificationCenter.class);
  self.sut = [BITTelemetryManager new];
  [self.sut startManager];
  
  [verify((id)self.mockNotificationCenter) addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:(id)anything()];
  [verify((id)self.mockNotificationCenter) addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:(id)anything()];
}

@end
