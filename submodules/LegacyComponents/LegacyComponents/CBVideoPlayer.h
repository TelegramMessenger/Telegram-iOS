//
//  CBVideoPlayer.h
//  Coub
//
//  Created by Pavel Tikhonenko on 12/08/14.
//  Copyright (c) 2014 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef enum
{
	CBVideoPlayerStatusInited,
	CBVideoPlayerStatusPrepairing = 1,
	CBVideoPlayerStatusReadyToPlay = 1 << 1,
	CBVideoPlayerStatusFailed = 1 << 2,
	CBVideoPlayerStatusUnknown = NSNotFound

}
CBVideoPlayerStatus;

@interface CBVideoPlayer : NSObject

@property (nonatomic, assign) CBVideoPlayerStatus status;

- (id)initWithVideoLayer:(AVPlayerLayer *)layer;

- (void)prepareWithAVAsset:(AVAsset *)asset completion:(void (^)(NSError *error))completion;
- (void)stopPrepairing;

- (void)play;
- (void)pause;
- (void)stop;

@end
