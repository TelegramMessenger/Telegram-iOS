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

@property(nonatomic, strong) BITHockeyAppClient *sut;

@end

@implementation BITHockeyAppClientTests

- (void)setUp {
  [super setUp];
  
  self.sut = [[BITHockeyAppClient alloc] initWithBaseURL:[NSURL URLWithString:@"http://bitbaseurl.com"]];
}

- (void)tearDown {
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

#pragma mark - Completion Tests
- (void) testThatCompletionIsCalled {
  //TODO
}

@end
