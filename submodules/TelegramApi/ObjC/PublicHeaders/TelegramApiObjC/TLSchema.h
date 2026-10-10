#import <TelegramApiObjC/TLEngine.h>

NS_ASSUME_NONNULL_BEGIN

/// Outcome of decoding the compressed schema table. Anything but Ok means a corrupt binary:
/// TLApiSchemaTable() aborts on it, tests assert on it.
typedef NS_CLOSED_ENUM(int32_t, TLSchemaDecodeResult) {
    TLSchemaDecodeResultOk = 0,
    TLSchemaDecodeResultInflateFailed = 1,
    TLSchemaDecodeResultTruncated = 2,
    TLSchemaDecodeResultBadMagic = 3,
    TLSchemaDecodeResultBadVersion = 4,
    TLSchemaDecodeResultLengthMismatch = 7,
    TLSchemaDecodeResultStringOutOfRange = 8,
    TLSchemaDecodeResultInvalidRecord = 9,
    TLSchemaDecodeResultNotSorted = 10,
    TLSchemaDecodeResultOutOfMemory = 11,
};

/// A decoded table: today's structs on the heap, strings pointing into `pool` (a copy of the
/// image's string pool, which the table owns; the record sections are not kept).
typedef struct TLSchemaTable {
    char *_Nullable pool;
    size_t poolLength;
    TLTypeInfo *_Nullable types;
    uint32_t typeCount;
    TLConstructorInfo *_Nullable constructors;   // ascending constructor id: TLApiConstructorAt order
    uint32_t constructorCount;
    TLFunctionInfo *_Nullable functions;
    uint32_t functionCount;
    TLFieldInfo *_Nullable fields;
    const TLConstructorInfo *_Nonnull *_Nullable typeConstructors;
    TLConstructorState *_Nullable states;
    size_t heapBytes;                             // all of the above, including the pool
} TLSchemaTable;

enum {
    TLSchemaImageHeaderSize = 72,
    TLSchemaMaxImageLength = 16 * 1024 * 1024,
};

/// Inflates a zlib stream into a malloc'd image (caller frees). Fails beyond TLSchemaMaxImageLength.
TLSchemaDecodeResult TLSchemaInflate(const uint8_t *compressed, size_t compressedLength, uint8_t *_Nullable *_Nonnull image, size_t *imageLength);
/// Validates `image` and builds `table` from it (the table copies what it keeps). On failure `table` is left empty.
TLSchemaDecodeResult TLSchemaDecodeImage(const uint8_t *image, size_t imageLength, TLSchemaTable *table);
TLSchemaDecodeResult TLSchemaDecode(const uint8_t *compressed, size_t compressedLength, TLSchemaTable *table);
void TLSchemaTableFree(TLSchemaTable *table);

/// The app's table, decoded from TLApiSchemaCompressed on first call; aborts if it is corrupt.
const TLSchemaTable *TLApiSchemaTable(void);
/// How many times this process decoded the app's table (exactly 1 once used).
uint32_t TLApiSchemaLoadCount(void);
const uint8_t *TLApiSchemaCompressedBytes(void);
size_t TLApiSchemaCompressedByteCount(void);

NS_ASSUME_NONNULL_END
