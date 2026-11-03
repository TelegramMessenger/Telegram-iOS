#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <Foundation/Foundation.h>
// Path-qualified for the reason spelled out in TGRichTextInputDec.h: SwiftPM
// propagates only include/ to dependents, so a bare sibling-less name does not
// resolve when the umbrella module is built.
#import "Kernel/IDUIKitRuntimeContract.h"

NS_ASSUME_NONNULL_BEGIN

/// The runtime contract manifest, parsed from bytes compiled into this module.
///
/// THIS FUNCTION returns nil rather than @throw-ing when the compiled-in data fails to parse.
/// That is a narrow guarantee and must not be over-read: the vendored kernel still raises
/// NSException on a contract mismatch in SEVEN other places, and TGRichTextInputDecHostPreflight's
/// two class methods raise as well. Notably, with this function returning nil,
/// IDUIKitInteractionRuntimeContract() dereferences a nil manifest and throws. Every reachable
/// entry point is therefore funnelled through TGRichTextInputDecExceptionGuard on the Swift side;
/// see that plan's Task A8.
///
/// THE SURVIVOR LIST IS IN Vendor/VENDOR.md, NOT HERE. The Task A4 brief named six sites and then
/// listed seven line numbers, and one of the seven (IDUIKitInteractionCapability.m:130) is the
/// manifest lookup the export's Edit 1 DELETES, while a real survivor
/// (IDUIKitBehaviorReport.m:80) was missing. Line numbers restated away from the file that
/// derives them go stale silently — Task A8 must re-derive them from VENDOR.md, which the
/// exporter writes.
FOUNDATION_EXPORT IDUIKitRuntimeManifest * _Nullable TGRichTextInputDecContractManifest(void);

NS_ASSUME_NONNULL_END

#endif
