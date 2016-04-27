#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
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

