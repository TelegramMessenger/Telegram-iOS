// telegram-ios-authored. NOT part of the upstream InputDec port — see PROVENANCE.md.
//
// Foundation-only on purpose. This header is PUBLIC (it lives in include/), and deviation 6 exists
// because a public header that imports a behavior-kernel header breaks a dependent's module build.
// Returning raw NSData keeps the kernel types out of it — and it is also the more faithful shape,
// because both ported call sites already have upstream's own parsing code and only ever lacked the
// bytes to feed it.
#import <Foundation/Foundation.h>

// Without this, Swift imports the function below as returning `Data?` and every use site needs an
// unwrap for a value that is documented never to be nil.
NS_ASSUME_NONNULL_BEGIN

/// The pristine upstream `UIKitBehaviorContracts-iOS26.5.json`, byte-for-byte, compiled in.
///
/// The manifest is not a bundle resource anywhere in this tree, so upstream's two
/// `URLForResource:` lookups always come back nil and the runtime-contract machinery silently
/// verifies nothing. This is what they fall back to. Never nil.
FOUNDATION_EXPORT NSData *TGRichTextInputDecUpstreamPristineContractJSON(void);

NS_ASSUME_NONNULL_END
