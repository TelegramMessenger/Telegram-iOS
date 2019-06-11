//
//  PhotoCollectionViewCell.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "PhotoCollectionViewCell.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"

@implementation PhotoCollectionViewCell
{
  UIImageView  *_photoImageView;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {
  
    _photoImageView = [[UIImageView alloc] init];
    [_photoImageView setPin_updateWithProgress:YES];
    [self.contentView addSubview:_photoImageView];
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  _photoImageView.frame = self.bounds;
}

- (void)prepareForReuse
{
  [super prepareForReuse];
  
  // remove images so that the old content doesn't appear before the new content is loaded
  _photoImageView.image = nil;
}

#pragma mark - Instance Methods

- (void)updateCellWithPhotoObject:(PhotoModel *)photo
{
  // async download of photo using PINRemoteImage
  [_photoImageView pin_setImageFromURL:photo.URL];
}

@end
