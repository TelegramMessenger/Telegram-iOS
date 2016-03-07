#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import <OCMock/OCMock.h>

#import "BITPersistencePrivate.h"
#import "BITChannel.h"
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
}

#pragma mark - Setup Tests

- (void)testNewInstanceWasInitialisedCorrectly {
  XCTAssertNotNil([BITChannel new]);
  XCTAssertNotNil(_sut.dataItemsOperations);
}

#pragma mark - Queue management

- (void)testEnqueueEnvelopeWithOneEnvelopeAndJSONStream {
  _sut = OCMPartialMock(_sut);
  _sut.maxBatchCount = 3;
  BITTelemetryData *testData = [BITTelemetryData new];
  
  [_sut enqueueTelemetryItem:testData];
  
  dispatch_sync(_sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(_sut.dataItemCount, equalToUnsignedInteger(1));
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
  });
}

- (void)testEnqueueEnvelopeWithMultipleEnvelopesAndJSONStream {
  _sut = OCMPartialMock(_sut);
  _sut.maxBatchCount = 3;
  
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
  BITSafeJsonEventsString = bit_jsonStreamByAppendingJsonString(0, nil);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString, ""), 0);
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
 BITSafeJsonEventsString = bit_jsonStreamByAppendingJsonString(NULL, nil);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString, ""), 0);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  BITSafeJsonEventsString = bit_jsonStreamByAppendingJsonString(nil, nil);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString, ""), 0);
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  BITSafeJsonEventsString = bit_jsonStreamByAppendingJsonString(NULL, @"");
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
  BITSafeJsonEventsString = bit_jsonStreamByAppendingJsonString("", @"{\"Key1\":\"Value1\"}");
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,"{\"Key1\":\"Value1\"}\n"), 0);
}

- (void)testResetSafeJsonStream {
  BITSafeJsonEventsString = NULL;
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_resetSafeJsonStream(NULL);
#pragma clang diagnostic pop
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_resetSafeJsonStream(nil);
#pragma clang diagnostic pop
  
  BITSafeJsonEventsString = strdup("test string");
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
}

@end
