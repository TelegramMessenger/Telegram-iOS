#import "BITTestsDependencyInjection.h"
#import <OCMock/OCMock.h>

static id testNotificationCenter;
static id mockCenter;

@implementation BITTestsDependencyInjection

- (void)setUp {
  [self setMockNotificationCenter:OCMPartialMock([NSNotificationCenter new])];
}

- (void)tearDown {
  [super tearDown];
}

# pragma mark - Helper

- (void)setMockNotificationCenter:(id)mockNotificationCenter {
  mockCenter = OCMClassMock([NSNotificationCenter class]);
  OCMStub([mockCenter defaultCenter]).andReturn(mockNotificationCenter);
  testNotificationCenter = mockNotificationCenter;
}

- (id)mockNotificationCenter {
  return testNotificationCenter;
}

@end
