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

static _Thread_local int tls_mainThreadAssertionsDisabledCount;

BOOL ASMainThreadAssertionsAreDisabled() {
  return tls_mainThreadAssertionsDisabledCount > 0;
}

void ASPushMainThreadAssertionsDisabled() {
  tls_mainThreadAssertionsDisabledCount += 1;
}

void ASPopMainThreadAssertionsDisabled() {
  tls_mainThreadAssertionsDisabledCount -= 1;
  ASDisplayNodeCAssert(tls_mainThreadAssertionsDisabledCount >= 0, @"Attempt to pop thread assertion-disabling without corresponding push.");
}
