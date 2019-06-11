//
//  ASPhotosFrameworkImageRequestTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#if AS_USE_PHOTOS

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASPhotosFrameworkImageRequest.h>

static NSString *const kTestAssetID = @"testAssetID";

@interface ASPhotosFrameworkImageRequestTests : XCTestCase

@end

@implementation ASPhotosFrameworkImageRequestTests

#pragma mark Example Data

+ (ASPhotosFrameworkImageRequest *)exampleImageRequest
{
  ASPhotosFrameworkImageRequest *req = [[ASPhotosFrameworkImageRequest alloc] initWithAssetIdentifier:kTestAssetID];
  req.options.networkAccessAllowed = YES;
  req.options.normalizedCropRect = CGRectMake(0.2, 0.1, 0.6, 0.8);
  req.targetSize = CGSizeMake(1024, 1536);
  req.contentMode = PHImageContentModeAspectFill;
  req.options.version = PHImageRequestOptionsVersionOriginal;
  req.options.resizeMode = PHImageRequestOptionsResizeModeFast;
  return req;
}

+ (NSURL *)urlForExampleImageRequest
{
  NSString *str = [NSString stringWithFormat:@"ph://%@?width=1024&height=1536&version=2&contentmode=1&network=1&resizemode=1&deliverymode=0&crop_x=0.2&crop_y=0.1&crop_w=0.6&crop_h=0.8", kTestAssetID];
  return [NSURL URLWithString:str];
}

#pragma mark Test cases

- (void)testThatConvertingToURLWorks
{
  XCTAssertEqualObjects([self.class exampleImageRequest].url, [self.class urlForExampleImageRequest]);
}

- (void)testThatParsingFromURLWorks
{
  NSURL *url = [self.class urlForExampleImageRequest];
  XCTAssertEqualObjects([ASPhotosFrameworkImageRequest requestWithURL:url], [self.class exampleImageRequest]);
}

- (void)testThatCopyingWorks
{
  ASPhotosFrameworkImageRequest *example = [self.class exampleImageRequest];
  ASPhotosFrameworkImageRequest *copy = [[self.class exampleImageRequest] copy];
  XCTAssertEqualObjects(example, copy);
}

@end

#endif
