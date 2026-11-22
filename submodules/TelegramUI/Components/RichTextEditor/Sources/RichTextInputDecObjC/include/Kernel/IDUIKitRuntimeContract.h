#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

#import "IDUIKitBehaviorCapabilities.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const IDUIKitRuntimeContractErrorDomain;

FOUNDATION_EXPORT BOOL IDUIKitRuntimeTypeEncodingMatches(
    const char *actual,
    NSString *expected);

@interface IDUIKitRuntimeMemberContract : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *className;
@property(nonatomic, readonly) IDUIKitPrivateMemberKind kind;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *returnType;
@property(nonatomic, copy, readonly) NSArray<NSString *> *argumentTypes;
@property(nonatomic, getter=isRequired, readonly) BOOL required;
@property(nonatomic, copy, readonly) NSString *direction;
@property(nonatomic, copy, readonly) NSString *source;
@property(nonatomic, copy, readonly) NSString *evidence;
@property(nonatomic, copy, readonly) NSString *fallback;
@property(nonatomic, copy, readonly) NSString *teardown;

@end

@interface IDUIKitRuntimeCapabilityContract : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, readonly) IDUIKitBehaviorCapabilities capability;
@property(nonatomic, getter=isMandatory, readonly) BOOL mandatory;
@property(nonatomic, copy, readonly)
    NSArray<IDUIKitRuntimeMemberContract *> *members;
@property(nonatomic, copy, readonly) NSArray<NSString *> *dependencies;
@property(nonatomic, copy, readonly) NSString *fallback;

@end

@interface IDUIKitRuntimeManifest : NSObject

@property(nonatomic, readonly) NSInteger schemaVersion;
@property(nonatomic, copy, readonly) NSString *osVersion;
@property(nonatomic, copy, readonly) NSString *osBuild;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, IDUIKitRuntimeCapabilityContract *> *capabilities;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, IDUIKitRuntimeCapabilityContract *> *referenceOnly;
@property(nonatomic, copy, readonly) NSArray<NSString *> *forbiddenSymbols;

+ (nullable instancetype)manifestWithData:(NSData *)data
                                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END

#endif
