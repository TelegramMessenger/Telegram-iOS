/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

#import <MTProtoKit/MTExportedAuthorizationData.h>
#import <MTProtoKit/MTDatacenterAddressListData.h>

typedef MTExportedAuthorizationData *(^MTExportAuthorizationResponseParser)(NSData *);
typedef MTDatacenterAddressListData *(^MTRequestDatacenterAddressListParser)(NSData *);

@protocol MTSerialization <NSObject>

- (NSUInteger)currentLayer;

- (id)parseMessage:(NSData *)data;

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data;
- (NSData *)importAuthorization:(int32_t)authId bytes:(NSData *)bytes;

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressList:(int32_t)datacenterId data:(__autoreleasing NSData **)data;

@end
