//
// Created by Tikhonenko Pavel on 29/11/2013.
// Copyright (c) 2013 Coub. All rights reserved.
//


#import "CBJSONCoubMapper.h"
#import "CBCoubNew.h"
#import "NSDictionary+CBExtensions.h"
#import "CBCoubVideoSource.h"
#import "CBCoubAudioSource.h"
#import "CBTagNew.h"



@implementation CBJSONCoubMapper
{

}

+ (CBCoubNew *)updateCoubFromCoub:(CBCoubNew *)newCoub coub:(CBCoubNew *)coub
{
	coub.title = newCoub.title;
	coub.liked = newCoub.liked;
	coub.visibility = newCoub.visibility;
	coub.recoubed = newCoub.recoubed;
	coub.likeCount = newCoub.likeCount;
	coub.recoubCount = newCoub.recoubCount;
	coub.cotd = newCoub.cotd;
	coub.flagged = newCoub.flagged;
	coub.creationDate = coub.creationDate;
	coub.creationDateAsString = coub.creationDateAsString;

//	if(newCoub.isDone)
//		coub.state = CBCoubDraftCompleted;

	return coub;
}

+ (CBCoubNew *)updateCoubFromJSONObject:(NSDictionary *)attributes coub:(CBCoubNew *)coub
{
	static NSDictionary *kCoubJSONKeys = nil;
	if(!kCoubJSONKeys)
	{
		kCoubJSONKeys = @{
				//@"permalink" : @"permalink",
				@"title" : @"title",
				@"visibility_type" : @"visibility",
				//@"created_at" : @"creationDateAsString",
				//@"external_download" : @"externalDownloadAsDictionary",
				@"like" : @"liked",
				@"recoub" : @"recoubed",
				@"likes_count" : @"likeCount",
				@"views_count" : @"viewCount",
				@"recoubs_count" : @"recoubCount",
				@"cotd" : @"cotd",
				@"flag" : @"flagged",
		};
	}

    if ([attributes[@"title"] isKindOfClass:[NSString class]])
    {
        NSString *title = attributes[@"title"];
        coub.title = title;
    }
    
	NSDictionary *recoubInfo = nil;

	if(attributes[@"permalink"])
		coub.permalink = attributes[@"permalink"];

	if(attributes[@"id"])
		coub.coubID = [attributes[@"id"] stringValue];

	coub.originalPermalink = attributes[@"permalink"];
	coub.originalCreationDateAsString = attributes[@"created_at"];

	if (coub.author == nil)
	{
		coub.author = [CBCoubAuthorVO coubAuthorWithAttributes:attributes[@"user"]];
		//coub.authorCD = [CBUserNewuserWithAttributes:attributes[@"user"]];
	}
    
    if (coub.author.name.length == 0)
    {
        NSDictionary *channel = attributes[@"channel"];
        if ([channel respondsToSelector:@selector(objectForKey:)])
            coub.author.name = channel[@"title"];
    }
    
	if(attributes[@"is_done"])
		coub.isDone = [attributes[@"is_done"] boolValue];

	NSString *remoteVideoLocation = nil;
	NSDictionary *fileVersions = attributes[@"file_versions"];
	if(fileVersions)
	{
		remoteVideoLocation = fileVersions[@"iphone"][@"url"];
	}
	if(!remoteVideoLocation)
		remoteVideoLocation = attributes[@"file"];
    if(!remoteVideoLocation || [remoteVideoLocation isEqual:[NSNull null]])
        remoteVideoLocation = fileVersions[@"mobile"][@"gifv"];
    
	if(remoteVideoLocation)
	{
		//
		NSRange r1 = [remoteVideoLocation rangeOfString:@"iphone_"];
		NSRange r2 = [remoteVideoLocation rangeOfString:@"_iphone"];
        
        if (r1.location == NSNotFound)
        {
            r1 = [remoteVideoLocation rangeOfString:@"gifv_"];
            r2 = [remoteVideoLocation rangeOfString:@"_gifv"];
        }
        
        if (r1.location != NSNotFound)
        {
            NSInteger loc = r1.length+r1.location;
            NSString *someVideoMetadataString = [remoteVideoLocation substringWithRange:NSMakeRange(loc, r2.location - loc)];

            remoteVideoLocation = fileVersions[@"web"][@"template"];
            NSRange r3 = [remoteVideoLocation rangeOfString:@"%{"];

            remoteVideoLocation = [remoteVideoLocation substringToIndex:r3.location];
            remoteVideoLocation = [NSString stringWithFormat:@"%@mp4_med_size_%@_med.mp4", remoteVideoLocation, someVideoMetadataString];
            coub.remoteVideoLocation = remoteVideoLocation;
        }
        else if ([remoteVideoLocation rangeOfString:@"mp4_med_size_"].location != NSNotFound)
        {
            coub.remoteVideoLocation = remoteVideoLocation;
        }
	}


	NSString *remoteAudioLocation = [attributes[@"audio_versions"] coubURIFromVersionTemplateWithPreferredSubstitutions:@[@"low", @"mid", @"high"]];
	if(!remoteAudioLocation)
		remoteAudioLocation = attributes[@"audio_file_url"];
    if(!remoteAudioLocation || [remoteAudioLocation isEqual:[NSNull null]])
        remoteAudioLocation = fileVersions[@"mobile"][@"mp3"];
	if(remoteAudioLocation)
		coub.remoteAudioLocation = remoteAudioLocation;

	NSDictionary *chunks = attributes[@"audio_versions"][@"chunks"];

	if(chunks)
	{
		NSString *audioTemplate  = chunks[@"template"];
		audioTemplate = [audioTemplate stringByReplacingOccurrencesOfString:@"%{version}" withString:@"low"];
		audioTemplate = [audioTemplate stringByReplacingOccurrencesOfString:@"%{chunk}" withString:@"%i"];
		coub.remoteAudioLocationPattern = audioTemplate;
	}

//	coub.remoteAudioLocationPattern = @"http://cdn1.akamai.coub.com/coub/simple/cw_audio/da1afb3df6f/734ed138b3577134af8bb/mp3_low_c%i_1400747442_out.mp3";

	// big, med, small, ios_large
	//KALog(@"ff=%@", [attributes[@"first_frame_versions"][@"versions"] componentsJoinedByString: @", "]);
	NSString *largePictureLocation = [attributes[@"first_frame_versions"] coubURIFromVersionTemplateWithPreferredSubstitutions:@[@"med", @"big", @"ios_large"]];
	if(largePictureLocation)
		coub.largePicture = largePictureLocation;

	// micro, tiny, age_restricted, ios_large, ios_mosaic, big, med, small
	NSString *mediumPictureLocation = [attributes[@"image_versions"] coubURIFromVersionTemplateWithPreferredSubstitutions:@[@"ios_mosaic", @"small", @"med"]];
	if(!mediumPictureLocation)
		mediumPictureLocation = attributes[@"picture"]; // short JSON
	if(mediumPictureLocation)
		coub.mediumPicture = mediumPictureLocation;

	// Determine the type of audio based on the values of "has_sound" and "audio_file_url"
	if(coub.remoteAudioLocation && ([coub.remoteAudioLocation isKindOfClass:[NSString class]] && [coub.remoteAudioLocation length] < 8))
		coub.remoteAudioLocation = nil;

	if(attributes[@"visibility_type"])
	{
		coub.audioType = coub.remoteAudioLocationPattern ? CBCoubAudioTypeExternal : ([attributes[@"has_sound"] boolValue] ? CBCoubAudioTypeInternal : CBCoubAudioTypeNone);
	}
	// else a short JSON doesn't have any information on sound

	NSDictionary *mediaBlock = attributes[@"media_blocks"];

	BOOL isCoubAudioSourceAvailable = mediaBlock[@"audio_track"] != nil;
	BOOL isCoubVideoSourceAvailable = mediaBlock[@"external_video"] != nil;

	if(isCoubVideoSourceAvailable)
		coub.videoSource = [CBCoubVideoSource sourceFromData:mediaBlock[@"external_video"]];
	if(isCoubAudioSourceAvailable)
		coub.audioSource = [CBCoubAudioSource sourceFromData:mediaBlock[@"audio_track"]];

	if(coub.audioSource || coub.videoSource)
		coub.isCoubSourcesAvailable = YES;

	NSDictionary *externalDownloadInfo = attributes[@"external_download"];
	if([externalDownloadInfo isKindOfClass:[NSDictionary class]])
	{
		coub.externalDownloadType = externalDownloadInfo[@"type"];
		coub.externalDownloadSource = externalDownloadInfo[@"url"];
	}else
	{
		// Coub API may return a boolean "false" as "external_download" value
		coub.externalDownloadType = nil;
		coub.externalDownloadSource = nil;
	}

	NSArray *tags = attributes[@"tags"];
	if(tags)
	{
		NSMutableArray *mutableArray = [NSMutableArray arrayWithCapacity:tags.count];
		[tags enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
		{
			[mutableArray addObject:[CBTagNew tagWithAttributes:obj]];
		}];

		coub.tags = [NSArray arrayWithArray:mutableArray];
	}



	if(recoubInfo)
	{
		coub.recouber = [CBCoubAuthorVO coubAuthorWithAttributes:recoubInfo[@"user"]];
		coub.liked = [recoubInfo[@"like"] boolValue];
		coub.recoubed = [recoubInfo[@"recoub"] boolValue];
		coub.flagged = [recoubInfo[@"flagged"] boolValue];
	}

	if(!coub.coubID)
		[NSException raise:NSInternalInconsistencyException format:@"No coub id found in %@", attributes];
	if(!coub.permalink)
		[NSException raise:NSInternalInconsistencyException format:@"No coub permalink found in %@", attributes];

	NSArray *size = attributes[@"dimensions"][@"small"];

	//coub.naturalVideoSize = CGSizeMake([size[0] floatValue], [size[1] floatValue]);
	return coub;
}

+ (CBCoubNew *)coubFromJSONObject:(NSDictionary *)jsonObj
{
	return [self updateCoubFromJSONObject:jsonObj coub:[CBCoubNew new]];
}

@end
