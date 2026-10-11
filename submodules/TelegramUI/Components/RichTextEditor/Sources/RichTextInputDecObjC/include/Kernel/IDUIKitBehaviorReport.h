#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import "IDUIKitBehaviorCapabilities.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDUIKitCapabilityReport : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, readonly) IDUIKitCapabilityState state;
@property(nonatomic, copy, readonly) NSArray<NSString *> *requiredMembers;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, NSString *> *observedABIs;
@property(nonatomic, copy, readonly) NSArray<NSString *> *dependencies;
@property(nonatomic, copy, readonly) NSString *fallback;
@property(nonatomic, copy, readonly, nullable) NSString *rejectionReason;

- (instancetype)initWithIdentifier:(NSString *)identifier
                             state:(IDUIKitCapabilityState)state
                   requiredMembers:(NSArray<NSString *> *)requiredMembers
                      observedABIs:
    (NSDictionary<NSString *, NSString *> *)observedABIs
                      dependencies:(NSArray<NSString *> *)dependencies
                          fallback:(NSString *)fallback
                   rejectionReason:
    (nullable NSString *)rejectionReason NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (IDUIKitCapabilityReport *)reportByActivating;
- (NSDictionary<NSString *, id> *)normalizedDictionary;

@end

@interface IDUIKitBehaviorReport : NSObject

@property(nonatomic, copy, readonly) NSString *osVersion;
@property(nonatomic, copy, readonly) NSString *osBuild;
@property(nonatomic, copy, readonly)
    NSArray<IDUIKitCapabilityReport *> *capabilities;
@property(nonatomic, getter=isDetached, readonly) BOOL detached;

- (instancetype)initWithOSVersion:(NSString *)osVersion
                          osBuild:(NSString *)osBuild
                      capabilities:
    (NSArray<IDUIKitCapabilityReport *> *)capabilities
                          detached:(BOOL)detached NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (IDUIKitBehaviorReport *)reportByMarkingDetached;
- (NSDictionary<NSString *, id> *)normalizedDictionary;

@end

NS_ASSUME_NONNULL_END

#endif
