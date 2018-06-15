

#import <Foundation/Foundation.h>

@interface MTSocksProxySettings : NSObject

@property (nonatomic, strong, readonly) NSString *ip;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, strong, readonly) NSString *username;
@property (nonatomic, strong, readonly) NSString *password;
@property (nonatomic, strong, readonly) NSData *secret;

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port username:(NSString *)username password:(NSString *)password secret:(NSData *)secret;

+ (bool)secretSupportsExtendedPadding:(NSData *)data;

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
    
@property (nonatomic, strong) NSString *langPack;
@property (nonatomic, strong, readonly) NSString *langPackCode;

@property (nonatomic, strong, readonly) NSString *apiInitializationHash;

@property (nonatomic) bool disableUpdates;
@property (nonatomic) NSData *tcpPayloadPrefix;
@property (nonatomic) NSDictionary *datacenterAddressOverrides;

@property (nonatomic, strong, readonly) MTSocksProxySettings *socksProxySettings;
@property (nonatomic, strong, readonly) MTNetworkSettings *networkSettings;

@property (nonatomic, copy) void (^passwordInputHandler)();

- (MTApiEnvironment *)withUpdatedLangPackCode:(NSString *)langPackCode;
- (MTApiEnvironment *)withUpdatedSocksProxySettings:(MTSocksProxySettings *)socksProxySettings;
- (MTApiEnvironment *)withUpdatedNetworkSettings:(MTNetworkSettings *)networkSettings;

@end
