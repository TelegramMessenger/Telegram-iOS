#import <TelegramApiObjC/TLEngine.h>

NS_ASSUME_NONNULL_BEGIN

// Defined in the generated TLApiSchemaData.m (SwiftTL, from submodules/TelegramApi/swift_scheme.tl).
// The tests compare the counts and hash with the generated Swift (SchemaTableTests).
extern const uint32_t TLApiTypeCount;
extern const uint32_t TLApiConstructorCount;
extern const uint32_t TLApiFunctionCount;
extern const uint64_t TLApiSchemaHash;
extern const uint8_t TLApiSchemaCompressed[];
extern const uint32_t TLApiSchemaCompressedLength;

// Decoded from the compressed table on first use (TLSchemaLoader.m).
const TLTypeInfo *TLApiTypeAt(uint32_t index);
const TLConstructorInfo *TLApiConstructorAt(uint32_t index);   // ascending constructor id
const TLFunctionInfo *TLApiFunctionAt(uint32_t index);
const TLConstructorInfo *TLApiFunctionConstructorAt(uint32_t index);   // &TLApiFunctionAt(index)->constructor
const TLConstructorInfo *_Nullable TLApiConstructorWithId(int32_t constructorId);

NS_ASSUME_NONNULL_END
