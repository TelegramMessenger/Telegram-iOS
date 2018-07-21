//
//  ASConfigurationTests.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>
#import "ASTestCase.h"
#import "ASConfiguration.h"
#import "ASConfigurationDelegate.h"
#import "ASConfigurationInternal.h"

@interface ASConfigurationTests : ASTestCase <ASConfigurationDelegate>

@end

@implementation ASConfigurationTests {
  void (^onActivate)(ASConfigurationTests *self, ASExperimentalFeatures feature);
}

- (void)testExperimentalFeatureConfig
{
  // Set the config
  ASConfiguration *config = [[ASConfiguration alloc] initWithDictionary:nil];
  config.experimentalFeatures = ASExperimentalGraphicsContexts;
  config.delegate = self;
  [ASConfigurationManager test_resetWithConfiguration:config];
  
  // Set an expectation for a callback, and assert we only get one.
  XCTestExpectation *e = [self expectationWithDescription:@"Callbacks done."];
  e.expectedFulfillmentCount = 2;
  e.assertForOverFulfill = YES;
  onActivate = ^(ASConfigurationTests *self, ASExperimentalFeatures feature) {
    [e fulfill];
  };
  
  // Now activate the graphics experiment and expect it works.
  XCTAssertTrue(ASActivateExperimentalFeature(ASExperimentalGraphicsContexts));
  // We should get a callback here
  // Now activate text node and expect it fails.
  XCTAssertFalse(ASActivateExperimentalFeature(ASExperimentalTextNode));
  // But we should get another callback.
  [self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)textureDidActivateExperimentalFeatures:(ASExperimentalFeatures)feature
{
  if (onActivate) {
    onActivate(self, feature);
  }
}

- (void)testMappingNamesToFlags
{
  // Throw in a bad bit.
  ASExperimentalFeatures features = ASExperimentalTextNode | ASExperimentalGraphicsContexts | (1 << 22);
  NSArray *expectedNames = @[ @"exp_graphics_contexts", @"exp_text_node" ];
  XCTAssertEqualObjects(expectedNames, ASExperimentalFeaturesGetNames(features));
}

- (void)testMappingFlagsFromNames
{
  // Throw in a bad name.
  NSArray *names = @[ @"exp_text_node", @"exp_graphics_contexts", @"__invalid_name" ];
  ASExperimentalFeatures expected = ASExperimentalGraphicsContexts | ASExperimentalTextNode;
  XCTAssertEqual(expected, ASExperimentalFeaturesFromArray(names));
}

@end
