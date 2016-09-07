#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "BITTestsDependencyInjection.h"
#import "BITMetricsManager.h"
#import "BITMetricsManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITSession.h"
#import "BITChannelPrivate.h"
#import "BITTelemetryContext.h"
#import "BITSessionStateData.h"

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface BITMetricsManagerTests : BITTestsDependencyInjection

@property (strong) BITMetricsManager *sut;

@end

@implementation BITMetricsManagerTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
  [super tearDown];
}

- (void)testMetricsManagerGetsInstantiated {
  self.sut = [BITMetricsManager new];
  XCTAssertNotNil(self.sut, @"Should not be nil.");
}

- (void)testDependenciesAreCreatedCorrectly {
  self.sut = [BITMetricsManager new];
  
  BITPersistence *persistence = self.sut.persistence;
  XCTAssertNotNil(persistence);
  
  BITTelemetryContext *context = self.sut.telemetryContext;
  XCTAssertNotNil(persistence);
  XCTAssertEqualObjects(persistence, context.persistence);
  
  BITChannel *channel = self.sut.channel;
  XCTAssertNotNil(persistence);
  XCTAssertEqualObjects(persistence, channel.persistence);
  XCTAssertEqualObjects(context, channel.telemetryContext);
}

- (void)testNewSessionIsCreatedCorrectly {
  NSUserDefaults *testUserDefaults = [NSUserDefaults new];
  [testUserDefaults setBool:NO forKey:kBITApplicationWasLaunched];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.sut = [[BITMetricsManager alloc] initWithChannel:nil telemetryContext:nil persistence:nil userDefaults:testUserDefaults];
#pragma clang diagnostic pop
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
  self.sut = [BITMetricsManager new];
  [self.sut startManager];
  
  [verify((id)self.mockNotificationCenter) addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:(id)anything()];
  [verify((id)self.mockNotificationCenter) addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:(id)anything()];
}

- (void)testTrackSessionEnqueuesObject {
  BITChannel *channel = [BITChannel new];
  id mockChannel = OCMPartialMock(channel);
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.sut = [[BITMetricsManager alloc] initWithChannel:mockChannel telemetryContext:nil persistence:nil userDefaults:nil];
#pragma clang diagnostic pop
  
  OCMExpect([mockChannel enqueueTelemetryItem:[OCMArg checkWithBlock:^BOOL(NSObject *value)
                                               {
                                                 return [value isKindOfClass:[BITSessionStateData class]];
                                               }]]);
  [self.sut trackSessionWithState:BITSessionState_start];
  OCMVerifyAll(mockChannel);
}

- (void)testNewSessionUpdatesSessionContext {
  BITTelemetryContext *context = [BITTelemetryContext new];
  id mockContext = OCMPartialMock(context);
  NSUserDefaults *testUserDefaults = [NSUserDefaults new];
  [testUserDefaults setBool:NO forKey:kBITApplicationWasLaunched];
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.sut = [[BITMetricsManager alloc] initWithChannel:nil telemetryContext:mockContext persistence:nil userDefaults:testUserDefaults];
#pragma clang diagnostic pop
  
  NSString *testSessionId = @"sessionId";
  
  OCMExpect([mockContext setSessionId:testSessionId]);
  OCMExpect([mockContext setIsNewSession:@"true"]);
  OCMExpect([mockContext setIsFirstSession:@"true"]);
  
  [self.sut startNewSessionWithId:testSessionId];
  OCMVerifyAll(mockContext);
}

- (void)testNewSessionCreated {
  NSUserDefaults *testUserDefaults = [NSUserDefaults new];
  BITTelemetryContext *context = [BITTelemetryContext new];
  
  BITChannel *channel = [BITChannel new];
  id mockChannel = OCMPartialMock(channel);
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.sut = [[BITMetricsManager alloc] initWithChannel:mockChannel telemetryContext:context persistence:nil userDefaults:testUserDefaults];
#pragma clang diagnostic pop

  int sessionStartCount = 0;
  int sessionNotRenewedCount = 0;
  
  for(int i = 0; i < 100; i++) {
    double randomOffset = (i%2 == 0) ? arc4random_uniform(1000 - 20 + 1) + 20 : arc4random_uniform(19 - 0 + 1) + 0;
    double backgroundtime = [[NSDate date] timeIntervalSince1970] - randomOffset;
    [testUserDefaults setDouble:backgroundtime forKey:@"BITApplicationDidEnterBackgroundTime"];
    
    [self.sut startNewSessionIfNeeded];
    
    NSLog(@"Test iteration %i", i);

    
    if(randomOffset >= 20.0) {
      NSLog(@"Calling OCMVerify for %f", randomOffset);
      OCMVerify([mockChannel enqueueTelemetryItem:anything()]);
      sessionStartCount +=1;
    }
    else {
      NSLog(@"Calling OCMReject for %f", randomOffset);
      // we cant OCMReject for the mockChannel as it will fail because enqueueTelemetryItem has been invoked before for all
      // randomOffset >= 20.
      sessionNotRenewedCount +=1;
    }
  }
  
  // Ac we can't use OCMReject, at least verify the counts of the cases.
  XCTAssertEqual(sessionStartCount, 50);
  XCTAssertEqual(sessionNotRenewedCount, 50);
}

- (void)testNewSessionNeverCreated {
  NSUserDefaults *testUserDefaults = [NSUserDefaults new];
  BITTelemetryContext *context = [BITTelemetryContext new];
  
  BITChannel *channel = [BITChannel new];
  id mockChannel = OCMPartialMock(channel);
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  self.sut = [[BITMetricsManager alloc] initWithChannel:mockChannel telemetryContext:context persistence:nil userDefaults:testUserDefaults];
#pragma clang diagnostic pop
  
  int sessionStartCount = 0;
  int sessionNotRenewedCount = 0;
  for(int i = 0; i < 100; i++) {
    double randomOffset = (i%2 == 0) ? arc4random_uniform(19 - 0 + 1) + 0 : arc4random_uniform(19 - 0 + 1) + 0;
    double backgroundtime = [[NSDate date] timeIntervalSince1970] - randomOffset;
    [testUserDefaults setDouble:backgroundtime forKey:@"BITApplicationDidEnterBackgroundTime"];
    
    [self.sut startNewSessionIfNeeded];
    
    NSLog(@"Test iteration %i", i);
    
    if(randomOffset >= 20.0) {
      NSLog(@"Calling OCMVerify for %f", randomOffset);
      OCMVerify([mockChannel enqueueTelemetryItem:anything()]);
      sessionStartCount +=1;
    }
    else {
      NSLog(@"Calling OCMReject for %f", randomOffset);
      OCMReject([mockChannel enqueueTelemetryItem:anything()]);
      sessionNotRenewedCount +=1;
    }
  }
  
  XCTAssertEqual(sessionStartCount, 0);
  XCTAssertEqual(sessionNotRenewedCount, 100);
}


@end
