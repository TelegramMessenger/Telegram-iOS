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

@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, strong, readonly) NSString * _Nullable username;
@property (nonatomic, strong, readonly) NSString * _Nullable password;
@property (nonatomic, strong, readonly) NSData * _Nullable secret;

- (instancetype _Nonnull)initWithIp:(NSString * _Nonnull )ip port:(uint16_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password secret:(NSData * _Nullable)secret;

@end

@interface MTNetworkSettings : NSObject

@property (nonatomic, readonly) bool reducedBackupDiscoveryTimeout;

- (instancetype _Nonnull)initWithReducedBackupDiscoveryTimeout:(bool)reducedBackupDiscoveryTimeout;

@end

@interface MTApiEnvironment : NSObject

@property (nonatomic) int32_t apiId;
@property (nonatomic, strong, readonly) NSString * _Nullable deviceModel;
@property (nonatomic, strong, readonly) NSDictionary<NSString *, NSString *> * _Nullable resolvedDeviceName;

@property (nonatomic, strong, readonly) NSString * _Nullable systemVersion;
@property (nonatomic, strong) NSString * _Nullable appVersion;
@property (nonatomic, strong, readonly) NSString * _Nullable systemLangCode;
@property (nonatomic, strong) NSNumber * _Nullable layer;
@property (nonatomic, strong, readonly) NSData * _Nullable systemCode;
    
@property (nonatomic, strong) NSString * _Nullable langPack;
@property (nonatomic, strong, readonly) NSString * _Nullable langPackCode;

@property (nonatomic, strong, readonly) NSString * _Nullable apiInitializationHash;

@property (nonatomic) bool disableUpdates;
@property (nonatomic) NSData * _Nullable tcpPayloadPrefix;
@property (nonatomic) NSDictionary * _Nullable datacenterAddressOverrides;
@property (nonatomic) NSString * _Nullable accessHostOverride;

@property (nonatomic, strong, readonly) MTSocksProxySettings * _Nullable socksProxySettings;
@property (nonatomic, strong, readonly) MTNetworkSettings * _Nullable networkSettings;

@property (nonatomic, copy) void (^ _Nullable passwordInputHandler)(void);

- (MTApiEnvironment * _Nonnull)withUpdatedLangPackCode:(NSString * _Nullable)langPackCode;
- (MTApiEnvironment * _Nonnull)withUpdatedSocksProxySettings:(MTSocksProxySettings * _Nullable)socksProxySettings;
- (MTApiEnvironment * _Nonnull)withUpdatedNetworkSettings:(MTNetworkSettings * _Nullable)networkSettings;
- (MTApiEnvironment * _Nonnull)withUpdatedSystemCode:(NSData * _Nullable)systemCode;

-(id _Nonnull)initWithResolvedDeviceName:(NSDictionary<NSString *, NSString *> * _Nullable)resolvedDeviceName;

@end
