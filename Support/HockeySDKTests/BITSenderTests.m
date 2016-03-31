#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import <OCMock/OCMock.h>
#import "BITEnvelope.h"
#import "BITSender.h"
#import "BITPersistencePrivate.h"
#import "BITHockeyHelper.h"
#import "BITTestsDependencyInjection.h"

@interface BITSenderTests : BITTestsDependencyInjection

@end

@implementation BITSenderTests{
  BITSender *_sut;
  BITPersistence *_mockPersistence;
  NSURL *_testServerURL;
}

- (void)setUp {
  [super setUp];
  _testServerURL = [NSURL URLWithString:@"http://test.com"];
  _sut = [self newSender];
}

- (void)tearDown {
  _sut = nil;
  [super tearDown];
}

- (BITSender *)newSender {
  _mockPersistence = mock(BITPersistence.class);
  return [[BITSender alloc]initWithPersistence:_mockPersistence serverURL:[_testServerURL copy]];
}

- (void)testThatItInstantiatesCorrectly {
  XCTAssertNotNil(_sut);
  XCTAssertNotNil(_sut.senderTasksQueue);
  XCTAssertEqualObjects(_sut.persistence, _mockPersistence);
  XCTAssertEqualObjects(_sut.serverURL, _testServerURL);
}

- (void)testRequestContainsDataItem {
  BITEnvelope *testItem = [BITEnvelope new];
  NSData *expectedBodyData = [NSJSONSerialization dataWithJSONObject:[testItem serializeToDictionary]
                                                              options:0
                                                                error:nil];
  NSURLRequest *testRequest = [_sut requestForData:expectedBodyData];
  
  XCTAssertNotNil(testRequest);
  XCTAssertEqualObjects(testRequest.HTTPBody, expectedBodyData);
}

- (void)testSendDataTriggersPlatformSpecificNetworkOperation {
  // setup
  _sut = OCMPartialMock(_sut);
  OCMStub([_sut isURLSessionSupported]).andReturn(YES);
  
  NSURLRequest *testRequest = [NSURLRequest new];
  NSString *testFilePath = @"path/to/file";
  [_sut sendRequest:testRequest filePath:testFilePath];
  
  OCMVerify([_sut sendUsingURLSessionWithRequest:testRequest filePath:testFilePath]);
  
  _sut = OCMPartialMock([self newSender]);
  OCMStub([_sut isURLSessionSupported]).andReturn(NO);
  
  [_sut sendRequest:testRequest filePath:testFilePath];
  
  OCMVerify([_sut sendUsingURLConnectionWithRequest:testRequest filePath:testFilePath]);
}

- (void)testSendDataVerifyDataIsGzipped {
  _sut = OCMPartialMock(_sut);
  NSString *testFilePath = @"path/to/file";
  NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  
  [_sut sendData:testData withFilePath:testFilePath];
  
  OCMVerify([_sut sendRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
    NSMutableURLRequest *request = (NSMutableURLRequest *)obj;
    NSData *data = request.HTTPBody;
    if (data) {
      // Test if first two bytes of data are the gzip header
      static const uint16_t GZIP_SIGNATURE = OSSwapBigToHostConstInt16(0x1f8b);
      UInt16 firstBytes = 0;
      [data getBytes:&firstBytes range:NSMakeRange(0, 2)];
      if ((data.length > sizeof(uint16_t)) && (firstBytes == GZIP_SIGNATURE)) {
        return YES;
      }
    }
    return NO;
  }] filePath:testFilePath]);
}

- (void)testSendUsingURLConnection {
  
  // setup
  _sut = OCMPartialMock(_sut);
  NSString *testFilePath = @"path/to/file";
  NSURLRequest *testRequest = [NSURLRequest new];
  
  // test
  [_sut sendUsingURLConnectionWithRequest:testRequest filePath:testFilePath];
  
  //verify
  OCMVerify([_sut.operationQueue addOperation:(id)anything()]);
}

- (void)testSendUsingURLSession {
  
  // setup=
  _sut = OCMPartialMock(_sut);
  NSString *testFilePath = @"path/to/file";
  NSURLRequest *testRequest = [NSURLRequest new];
  if ([_sut isURLSessionSupported]) {
    // test
    [_sut sendUsingURLSessionWithRequest:testRequest filePath:testFilePath];
    
    //verify
    OCMVerify([_sut resumeSessionDataTask:(id)anything()]);
  }
}

- (void)testDeleteDataWithStatusCodeWorks{
  
  for(NSInteger statusCode = 100; statusCode <= 510; statusCode++){
    if((statusCode == 429) || (statusCode == 408) || (statusCode == 500) || (statusCode == 503) || (statusCode == 511)) {
      XCTAssertTrue([_sut shouldDeleteDataWithStatusCode:statusCode] == NO);
    }else{
      XCTAssertTrue([_sut shouldDeleteDataWithStatusCode:statusCode] == YES);
    }
  }
}

- (void)testRegisterObserversOnInit {
  self.mockNotificationCenter = mock(NSNotificationCenter.class);
  _sut = [[BITSender alloc]initWithPersistence:_mockPersistence  serverURL:_testServerURL];
  
  [verify((id)self.mockNotificationCenter) addObserverForName:BITPersistenceSuccessNotification object:nil queue:nil usingBlock:(id)anything()];
}

- (void)testFilesGetDeletedOnPositiveOrUnrecoverableStatusCodes {
 
  // setup=
  _sut = OCMPartialMock(_sut);
  NSInteger testStatusCode = 999;
  OCMStub([_sut shouldDeleteDataWithStatusCode:testStatusCode]).andReturn(YES);
  _sut.runningRequestsCount = 8;
   NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *testFilePath = @"path/to/file";
  
  // Stub `sendSavedData` method so there won't be already a new running request when our test request finishes
  // Otherwise `runningRequestsCount` will already have been decreased by one and been increased by one again.
  OCMStub([_sut sendSavedData]).andDo(nil);
  
  // test
  [_sut handleResponseWithStatusCode:testStatusCode responseData:testData filePath:testFilePath error:[NSError errorWithDomain:@"Network error" code:503 userInfo:nil]];
  
  //verify
  [verify(_mockPersistence) deleteFileAtPath:testFilePath];
  XCTAssertTrue(_sut.runningRequestsCount == 7);
}

- (void)testFilesGetUnblockedOnRecoverableErrorCodes {
  
  // setup=
  _sut = OCMPartialMock(_sut);
  NSInteger testStatusCode = 999;
  OCMStub([_sut shouldDeleteDataWithStatusCode:testStatusCode]).andReturn(NO);
  _sut.runningRequestsCount = 8;
  NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *testFilePath = @"path/to/file";
  
  // test
  [_sut handleResponseWithStatusCode:testStatusCode responseData:testData filePath:testFilePath error:[NSError new]];
  
  //verify
  [verify(_mockPersistence) giveBackRequestedFilePath:testFilePath];
  XCTAssertTrue(_sut.runningRequestsCount == 7);
}

@end
