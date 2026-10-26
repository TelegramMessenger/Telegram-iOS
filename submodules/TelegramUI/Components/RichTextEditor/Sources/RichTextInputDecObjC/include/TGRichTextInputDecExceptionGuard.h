// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const TGRichTextInputDecExceptionGuardErrorDomain;

/// Runs `block` inside @try/@catch and converts any NSException into an NSError.
///
/// Swift has no `catch` for NSException, so an ObjC-raised exception crossing back into Swift
/// terminates the process. The vendored kernel raises on every contract mismatch — see
/// Vendor/VENDOR.md, "Behavior this snapshot does NOT change" — and it is certified against
/// exactly ONE OS build, so a mismatch on a future OS is the expected case, not an edge case.
///
/// Returns YES on clean completion; on NO, `*error` is set and out-params are untouched.
FOUNDATION_EXPORT BOOL TGRichTextInputDecPerform(void (NS_NOESCAPE ^block)(void),
                                                 NSError **error);

/// Same, for a block that returns an object. Returns nil on raise.
FOUNDATION_EXPORT id _Nullable TGRichTextInputDecPerformReturningObject(
    id _Nullable (NS_NOESCAPE ^block)(void), NSError **error);

NS_ASSUME_NONNULL_END

#endif
