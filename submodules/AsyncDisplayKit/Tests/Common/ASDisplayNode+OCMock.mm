//
//  ASDisplayNode+OCMock.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * For some reason, when creating partial mocks of nodes, OCMock fails to find
 * these class methods that it swizzled!
 */
@implementation ASDisplayNode (OCMock)

+ (Class)ocmock_replaced_viewClass
{
  return [_ASDisplayView class];
}

+ (Class)ocmock_replaced_layerClass
{
  return [_ASDisplayLayer class];
}

@end
