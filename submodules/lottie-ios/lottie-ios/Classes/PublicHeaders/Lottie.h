//
//  Lottie.h
//  Pods
//
//  Created by brandon_withrow on 1/27/17.
//
//  Dream Big.

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

#ifndef Lottie_h
#define Lottie_h

//! Project version number for Lottie.
FOUNDATION_EXPORT double LottieVersionNumber;

//! Project version string for Lottie.
FOUNDATION_EXPORT const unsigned char LottieVersionString[];

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <Lottie/LOTAnimationTransitionController.h>
#import <Lottie/LOTAnimatedSwitch.h>
#import <Lottie/LOTAnimatedControl.h>
#endif

#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
#import <Lottie/LOTCacheProvider.h>
#endif

#import <Lottie/LOTAnimationView.h>
#import <Lottie/LOTAnimationLayerContainer.h>
#import <Lottie/LOTAnimationCache.h>
#import <Lottie/LOTComposition.h>
#import <Lottie/LOTBlockCallback.h>
#import <Lottie/LOTInterpolatorCallback.h>
#import <Lottie/LOTValueCallback.h>
#import <Lottie/LOTValueDelegate.h>

#endif /* Lottie_h */
