//
//  AVAsset+Extension.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 19/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVAsset (CBExtension)

@property (nonatomic, readonly) AVAssetTrack *anyVideoTrack;
@property (nonatomic, readonly) AVAssetTrack *anyAudioTrack;

@end
