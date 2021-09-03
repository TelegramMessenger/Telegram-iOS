#import "Serialization.h"

@implementation Serialization

- (NSUInteger)currentLayer {
    return 133;
}

- (id _Nullable)parseMessage:(NSData * _Nullable)data {
    return nil;
}

- (MTExportAuthorizationResponseParser _Nonnull)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data {
    return ^MTExportedAuthorizationData *(NSData *resultData) {
        return nil;
    };
}

- (NSData * _Nonnull)importAuthorization:(int64_t)authId bytes:(NSData * _Nonnull)bytes {
    return [NSData data];
}

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data {
    return ^MTDatacenterAddressListData *(NSData *resultData) {
        return nil;
    };
}

- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data {
    return ^id(NSData *resultData) {
        return nil;
    };
}

@end
