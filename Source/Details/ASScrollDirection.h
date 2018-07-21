//
//  ASScrollDirection.h
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
#import <CoreGraphics/CGAffineTransform.h>

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, ASScrollDirection) {
  ASScrollDirectionNone  = 0,
  ASScrollDirectionRight = 1 << 0,
  ASScrollDirectionLeft  = 1 << 1,
  ASScrollDirectionUp    = 1 << 2,
  ASScrollDirectionDown  = 1 << 3
};

AS_EXTERN const ASScrollDirection ASScrollDirectionHorizontalDirections;
AS_EXTERN const ASScrollDirection ASScrollDirectionVerticalDirections;

AS_EXTERN BOOL ASScrollDirectionContainsVerticalDirection(ASScrollDirection scrollDirection);
AS_EXTERN BOOL ASScrollDirectionContainsHorizontalDirection(ASScrollDirection scrollDirection);

AS_EXTERN BOOL ASScrollDirectionContainsRight(ASScrollDirection scrollDirection);
AS_EXTERN BOOL ASScrollDirectionContainsLeft(ASScrollDirection scrollDirection);
AS_EXTERN BOOL ASScrollDirectionContainsUp(ASScrollDirection scrollDirection);
AS_EXTERN BOOL ASScrollDirectionContainsDown(ASScrollDirection scrollDirection);
AS_EXTERN ASScrollDirection ASScrollDirectionApplyTransform(ASScrollDirection scrollDirection, CGAffineTransform transform);

NS_ASSUME_NONNULL_END
