//
//  BITCrashManagerTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 25.09.13.
//
//

#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITCrashManager.h"
#import "BITCrashManagerPrivate.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITPersistence.h"

#import "BITTestHelper.h"
#import "BITHockeyAppClient.h"


static NSString *const kBITCrashMetaAttachment = @"BITCrashMetaAttachment";

@interface BITCrashManagerTests : XCTestCase

@property BITCrashManager *sut;
@property BOOL startManagerInitialized;

@end


@implementation BITCrashManagerTests {

}

- (void)setUp {
  [super setUp];
  
  self.startManagerInitialized = NO;
  self.sut = [[BITCrashManager alloc] initWithAppIdentifier:nil appEnvironment:BITEnvironmentOther hockeyAppClient:[[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString: BITHOCKEYSDK_URL]]];
}

- (void)tearDown {
  [self.sut cleanCrashReports];
  [super tearDown];
}

#pragma mark - Private

- (void)startManager {
  [self.sut startManager];
  [NSObject cancelPreviousPerformRequestsWithTarget:self.sut selector:@selector(invokeDelayedProcessing) object:nil];
  self.startManagerInitialized = YES;
}

- (void)startManagerDisabled {
  self.sut.crashManagerStatus = BITCrashManagerStatusDisabled;
  if (self.startManagerInitialized) return;
  [self startManager];
}

- (void)startManagerAutoSend {
  // Set mocks to prevent errors in `-configDefaultCrashCallback`
  id metricsManagerMock = mock([BITMetricsManager class]);
  [given([metricsManagerMock persistence]) willReturn:[[BITPersistence alloc] init]];
  [[BITHockeyManager sharedHockeyManager] setValue:metricsManagerMock forKey:@"metricsManager"];
  
  self.sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  if (self.startManagerInitialized) return;
  [self startManager];
}

#pragma mark - Setup Tests

- (void)testThatItInstantiates {
  XCTAssertNotNil(self.sut, @"Should be there");
}

#pragma mark - Getter/Setter tests

- (void)testSetServerURL {
  BITHockeyAppClient *client = self.sut.hockeyAppClient;
  NSURL *hockeyDefaultURL = [NSURL URLWithString:BITHOCKEYSDK_URL];
  XCTAssertEqualObjects(self.sut.hockeyAppClient.baseURL, hockeyDefaultURL);
  
  [self.sut setServerURL:BITHOCKEYSDK_URL];
  XCTAssertEqual(self.sut.hockeyAppClient, client, @"HockeyAppClient should stay the same when setting same URL again");
  XCTAssertEqualObjects(self.sut.hockeyAppClient.baseURL, hockeyDefaultURL);
  
  NSString *testURLString = @"http://example.com";
  [self.sut setServerURL:testURLString];
  XCTAssertNotEqual(self.sut.hockeyAppClient, client, @"Should have created a new instance of BITHockeyAppClient");
  XCTAssertEqualObjects(self.sut.hockeyAppClient.baseURL, [NSURL URLWithString:testURLString]);
}

#pragma mark - Persistence tests

- (void)testPersistUserProvidedMetaData {
  NSString *tempCrashName = @"tempCrash";
  [self.sut setLastCrashFilename:tempCrashName];
  
  BITCrashMetaData *metaData = [BITCrashMetaData new];
  [metaData setUserProvidedDescription:@"Test string"];
  [self.sut persistUserProvidedMetaData:metaData];
  
  NSError *error;
  NSString *description = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@.desc", [[self.sut crashesDir] stringByAppendingPathComponent: tempCrashName]] encoding:NSUTF8StringEncoding error:&error];
  assertThat(description, equalTo(@"Test string"));
}

- (void)testPersistAttachment {
  NSString *filename = @"TestAttachment";
  NSData *data = [[NSData alloc] initWithBase64EncodedString:@"TestData" options:0];

  NSString* type = @"text/plain";
  
  BITHockeyAttachment *originalAttachment = [[BITHockeyAttachment alloc] initWithFilename:filename hockeyAttachmentData:data contentType:type];
  NSString *attachmentFilename = [[self.sut crashesDir] stringByAppendingPathComponent:@"testAttachment"];
  
  [self.sut persistAttachment:originalAttachment withFilename:attachmentFilename];
  
  BITHockeyAttachment *decodedAttachment = [self.sut attachmentForCrashReport:attachmentFilename];
  
  assertThat(decodedAttachment.filename, equalTo(filename));
  assertThat(decodedAttachment.hockeyAttachmentData, equalTo(data));
  assertThat(decodedAttachment.contentType, equalTo(type));
}

#pragma mark - Helper

- (void)testUserIDForCrashReport {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  self.sut.delegate = delegateMock;
  
  NSString *result = [self.sut userIDForCrashReport];
  
  assertThat(result, notNilValue());
  
  [verifyCount(delegateMock, times(1)) userIDForHockeyManager:hm componentManager:self.sut];
}

- (void)testUserNameForCrashReport {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  self.sut.delegate = delegateMock;
  
  NSString *result = [self.sut userNameForCrashReport];
  
  assertThat(result, notNilValue());
  
  [verifyCount(delegateMock, times(1)) userNameForHockeyManager:hm componentManager:self.sut];
}

- (void)testUserEmailForCrashReport {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  self.sut.delegate = delegateMock;
  
  NSString *result = [self.sut userEmailForCrashReport];
  
  assertThat(result, notNilValue());
  
  [verifyCount(delegateMock, times(1)) userEmailForHockeyManager:hm componentManager:self.sut];
}

#pragma mark - Handle User Input

- (void)testHandleUserInputDontSend {
  id <BITCrashManagerDelegate> delegateMock = mockProtocol(@protocol(BITCrashManagerDelegate));
  self.sut.delegate = delegateMock;
  
  assertThatBool([self.sut handleUserInput:BITCrashManagerUserInputDontSend withUserProvidedMetaData:nil], isTrue());
  
  [verify(delegateMock) crashManagerWillCancelSendingCrashReport:self.sut];
  
}

- (void)testHandleUserInputSend {
  assertThatBool([self.sut handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:nil], isTrue());
}

- (void)testHandleUserInputAlwaysSend {
  id <BITCrashManagerDelegate> delegateMock = mockProtocol(@protocol(BITCrashManagerDelegate));
  self.sut.delegate = delegateMock;
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  
  //Test if CrashManagerStatus is unset
  [given([mockUserDefaults integerForKey:@"BITCrashManagerStatus"]) willReturn:nil];
  
  //Test if method runs through
  assertThatBool([self.sut handleUserInput:BITCrashManagerUserInputAlwaysSend withUserProvidedMetaData:nil], isTrue());
  
  //Test if correct CrashManagerStatus is now set
  [given([mockUserDefaults integerForKey:@"BITCrashManagerStauts"]) willReturnInt:BITCrashManagerStatusAutoSend];
  
  //Verify that delegate method has been called
  [verify(delegateMock) crashManagerWillSendCrashReportsAlways:self.sut];
  
}

- (void)testHandleUserInputWithInvalidInput {
  assertThatBool([self.sut handleUserInput:3 withUserProvidedMetaData:nil], isFalse());
}

#pragma mark - Debugger
/**
 * The test is currently disabled because it fails for unknown reasons when being run using xcodebuild.
 * This occurs for example on our current CI solution. Will be reenabled as soon as we find a fix.
*/
#ifndef CI
/**
 *  We are running this usually witin Xcode
 *  TODO: what to do if we do run this e.g. on Jenkins or Xcode bots ?
 */
- (void)testIsDebuggerAttached {
  assertThatBool([self.sut isDebuggerAttached], isTrue());
}
#endif

#pragma mark - Helper

- (void)testHasPendingCrashReportWithNoFiles {
  self.sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  assertThatBool([self.sut hasPendingCrashReport], isFalse());
}

- (void)testFirstNotApprovedCrashReportWithNoFiles {
  self.sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  assertThat([self.sut firstNotApprovedCrashReport], equalTo(nil));
}


#pragma mark - StartManager

- (void)testStartManagerWithModuleDisabled {
  [self startManagerDisabled];
  
  assertThat(self.sut.plCrashReporter, equalTo(nil));
}

- (void)testStartManagerWithAutoSend {
  // since PLCR is only initialized once ever, we need to pack all tests that rely on a PLCR instance
  // in this test method. Ugly but otherwise this would require a major redesign of BITCrashManager
  // which we can't do at this moment
  // This also limits us not being able to test various scenarios having a custom exception handler
  // which would require us to run without a debugger anyway and which would also require a redesign
  // to make this better testable with unit tests
  
  id delegateMock = mockProtocol(@protocol(BITCrashManagerDelegate));
  self.sut.delegate = delegateMock;

  [self startManagerAutoSend];
  
  assertThat(self.sut.plCrashReporter, notNilValue());
  
  // When running from the debugger this is always nil and not the exception handler from PLCR
  NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
  
  BOOL result = (self.sut.exceptionHandler == currentHandler);
  
  assertThatBool(result, isTrue());
  
  // No files at startup
  assertThatBool([self.sut hasPendingCrashReport], isFalse());
  assertThat([self.sut firstNotApprovedCrashReport], equalTo(nil));
  
  [self.sut invokeDelayedProcessing];
  
  // handle a new empty crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_empty"], isTrue());
  
  [self.sut handleCrashReport];
  
  // we should have 0 pending crash report
  assertThatBool([self.sut hasPendingCrashReport], isFalse());
  assertThat([self.sut firstNotApprovedCrashReport], equalTo(nil));
  
  [self.sut cleanCrashReports];
  
  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_signal"], isTrue());
  
  [self.sut handleCrashReport];

  // this old report doesn't have a marketing version present
  assertThat(self.sut.lastSessionCrashDetails.appVersion, equalTo(nil));

  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:self.sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:self.sut];
  
  // we should have now 1 pending crash report
  assertThatBool([self.sut hasPendingCrashReport], isTrue());
  assertThat([self.sut firstNotApprovedCrashReport], notNilValue());
  
  // this is currently sending blindly, needs refactoring to test properly
  [self.sut sendNextCrashReport];
  [verifyCount(delegateMock, times(1)) crashManagerWillSendCrashReport:self.sut];
  
  [self.sut cleanCrashReports];

  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  
  [self.sut handleCrashReport];
  
  // this old report doesn't have a marketing version present
  assertThat(self.sut.lastSessionCrashDetails.appVersion, equalTo(nil));
  
  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:self.sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:self.sut];
  
  // we should have now 1 pending crash report
  assertThatBool([self.sut hasPendingCrashReport], isTrue());
  assertThat([self.sut firstNotApprovedCrashReport], notNilValue());
  
  [self.sut cleanCrashReports];
  
  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_signal_marketing"], isTrue());
  
  [self.sut handleCrashReport];
  
  // this old report doesn't have a marketing version present
  assertThat(self.sut.lastSessionCrashDetails.appVersion, notNilValue());
  
  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:self.sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:self.sut];
  
  // we should have now 1 pending crash report
  assertThatBool([self.sut hasPendingCrashReport], isTrue());
  assertThat([self.sut firstNotApprovedCrashReport], notNilValue());
  
  // this is currently sending blindly, needs refactoring to test properly
  [self.sut sendNextCrashReport];
  [verifyCount(delegateMock, times(1)) crashManagerWillSendCrashReport:self.sut];
  
  [self.sut cleanCrashReports];
  
  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_exception_marketing"], isTrue());
  
  [self.sut handleCrashReport];
  
  // this old report doesn't have a marketing version present
  assertThat(self.sut.lastSessionCrashDetails.appVersion, notNilValue());
  
  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:self.sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:self.sut];
  
  // we should have now 1 pending crash report
  assertThatBool([self.sut hasPendingCrashReport], isTrue());
  assertThat([self.sut firstNotApprovedCrashReport], notNilValue());
  
  [self.sut cleanCrashReports];
  
  // handle a new xamarin crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_xamarin"], isTrue());
  
  [self.sut handleCrashReport];
  
  // this old report doesn't have a marketing version present
  assertThat(self.sut.lastSessionCrashDetails.appVersion, notNilValue());
  
  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:self.sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:self.sut];
  
  // we should have now 1 pending crash report
  assertThatBool([self.sut hasPendingCrashReport], isTrue());
  assertThat([self.sut firstNotApprovedCrashReport], notNilValue());
  
  [self.sut cleanCrashReports];
}

@end
