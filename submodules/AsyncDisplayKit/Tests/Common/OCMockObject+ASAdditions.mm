//
//  OCMockObject+ASAdditions.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "OCMockObject+ASAdditions.h"

#import <OCMock/OCMock.h>
#import <objc/runtime.h>
#import "ASTestCase.h"
#import <AsyncDisplayKit/ASAssert.h>
#import "debugbreak.h"

@interface ASTestCase (OCMockObjectRegistering)

- (void)registerMockObject:(id)mockObject;

@end

@implementation OCMockObject (ASAdditions)

+ (void)load
{
  // [OCProtocolMockObject respondsToSelector:] <-> [(self) swizzled_protocolMockRespondsToSelector:]
  Method orig = class_getInstanceMethod(OCMockObject.protocolMockObjectClass, @selector(respondsToSelector:));
  Method newMethod = class_getInstanceMethod(self, @selector(swizzled_protocolMockRespondsToSelector:));
  method_exchangeImplementations(orig, newMethod);

  // init <-> swizzled_init
  {
    Method origInit = class_getInstanceMethod([OCMockObject class], @selector(init));
    Method newInit = class_getInstanceMethod(self, @selector(swizzled_init));
    method_exchangeImplementations(origInit, newInit);
  }

  // (class mock) description <-> swizzled_classMockDescription
  {
    Method orig = class_getInstanceMethod(OCMockObject.classMockObjectClass, @selector(description));
    Method newMethod = class_getInstanceMethod(self, @selector(swizzled_classMockDescription));
    method_exchangeImplementations(orig, newMethod);
  }
}

/// Since OCProtocolMockObject is private, use this method to get the class.
+ (Class)protocolMockObjectClass
{
  static Class c;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    c = NSClassFromString(@"OCProtocolMockObject");
    NSAssert(c != Nil, nil);
  });
  return c;
}

/// Since OCClassMockObject is private, use this method to get the class.
+ (Class)classMockObjectClass
{
  static Class c;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    c = NSClassFromString(@"OCClassMockObject");
    NSAssert(c != Nil, nil);
  });
  return c;
}

/// Whether the user has opted-in to specify which optional methods are implemented for this object.
- (BOOL)hasSpecifiedOptionalProtocolMethods
{
  return objc_getAssociatedObject(self, @selector(optionalImplementedMethods)) != nil;
}

/// The optional protocol selectors the user has added via -addImplementedOptionalProtocolMethods:
- (NSMutableSet<NSString *> *)optionalImplementedMethods
{
  NSMutableSet *result = objc_getAssociatedObject(self, _cmd);
  if (result == nil) {
    result = [NSMutableSet set];
    objc_setAssociatedObject(self, _cmd, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return result;
}

- (void)addImplementedOptionalProtocolMethods:(SEL)aSelector, ...
{
  // Can't use isKindOfClass: since we're a proxy.
  NSAssert(object_getClass(self) == OCMockObject.protocolMockObjectClass, @"Cannot call this method on non-protocol mocks.");
  NSMutableSet *methods = self.optionalImplementedMethods;
  
  // First arg is not returned by va_arg, needs to be handled separately.
  if (aSelector != NULL) {
    [methods addObject:NSStringFromSelector(aSelector)];
  }
  
  va_list args;
  va_start(args, aSelector);
  SEL s;
  while((s = va_arg(args, SEL)))
  {
    [methods addObject:NSStringFromSelector(s)];
  }
  va_end(args);
}

- (BOOL)implementsOptionalProtocolMethod:(SEL)aSelector
{
  NSAssert(self.hasSpecifiedOptionalProtocolMethods, @"Shouldn't call this method if the user hasn't opted-in to specifying optional protocol methods.");
  
  // Check our collection first. It'll be in here if they explicitly marked the method as implemented.
  for (NSString *str in self.optionalImplementedMethods) {
    if (sel_isEqual(NSSelectorFromString(str), aSelector)) {
      return YES;
    }
  }
  
  // If they didn't explicitly mark it implemented, check if they stubbed/expected it. That counts too, but
  // we still want them to have the option to declare that the method exists without
  // stubbing it or making an expectation, so the rest of OCMock's mechanisms work as expected.
  return [self handleSelector:aSelector];
}

- (BOOL)swizzled_protocolMockRespondsToSelector:(SEL)aSelector
{
  // Can't use isKindOfClass: since we're a proxy.
  NSAssert(object_getClass(self) == OCMockObject.protocolMockObjectClass, @"Swizzled method should only ever be called for protocol mocks.");
  
  // If they haven't called our public method to opt-in, use the default behavior.
  if (!self.hasSpecifiedOptionalProtocolMethods) {
    return [self swizzled_protocolMockRespondsToSelector:aSelector];
  }
  
  Ivar i = class_getInstanceVariable([self class], "mockedProtocol");
  NSAssert(i != NULL, nil);
  Protocol *mockedProtocol = object_getIvar(self, i);
  NSAssert(mockedProtocol != NULL, nil);
  
  // Check if it's an optional protocol method. If not, just return the default implementation (which has now swapped).
  struct objc_method_description methodDescription;
  methodDescription = protocol_getMethodDescription(mockedProtocol, aSelector, NO, YES);
  if (methodDescription.name == NULL) {
    methodDescription = protocol_getMethodDescription(mockedProtocol, aSelector, NO, NO);
    if (methodDescription.name == NULL) {
      return [self swizzled_protocolMockRespondsToSelector:aSelector];
    }
  }
  
  // It's an optional instance or class method. Override the return value.
  return [self implementsOptionalProtocolMethod:aSelector];
}

// Whenever a mock object is initted, register it with the current test case
// so that it gets verified and its invocations are cleared during -tearDown.
- (instancetype)swizzled_init
{
  [self swizzled_init];
  [ASTestCase.currentTestCase registerMockObject:self];
  return self;
}

- (NSString *)swizzled_classMockDescription
{
  NSString *orig = [self swizzled_classMockDescription];
  __auto_type block = self.modifyDescriptionBlock;
  if (block) {
    return block(self, orig);
  }
  return orig;
}

- (void)setModifyDescriptionBlock:(NSString *(^)(OCMockObject *, NSString *))modifyDescriptionBlock
{
  objc_setAssociatedObject(self, @selector(modifyDescriptionBlock), modifyDescriptionBlock, OBJC_ASSOCIATION_COPY);
}

- (NSString *(^)(OCMockObject *, NSString *))modifyDescriptionBlock
{
  return objc_getAssociatedObject(self, _cmd);
}

@end

@implementation OCMStubRecorder (ASProperties)

@dynamic _ignoringNonObjectArgs;

- (OCMStubRecorder *(^)(void))_ignoringNonObjectArgs
{
  id (^theBlock)(void) = ^ ()
  {
    return [self ignoringNonObjectArgs];
  };
  return theBlock;
}

@dynamic _onMainThread;

- (OCMStubRecorder *(^)(void))_onMainThread
{
  id (^theBlock)(void) = ^ ()
  {
    return [self andDo:^(NSInvocation *invocation) {
      ASDisplayNodeAssertMainThread();
    }];
  };
  return theBlock;
}

@dynamic _offMainThread;

- (OCMStubRecorder *(^)(void))_offMainThread
{
  id (^theBlock)(void) = ^ ()
  {
    return [self andDo:^(NSInvocation *invocation) {
      ASDisplayNodeAssertNotMainThread();
    }];
  };
  return theBlock;
}

@dynamic _andDebugBreak;

- (OCMStubRecorder *(^)(void))_andDebugBreak
{
  id (^theBlock)(void) = ^ ()
  {
    return [self andDo:^(NSInvocation *invocation) {
      debug_break();
    }];
  };
  return theBlock;
}
@end
