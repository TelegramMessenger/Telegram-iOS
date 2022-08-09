#import <MtProtoKit/MTApiEnvironment.h>

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#else

#endif

#include <sys/sysctl.h>

#import <CommonCrypto/CommonDigest.h>

typedef enum {
    UIDeviceUnknown,
    
    UIDeviceSimulator,
    
    UIDevice1GiPhone,
    UIDevice3GiPhone,
    UIDevice3GSiPhone,
    UIDevice4iPhone,
    UIDevice4SiPhone,
    UIDevice5iPhone,
    UIDevice5SiPhone,
    UIDevice6iPhone,
    UIDevice6PlusiPhone,
    UIDevice6SiPhone,
    UIDevice6SPlusiPhone,
    UIDevice7iPhone,
    UIDevice7PlusiPhone,
    UIDevice8iPhone,
    UIDevice8PlusiPhone,
    UIDeviceXiPhone,
    UIDeviceSEPhone,
    UIDeviceSE2Phone,
    UIDeviceXSiPhone,
    UIDeviceXSMaxiPhone,
    UIDeviceXRiPhone,
    UIDevice11iPhone,
    UIDevice11ProiPhone,
    UIDevice11ProMaxiPhone,
    UIDevice12MiniiPhone,
    UIDevice12iPhone,
    UIDevice12ProiPhone,
    UIDevice12ProMaxiPhone,
    
    UIDevice1GiPod,
    UIDevice2GiPod,
    UIDevice3GiPod,
    UIDevice4GiPod,
    UIDevice5GiPod,
    UIDevice6GiPod,
    UIDevice7GiPod,
    
    UIDevice1GiPad,
    UIDevice2GiPad,
    UIDevice3GiPad,
    UIDevice4GiPad,
    UIDevice5GiPad,
    UIDevice6GiPad,
    
    UIDeviceiPadPro12_93g,
    UIDeviceiPadPro11,
    UIDeviceiPadPro6g,
    UIDeviceiPadPro10_5,
    UIDeviceiPadPro12_9,
    
    UIDeviceAppleTV2,
    UIDeviceAppleTV3,
    UIDeviceAppleTV4,
    
    UIDeviceUnknowniPhone,
    UIDeviceUnknowniPod,
    UIDeviceUnknowniPad,
    UIDeviceUnknownAppleTV,
    UIDeviceIFPGA,
    
    UIDeviceOSX
    
} UIDevicePlatform;

static NSData * _Nullable parseHexString(NSString * _Nonnull hex) {
    if ([hex length] % 2 != 0) {
        return nil;
    }
    char buf[3];
    buf[2] = '\0';
    uint8_t *bytes = (uint8_t *)malloc(hex.length / 2);
    uint8_t *bp = bytes;
    for (CFIndex i = 0; i < [hex length]; i += 2) {
        buf[0] = [hex characterAtIndex:i];
        buf[1] = [hex characterAtIndex:i+1];
        char *b2 = NULL;
        *bp++ = strtol(buf, &b2, 16);
        if (b2 != buf + 2) {
            return nil;
        }
    }
    
    return [NSData dataWithBytesNoCopy:bytes length:[hex length]/2 freeWhenDone:YES];
}

static NSString * _Nonnull dataToHexString(NSData * _Nonnull data) {
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    if (dataBuffer == NULL) {
        return @"";
    }
    
    NSUInteger dataLength  = [data length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < (int)dataLength; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    
    return hexString;
}

static NSData *base64_decode(NSString *str) {
    if ([NSData instancesRespondToSelector:@selector(initWithBase64EncodedString:options:)]) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        return data;
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[NSData alloc] initWithBase64Encoding:[str stringByReplacingOccurrencesOfString:@"[^A-Za-z0-9+/=]" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, [str length])]];
#pragma clang diagnostic pop
    }
}

@implementation MTProxySecret

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret {
    self = [super init];
    if (self != nil) {
        _secret = secret;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self != nil) {
        _secret = [aDecoder decodeObjectForKey:@"secret"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_secret forKey:@"secret"];
}

+ (MTProxySecret * _Nullable)parse:(NSString * _Nonnull)string {
    NSData *hexData = parseHexString(string);
    if (hexData == nil) {
        NSString *finalString = @"";
        finalString = [finalString stringByAppendingString:[string stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]]];
        finalString = [finalString stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
        finalString = [finalString stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
        while (finalString.length % 4 != 0) {
            finalString = [finalString stringByAppendingString:@"="];
        }
        
        hexData = base64_decode(finalString);
    }
    if (hexData != nil) {
        return [self parseData:hexData];
    } else {
        return nil;
    }
}

+ (MTProxySecret * _Nullable)parseData:(NSData * _Nonnull)data {
    if (data == nil || data.length < 16) {
        return nil;
    }
    
    uint8_t firstByte = 0;
    [data getBytes:&firstByte length:1];
    
    if (data.length == 16) {
        return [[MTProxySecretType0 alloc] initWithSecret:data];
    } else if (data.length == 17) {
        if (firstByte == 0xdd) {
            return [[MTProxySecretType1 alloc] initWithSecret:[data subdataWithRange:NSMakeRange(1, 16)]];
        } else {
            return nil;
        }
    } else if (data.length >= 18 && firstByte == 0xee) {
        NSString *domain = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(1 + 16, data.length - (1 + 16))] encoding:NSUTF8StringEncoding];
        if (domain == nil) {
            return nil;
        }
        return [[MTProxySecretType2 alloc] initWithSecret:[data subdataWithRange:NSMakeRange(1, 16)] domain:domain];
    } else {
        return nil;
    }
}

- (NSData * _Nonnull)serialize {
    assert(false);
    return nil;
}

- (NSString * _Nonnull)serializeToString {
    assert(false);
    return nil;
}

- (NSString *)description {
    return dataToHexString([self serialize]);
}

@end

@implementation MTProxySecretType0

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret {
    self = [super initWithSecret:secret];
    if (self != nil) {
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
}

- (NSData * _Nonnull)serialize {
    return self.secret;
}

- (NSString * _Nonnull)serializeToString {
    return dataToHexString(self.serialize);
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTProxySecretType0 class]]) {
        return false;
    }
    MTProxySecretType0 *other = object;
    if (![self.secret isEqual:other.secret]) {
        return false;
    }
    return true;
}

@end

@implementation MTProxySecretType1

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret {
    self = [super initWithSecret:secret];
    if (self != nil) {
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
}

- (NSData * _Nonnull)serialize {
    NSMutableData *data = [[NSMutableData alloc] init];
    uint8_t marker = 0xdd;
    [data appendBytes:&marker length:1];
    [data appendData:self.secret];
    return data;
}

- (NSString * _Nonnull)serializeToString {
    return dataToHexString(self.serialize);
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTProxySecretType1 class]]) {
        return false;
    }
    MTProxySecretType1 *other = object;
    if (![self.secret isEqual:other.secret]) {
        return false;
    }
    return true;
}

@end

@implementation MTProxySecretType2

- (instancetype _Nullable)initWithSecret:(NSData * _Nonnull)secret domain:(NSString * _Nonnull)domain {
    self = [super initWithSecret:secret];
    if (self != nil) {
        _domain = domain;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _domain = [aDecoder decodeObjectForKey:@"domain"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:_domain forKey:@"domain"];
}

- (NSData * _Nonnull)serialize {
    NSMutableData *data = [[NSMutableData alloc] init];
    uint8_t marker = 0xee;
    [data appendBytes:&marker length:1];
    [data appendData:self.secret];
    [data appendData:[_domain dataUsingEncoding:NSUTF8StringEncoding]];
    return data;
}

- (NSString * _Nonnull)serializeToString {
    NSData *data = [self serialize];
    if ([data respondsToSelector:@selector(base64EncodedDataWithOptions:)]) {
        return [[data base64EncodedStringWithOptions:kNilOptions] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self.serialize base64Encoding];
#pragma clang diagnostic pop
    }
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTProxySecretType2 class]]) {
        return false;
    }
    MTProxySecretType2 *other = object;
    if (![self.secret isEqual:other.secret]) {
        return false;
    }
    if (![self.domain isEqual:other.domain]) {
        return false;
    }
    return true;
}

@end

@implementation MTSocksProxySettings

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port username:(NSString *)username password:(NSString *)password secret:(NSData *)secret {
    self = [super init];
    if (self != nil) {
        _ip = ip;
        _port = port;
        _username = username;
        _password = password;
        _secret = secret;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTSocksProxySettings class]]) {
        return false;
    }
    MTSocksProxySettings *other = object;
    if ((other->_ip != nil) != (_ip != nil) || (_ip != nil && ![_ip isEqual:other->_ip])) {
        return false;
    }
    if (other->_port != _port) {
        return false;
    }
    if ((other->_username != nil) != (_username != nil) || (_username != nil && ![_username isEqual:other->_username])) {
        return false;
    }
    if ((other->_password != nil) != (_password != nil) || (_password != nil && ![_password isEqual:other->_password])) {
        return false;
    }
    if ((other->_secret != nil) != (_secret != nil) || (_secret != nil && ![_secret isEqual:other->_secret])) {
        return false;
    }
    return true;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%d+%@+%@+%@", _ip, (int)_port, _username, _password, [_secret description]];
}

@end

@implementation MTNetworkSettings

- (instancetype)initWithReducedBackupDiscoveryTimeout:(bool)reducedBackupDiscoveryTimeout {
    self = [super init];
    if (self != nil) {
        _reducedBackupDiscoveryTimeout = reducedBackupDiscoveryTimeout;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTNetworkSettings class]]) {
        return false;
    }
    MTNetworkSettings *other = object;
    if (_reducedBackupDiscoveryTimeout != other->_reducedBackupDiscoveryTimeout) {
        return false;
    }
    return true;
}

@end

@implementation MTApiEnvironment

-(instancetype)init {
    self = [self initWithResolvedDeviceName:nil];
    if (self != nil)
    {
        
    }
    return self;
}

-(id _Nonnull)initWithResolvedDeviceName:(NSDictionary<NSString *, NSString *> * _Nullable)resolvedDeviceName {
    self = [super init];
    if (self != nil)
    {
        if (resolvedDeviceName != nil) {
            NSString *model = [self platformString];
            NSString* resolved = resolvedDeviceName[model];
            if (resolved != nil) {
                _deviceModel = resolved;
            } else {
                _deviceModel = model;
            }
        } else {
            _deviceModel = [self platformString];
        }
        _resolvedDeviceName = resolvedDeviceName;
#if TARGET_OS_IPHONE
        _systemVersion = [[UIDevice currentDevice] systemVersion];
#else
        NSProcessInfo *pInfo = [NSProcessInfo processInfo];
        _systemVersion = [[[pInfo operatingSystemVersionString] componentsSeparatedByString:@" "] objectAtIndex:1];
#endif
        
NSString *suffix = @"";
#if TARGET_OS_OSX
#ifdef BETA
        suffix = @" BETA";
#endif
        
#ifdef APPSTORE
        suffix = @" APPSTORE";
#endif
        
#ifdef STABLE
        suffix = @" STABLE";
#endif
#endif
        NSString *versionString = [[NSString alloc] initWithFormat:@"%@ (%@)%@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], suffix];
        _appVersion = versionString;
        
        _systemLangCode = [[NSLocale preferredLanguages] objectAtIndex:0];
    #if TARGET_OS_OSX
        _langPack = @"macos";
    #else
         _langPack = @"ios";
    #endif
        _langPackCode = @"";
        
        [self _updateApiInitializationHash];
    }
    return self;
}

- (void)_updateApiInitializationHash {
    _apiInitializationHash = [[NSString alloc] initWithFormat:@"apiId=%" PRId32 "&deviceModel=%@&systemVersion=%@&appVersion=%@&langCode=%@&layer=%@&langPack=%@&langPackCode=%@&proxy=%@&systemCode=%@", _apiId, _deviceModel, _systemVersion, _appVersion, _systemLangCode, _layer, _langPack, _langPackCode, _socksProxySettings, _systemCode];
}

- (void)setLayer:(NSNumber *)layer {
    _layer = layer;
    
    [self _updateApiInitializationHash];
}

- (void)setAppVersion:(NSString *)appVersion {
    _appVersion = appVersion;
    
    [self _updateApiInitializationHash];
}

- (void)setLangPack:(NSString *)langPack {
    _langPack = langPack;
    
    [self _updateApiInitializationHash];
}

- (void)setLangPackCode:(NSString *)langPackCode {
    _langPackCode = langPackCode;
    
    [self _updateApiInitializationHash];
}

- (NSString *)platformString
{
#if TARGET_OS_IPHONE
    NSString *platform = [self platform];
    
    if ([platform isEqualToString:@"iPhone1,1"])
        return @"iPhone";
    if ([platform isEqualToString:@"iPhone1,2"])
        return @"iPhone 3G";
    if ([platform isEqualToString:@"iPhone2,1"])
        return @"iPhone 3GS";
    if ([platform hasPrefix:@"iPhone3"])
        return @"iPhone 4";
    if ([platform hasPrefix:@"iPhone4"])
        return @"iPhone 4S";
    if ([platform isEqualToString:@"iPhone5,1"] ||
        [platform isEqualToString:@"iPhone5,2"])
        return @"iPhone 5";
    if ([platform isEqualToString:@"iPhone5,3"] ||
        [platform isEqualToString:@"iPhone5,4"])
        return @"iPhone 5C";
    if ([platform hasPrefix:@"iPhone6"])
        return @"iPhone 5S";
    if ([platform isEqualToString:@"iPhone7,1"])
        return @"iPhone 6 Plus";
    if ([platform isEqualToString:@"iPhone7,2"])
        return @"iPhone 6";
    if ([platform isEqualToString:@"iPhone8,1"])
        return @"iPhone 6S";
    if ([platform isEqualToString:@"iPhone8,2"])
        return @"iPhone 6S Plus";
    if ([platform isEqualToString:@"iPhone8,4"])
        return @"iPhone SE";
    if ([platform isEqualToString:@"iPhone9,1"] ||
        [platform isEqualToString:@"iPhone9,3"])
        return @"iPhone 7";
    if ([platform isEqualToString:@"iPhone9,2"] ||
        [platform isEqualToString:@"iPhone9,4"])
        return @"iPhone 7 Plus";
    if ([platform isEqualToString:@"iPhone10,1"] ||
        [platform isEqualToString:@"iPhone10,4"])
        return @"iPhone 8";
    if ([platform isEqualToString:@"iPhone10,2"] ||
        [platform isEqualToString:@"iPhone10,5"])
        return @"iPhone 8 Plus";
    if ([platform isEqualToString:@"iPhone10,3"] ||
        [platform isEqualToString:@"iPhone10,6"])
        return @"iPhone X";
    if ([platform isEqualToString:@"iPhone11,2"])
        return @"iPhone XS";
    if ([platform isEqualToString:@"iPhone11,4"] ||
        [platform isEqualToString:@"iPhone11,6"])
        return @"iPhone XS Max";
    if ([platform isEqualToString:@"iPhone11,8"])
        return @"iPhone XR";
    if ([platform isEqualToString:@"iPhone12,1"])
        return @"iPhone 11";
    if ([platform isEqualToString:@"iPhone12,3"])
        return @"iPhone 11 Pro";
    if ([platform isEqualToString:@"iPhone12,5"])
        return @"iPhone 11 Pro Max";
    if ([platform isEqualToString:@"iPhone12,8"])
        return @"iPhone SE (2nd gen)";
    if ([platform isEqualToString:@"iPhone13,1"])
        return @"iPhone 12 mini";
    if ([platform isEqualToString:@"iPhone13,2"])
        return @"iPhone 12";
    if ([platform isEqualToString:@"iPhone13,3"])
        return @"iPhone 12 Pro";
    if ([platform isEqualToString:@"iPhone13,4"])
        return @"iPhone 12 Pro Max";
    if ([platform isEqualToString:@"iPhone14,2"])
        return @"iPhone 13 Pro";
    if ([platform isEqualToString:@"iPhone14,3"])
        return @"iPhone 13 Pro Max";
    if ([platform isEqualToString:@"iPhone14,4"])
        return @"iPhone 13 Mini";
    if ([platform isEqualToString:@"iPhone14,5"])
        return @"iPhone 13";
    if ([platform isEqualToString:@"iPhone14,6"])
        return @"iPhone SE (3rd gen)";
    
    if ([platform hasPrefix:@"iPod1"])
        return @"iPod touch 1G";
    if ([platform hasPrefix:@"iPod2"])
        return @"iPod touch 2G";
    if ([platform hasPrefix:@"iPod3"])
        return @"iPod touch 3G";
    if ([platform hasPrefix:@"iPod4"])
        return @"iPod touch 4G";
    if ([platform hasPrefix:@"iPod5"])
        return @"iPod touch 5G";
    if ([platform hasPrefix:@"iPod7"])
        return @"iPod touch 6G";
    if ([platform hasPrefix:@"iPod9"])
        return @"iPod touch 7G";
    
    if ([platform isEqualToString:@"iPad2,5"] ||
        [platform isEqualToString:@"iPad2,6"] ||
        [platform isEqualToString:@"iPad2,7"])
        return @"iPad mini";
    
    if ([platform hasPrefix:@"iPad2"])
        return @"iPad 2G";
    
    if ([platform isEqualToString:@"iPad3,1"] ||
        [platform isEqualToString:@"iPad3,2"] ||
        [platform isEqualToString:@"iPad3,3"])
        return @"iPad 3G";
    
    if ([platform isEqualToString:@"iPad3,4"] ||
        [platform isEqualToString:@"iPad3,5"] ||
        [platform isEqualToString:@"iPad3,6"])
        return @"iPad 3G";
    
    if ([platform isEqualToString:@"iPad4,1"] ||
        [platform isEqualToString:@"iPad4,2"])
        return @"iPad Air";
        
    if ([platform isEqualToString:@"iPad4,4"] ||
        [platform isEqualToString:@"iPad4,5"] ||
        [platform isEqualToString:@"iPad4,6"])
        return @"iPad mini Retina";
    
    if ([platform isEqualToString:@"iPad4,7"] ||
        [platform isEqualToString:@"iPad4,8"] ||
        [platform isEqualToString:@"iPad4,9"])
        return @"iPad mini 3";
    
    if ([platform isEqualToString:@"iPad5,1"] ||
        [platform isEqualToString:@"iPad5,2"])
        return @"iPad mini 4";
    
    if ([platform isEqualToString:@"iPad5,3"] ||
        [platform isEqualToString:@"iPad5,4"])
        return @"iPad Air 2";
    
    if ([platform isEqualToString:@"iPad6,3"] ||
        [platform isEqualToString:@"iPad6,4"])
        return @"iPad Pro 9.7 inch";
    
    if ([platform isEqualToString:@"iPad6,7"] ||
        [platform isEqualToString:@"iPad6,8"])
        return @"iPad Pro 12.9 inch";
    
    if ([platform isEqualToString:@"iPad6,11"] ||
        [platform isEqualToString:@"iPad6,12"])
        return @"iPad (2017)";
    
    if ([platform isEqualToString:@"iPad7,1"] ||
        [platform isEqualToString:@"iPad7,2"])
        return @"iPad Pro (2nd gen)";
    
    if ([platform isEqualToString:@"iPad7,3"] ||
        [platform isEqualToString:@"iPad7,4"])
        return @"iPad Pro 10.5 inch";
    
    if ([platform isEqualToString:@"iPad7,5"] ||
        [platform isEqualToString:@"iPad7,6"])
        return @"iPad (6th gen)";
    
    if ([platform isEqualToString:@"iPad7,11"] ||
        [platform isEqualToString:@"iPad7,12"])
        return @"iPad 10.2 inch (7th gen)";
    
    if ([platform isEqualToString:@"iPad8,1"] ||
        [platform isEqualToString:@"iPad8,2"] ||
        [platform isEqualToString:@"iPad8,3"] ||
        [platform isEqualToString:@"iPad8,4"])
        return @"iPad Pro 11 inch";
    
    if ([platform isEqualToString:@"iPad8,5"] ||
        [platform isEqualToString:@"iPad8,6"] ||
        [platform isEqualToString:@"iPad8,7"] ||
        [platform isEqualToString:@"iPad8,8"])
        return @"iPad Pro 12.9 inch (3rd gen)";
    
    if ([platform isEqualToString:@"iPad8,9"] ||
        [platform isEqualToString:@"iPad8,10"])
        return @"iPad Pro 11 inch (2th gen)";
    
    if ([platform isEqualToString:@"iPad8,11"] ||
        [platform isEqualToString:@"iPad8,12"])
        return @"iPad Pro 12.9 inch (4th gen)";
    
    if ([platform isEqualToString:@"iPad11,1"] ||
        [platform isEqualToString:@"iPad11,2"])
        return @"iPad mini (5th gen)";
    
    if ([platform isEqualToString:@"iPad11,3"] ||
        [platform isEqualToString:@"iPad11,4"])
        return @"iPad Air (3rd gen)";
    
    if ([platform isEqualToString:@"iPad11,6"] ||
        [platform isEqualToString:@"iPad11,7"])
        return @"iPad (8th gen)";
    
    if ([platform isEqualToString:@"iPad13,1"] ||
        [platform isEqualToString:@"iPad13,2"])
        return @"iPad Air (4th gen)";
    
    if ([platform isEqualToString:@"iPad13,4"] ||
        [platform isEqualToString:@"iPad13,5"] ||
        [platform isEqualToString:@"iPad13,6"] ||
        [platform isEqualToString:@"iPad13,7"])
        return @"iPad Pro 11 inch (3th gen)";
    
    if ([platform isEqualToString:@"iPad13,8"] ||
        [platform isEqualToString:@"iPad13,9"] ||
        [platform isEqualToString:@"iPad13,10"] ||
        [platform isEqualToString:@"iPad13,11"])
        return @"iPad Pro 12.9 inch (5th gen)";
    
    if ([platform isEqualToString:@"iPad13,16"] ||
        [platform isEqualToString:@"iPad13,17"])
        return @"iPad Air (5th gen)";
    
    if ([platform isEqualToString:@"iPad14,1"] ||
        [platform isEqualToString:@"iPad14,2"])
        return @"iPad mini (6th gen)";
            
    if ([platform hasPrefix:@"iPhone"])
        return @"Unknown iPhone";
    if ([platform hasPrefix:@"iPod"])
        return @"Unknown iPod";
    if ([platform hasPrefix:@"iPad"])
        return @"Unknown iPad";
    
    if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"] || [platform isEqual:@"arm64"]) {
        return @"iPhone Simulator";
    }
#else
    return [self macHWName];
#endif
    
    return @"Unknown iOS device";
}
    
- (NSString *)macHWName {
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *name = [[NSString alloc] initWithUTF8String:model];
        free(model);
        return name;
    };
    return @"macOS";
}

- (NSString *)getSysInfoByName:(char *)typeSpecifier
{
    size_t size;
    sysctlbyname(typeSpecifier, NULL, &size, NULL, 0);
    
    char *answer = malloc(size);
    sysctlbyname(typeSpecifier, answer, &size, NULL, 0);
    
    NSString *results = [NSString stringWithCString:answer encoding: NSUTF8StringEncoding];
    
    free(answer);
    return results;
}

- (NSString *)platform
{
    return [self getSysInfoByName:"hw.machine"];
}

- (MTApiEnvironment *)withUpdatedLangPackCode:(NSString *)langPackCode {
    MTApiEnvironment *result = [[MTApiEnvironment alloc] initWithResolvedDeviceName:_resolvedDeviceName];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = langPackCode;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    result.accessHostOverride = self.accessHostOverride;
    result->_socksProxySettings = self.socksProxySettings;
    result->_networkSettings = self.networkSettings;
    result->_systemCode = self.systemCode;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    MTApiEnvironment *result =  [[MTApiEnvironment alloc] initWithResolvedDeviceName:_resolvedDeviceName];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_networkSettings = self.networkSettings;
    result->_systemCode = self.systemCode;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    result.accessHostOverride = self.accessHostOverride;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedSocksProxySettings:(MTSocksProxySettings *)socksProxySettings {
    MTApiEnvironment *result =  [[MTApiEnvironment alloc] initWithResolvedDeviceName:_resolvedDeviceName];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = socksProxySettings;
    result->_networkSettings = self.networkSettings;
    result->_systemCode = self.systemCode;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    result.accessHostOverride = self.accessHostOverride;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedNetworkSettings:(MTNetworkSettings *)networkSettings {
    MTApiEnvironment *result =  [[MTApiEnvironment alloc] initWithResolvedDeviceName:_resolvedDeviceName];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_networkSettings = networkSettings;
    result->_systemCode = self.systemCode;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    result.accessHostOverride = self.accessHostOverride;
    
    [result _updateApiInitializationHash];
    
    return result;
}

- (MTApiEnvironment *)withUpdatedSystemCode:(NSData *)systemCode {
    MTApiEnvironment *result =  [[MTApiEnvironment alloc] initWithResolvedDeviceName:_resolvedDeviceName];
    
    result.apiId = self.apiId;
    result.appVersion = self.appVersion;
    result.layer = self.layer;
    
    result.langPack = self.langPack;
    
    result->_langPackCode = self.langPackCode;
    result->_socksProxySettings = self.socksProxySettings;
    result->_networkSettings = self.networkSettings;
    result->_systemCode = systemCode;
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    result.accessHostOverride = self.accessHostOverride;
    
    [result _updateApiInitializationHash];
    
    return result;
}

@end

