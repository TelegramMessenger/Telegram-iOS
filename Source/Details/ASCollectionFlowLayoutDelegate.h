//
//  ASCollectionFlowLayoutDelegate.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASCollectionLayoutDelegate.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED

/**
 * A thread-safe, high performant layout delegate that arranges items into a flow layout. 
 * It uses a concurrent and multi-line ASStackLayoutSpec under the hood. Thus, per-child flex properties (i.e alignSelf, 
 * flexShrink, flexGrow, etc - see @ASStackLayoutElement) can be set directly on cell nodes to be used
 * to calculate the final collection layout.
 */
@interface ASCollectionFlowLayoutDelegate : NSObject <ASCollectionLayoutDelegate>

- (instancetype)initWithScrollableDirections:(ASScrollDirection)scrollableDirections NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END

#endif
