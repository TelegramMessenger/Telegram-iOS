//
//  ASSnapshotTestCase.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <FBSnapshotTestCase/FBSnapshotTestCase.h>
#import "ASDisplayNodeTestsHelper.h"

@class ASDisplayNode;

NSOrderedSet *ASSnapshotTestCaseDefaultSuffixes(void);

#define ASSnapshotVerifyNode(node__, identifier__) \
{ \
  [ASSnapshotTestCase hackilySynchronouslyRecursivelyRenderNode:node__]; \
  FBSnapshotVerifyLayerWithOptions(node__.layer, identifier__, ASSnapshotTestCaseDefaultSuffixes(), 0) \
}

#define ASSnapshotVerifyLayer(layer__, identifier__) \
  FBSnapshotVerifyLayerWithOptions(layer__, identifier__, ASSnapshotTestCaseDefaultSuffixes(), 0);

#define ASSnapshotVerifyView(view__, identifier__) \
	FBSnapshotVerifyViewWithOptions(view__, identifier__, ASSnapshotTestCaseDefaultSuffixes(), 0);

@interface ASSnapshotTestCase : FBSnapshotTestCase

/**
 * Hack for testing.  ASDisplayNode lacks an explicit -render method, so we manually hit its layout & display codepaths.
 */
+ (void)hackilySynchronouslyRecursivelyRenderNode:(ASDisplayNode *)node;

@end
