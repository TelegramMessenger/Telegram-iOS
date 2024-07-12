//
//  Created by Adam Stragner
//

#import <TonProxyBridge/TPBTunnelParameters.h>

@implementation TPBTunnelParameters

- (instancetype)initWithHost:(NSString *)host port:(UInt16)port {
    self = [super init];
    if (self) {
        _host = [host copy];
        _port = port;
    }
    return self;
}

- (NSURL *)URL {
    NSString *path = [NSString stringWithFormat:@"%@:%d", self.host, self.port];
    return [[NSURL alloc] initWithString:path];
}

@end
