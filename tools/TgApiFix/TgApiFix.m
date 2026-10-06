#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

// ====== ВПИШИ СВОИ КЛЮЧИ с https://my.telegram.org ======
// API development tools -> Create application -> взять api_id и api_hash.
// Чужие/публичные ключи Telegram душит лимитами (API_ID_PUBLISHED_FLOOD),
// поэтому нужны личные.
static const int32_t kApiId = 26038409;
static NSString * const kApiHash = @"462cbea6c75e4dd6da95cb56820ac50f";

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

// Debug popup: visible proof the dylib is loaded, no Console needed.
static void TgApiFixShowAlert(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        UIApplication *app = [UIApplication sharedApplication];
        for (id scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            for (UIWindow *w in [(UIWindowScene *)scene windows]) {
                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }
            if (window) {
                break;
            }
        }
        if (!window) {
            for (id scene in app.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) {
                    continue;
                }
                NSArray<UIWindow *> *windows = [(UIWindowScene *)scene windows];
                if (windows.count > 0) {
                    window = windows[0];
                    break;
                }
            }
        }
        UIViewController *root = window.rootViewController;
        while (root.presentedViewController) {
            root = root.presentedViewController;
        }
        if (!root) {
            return;
        }
        NSString *msg = [NSString stringWithFormat:@"active, apiId=%d", (int)kApiId];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"TgApiFix"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
        NSLog(@"[TgApiFix] startup alert shown");
    });
}

__attribute__((constructor))
static void TgApiFixInit(void) {
    TgApiFixTryPatch();
    if (!gPatched) {
        _dyld_register_func_for_add_image(TgApiFixImageAdded);
    }
    TgApiFixShowAlert();
}
