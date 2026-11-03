#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Where the engine's SOURCE lives, for the suites that read it off disk and assert on its text.
///
/// A dozen of these tests are source scanners: they read `TextView/IDBlockTextView.m` and assert
/// that a method body calls (or never calls) something. Upstream they resolved the engine's root as
/// `__FILE__`'s grandparent, which was true there — `Tests/` sat beside `TextView/` and
/// `PrivateUIKit/`. Here the tests live under `Host/Engine/Tests/` and the engine under
/// `Sources/RichTextInputDecUpstream/`, so that assumption reads an empty directory: every scanner
/// failed with `viewSource == nil`, which is a test that cannot find its subject rather than a
/// subject that changed. 14 of the 26 unexpected failures in the import's first run were this.
///
/// **The `.h` half is not just a different root.** PROVENANCE's layout deviation flattened the
/// engine's headers into `include/` (public) and `Internal/` (private), while upstream keeps each
/// one beside its `.m` under `TextView/` or `PrivateUIKit/`. So a path is TRANSLATED, not merely
/// rebased, and the scanners keep quoting upstream-relative paths — which is what you want: those
/// strings say which file of the ENGINE is meant, and they stay readable against upstream's own
/// history.
NSString *IDEngineSourceRoot(void);

/// The on-disk path for an upstream-relative source path, or the rebased path unchanged when
/// nothing matches — a scanner that asks for a file which does not exist must still get a path it
/// can fail to read, exactly as it did upstream. Several tests deliberately pass names like
/// `TextView/Bad.m` while building temporary fixture trees; those must not be redirected anywhere.
NSString *IDEngineSourceFile(NSString *upstreamRelativePath);

/// The engine spells a private UIKit name only through its encoded entry in the generated
/// `TGPrivateRuntimeNames.h` (`TGPN_<name>()`), and compiles a callback UIKit sends under a private
/// name as a neutral `tgpn_` method. This maps each entry's function name (`TGPN_…`) to the name
/// it decodes to, read from the header itself, so a source scanner can recognise both spellings.
NSDictionary<NSString *, NSString *> *IDPrivateRuntimeNamesByFunction(void);

/// The neutral selector a private-named callback is compiled under: its first keyword prefixed with
/// `tgpn_` (`characterRangeForTextRange:` -> `tgpn_characterRangeForTextRange:`).
NSString *IDNeutralSelectorName(NSString *privateSelectorName);

/// YES when `path` names an upstream RUN RECORD — an `.xcresult` bundle written by one of upstream's
/// own test runs — rather than source this repo owns.
///
/// The authorization fixtures under `Host/Engine/Tests/Fixtures/` cite these by name as the evidence
/// behind each private-UIKit decision, and the suites assert their SHAPE. They deliberately do NOT
/// assert the bundle is on disk, and that is not laziness about finishing the import: of the 48
/// artifacts those fixtures name, 22 survive in the `~/Documents/InputDec` archive and **26 exist
/// nowhere at all**. `.xcresult` bundles are transient run output and these are upstream's TDD audit
/// trail (`…task3-withdrawal-red`, `…task3-withdrawn-green`), so the check was true on one machine at
/// one moment and is unsatisfiable anywhere now, upstream included.
///
/// Copying the surviving 22 would not restore it either: an existence check is satisfied by an empty
/// directory of the right name, so it would be a filename check wearing the clothes of evidence. What
/// constrains THIS code — which callback is authorized, on which owner, with which decision and
/// fallback host, pinned to a runtime and to Hopper addresses — is asserted in full and passes. The
/// surviving provenance claim is recorded in `PROVENANCE.md`, which is where a fact about upstream's
/// disk belongs.
///
/// The Hopper markdown those fixtures also cite IS versioned here (`Host/Engine/docs/hopper/`), so
/// those references keep their on-disk assertion. The split is the point: check what this repo owns.
BOOL IDIsUpstreamRunArtifactPath(NSString *path);

NS_ASSUME_NONNULL_END
