#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, IDUIKitPrivateMemberKind) {
    IDUIKitPrivateMemberKindClassMethod,
    IDUIKitPrivateMemberKindInstanceMethod,
    IDUIKitPrivateMemberKindIvar,
    IDUIKitPrivateMemberKindIncomingCallback,
    IDUIKitPrivateMemberKindProtocol,
};

typedef NS_ENUM(NSUInteger, IDUIKitCapabilityState) {
    IDUIKitCapabilityStateUnavailable,
    IDUIKitCapabilityStateRejectedContract,
    IDUIKitCapabilityStateAvailable,
    IDUIKitCapabilityStateActive,
    IDUIKitCapabilityStateProjectOwned,
};

typedef NS_OPTIONS(NSUInteger, IDUIKitBehaviorCapabilities) {
    IDUIKitBehaviorCapabilityInputController = 1UL << 0,
    IDUIKitBehaviorCapabilityInteraction = 1UL << 1,
    IDUIKitBehaviorCapabilityFloatingCursor = 1UL << 2,
    IDUIKitBehaviorCapabilityAutoscroll = 1UL << 3,
    IDUIKitBehaviorCapabilityChecking = 1UL << 4,
    IDUIKitBehaviorCapabilityTypingAttributes = 1UL << 5,
    IDUIKitBehaviorCapabilityPrediction = 1UL << 6,
    IDUIKitBehaviorCapabilityPaste = 1UL << 7,
    IDUIKitBehaviorCapabilityDictation = 1UL << 8,
    IDUIKitBehaviorCapabilityIncomingCallbacks = 1UL << 9,
};

NS_ASSUME_NONNULL_END

#endif
