#import "MTTransportSchemeStats.h"

#import <MtProtoKit/MTDatacenterAddress.h>

@implementation MTTransportSchemeStats

- (instancetype)initWithLastFailureTimestamp:(int32_t)lastFailureTimestamp lastResponseTimestamp:(int32_t)lastResponseTimestamp {
    self = [super init];
    if (self != nil) {
        _lastFailureTimestamp = lastFailureTimestamp;
        _lastResponseTimestamp = lastResponseTimestamp;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithLastFailureTimestamp:[aDecoder decodeInt32ForKey:@"lastFailureTimestamp"] lastResponseTimestamp:[aDecoder decodeInt32ForKey:@"lastResponseTimestamp"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_lastFailureTimestamp forKey:@"lastFailureTimestamp"];
    [aCoder encodeInt32:_lastResponseTimestamp forKey:@"lastResponseTimestamp"];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTTransportSchemeStats class]]) {
        return false;
    }
    MTTransportSchemeStats *other = object;
    if (_lastFailureTimestamp != other->_lastFailureTimestamp) {
        return false;
    }
    if (_lastResponseTimestamp != other->_lastResponseTimestamp) {
        return false;
    }
    return true;
}

- (instancetype)withUpdatedLastFailureTimestamp:(int32_t)lastFailureTimestamp {
    return [[MTTransportSchemeStats alloc] initWithLastFailureTimestamp:lastFailureTimestamp lastResponseTimestamp:_lastResponseTimestamp];
}

- (instancetype)withUpdatedLastResponseTimestamp:(int32_t)lastResponseTimestamp {
    return [[MTTransportSchemeStats alloc] initWithLastFailureTimestamp:_lastFailureTimestamp lastResponseTimestamp:lastResponseTimestamp];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"lastFailureTimestamp: %d, lastResponseTimestamp:%d", _lastFailureTimestamp, _lastResponseTimestamp];
}

+ (NSString *)formatStats:(NSMutableDictionary<NSNumber *, NSMutableDictionary<MTDatacenterAddress *, MTTransportSchemeStats *> *> *)stats {
    NSMutableString *result = [[NSMutableString alloc] init];
    [stats enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, NSMutableDictionary<MTDatacenterAddress *, MTTransportSchemeStats *> *values, __unused BOOL *stop) {
        [result appendFormat:@"DC%@:\n", nDatacenterId];
        [values enumerateKeysAndObjectsUsingBlock:^(MTDatacenterAddress *key, MTTransportSchemeStats *obj, __unused BOOL * stop) {
            [result appendFormat:@"    %@:%@\n", key, obj];
        }];
    }];
    return result;
}

@end
