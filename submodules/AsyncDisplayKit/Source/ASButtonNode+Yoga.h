//
//  ASButtonNode+Yoga.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASButtonNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASButtonNode (Yoga)

- (void)updateYogaLayoutIfNeeded;

@end

NS_ASSUME_NONNULL_END
