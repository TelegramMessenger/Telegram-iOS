//
// Created by Tikhonenko Pavel on 30/11/2013.
// Copyright (c) 2013 Coub. All rights reserved.
//


#import "CBTagNew.h"


@implementation CBTagNew
{

}

- (NSString *)hashTag
{
	return [@"#" stringByAppendingString:_title];
}

+ (instancetype)tagWithAttributes:(NSDictionary *)attributes
{
	CBTagNew *tag = [CBTagNew new];
	tag.tagId = attributes[@"id"];
	tag.title = attributes[@"title"];
	tag.value = attributes[@"value"];
	return tag;
}

@end