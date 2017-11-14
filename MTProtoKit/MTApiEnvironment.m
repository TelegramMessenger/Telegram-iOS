/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

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
#define IPHONE_5S_NAMESTRING             @"iPhone 5S"
#define IPHONE_6_NAMESTRING             @"iPhone 6"
#define IPHONE_6Plus_NAMESTRING             @"iPhone 6 Plus"
#define IPHONE_6S_NAMESTRING             @"iPhone 6S"
#define IPHONE_6SPlus_NAMESTRING             @"iPhone 6S Plus"
#define IPHONE_7_NAMESTRING             @"iPhone 7"
#define IPHONE_7Plus_NAMESTRING             @"iPhone 7 Plus"
#define IPHONE_8_NAMESTRING             @"iPhone 8"
#define IPHONE_8Plus_NAMESTRING             @"iPhone 8 Plus"
#define IPHONE_X_NAMESTRING             @"iPhone X"
#define IPHONE_SE_NAMESTRING             @"iPhone SE"
#define IPHONE_UNKNOWN_NAMESTRING       @"Unknown iPhone"

#define IPOD_1G_NAMESTRING              @"iPod touch 1G"
#define IPOD_2G_NAMESTRING              @"iPod touch 2G"
#define IPOD_3G_NAMESTRING              @"iPod touch 3G"
#define IPOD_4G_NAMESTRING              @"iPod touch 4G"
#define IPOD_5G_NAMESTRING              @"iPod touch 5G"
#define IPOD_6G_NAMESTRING              @"iPod touch 6G"
#define IPOD_UNKNOWN_NAMESTRING         @"Unknown iPod"

#define IPAD_1G_NAMESTRING              @"iPad 1G"
#define IPAD_2G_NAMESTRING              @"iPad 2G"
#define IPAD_3G_NAMESTRING              @"iPad 3G"
#define IPAD_4G_NAMESTRING              @"iPad 4G"
#define IPAD_5G_NAMESTRING              @"iPad Air 2"
#define IPAD_6G_NAMESTRING  @"iPad Pro"
#define IPAD_UNKNOWN_NAMESTRING         @"Unknown iPad"

#define APPLETV_2G_NAMESTRING           @"Apple TV 2G"
#define APPLETV_3G_NAMESTRING           @"Apple TV 3G"
#define APPLETV_4G_NAMESTRING           @"Apple TV 4G"
#define APPLETV_UNKNOWN_NAMESTRING      @"Unknown Apple TV"

#define IOS_FAMILY_UNKNOWN_DEVICE       @"Unknown iOS device"

#define SIMULATOR_NAMESTRING            @"iPhone Simulator"
#define SIMULATOR_IPHONE_NAMESTRING     @"iPhone Simulator"
#define SIMULATOR_IPAD_NAMESTRING       @"iPad Simulator"
#define SIMULATOR_APPLETV_NAMESTRING    @"Apple TV Simulator" // :)

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
    
    UIDevice1GiPod,
    UIDevice2GiPod,
    UIDevice3GiPod,
    UIDevice4GiPod,
    UIDevice5GiPod,
    UIDevice6GiPod,
    
    UIDevice1GiPad,
    UIDevice2GiPad,
    UIDevice3GiPad,
    UIDevice4GiPad,
    UIDevice5GiPad,
    UIDevice6GiPad,
    
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

@implementation MTSocksProxySettings

- (instancetype)initWithIp:(NSString *)ip port:(uint16_t)port username:(NSString *)username password:(NSString *)password {
    self = [super init];
    if (self != nil) {
        _ip = ip;
        _port = port;
        _username = username;
        _password = password;
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
        
        NSString *versionString = [[NSString alloc] initWithFormat:@"%@ (%@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
        _appVersion = versionString;
        
        _systemLangCode = [[NSLocale preferredLanguages] objectAtIndex:0];
        
        _langPack = @"ios";
        _langPackCode = @"";
        
        [self _updateApiInitializationHash];
    }
    return self;
}

- (void)_updateApiInitializationHash {
    _apiInitializationHash = [[NSString alloc] initWithFormat:@"apiId=%" PRId32 "&deviceModel=%@&systemVersion=%@&appVersion=%@&langCode=%@&layer=%@&langPack=%@&langPackCode=%@", _apiId, _deviceModel, _systemVersion, _appVersion, _systemLangCode, _layer, _langPack, _langPackCode];
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
        case UIDeviceUnknowniPhone: return IPHONE_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPod: return IPOD_1G_NAMESTRING;
        case UIDevice2GiPod: return IPOD_2G_NAMESTRING;
        case UIDevice3GiPod: return IPOD_3G_NAMESTRING;
        case UIDevice4GiPod: return IPOD_4G_NAMESTRING;
        case UIDevice5GiPod: return IPOD_5G_NAMESTRING;
        case UIDevice6GiPod: return IPOD_6G_NAMESTRING;
        case UIDeviceUnknowniPod: return IPOD_UNKNOWN_NAMESTRING;
            
        case UIDevice1GiPad : return IPAD_1G_NAMESTRING;
        case UIDevice2GiPad : return IPAD_2G_NAMESTRING;
        case UIDevice3GiPad : return IPAD_3G_NAMESTRING;
        case UIDevice4GiPad : return IPAD_4G_NAMESTRING;
        case UIDevice5GiPad : return IPAD_5G_NAMESTRING;
        case UIDevice6GiPad : return IPAD_6G_NAMESTRING;
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
            
        case UIDeviceOSX: return @"macOS";
            
        default: return IOS_FAMILY_UNKNOWN_DEVICE;
    }
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
    
    if ([platform isEqualToString:@"iPhone8,4"])    return UIDeviceSEPhone;
    
    // iPod
    if ([platform hasPrefix:@"iPod1"])              return UIDevice1GiPod;
    if ([platform hasPrefix:@"iPod2"])              return UIDevice2GiPod;
    if ([platform hasPrefix:@"iPod3"])              return UIDevice3GiPod;
    if ([platform hasPrefix:@"iPod4"])              return UIDevice4GiPod;
    if ([platform hasPrefix:@"iPod5"])              return UIDevice5GiPod;
    if ([platform hasPrefix:@"iPod7"])              return UIDevice6GiPod;
    
    // iPad
    if ([platform hasPrefix:@"iPad1"])              return UIDevice1GiPad;
    if ([platform hasPrefix:@"iPad2"])              return UIDevice2GiPad;
    if ([platform hasPrefix:@"iPad3"])              return UIDevice3GiPad;
    if ([platform hasPrefix:@"iPad4"])              return UIDevice4GiPad;
    if ([platform hasPrefix:@"iPad5"])              return UIDevice5GiPad;
    if ([platform hasPrefix:@"iPad6"])              return UIDevice6GiPad;
    
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
    result->_socksProxySettings = self.socksProxySettings;
    
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
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    
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
    
    result.disableUpdates = self.disableUpdates;
    result.tcpPayloadPrefix = self.tcpPayloadPrefix;
    result.datacenterAddressOverrides = self.datacenterAddressOverrides;
    
    [result _updateApiInitializationHash];
    
    return result;
}

@end

