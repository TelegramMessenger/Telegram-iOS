//
//  ASLayout+IGListKit.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//
#import <AsyncDisplayKit/ASAvailability.h>
#if AS_IG_LIST_KIT
#import "ASLayout+IGListKit.h"

@interface ASLayout() {
@public
  id<ASLayoutElement> _layoutElement;
}
@end

@implementation ASLayout(IGListKit)

- (id <NSObject>)diffIdentifier
{
  return self->_layoutElement;
}

- (BOOL)isEqualToDiffableObject:(id <IGListDiffable>)other
{
  return [self isEqual:other];
}
@end
#endif // AS_IG_LIST_KIT
