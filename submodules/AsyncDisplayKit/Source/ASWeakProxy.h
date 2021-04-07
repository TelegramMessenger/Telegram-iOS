//
//  ASWeakProxy.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

AS_SUBCLASSING_RESTRICTED
@interface ASWeakProxy : NSProxy

/**
 * @return target The target which will be forwarded all messages sent to the weak proxy.
 */
@property (nonatomic, weak, readonly) id target;

/**
 * An object which forwards messages to a target which it weakly references
 *
 * @discussion This class is useful for breaking retain cycles. You can pass this in place
 * of the target to something which creates a strong reference. All messages sent to the
 * proxy will be passed onto the target.
 *
 * @return an instance of ASWeakProxy
 */
+ (instancetype)weakProxyWithTarget:(id)target NS_RETURNS_RETAINED;

@end
