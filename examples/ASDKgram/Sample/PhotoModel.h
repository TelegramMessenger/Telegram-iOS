//
//  PhotoModel.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) through the present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "UserModel.h"
#import <IGListKit/IGListKit.h>

@interface PhotoModel : NSObject <IGListDiffable>

@property (nonatomic, strong, readonly) NSURL                  *URL;
@property (nonatomic, strong, readonly) NSString               *photoID;
@property (nonatomic, strong, readonly) NSString               *uploadDateString;
@property (nonatomic, strong, readonly) NSString               *descriptionText;
@property (nonatomic, assign, readonly) NSUInteger             likesCount;
@property (nonatomic, strong, readonly) NSString               *location;
@property (nonatomic, strong, readonly) UserModel              *ownerUserProfile;
@property (nonatomic, assign, readonly) NSUInteger             width;
@property (nonatomic, assign, readonly) NSUInteger             height;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUnsplashPhoto:(NSDictionary *)photoDictionary NS_DESIGNATED_INITIALIZER;

- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size;

@end
