//
//  ASResponderChainEnumerator.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <UIKit/UIResponder.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASResponderChainEnumerator : NSEnumerator

- (instancetype)initWithResponder:(UIResponder *)responder;

@end

@interface UIResponder (ASResponderChainEnumerator)

- (ASResponderChainEnumerator *)asdk_responderChainEnumerator;

@end


NS_ASSUME_NONNULL_END
