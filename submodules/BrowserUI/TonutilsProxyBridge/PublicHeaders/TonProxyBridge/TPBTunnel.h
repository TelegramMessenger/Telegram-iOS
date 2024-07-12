//
//  Created by Adam Stragner
//

#import <TonProxyBridge/TPB.h>

@class TPBTunnelParameters;

NS_ASSUME_NONNULL_BEGIN

TPB_EXPORT NSErrorDomain const TPBErrorDomain;

@interface TPBTunnel : NSObject

@property (nonatomic, readonly, retain) TPBTunnelParameters * _Nullable parameters;

+ (instancetype)sharedTunnel;
- (instancetype)init NS_UNAVAILABLE;

- (void)startWithPort:(UInt16)port completionBlock:(void (^ _Nullable)(TPBTunnelParameters * _Nullable parameters, NSError * _Nullable error))completionBlock;
- (void)stopWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock;

- (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END
