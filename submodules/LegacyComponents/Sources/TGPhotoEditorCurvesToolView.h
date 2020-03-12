#import "TGPhotoEditorToolView.h"
#import "PGPhotoEditorItem.h"
#import "PGCurvesTool.h"

@interface TGPhotoEditorCurvesToolView : UIView <TGPhotoEditorToolView>

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem;

+ (UIColor *)colorForCurveType:(PGCurvesType)curveType;

@end
