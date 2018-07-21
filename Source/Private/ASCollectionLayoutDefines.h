//
//  ASCollectionLayoutDefines.h
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASScrollDirection.h>

NS_ASSUME_NONNULL_BEGIN

AS_EXTERN ASSizeRange ASSizeRangeForCollectionLayoutThatFitsViewportSize(CGSize viewportSize, ASScrollDirection scrollableDirections) AS_WARN_UNUSED_RESULT;

NS_ASSUME_NONNULL_END
