#import "TGPhotoEditorToolView.h"
#import "PGPhotoEditorItem.h"

@interface TGPhotoEditorTintToolView : UIView <TGPhotoEditorToolView>

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem;

@end
