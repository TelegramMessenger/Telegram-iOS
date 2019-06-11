//
//  ASTip.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASTip.h>

#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASDisplayNode.h>

@implementation ASTip

- (instancetype)initWithNode:(ASDisplayNode *)node
                        kind:(ASTipKind)kind
                      format:(NSString *)format, ...
{
  if (self = [super init]) {
    _node = node;
    _kind = kind;
    va_list args;
    va_start(args, format);
    _text = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  }
  return self;
}

@end

#endif // AS_ENABLE_TIPS
