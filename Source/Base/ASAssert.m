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
#import <Foundation/Foundation.h>

static pthread_key_t ASMainThreadAssertionsDisabledKey()
{
  return ASPthreadStaticKey(NULL);
}

BOOL ASMainThreadAssertionsAreDisabled() {
  return (size_t)pthread_getspecific(ASMainThreadAssertionsDisabledKey()) > 0;
}

void ASPushMainThreadAssertionsDisabled() {
  pthread_key_t key = ASMainThreadAssertionsDisabledKey();
  size_t oldValue = (size_t)pthread_getspecific(key);
  pthread_setspecific(key, (void *)(oldValue + 1));
}

void ASPopMainThreadAssertionsDisabled() {
  pthread_key_t key = ASMainThreadAssertionsDisabledKey();
  size_t oldValue = (size_t)pthread_getspecific(key);
  if (oldValue > 0) {
    pthread_setspecific(key, (void *)(oldValue - 1));
  } else {
    ASDisplayNodeCFailAssert(@"Attempt to pop thread assertion-disabling without corresponding push.");
  }
}
