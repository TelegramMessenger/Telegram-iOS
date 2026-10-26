// The aggregate header the Swift adapter imports.
//
// Every import is inside the guard: all nine kernel headers and all three TG headers are
// TARGET_OS_IOS-guarded internally, so on macOS this aggregate is empty and the module is
// carried by TGRichTextInputDecModuleAnchor.m alone.
//
// AUTHORED telegram-ios-side, NOT exported — Scripts/export-behavior-kernel.sh does not own
// this file (see Vendor/VENDOR.md's "Paths this script owns"). It lists all NINE headers under
// include/Kernel/, not the seven the Task A4 brief enumerated: IDUIKitBehaviorBackend.h (the
// backend enum) and IDUIKitAutoscrollEntryCapability.h (a capability IDUIKitBehaviorKernel.h
// itself imports) were missing from that listing while its own comment said "all nine". Under
// SwiftPM's umbrella-DIRECTORY module (publicHeadersPath: "include") every header here is a
// module member regardless of this file, so the aggregate is a convenience for the adapter's
// single `#import`, and completeness costs nothing.
//
// THE KERNEL IMPORTS ARE PATH-QUALIFIED ("Kernel/…"), and that is load-bearing, not cosmetic.
// SwiftPM synthesizes an umbrella-DIRECTORY module map over include/ and propagates ONLY
// include/ itself as a -I to dependents — `cSettings: [.headerSearchPath("include/Kernel")]`
// applies to THIS target's own .m compiles and is NOT passed on. A quoted import resolves
// relative to the including file's directory first, so include/Kernel/*.h can import each
// other bare (they are siblings), but a header in include/ importing one in include/Kernel/
// resolves nowhere. Bare names built on macOS (every kernel header is TARGET_OS_IOS-guarded,
// so the aggregate is empty there and nothing is looked up) and then failed the SIMULATOR
// build with `fatal error: 'IDUIKitAutoscrollEntryCapability.h' file not found`, reported as
// `could not build module 'RichTextInputDecObjC'`. Bazel (Task A7) puts BOTH include/ and
// include/Kernel/ on `includes`, so the qualified spelling resolves there too.
#import <TargetConditionals.h>
#if TARGET_OS_IOS
#import "Kernel/IDUIKitAutoscrollEntryCapability.h"
#import "Kernel/IDUIKitBehaviorBackend.h"
#import "Kernel/IDUIKitBehaviorCapabilities.h"
#import "Kernel/IDUIKitBehaviorKernel.h"
#import "Kernel/IDUIKitBehaviorReport.h"
#import "Kernel/IDUIKitCapabilityResolver.h"
#import "Kernel/IDUIKitInputControllerCapability.h"
#import "Kernel/IDUIKitInteractionCapability.h"
#import "Kernel/IDUIKitRuntimeContract.h"
#import "TGRichTextInputDecCanvasABIWitness.h"
#import "TGRichTextInputDecCanvasCallbacks.h"
#import "TGRichTextInputDecClientBridge.h"
#import "TGRichTextInputDecContract.h"
#import "TGRichTextInputDecExceptionGuard.h"
#import "TGRichTextInputDecHostPreflight.h"
#import "TGRichTextInputDecLayoutController.h"
#import "TGRichTextInputDecSelectionRect.h"
#endif
