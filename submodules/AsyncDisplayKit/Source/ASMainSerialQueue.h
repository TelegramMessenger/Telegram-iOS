//
//  ASMainSerialQueue.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

AS_SUBCLASSING_RESTRICTED
@interface ASMainSerialQueue : NSObject

@property (nonatomic, readonly) NSUInteger numberOfScheduledBlocks;
- (void)performBlockOnMainThread:(dispatch_block_t)block;

@end
