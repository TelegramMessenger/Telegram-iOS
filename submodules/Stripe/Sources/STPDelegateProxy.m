//
//  STPDelegateProxy.m
//  Stripe
//
//  Created by Jack Flintermann on 10/20/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import "STPDelegateProxy.h"

@implementation STPDelegateProxy

- (instancetype)init {
    return self;
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [_delegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    if ([self respondsToSelector:selector]) {
        return self;
    }
    if ([_delegate respondsToSelector:selector]) {
        return _delegate;
    }
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [super methodSignatureForSelector:selector] ?: [_delegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    if ([_delegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:_delegate];
    }
}

@end
