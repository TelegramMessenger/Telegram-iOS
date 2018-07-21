//
//  UserModel.h
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

@interface UserModel : NSObject

@property (nonatomic, strong, readonly) NSDictionary *dictionaryRepresentation;
@property (nonatomic, assign, readonly) NSString     *userID;
@property (nonatomic, strong, readonly) NSString     *username;
@property (nonatomic, strong, readonly) NSString     *firstName;
@property (nonatomic, strong, readonly) NSString     *lastName;
@property (nonatomic, strong, readonly) NSString     *fullName;
@property (nonatomic, strong, readonly) NSString     *location;
@property (nonatomic, strong, readonly) NSString     *about;
@property (nonatomic, strong, readonly) NSURL        *userPicURL;
@property (nonatomic, assign, readonly) NSUInteger   photoCount;
@property (nonatomic, assign, readonly) NSUInteger   galleriesCount;
@property (nonatomic, assign, readonly) NSUInteger   affection;
@property (nonatomic, assign, readonly) NSUInteger   friendsCount;
@property (nonatomic, assign, readonly) NSUInteger   followersCount;
@property (nonatomic, assign, readonly) BOOL         following;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUnsplashPhoto:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)fullNameAttributedStringWithFontSize:(CGFloat)size;

- (void)fetchAvatarImageWithCompletionBlock:(void(^)(UserModel *, UIImage *))block;

- (void)downloadCompleteUserDataWithCompletionBlock:(void(^)(UserModel *))block;

@end
