//
//  ASAbsoluteLayoutElement.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 *  Layout options that can be defined for an ASLayoutElement being added to a ASAbsoluteLayoutSpec.
 */
@protocol ASAbsoluteLayoutElement

/**
 * @abstract The position of this object within its parent spec.
 */
@property (nonatomic) CGPoint layoutPosition;

@end

NS_ASSUME_NONNULL_END
