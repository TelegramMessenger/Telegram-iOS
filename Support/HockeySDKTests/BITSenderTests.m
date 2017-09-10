#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import <OCMock/OCMock.h>
#import "BITEnvelope.h"
#import "BITSender.h"
#import "BITPersistencePrivate.h"
#import "BITHockeyHelper.h"
#import "BITTestsDependencyInjection.h"

@interface BITSenderTests : BITTestsDependencyInjection

@property(nonatomic, strong) BITSender *sut;
@property(nonatomic, strong) BITPersistence *mockPersistence;
@property(nonatomic, strong) NSURL *testServerURL;

@end

@implementation BITSenderTests

- (void)setUp {
  [super setUp];
  self.testServerURL = [NSURL URLWithString:@"http://test.com"];
  self.sut = [self newSender];
}

- (void)tearDown {
  self.sut = nil;
  [super tearDown];
}

- (BITSender *)newSender {
  self.mockPersistence = mock(BITPersistence.class);
  return [[BITSender alloc]initWithPersistence:self.mockPersistence serverURL:[self.testServerURL copy]];
}

- (void)testThatItInstantiatesCorrectly {
  XCTAssertNotNil(self.sut);
  XCTAssertNotNil(self.sut.senderTasksQueue);
  XCTAssertEqualObjects(self.sut.persistence, self.mockPersistence);
  XCTAssertEqualObjects(self.sut.serverURL, self.testServerURL);
}

- (void)testRequestContainsDataItem {
  BITEnvelope *testItem = [BITEnvelope new];
  NSData *expectedBodyData = [NSJSONSerialization dataWithJSONObject:[testItem serializeToDictionary]
                                                              options:0
                                                                error:nil];
  NSURLRequest *testRequest = [self.sut requestForData:expectedBodyData];
  
  XCTAssertNotNil(testRequest);
  XCTAssertEqualObjects(testRequest.HTTPBody, expectedBodyData);
}

- (void)testSendDataTriggersPlatformSpecificNetworkOperation {
  // setup
  self.sut = OCMPartialMock(self.sut);
  OCMStub([self.sut isURLSessionSupported]).andReturn(YES);
  
  NSURLRequest *testRequest = [NSURLRequest new];
  NSString *testFilePath = @"path/to/file";
  [self.sut sendRequest:testRequest filePath:testFilePath];

  OCMVerify([self.sut sendUsingURLSessionWithRequest:testRequest filePath:testFilePath]);
}

- (void)testSendDataVerifyDataIsGzipped {
  self.sut = OCMPartialMock(self.sut);
  NSString *testFilePath = @"path/to/file";
  NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  
  [self.sut sendData:testData withFilePath:testFilePath];
  
  OCMVerify([self.sut sendRequest:[OCMArg checkWithBlock:^BOOL(id obj) {
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

- (void)testSendUsingURLSession {
  
  // setup=
  self.sut = OCMPartialMock(self.sut);
  NSString *testFilePath = @"path/to/file";
  NSURLRequest *testRequest = [NSURLRequest new];
  if ([self.sut isURLSessionSupported]) {
    // test
    [self.sut sendUsingURLSessionWithRequest:testRequest filePath:testFilePath];
    
    //verify
    OCMVerify([self.sut resumeSessionDataTask:(id)anything()]);
  }
}

- (void)testDeleteDataWithStatusCodeWorks{
  
  for(NSInteger statusCode = 100; statusCode <= 510; statusCode++){
    if((statusCode == 429) || (statusCode == 408) || (statusCode == 500) || (statusCode == 503) || (statusCode == 511)) {
      XCTAssertTrue([self.sut shouldDeleteDataWithStatusCode:statusCode] == NO);
    }else{
      XCTAssertTrue([self.sut shouldDeleteDataWithStatusCode:statusCode] == YES);
    }
  }
}

- (void)testRegisterObserversOnInit {
  self.mockNotificationCenter = mock(NSNotificationCenter.class);
  self.sut = [[BITSender alloc]initWithPersistence:self.mockPersistence  serverURL:self.testServerURL];
  
  [verify((id)self.mockNotificationCenter) addObserverForName:BITPersistenceSuccessNotification object:nil queue:nil usingBlock:(id)anything()];
}

- (void)testFilesGetDeletedOnPositiveOrUnrecoverableStatusCodes {
 
  // setup=
  self.sut = OCMPartialMock(self.sut);
  NSInteger testStatusCode = 999;
  OCMStub([self.sut shouldDeleteDataWithStatusCode:testStatusCode]).andReturn(YES);
  self.sut.runningRequestsCount = 8;
   NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *testFilePath = @"path/to/file";
  
  // Stub `sendSavedData` method so there won't be already a new running request when our test request finishes
  // Otherwise `runningRequestsCount` will already have been decreased by one and been increased by one again.
  OCMStub([self.sut sendSavedData]).andDo(nil);
  
  // test
  [self.sut handleResponseWithStatusCode:testStatusCode responseData:testData filePath:testFilePath error:[NSError errorWithDomain:@"Network error" code:503 userInfo:nil]];
  
  //verify
  [verify(self.mockPersistence) deleteFileAtPath:testFilePath];
  XCTAssertTrue(self.sut.runningRequestsCount == 7);
}

- (void)testFilesGetUnblockedOnRecoverableErrorCodes {
  
  // setup=
  self.sut = OCMPartialMock(self.sut);
  NSInteger testStatusCode = 999;
  OCMStub([self.sut shouldDeleteDataWithStatusCode:testStatusCode]).andReturn(NO);
  self.sut.runningRequestsCount = 8;
  NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  NSString *testFilePath = @"path/to/file";
  
  // test
  [self.sut handleResponseWithStatusCode:testStatusCode
                        responseData:testData
                            filePath:testFilePath
                               error:[NSError errorWithDomain:@"Network error" code:503 userInfo:nil]];
  
  //verify
  [verify(self.mockPersistence) giveBackRequestedFilePath:testFilePath];
  XCTAssertTrue(self.sut.runningRequestsCount == 7);
}

@end
