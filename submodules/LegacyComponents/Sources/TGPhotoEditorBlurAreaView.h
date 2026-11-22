#import <UIKit/UIKit.h>
#import "PGPhotoEditorItem.h"
#import <LegacyComponents/TGPhotoEditorToolView.h>

@interface TGPhotoEditorBlurAreaView : UIView <TGPhotoEditorToolView>

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem;

@end
