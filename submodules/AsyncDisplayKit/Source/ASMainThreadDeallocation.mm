//
//  ASMainThreadDeallocation.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASMainThreadDeallocation.h>

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

#import <objc/runtime.h>
#import <UIKit/UIKit.h>

@implementation NSObject (ASMainThreadIvarTeardown)

- (void)scheduleIvarsForMainThreadDeallocation
{
  if (ASDisplayNodeThreadIsMain()) {
    return;
  }
  
  NSValue *ivarsObj = [[self class] _ivarsThatMayNeedMainDeallocation];
  
  // Unwrap the ivar array
  unsigned int count = 0;
  // Will be unused if assertions are disabled.
  __unused int scanResult = sscanf(ivarsObj.objCType, "[%u^{objc_ivar}]", &count);
  ASDisplayNodeAssert(scanResult == 1, @"Unexpected type in NSValue: %s", ivarsObj.objCType);
  Ivar ivars[count];
  [ivarsObj getValue:ivars];
  
  for (Ivar ivar : ivars) {
    id value = object_getIvar(self, ivar);
    if (value == nil) {
      continue;
    }
    
    if ([object_getClass(value) needsMainThreadDeallocation]) {
      // Release the ivar's reference before handing the object to the queue so we
      // don't risk holding onto it longer than the queue does.
      object_setIvar(self, ivar, nil);
      
      ASPerformMainThreadDeallocation(&value);
    } else {
    }
  }
}

/**
 * Returns an NSValue-wrapped array of all the ivars in this class or its superclasses
 * up through ASDisplayNode, that we expect may need to be deallocated on main.
 *
 * This method caches its results.
 *
 * Result is of type NSValue<[Ivar]>
 */
+ (NSValue * _Nonnull)_ivarsThatMayNeedMainDeallocation NS_RETURNS_RETAINED
{
  static NSCache<Class, NSValue *> *ivarsCache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ivarsCache = [[NSCache alloc] init];
  });
  
  NSValue *result = [ivarsCache objectForKey:self];
  if (result != nil) {
    return result;
  }
  
  // Cache miss.
  unsigned int resultCount = 0;
  static const int kMaxDealloc2MainIvarsPerClassTree = 64;
  Ivar resultIvars[kMaxDealloc2MainIvarsPerClassTree];
  
  // Get superclass results first.
  Class c = class_getSuperclass(self);
  if (c != [NSObject class]) {
    NSValue *ivarsObj = [c _ivarsThatMayNeedMainDeallocation];
    // Unwrap the ivar array and append it to our working array
    unsigned int count = 0;
    // Will be unused if assertions are disabled.
    __unused int scanResult = sscanf(ivarsObj.objCType, "[%u^{objc_ivar}]", &count);
    ASDisplayNodeAssert(scanResult == 1, @"Unexpected type in NSValue: %s", ivarsObj.objCType);
    ASDisplayNodeCAssert(resultCount + count < kMaxDealloc2MainIvarsPerClassTree, @"More than %d dealloc2main ivars are not supported. Count: %d", kMaxDealloc2MainIvarsPerClassTree, resultCount + count);
    [ivarsObj getValue:resultIvars + resultCount];
    resultCount += count;
  }
  
  // Now gather ivars from this particular class.
  unsigned int allMyIvarsCount;
  Ivar *allMyIvars = class_copyIvarList(self, &allMyIvarsCount);
  
  for (NSUInteger i = 0; i < allMyIvarsCount; i++) {
    Ivar ivar = allMyIvars[i];
    
    // NOTE: Would be great to exclude weak/unowned ivars, since we don't
    // release them. Unfortunately the objc_ivar_management access is private and
    // class_getWeakIvarLayout does not have a well-defined structure.
    
    const char *type = ivar_getTypeEncoding(ivar);
    
    if (type != NULL && strcmp(type, @encode(id)) == 0) {
      // If it's `id` we have to include it just in case.
      resultIvars[resultCount] = ivar;
      resultCount += 1;
    } else {
      // If it's an ivar with a static type, check the type.
      Class c = ASGetClassFromType(type);
      if ([c needsMainThreadDeallocation]) {
        resultIvars[resultCount] = ivar;
        resultCount += 1;
      } else {
      }
    }
  }
  free(allMyIvars);
  
  // Encode the type (array of Ivars) into a string and wrap it in an NSValue
  char arrayType[32];
  snprintf(arrayType, 32, "[%u^{objc_ivar}]", resultCount);
  result = [NSValue valueWithBytes:resultIvars objCType:arrayType];
  
  [ivarsCache setObject:result forKey:self];
  return result;
}

@end

@implementation NSObject (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  const auto name = class_getName(self);
  if (0 == strncmp(name, "AV", 2) || 0 == strncmp(name, "UI", 2) || 0 == strncmp(name, "CA", 2)) {
    return YES;
  }
  return NO;
}

@end

@implementation CALayer (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  return YES;
}

@end

@implementation UIColor (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  return NO;
}

@end

@implementation UIGestureRecognizer (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  return YES;
}

@end

@implementation UIImage (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  return NO;
}

@end

@implementation UIResponder (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  return YES;
}

@end

@implementation NSProxy (ASNeedsMainThreadDeallocation)

+ (BOOL)needsMainThreadDeallocation
{
  return NO;
}

@end
