//
//  BITHockeyAppClientTests.m
//  HockeySDK
//
//  Created by Stephan Diederich on 06.09.13.
//
//

#import <XCTest/XCTest.h>

#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITHockeyAppClient.h"
#import "BITHTTPOperation.h"
#import "BITTestHelper.h"

@interface BITHockeyAppClientTests : XCTestCase

@property(nonatomic, strong) BITHockeyAppClient *sut;

@end

@implementation BITHockeyAppClientTests

- (void)setUp {
  [super setUp];
  
  self.sut = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:@"http://bitbaseurl.com"]];
}

- (void)tearDown {
  [self.sut cancelOperationsWithPath:nil method:nil];
  self.sut = nil;
  
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
  XCTAssertNotNil(self.sut, @"Should be there");
}

#pragma mark - Networking base tests
- (void) testThatURLRequestHasBaseURLSet {
  self.sut.baseURL = [NSURL URLWithString:@"http://myserver.com"];
  NSMutableURLRequest *request = [self.sut requestWithMethod:@"GET" path:nil parameters:nil];
  assertThat(request.URL, equalTo([NSURL URLWithString:@"http://myserver.com/"]));
}

- (void) testThatURLRequestHasPathAppended {
  self.sut.baseURL = [NSURL URLWithString:@"http://myserver.com"];
  NSMutableURLRequest *request = [self.sut requestWithMethod:@"GET" path:@"projects" parameters:nil];
  assertThat(request.URL, equalTo([NSURL URLWithString:@"http://myserver.com/projects"]));
}

- (void) testThatURLRequestHasMethodSet {
  NSMutableURLRequest *request = [self.sut requestWithMethod:@"POST" path:nil parameters:nil];
  
  assertThat(request.HTTPMethod, equalTo(@"POST"));
}

- (void) testThatOperationHasURLRequestSet {
  self.sut.baseURL = [NSURL URLWithString:@"http://myserver.com"];
  NSURLRequest *r = [self.sut requestWithMethod:@"PUT" path:@"x" parameters:nil];
  BITHTTPOperation *op = [self.sut operationWithURLRequest:r
                                            completion:nil];
  assertThat(op.URLRequest, equalTo(r));
}

- (void) testThatURLRequestHasParametersInGetAppended {
  NSDictionary *parameters = @{
                               @"email" : @"peter@pan.de",
                               @"push" : @"pop",
                               };
  NSMutableURLRequest *request = [self.sut requestWithMethod:@"GET"
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
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(0));
  [given([self.sut operationWithURLRequest:(id)anything()
                            completion:nil]) willReturn:[NSOperation new]];
  
  [self.sut getPath:@"endpoint"
     parameters:nil
     completion:nil];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(1));
}

- (void) testThatPostPathCreatesAndEnquesAnOperation {
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(0));
  [given([self.sut operationWithURLRequest:nil
                            completion:nil]) willReturn:[NSOperation new]];
  
  [self.sut postPath:@"endpoint"
      parameters:nil
      completion:nil];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(1));
}

#pragma mark - Completion Tests
- (void) testThatCompletionIsCalled {
  //TODO
}

#pragma mark - HTTPOperation enqueuing / cancellation
- (void) testThatOperationIsQueued {
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(0));
  [self.sut.operationQueue setSuspended:YES];
  BITHTTPOperation *op = [BITHTTPOperation new];
  [self.sut enqeueHTTPOperation:op];
  
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithNilMethod {
  [self.sut.operationQueue setSuspended:YES];
  NSURLRequest *requestGet = [self.sut requestWithMethod:@"GET" path:nil parameters:nil];
  NSURLRequest *requestPut = [self.sut requestWithMethod:@"PUT" path:nil parameters:nil];
  NSURLRequest *requestPost = [self.sut requestWithMethod:@"POST" path:nil parameters:nil];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [self.sut cancelOperationsWithPath:nil method:nil];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(3));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithNilPath {
  [self.sut.operationQueue setSuspended:YES];
  NSURLRequest *requestGet = [self.sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [self.sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [self.sut requestWithMethod:@"POST" path:nil parameters:nil];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [self.sut cancelOperationsWithPath:nil method:nil];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(3));
}


- (void) testThatOperationCancellingMatchesAllOperationsWithSetPath {
  NSURLRequest *requestGet = [self.sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [self.sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [self.sut requestWithMethod:@"POST" path:nil parameters:nil];
  [self.sut.operationQueue setSuspended:YES];
  
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [self.sut cancelOperationsWithPath:@"Another/acas" method:nil];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithSetMethod {
  NSURLRequest *requestGet = [self.sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [self.sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [self.sut requestWithMethod:@"POST" path:nil parameters:nil];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [self.sut cancelOperationsWithPath:nil method:@"POST"];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(1));
}

- (void) testThatOperationCancellingMatchesAllOperationsWithSetMethodAndPath {
  NSURLRequest *requestGet = [self.sut requestWithMethod:@"GET" path:@"test" parameters:nil];
  NSURLRequest *requestPut = [self.sut requestWithMethod:@"PUT" path:@"Another/acas" parameters:nil];
  NSURLRequest *requestPost = [self.sut requestWithMethod:@"POST" path:nil parameters:nil];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestGet
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPut
                                               completion:nil]];
  [self.sut enqeueHTTPOperation:[self.sut operationWithURLRequest:requestPost
                                               completion:nil]];
  assertThatUnsignedLong(self.sut.operationQueue.operationCount, equalToUnsignedLong(3));
  NSUInteger numCancelled = [self.sut cancelOperationsWithPath:@"Another/acas" method:@"PUT"];
  assertThatUnsignedLong(numCancelled, equalToUnsignedLong(1));
}

#pragma mark - Operation Testing

@end
