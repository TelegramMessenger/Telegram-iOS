//
//  ASTextDebugOption.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTextDebugOption.h"
#import <pthread.h>

static pthread_mutex_t _sharedDebugLock;
static CFMutableSetRef _sharedDebugTargets = nil;
static ASTextDebugOption *_sharedDebugOption = nil;

static const void* _as_sharedDebugSetRetain(CFAllocatorRef allocator, const void *value) {
  return value;
}

static void _as_sharedDebugSetRelease(CFAllocatorRef allocator, const void *value) {
}

void _as_sharedDebugSetFunction(const void *value, void *context) {
  id<ASTextDebugTarget> target = (__bridge id<ASTextDebugTarget>)(value);
  [target setDebugOption:_sharedDebugOption];
}

static void _initSharedDebug() {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    pthread_mutex_init(&_sharedDebugLock, NULL);
    CFSetCallBacks callbacks = kCFTypeSetCallBacks;
    callbacks.retain = _as_sharedDebugSetRetain;
    callbacks.release = _as_sharedDebugSetRelease;
    _sharedDebugTargets = CFSetCreateMutable(CFAllocatorGetDefault(), 0, &callbacks);
  });
}

static void _setSharedDebugOption(ASTextDebugOption *option) {
  _initSharedDebug();
  pthread_mutex_lock(&_sharedDebugLock);
  _sharedDebugOption = option.copy;
  CFSetApplyFunction(_sharedDebugTargets, _as_sharedDebugSetFunction, NULL);
  pthread_mutex_unlock(&_sharedDebugLock);
}

static ASTextDebugOption *_getSharedDebugOption() {
  _initSharedDebug();
  pthread_mutex_lock(&_sharedDebugLock);
  ASTextDebugOption *op = _sharedDebugOption;
  pthread_mutex_unlock(&_sharedDebugLock);
  return op;
}

static void _addDebugTarget(id<ASTextDebugTarget> target) {
  _initSharedDebug();
  pthread_mutex_lock(&_sharedDebugLock);
  CFSetAddValue(_sharedDebugTargets, (__bridge const void *)(target));
  pthread_mutex_unlock(&_sharedDebugLock);
}

static void _removeDebugTarget(id<ASTextDebugTarget> target) {
  _initSharedDebug();
  pthread_mutex_lock(&_sharedDebugLock);
  CFSetRemoveValue(_sharedDebugTargets, (__bridge const void *)(target));
  pthread_mutex_unlock(&_sharedDebugLock);
}


@implementation ASTextDebugOption

- (id)copyWithZone:(NSZone *)zone {
  ASTextDebugOption *op = [self.class new];
  op.baselineColor = self.baselineColor;
  op.CTFrameBorderColor = self.CTFrameBorderColor;
  op.CTFrameFillColor = self.CTFrameFillColor;
  op.CTLineBorderColor = self.CTLineBorderColor;
  op.CTLineFillColor = self.CTLineFillColor;
  op.CTLineNumberColor = self.CTLineNumberColor;
  op.CTRunBorderColor = self.CTRunBorderColor;
  op.CTRunFillColor = self.CTRunFillColor;
  op.CTRunNumberColor = self.CTRunNumberColor;
  op.CGGlyphBorderColor = self.CGGlyphBorderColor;
  op.CGGlyphFillColor = self.CGGlyphFillColor;
  return op;
}

- (BOOL)needDrawDebug {
  if (self.baselineColor ||
      self.CTFrameBorderColor ||
      self.CTFrameFillColor ||
      self.CTLineBorderColor ||
      self.CTLineFillColor ||
      self.CTLineNumberColor ||
      self.CTRunBorderColor ||
      self.CTRunFillColor ||
      self.CTRunNumberColor ||
      self.CGGlyphBorderColor ||
      self.CGGlyphFillColor) return YES;
  return NO;
}

- (void)clear {
  self.baselineColor = nil;
  self.CTFrameBorderColor = nil;
  self.CTFrameFillColor = nil;
  self.CTLineBorderColor = nil;
  self.CTLineFillColor = nil;
  self.CTLineNumberColor = nil;
  self.CTRunBorderColor = nil;
  self.CTRunFillColor = nil;
  self.CTRunNumberColor = nil;
  self.CGGlyphBorderColor = nil;
  self.CGGlyphFillColor = nil;
}

+ (void)addDebugTarget:(id<ASTextDebugTarget>)target {
  if (target) _addDebugTarget(target);
}

+ (void)removeDebugTarget:(id<ASTextDebugTarget>)target {
  if (target) _removeDebugTarget(target);
}

+ (ASTextDebugOption *)sharedDebugOption {
  return _getSharedDebugOption();
}

+ (void)setSharedDebugOption:(ASTextDebugOption *)option {
  NSAssert([NSThread isMainThread], @"This method must be called on the main thread");
  _setSharedDebugOption(option);
}

@end

