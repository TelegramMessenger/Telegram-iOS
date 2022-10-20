#import <MtProtoKit/MTTransportScheme.h>

#import <MtProtoKit/MTTransport.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTTcpTransport.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>

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

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTTransportScheme class]]) {
        return false;
    }
    return [self isEqualToScheme:(MTTransportScheme *)object];
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

- (NSString *)description
{
    return [[NSString alloc] initWithFormat:@"%@://%@ (media: %@)", [_transportClass isEqual:[MTTcpTransport class]] ? @"tcp" : @"http", _address, _media ? @"yes" : @"no"];
}

@end
