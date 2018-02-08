#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import <OCMock/OCMock.h>

#import "BITPersistencePrivate.h"
#import "BITChannelPrivate.h"
#import "BITTelemetryContext.h"
#import "BITPersistence.h"
#import "BITEnvelope.h"
#import "BITTelemetryData.h"

@interface BITChannelTests : XCTestCase

@property(nonatomic, strong) BITChannel *sut;
@property(nonatomic, strong) BITPersistence *mockPersistence;

@end

@implementation BITChannelTests

- (void)setUp {
  [super setUp];
  self.mockPersistence = OCMPartialMock([[BITPersistence alloc] init]);
  BITTelemetryContext *mockContext = mock(BITTelemetryContext.class);
  
  self.sut = [[BITChannel alloc]initWithTelemetryContext:mockContext persistence:self.mockPersistence];
  bit_resetEventBuffer(&BITTelemetryEventBuffer);
}

#pragma mark - Setup Tests

- (void)testNewInstanceWasInitialisedCorrectly {
  XCTAssertNotNil([BITChannel new]);
  XCTAssertNotNil(self.sut.dataItemsOperations);
}

#pragma mark - Queue management

- (void)testEnqueueEnvelopeWithOneEnvelopeAndJSONStream {
  self.sut = OCMPartialMock(self.sut);
  self.sut.maxBatchSize = 3;
  BITTelemetryData *testData = [BITTelemetryData new];
  
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Enqueued a telemetry item."];
  
  [self.sut enqueueTelemetryItem:testData completionHandler:^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITTelemetryEventBuffer) > 0);
    
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

- (void)testEnqueueEnvelopeWithMultipleEnvelopesAndJSONStream {
  self.sut = OCMPartialMock(self.sut);
  self.sut.maxBatchSize = 3;
  
  BITTelemetryData *testData = [BITTelemetryData new];
  
  assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(0));
  
  __weak XCTestExpectation *expectation = [self expectationWithDescription:@"Enqueued a telemetry item."];
  
  [self.sut enqueueTelemetryItem:testData completionHandler:^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITTelemetryEventBuffer) > 0);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  
  expectation = [self expectationWithDescription:@"Enqueued a second telemetry item."];

  [self.sut enqueueTelemetryItem:testData completionHandler:^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(2));
    XCTAssertTrue(strlen(BITTelemetryEventBuffer) > 0);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
  
  expectation = [self expectationWithDescription:@"Enqueued a third telemetry item."];
  
  [self.sut enqueueTelemetryItem:testData completionHandler:^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(0));
    XCTAssertTrue(strcmp(BITTelemetryEventBuffer, "") == 0);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:5.0
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@", error);
                                 }
                               }];
}

#pragma mark - Safe JSON Stream Tests

- (void)testAppendStringToEventBuffer {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_appendStringToEventBuffer(nil, 0);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,""), 0);
  
  bit_resetEventBuffer(&BITTelemetryEventBuffer);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_appendStringToEventBuffer(nil, &BITTelemetryEventBuffer);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,""), 0);
  
  bit_appendStringToEventBuffer(@"", &BITTelemetryEventBuffer);
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,""), 0);
  
  bit_appendStringToEventBuffer(@"{\"Key1\":\"Value1\"}", &BITTelemetryEventBuffer);
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,"{\"Key1\":\"Value1\"}\n"), 0);
}

- (void)testResetSafeJsonStream {
  bit_resetEventBuffer(&BITTelemetryEventBuffer);
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,""), 0);
  
  bit_resetEventBuffer(&BITTelemetryEventBuffer);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_resetEventBuffer(nil);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,""), 0);
  
  BITTelemetryEventBuffer = strdup("test string");
  bit_resetEventBuffer(&BITTelemetryEventBuffer);
  XCTAssertEqual(strcmp(BITTelemetryEventBuffer,""), 0);
}

@end
