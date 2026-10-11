#import <TelegramApiObjC/TLObject.h>

NS_ASSUME_NONNULL_BEGIN

/// A hand-written constructor over plain TLObject storage (number@24 int32, optionalNumber@32
/// int64 optional, text@40, child@48, children@56, presence mask@64; 72 bytes).
extern const TLConstructorInfo TLFixture_info;
extern const TLConstructorInfo TLFixtureEmpty_info;

TLObject *TLFixtureCreate(int32_t number, int64_t optionalNumber, NSString *text, TLObject *_Nullable child, NSArray<TLObject *> *_Nullable children, uint64_t present) NS_RETURNS_RETAINED;
int32_t TLFixtureNumber(TLObject *object);
TLObject *TLFixtureEmptySingleton(void);

NS_ASSUME_NONNULL_END
