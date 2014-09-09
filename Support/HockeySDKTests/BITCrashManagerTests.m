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

- (void)testHasNonApprovedCrashReportsWithNoFiles {
  _sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  assertThatBool([_sut hasNonApprovedCrashReports], equalToBool(NO));
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
  assertThatBool([_sut hasNonApprovedCrashReports], equalToBool(NO));
  
  [_sut invokeDelayedProcessing];
  
  // handle a new empty crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_empty"], equalToBool(YES));
  
  [_sut handleCrashReport];
  
  // we should have 0 pending crash report
  assertThatBool([_sut hasPendingCrashReport], equalToBool(NO));
  assertThatBool([_sut hasNonApprovedCrashReports], equalToBool(NO));
  
  [_sut cleanCrashReports];
  
  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_signal"], equalToBool(YES));
  
  [_sut handleCrashReport];
  
  [verifyCount(delegateMock, times(1)) applicationLogForCrashManager:_sut];
  [verifyCount(delegateMock, times(1)) attachmentForCrashManager:_sut];
  
  // we should have now 1 pending crash report
  assertThatBool([_sut hasPendingCrashReport], equalToBool(YES));
  assertThatBool([_sut hasNonApprovedCrashReports], equalToBool(YES));
  
  // this is currently sending blindly, needs refactoring to test properly
  [_sut sendCrashReports];
  [verifyCount(delegateMock, times(1)) crashManagerWillSendCrashReport:_sut];
  
  [_sut cleanCrashReports];

  // handle a new signal crash report
  assertThatBool([BITTestHelper copyFixtureCrashReportWithFileName:@"live_report_exception"], equalToBool(YES));
  
  [_sut handleCrashReport];
  
  // we should have now 1 pending crash report
  assertThatBool([_sut hasPendingCrashReport], equalToBool(YES));
  assertThatBool([_sut hasNonApprovedCrashReports], equalToBool(YES));
  
  [_sut cleanCrashReports];
}

@end
