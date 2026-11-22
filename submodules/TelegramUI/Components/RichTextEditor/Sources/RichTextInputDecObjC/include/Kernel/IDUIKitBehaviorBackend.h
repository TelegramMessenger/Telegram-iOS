#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, IDUIKitBehaviorBackend) {
    IDUIKitBehaviorBackendReference,
    IDUIKitBehaviorBackendMinimalKernel,
};

#endif
