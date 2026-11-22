// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import "TGRichTextInputDecClientBridge.h"

NS_ASSUME_NONNULL_BEGIN

/// The object handed to the behavior kernel as `layoutController`. It implements the 47
/// incoming private callbacks that UIKit's private text-input controller sends, each as a
/// one-line forward to a neutral `id_`-prefixed method that talks to `bridge`.
///
/// Document-neutral by construction: it holds no Telegram type and no InputDec document type,
/// only the bridge. This is the class InputDec's `IDRichTextLayoutController` would be if it
/// had not been written against `IDBlockDocument` — it is a rewrite, not a port.
///
/// TASK C0 SCOPE: only the connection/teardown row group (manifest rows 1, 26-29 —
/// `textStorage`, `textInputController`, `adoptTextInputController:`,
/// `detachFromTextInputController`, `canAccessLayoutManager`) is implemented here. The other 42
/// `incomingCallbacks` rows are deliberately NOT stubbed: the manifest marks every one of the 47
/// rows `required`, so an unimplemented row keeps the whole `incomingCallbacks` capability
/// rejected (loud — `isSupported()` stays false) rather than silently answering a plausible-looking
/// wrong value. See `IDTextEditorBackend.swift` for the resulting `isSupported()` measurement.
@interface TGRichTextInputDecLayoutController : NSObject

- (instancetype)initWithBridge:(id<TGRichTextInputDecClientBridging>)bridge
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// The single synthetic NSTextContainer the callbacks vend. UIKit requires container objects to
/// exist; `canAccessLayoutManager` answers NO and `layoutManager` answers nil, so no real
/// TextKit graph is ever demanded (upstream does exactly this).
@property(nonatomic, strong, readonly) NSTextContainer *syntheticContainer;

@property(nonatomic, strong, nullable) NSTextStorage *textStorageFacade;

@end

NS_ASSUME_NONNULL_END

#endif
