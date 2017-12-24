//
//  ASLayoutTestNode.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <OCMock/OCMock.h>

@interface ASLayoutTestNode : ASDisplayNode

/**
 * Mocking ASDisplayNodes directly isn't very safe because when you pump mock objects
 * into the guts of the framework, bad things happen e.g. direct-ivar-access on mock
 * objects will return garbage data.
 *
 * Instead we create a strict mock for each node, and forward a selected set of calls to it.
 */
@property (nonatomic, strong, readonly) id mock;

/**
 * The size that this node will return in calculateLayoutThatFits (if it doesn't have a layoutSpecBlock).
 *
 * Changing this value will call -setNeedsLayout on the node.
 */
@property (nonatomic) CGSize testSize;

/**
 * Generate a layout based on the frame of this node and its subtree.
 *
 * The root layout will be unpositioned. This is so that the returned layout can be directly
 * compared to `calculatedLayout`
 */
- (ASLayout *)currentLayoutBasedOnFrames;

@end
