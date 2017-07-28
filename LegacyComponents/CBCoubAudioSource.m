//
//  CBCoubAudioSource.m
//  Coub
//
//  Created by Tikhonenko Pavel on 18/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import "CBCoubAudioSource.h"

@implementation CBCoubAudioSource

+ (CBCoubAudioSource *)sourceFromData:(NSDictionary *)dict
{
	if(!dict.count) return nil;
	

	NSDictionary *meta = dict[@"meta"];

	CBCoubAudioSource *source = [[CBCoubAudioSource alloc] init];
	source.cover = dict[@"image"];
	source.itunesURL = dict[@"url"];
	source.songName = meta[@"title"];
	source.title = source.songName;
	source.artist = meta[@"artist"];
	if(source.title == nil || source.itunesURL == nil)
		return nil;
	
	return source;
}

@end
