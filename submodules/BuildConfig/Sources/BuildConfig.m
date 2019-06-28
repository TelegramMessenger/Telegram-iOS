#import "BuildConfig.h"

#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

#ifdef BUCK
#import <MtProtoKit/MtProtoKit.h>
#else
#import <MtProtoKitDynamic/MtProtoKitDynamic.h>
#endif

static uint32_t funcSwap32(uint32_t input)
{
    return OSSwapBigToHostInt32(input);
}

static uint32_t funcNoSwap32(uint32_t input)
{
    return OSSwapLittleToHostInt32(input);
}

/*
 * Magic numbers used by Code Signing
 */
enum {
    kSecCodeMagicRequirement = 0xfade0c00,       /* single requirement */
    kSecCodeMagicRequirementSet = 0xfade0c01,    /* requirement set */
    kSecCodeMagicCodeDirectory = 0xfade0c02,     /* CodeDirectory */
    kSecCodeMagicEmbeddedSignature = 0xfade0cc0, /* single-architecture embedded signature */
    kSecCodeMagicDetachedSignature = 0xfade0cc1, /* detached multi-architecture signature */
    kSecCodeMagicEntitlement = 0xfade7171,       /* entitlement blob */
    
    kSecCodeMagicByte = 0xfa                     /* shared first byte */
};


/*
 * Structure of an embedded-signature SuperBlob
 */
typedef struct __BlobIndex {
    uint32_t type;                  /* type of entry */
    uint32_t offset;                /* offset of entry */
} CS_BlobIndex;

typedef struct __Blob {
    uint32_t magic;                 /* magic number */
    uint32_t length;                /* total length of SuperBlob */
} CS_Blob;

typedef struct __SuperBlob {
    CS_Blob blob;
    uint32_t count;                  /* number of index entries following */
    CS_BlobIndex index[];            /* (count) entries */
    /* followed by Blobs in no particular order as indicated by offsets in index */
} CS_SuperBlob;


/*
 * C form of a CodeDirectory.
 */
typedef struct __CodeDirectory {
    uint32_t magic;                 /* magic number (CSMAGIC_CODEDIRECTORY) */
    uint32_t length;                /* total length of CodeDirectory blob */
    uint32_t version;               /* compatibility version */
    uint32_t flags;                 /* setup and mode flags */
    uint32_t hashOffset;            /* offset of hash slot element at index zero */
    uint32_t identOffset;           /* offset of identifier string */
    uint32_t nSpecialSlots;         /* number of special hash slots */
    uint32_t nCodeSlots;            /* number of ordinary (code) hash slots */
    uint32_t codeLimit;             /* limit to main image signature range */
    uint8_t hashSize;               /* size of each hash in bytes */
    uint8_t hashType;               /* type of hash (cdHashType* constants) */
    uint8_t spare1;                 /* unused (must be zero) */
    uint8_t    pageSize;            /* log2(page size in bytes); 0 => infinite */
    uint32_t spare2;                /* unused (must be zero) */
    /* followed by dynamic content as located by offset fields above */
} CS_CodeDirectory;

static MTPKCS * _Nullable parseSignature(const char* buffer, size_t size) {
    CS_SuperBlob* sb = (CS_SuperBlob*)buffer;
    if (OSSwapBigToHostInt32(sb->blob.magic) != kSecCodeMagicEmbeddedSignature)
    {
        return 0;
    }
    
    uint32_t count = OSSwapBigToHostInt32(sb->count);
    
    for (uint32_t i = 0; i < count; i++)
    {
        uint32_t offset = OSSwapBigToHostInt32(sb->index[i].offset);
        
        const CS_Blob* blob = (const CS_Blob*)(buffer + offset);
        
        if (OSSwapBigToHostInt32(blob->magic) == 0xfade0b01) // signature
        {
            printf("Embedded signature, length: %d\n", OSSwapBigToHostInt32(blob->length));
            
            if (OSSwapBigToHostInt32(blob->length) != 8)
            {
                const unsigned char* message = (const unsigned char*)buffer + offset + 8;
                MTPKCS *result = [MTPKCS parse:message size:(OSSwapBigToHostInt32(blob->length) - 8)];
                return result;
            }
        }
    }
    
    return nil;
}

static MTPKCS * _Nullable parseArch(const char* buffer, size_t size) {
    uint32_t (*swap32)(uint32_t) = funcNoSwap32;
    
    uint32_t offset = 0;
    
    const struct mach_header* header = (struct mach_header*)(buffer + offset);
    
    switch (header->magic) {
        case MH_CIGAM:
            swap32 = funcSwap32;
        case MH_MAGIC:
            offset += sizeof(struct mach_header);
            break;
        case MH_CIGAM_64:
            swap32 = funcSwap32;
        case MH_MAGIC_64:
            offset += sizeof(struct mach_header_64);
            break;
        default:
            return nil;
    }
    
    const NXArchInfo *archInfo = NXGetArchInfoFromCpuType(swap32(header->cputype), swap32(header->cpusubtype));
    if (archInfo != NULL) {
        printf("Architecture: %s\n", archInfo->name);
    }
    
    uint32_t commandCount = swap32(header->ncmds);
    
    for (uint32_t i = 0; i < commandCount; i++) {
        const struct load_command* loadCommand = (const struct load_command*)(buffer + offset);
        uint32_t commandSize = swap32(loadCommand->cmdsize);
        
        uint32_t commandType = swap32(loadCommand->cmd);
        if (commandType == LC_CODE_SIGNATURE) {
            const struct linkedit_data_command* dataCommand = (const struct linkedit_data_command*)(buffer + offset);
            uint32_t dataOffset = swap32(dataCommand->dataoff);
            uint32_t dataSize = swap32(dataCommand->datasize);
            
            return parseSignature(buffer + dataOffset, dataSize);
        }
        
        offset += commandSize;
    }
    
    return nil;
}

static MTPKCS * _Nullable parseFat(const char *buffer, size_t size) {
    size_t offset = 0;
    
    const struct fat_header* fatHeader = (const struct fat_header*)(buffer + offset);
    offset += sizeof(*fatHeader);
    
    uint32_t archCount = OSSwapBigToHostInt32(fatHeader->nfat_arch);
    
    for (uint32_t i = 0; i < archCount; i++) {
        const struct fat_arch* arch = (const struct fat_arch*)(buffer + offset);
        offset += sizeof(*arch);
        
        uint32_t archOffset = OSSwapBigToHostInt32(arch->offset);
        uint32_t archSize = OSSwapBigToHostInt32(arch->size);
        
        MTPKCS *result = parseArch(buffer + archOffset, archSize);
        if (result != nil) {
            return result;
        }
    }
    
    return nil;
}

static MTPKCS * _Nullable parseMachO(const char* buffer, size_t size) {
    const uint32_t* magic = (const uint32_t*)buffer;
    
    if (*magic == FAT_CIGAM || *magic == FAT_MAGIC) {
        return parseFat(buffer, size);
    } else {
        return parseArch(buffer, size);
    }
}

static MTPKCS * _Nullable checkSignature(const char *filename) {
    char *buffer = NULL;
    
    int fd = open(filename, O_RDONLY);
    
    if (fd == -1) {
        return nil;
    }
    
    struct stat st;
    fstat(fd, &st);
    
    buffer = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_FILE|MAP_PRIVATE, fd, 0);
    
    if (buffer == MAP_FAILED) {
        if (buffer) {
            munmap(buffer, (size_t)st.st_size);
        }
        if (fd != -1) {
            close(fd);
        }
        return nil;
    }
    
    MTPKCS *result = parseMachO(buffer, (size_t)st.st_size);
    if (buffer) {
        munmap(buffer, (size_t)st.st_size);
    }
    if (fd != -1) {
        close(fd);
    }
    
    return result;
}

API_AVAILABLE(ios(10))
@interface LocalPrivateKey : NSObject {
    SecKeyRef _privateKey;
    SecKeyRef _publicKey;
}

- (NSData * _Nullable)encrypt:(NSData * _Nonnull)data;
- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data;

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

- (NSData * _Nullable)decrypt:(NSData * _Nonnull)data {
    CFErrorRef error = NULL;
    NSData *plainText = (NSData *)CFBridgingRelease(SecKeyCreateDecryptedData(_privateKey, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM, (__bridge CFDataRef)data, &error));
    
    if (!plainText) {
        __unused NSError *err = CFBridgingRelease(error);
        return nil;
    }
    
    return plainText;
}

@end

@interface BuildConfig () {
    NSData * _Nullable _bundleData;
    int32_t _apiId;
    NSString * _Nonnull _apiHash;
    NSString * _Nullable _hockeyAppId;
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
        _hockeyAppId = @(APP_CONFIG_HOCKEYAPP_ID);
        
        MTPKCS *signature = checkSignature([[[NSBundle mainBundle] executablePath] UTF8String]);
        _dataDict = [[NSMutableDictionary alloc] init];
        
        if (baseAppBundleId != nil) {
            _dataDict[@"bundleId"] = baseAppBundleId;
        }
        if (signature.name != nil) {
            _dataDict[@"name"] = signature.name;
        }
        if (signature.data != nil) {
            _dataDict[@"data"] = [MTSha1(signature.data) base64EncodedStringWithOptions:0];
        }
    }
    return self;
}

- (NSData * _Nullable)bundleDataWithAppToken:(NSData * _Nullable)appToken {
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] initWithDictionary:_dataDict];
    if (appToken != nil) {
        dataDict[@"device_token"] = [appToken base64EncodedStringWithOptions:0];
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

- (NSString * _Nullable)hockeyAppId {
    return _hockeyAppId;
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

+ (LocalPrivateKey * _Nullable)getLocalPrivateKey:(NSString * _Nonnull)baseAppBundleId API_AVAILABLE(ios(10)) {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    NSData *applicationTag = [@"telegramLocalKey" dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassKey,
        (id)kSecAttrApplicationTag: applicationTag,
        (id)kSecAttrKeyType: (id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrAccessGroup: (id)accessGroup,
        (id)kSecReturnRef: @YES,
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

+ (bool)removeLocalPrivateKey:(NSString * _Nonnull)baseAppBundleId API_AVAILABLE(ios(10)) {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [@"telegramLocalKey" dataUsingEncoding:NSUTF8StringEncoding];
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

+ (LocalPrivateKey * _Nullable)addLocalPrivateKey:(NSString * _Nonnull)baseAppBundleId API_AVAILABLE(ios(10)) {
    NSString *bundleSeedId = [self bundleSeedId];
    if (bundleSeedId == nil) {
        return nil;
    }
    
    NSData *applicationTag = [@"telegramLocalKey" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *accessGroup = [bundleSeedId stringByAppendingFormat:@".%@", baseAppBundleId];
    
    SecAccessControlRef access = SecAccessControlCreateWithFlags(kCFAllocatorDefault, kSecAttrAccessibleAlwaysThisDeviceOnly, kSecAccessControlPrivateKeyUsage, NULL);
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
    NSString *encryptedPath = [rootPath stringByAppendingPathComponent:@".tempkeyEncrypted"];
    
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

@end
