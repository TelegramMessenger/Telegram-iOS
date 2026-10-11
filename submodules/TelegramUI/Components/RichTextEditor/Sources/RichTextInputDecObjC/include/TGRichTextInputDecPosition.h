// AUTHORED telegram-ios-side — NOT part of the vendored snapshot. See Vendor/VENDOR.md.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The ID backend's own `UITextPosition` identity object — mirrors the legacy backend's
/// `LegacyTextPosition` (`InputBackend/Legacy/LegacyTextPosition.swift`): backend-owned, opaque
/// outside `IDTextEditorBackend`, one UTF-16 offset (plus the affinity UIKit's private text
/// system needs to disambiguate a boundary offset).
///
/// `documentRevision` is STALENESS METADATA, not identity — see `isEqual:`/`hash` below. It lets
/// `TGRichTextInputDecLayoutController` detect a position minted before an intervening edit and
/// attempt exactly one rebase through the document client before giving up (never looping, never
/// fabricating offset 0 — see `TGRichTextInputDecClientBridge.h`'s `documentRebaseOffset:` doc
/// comment).
@interface TGRichTextInputDecPosition : UITextPosition

@property(nonatomic, readonly) NSInteger utf16Offset;
@property(nonatomic, readonly) UITextStorageDirection affinity;
@property(nonatomic, readonly) uint64_t documentRevision;

+ (instancetype)positionWithOffset:(NSInteger)offset
                           affinity:(UITextStorageDirection)affinity
                           revision:(uint64_t)revision;

/// The designated initializer (`positionWithOffset:affinity:revision:` forwards to it). Declared
/// as a real `-init...` — not just the class factory method above — so Swift's Cocoa-initializer
/// importer gives call sites `TGRichTextInputDecPosition(offset:affinity:revision:)` regardless
/// of whether the factory-method name (`positionWithOffset:...`) happens to satisfy the
/// importer's "leading word matches the class's stripped base name" heuristic — verified against
/// a real simulator build (`IDBackendFamily1Tests`, which calls exactly this initializer form)
/// rather than assumed; see the package `CLAUDE.md`'s note on Swift-spelling traps.
- (instancetype)initWithOffset:(NSInteger)offset
                       affinity:(UITextStorageDirection)affinity
                       revision:(uint64_t)revision NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
