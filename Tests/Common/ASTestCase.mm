//
//  ASTestCase.mm
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASTestCase.h"
#import <objc/runtime.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <OCMock/OCMock.h>
#import "OCMockObject+ASAdditions.h"

static __weak ASTestCase *currentTestCase;

@implementation ASTestCase {
  ASWeakSet *registeredMockObjects;
}

- (void)setUp
{
  [super setUp];
  currentTestCase = self;
  registeredMockObjects = [ASWeakSet new];
}

- (void)tearDown
{
  [ASConfigurationManager test_resetWithConfiguration:nil];
  
  // Clear out all application windows. Note: the system will retain these sometimes on its
  // own but we'll do our best.
  for (UIWindow *window in [UIApplication sharedApplication].windows) {
    [window resignKeyWindow];
    window.hidden = YES;
    window.rootViewController = nil;
    for (UIView *view in window.subviews) {
      [view removeFromSuperview];
    }
  }
  
  // Set nil for all our subclasses' ivars. Use setValue:forKey: so memory is managed correctly.
  // This is important to do _inside_ the test-perform, so that we catch any issues caused by the
  // deallocation, and so that we're inside the @autoreleasepool for the test invocation.
  Class c = [self class];
  while (c != [ASTestCase class]) {
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(c, &ivarCount);
    for (unsigned int i = 0; i < ivarCount; i++) {
      Ivar ivar = ivars[i];
      NSString *key = [NSString stringWithCString:ivar_getName(ivar) encoding:NSUTF8StringEncoding];
      if (OCMIsObjectType(ivar_getTypeEncoding(ivar))) {
      	[self setValue:nil forKey:key];
      }
    }
    if (ivars) {
      free(ivars);
    }

    c = [c superclass];
  }

  for (OCMockObject *mockObject in registeredMockObjects) {
    OCMVerifyAll(mockObject);
    [mockObject stopMocking];

    // Invocations retain arguments, which may cause retain cycles.
    // Manually clear them all out.
    NSMutableArray *invocations = object_getIvar(mockObject, class_getInstanceVariable(OCMockObject.class, "invocations"));
    [invocations removeAllObjects];
  }

  // Go ahead and spin the run loop before finishing, so the system
  // unregisters/cleans up whatever possible.
  [NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:NSDate.distantPast];
  
  [super tearDown];
}

- (void)invokeTest
{
  // This will call setup, run, then teardown.
  @autoreleasepool {
    [super invokeTest];
  }

  // Now that the autorelease pool is drained, drain the dealloc queue also.
  [[ASDeallocQueue sharedDeallocationQueue] drain];
}

+ (ASTestCase *)currentTestCase
{
  return currentTestCase;
}

@end

@implementation ASTestCase (OCMockObjectRegistering)

- (void)registerMockObject:(id)mockObject
{
  @synchronized (registeredMockObjects) {
    [registeredMockObjects addObject:mockObject];
  }
}

@end
