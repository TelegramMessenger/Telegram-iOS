#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import "IDUIKitBehaviorReport.h"
#import "IDUIKitCapabilityResolver.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDUIKitAutoscrollEntryCapability : NSObject

@property(nonatomic, getter=isActive, readonly) BOOL active;
@property(nonatomic, strong, readonly)
    IDUIKitCapabilityReport *report;

- (instancetype)initWithContract:
    (IDUIKitRuntimeCapabilityContract *)contract
                         resolver:
    (IDUIKitCapabilityResolver *)resolver
                        viewClass:(Class)viewClass
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
