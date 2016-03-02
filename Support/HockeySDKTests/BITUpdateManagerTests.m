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
  self.sut = [[BITUpdateManager alloc] initWithAppIdentifier:@"testIdentifier" appEnvironment:BITEnvironmentOther];
}

- (void)testRequestForUpdateCheck {
  // Given
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  OCMStub([mainBundleMock objectForInfoDictionaryKey:@"CFBundleVersion"]).andReturn(@"123 {Something, c0f42b3}");
  
  id mockBundle = OCMClassMock(NSBundle.class);
  OCMStub([mockBundle mainBundle]).andReturn(mainBundleMock);
  
  NSString *testInstallationIdentificationType = @"SomeInstallationIdentificationType";
  NSString *testInstallationIdentification = @"SpecificInstallationIdentification";
  self.sut.installationIdentificationType = testInstallationIdentificationType;
  self.sut.installationIdentification = testInstallationIdentification;
  
  
  NSURLRequest *request = [self.sut requestForUpdateCheck];
  
  XCTAssertTrue(self.sut.sendUsageData);
  
  // Test HTTP header
  XCTAssertEqualObjects(request.HTTPMethod, @"GET");
  XCTAssertEqualObjects([request valueForHTTPHeaderField:@"User-Agent"], @"Hockey/iOS");
  XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Accept-Encoding"], @"gzip");
  
  XCTAssertEqual(request.cachePolicy, NSURLRequestReloadIgnoringCacheData);
  XCTAssertEqual(request.timeoutInterval, 10.0);
  
  // Test URL parts
  XCTAssertEqualObjects(request.URL.host, @"sdk.hockeyapp.net");
  XCTAssertEqualObjects(request.URL.path, @"/api/2/apps/testIdentifier");

  NSString *identificationString = [NSString stringWithFormat:@"%@=%@", testInstallationIdentificationType, testInstallationIdentification];
  XCTAssertTrue([request.URL.query containsString:identificationString]);
  
  // Test identification and usage not present
  self.sut.installationIdentificationType = nil;
  self.sut.installationIdentification = nil;
  self.sut.sendUsageData = NO;
  
  request = [self.sut requestForUpdateCheck];
  
  XCTAssertFalse([request.URL.query containsString:@"app_version="]);
  XCTAssertFalse([request.URL.query containsString:@"os=iOS"]);
  XCTAssertFalse([request.URL.query containsString:@"os_version="]);
  XCTAssertFalse([request.URL.query containsString:@"device="]);
  XCTAssertFalse([request.URL.query containsString:@"lang="]);
  XCTAssertFalse([request.URL.query containsString:@"first_start_at="]);
  XCTAssertFalse([request.URL.query containsString:@"usage_time="]);
  XCTAssertFalse([request.URL.query containsString:identificationString]);
  
  // Test URL encoding
  NSString *requestUrlString = request.URL.absoluteString;
  NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@" {}"];
  XCTAssertEqual([requestUrlString rangeOfCharacterFromSet:characterSet].location, NSNotFound, "URL should not contain unencoded characters");
}

@end
