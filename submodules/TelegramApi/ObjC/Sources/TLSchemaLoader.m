#import <TelegramApiObjC/TelegramApiObjC.h>

#include <dispatch/dispatch.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#if __has_feature(objc_arc)
#error "TelegramApiObjC must be compiled without ARC"
#endif

_Static_assert(__LITTLE_ENDIAN__, "the schema image is little-endian");

NS_ASSUME_NONNULL_BEGIN

enum {
    TLSchemaMagic = 0x31534C54,
    TLSchemaVersion = 3,
    TLSchemaTypeRecordSize = 12,
    TLSchemaTypeConstructorRecordSize = 4,
    TLSchemaConstructorRecordSize = 28,
    TLSchemaFieldRecordSize = 20,
    TLSchemaFunctionRecordSize = 28,
    TLSchemaObjectHeaderSize = 24,
    TLSchemaMaxInstanceSize = 65536,
};

// Every multi-byte read goes through memcpy: records are packed, not aligned for their members.
static uint16_t TLImage16(const uint8_t *image, size_t offset) {
    uint16_t value;
    memcpy(&value, image + offset, sizeof(value));
    return value;
}

static uint32_t TLImage32(const uint8_t *image, size_t offset) {
    uint32_t value;
    memcpy(&value, image + offset, sizeof(value));
    return value;
}

static bool TLSectionFits(uint32_t offset, uint32_t count, uint32_t recordSize, size_t imageLength) {
    return (uint64_t)offset + (uint64_t)count * recordSize <= imageLength;
}

TLSchemaDecodeResult TLSchemaInflate(const uint8_t *compressed, size_t compressedLength, uint8_t *_Nullable *_Nonnull image, size_t *imageLength) {
    *image = NULL;
    *imageLength = 0;
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit(&stream) != Z_OK) {
        return TLSchemaDecodeResultOutOfMemory;
    }
    size_t capacity = MIN((size_t)TLSchemaMaxImageLength, compressedLength * 8 + 4096);
    uint8_t *buffer = malloc(capacity);
    if (buffer == NULL) {
        inflateEnd(&stream);
        return TLSchemaDecodeResultOutOfMemory;
    }
    stream.next_in = (Bytef *)compressed;
    stream.avail_in = (uInt)compressedLength;
    size_t length = 0;
    int status = Z_OK;
    for (;;) {
        if (length == capacity) {
            if (capacity >= TLSchemaMaxImageLength) {
                status = Z_DATA_ERROR;
                break;
            }
            size_t grown = MIN(capacity * 2, (size_t)TLSchemaMaxImageLength);
            uint8_t *resized = realloc(buffer, grown);
            if (resized == NULL) {
                free(buffer);
                inflateEnd(&stream);
                return TLSchemaDecodeResultOutOfMemory;
            }
            buffer = resized;
            capacity = grown;
        }
        stream.next_out = buffer + length;
        stream.avail_out = (uInt)(capacity - length);
        status = inflate(&stream, Z_NO_FLUSH);
        length = capacity - stream.avail_out;
        if (status != Z_OK) {
            break;
        }
    }
    inflateEnd(&stream);
    if (status != Z_STREAM_END) {
        free(buffer);
        return TLSchemaDecodeResultInflateFailed;
    }
    *image = buffer;
    *imageLength = length;
    return TLSchemaDecodeResultOk;
}

void TLSchemaTableFree(TLSchemaTable *table) {
    free(table->pool);
    free(table->types);
    free(table->constructors);
    free(table->functions);
    free(table->fields);
    free((void *)table->typeConstructors);
    free(table->states);
    memset(table, 0, sizeof(*table));
}

static bool TLFieldsAreConsistent(const TLFieldInfo *fields, uint16_t count) {
    for (uint16_t i = 0; i < count; i++) {
        if (fields[i].flagsFieldIndex < -1 || fields[i].flagsFieldIndex >= (int)count) {
            return false;
        }
    }
    return true;
}

static uint32_t TLFieldStorageSize(TLFieldKind kind) {
    switch (kind) {
        case TLFieldKindInt32:
            return 4;
        case TLFieldKindInt256:
            return 32;
        default:
            return 8;
    }
}

// Every field and the presence mask lie inside the object's storage, past the header.
static bool TLStorageIsConsistent(const TLFieldInfo *fields, uint16_t count, uint32_t instanceSize, int32_t presentOffset) {
    if (instanceSize < TLSchemaObjectHeaderSize || instanceSize % 8 != 0 || instanceSize > TLSchemaMaxInstanceSize) {
        return false;
    }
    for (uint16_t i = 0; i < count; i++) {
        if (fields[i].offset < TLSchemaObjectHeaderSize || (uint64_t)fields[i].offset + TLFieldStorageSize(fields[i].kind) > instanceSize) {
            return false;
        }
    }
    return presentOffset == -1 || (presentOffset >= TLSchemaObjectHeaderSize && (uint64_t)presentOffset + 8 <= instanceSize);
}

static TLSchemaDecodeResult TLSchemaFill(const uint8_t *image, const char *pool, TLSchemaTable *table, uint32_t fieldCount, uint32_t typeConstructorCount,
                                         uint32_t poolLength, uint32_t typesOffset, uint32_t typeConstructorsOffset,
                                         uint32_t constructorsOffset, uint32_t fieldsOffset, uint32_t functionsOffset) {
    for (uint32_t i = 0; i < fieldCount; i++) {
        size_t o = fieldsOffset + (size_t)i * TLSchemaFieldRecordSize;
        uint32_t name = TLImage32(image, o);
        if (name >= poolLength) {
            return TLSchemaDecodeResultStringOutOfRange;
        }
        uint8_t kind = image[o + 4];
        uint8_t elementKind = image[o + 5];
        uint16_t typeIndex = TLImage16(image, o + 12);
        if (kind > TLFieldKindVector || elementKind > TLFieldKindVector || (typeIndex >= table->typeCount && typeIndex != TLAnyTypeIndex)) {
            return TLSchemaDecodeResultInvalidRecord;
        }
        TLFieldInfo *field = &table->fields[i];
        field->name = pool + name;
        field->kind = kind;
        field->elementKind = elementKind;
        field->isOptional = image[o + 6];
        field->isBoxedVector = image[o + 7];
        field->isBareObject = image[o + 8];
        field->flagsFieldIndex = (int8_t)image[o + 9];
        field->flagBit = image[o + 10];
        field->presenceBit = image[o + 11];
        field->typeIndex = typeIndex;
        field->constructorIndex = TLImage16(image, o + 14);
        field->offset = TLImage32(image, o + 16);
    }

    uint32_t previousId = 0;
    for (uint32_t i = 0; i < table->constructorCount; i++) {
        size_t o = constructorsOffset + (size_t)i * TLSchemaConstructorRecordSize;
        uint32_t name = TLImage32(image, o);
        uint32_t constructorId = TLImage32(image, o + 4);
        uint16_t typeIndex = TLImage16(image, o + 8);
        uint32_t firstField = TLImage32(image, o + 12);
        uint16_t count = TLImage16(image, o + 16);
        uint32_t instanceSize = TLImage32(image, o + 20);
        int32_t presentOffset = (int32_t)TLImage32(image, o + 24);
        if (name >= poolLength) {
            return TLSchemaDecodeResultStringOutOfRange;
        }
        if (typeIndex >= table->typeCount || (uint64_t)firstField + count > fieldCount || !TLFieldsAreConsistent(table->fields + firstField, count) ||
            !TLStorageIsConsistent(table->fields + firstField, count, instanceSize, presentOffset)) {
            return TLSchemaDecodeResultInvalidRecord;
        }
        if (i > 0 && constructorId <= previousId) {
            return TLSchemaDecodeResultNotSorted;
        }
        previousId = constructorId;
        TLConstructorInfo *info = &table->constructors[i];
        info->name = pool + name;
        info->constructorId = constructorId;
        info->typeIndex = typeIndex;
        info->caseIndex = TLImage16(image, o + 10);
        info->fieldCount = count;
        info->instanceSize = instanceSize;
        info->presentOffset = presentOffset;
        info->fields = count > 0 ? table->fields + firstField : NULL;
        info->state = &table->states[i];
    }

    for (uint32_t i = 0; i < table->typeCount; i++) {
        size_t o = typesOffset + (size_t)i * TLSchemaTypeRecordSize;
        uint32_t name = TLImage32(image, o);
        uint32_t first = TLImage32(image, o + 4);
        uint32_t count = TLImage32(image, o + 8);
        if (name >= poolLength) {
            return TLSchemaDecodeResultStringOutOfRange;
        }
        if ((uint64_t)first + count > typeConstructorCount || count > UINT16_MAX) {
            return TLSchemaDecodeResultInvalidRecord;
        }
        for (uint32_t k = 0; k < count; k++) {
            uint32_t index = TLImage32(image, typeConstructorsOffset + (size_t)(first + k) * TLSchemaTypeConstructorRecordSize);
            if (index >= table->constructorCount) {
                return TLSchemaDecodeResultInvalidRecord;
            }
            const TLConstructorInfo *info = &table->constructors[index];
            if (info->typeIndex != i || info->caseIndex != k) {
                return TLSchemaDecodeResultInvalidRecord;
            }
            table->typeConstructors[first + k] = info;
        }
        table->types[i].name = pool + name;
        table->types[i].constructorCount = (uint16_t)count;
        table->types[i].constructors = table->typeConstructors + first;
    }

    for (uint32_t i = 0; i < fieldCount; i++) {
        const TLFieldInfo *field = &table->fields[i];
        if (field->isBareObject && (field->typeIndex >= table->typeCount || field->constructorIndex >= table->types[field->typeIndex].constructorCount)) {
            return TLSchemaDecodeResultInvalidRecord;
        }
    }

    for (uint32_t i = 0; i < table->functionCount; i++) {
        size_t o = functionsOffset + (size_t)i * TLSchemaFunctionRecordSize;
        uint32_t name = TLImage32(image, o);
        uint32_t firstField = TLImage32(image, o + 8);
        uint16_t count = TLImage16(image, o + 12);
        uint32_t result = TLImage32(image, o + 16);
        uint32_t instanceSize = TLImage32(image, o + 20);
        int32_t presentOffset = (int32_t)TLImage32(image, o + 24);
        if (name >= poolLength) {
            return TLSchemaDecodeResultStringOutOfRange;
        }
        if ((uint64_t)firstField + count > fieldCount || result >= fieldCount || !TLFieldsAreConsistent(table->fields + firstField, count) ||
            !TLStorageIsConsistent(table->fields + firstField, count, instanceSize, presentOffset)) {
            return TLSchemaDecodeResultInvalidRecord;
        }
        TLFunctionInfo *function = &table->functions[i];
        function->constructor.name = pool + name;
        function->constructor.constructorId = TLImage32(image, o + 4);
        function->constructor.typeIndex = TLAnyTypeIndex;
        function->constructor.caseIndex = 0;
        function->constructor.fieldCount = count;
        function->constructor.instanceSize = instanceSize;
        function->constructor.presentOffset = presentOffset;
        function->constructor.fields = count > 0 ? table->fields + firstField : NULL;
        function->constructor.state = &table->states[table->constructorCount + i];
        function->result = table->fields[result];
    }
    return TLSchemaDecodeResultOk;
}

TLSchemaDecodeResult TLSchemaDecodeImage(const uint8_t *image, size_t imageLength, TLSchemaTable *table) {
    memset(table, 0, sizeof(*table));
    if (imageLength < TLSchemaImageHeaderSize) {
        return TLSchemaDecodeResultTruncated;
    }
    if (TLImage32(image, 0) != TLSchemaMagic) {
        return TLSchemaDecodeResultBadMagic;
    }
    if (TLImage32(image, 4) != TLSchemaVersion) {
        return TLSchemaDecodeResultBadVersion;
    }
    uint32_t typeCount = TLImage32(image, 20);
    uint32_t constructorCount = TLImage32(image, 24);
    uint32_t functionCount = TLImage32(image, 28);
    if (TLImage32(image, 16) != imageLength) {
        return TLSchemaDecodeResultLengthMismatch;
    }
    uint32_t fieldCount = TLImage32(image, 32);
    uint32_t typeConstructorCount = TLImage32(image, 36);
    uint32_t poolOffset = TLImage32(image, 40);
    uint32_t poolLength = TLImage32(image, 44);
    uint32_t typesOffset = TLImage32(image, 48);
    uint32_t typeConstructorsOffset = TLImage32(image, 52);
    uint32_t constructorsOffset = TLImage32(image, 56);
    uint32_t fieldsOffset = TLImage32(image, 60);
    uint32_t functionsOffset = TLImage32(image, 64);
    if (!TLSectionFits(typesOffset, typeCount, TLSchemaTypeRecordSize, imageLength) ||
        !TLSectionFits(typeConstructorsOffset, typeConstructorCount, TLSchemaTypeConstructorRecordSize, imageLength) ||
        !TLSectionFits(constructorsOffset, constructorCount, TLSchemaConstructorRecordSize, imageLength) ||
        !TLSectionFits(fieldsOffset, fieldCount, TLSchemaFieldRecordSize, imageLength) ||
        !TLSectionFits(functionsOffset, functionCount, TLSchemaFunctionRecordSize, imageLength) ||
        !TLSectionFits(poolOffset, poolLength, 1, imageLength)) {
        return TLSchemaDecodeResultTruncated;
    }
    if (poolLength == 0 || image[poolOffset + poolLength - 1] != 0) {
        return TLSchemaDecodeResultStringOutOfRange;
    }

    table->pool = malloc(poolLength);
    table->fields = calloc(MAX(fieldCount, 1u), sizeof(TLFieldInfo));
    table->constructors = calloc(MAX(constructorCount, 1u), sizeof(TLConstructorInfo));
    table->functions = calloc(MAX(functionCount, 1u), sizeof(TLFunctionInfo));
    table->states = calloc(MAX(constructorCount + functionCount, 1u), sizeof(TLConstructorState));
    table->types = calloc(MAX(typeCount, 1u), sizeof(TLTypeInfo));
    table->typeConstructors = calloc(MAX(typeConstructorCount, 1u), sizeof(TLConstructorInfo *));
    if (table->pool == NULL || table->fields == NULL || table->constructors == NULL ||
        table->functions == NULL || table->states == NULL || table->types == NULL || table->typeConstructors == NULL) {
        TLSchemaTableFree(table);
        return TLSchemaDecodeResultOutOfMemory;
    }
    memcpy(table->pool, image + poolOffset, poolLength);
    table->poolLength = poolLength;
    table->typeCount = typeCount;
    table->constructorCount = constructorCount;
    table->functionCount = functionCount;
    table->heapBytes = poolLength + fieldCount * sizeof(TLFieldInfo) + constructorCount * sizeof(TLConstructorInfo) +
        functionCount * sizeof(TLFunctionInfo) + (constructorCount + functionCount) * sizeof(TLConstructorState) +
        typeCount * sizeof(TLTypeInfo) + typeConstructorCount * sizeof(TLConstructorInfo *);

    TLSchemaDecodeResult result = TLSchemaFill(image, table->pool, table, fieldCount, typeConstructorCount, poolLength, typesOffset,
                                               typeConstructorsOffset, constructorsOffset, fieldsOffset, functionsOffset);
    if (result != TLSchemaDecodeResultOk) {
        TLSchemaTableFree(table);
    }
    return result;
}

TLSchemaDecodeResult TLSchemaDecode(const uint8_t *compressed, size_t compressedLength, TLSchemaTable *table) {
    memset(table, 0, sizeof(*table));
    uint8_t *image = NULL;
    size_t imageLength = 0;
    TLSchemaDecodeResult result = TLSchemaInflate(compressed, compressedLength, &image, &imageLength);
    if (result != TLSchemaDecodeResultOk) {
        return result;
    }
    result = TLSchemaDecodeImage(image, imageLength, table);
    free(image);
    return result;
}

// MARK: - The app's table

static TLSchemaTable TLApiLoadedSchema;
static uint32_t TLApiSchemaLoads = 0;

// Must not call any TLApi*At accessor: they wait on this dispatch_once.
static void TLApiSchemaLoadOnce(void *_Nullable context) {
    (void)context;
    TLSchemaDecodeResult result = TLSchemaDecode(TLApiSchemaCompressed, TLApiSchemaCompressedLength, &TLApiLoadedSchema);
    if (result != TLSchemaDecodeResultOk) {
        fprintf(stderr, "TelegramApi: the compressed schema table does not decode (TLSchemaDecodeResult %d)\n", (int)result);
        abort();
    }
    __atomic_fetch_add(&TLApiSchemaLoads, 1, __ATOMIC_RELAXED);
}

const TLSchemaTable *TLApiSchemaTable(void) {
    static dispatch_once_t once;
    dispatch_once_f(&once, NULL, TLApiSchemaLoadOnce);
    return &TLApiLoadedSchema;
}

uint32_t TLApiSchemaLoadCount(void) {
    return __atomic_load_n(&TLApiSchemaLoads, __ATOMIC_RELAXED);
}

const uint8_t *TLApiSchemaCompressedBytes(void) {
    return TLApiSchemaCompressed;
}

size_t TLApiSchemaCompressedByteCount(void) {
    return TLApiSchemaCompressedLength;
}

// MARK: - Accessors (declared in TLApiTypes.h)

const TLTypeInfo *TLApiTypeAt(uint32_t index) {
    return &TLApiSchemaTable()->types[index];
}

const TLConstructorInfo *TLApiConstructorAt(uint32_t index) {
    return &TLApiSchemaTable()->constructors[index];
}

const TLFunctionInfo *TLApiFunctionAt(uint32_t index) {
    return &TLApiSchemaTable()->functions[index];
}

const TLConstructorInfo *TLApiFunctionConstructorAt(uint32_t index) {
    return &TLApiSchemaTable()->functions[index].constructor;
}

const TLConstructorInfo *_Nullable TLApiConstructorWithId(int32_t constructorId) {
    const TLSchemaTable *table = TLApiSchemaTable();
    uint32_t key = (uint32_t)constructorId;
    uint32_t low = 0;
    uint32_t high = table->constructorCount;
    while (low < high) {
        uint32_t middle = low + (high - low) / 2;
        uint32_t value = table->constructors[middle].constructorId;
        if (value == key) {
            return &table->constructors[middle];
        } else if (value < key) {
            low = middle + 1;
        } else {
            high = middle;
        }
    }
    return NULL;
}

NS_ASSUME_NONNULL_END
