#import <MtProtoKit/MTDatacenterAddress.h>

#import <netinet/in.h>
#import <arpa/inet.h>

@implementation MTDatacenterAddress

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port preferForMedia:(bool)preferForMedia restrictToTcp:(bool)restrictToTcp cdn:(bool)cdn preferForProxy:(bool)preferForProxy secret:(NSData *)secret
{
    self = [super init];
    if (self != nil)
    {
        _ip = ip;
        _port = port;
        _preferForMedia = preferForMedia;
        _restrictToTcp = restrictToTcp;
        _cdn = cdn;
        _preferForProxy = preferForProxy;
        _secret = secret;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _ip = [aDecoder decodeObjectForKey:@"ip"];
        _host = [aDecoder decodeObjectForKey:@"host"];
        _port = (uint16_t)[aDecoder decodeIntForKey:@"port"];
        _preferForMedia = [aDecoder decodeBoolForKey:@"preferForMedia"];
        _restrictToTcp = [aDecoder decodeBoolForKey:@"restrictToTcp"];
        _cdn = [aDecoder decodeBoolForKey:@"cdn"];
        _preferForProxy = [aDecoder decodeBoolForKey:@"preferForProxy"];
        _secret = [aDecoder decodeObjectForKey:@"secret"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_ip forKey:@"ip"];
    [aCoder encodeObject:_host forKey:@"host"];
    [aCoder encodeInt:_port forKey:@"port"];
    [aCoder encodeBool:_preferForMedia forKey:@"preferForMedia"];
    [aCoder encodeBool:_restrictToTcp forKey:@"restrictToTcp"];
    [aCoder encodeBool:_cdn forKey:@"cdn"];
    [aCoder encodeBool:_preferForProxy forKey:@"preferForProxy"];
    [aCoder encodeObject:_secret forKey:@"secret"];
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[MTDatacenterAddress class]])
        return false;
    
    return [self isEqualToAddress:object];
}

- (NSUInteger)hash {
    return [_ip hash] * 31 + ((NSUInteger)_port);
}

- (BOOL)isEqualToAddress:(MTDatacenterAddress *)other
{
    if (![other isKindOfClass:[MTDatacenterAddress class]])
        return false;
    
    if (![_ip isEqualToString:other.ip])
        return false;
    
    if (_port != other.port)
        return false;
    
    if (_preferForMedia != other.preferForMedia)
        return false;
    
    if (_restrictToTcp != other.restrictToTcp) {
        return false;
    }
    
    if (_cdn != other.cdn) {
        return false;
    }
    
    if (_preferForProxy != other.preferForProxy) {
        return false;
    }
    
    if ((_secret != nil) && (other->_secret != nil)) {
        if (![_secret isEqualToData:other->_secret]) {
            return false;
        }
    } else if ((_secret != nil) != (other->_secret != nil)) {
        return false;
    }
    
    return true;
}

- (BOOL)isIpv6
{
    const char *utf8 = [_ip UTF8String];
    int success;
    
    struct in6_addr dst6;
    success = inet_pton(AF_INET6, utf8, &dst6);
    
    return success == 1;
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"%@:%d (media: %@, cdn: %@, static: %@, secret: %@)", _ip == nil ? _host : _ip, (int)_port, _preferForMedia ? @"yes" : @"no", _cdn ? @"yes" : @"no", _preferForProxy ? @"yes" : @"no", _secret];
}

@end
