/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTTransportScheme.h"

#import "MTTransport.h"
#import "MTDatacenterAddress.h"

#import "MTTcpTransport.h"

@interface MTTransportScheme ()
{
}

@end

@implementation MTTransportScheme

- (instancetype)initWithTransportClass:(Class)transportClass address:(MTDatacenterAddress *)address media:(bool)media
{
    self = [super init];
    if (self != nil)
    {
        _transportClass = transportClass;
        _address = address;
        _media = media;
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
        _media = [aDecoder decodeBoolForKey:@"media"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:NSStringFromClass(_transportClass) forKey:@"transportClass"];
    [aCoder encodeObject:_address forKey:@"address"];
    [aCoder encodeBool:_media forKey:@"media"];
}

- (BOOL)isEqualToScheme:(MTTransportScheme *)other
{
    if (![other isKindOfClass:[MTTransportScheme class]])
        return false;
    
    if (![other->_transportClass isEqual:_transportClass])
        return false;
    
    if (![other->_address isEqualToAddress:_address])
        return false;
    
    if (other->_media != _media)
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
    return NSOrderedSame;
}

- (MTTransport *)createTransportWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId delegate:(id<MTTransportDelegate>)delegate usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo
{
    return [(MTTransport *)[_transportClass alloc] initWithDelegate:delegate context:context datacenterId:datacenterId address:_address usageCalculationInfo:usageCalculationInfo];
}

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"%@://%@ (media: %@)", [_transportClass isEqual:[MTTcpTransport class]] ? @"tcp" : @"http", _address, _media ? @"yes" : @"no"];
}

@end
