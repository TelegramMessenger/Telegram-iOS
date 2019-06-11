//
//  CBConstance.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 19/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CBSuccessBlock)(id result);
//typedef void (^CBSuccessWithUserInfoBlock)(id result, id userInfo);
typedef void (^CBFailureBlock)(NSError *error);

extern NSString * const kCBServerURL;

extern NSString * const CBCoubLoopErrorDomain;
enum {
	CBCoubLoopErrorUnknown = 1,
	CBCoubLoopErrorNoSuchFile,
	CBCoubLoopErrorUnsupportedAudioFormat,
	CBCoubLoopErrorUnreadableAudioTrack,
	CBCoubLoopErrorNoVideoTracks,
	CBCoubLoopErrorCanceled,
};


extern NSString *const CBPlayerInterruptionDidBeginNotification;
extern NSString *const CBPlayerInterruptionDidEndNotification;

@interface CBConstance : NSObject

@end
