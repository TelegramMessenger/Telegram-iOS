#import <Foundation/Foundation.h>

#import <MtProtoKit/MTDatacenterAuthInfo.h>


@class MTContext;

@interface MTDatacenterAuthAction : NSObject

- (instancetype)initWithAuthKeyInfoSelector:(MTDatacenterAuthInfoSelector)authKeyInfoSelector isCdn:(bool)isCdn skipBind:(bool)skipBind completion:(void (^)(MTDatacenterAuthAction *, bool))completion;

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId;
- (void)cancel;

@end
