//
//  ASMultiplexImageNodeTests.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <OCMock/OCMock.h>
#import "NSInvocation+ASTestHelpers.h"

#import <AsyncDisplayKit/ASImageProtocols.h>
#import <AsyncDisplayKit/ASMultiplexImageNode.h>
#import <AsyncDisplayKit/ASImageContainerProtocolCategories.h>

#import <XCTest/XCTest.h>

@interface ASMultiplexImageNodeTests : XCTestCase
{
@private
  id mockCache;
  id mockDownloader;
  id mockDataSource;
  id mockDelegate;
  ASMultiplexImageNode *imageNode;
}

@end

@implementation ASMultiplexImageNodeTests

#pragma mark - Helpers.

- (NSURL *)_testImageURL
{
  return [[NSBundle bundleForClass:[self class]] URLForResource:@"logo-square"
                                                  withExtension:@"png"
                                                   subdirectory:@"TestResources"];
}

- (UIImage *)_testImage
{
  return [UIImage imageWithContentsOfFile:[self _testImageURL].path];
}

#pragma mark - Unit tests.

// TODO:  add tests for delegate display notifications

- (void)setUp
{
  [super setUp];

  mockCache = OCMStrictProtocolMock(@protocol(ASImageCacheProtocol));
  [mockCache setExpectationOrderMatters:YES];
  mockDownloader = OCMStrictProtocolMock(@protocol(ASImageDownloaderProtocol));
  [mockDownloader setExpectationOrderMatters:YES];
  imageNode = [[ASMultiplexImageNode alloc] initWithCache:mockCache downloader:mockDownloader];

  mockDataSource = OCMStrictProtocolMock(@protocol(ASMultiplexImageNodeDataSource));
  [mockDataSource setExpectationOrderMatters:YES];
  imageNode.dataSource = mockDataSource;

  mockDelegate = OCMProtocolMock(@protocol(ASMultiplexImageNodeDelegate));
  [mockDelegate setExpectationOrderMatters:YES];
  imageNode.delegate = mockDelegate;
}

- (void)tearDown
{
  OCMVerifyAll(mockDelegate);
  OCMVerifyAll(mockDataSource);
  OCMVerifyAll(mockDownloader);
  OCMVerifyAll(mockCache);
  [super tearDown];
}

- (void)testDataSourceImageMethod
{
  NSNumber *imageIdentifier = @1;

  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:imageIdentifier])
  .andReturn([self _testImage]);

  imageNode.imageIdentifiers = @[imageIdentifier];
  [imageNode reloadImageIdentifierSources];

  // Also expect it to be loaded immediately.
  XCTAssertEqualObjects(imageNode.loadedImageIdentifier, imageIdentifier, @"imageIdentifier was not loaded");
  // And for the image to be equivalent to the image we provided.
  XCTAssertEqualObjects(UIImagePNGRepresentation(imageNode.image),
                        UIImagePNGRepresentation([self _testImage]),
                        @"Loaded image isn't the one we provided");
}

- (void)testDataSourceURLMethod
{
  NSNumber *imageIdentifier = @1;

  // First expect to be hit for the image directly, and fail to return it.
  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:imageIdentifier])
  .andReturn((id)nil);
  // BUG: -imageForImageIdentifier is called twice in this case (where we return nil).
  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:imageIdentifier])
  .andReturn((id)nil);
  // Then expect to be hit for the URL, which we'll return.
  OCMExpect([mockDataSource multiplexImageNode:imageNode URLForImageIdentifier:imageIdentifier])
  .andReturn([self _testImageURL]);

  // Mock the cache to do a cache-hit for the test image URL.
  OCMExpect([mockCache cachedImageWithURL:[self _testImageURL] callbackQueue:OCMOCK_ANY completion:[OCMArg isNotNil]])
  .andDo(^(NSInvocation *inv) {
    ASImageCacherCompletion completionBlock = [inv as_argumentAtIndexAsObject:4];
    completionBlock([self _testImage]);
  });

  imageNode.imageIdentifiers = @[imageIdentifier];
  // Kick off loading.
  [imageNode reloadImageIdentifierSources];

  // Also expect it to be loaded immediately.
  XCTAssertEqualObjects(imageNode.loadedImageIdentifier, imageIdentifier, @"imageIdentifier was not loaded");
  // And for the image to be equivalent to the image we provided.
  XCTAssertEqualObjects(UIImagePNGRepresentation(imageNode.image),
                        UIImagePNGRepresentation([self _testImage]),
                        @"Loaded image isn't the one we provided");
}

- (void)testAddLowerQualityImageIdentifier
{
  // Adding a lower quality image identifier should not cause any loading.
  NSNumber *highResIdentifier = @2, *lowResIdentifier = @1;

  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:highResIdentifier])
  .andReturn([self _testImage]);
  imageNode.imageIdentifiers = @[highResIdentifier];
  [imageNode reloadImageIdentifierSources];

  // At this point, we should have the high-res identifier loaded and the DS should have been hit once.
  XCTAssertEqualObjects(imageNode.loadedImageIdentifier, highResIdentifier, @"High res identifier should be loaded.");

  // BUG: We should not get another -imageForImageIdentifier:highResIdentifier.
  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:highResIdentifier])
  .andReturn([self _testImage]);

  imageNode.imageIdentifiers = @[highResIdentifier, lowResIdentifier];
  [imageNode reloadImageIdentifierSources];

  // At this point the high-res should still be loaded, and the data source should not have been hit again (see BUG above).
  XCTAssertEqualObjects(imageNode.loadedImageIdentifier, highResIdentifier, @"High res identifier should be loaded.");
}

- (void)testAddHigherQualityImageIdentifier
{
  NSNumber *lowResIdentifier = @1, *highResIdentifier = @2;

  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:lowResIdentifier])
  .andReturn([self _testImage]);

  imageNode.imageIdentifiers = @[lowResIdentifier];
  [imageNode reloadImageIdentifierSources];

  // At this point, we should have the low-res identifier loaded and the DS should have been hit once.
  XCTAssertEqualObjects(imageNode.loadedImageIdentifier, lowResIdentifier, @"Low res identifier should be loaded.");

  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:highResIdentifier])
  .andReturn([self _testImage]);

  imageNode.imageIdentifiers = @[highResIdentifier, lowResIdentifier];
  [imageNode reloadImageIdentifierSources];

  // At this point the high-res should be loaded, and the data source should been hit twice.
  XCTAssertEqualObjects(imageNode.loadedImageIdentifier, highResIdentifier, @"High res identifier should be loaded.");
}

- (void)testIntermediateImageDownloading
{
  imageNode.downloadsIntermediateImages = YES;

  // Let them call URLForImageIdentifier all they want.
  OCMStub([mockDataSource multiplexImageNode:imageNode URLForImageIdentifier:[OCMArg isNotNil]]);

  // Set up a few identifiers to load.
  NSInteger identifierCount = 5;
  NSMutableArray *imageIdentifiers = [NSMutableArray array];
  for (NSInteger identifier = identifierCount; identifier > 0; identifier--) {
    [imageIdentifiers addObject:@(identifier)];
  }

  // Create the array of IDs in the order we expect them to get -imageForImageIdentifier:
  // BUG: The second to last ID (the last one that returns nil) will get -imageForImageIdentifier: called
  // again after the last ID (the one that returns non-nil).
  id secondToLastID = imageIdentifiers[identifierCount - 2];
  NSArray *imageIdentifiersThatWillBeCalled = [imageIdentifiers arrayByAddingObject:secondToLastID];

  for (id imageID in imageIdentifiersThatWillBeCalled) {
    // Return nil for everything except the worst ID.
    OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:imageID])
    .andDo(^(NSInvocation *inv){
      id imageID = [inv as_argumentAtIndexAsObject:3];
      if ([imageID isEqual:imageIdentifiers.lastObject]) {
        [inv as_setReturnValueWithObject:[self _testImage]];
      } else {
        [inv as_setReturnValueWithObject:nil];
      }
    });
  }

  imageNode.imageIdentifiers = imageIdentifiers;
  [imageNode reloadImageIdentifierSources];
}

- (void)testUncachedDownload
{
  // Mock a cache miss.
  OCMExpect([mockCache cachedImageWithURL:[self _testImageURL] callbackQueue:OCMOCK_ANY completion:[OCMArg isNotNil]])
  .andDo(^(NSInvocation *inv){
    ASImageCacherCompletion completion = [inv as_argumentAtIndexAsObject:4];
    completion(nil);
  });

  // Mock a 50%-progress URL download.
  const CGFloat mockedProgress = 0.5;
  OCMExpect([mockDownloader downloadImageWithURL:[self _testImageURL] callbackQueue:OCMOCK_ANY downloadProgress:[OCMArg isNotNil] completion:[OCMArg isNotNil]])
  .andDo(^(NSInvocation *inv){
    // Simulate progress.
    ASImageDownloaderProgress progressBlock = [inv as_argumentAtIndexAsObject:4];
    progressBlock(mockedProgress);

    // Simulate completion.
    ASImageDownloaderCompletion completionBlock = [inv as_argumentAtIndexAsObject:5];
    completionBlock([self _testImage], nil, nil, nil);
  });

  NSNumber *imageIdentifier = @1;

  // Mock the data source to return nil image, and our test URL.
  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:imageIdentifier]);
  // BUG: Multiplex image node will call imageForImageIdentifier twice if we return nil.
  OCMExpect([mockDataSource multiplexImageNode:imageNode imageForImageIdentifier:imageIdentifier]);
  OCMExpect([mockDataSource multiplexImageNode:imageNode URLForImageIdentifier:imageIdentifier])
  .andReturn([self _testImageURL]);

  // Mock the delegate to expect start, 50% progress, and completion invocations.
  OCMExpect([mockDelegate multiplexImageNode:imageNode didStartDownloadOfImageWithIdentifier:imageIdentifier]);
  OCMExpect([mockDelegate multiplexImageNode:imageNode didUpdateDownloadProgress:mockedProgress forImageWithIdentifier:imageIdentifier]);
  OCMExpect([mockDelegate multiplexImageNode:imageNode didUpdateImage:[OCMArg isNotNil] withIdentifier:imageIdentifier fromImage:[OCMArg isNil] withIdentifier:[OCMArg isNil]]);
  OCMExpect([mockDelegate multiplexImageNode:imageNode didFinishDownloadingImageWithIdentifier:imageIdentifier error:[OCMArg isNil]]);

  imageNode.imageIdentifiers = @[imageIdentifier];
  // Kick off loading.
  [imageNode reloadImageIdentifierSources];

  // Wait until the image is loaded.
  [self expectationForPredicate:[NSPredicate predicateWithFormat:@"loadedImageIdentifier = %@", imageIdentifier] evaluatedWithObject:imageNode handler:nil];
  [self waitForExpectationsWithTimeout:30 handler:nil];
}

- (void)testThatSettingAnImageExternallyWillThrow
{
  XCTAssertThrows(imageNode.image = [UIImage imageNamed:@""]);
}

@end
