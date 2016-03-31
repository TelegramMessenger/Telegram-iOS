#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "BITTelemetryContext.h"
#import "BITPersistencePrivate.h"
#import "BITApplication.h"
#import "BITDevice.h"
#import "BITInternal.h"
#import "BITUser.h"
#import "BITSession.h"

@interface BITTelemetryContextTests : XCTestCase

@end

@implementation BITTelemetryContextTests {
  BITTelemetryContext *_sut;
  BITPersistence *_mockPersistence;
}

- (void)setUp {
  [super setUp];
  
  [self initDependencies];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testThatContextObjectsNotNil {
  XCTAssertNotNil(_sut.device);
  XCTAssertNotNil(_sut.internal);
  XCTAssertNotNil(_sut.application);
  XCTAssertNotNil(_sut.session);
  XCTAssertNotNil(_sut.user);
  XCTAssertNotNil(_sut.appIdentifier);
}

- (void)testContextIsAccessible {
  _sut.deviceModel = @"Model";
  [self wait];
  XCTAssertEqualObjects(_sut.device.model, _sut.deviceModel);
  
  _sut.deviceType = @"Type";
  [self wait];
  XCTAssertEqualObjects(_sut.device.type, _sut.deviceType);
  
  _sut.osVersion = @"OsVersion";
  [self wait];
  XCTAssertEqualObjects(_sut.device.osVersion, _sut.osVersion);
  
  _sut.osName = @"Os";
  [self wait];
  XCTAssertEqualObjects(_sut.device.os, _sut.osName);
  
  _sut.deviceId = @"DeviceId";
  [self wait];
  XCTAssertEqualObjects(_sut.device.deviceId, _sut.deviceId);
  
  _sut.osLocale = @"OsLocale";
  [self wait];
  XCTAssertEqualObjects(_sut.device.locale, _sut.osLocale);
  
  _sut.osLanguage = @"OsLanguage";
  [self wait];
  XCTAssertEqualObjects(_sut.device.language, _sut.osLanguage);
  
  _sut.screenResolution = @"ScreenResolution";
  [self wait];
  XCTAssertEqualObjects(_sut.device.screenResolution, _sut.screenResolution);
  
  _sut.deviceOemName = @"OemName";
  [self wait];
  XCTAssertEqualObjects(_sut.device.oemName, _sut.deviceOemName);

  // Internal context
  _sut.sdkVersion = @"SdkVersion";
  [self wait];
  XCTAssertEqualObjects(_sut.internal.sdkVersion, _sut.sdkVersion);
  
  // Application context
  _sut.appVersion = @"Version";
  [self wait];
  XCTAssertEqualObjects(_sut.application.version, _sut.appVersion);
  
  // User context
  _sut.anonymousUserId = @"AnonymousUserId";
  [self wait];
  XCTAssertEqualObjects(_sut.user.userId, _sut.anonymousUserId);
  
  _sut.anonymousUserAquisitionDate = @"AnonymousUserAquisitionDate";
  [self wait];
  XCTAssertEqualObjects(_sut.user.anonUserAcquisitionDate, _sut.anonymousUserAquisitionDate);
  
  // Session context
  _sut.sessionId = @"SessionId";
  [self wait];
  XCTAssertEqualObjects(_sut.session.sessionId, _sut.sessionId);
  
  _sut.isFirstSession = @"IsFirstSession";
  [self wait];
  XCTAssertEqualObjects(_sut.session.isFirst, _sut.isFirstSession);
  
  _sut.isNewSession = @"IsNewSession";
  [self wait];
  XCTAssertEqualObjects(_sut.session.isNew, _sut.isNewSession);
}

- (void)testUserMetaDataGetsLoadedOnInit {
  [self initDependencies];
  
  [verify(_mockPersistence) metaData];
}

#ifndef CI
- (void)testContextDictionaryPerformance {
  [self measureBlock:^{
    for (int i = 0; i < 1000; ++i) {
      [_sut contextDictionary];
    }
  }];
}
#endif

#pragma mark - Setup helpers

- (void)initDependencies {
  _mockPersistence = mock(BITPersistence.class);
  _sut = [[BITTelemetryContext alloc] initWithAppIdentifier:@"123" persistence:_mockPersistence];
}

-(void)wait {
  // Setters use dispatch_barrier_async so we have to wait a bit for the value change
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
}

@end

