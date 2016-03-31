#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import <OCMock/OCMock.h>

#import "BITPersistencePrivate.h"
#import "BITChannelPrivate.h"
#import "BITTelemetryContext.h"
#import "BITPersistence.h"
#import "BITEnvelope.h"
#import "BITTelemetryData.h"

@interface BITChannelTests : XCTestCase

@end


@implementation BITChannelTests {
  BITChannel *_sut;
  BITPersistence *_mockPersistence;
}

- (void)setUp {
  [super setUp];
  _mockPersistence = mock(BITPersistence.class);
  BITTelemetryContext *mockContext = mock(BITTelemetryContext.class);
  
  _sut = [[BITChannel alloc]initWithTelemetryContext:mockContext persistence:_mockPersistence];
  BITSafeJsonEventsString = NULL;
}

#pragma mark - Setup Tests

- (void)testNewInstanceWasInitialisedCorrectly {
  XCTAssertNotNil([BITChannel new]);
  XCTAssertNotNil(_sut.dataItemsOperations);
}

#pragma mark - Queue management

- (void)testEnqueueEnvelopeWithOneEnvelopeAndJSONStream {
  _sut = OCMPartialMock(_sut);
  _sut.maxBatchSize = 3;
  BITTelemetryData *testData = [BITTelemetryData new];
  
  [_sut enqueueTelemetryItem:testData];
  
  dispatch_sync(_sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(_sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
  });
}

- (void)testEnqueueEnvelopeWithMultipleEnvelopesAndJSONStream {
  _sut = OCMPartialMock(_sut);
  _sut.maxBatchSize = 3;
  
  BITTelemetryData *testData = [BITTelemetryData new];
  
  assertThatUnsignedInteger(_sut.dataItemCount, equalToUnsignedInteger(0));
  
  [_sut enqueueTelemetryItem:testData];
  dispatch_sync(_sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(_sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
  });
  
  [_sut enqueueTelemetryItem:testData];
  dispatch_sync(_sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(_sut.dataItemCount, equalToUnsignedInteger(2));
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
  });
  
  [_sut enqueueTelemetryItem:testData];
  dispatch_sync(_sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(_sut.dataItemCount, equalToUnsignedInteger(0));
    XCTAssertTrue(strcmp(BITSafeJsonEventsString, "") == 0);
  });
}

#pragma mark - Safe JSON Stream Tests

- (void)testAppendStringToSafeJsonStream {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_appendStringToSafeJsonStream(nil, 0);
#pragma clang diagnostic pop
  XCTAssertTrue(BITSafeJsonEventsString == NULL);
  
  BITSafeJsonEventsString = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_appendStringToSafeJsonStream(nil, &BITSafeJsonEventsString);
#pragma clang diagnostic pop
  XCTAssertTrue(BITSafeJsonEventsString == NULL);
  
  bit_appendStringToSafeJsonStream(@"", &BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
  bit_appendStringToSafeJsonStream(@"{\"Key1\":\"Value1\"}", &BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,"{\"Key1\":\"Value1\"}\n"), 0);
}

- (void)testResetSafeJsonStream {
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
  BITSafeJsonEventsString = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_resetSafeJsonStream(nil);
#pragma clang diagnostic pop
  XCTAssertEqual(BITSafeJsonEventsString, NULL);
  
  BITSafeJsonEventsString = strdup("test string");
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
}

@end
