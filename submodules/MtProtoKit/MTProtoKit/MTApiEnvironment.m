

#import "MTApiEnvironment.h"

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#else

#endif

#include <sys/sysctl.h>

#import <CommonCrypto/CommonDigest.h>

#define IFPGA_NAMESTRING                @"iFPGA"

#define IPHONE_1G_NAMESTRING            @"iPhone 1G"
#define IPHONE_3G_NAMESTRING            @"iPhone 3G"
#define IPHONE_3GS_NAMESTRING           @"iPhone 3GS"
#define IPHONE_4_NAMESTRING             @"iPhone 4"
#define IPHONE_4S_NAMESTRING            @"iPhone 4S"
#define IPHONE_5_NAMESTRING             @"iPhone 5"
#define IPHONE_5S_NAMESTRING            @"iPhone 5S"
#define IPHONE_6_NAMESTRING             @"iPhone 6"
#define IPHONE_6Plus_NAMESTRING         @"iPhone 6 Plus"
#define IPHONE_6S_NAMESTRING            @"iPhone 6S"
#define IPHONE_6SPlus_NAMESTRING        @"iPhone 6S Plus"
#define IPHONE_7_NAMESTRING             @"iPhone 7"
#define IPHONE_7Plus_NAMESTRING         @"iPhone 7 Plus"
#define IPHONE_8_NAMESTRING             @"iPhone 8"
#define IPHONE_8Plus_NAMESTRING         @"iPhone 8 Plus"
#define IPHONE_X_NAMESTRING             @"iPhone X"
#define IPHONE_SE_NAMESTRING            @"iPhone SE"
#define IPHONE_XS_NAMESTRING            @"iPhone XS"
#define IPHONE_XSMAX_NAMESTRING         @"iPhone XS Max"
#define IPHONE_XR_NAMESTRING            @"iPhone XR"
#define IPHONE_11_NAMESTRING            @"iPhone 11"
#define IPHONE_11PRO_NAMESTRING         @"iPhone 11 Pro"
#define IPHONE_11PROMAX_NAMESTRING      @"iPhone 11 Pro Max"
#define IPHONE_UNKNOWN_NAMESTRING       @"Unknown iPhone"

#define IPOD_1G_NAMESTRING              @"iPod touch 1G"
#define IPOD_2G_NAMESTRING              @"iPod touch 2G"
#define IPOD_3G_NAMESTRING              @"iPod touch 3G"
#define IPOD_4G_NAMESTRING              @"iPod touch 4G"
#define IPOD_5G_NAMESTRING              @"iPod touch 5G"
#define IPOD_6G_NAMESTRING              @"iPod touch 6G"
#define IPOD_7G_NAMESTRING              @"iPod touch 7G"
#define IPOD_UNKNOWN_NAMESTRING         @"Unknown iPod"

#define IPAD_1G_NAMESTRING              @"iPad 1G"
#define IPAD_2G_NAMESTRING              @"iPad 2G"
#define IPAD_3G_NAMESTRING              @"iPad 3G"
#define IPAD_4G_NAMESTRING              @"iPad 4G"
#define IPAD_5G_NAMESTRING              @"iPad Air 2"
#define IPAD_6G_NAMESTRING              @"iPad Pro"
#define IPAD_PRO_3G_NAMESTRING          @"iPad Pro 12.9 inch (3rd gen)"
#define IPAD_PRO_11_NAMESTRING          @"iPad Pro 11 inch"
#define IPAD_PRO_6G_NAMESTRING          @"iPad (6th gen)"
#define IPAD_PRO_10_5_NAMESTRING        @"iPad Pro 10.5 inch"
#define IPAD_PRO_12_9_NAMESTRING        @"iPad Pro 12.9 inch"
#define IPAD_UNKNOWN_NAMESTRING         @"Unknown iPad"

#define APPLETV_2G_NAMESTRING           @"Apple TV 2G"
#define APPLETV_3G_NAMESTRING           @"Apple TV 3G"
#define APPLETV_4G_NAMESTRING           @"Apple TV 4G"
#define APPLETV_UNKNOWN_NAMESTRING      @"Unknown Apple TV"

#define IOS_FAMILY_UNKNOWN_DEVICE       @"Unknown iOS device"

#define SIMULATOR_NAMESTRING            @"iPhone Simulator"
#define SIMULATOR_IPHONE_NAMESTRING     @"iPhone Simulator"
#define SIMULATOR_IPAD_NAMESTRING       @"iPad Simulator"
#define SIMULATOR_APPLETV_NAMESTRING    @"Apple TV Simulator"

/*
 iPad8,5, iPad8,6, iPad8,7, iPad8,8 - iPad Pro 12.9" (3rd gen)
 iPad8,1, iPad8,2, iPad8,3, iPad8,4 - iPad Pro 11"
 iPad7,5, iPad7,6 - iPad 6th gen
 iPad7,3, iPad7,4 - iPad Pro 10.5"
 iPad7,1, iPad7,2 - iPad Pro 12.9" (2ng gen)
 */

typedef enum {
    UIDeviceUnknown,
    
    UIDeviceSimulator,
    UIDeviceSimulatoriPhone,
    UIDeviceSimulatoriPad,
    UIDeviceSimulatorAppleTV,
    
    UIDevice1GiPhone,
    UIDevice3GiPhone,
    UIDevice3GSiPhone,
    UIDevice4iPhone,
    UIDevice4SiPhone,
    UIDevice5iPhone,
    UIDevice5SiPhone,
    UIDevice6iPhone,
    UIDevice6PlusiPhone,
    UIDevice6siPhone,
    UIDevice6SPlusiPhone,
    UIDevice7iPhone,
    UIDevice7PlusiPhone,
    UIDevice8iPhone,
    UIDevice8PlusiPhone,
    UIDeviceXiPhone,
    UIDeviceSEPhone,
    UIDeviceXSiPhone,
    UIDeviceXSMaxiPhone,
    UIDeviceXRiPhone,
    UIDevice11iPhone,
    UIDevice11ProiPhone,
    UIDevice11ProMaxiPhone,
    
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

typedef enum {
    UIDeviceFamilyiPhone,
    UIDeviceFamilyiPod,
    UIDeviceFamilyiPad,
    UIDeviceFamilyAppleTV,
    UIDeviceFamilyUnknown,
    
} UIDeviceFamily;

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

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _deviceModel = [self platformString];
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
    switch ([self platformType])
    {
        case UIDevice1GiPhone: return IPHONE_1G_NAMESTRING;
        case UIDevice3GiPhone: return IPHONE_3G_NAMESTRING;
        case UIDevice3GSiPhone: return IPHONE_3GS_NAMESTRING;
        case UIDevice4iPhone: return IPHONE_4_NAMESTRING;
        case UIDevice4SiPhone: return IPHONE_4S_NAMESTRING;
        case UIDevice5iPhone: return IPHONE_5_NAMESTRING;
        case UIDevice5SiPhone: return IPHONE_5S_NAMESTRING;
        case UIDevice6iPhone: return IPHONE_6_NAMESTRING;
        case UIDevice6PlusiPhone: return IPHONE_6Plus_NAMESTRING;
        case UIDevice6siPhone: return IPHONE_6S_NAMESTRING;
        case UIDevice6SPlusiPhone: return IPHONE_6SPlus_NAMESTRING;
        case UIDevice7iPhone: return IPHONE_7_NAMESTRING;
        case UIDevice7PlusiPhone: return IPHONE_7Plus_NAMESTRING;
        case UIDevice8iPhone: return IPHONE_8_NAMESTRING;
        case UIDevice8PlusiPhone: return IPHONE_8Plus_NAMESTRING;
        case UIDeviceXiPhone: return IPHONE_X_NAMESTRING;
        case UIDeviceSEPhone: return IPHONE_SE_NAMESTRING;
        case UIDeviceXSiPhone: return IPHONE_XS_NAMESTRING;
        case UIDeviceXSMaxiPhone: return IPHONE_XSMAX_NAMESTRING;
        case UIDeviceXRiPhone: return IPHONE_XR_NAMESTRING;
        case UIDevice11iPhone: return IPHONE_11_NAMESTRING;
        case UIDevice11ProiPhone: return IPHONE_11PRO_NAMESTRING;
        case UIDevice11ProMaxiPhone: return IPHONE_11PROMAX_NAMESTRING;
        case UIDeviceUnknowniPhone: return IPHONE_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPod: return IPOD_1G_NAMESTRING;
        case UIDevice2GiPod: return IPOD_2G_NAMESTRING;
        case UIDevice3GiPod: return IPOD_3G_NAMESTRING;
        case UIDevice4GiPod: return IPOD_4G_NAMESTRING;
        case UIDevice5GiPod: return IPOD_5G_NAMESTRING;
        case UIDevice6GiPod: return IPOD_6G_NAMESTRING;
        case UIDevice7GiPod: return IPOD_7G_NAMESTRING;
        case UIDeviceUnknowniPod: return IPOD_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPad : return IPAD_1G_NAMESTRING;
        case UIDevice2GiPad : return IPAD_2G_NAMESTRING;
        case UIDevice3GiPad : return IPAD_3G_NAMESTRING;
        case UIDevice4GiPad : return IPAD_4G_NAMESTRING;
        case UIDevice5GiPad : return IPAD_5G_NAMESTRING;
        case UIDevice6GiPad : return IPAD_6G_NAMESTRING;
        case UIDeviceiPadPro12_93g : return IPAD_PRO_12_9_NAMESTRING;
        case UIDeviceiPadPro11 : return IPAD_PRO_11_NAMESTRING;
        case UIDeviceiPadPro6g : return IPAD_PRO_6G_NAMESTRING;
        case UIDeviceiPadPro10_5 : return IPAD_PRO_10_5_NAMESTRING;
        case UIDeviceiPadPro12_9 : return IPAD_PRO_12_9_NAMESTRING;
        case UIDeviceUnknowniPad : return IPAD_UNKNOWN_NAMESTRING;
            
        case UIDeviceAppleTV2 : return APPLETV_2G_NAMESTRING;
        case UIDeviceAppleTV3 : return APPLETV_3G_NAMESTRING;
        case UIDeviceAppleTV4 : return APPLETV_4G_NAMESTRING;
        case UIDeviceUnknownAppleTV: return APPLETV_UNKNOWN_NAMESTRING;
            
        case UIDeviceSimulator: return SIMULATOR_NAMESTRING;
        case UIDeviceSimulatoriPhone: return SIMULATOR_IPHONE_NAMESTRING;
        case UIDeviceSimulatoriPad: return SIMULATOR_IPAD_NAMESTRING;
        case UIDeviceSimulatorAppleTV: return SIMULATOR_APPLETV_NAMESTRING;
            
        case UIDeviceIFPGA: return IFPGA_NAMESTRING;
            
        case UIDeviceOSX: return [self macHWName];
        
        default: return IOS_FAMILY_UNKNOWN_DEVICE;
    }
}
    
-(NSString *)macHWName {
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

- (NSUInteger)platformType
{
#if TARGET_OS_IPHONE
    NSString *platform = [self platform];
    
    // The ever mysterious iFPGA
    if ([platform isEqualToString:@"iFPGA"])        return UIDeviceIFPGA;
    
    // iPhone
    if ([platform isEqualToString:@"iPhone1,1"])    return UIDevice1GiPhone;
    if ([platform isEqualToString:@"iPhone1,2"])    return UIDevice3GiPhone;
    if ([platform hasPrefix:@"iPhone2"])            return UIDevice3GSiPhone;
    if ([platform hasPrefix:@"iPhone3"])            return UIDevice4iPhone;
    if ([platform hasPrefix:@"iPhone4"])            return UIDevice4SiPhone;
    if ([platform hasPrefix:@"iPhone5"])            return UIDevice5iPhone;
    if ([platform hasPrefix:@"iPhone6"])            return UIDevice5SiPhone;
    
    if ([platform isEqualToString:@"iPhone7,1"])    return UIDevice6PlusiPhone;
    if ([platform isEqualToString:@"iPhone7,2"])    return UIDevice6iPhone;
    if ([platform isEqualToString:@"iPhone8,1"])    return UIDevice6siPhone;
    if ([platform isEqualToString:@"iPhone8,2"])    return UIDevice6SPlusiPhone;
    if ([platform isEqualToString:@"iPhone9,1"])    return UIDevice7iPhone;
    if ([platform isEqualToString:@"iPhone9,3"])    return UIDevice7iPhone;
    if ([platform isEqualToString:@"iPhone9,2"])    return UIDevice7PlusiPhone;
    if ([platform isEqualToString:@"iPhone9,4"])    return UIDevice7PlusiPhone;
    
    if ([platform isEqualToString:@"iPhone10,1"])    return UIDevice8iPhone;
    if ([platform isEqualToString:@"iPhone10,4"])    return UIDevice8iPhone;
    if ([platform isEqualToString:@"iPhone10,2"])    return UIDevice8PlusiPhone;
    if ([platform isEqualToString:@"iPhone10,5"])    return UIDevice8PlusiPhone;
    if ([platform isEqualToString:@"iPhone10,3"])    return UIDeviceXiPhone;
    if ([platform isEqualToString:@"iPhone10,6"])    return UIDeviceXiPhone;
    if ([platform isEqualToString:@"iPhone11,2"])    return UIDeviceXSiPhone;
    if ([platform isEqualToString:@"iPhone11,6"])    return UIDeviceXSMaxiPhone;
    if ([platform isEqualToString:@"iPhone11,4"])    return UIDeviceXSMaxiPhone;
    if ([platform isEqualToString:@"iPhone11,8"])    return UIDeviceXRiPhone;
    
    if ([platform isEqualToString:@"iPhone12,1"])    return UIDevice11iPhone;
    if ([platform isEqualToString:@"iPhone12,3"])    return UIDevice11ProiPhone;
    if ([platform isEqualToString:@"iPhone12,5"])    return UIDevice11ProMaxiPhone;
    
    if ([platform isEqualToString:@"iPhone8,4"])    return UIDeviceSEPhone;
    
    // iPod
    if ([platform hasPrefix:@"iPod1"])              return UIDevice1GiPod;
    if ([platform hasPrefix:@"iPod2"])              return UIDevice2GiPod;
    if ([platform hasPrefix:@"iPod3"])              return UIDevice3GiPod;
    if ([platform hasPrefix:@"iPod4"])              return UIDevice4GiPod;
    if ([platform hasPrefix:@"iPod5"])              return UIDevice5GiPod;
    if ([platform hasPrefix:@"iPod7"])              return UIDevice6GiPod;
    if ([platform hasPrefix:@"iPod9"])              return UIDevice7GiPod;
    
    // iPad
    if ([platform hasPrefix:@"iPad1"])              return UIDevice1GiPad;
    if ([platform hasPrefix:@"iPad2"])              return UIDevice2GiPad;
    if ([platform hasPrefix:@"iPad3"])              return UIDevice3GiPad;
    if ([platform hasPrefix:@"iPad4"])              return UIDevice4GiPad;
    if ([platform hasPrefix:@"iPad5"])              return UIDevice5GiPad;
    if ([platform hasPrefix:@"iPad6"])              return UIDevice6GiPad;
    
    if ([platform isEqualToString:@"iPad8,5"] ||
        [platform isEqualToString:@"iPad8,6"] ||
        [platform isEqualToString:@"iPad8,7"] ||
        [platform isEqualToString:@"iPad8,8"]) {
        return UIDeviceiPadPro12_93g;
    }
    
    if ([platform isEqualToString:@"iPad8,1"] ||
        [platform isEqualToString:@"iPad8,2"] ||
        [platform isEqualToString:@"iPad8,3"] ||
        [platform isEqualToString:@"iPad8,4"]) {
        return UIDeviceiPadPro11;
    }
    
    if ([platform isEqualToString:@"iPad7,5"] ||
        [platform isEqualToString:@"iPad7,6"]) {
        return UIDeviceiPadPro6g;
    }
    
    if ([platform isEqualToString:@"iPad7,3"] ||
        [platform isEqualToString:@"iPad7,4"]) {
        return UIDeviceiPadPro10_5;
    }
    
    if ([platform isEqualToString:@"iPad7,1"] ||
        [platform isEqualToString:@"iPad7,2"]) {
        return UIDeviceiPadPro12_9;
    }
    
    // Apple TV
    if ([platform hasPrefix:@"AppleTV2"])           return UIDeviceAppleTV2;
    if ([platform hasPrefix:@"AppleTV3"])           return UIDeviceAppleTV3;
    
    if ([platform hasPrefix:@"iPhone"])             return UIDeviceUnknowniPhone;
    if ([platform hasPrefix:@"iPod"])               return UIDeviceUnknowniPod;
    if ([platform hasPrefix:@"iPad"])               return UIDeviceUnknowniPad;
    if ([platform hasPrefix:@"AppleTV"])            return UIDeviceUnknownAppleTV;
    
    // Simulator thanks Jordan Breeding
    if ([platform hasSuffix:@"86"] || [platform isEqual:@"x86_64"])
    {
        return UIDeviceSimulatoriPhone;
    }
#else
    return UIDeviceOSX;
#endif
    
    return UIDeviceUnknown;
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
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
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
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
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
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
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
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
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
    MTApiEnvironment *result = [[MTApiEnvironment alloc] init];
    
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

