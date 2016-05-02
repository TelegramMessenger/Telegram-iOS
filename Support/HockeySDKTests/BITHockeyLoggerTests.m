#import <XCTest/XCTest.h>
#import "OCMock.h"
#import "BITHockeyLoggerPrivate.h"

static char *const testFile = "Filename";
static char *const testFunction = "Function name";
static uint const testLine = 42;

@interface BITHockeyLoggerTests : XCTestCase

@end

@implementation BITHockeyLoggerTests

// Set default log handler after every test to avoid interferences
- (void)tearDown {
  [BITHockeyLogger setLogHandler:defaultLogHandler];
  [super tearDown];
}

- (void)testInitialLogLevel {
  XCTAssertEqual([BITHockeyLogger currentLogLevel], BITLogLevelWarning);
}

- (void)testSetCurrentLogLevel {
  [BITHockeyLogger setCurrentLogLevel:BITLogLevelNone];
  XCTAssertEqual([BITHockeyLogger currentLogLevel], BITLogLevelNone);
}

- (void)testSetLogHandler {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expected logHandler to be called"];
  BITLogHandler testLogHandler = ^(BITLogMessageProvider messageProvider, BITLogLevel logLevel, const char *file, const char *function, uint line) {
    [expectation fulfill];
  };

  [BITHockeyLogger setLogHandler:testLogHandler];

  [BITHockeyLogger logMessage:^{ return @"Test"; } level:BITLogLevelError file:testFile function:testFunction line:testLine];

  [self waitForExpectationsWithTimeout:0 handler:nil];
}

#pragma mark - Test Default LogHandler

- (void)testLogLevelNone {
  [BITHockeyLogger setCurrentLogLevel:BITLogLevelNone];

  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelError file:testFile function:testFunction line:testLine];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelWarning file:testFile function:testFunction line:testLine];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelDebug file:testFile function:testFunction line:testLine];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelVerbose file:testFile function:testFunction line:testLine];
}

- (void)testLogLevelError {
  XCTestExpectation *expectation = [self expectationWithDescription:@"An error message should have been logged"];
  [BITHockeyLogger setCurrentLogLevel:BITLogLevelError];
  
  [BITHockeyLogger logMessage:^NSString * {
    [expectation fulfill];
    return nil;
  } level:BITLogLevelError file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelWarning file:testFile function:testFunction line:testLine];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelDebug file:testFile function:testFunction line:testLine];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelVerbose file:testFile function:testFunction line:testLine];
}

- (void)testLogLevelWarning {
  [BITHockeyLogger setCurrentLogLevel:BITLogLevelWarning];

  XCTestExpectation *expectation1 = [self expectationWithDescription:@"An error message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation1 fulfill];
    return nil;
  } level:BITLogLevelError file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];
  
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"A warning message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation2 fulfill];
    return nil;
  } level:BITLogLevelWarning file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];
  
  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelDebug file:testFile function:testFunction line:testLine];

  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelVerbose file:testFile function:testFunction line:testLine];
}

- (void)testLogLevelDebug {
  [BITHockeyLogger setCurrentLogLevel:BITLogLevelDebug];
  
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"An error message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation1 fulfill];
    return nil;
  } level:BITLogLevelError file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];
  
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"A warning message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation2 fulfill];
    return nil;
  } level:BITLogLevelWarning file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"A debug message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation3 fulfill];
    return nil;
  } level:BITLogLevelDebug file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];

  [BITHockeyLogger logMessage:^NSString * {
    XCTFail(@"This should not be called");
    return nil;
  } level:BITLogLevelVerbose file:testFile function:testFunction line:testLine];
}

- (void)testLogLevelVerbose {
  [BITHockeyLogger setCurrentLogLevel:BITLogLevelVerbose];
  
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"An error message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation1 fulfill];
    return nil;
  } level:BITLogLevelError file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];
  
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"A warning message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation2 fulfill];
    return nil;
  } level:BITLogLevelWarning file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"A debug message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation3 fulfill];
    return nil;
  } level:BITLogLevelDebug file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];

  XCTestExpectation *expectation4 = [self expectationWithDescription:@"A verbose message should have been logged"];
  [BITHockeyLogger logMessage:^NSString * {
    [expectation4 fulfill];
    return nil;
  } level:BITLogLevelVerbose file:testFile function:testFunction line:testLine];
  [self waitForExpectationsWithTimeout:0 handler:nil];
}
@end
