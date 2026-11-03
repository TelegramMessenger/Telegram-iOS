

#import <Foundation/Foundation.h>

#import <MtProtoKit/MTExportedAuthorizationData.h>
#import <MtProtoKit/MTDatacenterAddressListData.h>
#import <MtProtoKit/MTDatacenterVerificationData.h>

typedef MTExportedAuthorizationData *(^MTExportAuthorizationResponseParser)(NSData *);
typedef MTDatacenterAddressListData *(^MTRequestDatacenterAddressListParser)(NSData *);
typedef MTDatacenterVerificationData *(^MTDatacenterVerificationDataParser)(NSData *);
typedef id (^MTRequestNoopParser)(NSData *);

@protocol MTSerialization <NSObject>

- (NSUInteger)currentLayer;

- (id)parseMessage:(NSData *)data;

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data;
- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes;
- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data;
- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data;

@end
