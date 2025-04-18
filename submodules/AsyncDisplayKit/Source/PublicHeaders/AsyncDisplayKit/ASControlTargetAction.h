//
//  ASControlTargetAction.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 @abstract ASControlTargetAction stores target action pairs registered for specific ASControlNodeEvent values.
 */
@interface ASControlTargetAction : NSObject

/** 
 The action to be called on the registered target.
 */
@property (nonatomic) SEL action;

/**
 Event handler target. The specified action will be called on this object.
 */
@property (nonatomic, weak) id target;

/**
 Indicated whether this target was created without a target, so the action should travel up in the responder chain.
 */
@property (nonatomic, readonly) BOOL createdWithNoTarget;

@end
