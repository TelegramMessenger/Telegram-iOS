#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGRichTextInputDecCanvasABIWitness.h"
#import "TGRichTextInputDecCanvasCallbacks.h"
#import "TGPrivateMethodAliases.h"
#import "TGPrivateRuntimeNames.h"

// The method SIGNATURES here are NOT copied from the Task B4 brief's literal Step-4 snippet
// verbatim: the controller supplement decoded the compiled-in contract manifest and found
// `autoscrollEntry.start` / `startAutoscroll:` has returnType "v" (void) in the manifest, not "B"
// (BOOL) as the brief's snippet declared — a mismatch that would compile but fail resolver
// validation (the resolver compares runtime type encodings). This file follows the supplement's
// decoded table.
//
// keyboardInputShouldDelete: now consults the attached client bridge (Task B5, this task). Task
// B4 shipped this method as a self-contained placeholder (unconditional YES) because the bridge
// symbols (TGRichTextInputDecAttachedBridge / TGRichTextInputDecClientBridging) did not exist
// yet — see that task's own recorded deviation note, now removed since the infrastructure it
// deferred to has landed. Per TGRichTextInputDecInstallCanvasCallbacks's documented design (see
// its header), the installer borrows this class's COMPILED IMPs directly onto the real canvas via
// class_getInstanceMethod/class_addMethod rather than writing bodies of its own — so this body IS
// the production behavior for the real canvas's `keyboardInputShouldDelete:`.

@implementation TGRichTextInputDecCanvasABIWitness

// Two of the witnessed selectors are private UIKit names; they are compiled under neutral names and
// added under the private ones here (`TGPrivateMethodAliases.h`), so the resolver and the canvas
// installer find them by selector exactly as before.
+ (void)initialize {
    if (self != TGRichTextInputDecCanvasABIWitness.class) {
        return;
    }
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_keyboardInputShouldDelete_, @selector(tgpn_keyboardInputShouldDelete:) },
        { TGPN_startAutoscroll_, @selector(tgpn_startAutoscroll:) },
    };
    TGPrivateInstallMethodAliases(self, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

- (BOOL)tgpn_keyboardInputShouldDelete:(id)textInput {
    id<TGRichTextInputDecClientBridging> bridge = TGRichTextInputDecAttachedBridge(self);
    if (bridge == nil) {
        // No bridge attached (canvas not yet wired to a backend, or the backend detached) — the
        // same safe fallback the placeholder always returned: allow the delete.
        return YES;
    }
    // TASK C7 (Family 4) — the intent latch. This method's own IMP is borrowed verbatim onto the
    // real canvas by `TGRichTextInputDecInstallCanvasCallbacks` (see this class's own doc comment:
    // "this body IS the production behavior"), so adding the latch HERE — rather than duplicating
    // this selector as a fourth unconditional thunk in `TGRichTextInputDecCanvasCallbacks.m` — is
    // the only way to touch it without disturbing the compiled IMP/type-encoding pair the resolver
    // already validated for this manifest row (`inputController.keyboardDeletePreflight`).
    TGRichTextInputDecLatchIntent(bridge, TGRichTextInputDecIntentDeleteBackward);
    return [bridge canvasKeyboardInputShouldDelete];
}

- (void)tgpn_startAutoscroll:(CGPoint)point {
    // The `autoscrollEntry` capability is never requested (Telegram's canvas is a UIView inside
    // a separate scroll view, not the scroll view itself), so this exists only to give the
    // manifest row a real ABI to validate against.
}

- (void)cancelAutoscroll {
}

@end

#endif
