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

#pragma mark - Completion Tests
- (void) testThatCompletionIsCalled {
  //TODO
}

@end
