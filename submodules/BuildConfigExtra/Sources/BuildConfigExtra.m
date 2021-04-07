#import <BuildConfigExtra/BuildConfigExtra.h>

#include <mach-o/arch.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>

#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonDigest.h>

#import <PKCS/PKCS.h>

static NSData *sha1(NSData *data) {
    uint8_t digest[20];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    
    return [[NSData alloc] initWithBytes:digest length:20];
}

static NSString *telegramApplicationSecretKey = @"telegramApplicationSecretKey_v3";

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

@implementation BuildConfigExtra

+ (NSDictionary * _Nonnull)signatureDict {
    NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
    MTPKCS *signature = checkSignature([[[NSBundle mainBundle] executablePath] UTF8String]);
    if (signature.issuerName != nil) {
        dataDict[@"issuerName"] = signature.issuerName;
    }
    if (signature.subjectName != nil) {
        dataDict[@"name"] = signature.subjectName;
    }
    if (signature.data != nil) {
        dataDict[@"data"] = [sha1(signature.data) base64EncodedStringWithOptions:0];
        dataDict[@"data1"] = [signature.data base64EncodedStringWithOptions:0];
    }
    return dataDict;
}

@end
