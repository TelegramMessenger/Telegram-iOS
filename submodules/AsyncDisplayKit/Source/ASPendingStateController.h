//
//  ASPendingStateController.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASDisplayNode;

NS_ASSUME_NONNULL_BEGIN

/**
 A singleton that is responsible for applying changes to
 UIView/CALayer properties of display nodes when they
 have been set on background threads.
 
 This controller will enqueue run-loop events to flush changes
 but if you need them flushed now you can call `flush` from the main thread.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASPendingStateController : NSObject

+ (ASPendingStateController *)sharedInstance;

@property (nonatomic, readonly) BOOL hasChanges;

/**
 Flush all pending states for nodes now. Any UIView/CALayer properties
 that have been set in the background will be applied to their
 corresponding views/layers before this method returns.
 
 You must call this method on the main thread.
 */
- (void)flush;

/**
 Register this node as having pending state that needs to be copied
 over to the view/layer. This is called automatically by display nodes
 when their view/layer properties are set post-load on background threads.
 */
- (void)registerNode:(ASDisplayNode *)node;

@end

NS_ASSUME_NONNULL_END
