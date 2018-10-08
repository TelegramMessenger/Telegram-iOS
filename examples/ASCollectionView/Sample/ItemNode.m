//
//  ItemNode.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ItemNode.h"

@implementation ItemNode

- (instancetype)initWithString:(NSString *)string
{
  self = [super init];
  
  if (self != nil) {
    self.text = string;
    [self updateBackgroundColor];
  }
  
  return self;
}

- (void)updateBackgroundColor
{
  if (self.highlighted) {
    self.backgroundColor = [UIColor grayColor];
  } else if (self.selected) {
    self.backgroundColor = [UIColor darkGrayColor];
  } else {
    self.backgroundColor = [UIColor lightGrayColor];
  }
}

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  
  [self updateBackgroundColor];
}

- (void)setHighlighted:(BOOL)highlighted
{
  [super setHighlighted:highlighted];
  
  [self updateBackgroundColor];
}

@end
