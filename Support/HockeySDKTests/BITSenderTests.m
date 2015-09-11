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
  _mockPersistence = mock(BITPersistence.class);
  _sut = [[BITSender alloc]initWithPersistence:_mockPersistence serverURL:[_testServerURL copy]];
}

- (void)tearDown {
  _sut = nil;
  [super tearDown];
}

- (void)testThatItInstantiatesCorrectly {
  XCTAssertNotNil(_sut);
  XCTAssertNotNil(_sut.senderQueue);
  XCTAssertEqualObjects(_sut.persistence, _mockPersistence);
  XCTAssertEqualObjects(_sut.serverURL, _testServerURL);
}

- (void)testRequestContainsDataItem {
  BITEnvelope *testItem = [BITEnvelope new];
  NSData *expectedBodyData = [[testItem serializeToString] dataUsingEncoding:NSUTF8StringEncoding];
  NSURLRequest *testRequest = [_sut requestForData:expectedBodyData];
  
  XCTAssertNotNil(testRequest);
  XCTAssertEqualObjects(testRequest.HTTPBody, expectedBodyData);
}

- (void)testSendDataTriggersPlatformSpecificNetworkOperation {
  
  // setup
  _sut = OCMPartialMock(_sut);
  NSString *testFilePath = @"path/to/file";
  id nsurlsessionClass = NSClassFromString(@"NSURLSessionUploadTask");
  BOOL nsUrlSessionSupported = (nsurlsessionClass && !bit_isRunningInAppExtension());
  NSData *testData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
  
  // test
  [_sut sendData:testData  withPath:testFilePath];
  
  //verify
   OCMVerify([_sut sendRequest:(id)anything() path:testFilePath urlSessionSupported:nsUrlSessionSupported]);
}

- (void)testSendDataCreatesOperationPriorToIOS7 {
  
  // setup
  _sut = OCMPartialMock(_sut);
  NSString *testFilePath = @"path/to/file";
  NSURLRequest *testRequest = [NSURLRequest new];
  
  // test
  [_sut sendRequest:testRequest path:testFilePath urlSessionSupported:NO];
  
  //verify
  OCMVerify([_sut.operationQueue addOperation:(id)anything()]);
}

- (void)testSendDataCreatesSessionDataTaskLaterIOS7 {
  
  // setup=
  _sut = OCMPartialMock(_sut);
  NSString *testFilePath = @"path/to/file";
  NSURLRequest *testRequest = [NSURLRequest new];
  id nsurlsessionClass = NSClassFromString(@"NSURLSessionUploadTask");
  if(nsurlsessionClass && !bit_isRunningInAppExtension()){
    // test
    [_sut sendRequest:testRequest path:testFilePath urlSessionSupported:YES];
    
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

- (void)testFilesGetDeletedOnositiveOrUnrecoverableStatusCodes {
 
  // setup=
  _sut = OCMPartialMock(_sut);
  NSInteger testStatusCode = 999;
  OCMStub([_sut shouldDeleteDataWithStatusCode:testStatusCode]).andReturn(YES);
  _sut.runningRequestsCount = 8;
  NSString *testFilePath = @"path/to/file";
  
  // test
  [_sut handleResponseWithStatusCode:testStatusCode responseData:[NSData new] filePath:testFilePath error:[NSError new]];
  
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
  NSString *testFilePath = @"path/to/file";
  
  // test
  [_sut handleResponseWithStatusCode:testStatusCode responseData:[NSData new] filePath:testFilePath error:[NSError new]];
  
  //verify
  [verify(_mockPersistence) giveBackRequestedPath:testFilePath];
  XCTAssertTrue(_sut.runningRequestsCount == 7);
}

@end
