//
//  CBCoubAuthorVO.h
//  Coub
//
//  Created by Tikhonenko Pavel on 21/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CBCoubAuthorVO : NSObject

@property (nonatomic, strong) NSString *avatarURL;
@property (nonatomic, strong) NSString *largeAvatarURL;
@property (nonatomic, assign) NSInteger followersCount;
@property (nonatomic, assign) NSInteger viewsCount;
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *permalink;

+ (CBCoubAuthorVO *)coubAuthorWithAttributes:(NSDictionary *)attributes;
+ (CBCoubAuthorVO *)currentUser;
@end
