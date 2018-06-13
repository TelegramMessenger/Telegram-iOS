

#import <Foundation/Foundation.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTExportedAuthorizationData.h>
#   import <MTProtoKitDynamic/MTDatacenterAddressListData.h>
#   import <MTProtoKitDynamic/MTDatacenterVerificationData.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTExportedAuthorizationData.h>
#   import <MTProtoKitMac/MTDatacenterAddressListData.h>
#   import <MTProtoKitMac/MTDatacenterVerificationData.h>
#else
#   import <MTProtoKit/MTExportedAuthorizationData.h>
#   import <MTProtoKit/MTDatacenterAddressListData.h>
#   import <MTProtoKit/MTDatacenterVerificationData.h>
#endif

typedef MTExportedAuthorizationData *(^MTExportAuthorizationResponseParser)(NSData *);
typedef MTDatacenterAddressListData *(^MTRequestDatacenterAddressListParser)(NSData *);
typedef MTDatacenterVerificationData *(^MTDatacenterVerificationDataParser)(NSData *);
typedef id (^MTRequestNoopParser)(NSData *);

@protocol MTSerialization <NSObject>

- (NSUInteger)currentLayer;

- (id)parseMessage:(NSData *)data;

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data;
- (NSData *)importAuthorization:(int32_t)authId bytes:(NSData *)bytes;
- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data;
- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data;

@end
