/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTSocksProxySettings : NSObject

@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *password;

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port username:(NSString *)username password:(NSString *)password;

@end

@interface MTApiEnvironment : NSObject

@property (nonatomic) int32_t apiId;
@property (nonatomic, strong, readonly) NSString *deviceModel;
@property (nonatomic, strong, readonly) NSString *systemVersion;
@property (nonatomic, strong) NSString *appVersion;
@property (nonatomic, strong, readonly) NSString *systemLangCode;
@property (nonatomic, strong) NSNumber *layer;
    
@property (nonatomic, strong) NSString *langPack;
@property (nonatomic, strong, readonly) NSString *langPackCode;

@property (nonatomic, strong, readonly) NSString *apiInitializationHash;

@property (nonatomic) bool disableUpdates;
@property (nonatomic) NSData *tcpPayloadPrefix;
@property (nonatomic) NSDictionary *datacenterAddressOverrides;

@property (nonatomic, strong, readonly) MTSocksProxySettings *socksProxySettings;

@property (nonatomic, copy) void (^passwordInputHandler)();

- (MTApiEnvironment *)withUpdatedLangPackCode:(NSString *)langPackCode;
- (MTApiEnvironment *)withUpdatedSocksProxySettings:(MTSocksProxySettings *)socksProxySettings;

@end
