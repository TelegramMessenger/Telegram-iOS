#import <XCTest/XCTest.h>
#import "BITReachability.h"

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

@interface BITReachabilityTests : XCTestCase
@end

NSString *const testHostName = @"www.google.com";

@implementation BITReachabilityTests{
  BITReachability *_sut;
}

- (void)setUp {
  [super setUp];
  
  _sut = [BITReachability sharedInstance];
}

- (void)tearDown {
  _sut = nil;
  
  [super tearDown];
}

- (void)testThatItInstantiates {
  assertThat(_sut, notNilValue());
  assertThat(_sut.networkQueue, notNilValue());
  assertThat(_sut.singletonQueue, notNilValue());
  
  if ([CTTelephonyNetworkInfo class]) {
    assertThat(_sut.radioInfo, notNilValue());
  }
}

- (void)testWwanTypeForRadioAccessTechnology{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:nil], equalToInteger(BITReachabilityTypeNone));
#pragma clang diagnostic pop
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:@"Foo"], equalToInteger(BITReachabilityTypeNone));
  
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyGPRS], equalToInteger(BITReachabilityTypeGPRS));
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyCDMA1x], equalToInteger(BITReachabilityTypeGPRS));
  
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyEdge], equalToInteger(BITReachabilityTypeEDGE));
  
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyWCDMA], equalToInteger(BITReachabilityType3G));
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyHSDPA], equalToInteger(BITReachabilityType3G));
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyHSUPA], equalToInteger(BITReachabilityType3G));
  
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyCDMAEVDORev0], equalToInteger(BITReachabilityType3G));
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyCDMAEVDORevA], equalToInteger(BITReachabilityType3G));
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyCDMAEVDORevB], equalToInteger(BITReachabilityType3G));
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyeHRPD], equalToInteger(BITReachabilityType3G));
  
  assertThatInteger([_sut wwanTypeForRadioAccessTechnology:CTRadioAccessTechnologyLTE], equalToInteger(BITReachabilityTypeLTE));
}

- (void)testDescriptionForReachabilityType{
  BITReachabilityType type = BITReachabilityTypeNone;
  assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"none"));
  
  type = BITReachabilityTypeWIFI;
  assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"wifi"));
  
  type = BITReachabilityTypeWWAN;
  assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"wwan"));
  
  if ([CTTelephonyNetworkInfo class]) {
    type = BITReachabilityTypeGPRS;
    assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"gprs"));
    
    type = BITReachabilityTypeEDGE;
    assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"edge"));
    
    type = BITReachabilityType3G;
    assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"3g"));
    
    type = BITReachabilityTypeLTE;
    assertThat([_sut descriptionForReachabilityType:type], equalToIgnoringCase(@"lte"));
  }
}

@end
