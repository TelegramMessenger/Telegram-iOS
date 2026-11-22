#import <AVFoundation/AVFoundation.h>
#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/TGMediaEditingContext.h>

@interface AVURLAsset (TGMediaItem) <TGMediaSelectableItem, TGMediaEditableItem>

@end
