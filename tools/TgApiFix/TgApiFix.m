#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

// ====== ВПИШИ СВОИ КЛЮЧИ с https://my.telegram.org ======
// API development tools -> Create application -> взять api_id и api_hash.
// Чужие/публичные ключи Telegram душит лимитами (API_ID_PUBLISHED_FLOOD),
// поэтому нужны личные.
static const int32_t kApiId = 12345678;
static NSString * const kApiHash = @"0123456789abcdef0123456789abcdef";

static int32_t TgApiFixApiId(id self, SEL _cmd) {
    return kApiId;
}

static NSString *TgApiFixApiHash(id self, SEL _cmd) {
    return kApiHash;
}

static BOOL gPatched = NO;

static void TgApiFixTryPatch(void) {
    if (gPatched) {
        return;
    }
    Class cls = objc_getClass("BuildConfig");
    if (!cls) {
        return;
    }
    Method mId = class_getInstanceMethod(cls, sel_registerName("apiId"));
    Method mHash = class_getInstanceMethod(cls, sel_registerName("apiHash"));
    if (!mId || !mHash) {
        return;
    }
    method_setImplementation(mId, (IMP)TgApiFixApiId);
    method_setImplementation(mHash, (IMP)TgApiFixApiHash);
    gPatched = YES;
    NSLog(@"[TgApiFix] BuildConfig apiId/apiHash overridden -> %d", (int)kApiId);
}

static void TgApiFixImageAdded(const struct mach_header *mh, intptr_t slide) {
    (void)mh;
    (void)slide;
    TgApiFixTryPatch();
}

__attribute__((constructor))
static void TgApiFixInit(void) {
    TgApiFixTryPatch();
    if (!gPatched) {
        _dyld_register_func_for_add_image(TgApiFixImageAdded);
    }
}
