//
//  LayoutExampleNodes.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface LayoutExampleNode : ASDisplayNode
+ (NSString *)title;
+ (NSString *)descriptionTitle;
@end

@interface HeaderWithRightAndLeftItems : LayoutExampleNode
@end

@interface PhotoWithInsetTextOverlay : LayoutExampleNode
@end

@interface PhotoWithOutsetIconOverlay : LayoutExampleNode
@end

@interface FlexibleSeparatorSurroundingContent : LayoutExampleNode
@end

@interface CornerLayoutExample : PhotoWithOutsetIconOverlay
@end

@interface UserProfileSample : LayoutExampleNode
@end
