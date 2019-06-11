//
//  ASListTestSection.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <IGListKit/IGListKit.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASListTestSection : IGListSectionController <ASSectionController>

@property (nonatomic) NSInteger itemCount;

@property (nonatomic) NSInteger selectedItemIndex;

@end
