//
//  CBCoubPlayerContance.h
//  CoubPlayer
//
//  Created by Pavel Tikhonenko on 19/10/14.
//  Copyright (c) 2014 Pavel Tikhonenko. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(UInt16, CBCoubAudioType)
{
    CBCoubAudioTypeNone = 0,
    CBCoubAudioTypeInternal,
    CBCoubAudioTypeExternal,
};

@interface CBCoubPlayerContance : NSObject

@end
