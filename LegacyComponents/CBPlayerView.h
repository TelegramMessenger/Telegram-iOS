//
//  CBPlayerView.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 17/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

#import "CBCoubPlayer.h"
#import "CBPlayerLayerView.h"

@interface CBPlayerView : UIView <CBCoubPlayerDelegate>

@property (nonatomic, readonly) UIImageView *preview;
@property (nonatomic, readonly) CBPlayerLayerView *videoPlayerView;

- (void)play;
- (void)stop;

@end

//@interface CBPlayerLayerView : UIView
//@end