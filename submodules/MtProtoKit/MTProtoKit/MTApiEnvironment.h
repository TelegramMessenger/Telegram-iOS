#import <Foundation/Foundation.h>

@interface MTProxySecret : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData * _Nonnull secret;

+ (MTProxySecret * _Nullable)parse:(NSString * _Nonnull)string;
+ (MTProxySecret * _Nullable)parseData:(NSData * _Nonnull)data;
- (NSData * _Nonnull)serialize;
- (NSString * _Nonnull)serializeToString;

@end

@interface MTProxySecretType0 : MTProxySecret

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret;

@end

@interface MTProxySecretType1 : MTProxySecret

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret;

@end

@interface MTProxySecretType2 : MTProxySecret

@property (nonatomic, strong, readonly) NSString * _Nonnull domain;

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret domain:(NSString * _Nonnull)domain;

@end

@interface MTSocksProxySettings : NSObject

@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *password;
@property (nonatomic, strong, readonly) NSData *secret;

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port username:(NSString *)username password:(NSString *)password secret:(NSData *)secret;

@end

@interface MTNetworkSettings : NSObject

@property (nonatomic, readonly) bool reducedBackupDiscoveryTimeout;

- (instancetype)initWithReducedBackupDiscoveryTimeout:(bool)reducedBackupDiscoveryTimeout;

@end

@interface MTApiEnvironment : NSObject

@property (nonatomic) int32_t apiId;
@property (nonatomic, strong, readonly) NSString *deviceModel;
@property (nonatomic, strong, readonly) NSString *systemVersion;
@property (nonatomic, strong) NSString *appVersion;
@property (nonatomic, strong, readonly) NSString *systemLangCode;
@property (nonatomic, strong) NSNumber *layer;
@property (nonatomic, strong, readonly) NSData *systemCode;
    
@property (nonatomic, strong) NSString *langPack;
@property (nonatomic, strong, readonly) NSString *langPackCode;

@property (nonatomic, strong, readonly) NSString *apiInitializationHash;

@property (nonatomic) bool disableUpdates;
@property (nonatomic) NSData *tcpPayloadPrefix;
@property (nonatomic) NSDictionary *datacenterAddressOverrides;
@property (nonatomic) NSString *accessHostOverride;

@property (nonatomic, strong, readonly) MTSocksProxySettings *socksProxySettings;
@property (nonatomic, strong, readonly) MTNetworkSettings *networkSettings;

@property (nonatomic, copy) void (^passwordInputHandler)(void);

- (MTApiEnvironment *)withUpdatedLangPackCode:(NSString *)langPackCode;
- (MTApiEnvironment *)withUpdatedSocksProxySettings:(MTSocksProxySettings *)socksProxySettings;
- (MTApiEnvironment *)withUpdatedNetworkSettings:(MTNetworkSettings *)networkSettings;
- (MTApiEnvironment *)withUpdatedSystemCode:(NSData *)systemCode;

@end
