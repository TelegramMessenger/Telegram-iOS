//
//  BITHockeyAppClientTests
//  HockeySDKTests
//
//  Created by Stephan Diederich on 06.09.13.
//
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITHockeyAppClient.h"
#import "BITHTTPOperation.h"
#import "BITTestHelper.h"

@interface BITHockeyAppClientTests : XCTestCase
@end

@implementation BITHockeyAppClientTests {
  BITHockeyAppClient *_sut;
}

- (void)setUp {
  [super setUp];
  
  _sut = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:@"http://bitbaseurl.com"]];
}

- (void)tearDown {
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop
  
  [_sut cancelOperationsWithPath:nil method:nil];
  _sut = nil;
  
  [super tearDown];
}

#pragma mark - Setup helpers
- (NSDictionary *)jsonFromFixture:(NSString *)fixture {
  NSString *dataString = [BITTestHelper jsonFixture:fixture];
  
  NSData *data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = nil;
  NSDictionary *json = (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  
  return json;
}

#pragma mark - Setup Tests
- (void) testThatItInstantiates {
  XCTAssertNotNil(_sut, @"Should be there");
}

#pragma mark - Networking base tests
- (void) testThatURLRequestHasBaseURLSet {
  _sut.baseURL = [NSURL URLWithString:@"http://myserver.com"];
  NSMutableURLRequest *request = [_sut requestWithMethod:@"GET" path:nil parameters:nil];
  assertThat(request.URL, equalTo([NSURL URLWithString:@"http://myserver.com/"]));
}

- (void) testThatURLRequestHasPathAppended {
  _sut.baseURL = [NSURL URLWithString:@"http://myserver.com"];
  NSMutableURLRequest *request = [_sut requestWithMethod:@"GET" path:@"projects" parameters:nil];
  assertThat(request.URL, equalTo([NSURL URLWithString:@"http://myserver.com/projects"]));
}

- (void) testThatURLRequestHasMethodSet {
  NSMutableURLRequest *request = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  
  assertThat(request.HTTPMethod, equalTo(@"POST"));
}

- (void) testThatOperationHasURLRequestSet {
  _sut.baseURL = [NSURL URLWithString:@"http://myserver.com"];
  NSURLRequest *r = [_sut requestWithMethod:@"PUT" path:@"x" parameters:nil];
  BITHTTPOperation *op = [_sut operationWithURLRequest:r
                                            completion:nil];
  assertThat(op.URLRequest, equalTo(r));
}

- (void) testThatURLRequestHasParametersInGetAppended {
  NSDictionary *parameters = @{
                               @"email" : @"peter@pan.de",
                               @"push" : @"pop",
                               };
  NSMutableURLRequest *request = [_sut requestWithMethod:@"GET"
                                                    path:@"something"
                                              parameters:parameters];
  NSURL *url = request.URL;
  NSString *params = [url query];
  NSArray *paramPairs = [params componentsSeparatedByString:@"&"];
  assertThat(paramPairs, hasCountOf(2));
  
  NSMutableDictionary *dict = [NSMutableDictionary new];
  for(NSString *paramPair in paramPairs) {
    NSArray *a = [paramPair componentsSeparatedByString:@"="];
    assertThat(a, hasCountOf(2));
    dict[a[0]] = a[1];
  }
  assertThat(dict, equalTo(parameters));
}

- (void) testThatURLRequestHasParametersInPostInTheBody {
  //pending
}

#pragma mark - Convenience methods
- (void) testThatGetPathCreatesAndEnquesAnOperation {
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(0));
  [given([_sut operationWithURLRequest:(id)anything()
                            completion:nil]) willReturn:[NSOperation new]];
  
  [_sut getPath:@"endpoint"
     parameters:nil
     completion:nil];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(1));
}

- (void) testThatPostPathCreatesAndEnquesAnOperation {
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(0));
  [given([_sut operationWithURLRequest:nil
                            completion:nil]) willReturn:[NSOperation new]];
  
  [_sut postPath:@"endpoint"
      parameters:nil
      completion:nil];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(1));
}

#pragma mark - Completion Tests
- (void) testThatCompletionIsCalled {
  //TODO
}

#pragma mark - HTTPOperation enqueuing / cancellation
- (void) testThatOperationIsQueued {
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(0));
  [_sut.operationQueue setSuspended:YES];
  BITHTTPOperation *op = [BITHTTPOperation new];
  [_sut enqeueHTTPOperation:op];
  
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithNilMethod {
  [_sut.operationQueue setSuspended:YES];
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:nil parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:nil parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:nil method:nil];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(3));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithNilPath {
  [_sut.operationQueue setSuspended:YES];
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:nil method:nil];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(3));
}


- (void) testThatOperationCancellingMatchesAllOperationsWithSetPath {
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut.operationQueue setSuspended:YES];
  
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:@"Another/acas" method:nil];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithSetMethod {
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:nil method:@"POST"];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithSetMethodAndPath {
  NSURLRequest *requestGet = [_sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [_sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [_sut requestWithMethod:@"POST" path:nil parameters:nil];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [_sut enqeueHTTPOperation:[_sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(_sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [_sut cancelOperationsWithPath:@"Another/acas" method:@"PUT"];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(1));
}

#pragma mark - Operation Testing

@end
