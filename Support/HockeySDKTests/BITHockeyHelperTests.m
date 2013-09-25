//
//  HockeySDKPrivateTests.m
//  HockeySDK
//
//  Created by Andreas Linde on 25.09.13.
//
//

#import <SenTestingKit/SenTestingKit.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITHockeyHelper.h"


@interface BITHockeyHelperTests : SenTestCase

@end

@implementation BITHockeyHelperTests


- (void)setUp {
  [super setUp];
  // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown {
  // Put teardown code here; it will be run once, after the last test case.
  [super tearDown];
}

- (void)testValidateEmail {
  BOOL result = NO;
  
  // valid email
  result = bit_validateEmail(@"mail@test.com");
  assertThatBool(result, equalToBool(YES));
  
  // invalid emails
  
  result = bit_validateEmail(@"mail@test");
  assertThatBool(result, equalToBool(NO));

  result = bit_validateEmail(@"mail@.com");
  assertThatBool(result, equalToBool(NO));

  result = bit_validateEmail(@"mail.com");
  assertThatBool(result, equalToBool(NO));

}

@end
