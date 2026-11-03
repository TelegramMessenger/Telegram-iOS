#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "IDUIKitBehaviorReport.h"
#import "IDUIKitAutoscrollEntryCapability.h"
#import "IDUIKitCapabilityResolver.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDUIKitInteractionCapability.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const IDUIKitBehaviorKernelErrorDomain;
FOUNDATION_EXPORT IDUIKitRuntimeManifest *
    IDUIKitBehaviorRuntimeManifest(void);

typedef NS_ENUM(NSUInteger, IDUIKitBehaviorKernelLifecycle) {
    IDUIKitBehaviorKernelLifecycleConstructing,
    IDUIKitBehaviorKernelLifecycleActive,
    IDUIKitBehaviorKernelLifecycleDetached,
};

@interface IDUIKitBehaviorKernel : NSObject

@property(nonatomic, readonly) IDUIKitBehaviorKernelLifecycle lifecycle;
@property(nonatomic, strong, readonly)
    IDUIKitInputControllerCapability *inputController;
@property(nonatomic, strong, readonly, nullable)
    IDUIKitInteractionCapability *interaction;
@property(nonatomic, strong, readonly, nullable)
    IDUIKitAutoscrollEntryCapability *autoscrollEntry;
@property(nonatomic, strong, readonly) IDUIKitBehaviorReport *report;

- (nullable instancetype)initWithManifest:
    (IDUIKitRuntimeManifest *)manifest
                                 resolver:(IDUIKitCapabilityResolver *)resolver
                         layoutController:(id)layoutController
                                 delegate:(id)delegate
                                     view:(UIView *)view
                    requestedCapabilities:
    (IDUIKitBehaviorCapabilities)requested
                                    error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
- (void)detach;

@end

NS_ASSUME_NONNULL_END

#endif
