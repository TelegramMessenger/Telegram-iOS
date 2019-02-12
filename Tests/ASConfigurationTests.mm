//
//  ASConfigurationTests.m
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASConfiguration.h>
#import <AsyncDisplayKit/ASConfigurationDelegate.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>

#import "ASTestCase.h"

static ASExperimentalFeatures features[] = {
  ASExperimentalGraphicsContexts,
#if AS_ENABLE_TEXTNODE
  ASExperimentalTextNode,
#endif
  ASExperimentalInterfaceStateCoalescing,
  ASExperimentalUnfairLock,
  ASExperimentalLayerDefaults,
  ASExperimentalNetworkImageQueue,
  ASExperimentalCollectionTeardown,
  ASExperimentalFramesetterCache,
  ASExperimentalSkipClearData,
  ASExperimentalDidEnterPreloadSkipASMLayout,
  ASExperimentalDisableAccessibilityCache,
  ASExperimentalSkipAccessibilityWait,
  ASExperimentalNewDefaultCellLayoutMode
};

@interface ASConfigurationTests : ASTestCase <ASConfigurationDelegate>

@end

@implementation ASConfigurationTests {
  void (^onActivate)(ASConfigurationTests *self, ASExperimentalFeatures feature);
}

+ (NSArray *)names {
  return @[
    @"exp_graphics_contexts",
    @"exp_text_node",
    @"exp_interface_state_coalesce",
    @"exp_unfair_lock",
    @"exp_infer_layer_defaults",
    @"exp_network_image_queue",
    @"exp_collection_teardown",
    @"exp_framesetter_cache",
    @"exp_skip_clear_data",
    @"exp_did_enter_preload_skip_asm_layout",
    @"exp_disable_a11y_cache",
    @"exp_skip_a11y_wait",
    @"exp_new_default_cell_layout_mode"
  ];
}

- (ASExperimentalFeatures)allFeatures {
  ASExperimentalFeatures allFeatures = 0;
  for (int i = 0; i < sizeof(features)/sizeof(ASExperimentalFeatures); i++) {
    allFeatures |= features[i];
  }
  return allFeatures;
}

#if AS_ENABLE_TEXTNODE

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

#endif

- (void)textureDidActivateExperimentalFeatures:(ASExperimentalFeatures)feature
{
  if (onActivate) {
    onActivate(self, feature);
  }
}

- (void)testMappingNamesToFlags
{
  // Throw in a bad bit.
  ASExperimentalFeatures allFeatures = [self allFeatures];
  ASExperimentalFeatures featuresWithBadBit = allFeatures | (1 << 22);
  NSArray *expectedNames = [ASConfigurationTests names];
  XCTAssertEqualObjects(expectedNames, ASExperimentalFeaturesGetNames(featuresWithBadBit));
}

- (void)testMappingFlagsFromNames
{
  // Throw in a bad name.
  NSMutableArray *allNames = [[NSMutableArray alloc] initWithArray:[ASConfigurationTests names]];
  [allNames addObject:@"__invalid_name"];
  ASExperimentalFeatures expected = [self allFeatures];
  XCTAssertEqual(expected, ASExperimentalFeaturesFromArray(allNames));
}

- (void)testFlagMatchName
{
  NSArray *names = [ASConfigurationTests names];
  for (NSInteger i = 0; i < names.count; i++) {
    XCTAssertEqual(features[i], ASExperimentalFeaturesFromArray(@[names[i]]));
  }
}

- (void)testNameMatchFlag {
  NSArray *names = [ASConfigurationTests names];
  for (NSInteger i = 0; i < names.count; i++) {
    XCTAssertEqualObjects(@[names[i]], ASExperimentalFeaturesGetNames(features[i]));
  }
}

@end
