//
//  ASDisplayNode+DebugTiming.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASDisplayNode.h>

@interface ASDisplayNode (DebugTiming)

@property (nonatomic, readonly) NSTimeInterval debugTimeToCreateView;
@property (nonatomic, readonly) NSTimeInterval debugTimeToApplyPendingState;
@property (nonatomic, readonly) NSTimeInterval debugTimeToAddSubnodeViews;
@property (nonatomic, readonly) NSTimeInterval debugTimeForDidLoad;

- (NSTimeInterval)debugAllCreationTime;

@end
