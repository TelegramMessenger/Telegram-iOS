#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One method a class answers under a private UIKit selector.
///
/// UIKit calls these methods on our objects by name — the layout controller's callbacks, the text
/// view's keyboard-input and paste hooks — so the private selector has to exist on the class at run
/// time. Written as an ordinary method under that name, it would also exist in the binary as plain
/// text. So the method is compiled under a neutral name (`implementation`), and
/// `TGPrivateInstallMethodAliases` adds it under the private one (`privateName`, decoded from
/// `TGPrivateRuntimeNames.h`) before anything can ask for it. This is the arrangement
/// `UIViewController+Navigation.m` already uses for `_canAffectStatusBarAppearance`.
typedef struct TGPrivateMethodAlias {
    NSString * _Nonnull (* _Nonnull privateName)(void);
    SEL _Nonnull implementation;
} TGPrivateMethodAlias;

/// Adds every alias to `cls`, from the implementation `cls` resolves for the neutral selector (its
/// own override, or an inherited one). Idempotent. A private name `cls` already defines itself is
/// left alone, and an alias whose implementation `cls` does not respond to is skipped. Install from
/// `+initialize` for the class AND for every subclass that overrides a neutral method, so the
/// override is reached under the private name too.
FOUNDATION_EXPORT void TGPrivateInstallMethodAliases(Class cls, const TGPrivateMethodAlias *aliases, NSUInteger count);

NS_ASSUME_NONNULL_END
