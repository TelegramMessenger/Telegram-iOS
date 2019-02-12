//
//  ASTestCase.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <XCTest/XCTest.h>

// Not strictly necessary, but convenient
#import <OCMock/OCMock.h>

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "OCMockObject+ASAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@interface ASTestCase : XCTestCase

@property (class, nonatomic, nullable, readonly) ASTestCase *currentTestCase;

@end

NS_ASSUME_NONNULL_END
