//
//  CBPlayerLayerView.m
//  Coub
//
//  Created by Tikhonenko Pavel on 23/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import "CBPlayerLayerView.h"

#import <AVFoundation/AVFoundation.h>

@implementation CBPlayerLayerView

+ (Class)layerClass
{
	return [AVPlayerLayer class];
}

@end
