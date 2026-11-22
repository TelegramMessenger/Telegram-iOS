#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

// `direct` accessors are private-external symbols. SwiftPM prelinks each ObjC target into
// one relocatable object (`ld -r`), which demotes them to non-external and hides them from
// every other target, so direct dispatch is enabled only where the build links archives:
// Bazel defines TL_OBJC_DIRECT on the objc_library, which also reaches Swift's clang
// importer, so both sides always agree on how an accessor is called. SwiftPM never
// enables it, even if a package passes the define to this target: SwiftPM defines
// SWIFT_PACKAGE and does not pass a C target's defines to its Swift clients.
#if defined(TL_OBJC_DIRECT) && TL_OBJC_DIRECT && !defined(SWIFT_PACKAGE)
#define TL_DIRECT , direct
#else
#define TL_DIRECT
#endif

typedef NS_CLOSED_ENUM(uint8_t, TLFieldKind) {
    TLFieldKindInt32 = 0,
    TLFieldKindInt64 = 1,
    TLFieldKindInt256 = 2,
    TLFieldKindDouble = 3,
    TLFieldKindString = 4,   // NSString *
    TLFieldKindBytes = 5,    // NSData *
    TLFieldKindObject = 6,   // TLObject subclass
    TLFieldKindVector = 7,   // Int32/Int64: packed NSData *; String: NSArray<NSString *>; Bytes: NSArray<NSData *>; Object: NSArray<TLObject *>
};

typedef struct TLInt256 {
    int64_t _0;
    int64_t _1;
    int64_t _2;
    int64_t _3;
} TLInt256;

/// "Any type" for TLParseConstructor's expected type.
static const uint16_t TLAnyTypeIndex = 0xFFFF;

typedef struct TLFieldInfo {
    const char *name;
    TLFieldKind kind;
    TLFieldKind elementKind;
    uint8_t isOptional;
    uint8_t isBoxedVector;
    uint8_t isBareObject;
    int8_t flagsFieldIndex;
    uint8_t flagBit;
    uint8_t presenceBit;
    uint16_t typeIndex;
    uint16_t constructorIndex;
    uint32_t offset;           // byte offset in the object's storage
} TLFieldInfo;

typedef struct TLConstructorState {
    void *_Nullable singleton;
} TLConstructorState;

typedef struct TLConstructorInfo {
    const char *name;
    uint32_t constructorId;
    uint16_t typeIndex;
    uint16_t caseIndex;
    uint16_t fieldCount;
    uint32_t instanceSize;     // storage size in bytes, header included
    int32_t presentOffset;     // offset of the presence mask, -1 if none
    const TLFieldInfo *_Nullable fields;
    TLConstructorState *state;
} TLConstructorInfo;

typedef struct TLTypeInfo {
    const char *name;
    uint16_t constructorCount;
    const TLConstructorInfo *_Nonnull const *_Nonnull constructors;
} TLTypeInfo;

/// Root of every generated TL payload class. Not an NSObject: nothing it inherits is
/// visible to Swift, so TL fields named `hash` or `description` cannot resolve to a
/// runtime method. Implements reference counting, weak support and a table-driven
/// -dealloc itself (MRC).
NS_ROOT_CLASS
@interface TLObject
{
@public
    Class isa;
    uint32_t _tl_refcount;
    uint32_t _tl_flags;
    const TLConstructorInfo *_tl_info;
}

// Objects come only from TLObjectAllocate, which sizes the storage from the constructor.
+ (instancetype)alloc NS_UNAVAILABLE;
+ (instancetype)allocWithZone:(struct _NSZone *_Nullable)zone NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nonatomic, readonly TL_DIRECT) const TLConstructorInfo *tl_constructorInfo;
@property (nonatomic, readonly TL_DIRECT) uint16_t tl_typeIndex;
@property (nonatomic, readonly TL_DIRECT) uint16_t tl_caseIndex;

@end

/// Live (allocated, not destroyed, not immortal) TL objects. For leak tests.
int64_t TLObjectLiveCount(void);

/// A zeroed +1 object of `info`'s storage size (header included), refcount 1. Every TL payload
/// is a plain TLObject; its fields live at the table's offsets, read by the generated Swift.
TLObject *TLObjectAllocate(const TLConstructorInfo *info) NS_RETURNS_RETAINED;

/// The shared immortal instance of a fieldless constructor, created on first use.
TLObject *TLObjectSingleton(const TLConstructorInfo *info);

/// Scalar kinds: `scalar` points at the ivar (NULL for an absent optional), `object` is nil.
/// Other kinds: `scalar` is NULL, `object` is the stored value (nil when absent).
typedef void (*TLFieldSink)(void *_Nullable context, const TLFieldInfo *field, const void *_Nullable scalar, id _Nullable object);
void TLObjectDescribe(TLObject *object, void *_Nullable context, TLFieldSink sink);

NS_ASSUME_NONNULL_END
