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
  
  [self.sut enqueueTelemetryItem:testData];
  
  dispatch_sync(self.sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITTelemetryEventBuffer) > 0);
  });
}

- (void)testEnqueueEnvelopeWithMultipleEnvelopesAndJSONStream {
  self.sut = OCMPartialMock(self.sut);
  self.sut.maxBatchSize = 3;
  
  BITTelemetryData *testData = [BITTelemetryData new];
  
  assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(0));
  
  [self.sut enqueueTelemetryItem:testData];
  dispatch_sync(self.sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITTelemetryEventBuffer) > 0);
  });
  
  [self.sut enqueueTelemetryItem:testData];
  dispatch_sync(self.sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(2));
    XCTAssertTrue(strlen(BITTelemetryEventBuffer) > 0);
  });
  
  [self.sut enqueueTelemetryItem:testData];
  dispatch_sync(self.sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(0));
    XCTAssertTrue(strcmp(BITTelemetryEventBuffer, "") == 0);
  });
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

- (void) testBITEventBufferThreadSafety {
  int count = 1000;
  XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"append"];
  XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"reset"];
  dispatch_async(dispatch_queue_create("queue1", DISPATCH_QUEUE_SERIAL), ^{
    for(int i = 0; i < count; i++) {
      bit_appendStringToEventBuffer([NSString stringWithFormat:@"%d", i], &BITTelemetryEventBuffer);
    }
    [expectation1 fulfill];
  });
  dispatch_async(dispatch_queue_create("queue2", DISPATCH_QUEUE_SERIAL), ^{
    for(int i = 0; i < count; i++) {
      bit_resetEventBuffer(&BITTelemetryEventBuffer);
    }
    [expectation2 fulfill];
  });
  [self waitForExpectations:@[expectation1, expectation2] timeout: 10];
  XCTAssertTrue(true);
}

@end
