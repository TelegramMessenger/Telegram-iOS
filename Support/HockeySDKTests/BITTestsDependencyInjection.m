#import "BITTestsDependencyInjection.h"
#import <OCMock/OCMock.h>

static NSUserDefaults *mockUserDefaults;
static id testNotificationCenter;
static id mockCenter;

@implementation NSUserDefaults (UnitTests)

+ (instancetype)standardUserDefaults {
  if (!mockUserDefaults) {
    mockUserDefaults = OCMPartialMock([NSUserDefaults new]);
  }
  return mockUserDefaults;
}

@end

@implementation BITTestsDependencyInjection

- (void)setUp {
  [self setMockNotificationCenter:OCMPartialMock([NSNotificationCenter new])];
}

- (void)tearDown {
  [super tearDown];
  mockUserDefaults = nil;
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

- (void)setMockUserDefaults:(NSUserDefaults *)userDefaults {
  mockUserDefaults = userDefaults;
}

- (NSUserDefaults *)mockUserDefaults {
  return mockUserDefaults;
}

@end
