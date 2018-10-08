//
//  PhotoModel.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "PhotoModel.h"
#import "Utilities.h"

@implementation PhotoModel
{
  NSDictionary     *_dictionaryRepresentation;
  NSString         *_uploadDateRaw;
}

#pragma mark - Lifecycle

- (instancetype)initWithUnsplashPhoto:(NSDictionary *)photoDictionary
{
  self = [super init];
  
  if (self) {
    _dictionaryRepresentation = photoDictionary;
    _uploadDateRaw            = [photoDictionary objectForKey:@"created_at"];
    _photoID                  = [photoDictionary objectForKey:@"id"];
    _descriptionText          = [photoDictionary valueForKeyPath:@"description"];
    _likesCount               = [[photoDictionary objectForKey:@"likes"] integerValue];
    _location                 = [photoDictionary objectForKey:@"location"];
    
    NSString *urlString       = [photoDictionary objectForKey:@"urls"][@"regular"];
    _URL                      = urlString ? [NSURL URLWithString:urlString] : nil;
    
    _ownerUserProfile         = [[UserModel alloc] initWithUnsplashPhoto:photoDictionary];
    _uploadDateString         = [NSString elapsedTimeStringSinceDate:_uploadDateRaw];
    
    _height = [[photoDictionary objectForKey:@"height"] integerValue];
    _width = [[photoDictionary objectForKey:@"width"] integerValue];
  }
  
  return self;
}

#pragma mark - Instance Methods

- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size
{
  NSString *string               = [NSString stringWithFormat:@"%@ %@", self.ownerUserProfile.username, self.descriptionText];
  NSAttributedString *attrString = [NSAttributedString attributedStringWithString:string
                                                                         fontSize:size
                                                                            color:[UIColor darkGrayColor]
                                                                   firstWordColor:[UIColor darkBlueColor]];
  return attrString;
}

- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.uploadDateString fontSize:size color:[UIColor lightGrayColor] firstWordColor:nil];
}

- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size
{
  NSString *likesString = [NSString stringWithFormat:@"♥︎ %lu likes", (unsigned long)_likesCount];

  return [NSAttributedString attributedStringWithString:likesString fontSize:size color:[UIColor darkBlueColor] firstWordColor:nil];
}

- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.location fontSize:size color:[UIColor lightBlueColor] firstWordColor:nil];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@ - %@", _photoID, _descriptionText];
}

- (id<NSObject>)diffIdentifier
{
  return self.photoID;
}

- (BOOL)isEqualToDiffableObject:(id<IGListDiffable>)object
{
  return [self isEqual:object];
}

@end
