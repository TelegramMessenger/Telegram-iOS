//
//  BITCrashManagerTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 25.09.13.
//
//

#import <SenTestingKit/SenTestingKit.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITCrashManager.h"
#import "BITCrashManagerPrivate.h"
#import "BITHockeyBaseManager.h"
#import "BITHockeyBaseManagerPrivate.h"
#import "BITHockeyManagerPrivate.h"

#import "BITTestHelper.h"


@interface BITCrashManagerTests : SenTestCase

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
  
  _sut = nil;
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
  STAssertNotNil(_sut, @"Should be there");
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

- (void)testHasPendingCrashReports {
  _sut.crashManagerStatus = BITCrashManagerStatusAutoSend;
  
  // No files
  assertThatBool([_sut hasPendingCrashReport], equalToBool(NO));
  assertThatBool([_sut hasNonApprovedCrashReports], equalToBool(NO));
  
  // TODO: add some test files
}


#pragma mark - StartManager

- (void)testStartManagerWithModuleDisabled {
  [self startManagerDisabled];
  
  assertThat(_sut.plCrashReporter, equalTo(nil));
}

- (void)testStartManagerWithAutoSend {
  [self startManagerAutoSend];

  assertThat(_sut.plCrashReporter, notNilValue());
  
  // When running from the debugger this is always nil and not the exception handler from PLCR
  NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
  
  BOOL result = (_sut.exceptionHandler == currentHandler);
  
  assertThatBool(result, equalToBool(YES));


//  [_sut invokeDelayedProcessing];

}

@end
