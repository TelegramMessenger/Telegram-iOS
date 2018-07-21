//
//  ASControlTargetAction.h
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

#import <Foundation/Foundation.h>

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
