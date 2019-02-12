//
//  ASSnapshotTestCase.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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

#define ASSnapshotVerifyViewWithTolerance(view__, identifier__, tolerance__) \
    FBSnapshotVerifyLayerWithOptions(view__, identifier__, ASSnapshotTestCaseDefaultSuffixes(), tolerance__);

@interface ASSnapshotTestCase : FBSnapshotTestCase

/**
 * Hack for testing.  ASDisplayNode lacks an explicit -render method, so we manually hit its layout & display codepaths.
 */
+ (void)hackilySynchronouslyRecursivelyRenderNode:(ASDisplayNode *)node;

@end
