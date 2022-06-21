#import <MtProtoKit/MTFileBasedKeychain.h>

#import <MtProtoKit/MTLogging.h>

#import <pthread.h>

#define TG_SYNCHRONIZED_DEFINE(lock) pthread_mutex_t _TG_SYNCHRONIZED_##lock
#define TG_SYNCHRONIZED_INIT(lock) pthread_mutex_init(&_TG_SYNCHRONIZED_##lock, NULL)
#define TG_SYNCHRONIZED_BEGIN(lock) pthread_mutex_lock(&_TG_SYNCHRONIZED_##lock);
#define TG_SYNCHRONIZED_END(lock) pthread_mutex_unlock(&_TG_SYNCHRONIZED_##lock);

#import <CommonCrypto/CommonCrypto.h>
#import <MtProtoKit/MTEncryption.h>

static TG_SYNCHRONIZED_DEFINE(_keychains) = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *keychains()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TG_SYNCHRONIZED_INIT(_keychains);
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

@interface MTFileBasedKeychain ()
{
    NSString *_name;
    bool _encrypted;
    NSData *_aesKey;
    NSData *_aesIv;
    NSString *_documentsPath;
    
    TG_SYNCHRONIZED_DEFINE(_dictByGroup);
    NSMutableDictionary *_dictByGroup;
}

@end

@implementation MTFileBasedKeychain

+ (instancetype)unencryptedKeychainWithName:(NSString *)name documentsPath:(NSString *)documentsPath
{
    if (name == nil)
        return nil;
    
    TG_SYNCHRONIZED_BEGIN(_keychains);
    MTFileBasedKeychain *keychain = [keychains() objectForKey:name];
    if (keychain == nil)
    {
        keychain = [[MTFileBasedKeychain alloc] initWithName:name documentsPath:documentsPath encrypted:false];
        [keychains() setObject:keychain forKey:name];
    }
    TG_SYNCHRONIZED_END(_keychains);
    
    return keychain;
}

+ (instancetype)keychainWithName:(NSString *)name documentsPath:(NSString *)documentsPath
{
    if (name == nil)
        return nil;
    
    TG_SYNCHRONIZED_BEGIN(_keychains);
    MTFileBasedKeychain *keychain = [keychains() objectForKey:name];
    if (keychain == nil)
    {
        keychain = [[MTFileBasedKeychain alloc] initWithName:name documentsPath:documentsPath encrypted:true];
        [keychains() setObject:keychain forKey:name];
    }
    TG_SYNCHRONIZED_END(_keychains);
    
    return keychain;
}

- (instancetype)initWithName:(NSString *)name documentsPath:(NSString *)documentsPath encrypted:(bool)encrypted
{
    self = [super init];
    if (self != nil)
    {
        TG_SYNCHRONIZED_INIT(_dictByGroup);
        _dictByGroup = [[NSMutableDictionary alloc] init];
        
        _name = name;
        _documentsPath = documentsPath;
        _encrypted = encrypted;
        
        if (name != nil)
        {
            if (_encrypted)
            {
                NSMutableDictionary *keychainReadQuery = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                                           (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                                                                                           (__bridge id)kSecAttrService: @"org.mtproto.MTKeychain",
                                                                                                           (__bridge id)kSecAttrAccount: [[NSString alloc] initWithFormat:@"MTKeychain:%@", name],
#if TARGET_OS_IPHONE
                                                                                                           (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly,
#endif
                                                                                                           (__bridge id)kSecReturnData: (id)kCFBooleanTrue,
                                                                                                           (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
                                                                                                           }];
                
                bool upgradeEncryption = false;
                
                CFDataRef keyData = NULL;
                if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainReadQuery, (CFTypeRef *)&keyData) == noErr && keyData != NULL)
                {
                    NSData *data = (__bridge_transfer NSData *)keyData;
                    if (data.length == 64)
                    {
                        _aesKey = [data subdataWithRange:NSMakeRange(0, 32)];
                        _aesIv = [data subdataWithRange:NSMakeRange(32, 32)];
                    }
                }
                else
                {
                    keychainReadQuery[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
                    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainReadQuery, (CFTypeRef *)&keyData) == noErr && keyData != NULL)
                    {
                        NSData *data = (__bridge_transfer NSData *)keyData;
                        if (data.length == 64)
                        {
                            upgradeEncryption = true;
                            
                            _aesKey = [data subdataWithRange:NSMakeRange(0, 32)];
                            _aesIv = [data subdataWithRange:NSMakeRange(32, 32)];
                        }
                    }
                }
                
                bool storeKey = upgradeEncryption || _aesKey == nil || _aesIv == nil;
                
                if (_aesKey == nil || _aesIv == nil)
                {
                    uint8_t buf[32];
                    
                    __unused int result = 0;
                    result = SecRandomCopyBytes(kSecRandomDefault, 32, buf);
                    _aesKey = [[NSData alloc] initWithBytes:buf length:32];
                    
                    result = SecRandomCopyBytes(kSecRandomDefault, 32, buf);
                    _aesIv = [[NSData alloc] initWithBytes:buf length:32];
                }
                
                NSMutableData *newKeyData = [[NSMutableData alloc] init];
                [newKeyData appendData:_aesKey];
                [newKeyData appendData:_aesIv];
                
                if (storeKey)
                {
                    SecItemDelete((__bridge CFDictionaryRef)@{
                                                              (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                                              (__bridge id)kSecAttrService: @"org.mtproto.MTKeychain",
                                                              (__bridge id)kSecAttrAccount: [[NSString alloc] initWithFormat:@"MTKeychain:%@", name],
#if TARGET_OS_IPHONE
                                                              (__bridge id)kSecAttrAccessible: upgradeEncryption ? (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly : (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly
#endif
                                                              });
                    
                    SecItemAdd((__bridge CFDictionaryRef)@{
                                                           (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                                           (__bridge id)kSecAttrService: @"org.mtproto.MTKeychain",
                                                           (__bridge id)kSecAttrAccount: [[NSString alloc] initWithFormat:@"MTKeychain:%@", name],
#if TARGET_OS_IPHONE
                                                           (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly,
#endif
                                                           (__bridge id)kSecValueData: newKeyData
                                                           }, NULL);
                }
            }
        }
    }
    return self;
}

- (NSString *)filePathForName:(NSString *)name group:(NSString *)group
{
    static NSString *dataDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
#if TARGET_OS_IPHONE
                      dataDirectory = [_documentsPath stringByAppendingPathComponent:@"mtkeychain"];
#elif TARGET_OS_MAC
                      NSString *applicationSupportPath = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES)[0];
                      NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
                      dataDirectory = [[applicationSupportPath stringByAppendingPathComponent:applicationName] stringByAppendingPathComponent:@"mtkeychain"];
#else
#   error "Unsupported OS"
#endif
                      
                      __autoreleasing NSError *error = nil;
                      [[NSFileManager defaultManager] createDirectoryAtPath:dataDirectory withIntermediateDirectories:true attributes:nil error:&error];
                      if (error != nil) {
                          if (MTLogEnabled()) {
                              MTLog(@"[MTKeychain error creating keychain directory: %@]", error);
                          }
                      }
                  });
    
    return [dataDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%@_%@.bin", name, group]];
}

- (void)_loadKeychainIfNeeded:(NSString *)group
{
    if (_dictByGroup[group] == nil)
    {
        if (_name != nil)
        {
            NSData *data = [[NSData alloc] initWithContentsOfFile:[self filePathForName:_name group:group]];
            if (data != nil && data.length >= 4)
            {
                uint32_t length = 0;
                [data getBytes:&length range:NSMakeRange(0, 4)];
                
                uint32_t paddedLength = length;
                while (paddedLength % 16 != 0)
                {
                    paddedLength++;
                }
                
                if (data.length == 4 + paddedLength || data.length == 4 + paddedLength + 4)
                {
                    NSMutableData *encryptedData = [[NSMutableData alloc] init];
                    [encryptedData appendData:[data subdataWithRange:NSMakeRange(4, paddedLength)]];
                    
                    NSMutableData *decryptedData = nil;
                    if (_encrypted) {
                        decryptedData = [[NSMutableData alloc] initWithData:MTAesDecrypt(encryptedData, _aesKey, _aesIv)];
                    } else {
                        decryptedData = encryptedData;
                    }
                    
                    [decryptedData setLength:length];
                    
                    bool hashVerified = true;
                    
                    if (data.length == 4 + paddedLength + 4)
                    {
                        int32_t hash = 0;
                        [data getBytes:&hash range:NSMakeRange(4 + paddedLength, 4)];
                        
                        int32_t decryptedHash = MTMurMurHash32(decryptedData.bytes, (int)decryptedData.length);
                        if (hash != decryptedHash)
                        {
                            if (MTLogEnabled()) {
                                MTLog(@"[MTKeychain invalid decrypted hash]");
                            }
                            hashVerified = false;
                        }
                    }
                    
                    if (hashVerified)
                    {
                        @try
                        {
                            id object = [NSKeyedUnarchiver unarchiveObjectWithData:decryptedData];
                            if ([object respondsToSelector:@selector(objectForKey:)] && [object respondsToSelector:@selector(setObject:forKey:)])
                                _dictByGroup[group] = object;
                            else {
                                if (MTLogEnabled()) {
                                    MTLog(@"[MTKeychain invalid root object %@]", object);
                                }
                            }
                        }
                        @catch (NSException *e)
                        {
                            if (MTLogEnabled()) {
                                MTLog(@"[MTKeychain error parsing keychain: %@]", e);
                            }
                        }
                    }
                }
                else {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTKeychain error loading keychain: expected data length %d, got %d]", 4 + (int)paddedLength, (int)data.length);
                    }
                }
            }
        }
        
        if (_dictByGroup[group] == nil)
            _dictByGroup[group] = [[NSMutableDictionary alloc] init];
    }
}

- (void)_storeKeychain:(NSString *)group
{
    if (_dictByGroup[group] != nil && _name != nil)
    {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_dictByGroup[group]];
        if (data != nil)
        {
            NSMutableData *encryptedData = [[NSMutableData alloc] initWithData:data];
            int32_t hash = MTMurMurHash32(encryptedData.bytes, (int)encryptedData.length);
            
            while (encryptedData.length % 16 != 0)
            {
                uint8_t random = 0;
                arc4random_buf(&random, 1);
                [encryptedData appendBytes:&random length:1];
            }
            
            if (_encrypted)
                MTAesEncryptInplace(encryptedData, _aesKey, _aesIv);
            
            uint32_t length = (uint32_t)data.length;
            [encryptedData replaceBytesInRange:NSMakeRange(0, 0) withBytes:&length length:4];
            [encryptedData appendBytes:&hash length:4];
            
            NSString *filePath = [self filePathForName:_name group:group];
            if (![encryptedData writeToFile:filePath atomically:true]) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTKeychain error writing keychain to file]");
                }
            }
            else
            {
#if TARGET_OS_IPHONE
                __autoreleasing NSError *error = nil;
                [[NSURL fileURLWithPath:filePath] setResourceValue:[NSNumber numberWithBool:true] forKey:NSURLIsExcludedFromBackupKey error:&error];
                if (error != nil) {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTKeychain error setting \"exclude from backup\" flag]");
                    }
                }
#endif
            }
        }
        else {
            if (MTLogEnabled()) {
                MTLog(@"[MTKeychain error serializing keychain]");
            }
        }
    }
}

- (void)setObject:(id)object forKey:(id<NSCopying>)aKey group:(NSString *)group
{
    if (object == nil || aKey == nil)
        return;
    
    TG_SYNCHRONIZED_BEGIN(_dictByGroup);
    [self _loadKeychainIfNeeded:group];
    
    _dictByGroup[group][aKey] = object;
    [self _storeKeychain:group];
    TG_SYNCHRONIZED_END(_dictByGroup);
}

- (id)objectForKey:(id<NSCopying>)aKey group:(NSString *)group
{
    if (aKey == nil)
        return nil;
    
    TG_SYNCHRONIZED_BEGIN(_dictByGroup);
    [self _loadKeychainIfNeeded:group];
    
    id result = _dictByGroup[group][aKey];
    TG_SYNCHRONIZED_END(_dictByGroup);
    
    return result;
}

- (void)removeObjectForKey:(id<NSCopying>)aKey group:(NSString *)group
{
    if (aKey == nil)
        return;
    
    TG_SYNCHRONIZED_BEGIN(_dictByGroup);
    [self _loadKeychainIfNeeded:group];
    
    [_dictByGroup[group] removeObjectForKey:aKey];
    [self _storeKeychain:group];
    TG_SYNCHRONIZED_END(_dictByGroup);
}

- (void)dropGroup:(NSString *)group
{
    if (group == nil)
        return;
    
    TG_SYNCHRONIZED_BEGIN(_dictByGroup);
    _dictByGroup[group] = [[NSMutableDictionary alloc] init];
    [self _storeKeychain:group];
    TG_SYNCHRONIZED_END(_dictByGroup);
}

- (NSDictionary<NSString *, id> *)contentsForGroup:(NSString *)group {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    TG_SYNCHRONIZED_BEGIN(_dictByGroup);
    [self _loadKeychainIfNeeded:group];
    [_dictByGroup[group] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        result[key] = obj;
    }];
    TG_SYNCHRONIZED_END(_dictByGroup);
    
    return result;
}

@end
