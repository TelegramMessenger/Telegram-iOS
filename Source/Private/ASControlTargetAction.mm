//
//  ASControlTargetAction.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASControlTargetAction.h>

@implementation ASControlTargetAction
{
  __weak id _target;
  BOOL _createdWithNoTarget;
}

- (void)setTarget:(id)target {
  _target = target;
  
  if (!target) {
    _createdWithNoTarget = YES;
  }
}

- (id)target {
  return _target;
}

- (BOOL)isEqual:(id)object {
  if (![object isKindOfClass:[ASControlTargetAction class]]) {
    return NO;
  }
  
  ASControlTargetAction *otherObject = (ASControlTargetAction *)object;
  
  BOOL areTargetsEqual;
  
  if (self.target != nil && otherObject.target != nil && self.target == otherObject.target) {
    areTargetsEqual = YES;
  }
  else if (self.target == nil && otherObject.target == nil && self.createdWithNoTarget && otherObject.createdWithNoTarget) {
    areTargetsEqual = YES;
  }
  else {
    areTargetsEqual = NO;
  }
  
  if (!areTargetsEqual) {
    return NO;
  }
  
  if (self.action && otherObject.action && self.action == otherObject.action) {
    return YES;
  }
  else {
    return NO;
  }
}

- (NSUInteger)hash {
  return [self.target hash];
}

@end
