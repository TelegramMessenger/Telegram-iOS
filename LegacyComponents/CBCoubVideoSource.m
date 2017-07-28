//
//  CBCoubVideoSource.m
//  Coub
//
//  Created by Tikhonenko Pavel on 18/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import "CBCoubVideoSource.h"

@implementation CBCoubVideoSource

- (BOOL)isYouTube
{
	return [_yourtubeURL rangeOfString:@"youtube"].length != 0;
}

+ (CBCoubVideoSource *)sourceFromData:(NSDictionary *)dict
{
	if(!dict.count) return nil;
	
	CBCoubVideoSource *source = [[CBCoubVideoSource alloc] init];
	source.yourtubeURL = dict[@"url"];
	source.title = dict[@"title"];
	source.thumbnail = dict[@"image"];
	
	if(source.yourtubeURL == nil)
		return nil;
	
	return source;
}

@end
