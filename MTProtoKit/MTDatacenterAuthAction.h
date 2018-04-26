#import <Foundation/Foundation.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTDatacenterAuthInfo.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTDatacenterAuthInfo.h>
#else
#   import <MTProtoKit/MTDatacenterAuthInfo.h>
#endif

@class MTContext;
@class MTDatacenterAuthAction;

@protocol MTDatacenterAuthActionDelegate <NSObject>

- (void)datacenterAuthActionCompleted:(MTDatacenterAuthAction *)action;

@end

@interface MTDatacenterAuthAction : NSObject

@property (nonatomic, readonly) bool tempAuth;
@property (nonatomic, weak) id<MTDatacenterAuthActionDelegate> delegate;

- (instancetype)initWithTempAuth:(bool)tempAuth tempAuthKeyType:(MTDatacenterAuthTempKeyType)tempAuthKeyType;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId isCdn:(bool)isCdn;
- (void)cancel;

@end
