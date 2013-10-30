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
#import "BITKeychainUtils.h"


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

- (void)testBase64Encoding {
  NSString *string = @"Lorem ipsum dolor sit amet.";
  NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
  NSString *encodedString = bit_base64String(stringData, stringData.length);
  assertThatBool([encodedString isEqualToString:@"TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQu"], equalToBool(YES));
}

- (void)testBase64EncodingPreiOS7 {
  NSString *string = @"Lorem ipsum dolor sit amet.";
  NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
  NSString *encodedString = bit_base64StringPreiOS7(stringData, stringData.length);
  assertThatBool([encodedString isEqualToString:@"TG9yZW0gaXBzdW0gZG9sb3Igc2l0IGFtZXQu"], equalToBool(YES));
}

- (void)testBase64EncodingPreiOS7EmptyString {
  NSString *string = @"";
  NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
  NSString *encodedString = bit_base64StringPreiOS7(stringData, stringData.length);
  assertThatBool([encodedString isEqualToString:@""], equalToBool(YES));
}

- (void)testBase64EncodingCompareToiOS7Implementation {
  // this requires iOS 7
  BOOL result = YES;
  SEL base64EncodingSelector = NSSelectorFromString(@"base64EncodedStringWithOptions:");
  NSData *dataInstance = [NSData data];
  if ([dataInstance respondsToSelector:base64EncodingSelector]) {
    
    NSString *string = @"A dummy whatever strange !* char : test &# more";
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
  
    NSString *encodedString = bit_base64String(stringData, stringData.length);
  
    NSString *base64EncodedString = [[string dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    
    result = [base64EncodedString isEqualToString:encodedString];
  }
  assertThatBool(result, equalToBool(YES));
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

- (void)testAppName {
  NSString *resultString = bit_appName(@"Placeholder");
  assertThatBool([resultString isEqualToString:@"Placeholder"], equalToBool(YES));
}

- (void)testUUIDPreiOS6 {
  NSString *resultString = bit_UUIDPreiOS6();
  assertThat(resultString, notNilValue());
  assertThatInteger([resultString length], equalToInteger(36));
}

- (void)testUUID {
  NSString *resultString = bit_UUID();
  assertThat(resultString, notNilValue());
  assertThatInteger([resultString length], equalToInteger(36));
}

- (void)testAppAnonID {
  // clean keychain cache
  NSError *error = NULL;
  [BITKeychainUtils deleteItemForUsername:@"appAnonID"
                           andServiceName:bit_keychainHockeySDKServiceName()
                                    error:&error];
  
  NSString *resultString = bit_appAnonID();
  assertThat(resultString, notNilValue());
  assertThatInteger([resultString length], equalToInteger(36));
}


@end
