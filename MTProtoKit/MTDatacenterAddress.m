/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTDatacenterAddress.h>

#import <netinet/in.h>
#import <arpa/inet.h>

@implementation MTDatacenterAddress

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port preferForMedia:(bool)preferForMedia
{
    self = [super init];
    if (self != nil)
    {
        _ip = ip;
        _port = port;
        _preferForMedia = preferForMedia;
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
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_ip forKey:@"ip"];
    [aCoder encodeObject:_host forKey:@"host"];
    [aCoder encodeInt:_port forKey:@"port"];
    [aCoder encodeBool:_preferForMedia forKey:@"preferForMedia"];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[MTDatacenterAddress class]])
        return false;
    
    return [self isEqualToAddress:object];
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
    return [[NSString alloc] initWithFormat:@"%@:%d (media: %@)", _ip == nil ? _host : _ip, (int)_port, _preferForMedia ? @"yes" : @"no"];
}

@end
