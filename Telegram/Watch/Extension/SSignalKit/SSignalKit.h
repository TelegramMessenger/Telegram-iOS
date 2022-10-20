//
//  SSignalKit.h
//  SSignalKit
//
//  Created by Peter on 31/01/15.
//  Copyright (c) 2015 Telegram. All rights reserved.
//

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif

//! Project version number for SSignalKit.
FOUNDATION_EXPORT double SSignalKitVersionNumber;

//! Project version string for SSignalKit.
FOUNDATION_EXPORT const unsigned char SSignalKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SSignalKit/PublicHeader.h>

#import <SSignalKit/SAtomic.h>
#import <SSignalKit/SBag.h>
#import <SSignalKit/SSignal.h>
#import <SSignalKit/SSubscriber.h>
#import <SSignalKit/SDisposable.h>
#import <SSignalKit/SDisposableSet.h>
#import <SSignalKit/SBlockDisposable.h>
#import <SSignalKit/SMetaDisposable.h>
#import <SSignalKit/SSignal+Single.h>
#import <SSignalKit/SSignal+Mapping.h>
#import <SSignalKit/SSignal+Multicast.h>
#import <SSignalKit/SSignal+Meta.h>
#import <SSignalKit/SSignal+Accumulate.h>
#import <SSignalKit/SSignal+Dispatch.h>
#import <SSignalKit/SSignal+Catch.h>
#import <SSignalKit/SSignal+SideEffects.h>
#import <SSignalKit/SSignal+Combine.h>
#import <SSignalKit/SSignal+Timing.h>
#import <SSignalKit/SSignal+Take.h>
#import <SSignalKit/SSignal+Pipe.h>
#import <SSignalKit/SMulticastSignalManager.h>
#import <SSignalKit/STimer.h>
#import <SSignalKit/SVariable.h>
