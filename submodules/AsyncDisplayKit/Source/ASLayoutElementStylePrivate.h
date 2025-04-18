//
//  ASLayoutElementStylePrivate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#pragma once

#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@interface ASLayoutElementStyle () <ASDescriptionProvider>

/**
 * @abstract The object that acts as the delegate of the style.
 *
 * @discussion The delegate must adopt the ASLayoutElementStyleDelegate protocol. The delegate is not retained.
 */
@property (nullable, nonatomic, weak) id<ASLayoutElementStyleDelegate> delegate;

/**
 * @abstract A size constraint that should apply to this ASLayoutElement.
 */
@property (nonatomic, readonly) ASLayoutElementSize size;

@property (nonatomic, assign) ASStackLayoutAlignItems parentAlignStyle;

@end
