#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockStackCanvasView.h"

@class IDBlockDocument;

NS_ASSUME_NONNULL_BEGIN

@interface IDBlockStackCanvasView ()

- (IDBlockDocument *)id_document;
- (void)id_setCanvasHost:(nullable id)host;

/// The provider's answer for `identifier` when one is set, else the map's.
- (nullable NSDictionary<NSAttributedStringKey, id> *)id_emptyLineAttributesForIdentifier:(NSUUID *)identifier;
- (CGFloat)id_emptyLineCaretOffsetForIdentifier:(NSUUID *)identifier;

/// Where a run caught under a finger settles: where it is, clamped into its own range. A touch
/// during the rubber band would otherwise settle it outside that range, with nothing left to bring
/// it back — the bounce it interrupted is what would have.
+ (CGFloat)id_caughtRunOffsetForCurrent:(CGFloat)current maximum:(CGFloat)maximum;

/// Whether any placed run is being dragged or coasting. See `-[IDBlockTextView id_hasPlacedRunInFlight]`.
- (BOOL)id_hasPlacedRunInFlight;

/// Whether the placed run OWNING this view is in flight. See
/// `-[IDBlockTextView id_isPlacedRunInFlightForView:]`.
- (BOOL)id_isPlacedRunInFlightForView:(UIView *)view;


@end

NS_ASSUME_NONNULL_END

#endif
