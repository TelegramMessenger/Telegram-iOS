#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDRichTextAnchor.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDRichTextAnchor ()

@property(nonatomic, readonly) BOOL id_tracksChanges;
@property(nonatomic, readonly) NSUInteger id_snapshotCanonicalOffset;

/// An UNTRACKED anchor's offset read against a document of `canonicalLength`: its snapshot, clamped —
/// and the clamp is STICKY. Once the document is shorter than the snapshot, the snapshot becomes that
/// length for good, so a position past the end is the end from then on and never re-grows into text
/// typed later. Re-growing is what kept UIKit's input-controller range stale: after a paste left a
/// snapshot at 6, the composer's Send emptied the document and typing "abc" moved the caret to 3 — and
/// the stale range READ 3 as well (`MIN(6, 3)`), so every caret update while typing at the end looked
/// like no change and the controller kept the stale range; the next paste measured from it and
/// resolved 6 in the grown text (composer harness, 2026-09-23, `HarnessPasteCaretAfterSendTests`).
/// Clamped for good, the stale range reads 0 after the clear, the first keystroke's caret differs from
/// it, and the controller takes a fresh range, as it does for any other edit.
- (NSUInteger)id_snapshotCanonicalOffsetClampedToLength:(NSUInteger)canonicalLength;

- (instancetype)initWithDocument:(IDBlockDocument *)document
                  blockIdentifier:(NSUUID *)blockIdentifier
                       localOffset:(NSUInteger)localOffset
                              bias:(IDRichTextAnchorBias)bias
                     tracksChanges:(BOOL)tracksChanges;

@end

NS_ASSUME_NONNULL_END

#endif
