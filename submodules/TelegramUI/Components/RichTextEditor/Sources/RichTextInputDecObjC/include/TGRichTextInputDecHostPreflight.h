// CARVED from InputDec/PrivateUIKit/IDPrivateUIKit.m by Scripts/carve-host-preflight.sh.
// DO NOT HAND-EDIT — see Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The two IDPrivateUIKit class methods the vendored behavior kernel calls, and nothing else.
/// BOTH RAISE NSException on a mismatch — that is upstream behavior and is deliberately
/// preserved; the Swift adapter routes every call through TGRichTextInputDecExceptionGuard.
@interface TGRichTextInputDecHostPreflight : NSObject
+ (void)requireInteractionHost:(id)host stage:(NSString *)stage;
+ (BOOL)adoptResolvedTextAutoscrollingProtocol:(Protocol *)protocol onClass:(Class)viewClass;
@end

NS_ASSUME_NONNULL_END

#endif
