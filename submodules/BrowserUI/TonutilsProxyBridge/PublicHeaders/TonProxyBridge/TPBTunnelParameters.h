//
//  Created by Adam Stragner
//

#import <TonProxyBridge/TPB.h>

NS_ASSUME_NONNULL_BEGIN

@interface TPBTunnelParameters : NSObject

@property (nonatomic, readonly, copy) NSString *host;
@property (nonatomic, readonly, assign) UInt16 port;

- (instancetype)initWithHost:(NSString *)host port:(UInt16)port;
- (NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
