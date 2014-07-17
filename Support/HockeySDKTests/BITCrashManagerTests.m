//
//  BITCrashManagerTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 25.09.13.
//
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "HockeySDKPrivate.h"
#import "BITCrashManager.h"
#import "BITCrashManagerPrivate.h"
#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"

#import "BITTestHelper.h"

#define kBITCrashMetaAttachment @"BITCrashMetaAttachment"

@interface BITCrashManagerTests : XCTestCase

@end


@implementation BITCrashManagerTests {
  BITCrashManager *_sut;
  BOOL _startManagerInitialized;
}

- (void)setUp {
  [super setUp];
  
  _startManagerInitialized = NO;
  _sut = [[BITCrashManager alloc] initWithAppIdentifier:nil isAppStoreEnvironment:NO];
}

- (void)tearDown {
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop
  
  [_sut cleanCrashReports];
  [super tearDown];
}

#pragma mark - Private

- (void)startManager {
  [_sut startManager];
  [NSObject cancelPreviousPerformRequestsWithTarget:_sut selector:@selector(invokeDelayedProcessing) object:nil];
  _startManagerInitialized = YES;
}

- (void)startManagerDisabled {
  _sut.crashManagerStatus = BITCrashManagerStatusDisabled;
  if (_startManagerInitialized) return;
  [self startManager];
}

- (void)startManagerAutoSend {
  _sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  if (_startManagerInitialized) return;
  [self startManager];
}

#pragma mark - Setup Tests

- (void)testThatItInstantiates {
  XCTAssertNotNil(_sut, @"Should be there");
}


#pragma mark - Persistence tests

- (void)testPersistUserProvidedMetaData {
  NSString *tempCrashName = @"tempCrash";
  [_sut setLastCrashFilename:tempCrashName];
  
  BITCrashMetaData *metaData = [BITCrashMetaData new];
  [metaData setUserDescription:@"Test string"];
  [_sut persistUserProvidedMetaData:metaData];
  
  NSError *error;
  NSString *description = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@.desc", [[_sut crashesDir] stringByAppendingPathComponent: tempCrashName]] encoding:NSUTF8StringEncoding error:&error];
  assertThat(description, equalTo(@"Test string"));
}

- (void)testPersistAttachment {
  NSString *filename = @"TestAttachment";
  NSData *data = [[NSData alloc] initWithBase64Encoding:@"TestData"];
  NSString* type = @"text/plain";
  
  BITHockeyAttachment *originalAttachment = [[BITHockeyAttachment alloc] initWithFilename:filename hockeyAttachmentData:data contentType:type];
  NSString *attachmentFilename = [[_sut crashesDir] stringByAppendingPathComponent:@"testAttachment"];
  
  [_sut persistAttachment:originalAttachment withFilename:attachmentFilename];
  
  BITHockeyAttachment *decodedAttachment = [_sut attachmentForCrashReport:attachmentFilename];
  
  assertThat(decodedAttachment.filename, equalTo(filename));
  assertThat(decodedAttachment.hockeyAttachmentData, equalTo(data));
  assertThat(decodedAttachment.contentType, equalTo(type));
}

#pragma mark - Helper

- (void)testUserIDForCrashReport {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  _sut.delegate = delegateMock;
  
  NSString *result = [_sut userIDForCrashReport];
  
  assertThat(result, notNilValue());
  
  [verifyCount(delegateMock, times(1)) userIDForHockeyManager:hm componentManager:_sut];
}

- (void)testUserNameForCrashReport {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  _sut.delegate = delegateMock;
  
  NSString *result = [_sut userNameForCrashReport];
  
  assertThat(result, notNilValue());
  
  [verifyCount(delegateMock, times(1)) userNameForHockeyManager:hm componentManager:_sut];
}

- (void)testUserEmailForCrashReport {
  BITHockeyManager *hm = [BITHockeyManager sharedHockeyManager];
  id delegateMock = mockProtocol(@protocol(BITHockeyManagerDelegate));
  hm.delegate = delegateMock;
  _sut.delegate = delegateMock;
  
  NSString *result = [_sut userEmailForCrashReport];
  
  assertThat(result, notNilValue());
  
  [verifyCount(delegateMock, times(1)) userEmailForHockeyManager:hm componentManager:_sut];
}

#pragma mark - Handle User Input

- (void)testHandleUserInputDontSend {
  id <BITCrashManagerDelegate> delegateMock = mockProtocol(@protocol(BITCrashManagerDelegate));
  _sut.delegate = delegateMock;
  
  assertThatBool([_sut handleUserInput:BITCrashManagerUserInputDontSend withUserProvidedMetaData:nil], equalToBool(YES));
  
  [verify(delegateMock) crashManagerWillCancelSendingCrashReport:_sut];
  
}

- (void)testHandleUserInputSend {
  assertThatBool([_sut handleUserInput:BITCrashManagerUserInputSend withUserProvidedMetaData:nil], equalToBool(YES));
}

- (void)testHandleUserInputAlwaysSend {
  id <BITCrashManagerDelegate> delegateMock = mockProtocol(@protocol(BITCrashManagerDelegate));
  _sut.delegate = delegateMock;
  NSUserDefaults *mockUserDefaults = mock([NSUserDefaults class]);
  
  //Test if CrashManagerStatus is unset
  [given([mockUserDefaults integerForKey:@"BITCrashManagerStatus"]) willReturn:nil];
  
  //Test if method runs through
  assertThatBool([_sut handleUserInput:BITCrashManagerUserInputAlwaysSend withUserProvidedMetaData:nil], equalToBool(YES));
  
  //Test if correct CrashManagerStatus is now set
  [given([mockUserDefaults integerForKey:@"BITCrashManagerStauts"]) willReturnInt:BITCrashManagerStatusAutoSend];
  
  //Verify that delegate method has been called
  [verify(delegateMock) crashManagerWillSendCrashReportsAlways:_sut];
  
}

- (void)testHandleUserInputWithInvalidInput {
  assertThatBool([_sut handleUserInput:3 withUserProvidedMetaData:nil], equalToBool(NO));
}

#pragma mark - Debugger

/**
 *  We are running this usually witin Xcode
 *  TODO: what to do if we do run this e.g. on Jenkins or Xcode bots ?
 */
- (void)testIsDebuggerAttached {
  assertThatBool([_sut isDebuggerAttached], equalToBool(YES));
}


#pragma mark - Helper

- (void)testHasPendingCrashReportWithNoFiles {
  _sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  assertThatBool([_sut hasPendingCrashReport], equalToBool(NO));
}

- (void)testFirstNotApprovedCrashReportWithNoFiles {
  _sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  assertThat([_sut firstNotApprovedCrashReport], equalTo(nil));
}


#pragma mark - StartManager

- (void)testStartManagerWithModuleDisabled {
  [self startManagerDisabled];
  
  assertThat(_sut.plCrashReporter, equalTo(nil));
}

- (void)testStartManagerWithAutoSend {
  // since PLCR is only initialized once ever, we need to pack all tests that rely on a PLCR instance
  // in this test method. Ugly but otherwise this would require a major redesign of BITCrashManager
  // which we can't do at this moment
  // This also limits us not being able to test various scenarios having a custom exception handler
  // which would require us to run without a debugger anyway and which would also require a redesign
  // to make this better testable with unit tests
  
  id delegateMock = mockProtocol(@protocol(BITCrashManagerDelegate));
  _sut.delegate = delegateMock;

  [self startManagerAutoSend];
  
  assertThat(_sut.plCrashReporter, notNilValue());
  
  // When running from the debugger this is always nil and not the exception handler from PLCR
  NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
  
  BOOL result = (_sut.exceptionHandler == currentHandler);
  
  assertThatBool(result, equalToBool(YES));
  
  // No files at startup
  assertThatBool([_sut hasPendingCrashReport], equalToBool(NO));
  assertThat([_sut firstNotApprovedCrashReport], equalTo(nil));
  
  [_sut invokeDelayedProcessing];
  
  // handle a new empty crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_empty"], equalToBool(YES));
  
  [_sut handleCrashReport];
  
  // we should have 0 pending crash report
  assertThatBool([_sut hasPendingCrashReport], equalToBool(NO));
  assertThat([_sut firstNotApprovedCrashReport], equalTo(nil));
  
  [_sut cleanCrashReports];
  
  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_signal"], equalToBool(YES));
  
  [_sut handleCrashReport];
  
  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:_sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:_sut];
  
  // we should have now 1 pending crash report
  assertThatBool([_sut hasPendingCrashReport], equalToBool(YES));
  assertThat([_sut firstNotApprovedCrashReport], notNilValue());
  
  // this is currently sending blindly, needs refactoring to test properly
  [_sut sendNextCrashReport];
  [verifyCount(delegateMock, times(1)) crashManagerWillSendCrashReport:_sut];
  
  [_sut cleanCrashReports];

  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_exception"], equalToBool(YES));
  
  [_sut handleCrashReport];
  
  // we should have now 1 pending crash report
  assertThatBool([_sut hasPendingCrashReport], equalToBool(YES));
  assertThat([_sut firstNotApprovedCrashReport], notNilValue());
  
  [_sut cleanCrashReports];
}

@end
