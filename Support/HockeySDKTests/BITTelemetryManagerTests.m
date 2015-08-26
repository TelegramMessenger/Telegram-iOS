#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "BITTestsDependencyInjection.h"
#import "BITTelemetryManager.h"
#import "BITHockeyBaseManagerPrivate.h"

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
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRegisterObserversOnStart {
  self.mockNotificationCenter = mock(NSNotificationCenter.class);
  
  self.sut = [BITTelemetryManager new];
  [self.sut startManager];
  
  [verify((id)self.mockNotificationCenter) addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:(id)anything()];
  [verify((id)self.mockNotificationCenter) addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:(id)anything()];
}

@end
