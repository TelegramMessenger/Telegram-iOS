//
//  CBCoubAuthorVO.m
//  Coub
//
//  Created by Tikhonenko Pavel on 21/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import "CBCoubAuthorVO.h"

@implementation CBCoubAuthorVO

+ (CBCoubAuthorVO *)coubAuthorWithAttributes:(NSDictionary *)attributes
{
	CBCoubAuthorVO *author = [CBCoubAuthorVO new];
	author.avatarURL = attributes[@"avatar"];
	author.largeAvatarURL = attributes[@"large_avatar"];
	author.followersCount = [attributes[@"followers_count"] integerValue];
	author.userId = [attributes[@"id"] stringValue];
	author.name = attributes[@"name"];
	author.permalink = attributes[@"permalink"];
	author.viewsCount = [attributes[@"views_count"] integerValue];
	//author.viewsCount;
	return author;
}

//+ (CBCoubAuthorVO *)currentUser
//{
//	CBUserNew *curUser = [CBUserNew currentUser];
//
//	CBCoubAuthorVO *author = [CBCoubAuthorVO new];
//	author.avatarURL = curUser.mediumAvatar;
//	author.largeAvatarURL = curUser.largeAvatar;
//	author.followersCount = curUser.followerCount;
//	author.userId = curUser.coubID;
//	author.name = curUser.fullName;
//	author.permalink = curUser.permalink;
//	author.viewsCount = curUser.viewsCount;
//	return author;
//}

@end
