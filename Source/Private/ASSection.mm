//
//  ASSection.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK

#import <AsyncDisplayKit/ASSection.h>
#import <AsyncDisplayKit/ASSectionContext.h>

@implementation ASSection

- (instancetype)initWithSectionID:(NSInteger)sectionID context:(id<ASSectionContext>)context
{
  self = [super init];
  if (self) {
    _sectionID = sectionID;
    _context = context;
  }
  return self;
}

@end

#endif
