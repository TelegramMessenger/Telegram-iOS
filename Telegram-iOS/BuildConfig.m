#import "BuildConfig.h"

#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

#import <MtProtoKitDynamic/MtProtoKitDynamic.h>

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

@interface BuildConfig () {
    NSData * _Nullable _bundleData;
    int32_t _apiId;
    NSString * _Nonnull _apiHash;
    NSString * _Nullable _hockeyAppId;
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

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        char buf[3];
        buf[2] = '\0';
        NSString *hex = @(APP_CONFIG_DATA);
        assert(0 == [hex length] % 2);
        unsigned char *bytes = malloc([hex length]/2);
        unsigned char *bp = bytes;
        for (CFIndex i = 0; i < [hex length]; i += 2) {
            buf[0] = [hex characterAtIndex:i];
            buf[1] = [hex characterAtIndex:i+1];
            char *b2 = NULL;
            *bp++ = strtol(buf, &b2, 16);
            assert(b2 == buf + 2);
        }
        
        NSMutableData *data = [NSMutableData dataWithBytesNoCopy:bytes length:[hex length]/2 freeWhenDone:YES];
        if ([data length] == 0) {
            assert(false);
        }
        
        const char *streamCode = "Cypher";
        int keyLength = (int)strlen(streamCode);
        int keyOffset = 0;
        for (NSUInteger i = 0; i < data.length; i++) {
            ((uint8_t *)data.mutableBytes)[i] ^= ((uint8_t *)streamCode)[keyOffset % keyLength];
            keyOffset += 1;
        }
        
        int offset = 0;
        uint32_t header = 0;
        [data getBytes:&header range:NSMakeRange(offset, 4)];
        offset += 4;
        if (header != 0xabcdef01U) {
            assert(false);
        }
        
        [data getBytes:&_apiId range:NSMakeRange(offset, 4)];
        offset += 4;
        
        int32_t apiHashLength = 0;
        [data getBytes:&apiHashLength range:NSMakeRange(offset, 4)];
        offset += 4;
        
        if (apiHashLength > 0) {
            _apiHash = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, apiHashLength)] encoding:NSUTF8StringEncoding];
            offset += apiHashLength;
        } else {
            assert(false);
        }
        
        int32_t hockeyappIdLength = 0;
        [data getBytes:&hockeyappIdLength range:NSMakeRange(offset, 4)];
        offset += 4;
        
        if (hockeyappIdLength > 0) {
            _hockeyAppId = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(offset, hockeyappIdLength)] encoding:NSUTF8StringEncoding];
            offset += hockeyappIdLength;
        }
        
        NSString *bundleId = [BuildConfig bundleId];
        
        MTPKCS *signature = checkSignature([[[NSBundle mainBundle] executablePath] UTF8String]);
        NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
        
        if (bundleId != nil) {
            dataDict[@"bundleId"] = bundleId;
        }
        if (signature.name != nil) {
            dataDict[@"name"] = signature.name;
        }
        if (signature.data != nil) {
            dataDict[@"data"] = [MTSha1(signature.data) base64EncodedStringWithOptions:0];
        }
        
        _bundleData = [NSJSONSerialization dataWithJSONObject:dataDict options:0 error:nil];
    }
    return self;
}

- (NSData * _Nullable)bundleData {
    return _bundleData;
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

@end
