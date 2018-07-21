//
//  ASAvailability.h
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <CoreFoundation/CFBase.h>

#pragma once

#ifndef kCFCoreFoundationVersionNumber_iOS_10_0
  #define kCFCoreFoundationVersionNumber_iOS_10_0 1348.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_11_0
  #define kCFCoreFoundationVersionNumber_iOS_11_0 1438.10
#endif

#ifndef __IPHONE_11_0
  #define __IPHONE_11_0 110000
#endif

#define AS_AT_LEAST_IOS10  (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_10_0)
#define AS_AT_LEAST_IOS11  (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_11_0)

// Use __builtin_available if we're on Xcode >= 9, AS_AT_LEAST otherwise.
#if __has_builtin(__builtin_available)
  #define AS_AVAILABLE_IOS(ver)               __builtin_available(iOS ver, *)
  #define AS_AVAILABLE_TVOS(ver)              __builtin_available(tvOS ver, *)
  #define AS_AVAILABLE_IOS_TVOS(ver1, ver2)   __builtin_available(iOS ver1, tvOS ver2, *)
#else
  #define AS_AVAILABLE_IOS(ver)               (TARGET_OS_IOS && AS_AT_LEAST_IOS##ver)
  #define AS_AVAILABLE_TVOS(ver)              (TARGET_OS_TV && AS_AT_LEAST_IOS##ver)
  #define AS_AVAILABLE_IOS_TVOS(ver1, ver2)   (AS_AVAILABLE_IOS(ver1) || AS_AVAILABLE_TVOS(ver2))
#endif

// If Yoga is available, make it available anywhere we use ASAvailability.
// This reduces Yoga-specific code in other files.
// NOTE: Yoga integration is experimental and not fully tested. Use with caution and test layouts carefully.
#ifndef YOGA_HEADER_PATH
  #define YOGA_HEADER_PATH <yoga/Yoga.h>
#endif

#ifndef YOGA
  #define YOGA __has_include(YOGA_HEADER_PATH)
#endif

#ifdef ASTEXTNODE_EXPERIMENT_GLOBAL_ENABLE
  #error "ASTEXTNODE_EXPERIMENT_GLOBAL_ENABLE is unavailable. See ASConfiguration.h."
#endif

#define AS_PIN_REMOTE_IMAGE __has_include(<PINRemoteImage/PINRemoteImage.h>)
#define AS_IG_LIST_KIT __has_include(<IGListKit/IGListKit.h>)

/**
 * For IGListKit versions < 3.0, you have to use IGListCollectionView.
 * For 3.0 and later, that class is removed and you use UICollectionView.
 */
#define IG_LIST_COLLECTION_VIEW __has_include(<IGListKit/IGListCollectionView.h>)
