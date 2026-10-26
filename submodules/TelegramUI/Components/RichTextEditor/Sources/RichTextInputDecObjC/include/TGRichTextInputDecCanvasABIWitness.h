#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A compile-time ABI witness for the three canvas-hosted manifest rows
/// (`inputController.keyboardDeletePreflight`, `autoscrollEntry.start`, `autoscrollEntry.cancel`).
///
/// The capability resolver validates a contract by looking the row's className up with
/// NSClassFromString and comparing runtime type encodings — and it runs BEFORE any method is
/// installed on the real canvas. So the manifest names this class, and
/// `TGRichTextInputDecInstallCanvasCallbacks` installs
/// `class_getMethodImplementation(TGRichTextInputDecCanvasABIWitness.class, sel)` for exactly
/// these three selectors — i.e. the IMPs the resolver validated are the IMPs that run.
///
/// Never instantiated.
@interface TGRichTextInputDecCanvasABIWitness : UIView
@end

NS_ASSUME_NONNULL_END

#endif
