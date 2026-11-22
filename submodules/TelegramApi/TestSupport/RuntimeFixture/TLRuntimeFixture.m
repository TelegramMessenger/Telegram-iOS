#import "TLRuntimeFixture.h"

NS_ASSUME_NONNULL_BEGIN

static const TLFieldInfo TLFixture_fields[] = {
    { .name = "number", .kind = TLFieldKindInt32, .flagsFieldIndex = -1, .offset = 24 },
    { .name = "optionalNumber", .kind = TLFieldKindInt64, .isOptional = 1, .flagsFieldIndex = 0, .flagBit = 0, .presenceBit = 0, .offset = 32 },
    { .name = "text", .kind = TLFieldKindString, .flagsFieldIndex = -1, .offset = 40 },
    { .name = "child", .kind = TLFieldKindObject, .isOptional = 1, .flagsFieldIndex = 0, .flagBit = 1, .offset = 48 },
    { .name = "children", .kind = TLFieldKindVector, .elementKind = TLFieldKindObject, .isOptional = 1, .isBoxedVector = 1, .flagsFieldIndex = 0, .flagBit = 2, .offset = 56 },
};
static TLConstructorState TLFixture_state;
const TLConstructorInfo TLFixture_info = {
    .name = "fixture", .constructorId = 0x12345678u,
    .fieldCount = 5, .instanceSize = 72, .presentOffset = 64, .fields = TLFixture_fields, .state = &TLFixture_state,
};

static TLConstructorState TLFixtureEmpty_state;
const TLConstructorInfo TLFixtureEmpty_info = {
    .name = "fixtureEmpty", .constructorId = 0x87654321u, .caseIndex = 1, .instanceSize = 24, .presentOffset = -1,
    .state = &TLFixtureEmpty_state,
};

TLObject *TLFixtureCreate(int32_t number, int64_t optionalNumber, NSString *text, TLObject *_Nullable child, NSArray<TLObject *> *_Nullable children, uint64_t present) {
    TLObject *object = TLObjectAllocate(&TLFixture_info);
    char *base = (char *)object;
    *(int32_t *)(base + 24) = number;
    *(int64_t *)(base + 32) = optionalNumber;
    *(id *)(base + 40) = [(id)text retain];
    *(id *)(base + 48) = [(id)child retain];
    *(id *)(base + 56) = [(id)children retain];
    *(uint64_t *)(base + 64) = present;
    return object;
}

int32_t TLFixtureNumber(TLObject *object) {
    return *(int32_t *)((char *)object + 24);
}

TLObject *TLFixtureEmptySingleton(void) {
    return TLObjectSingleton(&TLFixtureEmpty_info);
}

NS_ASSUME_NONNULL_END
