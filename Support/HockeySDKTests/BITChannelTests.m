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
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
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
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
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
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
  });
  
  [self.sut enqueueTelemetryItem:testData];
  dispatch_sync(self.sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(2));
    XCTAssertTrue(strlen(BITSafeJsonEventsString) > 0);
  });
  
  [self.sut enqueueTelemetryItem:testData];
  dispatch_sync(self.sut.dataItemsOperations, ^{
    assertThatUnsignedInteger(self.sut.dataItemCount, equalToUnsignedInteger(0));
    XCTAssertTrue(strcmp(BITSafeJsonEventsString, "") == 0);
  });
}

#pragma mark - Safe JSON Stream Tests

- (void)testAppendStringToSafeJsonStream {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_appendStringToSafeJsonStream(nil, 0);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
//  BITSafeJsonEventsString = NULL;
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_appendStringToSafeJsonStream(nil, &BITSafeJsonEventsString);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
  bit_appendStringToSafeJsonStream(@"", &BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
  bit_appendStringToSafeJsonStream(@"{\"Key1\":\"Value1\"}", &BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,"{\"Key1\":\"Value1\"}\n"), 0);
}

- (void)testResetSafeJsonStream {
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
//  BITSafeJsonEventsString = NULL;
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  bit_resetSafeJsonStream(nil);
#pragma clang diagnostic pop
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
  
  BITSafeJsonEventsString = strdup("test string");
  bit_resetSafeJsonStream(&BITSafeJsonEventsString);
  XCTAssertEqual(strcmp(BITSafeJsonEventsString,""), 0);
}

@end
