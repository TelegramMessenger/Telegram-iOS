#import "TGPhotoEditorToolView.h"
#import "PGPhotoEditorItem.h"

@interface TGPhotoEditorGenericToolView : UIView <TGPhotoEditorToolView>

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem;
- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem explicit:(bool)explicit nameWidth:(CGFloat)nameWidth;

@end
