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

@property(nonatomic, strong) BITTelemetryContext *sut;
@property(nonatomic, strong) BITPersistence *mockPersistence;

@end

@implementation BITTelemetryContextTests

- (void)setUp {
  [super setUp];
  
  [self initDependencies];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testThatContextObjectsNotNil {
  XCTAssertNotNil(self.sut.device);
  XCTAssertNotNil(self.sut.internal);
  XCTAssertNotNil(self.sut.application);
  XCTAssertNotNil(self.sut.session);
  XCTAssertNotNil(self.sut.user);
  XCTAssertNotNil(self.sut.appIdentifier);
}

- (void)testUserMetaDataGetsLoadedOnInit {
  [self initDependencies];
  
  [verify(self.mockPersistence) metaData];
}

#ifndef CI
- (void)testContextDictionaryPerformance {
  [self measureBlock:^{
    for (int i = 0; i < 1000; ++i) {
      [self.sut contextDictionary];
    }
  }];
}
#endif

#pragma mark - Setup helpers

- (void)initDependencies {
  self.mockPersistence = mock(BITPersistence.class);
  self.sut = [[BITTelemetryContext alloc] initWithAppIdentifier:@"123" persistence:self.mockPersistence];
}

-(void)wait {
  // Setters use dispatch_barrier_async so we have to wait a bit for the value change
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.001]];
}

@end

