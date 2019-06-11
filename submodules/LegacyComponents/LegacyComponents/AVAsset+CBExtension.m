//
//  AVAsset+Extension.m
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 19/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import "AVAsset+CBExtension.h"

@implementation AVAsset (CBExtension)

- (AVAssetTrack *)anyVideoTrack
{
    NSArray *videoTracks = [self tracksWithMediaType:AVMediaTypeVideo];
    return [videoTracks count] ? videoTracks[0] : nil;
}

- (AVAssetTrack *)anyAudioTrack
{
    NSArray *audioTracks = [self tracksWithMediaType:AVMediaTypeAudio];
    return [audioTracks count] ? audioTracks[0] : nil;
}

@end
