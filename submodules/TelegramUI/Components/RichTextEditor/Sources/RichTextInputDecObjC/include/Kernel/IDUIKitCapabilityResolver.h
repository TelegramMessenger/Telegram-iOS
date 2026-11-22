#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import <objc/runtime.h>

#import "IDUIKitRuntimeContract.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDUIKitContractResult : NSObject

@property(nonatomic, getter=isAccepted, readonly) BOOL accepted;
@property(nonatomic, readonly) IDUIKitCapabilityState state;
@property(nonatomic, copy, readonly) NSString *contractIdentifier;
@property(nonatomic, copy, readonly) NSArray<NSString *> *mismatches;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, NSString *> *observedABIs;

@end

@protocol IDUIKitRuntimeLookingUp <NSObject>

- (nullable Class)classNamed:(NSString *)name;
- (nullable Protocol *)protocolNamed:(NSString *)name;
- (nullable Method)instanceMethodForClass:(Class)cls
                                 selector:(SEL)selector;
- (nullable Method)classMethodForClass:(Class)cls
                              selector:(SEL)selector;
- (nullable Ivar)instanceVariableForClass:(Class)cls
                                     name:(NSString *)name;

@end

@interface IDUIKitCapabilityResolver : NSObject

+ (instancetype)systemResolver;

- (instancetype)initWithLookup:(id<IDUIKitRuntimeLookingUp>)lookup
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (nullable Class)classNamed:(NSString *)name;
- (nullable Protocol *)protocolNamed:(NSString *)name;
- (IDUIKitContractResult *)evaluateContract:
    (IDUIKitRuntimeCapabilityContract *)contract;

@end

NS_ASSUME_NONNULL_END

#endif
