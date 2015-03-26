//
//  BITKeychainHelperTests.m
//  HockeySDK
//
//  Created by Stephan Diederich on 23.09.13.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

#import "HockeySDK.h"
#import "BITKeychainUtils.h"

@interface BITKeychainUtilsTests : XCTestCase {

}
@end


@implementation BITKeychainUtilsTests
- (void)setUp {
  [super setUp];
  
  // Set-up code here.
}

- (void)tearDown {
  // Tear-down code here.
# pragma clang diagnostic push
# pragma clang diagnostic ignored "-Wimplicit"
  __gcov_flush();
# pragma clang diagnostic pop

  [super tearDown];
}

- (void)testThatBITKeychainHelperStoresAndRetrievesPassword {
  [BITKeychainUtils deleteItemForUsername:@"Peter" andServiceName:@"Test" error:nil];
  BOOL success =   [BITKeychainUtils storeUsername:@"Peter"
                                       andPassword:@"Pan"
                                    forServiceName:@"Test"
                                    updateExisting:YES
                                             error:nil];
  assertThatBool(success, equalToBool(YES));
  NSString *pass = [BITKeychainUtils getPasswordForUsername:@"Peter"
                                             andServiceName:@"Test"
                                                      error:NULL];
  assertThat(pass, equalTo(@"Pan"));
}

- (void)testThatBITKeychainHelperStoresAndRetrievesPasswordThisDeviceOnly {
  [BITKeychainUtils deleteItemForUsername:@"Peter" andServiceName:@"Test" error:nil];
  BOOL success =   [BITKeychainUtils storeUsername:@"Peter"
                                       andPassword:@"PanThisDeviceOnly"
                                    forServiceName:@"Test"
                                    updateExisting:YES
                                     accessibility:kSecAttrAccessibleAlwaysThisDeviceOnly
                                             error:nil];
  assertThatBool(success, equalToBool(YES));
  NSString *pass = [BITKeychainUtils getPasswordForUsername:@"Peter"
                                             andServiceName:@"Test"
                                                      error:NULL];
  assertThat(pass, equalTo(@"PanThisDeviceOnly"));
}

- (void)testThatBITKeychainHelperRemovesAStoredPassword {
  [BITKeychainUtils deleteItemForUsername:@"Peter" andServiceName:@"Test" error:nil];
  [BITKeychainUtils storeUsername:@"Peter"
                      andPassword:@"Pan"
                   forServiceName:@"Test"
                   updateExisting:YES
                            error:nil];
  BOOL success = [BITKeychainUtils deleteItemForUsername:@"Peter" andServiceName:@"Test" error:nil];
  assertThatBool(success, equalToBool(YES));
  
  NSString *pass = [BITKeychainUtils getPasswordForUsername:@"Peter"
                                             andServiceName:@"Test"
                                                      error:NULL];
  assertThat(pass, equalTo(nil));
}

@end
