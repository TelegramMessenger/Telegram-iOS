// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecExceptionGuard.h"

NSErrorDomain const TGRichTextInputDecExceptionGuardErrorDomain =
    @"TGRichTextInputDecExceptionGuardErrorDomain";

static NSError *TGErrorFromException(NSException *exception) {
    NSMutableDictionary<NSString *, id> *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = exception.reason ?: @"<no reason>";
    userInfo[@"TGRichTextInputDecExceptionName"] = exception.name ?: @"<unnamed>";
    if (exception.userInfo != nil) {
        userInfo[@"TGRichTextInputDecExceptionUserInfo"] = exception.userInfo;
    }
    return [NSError errorWithDomain:TGRichTextInputDecExceptionGuardErrorDomain
                               code:1
                           userInfo:userInfo.copy];
}

BOOL TGRichTextInputDecPerform(void (NS_NOESCAPE ^block)(void), NSError **error) {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) { *error = TGErrorFromException(exception); }
        return NO;
    }
}

id TGRichTextInputDecPerformReturningObject(id (NS_NOESCAPE ^block)(void), NSError **error) {
    @try {
        return block();
    } @catch (NSException *exception) {
        if (error != NULL) { *error = TGErrorFromException(exception); }
        return nil;
    }
}

#endif
