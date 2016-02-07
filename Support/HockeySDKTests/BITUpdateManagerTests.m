#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "BITUpdateManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"

@interface BITUpdateManagerTests : XCTestCase

@property (nonatomic, strong) BITUpdateManager *sut;

@end

@implementation BITUpdateManagerTests

- (void)setUp {
  [super setUp];
  self.sut = [[BITUpdateManager alloc] initWithAppIdentifier:@"" appEnvironment:BITEnvironmentOther];
}

- (void)testRequestForUpdateCheck {
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([mainBundleMock objectForInfoDictionaryKey:@"CFBundleVersion"]).andReturn(@"123 {Something, c0f42b3}");
  
  id mockBundle = OCMClassMock(NSBundle.class);
  OCMStub([mockBundle mainBundle]).andReturn(mainBundleMock);
  
  NSURLRequest *request = [self.sut requestForUpdateCheck];
  
  NSString *requestUrlString = request.URL.absoluteString;
  NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@" {}"];
  XCTAssertEqual([requestUrlString rangeOfCharacterFromSet:characterSet].location, NSNotFound, "URL should not contain unencoded characters");
}

@end
