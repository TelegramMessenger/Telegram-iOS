/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTransportScheme.h>

#import <MtProtoKit/MTTransport.h>
#import <MtProtoKit/MTDatacenterAddress.h>

#import <MTProtoKit/MTTcpTransport.h>

@interface MTTransportScheme ()
{
}

@end

@implementation MTTransportScheme

- (instancetype)initWithTransportClass:(Class)transportClass address:(MTDatacenterAddress *)address
{
    self = [super init];
    if (self != nil)
    {
        _transportClass = transportClass;
        _address = address;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _transportClass = NSClassFromString([aDecoder decodeObjectForKey:@"transportClass"]);
        _address = [aDecoder decodeObjectForKey:@"address"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:NSStringFromClass(_transportClass) forKey:@"transportClass"];
    [aCoder encodeObject:_address forKey:@"address"];
}

- (BOOL)isEqualToScheme:(MTTransportScheme *)other
{
    if (![other isKindOfClass:[MTTransportScheme class]])
        return false;
    
    if (![other->_transportClass isEqual:_transportClass])
        return false;
    
    if (![other->_address isEqualToAddress:_address])
        return false;
    
    return true;
}

- (BOOL)isOptimal
{
    return [_transportClass isEqual:[MTTcpTransport class]];
}

- (NSComparisonResult)compareToScheme:(MTTransportScheme *)other
{
    if (other == nil)
        return NSOrderedAscending;
    
    bool selfIsTcp = [_transportClass isEqual:[MTTcpTransport class]];
    bool otherIsTcp = [other->_transportClass isEqual:[MTTcpTransport class]];
    
    if (selfIsTcp != otherIsTcp)
        return selfIsTcp ? NSOrderedAscending : NSOrderedDescending;
    
    /*if (_address.port != other.address.port)
    {
        int bestPort = selfIsTcp ? 443 : 80;
        
        if (_address.port == bestPort && other->_address.port != bestPort)
            return NSOrderedAscending;
        else if (_address.port != bestPort && other->_address.port == bestPort)
            return NSOrderedDescending;
    }*/
    
    return NSOrderedSame;
}

- (MTTransport *)createTransportWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId delegate:(id<MTTransportDelegate>)delegate
{
    return [(MTTransport *)[_transportClass alloc] initWithDelegate:delegate context:context datacenterId:datacenterId address:_address];
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"%@://%@", [_transportClass isEqual:[MTTcpTransport class]] ? @"tcp" : @"http", _address];
}

@end
