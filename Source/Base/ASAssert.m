//
//  ASAssert.m
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASAssert.h>

#ifndef MINIMAL_ASDK
static _Thread_local int tls_mainThreadAssertionsDisabledCount;
#endif

BOOL ASMainThreadAssertionsAreDisabled() {
#ifdef MINIMAL_ASDK
  return false;
#else
  return tls_mainThreadAssertionsDisabledCount > 0;
#endif
}

void ASPushMainThreadAssertionsDisabled() {
#ifndef MINIMAL_ASDK
  tls_mainThreadAssertionsDisabledCount += 1;
#endif
}

void ASPopMainThreadAssertionsDisabled() {
#ifndef MINIMAL_ASDK
  tls_mainThreadAssertionsDisabledCount -= 1;
  ASDisplayNodeCAssert(tls_mainThreadAssertionsDisabledCount >= 0, @"Attempt to pop thread assertion-disabling without corresponding push.");
#endif
}
