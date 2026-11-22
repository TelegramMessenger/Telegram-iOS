#import <TelegramApiObjC/TelegramApiObjC.h>
#import "TLObjectInternal.h"

#include <stdlib.h>
#include <string.h>

#if __has_feature(objc_arc)
#error "TelegramApiObjC must be compiled without ARC"
#endif

NS_ASSUME_NONNULL_BEGIN

static const int32_t TLVectorConstructorId = 481674261;

// Ids Api.parse handles as primitives (int, long, double, int256, string/bytes). In an object
// position they fail the field silently, as the Swift `as? Api.X` cast did.
static bool TLIsBuiltinId(int32_t constructorId) {
    switch (constructorId) {
        case -1471112230:
        case 570911930:
        case 571523412:
        case 0x0929C32F:
        case -1255641564:
            return true;
        default:
            return false;
    }
}

static void (*_Nullable TLUnknownConstructorHandler)(int32_t) = NULL;

void TLSetUnknownConstructorHandler(void (*_Nullable handler)(int32_t constructorId)) {
    TLUnknownConstructorHandler = handler;
}

static bool TLKindIsScalar(TLFieldKind kind) {
    return kind == TLFieldKindInt32 || kind == TLFieldKindInt64 || kind == TLFieldKindInt256 || kind == TLFieldKindDouble;
}

static const TLConstructorInfo *_Nullable TLLookupConstructor(int32_t constructorId) {
    return TLApiConstructorWithId(constructorId);
}

// MARK: - Reading (mirrors BufferReader / parseBytes, including where it stops on failure:
// ParseFailureTests pins that against the Swift parser's literal behaviour)

static bool TLReadRaw(TLReader *reader, void *out, size_t count) {
    if (reader->offset + count > reader->length) {
        return false;
    }
    memcpy(out, reader->bytes + reader->offset, count);
    reader->offset += count;
    return true;
}

static bool TLReadInt32(TLReader *reader, int32_t *out) {
    return TLReadRaw(reader, out, 4);
}

static bool TLReadInt64(TLReader *reader, int64_t *out) {
    return TLReadRaw(reader, out, 8);
}

static bool TLReadDouble(TLReader *reader, double *out) {
    return TLReadRaw(reader, out, 8);
}

static size_t TLRoundUp4(size_t value) {
    return (value % 4) == 0 ? value : value + 4 - (value % 4);
}

static bool TLReadBytesRange(TLReader *reader, const uint8_t *_Nullable *_Nonnull start, size_t *length) {
    uint8_t first = 0;
    if (!TLReadRaw(reader, &first, 1)) {
        return false;
    }
    size_t count;
    size_t padding;
    if (first == 254) {
        uint8_t lengthBytes[3];
        if (!TLReadRaw(reader, lengthBytes, 3)) {
            return false;
        }
        count = (size_t)lengthBytes[0] | ((size_t)lengthBytes[1] << 8) | ((size_t)lengthBytes[2] << 16);
        padding = TLRoundUp4(count) - count;
    } else {
        count = first;
        padding = TLRoundUp4(count + 1) - (count + 1);
    }
    if (reader->offset + count > reader->length) {
        // parseBytes skipped the padding even when readBuffer failed; the next field (and
        // the constructor id it may log) is read from there.
        reader->offset = MIN(reader->length, reader->offset + padding);
        return false;
    }
    *start = reader->bytes + reader->offset;
    *length = count;
    reader->offset += count;
    reader->offset = MIN(reader->length, reader->offset + padding);
    return true;
}

static NSString *_Nullable TLReadString(TLReader *reader) NS_RETURNS_RETAINED {
    const uint8_t *start = NULL;
    size_t length = 0;
    if (!TLReadBytesRange(reader, &start, &length)) {
        return nil;
    }
    NSString *string = [[NSString alloc] initWithBytes:start length:length encoding:NSUTF8StringEncoding];
    return string != nil ? string : [[NSString alloc] init];
}

static NSData *_Nullable TLReadData(TLReader *reader) NS_RETURNS_RETAINED {
    const uint8_t *start = NULL;
    size_t length = 0;
    if (!TLReadBytesRange(reader, &start, &length)) {
        return nil;
    }
    return [[NSData alloc] initWithBytes:start length:length];
}

// A primitive's id in an object position: Api.parse read the primitive before the
// `as? Api.X` cast failed, so consume its value the same way (each read independently, as
// the Swift readers did) and let the next field start where the Swift parser's did.
static void TLSkipBuiltinValue(TLReader *reader, int32_t constructorId) {
    switch (constructorId) {
        case -1471112230: {
            int32_t value;
            TLReadInt32(reader, &value);
            break;
        }
        case 570911930:
        case 571523412: {
            int64_t value;
            TLReadInt64(reader, &value);
            break;
        }
        case 0x0929C32F: {
            int64_t value;
            for (int i = 0; i < 4; i++) {
                TLReadInt64(reader, &value);
            }
            break;
        }
        case -1255641564: {
            const uint8_t *start = NULL;
            size_t length = 0;
            TLReadBytesRange(reader, &start, &length);
            break;
        }
        default:
            break;
    }
}

static TLObject *_Nullable TLParseBody(TLReader *reader, const TLConstructorInfo *info) NS_RETURNS_RETAINED;

static const TLConstructorInfo *TLBareConstructorInfo(uint16_t typeIndex, uint16_t constructorIndex) {
    return TLApiTypeAt(typeIndex)->constructors[constructorIndex];
}

static TLObject *_Nullable TLParseObjectValue(TLReader *reader, uint16_t typeIndex, bool bare, uint16_t constructorIndex) NS_RETURNS_RETAINED {
    if (bare) {
        return TLParseBody(reader, TLBareConstructorInfo(typeIndex, constructorIndex));
    }
    int32_t constructorId = 0;
    if (!TLReadInt32(reader, &constructorId)) {
        return nil;
    }
    return TLParseConstructor(reader, constructorId, typeIndex);
}

static id _Nullable TLParseVector(TLReader *reader, TLFieldKind elementKind, bool boxed, uint16_t typeIndex, bool bareElements, uint16_t constructorIndex) NS_RETURNS_RETAINED {
    int32_t ignoredVectorId = 0;
    if (boxed && !TLReadInt32(reader, &ignoredVectorId)) {
        return nil;
    }
    int32_t count = 0;
    if (!TLReadInt32(reader, &count)) {
        return nil;
    }
    switch (elementKind) {
        case TLFieldKindInt32: {
            NSMutableData *data = [[NSMutableData alloc] init];
            for (int32_t i = 0; i < count; i++) {
                int32_t value = 0;
                if (!TLReadInt32(reader, &value)) {
                    [data release];
                    return nil;
                }
                [data appendBytes:&value length:4];
            }
            return data;
        }
        case TLFieldKindInt64: {
            NSMutableData *data = [[NSMutableData alloc] init];
            for (int32_t i = 0; i < count; i++) {
                int64_t value = 0;
                if (!TLReadInt64(reader, &value)) {
                    [data release];
                    return nil;
                }
                [data appendBytes:&value length:8];
            }
            return data;
        }
        case TLFieldKindString:
        case TLFieldKindBytes:
        case TLFieldKindObject: {
            NSMutableArray *array = [[NSMutableArray alloc] init];
            for (int32_t i = 0; i < count; i++) {
                id element;
                if (elementKind == TLFieldKindString) {
                    element = TLReadString(reader);
                } else if (elementKind == TLFieldKindBytes) {
                    element = TLReadData(reader);
                } else {
                    element = TLParseObjectValue(reader, typeIndex, bareElements, constructorIndex);
                }
                if (element == nil) {
                    [array release];
                    return nil;
                }
                [array addObject:element];
                [element release];
            }
            return array;
        }
        case TLFieldKindInt256:
        case TLFieldKindDouble:
        case TLFieldKindVector:
            return nil;
    }
    return nil;
}

// Fields are all attempted even after one fails (as the generated Swift did), so nested
// unknown ids later in a failing constructor are still reported.
static bool TLParseField(TLReader *reader, const TLFieldInfo *field, char *slot) {
    switch (field->kind) {
        case TLFieldKindInt32:
            return TLReadInt32(reader, (int32_t *)slot);
        case TLFieldKindInt64:
            return TLReadInt64(reader, (int64_t *)slot);
        case TLFieldKindDouble:
            return TLReadDouble(reader, (double *)slot);
        case TLFieldKindInt256: {
            TLInt256 value;
            bool ok0 = TLReadInt64(reader, &value._0);
            bool ok1 = TLReadInt64(reader, &value._1);
            bool ok2 = TLReadInt64(reader, &value._2);
            bool ok3 = TLReadInt64(reader, &value._3);
            if (!(ok0 && ok1 && ok2 && ok3)) {
                return false;
            }
            *(TLInt256 *)slot = value;
            return true;
        }
        case TLFieldKindString: {
            NSString *value = TLReadString(reader);
            if (value == nil) {
                return false;
            }
            *(id *)slot = value;
            return true;
        }
        case TLFieldKindBytes: {
            NSData *value = TLReadData(reader);
            if (value == nil) {
                return false;
            }
            *(id *)slot = value;
            return true;
        }
        case TLFieldKindObject: {
            TLObject *value = TLParseObjectValue(reader, field->typeIndex, field->isBareObject != 0, field->constructorIndex);
            if (value == nil) {
                return false;
            }
            *(id *)slot = value;
            return true;
        }
        case TLFieldKindVector: {
            id value = TLParseVector(reader, field->elementKind, field->isBoxedVector != 0, field->typeIndex, field->isBareObject != 0, field->constructorIndex);
            if (value == nil) {
                return false;
            }
            *(id *)slot = value;
            return true;
        }
    }
    return false;
}

static TLObject *_Nullable TLParseBody(TLReader *reader, const TLConstructorInfo *info) {
    if (info->fieldCount == 0) {
        return [(id)TLObjectSingleton(info) retain];
    }
    TLObject *object = TLObjectCreate(info);
    char *base = (char *)object;
    uint64_t present = 0;
    bool ok = true;
    for (uint16_t i = 0; i < info->fieldCount; i++) {
        const TLFieldInfo *field = &info->fields[i];
        if (field->flagsFieldIndex >= 0) {
            uint32_t flags = *(const uint32_t *)(base + info->fields[field->flagsFieldIndex].offset);
            if ((flags & (1u << field->flagBit)) == 0) {
                continue;
            }
        }
        if (!TLParseField(reader, field, base + info->fields[i].offset)) {
            ok = false;
            continue;
        }
        if (field->isOptional && TLKindIsScalar(field->kind)) {
            present |= 1ull << field->presenceBit;
        }
    }
    if (info->presentOffset >= 0) {
        *(uint64_t *)(base + info->presentOffset) = present;
    }
    if (!ok) {
        [(id)object release];
        return nil;
    }
    return object;
}

TLObject *_Nullable TLParseConstructor(TLReader *reader, int32_t constructorId, uint16_t expectedTypeIndex) {
    const TLConstructorInfo *info = TLLookupConstructor(constructorId);
    if (info == NULL) {
        if (TLIsBuiltinId(constructorId)) {
            TLSkipBuiltinValue(reader, constructorId);
        } else if (TLUnknownConstructorHandler != NULL) {
            TLUnknownConstructorHandler(constructorId);
        }
        return nil;
    }
    // Parse fully before the type check, as `Api.parse(…) as? Api.X` did (nested ids are
    // still reported when the outer type turns out to be wrong).
    TLObject *object = TLParseBody(reader, info);
    if (object != nil && expectedTypeIndex != TLAnyTypeIndex && info->typeIndex != expectedTypeIndex) {
        [(id)object release];
        return nil;
    }
    return object;
}

const TLFunctionInfo *TLObjectFunctionInfo(TLObject *object) {
    // `constructor` is the first member of TLFunctionInfo.
    return (const TLFunctionInfo *)object->_tl_info;
}

id _Nullable TLParseFunctionResult(TLReader *reader, const TLFunctionInfo *info) {
    const TLFieldInfo *result = &info->result;
    switch (result->kind) {
        case TLFieldKindObject: {
            int32_t constructorId = 0;
            if (!TLReadInt32(reader, &constructorId)) {
                return nil;
            }
            return TLParseConstructor(reader, constructorId, result->typeIndex);
        }
        case TLFieldKindVector:
            return TLParseVector(reader, result->elementKind, result->isBoxedVector != 0, result->typeIndex, result->isBareObject != 0, result->constructorIndex);
        default:
            return nil;
    }
}

// MARK: - Writing (mirrors Buffer.append* / serializeBytes / serializeString)

static void TLWriterReserve(TLWriter *writer, size_t extra) {
    if (writer->length + extra <= writer->capacity) {
        return;
    }
    size_t capacity = writer->capacity == 0 ? 64 : writer->capacity;
    while (capacity < writer->length + extra) {
        capacity *= 2;
    }
    writer->bytes = realloc(writer->bytes, capacity);
    writer->capacity = capacity;
}

static void TLWriteRaw(TLWriter *writer, const void *_Nullable bytes, size_t count) {
    if (count == 0) {
        return;
    }
    TLWriterReserve(writer, count);
    memcpy(writer->bytes + writer->length, bytes, count);
    writer->length += count;
}

static void TLWriteInt32(TLWriter *writer, int32_t value) {
    TLWriteRaw(writer, &value, 4);
}

static void TLWriteBytes(TLWriter *writer, const void *_Nullable bytes, size_t count) {
    static const uint8_t zeros[4] = { 0, 0, 0, 0 };
    size_t padding;
    if (count >= 254) {
        uint8_t header[4] = { 254, (uint8_t)(count & 0xff), (uint8_t)((count >> 8) & 0xff), (uint8_t)((count >> 16) & 0xff) };
        TLWriteRaw(writer, header, 4);
        padding = TLRoundUp4(count) - count;
    } else {
        uint8_t header = (uint8_t)count;
        TLWriteRaw(writer, &header, 1);
        padding = TLRoundUp4(count + 1) - (count + 1);
    }
    TLWriteRaw(writer, bytes, count);
    TLWriteRaw(writer, zeros, padding);
}

// UTF-16 -> UTF-8 with U+FFFD for every unpaired surrogate: what Swift's
// `data(using: .utf8, allowLossyConversion: true)` produced. Foundation's lossy conversion
// returns nil for such a string instead, which would send the field empty.
static NSData *TLUTF8DataReplacingUnpairedSurrogates(NSString *string) {
    NSUInteger length = string.length;
    unichar *characters = malloc(MAX(length, 1) * sizeof(unichar));
    [string getCharacters:characters range:NSMakeRange(0, length)];
    NSMutableData *data = [NSMutableData dataWithCapacity:length * 3];
    for (NSUInteger i = 0; i < length; i++) {
        uint32_t scalar = characters[i];
        if (scalar >= 0xD800 && scalar <= 0xDBFF && i + 1 < length && characters[i + 1] >= 0xDC00 && characters[i + 1] <= 0xDFFF) {
            scalar = 0x10000 + ((scalar - 0xD800) << 10) + (characters[i + 1] - 0xDC00);
            i++;
        } else if (scalar >= 0xD800 && scalar <= 0xDFFF) {
            scalar = 0xFFFD;
        }
        uint8_t bytes[4];
        size_t count;
        if (scalar < 0x80) {
            bytes[0] = (uint8_t)scalar;
            count = 1;
        } else if (scalar < 0x800) {
            bytes[0] = (uint8_t)(0xC0 | (scalar >> 6));
            bytes[1] = (uint8_t)(0x80 | (scalar & 0x3F));
            count = 2;
        } else if (scalar < 0x10000) {
            bytes[0] = (uint8_t)(0xE0 | (scalar >> 12));
            bytes[1] = (uint8_t)(0x80 | ((scalar >> 6) & 0x3F));
            bytes[2] = (uint8_t)(0x80 | (scalar & 0x3F));
            count = 3;
        } else {
            bytes[0] = (uint8_t)(0xF0 | (scalar >> 18));
            bytes[1] = (uint8_t)(0x80 | ((scalar >> 12) & 0x3F));
            bytes[2] = (uint8_t)(0x80 | ((scalar >> 6) & 0x3F));
            bytes[3] = (uint8_t)(0x80 | (scalar & 0x3F));
            count = 4;
        }
        [data appendBytes:bytes length:count];
    }
    free(characters);
    return data;
}

static void TLWriteString(TLWriter *writer, NSString *string) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    if (data == nil && string.length != 0) {
        data = TLUTF8DataReplacingUnpairedSurrogates(string);
    }
    TLWriteBytes(writer, data.bytes, data.length);
}

static void TLWriteObjectValue(TLWriter *writer, TLObject *object, bool bare) {
    TLSerialize(object, writer, !bare);
}

static void TLWriteVector(TLWriter *writer, const TLFieldInfo *field, id value) {
    if (field->isBoxedVector) {
        TLWriteInt32(writer, TLVectorConstructorId);
    }
    switch (field->elementKind) {
        case TLFieldKindInt32:
        case TLFieldKindInt64: {
            NSData *data = value;
            size_t width = field->elementKind == TLFieldKindInt32 ? 4 : 8;
            TLWriteInt32(writer, (int32_t)(data.length / width));
            TLWriteRaw(writer, data.bytes, data.length);
            break;
        }
        case TLFieldKindString:
        case TLFieldKindBytes:
        case TLFieldKindObject: {
            NSArray *array = value;
            TLWriteInt32(writer, (int32_t)array.count);
            for (id element in array) {
                if (field->elementKind == TLFieldKindString) {
                    TLWriteString(writer, element);
                } else if (field->elementKind == TLFieldKindBytes) {
                    TLWriteBytes(writer, [(NSData *)element bytes], [(NSData *)element length]);
                } else {
                    TLWriteObjectValue(writer, element, field->isBareObject != 0);
                }
            }
            break;
        }
        case TLFieldKindInt256:
        case TLFieldKindDouble:
        case TLFieldKindVector:
            break;
    }
}

static void TLAbortMissingField(const TLConstructorInfo *info, const TLFieldInfo *field) __attribute__((noreturn));
static void TLAbortMissingField(const TLConstructorInfo *info, const TLFieldInfo *field) {
    fprintf(stderr, "TelegramApi: %s.%s has its flag bit set but no value\n", info->name, field->name);
    abort();
}

void TLSerialize(TLObject *object, TLWriter *writer, bool boxed) {
    const TLConstructorInfo *info = object->_tl_info;
    if (boxed) {
        TLWriteInt32(writer, (int32_t)info->constructorId);
    }
    if (info->fieldCount == 0) {
        return;
    }
    const char *base = (const char *)object;
    uint64_t present = info->presentOffset >= 0 ? *(const uint64_t *)(base + info->presentOffset) : 0;
    for (uint16_t i = 0; i < info->fieldCount; i++) {
        const TLFieldInfo *field = &info->fields[i];
        const char *slot = base + info->fields[i].offset;
        if (field->flagsFieldIndex >= 0) {
            uint32_t flags = *(const uint32_t *)(base + info->fields[field->flagsFieldIndex].offset);
            if ((flags & (1u << field->flagBit)) == 0) {
                continue;
            }
            bool isPresent = TLKindIsScalar(field->kind) ? (present & (1ull << field->presenceBit)) != 0 : *(id const *)slot != nil;
            if (!isPresent) {
                TLAbortMissingField(info, field);
            }
        }
        switch (field->kind) {
            case TLFieldKindInt32:
                TLWriteRaw(writer, slot, 4);
                break;
            case TLFieldKindInt64:
            case TLFieldKindDouble:
                TLWriteRaw(writer, slot, 8);
                break;
            case TLFieldKindInt256:
                TLWriteRaw(writer, slot, 32);
                break;
            case TLFieldKindString:
                TLWriteString(writer, *(NSString *const *)slot);
                break;
            case TLFieldKindBytes: {
                NSData *data = *(NSData *const *)slot;
                TLWriteBytes(writer, data.bytes, data.length);
                break;
            }
            case TLFieldKindObject:
                TLWriteObjectValue(writer, *(TLObject *const *)slot, field->isBareObject != 0);
                break;
            case TLFieldKindVector:
                TLWriteVector(writer, field, *(id const *)slot);
                break;
        }
    }
}

void TLWriterFree(TLWriter *writer) {
    free(writer->bytes);
    writer->bytes = NULL;
    writer->length = 0;
    writer->capacity = 0;
}

NS_ASSUME_NONNULL_END
