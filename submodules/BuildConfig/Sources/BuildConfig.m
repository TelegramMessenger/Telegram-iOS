#import <BuildConfig/BuildConfig.h>

static NSString *telegramApplicationSecretKey = @"telegramApplicationSecretKey_v3";
API_AVAILABLE(ios(10))
@interface LocalPrivateKey : NSObject {
    SecKeyRef _privateKey;
    SecKeyRef _publicKey;
}

- (NSData * _Nullable)encrypt:(NSData * _Nonnull)data;
- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data cancelled:(bool *)cancelled;

@end

@implementation LocalPrivateKey

- (instancetype _Nonnull)initWithPrivateKey:(SecKeyRef)privateKey publicKey:(SecKeyRef)publicKey {
    self = [super init];
    if (self != nil) {
        _privateKey = (SecKeyRef)CFRetain(privateKey);
        _publicKey = (SecKeyRef)CFRetain(publicKey);
    }
    return self;
}

- (void)dealloc {
    CFRelease(_privateKey);
    CFRelease(_publicKey);
}

- (NSData * _Nullable)getPublicKey {
    NSData *result = CFBridgingRelease(SecKeyCopyExternalRepresentation(_publicKey, nil));
    return result;
}

- (NSData * _Nullable)encrypt:(NSData * _Nonnull)data {
    if (data.length % 16 != 0) {
        return nil;
    }
    
    CFErrorRef error = NULL;
    NSData *cipherText = (NSData *)CFBridgingRelease(SecKeyCreateEncryptedData(_publicKey, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM, (__bridge CFDataRef)data, &error));
    
    if (!cipherText) {
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    return cipherText;
}

- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data cancelled:(bool *)cancelled {    
    CFErrorRef error = NULL;
    NSData *plainText = (NSData *)CFBridgingRelease(SecKeyCreateDecryptedData(_privateKey, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM, (__bridge CFDataRef)data, &error));
    
    if (!plainText) {
        __unused NSError *err = CFBridgingRelease(error);
        if (err.code == -2) {
            if (cancelled) {
                *cancelled = true;
            }
        }
        return nil;
    }
    
    return plainText;
}

@end

@interface BuildConfig () {
    NSData * _Nullable _bundleData;
    int32_t _apiId;
    NSString * _Nonnull _apiHash;
    NSString * _Nullable _appCenterId;
    NSMutableDictionary * _Nonnull _dataDict;
}

@end

@implementation DeviceSpecificEncryptionParameters

- (instancetype)initWithKey:(NSData * _Nonnull)key salt:(NSData * _Nonnull)salt {
    self = [super init];
    if (self != nil) {
        _key = key;
        _salt = salt;
    }
    return self;
}

@end

@implementation BuildConfig

+ (NSString *)bundleId {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
        (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
        @"bundleSeedID", kSecAttrAccount,
        @"", kSecAttrService,
        (id)kCFBooleanTrue, kSecReturnAttributes,
    nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }
    if (status != errSecSuccess) {
        return nil;
    }
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [[components objectEnumerator] nextObject];
    CFRelease(result);
    return bundleSeedID;
}

+ (instancetype _Nonnull)sharedBuildConfig {
    static BuildConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BuildConfig alloc] init];
    });
    return instance;
}

- (instancetype _Nonnull)initWithBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId {
    self = [super init];
    if (self != nil) {
        _apiId = APP_CONFIG_API_ID;
        _apiHash = @(APP_CONFIG_API_HASH);
        _appCenterId = @(APP_CONFIG_APP_CENTER_ID);
        
        _dataDict = [[NSMutableDictionary alloc] init];
        
        if (baseAppBundleId != nil) {
            _dataDict[@"bundleId"] = baseAppBundleId;
        }
    }
    return self;
}

- (NSData * _Nullable)bundleDataWithAppToken:(NSData * _Nullable)appToken signatureDict:(NSDictionary * _Nullable)signatureDict {
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] initWithDictionary:_dataDict];
    if (appToken != nil) {
        dataDict[@"device_token"] = [appToken base64EncodedStringWithOptions:0];
        dataDict[@"device_token_type"] = @"voip";
    }
    float tzOffset = [[NSTimeZone systemTimeZone] secondsFromGMT];
    dataDict[@"tz_offset"] = @((int)tzOffset);
    if (signatureDict != nil) {
        for (id<NSCopying> key in signatureDict.allKeys) {
            dataDict[key] = signatureDict[key];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
    return data;
}

- (int32_t)apiId {
    return _apiId;
}

- (NSString * _Nonnull)apiHash {
    return _apiHash;
}

- (NSString * _Nullable)appCenterId {
    return _appCenterId;
}

- (bool)isInternalBuild {
    return APP_CONFIG_IS_INTERNAL_BUILD;
}

- (bool)isAppStoreBuild {
    return APP_CONFIG_IS_APPSTORE_BUILD;
}

- (int64_t)appStoreId {
    return APP_CONFIG_APPSTORE_ID;
}

- (NSString *)appSpecificUrlScheme {
    return @(APP_SPECIFIC_URL_SCHEME);
}

- (NSString *)premiumIAPProductId {
    return @(APP_CONFIG_PREMIUM_IAP_PRODUCT_ID);
}

+ (NSString * _Nullable)bundleSeedId {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
       (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
       @"bundleSeedID", kSecAttrAccount,
       @"", kSecAttrService,
       (id)kCFBooleanTrue, kSecReturnAttributes,
    nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    }
    if (status != errSecSuccess) {
        return nil;
    }
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [[components objectEnumerator] nextObject];
    CFRelease(result);
    return bundleSeedID;
}

+ (NSData * _Nullable)applicationSecretTag:(bool)isCheckKey {
    if (isCheckKey) {
        return [[telegramApplicationSecretKey stringByAppendingString:@"_check"] dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        return [telegramApplicationSecretKey dataUsingEncoding:NSUTF8StringEncoding];
    }
}

+ (LocalPrivateKey * _Nullable)getApplicationSecretKey:(NSString * _Nonnull)baseAppBundleId isCheckKey:(bool)isCheckKey API_AVAILABLE(ios(10)) {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [self applicationSecretTag:isCheckKey];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassKey,
        (id)kSecAttrApplicationTag: applicationTag,
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrAccessGroup: (id)accessGroup,
        (id)kSecReturnRef: @YES
    };
    SecKeyRef privateKey = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&privateKey);
    if (status != errSecSuccess) {
        return nil;
    }
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        if (privateKey) {
            CFRelease(privateKey);
        }
        return nil;
    }
    
    LocalPrivateKey *result = [[LocalPrivateKey alloc] initWithPrivateKey:privateKey publicKey:publicKey];
    
    if (publicKey) {
        CFRelease(publicKey);
    }
    if (privateKey) {
        CFRelease(privateKey);
    }
    
    return result;
}

+ (bool)removeApplicationSecretKey:(NSString * _Nonnull)baseAppBundleId isCheckKey:(bool)isCheckKey API_AVAILABLE(ios(10)) {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [self applicationSecretTag:isCheckKey];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassKey,
        (id)kSecAttrApplicationTag: applicationTag,
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrAccessGroup: (id)accessGroup
    };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status != errSecSuccess) {
        return false;
    }
    return true;
}

+ (LocalPrivateKey * _Nullable)addApplicationSecretKey:(NSString * _Nonnull)baseAppBundleId isCheckKey:(bool)isCheckKey API_AVAILABLE(ios(10)) {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [self applicationSecretTag:isCheckKey];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    SecAccessControlRef access;
    if (isCheckKey) {
        access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, kSecAccessControlPrivateKeyUsage, NULL);
    } else {
        access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, kSecAccessControlUserPresence | kSecAccessControlPrivateKeyUsage, NULL);
    }
    NSDictionary *attributes = @{
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeySizeInBits: @256,
        (id)kSecAttrTokenID: (id)kSecAttrTokenIDSecureEnclave,
        (id)kSecPrivateKeyAttrs: @{
            (id)kSecAttrIsPermanent: @YES,
            (id)kSecAttrApplicationTag: applicationTag,
            (id)kSecAttrAccessControl: (__bridge id)access,
            (id)kSecAttrAccessGroup: (id)accessGroup,
        },
    };
    
    CFErrorRef error = NULL;
    SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
    if (!privateKey) {
        if (access) {
            CFRelease(access);
        }
        
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
    if (!publicKey) {
        if (privateKey) {
            CFRelease(privateKey);
        }
        if (access) {
            CFRelease(access);
        }
        
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    LocalPrivateKey *result = [[LocalPrivateKey alloc] initWithPrivateKey:privateKey publicKey:publicKey];
    
    if (publicKey) {
        CFRelease(publicKey);
    }
    if (privateKey) {
        CFRelease(privateKey);
    }
    if (access) {
        CFRelease(access);
    }
    
    return result;
}

+ (DeviceSpecificEncryptionParameters * _Nonnull)deviceSpecificEncryptionParameters:(NSString * _Nonnull)rootPath baseAppBundleId:(NSString * _Nonnull)baseAppBundleId {
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    NSString *filePath = [rootPath stringByAppendingPathComponent:@".tempkey"];
    //NSString *encryptedPath = [rootPath stringByAppendingPathComponent:@".tempkeyEncrypted"];
    
    NSData *currentData = [NSData dataWithContentsOfFile:filePath];
    NSData *resultData = nil;
    if (currentData != nil && currentData.length == 32 + 16) {
        resultData = currentData;
    }
    if (resultData == nil) {
        NSMutableData *randomData = [[NSMutableData alloc] initWithLength:32 + 16];
        int result = SecRandomCopyBytes(kSecRandomDefault, randomData.length, [randomData mutableBytes]);
        if (currentData != nil && currentData.length == 32) { // upgrade key with salt
            [currentData getBytes:randomData.mutableBytes length:32];
        }
        assert(result == 0);
        resultData = randomData;
        [resultData writeToFile:filePath atomically:false];
    }
    
    /*if (@available(iOS 11, *)) {
        NSData *currentEncryptedData = [NSData dataWithContentsOfFile:encryptedPath];
        
        LocalPrivateKey *localPrivateKey = [self getLocalPrivateKey:baseAppBundleId];
        
        if (localPrivateKey == nil) {
            localPrivateKey = [self addLocalPrivateKey:baseAppBundleId];
        }
    
        if (localPrivateKey != nil) {
            if (currentEncryptedData != nil) {
                NSData *decryptedData = [localPrivateKey decrypt:currentEncryptedData];
                
                if (![resultData isEqualToData:decryptedData]) {
                    NSData *encryptedData = [localPrivateKey encrypt:resultData];
                    [encryptedData writeToFile:encryptedPath atomically:false];
                    //assert(false);
                }
            } else {
                NSData *encryptedData = [localPrivateKey encrypt:resultData];
                [encryptedData writeToFile:encryptedPath atomically:false];
            }
        }
    }*/
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    NSLog(@"deviceSpecificEncryptionParameters took %f ms", (endTime - startTime) * 1000.0);
    
    NSData *key = [resultData subdataWithRange:NSMakeRange(0, 32)];
    NSData *salt = [resultData subdataWithRange:NSMakeRange(32, 16)];
    return [[DeviceSpecificEncryptionParameters alloc] initWithKey:key salt:salt];
}

+ (dispatch_queue_t)encryptionQueue {
    static dispatch_queue_t instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = dispatch_queue_create("encryptionQueue", 0);
    });
    return instance;
}

+ (void)getHardwareEncryptionAvailableWithBaseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^)(NSData * _Nullable))completion {
    dispatch_async([self encryptionQueue], ^{
        LocalPrivateKey *checkKey = [self getApplicationSecretKey:baseAppBundleId isCheckKey:true];
        if (checkKey != nil) {
            NSData *sampleData = [checkKey encrypt:[NSData data]];
            if (sampleData == nil) {
                [self removeApplicationSecretKey:baseAppBundleId isCheckKey:false];
                [self removeApplicationSecretKey:baseAppBundleId isCheckKey:true];
            } else {
                NSData *decryptedData = [checkKey decrypt:sampleData cancelled: nil];
                if (decryptedData == nil) {
                    [self removeApplicationSecretKey:baseAppBundleId isCheckKey:false];
                    [self removeApplicationSecretKey:baseAppBundleId isCheckKey:true];
                }
            }
        } else {
            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:false];
            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:true];
        }
        
        LocalPrivateKey *privateKey = [self getApplicationSecretKey:baseAppBundleId isCheckKey:false];
        if (privateKey == nil) {
            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:false];
            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:true];
            privateKey = [self addApplicationSecretKey:baseAppBundleId isCheckKey:false];
            privateKey = [self addApplicationSecretKey:baseAppBundleId isCheckKey:true];
        }
        completion([privateKey getPublicKey]);
    });
}

+ (void)encryptApplicationSecret:(NSData * _Nonnull)secret baseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^)(NSData * _Nullable, NSData * _Nullable))completion {
    dispatch_async([self encryptionQueue], ^{
        LocalPrivateKey *privateKey = [self getApplicationSecretKey:baseAppBundleId isCheckKey:false];
        if (privateKey == nil) {
            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:false];
            [self removeApplicationSecretKey:baseAppBundleId isCheckKey:true];
            privateKey = [self addApplicationSecretKey:baseAppBundleId isCheckKey:false];
            privateKey = [self addApplicationSecretKey:baseAppBundleId isCheckKey:true];
        }
        if (privateKey == nil) {
            completion(nil, nil);
            return;
        }
        NSData *result = [privateKey encrypt:secret];
        completion(result, [privateKey getPublicKey]);
    });
}

+ (void)decryptApplicationSecret:(NSData * _Nonnull)secret publicKey:(NSData * _Nonnull)publicKey baseAppBundleId:(NSString * _Nonnull)baseAppBundleId completion:(void (^)(NSData * _Nullable, bool))completion {
    dispatch_async([self encryptionQueue], ^{
        LocalPrivateKey *privateKey = [self getApplicationSecretKey:baseAppBundleId isCheckKey:false];
        if (privateKey == nil) {
            completion(nil, false);
            return;
        }
        if (privateKey == nil) {
            completion(nil, false);
            return;
        }
        NSData *currentPublicKey = [privateKey getPublicKey];
        if (currentPublicKey == nil) {
            completion(nil, false);
            return;
        }
        if (![publicKey isEqualToData:currentPublicKey]) {
            completion(nil, false);
            return;
        }
        bool cancelled = false;
        NSData *result = [privateKey decrypt:secret cancelled:&cancelled];
        completion(result, cancelled);
    });
}

@end
